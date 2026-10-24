jest.mock('../src/config/database', () => ({ query: jest.fn() }));

const db = require('../src/config/database');
const categories = require('../src/repositories/category.repository');

const categoryRow = (overrides = {}) => ({
  id: 10,
  shop_id: 7,
  name: 'Dairy',
  description: 'Milk products',
  created_at: new Date('2026-01-01T00:00:00Z'),
  updated_at: new Date('2026-01-02T00:00:00Z'),
  product_count: '2',
  ...overrides,
});

describe('category repository', () => {
  beforeEach(() => jest.clearAllMocks());

  test('creates an active tenant category and returns its ID', async () => {
    db.query.mockResolvedValueOnce([{ insertId: 15 }, undefined]);
    await expect(categories.create({ shop_id: 7, name: 'Dairy', description: 'Milk' })).resolves.toBe(15);
    expect(db.query.mock.calls[0][0]).toContain('s.deleted_at IS NULL');
    expect(db.query.mock.calls[0][1]).toEqual(['Dairy', 'Milk', 'Dairy', 7]);
  });

  test('propagates duplicate category name errors', async () => {
    const duplicate = Object.assign(new Error('duplicate category'), { code: 'ER_DUP_ENTRY' });
    db.query.mockRejectedValueOnce(duplicate);
    await expect(categories.create({ shop_id: 7, name: 'Dairy' })).rejects.toBe(duplicate);
  });

  test('findById returns active rows and hides soft-deleted rows', async () => {
    db.query.mockResolvedValueOnce([[categoryRow()], undefined]);
    await expect(categories.findById(10, 7)).resolves.toMatchObject({ id: 10, shop_id: 7 });
    expect(db.query.mock.calls[0][0]).toContain('c.deleted_at IS NULL');
    expect(db.query.mock.calls[0][0]).toContain('c.shop_id = ?');

    db.query.mockResolvedValueOnce([[], undefined]);
    await expect(categories.findById(10, 7)).resolves.toBeNull();
  });

  test('lists categories with and without pagination', async () => {
    db.query.mockResolvedValueOnce([[categoryRow()], undefined]);
    await expect(categories.findByShopId(7, { limit: 10, offset: 20 })).resolves.toHaveLength(1);
    expect(db.query.mock.calls[0][0]).toContain('c.deleted_at IS NULL');
    expect(db.query.mock.calls[0][1]).toEqual([7, 10, 20]);

    db.query.mockResolvedValueOnce([[], undefined]);
    await expect(categories.findByShopId(7)).resolves.toEqual([]);
    expect(db.query.mock.calls[1][0]).not.toContain('LIMIT ?');
  });

  test('counts categories for a shop', async () => {
    db.query.mockResolvedValueOnce([[{ count: '4' }], undefined]);
    await expect(categories.countByShopId(7)).resolves.toBe('4');
    expect(db.query.mock.calls[0][0]).toContain('s.deleted_at IS NULL');
  });

  test('checks category names with optional excluded ID', async () => {
    db.query.mockResolvedValueOnce([[{ count: '1' }], undefined]);
    await expect(categories.nameExistsInShop(7, 'Dairy', 10)).resolves.toBe(true);
    expect(db.query.mock.calls[0][1]).toEqual([7, 'Dairy', 10]);

    db.query.mockResolvedValueOnce([[{ count: 0 }], undefined]);
    await expect(categories.nameExistsInShop(7, 'Dairy')).resolves.toBe(false);
    expect(db.query.mock.calls[1][0]).not.toContain('c.id != ?');
  });

  test('updates a category name and its active unique key; empty updates return false', async () => {
    await expect(categories.update(10, 7, {})).resolves.toBe(false);
    expect(db.query).not.toHaveBeenCalled();

    db.query.mockResolvedValueOnce([{ affectedRows: 1 }, undefined]);
    await expect(categories.update(10, 7, { name: 'Milk', description: 'Fresh dairy' })).resolves.toBe(true);
    const [sql, params] = db.query.mock.calls[0];
    expect(sql).toContain('c.active_name = ?');
    expect(sql).toContain('c.shop_id = ?');
    expect(sql).toContain('c.deleted_at IS NULL');
    expect(params).toEqual(['Milk', 'Milk', 'Fresh dairy', 10, 7]);

    db.query.mockResolvedValueOnce([{ affectedRows: 0 }, undefined]);
    await expect(categories.update(10, 8, { description: 'No access' })).resolves.toBe(false);
  });

  test('soft-deletes a category within its shop and releases its active name', async () => {
    db.query.mockResolvedValueOnce([{ affectedRows: 1 }, undefined]);
    await expect(categories.delete(10, 7)).resolves.toBe(true);
    expect(db.query.mock.calls[0][0]).toContain('SET c.deleted_at = CURRENT_TIMESTAMP');
    expect(db.query.mock.calls[0][0]).toContain('c.active_name = NULL');
    expect(db.query.mock.calls[0][0]).toContain('c.shop_id = ?');
  });

  test('checks for active products in the same shop', async () => {
    db.query.mockResolvedValueOnce([[{ count: '1' }], undefined]);
    await expect(categories.hasProducts(10, 7)).resolves.toBe(true);
    expect(db.query.mock.calls[0][0]).toContain('p.shop_id = ?');
    expect(db.query.mock.calls[0][0]).toContain('p.deleted_at IS NULL');

    db.query.mockResolvedValueOnce([[{ count: 0 }], undefined]);
    await expect(categories.hasProducts(10, 7)).resolves.toBe(false);
  });

  test('finds one category with its active product count or returns null', async () => {
    db.query.mockResolvedValueOnce([[categoryRow()], undefined]);
    await expect(categories.findWithProductCount(10, 7)).resolves.toMatchObject({ product_count: '2' });
    expect(db.query.mock.calls[0][0]).toContain('c.shop_id = ?');
    expect(db.query.mock.calls[0][0]).toContain('p.deleted_at IS NULL');

    db.query.mockResolvedValueOnce([[], undefined]);
    await expect(categories.findWithProductCount(10, 7)).resolves.toBeNull();
  });

  test('lists category product counts for a shop and propagates DB failures', async () => {
    db.query.mockResolvedValueOnce([[categoryRow()], undefined]);
    await expect(categories.findByShopIdWithCounts(7)).resolves.toHaveLength(1);
    expect(db.query.mock.calls[0][0]).toContain('s.deleted_at IS NULL');

    const failure = new Error('database unavailable');
    db.query.mockRejectedValueOnce(failure);
    await expect(categories.findByShopIdWithCounts(7)).rejects.toBe(failure);
  });
});
