jest.mock('../src/repositories/reports.repository.js', () => ({
  getDailySummary: jest.fn(), getSalesTrend: jest.fn(),
}));
jest.mock('../src/utils/date.util.js', () => ({ getBusinessDate: jest.fn(() => '2026-10-25') }));

const repository = require('../src/repositories/reports.repository.js');
const service = require('../src/services/reports.service.js');

describe('reports service', () => {
  beforeEach(() => jest.clearAllMocks());

  test('returns daily totals and fills all seven trend dates', async () => {
    repository.getDailySummary.mockResolvedValueOnce({
      total_sales_amount: '125.50', total_due_amount: '25.00', total_items_sold: '3.50',
    });
    repository.getSalesTrend.mockResolvedValueOnce([
      { sale_date: '2026-10-24', sales_amount: '40.00' },
      { sale_date: new Date('2026-10-25T00:00:00.000Z'), sales_amount: '125.50' },
    ]);

    const result = await service.getDailySummary('7');
    expect(result).toEqual({
      date: '2026-10-25', total_sales_amount: '125.50', total_due_amount: '25.00',
      total_items_sold: '3.50',
      sales_trend: [
        { date: '2026-10-19', sales_amount: '0.00' },
        { date: '2026-10-20', sales_amount: '0.00' },
        { date: '2026-10-21', sales_amount: '0.00' },
        { date: '2026-10-22', sales_amount: '0.00' },
        { date: '2026-10-23', sales_amount: '0.00' },
        { date: '2026-10-24', sales_amount: '40.00' },
        { date: '2026-10-25', sales_amount: '125.50' },
      ],
    });
    expect(repository.getDailySummary).toHaveBeenCalledWith(7, '2026-10-25');
    expect(repository.getSalesTrend).toHaveBeenCalledWith(7, '2026-10-19', '2026-10-25');
  });

  test.each([undefined, null, 0, -1, 'invalid'])('rejects invalid shop ID %s', async (shopId) => {
    await expect(service.getDailySummary(shopId)).rejects.toMatchObject({ statusCode: 400 });
    expect(repository.getDailySummary).not.toHaveBeenCalled();
  });

  test('propagates a repository failure', async () => {
    repository.getDailySummary.mockRejectedValueOnce(new Error('database unavailable'));
    repository.getSalesTrend.mockResolvedValueOnce([]);
    await expect(service.getDailySummary(4)).rejects.toThrow('database unavailable');
  });
});