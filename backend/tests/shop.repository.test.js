jest.mock('../src/config/database', () => ({
  query: jest.fn(),
  getConnection: jest.fn(),
}));

const db = require('../src/config/database');
const shops = require('../src/repositories/shop.repository');

const connectionMock = () => ({
  beginTransaction: jest.fn().mockResolvedValue(undefined),
  execute: jest.fn(),
  commit: jest.fn().mockResolvedValue(undefined),
  rollback: jest.fn().mockResolvedValue(undefined),
  release: jest.fn(),
});

describe('shop repository', () => {
  beforeEach(() => jest.clearAllMocks());

  test('creates a shop with the default currency and active owner key', async () => {
    db.query.mockResolvedValueOnce([{ insertId: 21 }, undefined]);
    await expect(shops.create({ owner_id: 5, shop_name: 'Asha' })).resolves.toBe(21);
    expect(db.query.mock.calls[0][0]).toContain('active_owner_id');
    expect(db.query.mock.calls[0][1]).toEqual([5, 'Asha', undefined, undefined, 'BDT', 5]);
  });

  test('creates a shop with a selected currency and propagates duplicate-owner errors', async () => {
    db.query.mockResolvedValueOnce([{ insertId: 22 }, undefined]);
    await expect(shops.create({ owner_id: 5, shop_name: 'Store', currency: 'USD' })).resolves.toBe(22);
    expect(db.query.mock.calls[0][1]).toEqual([5, 'Store', undefined, undefined, 'USD', 5]);

    const duplicate = Object.assign(new Error('duplicate active owner'), { code: 'ER_DUP_ENTRY' });
    db.query.mockRejectedValueOnce(duplicate);
    await expect(shops.create({ owner_id: 5, shop_name: 'Store 2' })).rejects.toBe(duplicate);
  });

  test('finds a shop by ID only for its owner and hides soft-deleted rows', async () => {
    db.query.mockResolvedValueOnce([[{ id: 21, owner_id: 5 }], undefined]);
    await expect(shops.findById(21, 5)).resolves.toMatchObject({ id: 21, owner_id: 5 });
    expect(db.query.mock.calls[0][0]).toContain('owner_id = ?');
    expect(db.query.mock.calls[0][0]).toContain('deleted_at IS NULL');

    db.query.mockResolvedValueOnce([[], undefined]);
    await expect(shops.findById(21, 99)).resolves.toBeNull();
  });

  test('finds an active shop by owner and checks active-shop existence', async () => {
    db.query.mockResolvedValueOnce([[{ id: 21, owner_id: 5 }], undefined]);
    await expect(shops.findByOwnerId(5)).resolves.toMatchObject({ id: 21 });
    expect(db.query.mock.calls[0][0]).toContain('deleted_at IS NULL');

    db.query.mockResolvedValueOnce([[{ count: '1' }], undefined]);
    await expect(shops.ownerHasShop(5)).resolves.toBe(true);
    expect(db.query.mock.calls[1][0]).toContain('deleted_at IS NULL');
    db.query.mockResolvedValueOnce([[{ count: 0 }], undefined]);
    await expect(shops.ownerHasShop(8)).resolves.toBe(false);
  });

  test('updates only supplied shop fields and scopes the update to owner', async () => {
    await expect(shops.update(21, 5, {})).resolves.toBe(false);
    expect(db.query).not.toHaveBeenCalled();

    db.query.mockResolvedValueOnce([{ affectedRows: 1 }, undefined]);
    await expect(shops.update(21, 5, { shop_name: 'New name', currency: 'BDT' })).resolves.toBe(true);
    const [sql, params] = db.query.mock.calls[0];
    expect(sql).toContain('id = ? AND owner_id = ? AND deleted_at IS NULL');
    expect(params).toEqual(['New name', 'BDT', 21, 5]);

    db.query.mockResolvedValueOnce([{ affectedRows: 0 }, undefined]);
    await expect(shops.update(21, 99, { address: 'Other tenant' })).resolves.toBe(false);
  });

  test('soft-deletes shop data transactionally and releases active keys', async () => {
    const connection = connectionMock();
    connection.execute
      .mockResolvedValueOnce([[{ id: 21 }], undefined])
      .mockResolvedValueOnce([{ affectedRows: 2 }, undefined])
      .mockResolvedValueOnce([{ affectedRows: 1 }, undefined])
      .mockResolvedValueOnce([{ affectedRows: 3 }, undefined])
      .mockResolvedValueOnce([{ affectedRows: 1 }, undefined]);
    db.getConnection.mockResolvedValueOnce(connection);

    await expect(shops.delete(21, 5)).resolves.toBe(true);
    expect(connection.execute).toHaveBeenCalledTimes(5);
    expect(connection.execute.mock.calls[1][0]).toContain('product_batches');
    expect(connection.execute.mock.calls[1][0]).toContain('deleted_at = CURRENT_TIMESTAMP');
    expect(connection.execute.mock.calls[2][0]).toContain('active_sku = NULL');
    expect(connection.execute.mock.calls[3][0]).toContain('active_name = NULL');
    expect(connection.execute.mock.calls[4][0]).toContain('active_owner_id = NULL');
    expect(connection.commit).toHaveBeenCalledTimes(1);
    expect(connection.rollback).not.toHaveBeenCalled();
    expect(connection.release).toHaveBeenCalledTimes(1);
  });

  test('rolls back when the shop is missing or already soft-deleted', async () => {
    const connection = connectionMock();
    connection.execute.mockResolvedValueOnce([[], undefined]);
    db.getConnection.mockResolvedValueOnce(connection);

    await expect(shops.delete(21, 99)).resolves.toBe(false);
    expect(connection.rollback).toHaveBeenCalledTimes(1);
    expect(connection.commit).not.toHaveBeenCalled();
    expect(connection.release).toHaveBeenCalledTimes(1);
  });

  test('rolls back and releases on database failures, including connection errors', async () => {
    const connection = connectionMock();
    const failure = new Error('update failed');
    connection.execute.mockRejectedValueOnce(failure);
    db.getConnection.mockResolvedValueOnce(connection);
    await expect(shops.delete(21, 5)).rejects.toBe(failure);
    expect(connection.rollback).toHaveBeenCalledTimes(1);
    expect(connection.release).toHaveBeenCalledTimes(1);

    const connectionFailure = new Error('pool unavailable');
    db.getConnection.mockRejectedValueOnce(connectionFailure);
    await expect(shops.delete(21, 5)).rejects.toBe(connectionFailure);
  });

  test('maps shop and owner details and returns null when the active shop is not found', async () => {
    db.query.mockResolvedValueOnce([[
      {
        id: 21, owner_id: 5, shop_name: 'Asha', address: 'Dhaka', phone: '01300000000',
        currency: 'BDT', created_at: 'created', updated_at: 'updated', owner_name: 'Asha Owner',
        owner_email: 'asha@example.test', owner_phone: '01300000001',
      },
    ], undefined]);
    await expect(shops.findWithOwner(21, 5)).resolves.toMatchObject({
      id: 21,
      owner: { name: 'Asha Owner', email: 'asha@example.test' },
    });
    expect(db.query.mock.calls[0][0]).toContain('s.deleted_at IS NULL');

    db.query.mockResolvedValueOnce([[], undefined]);
    await expect(shops.findWithOwner(21, 99)).resolves.toBeNull();
  });
});
