const { isDateOnly, dateOnlyDaysBetween, getBusinessDate } = require('../src/utils/date.util');

describe('date-only business helpers', () => {
  test('accepts calendar dates and rejects impossible dates', () => {
    expect(isDateOnly('2026-10-30')).toBe(true);
    expect(isDateOnly('2026-02-29')).toBe(false);
    expect(isDateOnly('2026-2-03')).toBe(false);
  });

  test('calculates calendar days without local timezone drift', () => {
    expect(dateOnlyDaysBetween('2026-10-16', '2026-10-23')).toBe(7);
    expect(dateOnlyDaysBetween('2026-10-17', '2026-10-16')).toBe(-1);
  });

  test('uses Asia/Dhaka for business-date boundaries', () => {
    expect(getBusinessDate(new Date('2026-10-15T19:00:00.000Z'))).toBe('2026-10-16');
  });
});
