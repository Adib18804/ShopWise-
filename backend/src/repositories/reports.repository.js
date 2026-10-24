const pool = require('../config/database.js');

const getDailySummary = async (shopId, date) => {
  const [rows] = await pool.execute(
    `SELECT
       COALESCE(SUM(i.total_amount - i.discount), 0) AS total_sales_amount,
       COALESCE(SUM(i.due_amount), 0) AS total_due_amount,
       COALESCE(SUM(item_totals.items_sold), 0) AS total_items_sold
     FROM sales_invoices i
     LEFT JOIN (
       SELECT invoice_id, SUM(quantity) AS items_sold
       FROM sale_items
       WHERE invoice_id IS NOT NULL
       GROUP BY invoice_id
     ) item_totals ON item_totals.invoice_id = i.id
     WHERE i.shop_id = ?
       AND DATE(i.created_at) = ?
       AND i.status = 'completed'
       AND i.deleted_at IS NULL`,
    [shopId, date],
  );
  return rows[0] ?? {
    total_sales_amount: '0.00',
    total_due_amount: '0.00',
    total_items_sold: '0.00',
  };
};

const getSalesTrend = async (shopId, startDate, endDate) => {
  const [rows] = await pool.execute(
    `SELECT DATE(i.created_at) AS sale_date,
            COALESCE(SUM(i.total_amount - i.discount), 0) AS sales_amount
       FROM sales_invoices i
      WHERE i.shop_id = ?
        AND DATE(i.created_at) BETWEEN ? AND ?
        AND i.status = 'completed'
        AND i.deleted_at IS NULL
      GROUP BY DATE(i.created_at)
      ORDER BY sale_date ASC`,
    [shopId, startDate, endDate],
  );
  return rows;
};

module.exports = { getDailySummary, getSalesTrend };