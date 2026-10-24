jest.mock('../src/config/database', () => ({
  execute: jest.fn(),
  query: jest.fn(),
  getConnection: jest.fn(),
}));

const db = require('../src/config/database');
const products = require('../src/repositories/product.repository');

const productRow = (overrides = {}) => ({
  id: 4,
  shop_id: 7,
  category_id: 3,
  name: 'Rice',
  sku: 'RICE-1',
  barcode: '12345',
  unit: 'kg',
  selling_price: '45.50',
  default_purchase_price: '40.25',
  minimum_stock: '2.00',
  target_stock_days: 7,
  is_active: 1,
  total_stock: '5.00',
  batch_count: '2',
  category_name: 'Grains',
  created_at: new Date('2026-01-01T00:00:00Z'),
  updated_at: new Date('2026-01-02T00:00:00Z'),
  ...overrides,
});

const connectionMock = () => ({
  beginTransaction: jest.fn().mockResolvedValue(undefined),
  execute: jest.fn(),
  commit: jest.fn().mockResolvedValue(undefined),
  rollback: jest.fn().mockResolvedValue(undefined),
  release: jest.fn(),
});

describe('product repository', () => {
  beforeEach(() => jest.clearAllMocks());

  test('creates a tenant-scoped product with defaults and returns its insert ID', async () => {
    db.execute.mockResolvedValue([{ insertId: 19 }, undefined]);

    await expect(products.create({
      shop_id: 7, name: 'Rice', unit: 'kg', selling_price: 45.5,
      default_purchase_price: 40.25,
    })).resolves.toBe(19);

    expect(db.execute.mock.calls[0][0]).toContain('s.deleted_at IS NULL');
    expect(db.execute.mock.calls[0][1]).toEqual([
      null, 'Rice', null, null, 'kg', 45.5, 40.25, 0, 7, null, 7,
    ]);
  });

  test('propagates duplicate-key errors from product creation', async () => {
    const duplicate = Object.assign(new Error('duplicate'), { code: 'ER_DUP_ENTRY' });
    db.execute.mockRejectedValue(duplicate);
    await expect(products.create({ shop_id: 7, name: 'Rice' })).rejects.toBe(duplicate);
  });

  test('findById returns an active tenant product and excludes soft-deleted rows', async () => {
    db.execute.mockResolvedValueOnce([[productRow()], undefined]);
    await expect(products.findById(4, 7)).resolves.toMatchObject({ id: 4, shop_id: 7 });
    expect(db.execute.mock.calls[0][0]).toContain('p.deleted_at IS NULL');
    expect(db.execute.mock.calls[0][0]).toContain('s.deleted_at IS NULL');

    db.execute.mockResolvedValueOnce([[], undefined]);
    await expect(products.findById(4, 7)).resolves.toBeNull();
  });

  test('findByIdAndShopId returns null for deleted/missing rows and supports a row lock', async () => {
    db.execute.mockResolvedValueOnce([[], undefined]);
    await expect(products.findByIdAndShopId(4, 7)).resolves.toBeNull();
    expect(db.execute.mock.calls[0][0]).toContain('p.deleted_at IS NULL');

    const connection = { execute: jest.fn().mockResolvedValue([[productRow()], undefined]) };
    await expect(products.findByIdAndShopId(4, 7, connection, true)).resolves.toMatchObject({ id: 4 });
    expect(connection.execute.mock.calls[0][0]).toContain('FOR UPDATE');
  });

  test('findByIdWithCategory maps decimal values and handles a missing category', async () => {
    db.execute.mockResolvedValueOnce([[productRow()], undefined]);
    await expect(products.findByIdWithCategory(4, 7)).resolves.toMatchObject({
      selling_price: 45.5,
      default_purchase_price: 40.25,
      category: { id: 3, name: 'Grains' },
    });

    db.execute.mockResolvedValueOnce([[productRow({ category_id: null, category_name: null })], undefined]);
    await expect(products.findByIdWithCategory(4, 7)).resolves.toMatchObject({ category: null });
    db.execute.mockResolvedValueOnce([[], undefined]);
    await expect(products.findByIdWithCategory(404, 7)).resolves.toBeNull();
  });

  test('lists products with category/search filters and pagination', async () => {
    db.execute.mockResolvedValueOnce([[productRow()], undefined]);
    const result = await products.findByShopId(7, {
      category_id: 3, search: 'rice', limit: '10', offset: '2',
    });

    expect(result).toHaveLength(1);
    expect(result[0]).toMatchObject({
      id: 4,
      selling_price: 45.5,
      total_stock: 5,
      batch_count: 2,
      category: { id: 3, name: 'Grains' },
    });
    const [sql, params] = db.execute.mock.calls[0];
    expect(sql).toContain('p.deleted_at IS NULL');
    expect(sql).toContain('c.deleted_at IS NULL');
    expect(params).toEqual([7, 3, '%rice%', '%rice%', '%rice%', 10, 2]);
  });

  test('lists products without optional filters and without offset', async () => {
    db.execute.mockResolvedValueOnce([[productRow({ batch_count: null, total_stock: null })], undefined]);
    const result = await products.findByShopId(7, { limit: 5 });
    expect(result[0]).toMatchObject({ total_stock: 0, batch_count: undefined });
    expect(db.execute.mock.calls[0][0]).toContain('LIMIT ?');
    expect(db.execute.mock.calls[0][0]).not.toContain('OFFSET ?');
    expect(db.execute.mock.calls[0][1]).toEqual([7, 5]);
  });

  test('counts by shop with optional category and search filters', async () => {
    db.execute.mockResolvedValueOnce([[{ count: '6' }], undefined]);
    await expect(products.countByShopId(7, { category_id: 3, search: 'rice' })).resolves.toBe(6);
    expect(db.execute.mock.calls[0][1]).toEqual([7, 3, '%rice%', '%rice%', '%rice%']);

    db.execute.mockResolvedValueOnce([[{ count: 0 }], undefined]);
    await expect(products.countByShopId(8)).resolves.toBe(0);
  });

  test('checks product names, barcodes, and SKUs with optional excluded IDs', async () => {
    db.execute.mockResolvedValueOnce([[{ count: '1' }], undefined]);
    await expect(products.nameExistsInShop(7, 'Rice', 4)).resolves.toBe(true);
    expect(db.execute.mock.calls[0][0]).toContain('p.deleted_at IS NULL');
    expect(db.execute.mock.calls[0][1]).toEqual([7, 'Rice', 4]);

    db.execute.mockResolvedValueOnce([[{ count: 0 }], undefined]);
    await expect(products.nameExistsInShop(7, 'Rice')).resolves.toBe(false);
    db.execute.mockResolvedValueOnce([[{ count: 1 }], undefined]);
    await expect(products.barcodeExistsInShop(7, '12345', 4)).resolves.toBe(true);
    db.execute.mockResolvedValueOnce([[{ count: 0 }], undefined]);
    await expect(products.skuExistsInShop(7, 'RICE-1')).resolves.toBe(false);
    const callsBeforeEmptySku = db.execute.mock.calls.length;
    await expect(products.skuExistsInShop(7, null)).resolves.toBe(false);
    expect(db.execute).toHaveBeenCalledTimes(callsBeforeEmptySku);
  });

  test('updates allowed fields and synchronizes the active SKU; empty updates return false', async () => {
    await expect(products.update(4, 7, {})).resolves.toBe(false);
    expect(db.execute).not.toHaveBeenCalled();

    db.execute.mockResolvedValueOnce([{ affectedRows: 1 }, undefined]);
    await expect(products.update(4, 7, { name: 'Brown rice', sku: 'BROWN-1', minimum_stock: 0 })).resolves.toBe(true);
    const [sql, params] = db.execute.mock.calls[0];
    expect(sql).toContain('p.shop_id = ?');
    expect(sql).toContain('p.deleted_at IS NULL');
    expect(sql).toContain('active_sku = ?');
    expect(params).toEqual(['Brown rice', 'BROWN-1', 'BROWN-1', 0, 4, 7]);

    db.execute.mockResolvedValueOnce([{ affectedRows: 0 }, undefined]);
    await expect(products.update(4, 8, { name: 'No access' })).resolves.toBe(false);
  });

  test('deactivates a product and its batches in one transaction', async () => {
    const connection = connectionMock();
    connection.execute
      .mockResolvedValueOnce([[{ id: 4 }], undefined])
      .mockResolvedValueOnce([{ affectedRows: 2 }, undefined])
      .mockResolvedValueOnce([{ affectedRows: 1 }, undefined]);
    db.getConnection.mockResolvedValueOnce(connection);

    await expect(products.deactivate(4, 7)).resolves.toBe(true);
    expect(connection.execute).toHaveBeenCalledTimes(3);
    expect(connection.execute.mock.calls[1][0]).toContain('product_batches');
    expect(connection.execute.mock.calls[1][0]).toContain('deleted_at IS NULL');
    expect(connection.execute.mock.calls[2][0]).toContain('active_sku = NULL');
    expect(connection.commit).toHaveBeenCalledTimes(1);
    expect(connection.rollback).not.toHaveBeenCalled();
    expect(connection.release).toHaveBeenCalledTimes(1);
  });

  test('rolls back deactivation when the tenant product is missing', async () => {
    const connection = connectionMock();
    connection.execute.mockResolvedValueOnce([[], undefined]);
    db.getConnection.mockResolvedValueOnce(connection);

    await expect(products.deactivate(4, 99)).resolves.toBe(false);
    expect(connection.rollback).toHaveBeenCalledTimes(1);
    expect(connection.commit).not.toHaveBeenCalled();
    expect(connection.release).toHaveBeenCalledTimes(1);
  });

  test('rolls back and releases the connection when deactivation encounters a DB error', async () => {
    const connection = connectionMock();
    const failure = new Error('database unavailable');
    connection.execute.mockRejectedValueOnce(failure);
    db.getConnection.mockResolvedValueOnce(connection);

    await expect(products.deactivate(4, 7)).rejects.toBe(failure);
    expect(connection.rollback).toHaveBeenCalledTimes(1);
    expect(connection.release).toHaveBeenCalledTimes(1);
  });

  test('checks batch and sales references within the product tenant', async () => {
    db.execute.mockResolvedValueOnce([[{ count: '2' }], undefined]);
    await expect(products.hasBatches(4, 7)).resolves.toBe(true);
    expect(db.execute.mock.calls[0][0]).toContain('p.shop_id = ?');
    db.execute.mockResolvedValueOnce([[{ count: 0 }], undefined]);
    await expect(products.hasSales(4, 7)).resolves.toBe(false);
  });

  test('finds detailed products, returns null for deleted rows, and filters low stock', async () => {
    db.execute.mockResolvedValueOnce([[productRow()], undefined]);
    await expect(products.findByIdWithDetails(4, 7)).resolves.toMatchObject({
      id: 4,
      total_stock: 5,
      batch_count: 2,
    });
    expect(db.execute.mock.calls[0][0]).toContain('p.deleted_at IS NULL');

    db.execute.mockResolvedValueOnce([[], undefined]);
    await expect(products.findByIdWithDetails(4, 7)).resolves.toBeNull();

    db.execute.mockResolvedValueOnce([[productRow({ id: 1, total_stock: '1', minimum_stock: '2' }),
      productRow({ id: 2, total_stock: '5', minimum_stock: '2' })], undefined]);
    await expect(products.findLowStockProducts(7)).resolves.toMatchObject([{ id: 1 }]);
  });

  test('propagates query errors from reads', async () => {
    const failure = new Error('connection lost');
    db.execute.mockRejectedValueOnce(failure);
    await expect(products.findById(4, 7)).rejects.toBe(failure);
  });
});
