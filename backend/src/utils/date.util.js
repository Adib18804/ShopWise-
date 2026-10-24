/**
 * Format date to MySQL date format (YYYY-MM-DD)
 */
function formatDate(date) {
  const d = new Date(date);
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/**
 * Format date to MySQL datetime format (YYYY-MM-DD HH:MM:SS)
 */
function formatDateTime(date) {
  const d = new Date(date);
  const datePart = formatDate(d);
  const hours = String(d.getHours()).padStart(2, '0');
  const minutes = String(d.getMinutes()).padStart(2, '0');
  const seconds = String(d.getSeconds()).padStart(2, '0');
  return `${datePart} ${hours}:${minutes}:${seconds}`;
}

/**
 * Get current date in MySQL format
 */
function getCurrentDate() {
  return formatDate(new Date());
}

/** Current calendar date in the ShopWise business timezone (Bangladesh). */
function getBusinessDate(date = new Date()) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Dhaka', year: 'numeric', month: '2-digit', day: '2-digit',
  }).formatToParts(date);
  const values = Object.fromEntries(parts.map(part => [part.type, part.value]));
  return `${values.year}-${values.month}-${values.day}`;
}

/** Validate a date-only value without interpreting it in local time. */
function isDateOnly(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const [year, month, day] = value.split('-').map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  return date.getUTCFullYear() === year
    && date.getUTCMonth() === month - 1
    && date.getUTCDate() === day;
}

/** Calendar-day difference between two YYYY-MM-DD values. */
function dateOnlyDaysBetween(fromDate, toDate) {
  if (!isDateOnly(fromDate) || !isDateOnly(toDate)) return null;
  const from = Date.parse(`${fromDate}T00:00:00Z`);
  const to = Date.parse(`${toDate}T00:00:00Z`);
  return Math.round((to - from) / 86400000);
}

/**
 * Get current datetime in MySQL format
 */
function getCurrentDateTime() {
  return formatDateTime(new Date());
}

/**
 * Calculate days between two dates
 */
function daysBetween(date1, date2) {
  const oneDay = 24 * 60 * 60 * 1000; // milliseconds in a day
  const d1 = new Date(date1);
  const d2 = new Date(date2);
  return Math.round(Math.abs((d1 - d2) / oneDay));
}

/**
 * Add days to a date
 */
function addDays(date, days) {
  const result = new Date(date);
  result.setDate(result.getDate() + days);
  return result;
}

/**
 * Subtract days from a date
 */
function subtractDays(date, days) {
  const result = new Date(date);
  result.setDate(result.getDate() - days);
  return result;
}

/**
 * Check if date is in the past
 */
function isInPast(date) {
  return new Date(date) < new Date();
}

/**
 * Check if date is in the future
 */
function isInFuture(date) {
  return new Date(date) > new Date();
}

/**
 * Check if date is today
 */
function isToday(date) {
  const d = new Date(date);
  const today = new Date();
  return (
    d.getDate() === today.getDate()
    && d.getMonth() === today.getMonth()
    && d.getFullYear() === today.getFullYear()
  );
}

/**
 * Get start of day
 */
function startOfDay(date) {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  return d;
}

/**
 * Get end of day
 */
function endOfDay(date) {
  const d = new Date(date);
  d.setHours(23, 59, 59, 999);
  return d;
}

module.exports = {
  formatDate,
  formatDateTime,
  getCurrentDate,
  getBusinessDate,
  isDateOnly,
  dateOnlyDaysBetween,
  getCurrentDateTime,
  daysBetween,
  addDays,
  subtractDays,
  isInPast,
  isInFuture,
  isToday,
  startOfDay,
  endOfDay,
};
