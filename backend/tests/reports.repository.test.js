jest.mock('../src/config/database.js', () => ({ execute: jest.fn() }));

const pool = require('../src/config/database.js');
const repository = require('../src/repositories/reports.repository.js');

describe('reports repository', () => {
  beforeEach(() => jest.clearAllMocks());

  test('gets today totals using tenant, date, completed status, and active invoices', async () => {
    const summary = { total_sales_amount: '98.50', total_due_amount: '15.00', total_items_sold: '4.50' };
    pool.execute.mockResolvedValueOnce([[summary]]);
    await expect(repository.getDailySummary(8, '2026-10-25')).resolves.toEqual(summary);
    expect(pool.execute.mock.calls[0][0]).toContain('i.shop_id = ?');
    expect(pool.execute.mock.calls[0][0]).toContain("i.status = 'completed'");
    expect(pool.execute.mock.calls[0][0]).toContain('i.deleted_at IS NULL');
    expect(pool.execute.mock.calls[0][1]).toEqual([8, '2026-10-25']);
  });

  test('returns zero totals for an empty aggregate result', async () => {
    pool.execute.mockResolvedValueOnce([[]]);
    await expect(repository.getDailySummary(8, '2026-10-25')).resolves.toEqual({
      total_sales_amount: '0.00', total_due_amount: '0.00', total_items_sold: '0.00',
    });
  });

  test('queries completed sales for the shop within the requested trend range', async () => {
    const rows = [{ sale_date: '2026-10-24', sales_amount: '10.00' }];
    pool.execute.mockResolvedValueOnce([rows]);
    await expect(repository.getSalesTrend(8, '2026-10-19', '2026-10-25')).resolves.toEqual(rows);
    expect(pool.execute.mock.calls[0][0]).toContain('i.shop_id = ?');
    expect(pool.execute.mock.calls[0][1]).toEqual([8, '2026-10-19', '2026-10-25']);
  });
});