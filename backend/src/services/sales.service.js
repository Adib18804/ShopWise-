const pool = require('../config/database.js');
const invoiceRepository = require('../repositories/invoice.repository.js');
const paymentRepository = require('../repositories/payment.repository.js');
const { getBusinessDate } = require('../utils/date.util.js');

const PAYMENT_METHODS = new Set(['cash', 'bkash', 'nagad']);
const MAX_DECIMAL_CENTS = 9999999999n; // DECIMAL(10,2)

class SalesServiceError extends Error {
  constructor(code, message, statusCode = 400) {
    super(message);
    this.name = 'SalesServiceError';
    this.code = code;
    this.statusCode = statusCode;
  }
}

const invalid = (message) => new SalesServiceError('SALE_VALIDATION', message, 400);
const notFound = (message) => new SalesServiceError('SALE_RESOURCE_NOT_FOUND', message, 404);
const conflict = (message) => new SalesServiceError('SALE_CONFLICT', message, 409);

/** Parse a DECIMAL(10,2) input into integer hundredths without float math. */
const toCents = (value, field, { allowZero = true } = {}) => {
  if (typeof value === 'number' && !Number.isFinite(value)) {
    throw invalid(`${field} must be a valid decimal amount`);
  }

  const text = String(value ?? '');
  const match = /^(\d+)(?:\.(\d{1,2}))?$/.exec(text);
  if (!match) throw invalid(`${field} must be a non-negative amount with at most 2 decimal places`);

  const fraction = (match[2] ?? '').padEnd(2, '0');
  const cents = BigInt(match[1]) * 100n + BigInt(fraction || '0');
  if ((!allowZero && cents === 0n) || cents > MAX_DECIMAL_CENTS) {
    throw invalid(`${field} is outside the supported amount range`);
  }
  return cents;
};

const fromCents = (cents) => {
  const whole = cents / 100n;
  const fraction = (cents % 100n).toString().padStart(2, '0');
  return `${whole}.${fraction}`;
};

// quantity and unit_price are both stored to 2 decimal places. Round the
// resulting monetary amount half-up to cents, matching DECIMAL(10,2).
const lineTotalCents = (quantityCents, unitPriceCents) =>
  (quantityCents * unitPriceCents + 50n) / 100n;

const assertPositiveId = (value, field) => {
  const id = Number(value);
  if (!Number.isSafeInteger(id) || id <= 0) throw invalid(`${field} must be a positive integer`);
  return id;
};

const prepareSale = (shopId, userId, saleData) => {
  const normalizedShopId = assertPositiveId(shopId, 'shopId');
  const normalizedUserId = assertPositiveId(userId, 'userId');
  if (!saleData || typeof saleData !== 'object') throw invalid('Sale data is required');
  if (!Array.isArray(saleData.items) || saleData.items.length === 0) {
    throw new SalesServiceError('SALE_002', 'A sale must contain at least one item', 400);
  }

  const seenProducts = new Set();
  const items = saleData.items.map((item, index) => {
    if (!item || typeof item !== 'object') throw invalid(`Item ${index + 1} is invalid`);
    const productId = assertPositiveId(item.product_id, `items[${index}].product_id`);
    if (seenProducts.has(productId)) {
      throw invalid(`Product ${productId} appears more than once; combine its quantities into one item`);
    }
    seenProducts.add(productId);

    const quantityCents = toCents(item.quantity, `items[${index}].quantity`, { allowZero: false });
    const unitPriceCents = toCents(item.unit_price, `items[${index}].unit_price`);
    return {
      product_id: productId,
      quantity_cents: quantityCents,
      unit_price_cents: unitPriceCents,
      unit_price: fromCents(unitPriceCents),
    };
  });

  const discountCents = toCents(saleData.discount ?? 0, 'discount');
  const rawPayments = saleData.payments ?? [];
  if (!Array.isArray(rawPayments)) throw invalid('payments must be an array');
  const payments = rawPayments.map((payment, index) => {
    if (!payment || typeof payment !== 'object') throw invalid(`Payment ${index + 1} is invalid`);
    const method = String(payment.payment_method ?? '').toLowerCase();
    if (!PAYMENT_METHODS.has(method)) {
      throw invalid(`Payment ${index + 1} must use cash, bkash, or nagad`);
    }
    return {
      amount_cents: toCents(payment.amount, `payments[${index}].amount`, { allowZero: false }),
      payment_method: method,
    };
  });

  return {
    shopId: normalizedShopId,
    userId: normalizedUserId,
    customerId: saleData.customer_id ?? null,
    items,
    discountCents,
    payments,
  };
};

