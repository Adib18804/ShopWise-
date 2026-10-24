jest.mock('../src/config/database', () => ({ execute: jest.fn() }));

const db = require('../src/config/database');
const batches = require('../src/repositories/batch.repository');

const row = (overrides = {}) => ({
  id: 11, product_id: 3, quantity: '5.00', purchase_price: '40.50',
  expiry_date: '2026-12-01', is_active: 1, ...overrides,
});

describe('batch repository', () => {
  beforeEach(() => jest.clearAllMocks());

  test('creates a tenant-scoped batch with optional batch number and expiry date', async () => {
    db.execute.mockResolvedValueOnce([{ insertId: 11 }, undefined]);
    await expect(batches.create({ product_id: 3, purchase_date: '2026-10-20', quantity: 5, purchase_price: 40 }, 7))
      .resolves.toBe(11);
    expect(db.execute.mock.calls[0][0]).toContain('p.shop_id = ?');
    expect(db.execute.mock.calls[0][0]).toContain('p.deleted_at IS NULL');
    expect(db.execute.mock.calls[0][1]).toEqual([null, '2026-10-20', null, 5, 40, 3, 7]);
    db.execute.mockResolvedValueOnce([{ insertId: 12 }, undefined]);
    await expect(batches.create({ product_id: 3, batch_number: 'B-1', purchase_date: '2026-10-20', expiry_date: '2027-01-01', quantity: 1, purchase_price: 2 }, 7))
      .resolves.toBe(12);
    expect(db.execute.mock.calls[1][1]).toEqual(['B-1', '2026-10-20', '2027-01-01', 1, 2, 3, 7]);
  });

  test('finds batches by ID, hides deleted and foreign-shop records, and supports locks', async () => {
    db.execute.mockResolvedValueOnce([[row()], undefined]);
    await expect(batches.findById(11, 7)).resolves.toMatchObject({ id: 11 });
    expect(db.execute.mock.calls[0][0]).toContain('pb.deleted_at IS NULL');
    db.execute.mockResolvedValueOnce([[], undefined]);
    await expect(batches.findById(11, 99)).resolves.toBeNull();

    db.execute.mockResolvedValueOnce([[row({ product_name: 'Rice', shop_id: 7 })], undefined]);
    await expect(batches.findByIdWithProduct(11, 7)).resolves.toMatchObject({ product_name: 'Rice' });
    expect(db.execute.mock.calls[2][0]).not.toContain('FOR UPDATE');
    db.execute.mockResolvedValueOnce([[], undefined]);
    await expect(batches.findByIdWithProduct(11, 7, db, true)).resolves.toBeNull();
    expect(db.execute.mock.calls[3][0]).toContain('FOR UPDATE');
    expect(db.execute.mock.calls[3][0]).toContain('pb.is_active = TRUE');
  });

  test('lists active batches with deterministic FEFO ordering and optional depleted inclusion', async () => {
    db.execute.mockResolvedValueOnce([[row()], undefined]);
    await expect(batches.findByProductId(3, 7)).resolves.toHaveLength(1);
    expect(db.execute.mock.calls[0][0]).toContain('pb.quantity > 0');
    expect(db.execute.mock.calls[0][0]).toContain('pb.expiry_date ASC, pb.purchase_date ASC, pb.id ASC');
    expect(db.execute.mock.calls[0][1]).toEqual([3, 7]);
    db.execute.mockResolvedValueOnce([[row({ quantity: '0' })], undefined]);
    await expect(batches.findByProductId(3, 7, true)).resolves.toHaveLength(1);
    expect(db.execute.mock.calls[1][0]).not.toContain('pb.quantity > 0');
  });

  test('updates only supported supplied fields, scopes the tenant, and returns false for no fields', async () => {
    await expect(batches.update(11, 7, {})).resolves.toBe(false);
    expect(db.execute).not.toHaveBeenCalled();
    db.execute.mockResolvedValueOnce([{ affectedRows: 1 }, undefined]);
    await expect(batches.update(11, 7, { quantity: 2, purchase_price: 3, expiry_date: null, ignored: 'x' })).resolves.toBe(true);
    const [sql, params] = db.execute.mock.calls[0];
    expect(sql).toContain('pb.quantity = ?, pb.purchase_price = ?, pb.expiry_date = ?');
    expect(sql).toContain('p.shop_id = ?');
    expect(sql).toContain('pb.deleted_at IS NULL');
    expect(params).toEqual([2, 3, null, 11, 7]);
    db.execute.mockResolvedValueOnce([{ affectedRows: 0 }, undefined]);
    await expect(batches.update(11, 99, { quantity: 2 })).resolves.toBe(false);
  });

  test('deactivates only active batches owned by the shop', async () => {
    db.execute.mockResolvedValueOnce([{ affectedRows: 1 }, undefined]);
    await expect(batches.deactivate(11, 7)).resolves.toBe(true);
    expect(db.execute.mock.calls[0][0]).toContain('SET pb.is_active = FALSE, pb.deleted_at = CURRENT_TIMESTAMP');
    expect(db.execute.mock.calls[0][0]).toContain('p.shop_id = ?');
    db.execute.mockResolvedValueOnce([{ affectedRows: 0 }, undefined]);
    await expect(batches.deactivate(11, 99)).resolves.toBe(false);
  });

  test('calculates total stock as a number', async () => {
    db.execute.mockResolvedValueOnce([[{ total_stock: '15.75' }], undefined]);
    await expect(batches.getTotalStockByProductId(3, 7)).resolves.toBe(15.75);
    expect(db.execute.mock.calls[0][0]).toContain('s.deleted_at IS NULL');
    db.execute.mockResolvedValueOnce([[{ total_stock: '0' }], undefined]);
    await expect(batches.getTotalStockByProductId(3, 7)).resolves.toBe(0);
  });

  test('creates tenant-scoped stock transactions with optional reference and notes', async () => {
    db.execute.mockResolvedValueOnce([{ insertId: 40 }, undefined]);
    await expect(batches.createTransaction({ product_id: 3, transaction_type: 'PURCHASE', quantity: 5 }, 7)).resolves.toBe(40);
    expect(db.execute.mock.calls[0][1]).toEqual([null, 'PURCHASE', 5, null, null, 3, 7]);
    db.execute.mockResolvedValueOnce([{ insertId: 41 }, undefined]);
    await expect(batches.createTransaction({ product_id: 3, batch_id: 11, transaction_type: 'ADJUSTMENT_IN', quantity: 2, reference_id: 9, notes: 'stock in' }, 7))
      .resolves.toBe(41);
    expect(db.execute.mock.calls[1][1]).toEqual([11, 'ADJUSTMENT_IN', 2, 9, 'stock in', 3, 7]);
  });

  test('lists stock history and counts transactions for the tenant', async () => {
    db.execute.mockResolvedValueOnce([[{ id: 1, batch_number: 'B-1' }], undefined]);
    await expect(batches.getTransactionsByProductId(3, 7, 20, 5)).resolves.toMatchObject([{ id: 1 }]);
    expect(db.execute.mock.calls[0][1]).toEqual([3, 7, 20, 5]);
    expect(db.execute.mock.calls[0][0]).toContain('ORDER BY st.created_at DESC, st.id DESC');
    db.execute.mockResolvedValueOnce([[{ count: '8' }], undefined]);
    await expect(batches.getTransactionCountByProductId(3, 7)).resolves.toBe(8);
  });

  test('checks sales and stock references for the same shop', async () => {
    db.execute.mockResolvedValueOnce([[{ count: '1' }], undefined]);
    await expect(batches.hasSalesReferences(11, 7)).resolves.toBe(true);
    expect(db.execute.mock.calls[0][0]).toContain('si.batch_id = ?');
    db.execute.mockResolvedValueOnce([[{ count: 0 }], undefined]);
    await expect(batches.hasSalesReferences(11, 7)).resolves.toBe(false);
    db.execute.mockResolvedValueOnce([[{ count: '2' }], undefined]);
    await expect(batches.hasStockReferences(11, 7)).resolves.toBe(true);
    db.execute.mockResolvedValueOnce([[{ count: '0' }], undefined]);
    await expect(batches.hasStockReferences(11, 7)).resolves.toBe(false);
  });

  test('finds expiring active, non-depleted batches in date order', async () => {
    db.execute.mockResolvedValueOnce([[row({ days_until_expiry: 3, value_at_risk: '202.5' })], undefined]);
    await expect(batches.findExpiringBatches(7, '2026-11-01', '2026-11-14')).resolves.toMatchObject([{ id: 11 }]);
    const [sql, params] = db.execute.mock.calls[0];
    expect(sql).toContain('pb.quantity > 0');
    expect(sql).toContain('pb.expiry_date BETWEEN ? AND ?');
    expect(sql).toContain('pb.expiry_date ASC, pb.purchase_date ASC, pb.id ASC');
    expect(params).toEqual(['2026-11-01', 7, '2026-11-01', '2026-11-14']);
  });

  test('propagates database failures from repository operations', async () => {
    const failure = new Error('database unavailable');
    db.execute.mockRejectedValueOnce(failure);
    await expect(batches.findById(11, 7)).rejects.toBe(failure);
  });
});
