const pool = require('../config/database.js');

const INVOICE_NUMBER_PREFIX = 'SW';
const MAX_INVOICE_NUMBER_RETRIES = 1000;

const formatInvoiceNumber = (shopId, sequence) =>
  `${INVOICE_NUMBER_PREFIX}-${shopId}-${sequence.toString().padStart(6, '0')}`;

/**
 * Generate the next invoice number for a shop.
 *
 * Call this using the same connection and active transaction used to create
 * the invoice. Locking the parent shop row serializes invoice creation for
 * that shop; the unique (shop_id, invoice_number) key is the final safeguard.
 */
const generateNextInvoiceNumber = async (shopId, connection) => {
  if (!connection || typeof connection.execute !== 'function') {
    throw new TypeError('A transaction connection is required to generate an invoice number');
  }

  // shops.id is the shop_id being locked. The lock is held until the caller's
  // transaction commits or rolls back.
  const [shops] = await connection.execute(
    'SELECT id FROM shops WHERE id = ? AND deleted_at IS NULL FOR UPDATE',
    [shopId],
  );
  if (!shops.length) {
    const error = new Error('Shop not found');
    error.code = 'SHOP_002';
    throw error;
  }

  const pattern = `^${INVOICE_NUMBER_PREFIX}-${shopId}-[0-9]+$`;
  const [rows] = await connection.execute(
    `SELECT COALESCE(
              MAX(CAST(SUBSTRING_INDEX(invoice_number, '-', -1) AS UNSIGNED)), 0
            ) AS last_sequence
       FROM sales_invoices
      WHERE shop_id = ? AND deleted_at IS NULL AND invoice_number REGEXP ?`,
    [shopId, pattern],
  );

  return formatInvoiceNumber(shopId, BigInt(rows[0]?.last_sequence ?? 0) + 1n);
};

/**
 * Insert an invoice on the caller's transaction connection.
 *
 * The transaction must remain open through the rest of the sale operation so
 * the shop-row lock protects number allocation until the invoice is committed.
 * Returns { id, invoice_number }, or null if the shop is missing/deleted.
 */
const create = async (invoiceData, connection) => {
  if (!connection || typeof connection.execute !== 'function') {
    throw new TypeError('A transaction connection is required to create an invoice');
  }

  const shopId = invoiceData.shop_id;
  let invoiceNumber = await generateNextInvoiceNumber(shopId, connection);
  let sequence = BigInt(invoiceNumber.split('-').at(-1));

  // Soft-deleted invoices are excluded from the sequence lookup, as required
  // for active invoice reads. If a tombstone already owns a candidate number,
  // the unique key rejects it and the held shop lock lets us safely advance.
  for (let attempt = 0; attempt < MAX_INVOICE_NUMBER_RETRIES; attempt += 1) {
    try {
      const [result] = await connection.execute(
        `INSERT INTO sales_invoices
          (shop_id, invoice_number, customer_id, total_amount, discount, paid_amount, status)
         SELECT s.id, ?, ?, ?, ?, ?, ?
           FROM shops s
          WHERE s.id = ? AND s.deleted_at IS NULL`,
        [
          invoiceNumber,
          invoiceData.customer_id ?? null,
          invoiceData.total_amount,
          invoiceData.discount ?? 0,
          invoiceData.paid_amount ?? 0,
          invoiceData.status ?? 'completed',
          shopId,
        ],
      );

      if (!result.affectedRows) return null;
      return { id: result.insertId, invoice_number: invoiceNumber };
    } catch (error) {
      if (error.code !== 'ER_DUP_ENTRY') throw error;
      sequence += 1n;
      invoiceNumber = formatInvoiceNumber(shopId, sequence);
    }
  }

  throw new Error('Unable to allocate a unique invoice number for this shop');
};

const findById = async (id, shopId, connection = pool) => {
  const [rows] = await connection.execute(
    `SELECT i.*
       FROM sales_invoices i
      WHERE i.id = ? AND i.shop_id = ? AND i.deleted_at IS NULL`,
    [id, shopId],
  );
  return rows[0] ?? null;
};

/**
 * Bulk insert invoice lines after checking invoice, product, and optional batch
 * ownership against the same shop. The caller's transaction should also hold
 * the invoice row/related batch locks needed for stock allocation.
 */
const createItems = async (items, invoiceId, shopId, connection) => {
  if (!connection || typeof connection.execute !== 'function') {
    throw new TypeError('A transaction connection is required to create sale items');
  }
  if (!Array.isArray(items)) throw new TypeError('Sale items must be an array');
  if (!items.length) return 0;

  const rowSelects = items.map(() => (
    'SELECT ? AS product_id, ? AS batch_id, ? AS quantity, ? AS unit_price, ? AS purchase_price'
  ));
  const rowParams = items.flatMap((item) => [
    item.product_id,
    item.batch_id ?? null,
    item.quantity,
    item.unit_price,
    item.purchase_price,
  ]);

  const [result] = await connection.execute(
    `INSERT INTO sale_items
       (sale_id, invoice_id, product_id, batch_id, quantity, unit_price, purchase_price)
     SELECT NULL, i.id, p.id, line.batch_id, line.quantity, line.unit_price, line.purchase_price
       FROM (${rowSelects.join(' UNION ALL ')}) AS line
       JOIN sales_invoices i ON i.id = ? AND i.shop_id = ?
         AND i.deleted_at IS NULL AND i.status = 'completed'
       JOIN products p ON p.id = line.product_id AND p.shop_id = i.shop_id
         AND p.is_active = TRUE AND p.deleted_at IS NULL
       LEFT JOIN product_batches b ON b.id = line.batch_id AND b.product_id = p.id
         AND b.is_active = TRUE AND b.deleted_at IS NULL
      WHERE line.batch_id IS NULL OR b.id IS NOT NULL`,
    [...rowParams, invoiceId, shopId],
  );

  if (result.affectedRows !== items.length) {
    const error = new Error('One or more sale items reference an inactive or foreign-shop record');
    error.code = 'SALE_ITEM_001';
    throw error;
  }
  return result.affectedRows;
};

/** Increment paid_amount without allowing overpayment or cross-shop updates. */
const addPaidAmount = async (invoiceId, shopId, amount, connection) => {
  if (!connection || typeof connection.execute !== 'function') {
    throw new TypeError('A transaction connection is required to update invoice payments');
  }
  const [result] = await connection.execute(
    `UPDATE sales_invoices
        SET paid_amount = paid_amount + ?
      WHERE id = ? AND shop_id = ? AND deleted_at IS NULL AND status = 'completed'
        AND paid_amount + ? <= total_amount - discount AND ? > 0`,
    [amount, invoiceId, shopId, amount, amount],
  );
  return result.affectedRows > 0;
};

module.exports = {
  create,
  findById,
  generateNextInvoiceNumber,
  createItems,
  addPaidAmount,
};