const lockProduct = async (connection, productId, shopId) => {
  const [rows] = await connection.execute(
    `SELECT p.id, p.shop_id, p.name, p.unit
       FROM products p
       JOIN shops s ON s.id = p.shop_id
      WHERE p.id = ? AND p.shop_id = ? AND p.is_active = TRUE
        AND p.deleted_at IS NULL AND s.deleted_at IS NULL
      FOR UPDATE`,
    [productId, shopId],
  );
  if (!rows.length) throw notFound(`Product ${productId} was not found in this shop`);
  return rows[0];
};

const lockSellableBatches = async (connection, productId, shopId, businessDate) => {
  const [rows] = await connection.execute(
    `SELECT b.id, b.product_id, b.quantity, b.purchase_price, b.expiry_date, b.purchase_date
       FROM product_batches b
       JOIN products p ON p.id = b.product_id
       JOIN shops s ON s.id = p.shop_id
      WHERE b.product_id = ? AND p.shop_id = ? AND b.is_active = TRUE
        AND b.deleted_at IS NULL AND p.is_active = TRUE AND p.deleted_at IS NULL
        AND s.deleted_at IS NULL AND b.quantity > 0
        AND (b.expiry_date IS NULL OR b.expiry_date >= ?)
      ORDER BY CASE WHEN b.expiry_date IS NULL THEN 1 ELSE 0 END,
        b.expiry_date ASC, b.purchase_date ASC, b.id ASC
      FOR UPDATE`,
    [productId, shopId, businessDate],
  );
  return rows;
};

const planBatchAllocations = (item, batches, product) => {
  let remaining = item.quantity_cents;
  const allocations = [];

  for (const batch of batches) {
    if (remaining === 0n) break;
    const available = toCents(batch.quantity, `batch ${batch.id} quantity`);
    if (available === 0n) continue;

    const taken = available < remaining ? available : remaining;
    const purchasePriceCents = toCents(batch.purchase_price, `batch ${batch.id} purchase_price`);
    allocations.push({
      product_id: item.product_id,
      batch_id: batch.id,
      quantity_cents: taken,
      quantity: fromCents(taken),
      unit_price: item.unit_price,
      purchase_price: fromCents(purchasePriceCents),
      total_price_cents: lineTotalCents(taken, item.unit_price_cents),
      product_name: product.name,
    });
    remaining -= taken;
  }

  if (remaining > 0n) {
    const available = item.quantity_cents - remaining;
    throw conflict(
      `Insufficient stock for product ${product.name} (ID ${item.product_id}): requested ${fromCents(item.quantity_cents)}, available ${fromCents(available)}`,
    );
  }
  return allocations;
};

const decrementBatch = async (connection, allocation, shopId) => {
  const [result] = await connection.execute(
    `UPDATE product_batches b
       JOIN products p ON p.id = b.product_id
       JOIN shops s ON s.id = p.shop_id
        SET b.quantity = b.quantity - ?
      WHERE b.id = ? AND b.product_id = ? AND p.shop_id = ?
        AND b.is_active = TRUE AND b.deleted_at IS NULL AND b.quantity >= ?
        AND p.is_active = TRUE AND p.deleted_at IS NULL AND s.deleted_at IS NULL`,
    [
      allocation.quantity,
      allocation.batch_id,
      allocation.product_id,
      shopId,
      allocation.quantity,
    ],
  );
  if (result.affectedRows !== 1) {
    throw conflict(`Stock changed while processing product ${allocation.product_name}; retry the sale`);
  }
};

