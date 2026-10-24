const reportsRepository = require('../repositories/reports.repository.js');
const { getBusinessDate } = require('../utils/date.util.js');

const shiftDate = (dateText, days) => {
  const date = new Date(`${dateText}T00:00:00Z`);
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
};

const decimalString = (value) => value == null ? '0.00' : String(value);

const getDailySummary = async (shopId) => {
  const normalizedShopId = Number(shopId);
  if (!Number.isSafeInteger(normalizedShopId) || normalizedShopId <= 0) {
    const error = new Error('A valid shop is required to view reports');
    error.statusCode = 400;
    throw error;
  }

  const date = getBusinessDate();
  const startDate = shiftDate(date, -6);
  const [today, rows] = await Promise.all([
    reportsRepository.getDailySummary(normalizedShopId, date),
    reportsRepository.getSalesTrend(normalizedShopId, startDate, date),
  ]);

  const salesByDate = new Map(rows.map((row) => [
    row.sale_date instanceof Date ? row.sale_date.toISOString().slice(0, 10) : String(row.sale_date).slice(0, 10),
    decimalString(row.sales_amount),
  ]));
  const salesTrend = Array.from({ length: 7 }, (_, index) => {
    const trendDate = shiftDate(startDate, index);
    return { date: trendDate, sales_amount: salesByDate.get(trendDate) ?? '0.00' };
  });

  return {
    date,
    total_sales_amount: decimalString(today.total_sales_amount),
    total_items_sold: decimalString(today.total_items_sold),
    total_due_amount: decimalString(today.total_due_amount),
    sales_trend: salesTrend,
  };
};

module.exports = { getDailySummary };