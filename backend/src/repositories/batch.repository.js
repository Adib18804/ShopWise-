const pool = require('../config/database.js');

const create = async (data, shopId, connection = pool) => {
  const [result] = await connection.execute(
    `INSERT INTO product_batches
      (product_id, batch_number, purchase_date, expiry_date, quantity, purchase_price)
     SELECT p.id, ?, ?, ?, ?, ? FROM products p JOIN shops s ON s.id = p.shop_id
      WHERE p.id = ? AND p.shop_id = ? AND p.is_active = TRUE
        AND p.deleted_at IS NULL AND s.deleted_at IS NULL`,
    [data.batch_number || null, data.purchase_date, data.expiry_date || null,
      data.quantity, data.purchase_price, data.product_id, shopId],
  );
  return result.insertId;
};

const findById = async (id, shopId, connection = pool) => {
  const [rows] = await connection.execute(`SELECT pb.* FROM product_batches pb
    JOIN products p ON p.id = pb.product_id JOIN shops s ON s.id = p.shop_id
    WHERE pb.id = ? AND p.shop_id = ? AND pb.deleted_at IS NULL
      AND p.deleted_at IS NULL AND s.deleted_at IS NULL`, [id, shopId]);
  return rows[0] ?? null;
};

const findByIdWithProduct = async (id, shopId, connection = pool, forUpdate = false) => {
  const [rows] = await connection.execute(
    `SELECT pb.*, p.shop_id, p.name AS product_name, p.unit,
            p.minimum_stock, p.is_active AS product_is_active
       FROM product_batches pb
       JOIN products p ON p.id = pb.product_id
       JOIN shops s ON s.id = p.shop_id
      WHERE pb.id = ? AND pb.is_active = TRUE AND pb.deleted_at IS NULL
        AND p.shop_id = ? AND p.is_active = TRUE AND p.deleted_at IS NULL AND s.deleted_at IS NULL
      ${forUpdate ? 'FOR UPDATE' : ''}`,
    [id, shopId],
  );
  return rows[0] ?? null;
};

const findByProductId = async (productId, shopId, includeDepleted = false, connection = pool) => {
  let query = `SELECT pb.* FROM product_batches pb
    JOIN products p ON p.id = pb.product_id JOIN shops s ON s.id = p.shop_id
    WHERE pb.product_id = ? AND p.shop_id = ? AND pb.is_active = TRUE
      AND pb.deleted_at IS NULL AND p.is_active = TRUE AND p.deleted_at IS NULL AND s.deleted_at IS NULL`;
  if (!includeDepleted) query += ' AND pb.quantity > 0';
  query += ` ORDER BY CASE WHEN pb.expiry_date IS NULL THEN 1 ELSE 0 END,
    pb.expiry_date ASC, pb.purchase_date ASC, pb.id ASC`;
  const [rows] = await connection.execute(query, [productId, shopId]);
  return rows;
};

const update = async (id, shopId, data, connection = pool) => {
  const fields = [];
  const values = [];
  for (const field of ['quantity', 'purchase_price', 'expiry_date']) {
    if (data[field] !== undefined) {
      fields.push(`${field} = ?`);
      values.push(data[field]);
    }
  }
  if (!fields.length) return false;
  values.push(id, shopId);
  const [result] = await connection.execute(
    `UPDATE product_batches pb JOIN products p ON p.id = pb.product_id
       JOIN shops s ON s.id = p.shop_id SET ${fields.map((field) => `pb.${field}`).join(', ')}
      WHERE pb.id = ? AND p.shop_id = ? AND pb.is_active = TRUE
        AND pb.deleted_at IS NULL AND p.deleted_at IS NULL AND s.deleted_at IS NULL`, values,
  );
  return result.affectedRows > 0;
};

const deactivate = async (id, shopId, connection = pool) => {
  const [result] = await connection.execute(
    `UPDATE product_batches pb JOIN products p ON p.id = pb.product_id
       JOIN shops s ON s.id = p.shop_id
        SET pb.is_active = FALSE, pb.deleted_at = CURRENT_TIMESTAMP
      WHERE pb.id = ? AND p.shop_id = ? AND pb.is_active = TRUE
        AND pb.deleted_at IS NULL AND p.deleted_at IS NULL AND s.deleted_at IS NULL`, [id, shopId],
  );
  return result.affectedRows > 0;
};