const recordStockSale = async (connection, allocation, shopId, invoice) => {
  const [result] = await connection.execute(
    `INSERT INTO stock_transactions
       (product_id, batch_id, transaction_type, quantity, reference_id, notes)
     SELECT p.id, ?, 'SALE', ?, ?, ?
       FROM products p
       JOIN shops s ON s.id = p.shop_id
      WHERE p.id = ? AND p.shop_id = ? AND p.deleted_at IS NULL AND s.deleted_at IS NULL`,
    [
      allocation.batch_id,
      allocation.quantity,
      invoice.id,
      `Invoice ${invoice.invoice_number}; processed by user ${invoice.user_id}`,
      allocation.product_id,
      shopId,
    ],
  );
  if (result.affectedRows !== 1) {
    throw conflict(`Could not record stock movement for product ${allocation.product_name}`);
  }
};

const processSale = async (shopId, userId, saleData) => {
  const sale = prepareSale(shopId, userId, saleData);
  const connection = await pool.getConnection();
  let transactionStarted = false;

  try {
    await connection.beginTransaction();
    transactionStarted = true;

    // Acquire product locks in a stable order to reduce deadlocks between
    // concurrent carts that contain overlapping products.
    const sortedItems = [...sale.items].sort((a, b) => a.product_id - b.product_id);
    const productsById = new Map();
    for (const item of sortedItems) {
      productsById.set(item.product_id, await lockProduct(connection, item.product_id, sale.shopId));
    }

    const businessDate = getBusinessDate();
    const allocations = [];
    for (const item of sortedItems) {
      const product = productsById.get(item.product_id);
      const batches = await lockSellableBatches(connection, item.product_id, sale.shopId, businessDate);
      allocations.push(...planBatchAllocations(item, batches, product));
    }

    const totalCents = allocations.reduce((total, line) => total + line.total_price_cents, 0n);
    if (totalCents > MAX_DECIMAL_CENTS) throw invalid('Sale total exceeds the supported amount range');
    if (sale.discountCents > totalCents) throw invalid('Discount cannot exceed the sale total');

    const paidCents = sale.payments.reduce((total, payment) => total + payment.amount_cents, 0n);
    if (paidCents > totalCents - sale.discountCents) {
      throw invalid('Payments cannot exceed the amount due after discount');
    }

    const invoice = await invoiceRepository.create({
      shop_id: sale.shopId,
      customer_id: sale.customerId,
      total_amount: fromCents(totalCents),
      discount: fromCents(sale.discountCents),
      paid_amount: '0.00',
      status: 'completed',
    }, connection);
    if (!invoice) throw notFound('Shop was not found or is inactive');
    invoice.user_id = sale.userId;

    for (const allocation of allocations) {
      await decrementBatch(connection, allocation, sale.shopId);
      await recordStockSale(connection, allocation, sale.shopId, invoice);
    }

    const itemRows = allocations.map(({ total_price_cents, product_name, ...line }) => line);
    await invoiceRepository.createItems(itemRows, invoice.id, sale.shopId, connection);

    const recordedPayments = [];
    for (const payment of sale.payments) {
      const amount = fromCents(payment.amount_cents);
      const paidAmountUpdated = await invoiceRepository.addPaidAmount(
        invoice.id,
        sale.shopId,
        amount,
        connection,
      );
      if (!paidAmountUpdated) throw conflict('Payment would exceed the invoice amount due');

      const paymentId = await paymentRepository.create({
        invoice_id: invoice.id,
        amount,
        payment_method: payment.payment_method,
      }, sale.shopId, connection);
      if (!paymentId) throw notFound('Invoice was not found while recording payment');
      recordedPayments.push({
        id: paymentId,
        amount,
        payment_method: payment.payment_method,
      });
    }

    const savedInvoice = await invoiceRepository.findById(invoice.id, sale.shopId, connection);
    if (!savedInvoice) throw notFound('Created invoice could not be read back');

    await connection.commit();
    transactionStarted = false;

    return {
      ...savedInvoice,
      items: allocations.map((line) => ({
        product_id: line.product_id,
        product_name: line.product_name,
        batch_id: line.batch_id,
        quantity: line.quantity,
        unit_price: line.unit_price,
        purchase_price: line.purchase_price,
        total_price: fromCents(line.total_price_cents),
      })),
      payments: recordedPayments,
    };
  } catch (error) {
    if (transactionStarted) {
      try {
        await connection.rollback();
      } catch (rollbackError) {
        error.rollbackError = rollbackError;
      }
    }
    throw error;
  } finally {
    connection.release();
  }
};

module.exports = { processSale };
