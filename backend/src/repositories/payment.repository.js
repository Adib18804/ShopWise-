const pool = require('../config/database.js');

/**
 * Record a payment on the caller's transaction connection.
 * Returns the inserted payment ID, or null when the invoice is not active,
 * completed, and owned by shopId. The service should update the invoice's
 * paid_amount in the same transaction so the ledger and generated due amount
 * remain consistent.
 */
const create = async (paymentData, shopId, connection) => {
  if (!connection || typeof connection.execute !== 'function') {
    throw new TypeError('A transaction connection is required to create a payment');
  }

  const [result] = await connection.execute(
    `INSERT INTO payments (invoice_id, amount, payment_method)
     SELECT i.id, ?, ?
       FROM sales_invoices i
      WHERE i.id = ? AND i.shop_id = ? AND i.deleted_at IS NULL AND i.status = 'completed'`,
    [paymentData.amount, paymentData.payment_method, paymentData.invoice_id, shopId],
  );
  return result.affectedRows ? result.insertId : null;
};

const findByInvoiceId = async (invoiceId, shopId, connection = pool) => {
  const [rows] = await connection.execute(
    `SELECT p.*
       FROM payments p
       JOIN sales_invoices i ON i.id = p.invoice_id
      WHERE p.invoice_id = ? AND i.shop_id = ? AND i.deleted_at IS NULL
        AND i.status = 'completed'
      ORDER BY p.created_at ASC, p.id ASC`,
    [invoiceId, shopId],
  );
  return rows;
};

const getTotalByInvoiceId = async (invoiceId, shopId, connection = pool) => {
  const [rows] = await connection.execute(
    `SELECT COALESCE(SUM(p.amount), 0) AS total_paid
       FROM payments p
       JOIN sales_invoices i ON i.id = p.invoice_id
      WHERE p.invoice_id = ? AND i.shop_id = ? AND i.deleted_at IS NULL
        AND i.status = 'completed'`,
    [invoiceId, shopId],
  );
  return rows[0]?.total_paid ?? 0;
};

module.exports = {
  create,
  findByInvoiceId,
  getTotalByInvoiceId,
};