const getTotalStockByProductId = async (productId, shopId, connection = pool) => {
  const [rows] = await connection.execute(
    `SELECT COALESCE(SUM(quantity), 0) AS total_stock
       FROM product_batches pb JOIN products p ON p.id = pb.product_id
       JOIN shops s ON s.id = p.shop_id
      WHERE pb.product_id = ? AND p.shop_id = ? AND pb.is_active = TRUE
        AND pb.deleted_at IS NULL AND p.deleted_at IS NULL AND s.deleted_at IS NULL`, [productId, shopId],
  );
  return Number(rows[0].total_stock);
};

const createTransaction = async (data, shopId, connection = pool) => {
  const [result] = await connection.execute(
    `INSERT INTO stock_transactions
      (product_id, batch_id, transaction_type, quantity, reference_id, notes)
     SELECT p.id, ?, ?, ?, ?, ? FROM products p JOIN shops s ON s.id = p.shop_id
      WHERE p.id = ? AND p.shop_id = ? AND p.deleted_at IS NULL AND s.deleted_at IS NULL`,
    [data.batch_id ?? null, data.transaction_type, data.quantity,
      data.reference_id ?? null, data.notes ?? null, data.product_id, shopId],
  );
  return result.insertId;
};

const getTransactionsByProductId = async (productId, shopId, limit = 50, offset = 0) => {
  const [rows] = await pool.execute(
    `SELECT st.*, pb.batch_number
       FROM stock_transactions st
       LEFT JOIN product_batches pb ON pb.id = st.batch_id AND pb.deleted_at IS NULL
      JOIN products p ON p.id = st.product_id JOIN shops s ON s.id = p.shop_id
      WHERE st.product_id = ? AND p.shop_id = ? AND p.deleted_at IS NULL AND s.deleted_at IS NULL
      ORDER BY st.created_at DESC, st.id DESC LIMIT ? OFFSET ?`,
    [productId, shopId, limit, offset],
  );
  return rows;
};

const getTransactionCountByProductId = async (productId, shopId) => {
  const [rows] = await pool.execute(
    `SELECT COUNT(*) AS count FROM stock_transactions st JOIN products p ON p.id = st.product_id
       JOIN shops s ON s.id = p.shop_id
      WHERE st.product_id = ? AND p.shop_id = ? AND p.deleted_at IS NULL AND s.deleted_at IS NULL`, [productId, shopId],
  );
  return Number(rows[0].count);
};

const hasSalesReferences = async (batchId, shopId, connection = pool) => {
  const [rows] = await connection.execute(
    `SELECT COUNT(*) AS count FROM sale_items si JOIN products p ON p.id = si.product_id
       JOIN shops s ON s.id = p.shop_id
      WHERE si.batch_id = ? AND p.shop_id = ? AND p.deleted_at IS NULL AND s.deleted_at IS NULL`, [batchId, shopId],
  );
  return Number(rows[0].count) > 0;
};

const hasStockReferences = async (batchId, shopId, connection = pool) => {
  const [rows] = await connection.execute(
    `SELECT COUNT(*) AS count FROM stock_transactions st JOIN products p ON p.id = st.product_id
       JOIN shops s ON s.id = p.shop_id
      WHERE st.batch_id = ? AND p.shop_id = ? AND p.deleted_at IS NULL AND s.deleted_at IS NULL`, [batchId, shopId],
  );
  return Number(rows[0].count) > 0;
};

const findExpiringBatches = async (shopId, today, endDate) => {
  const [rows] = await pool.execute(
    `SELECT pb.*, p.name AS product_name, p.unit, p.minimum_stock,
            DATEDIFF(pb.expiry_date, ?) AS days_until_expiry,
            (pb.quantity * pb.purchase_price) AS value_at_risk
       FROM product_batches pb JOIN products p ON p.id = pb.product_id
       JOIN shops s ON s.id = p.shop_id
      WHERE p.shop_id = ? AND p.is_active = TRUE AND p.deleted_at IS NULL
        AND s.deleted_at IS NULL AND pb.is_active = TRUE AND pb.deleted_at IS NULL
        AND pb.quantity > 0 AND pb.expiry_date IS NOT NULL
        AND pb.expiry_date BETWEEN ? AND ?
      ORDER BY pb.expiry_date ASC, pb.purchase_date ASC, pb.id ASC`,
    [today, shopId, today, endDate],
  );
  return rows;
};

module.exports = {
  create, findById, findByIdWithProduct, findByProductId, update, deactivate,
  getTotalStockByProductId, createTransaction, getTransactionsByProductId,
  getTransactionCountByProductId, hasSalesReferences, findExpiringBatches,
  hasStockReferences,
};
