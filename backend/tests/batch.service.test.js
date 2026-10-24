jest.mock('../src/config/database', () => ({ getConnection: jest.fn(), end: jest.fn() }));
jest.mock('../src/repositories/batch.repository', () => ({
  create: jest.fn(), createTransaction: jest.fn(), findById: jest.fn(),
  findByProductId: jest.fn(), getTotalStockByProductId: jest.fn(),
  findByIdWithProduct: jest.fn(), update: jest.fn(), deactivate: jest.fn(),
  hasStockReferences: jest.fn(), hasSalesReferences: jest.fn(),
  getTransactionsByProductId: jest.fn(), getTransactionCountByProductId: jest.fn(),
  findExpiringBatches: jest.fn(),
}));
jest.mock('../src/repositories/product.repository', () => ({
  findByIdAndShopId: jest.fn(),
}));

const pool = require('../src/config/database');
const batches = require('../src/repositories/batch.repository');
const products = require('../src/repositories/product.repository');
const service = require('../src/services/batch.service');

describe('batch service', () => {
  beforeEach(() => {
    jest.useFakeTimers().setSystemTime(new Date('2026-10-16T12:00:00.000Z'));
    jest.clearAllMocks();
  });
  afterEach(() => jest.useRealTimers());

  test('FEFO excludes depleted, expired, and no-expiry batches and keeps deterministic source order', async () => {
    products.findByIdAndShopId.mockResolvedValue({
      id: 1, name: 'Milk', unit: 'piece', minimum_stock: 2,
    });
    batches.findByProductId.mockResolvedValue([
      { id: 2, quantity: '4', expiry_date: '2026-10-20', purchase_date: '2026-10-01' },
      { id: 1, quantity: '4', expiry_date: '2026-10-30', purchase_date: '2026-10-01' },
      { id: 3, quantity: '4', expiry_date: '2026-10-15', purchase_date: '2026-10-01' },
      { id: 4, quantity: '0', expiry_date: '2026-10-18', purchase_date: '2026-10-01' },
      { id: 5, quantity: '4', expiry_date: null, purchase_date: '2026-10-01' },
    ]);
    batches.getTotalStockByProductId.mockResolvedValue(12);

    const result = await service.getFEFORecommendations(1, 9);

    expect(products.findByIdAndShopId).toHaveBeenCalledWith(1, 9, undefined, false);
    expect(result.batches.map(batch => batch.batch_id)).toEqual([2, 1]);
    expect(result.batches.map(batch => batch.priority)).toEqual([1, 2]);
    expect(result.batches[0].days_until_expiry).toBe(4);
  });

  test('normalizes MySQL decimal strings before creating a batch and purchase audit row', async () => {
    const connection = {
      beginTransaction: jest.fn(), commit: jest.fn(), rollback: jest.fn(), release: jest.fn(),
    };
    pool.getConnection.mockResolvedValue(connection);
    products.findByIdAndShopId.mockResolvedValue({
      id: 1, name: 'Milk', unit: 'piece', minimum_stock: '0.00',
    });
    batches.create.mockResolvedValue(22);
    batches.createTransaction.mockResolvedValue(33);
    batches.findById.mockResolvedValue({
      id: 22, quantity: '2.50', expiry_date: '2026-11-01',
    });
    batches.getTotalStockByProductId.mockResolvedValue(2.5);

    await service.addBatch(1, {
      purchase_date: '2026-10-15', expiry_date: '2026-11-01',
      quantity: '2.50', purchase_price: '1.25',
    }, 9);

    expect(batches.create).toHaveBeenCalledWith(expect.objectContaining({
      quantity: 2.5, purchase_price: 1.25,
    }), 9, connection);
    expect(batches.createTransaction).toHaveBeenCalledWith(expect.objectContaining({
      transaction_type: 'PURCHASE', quantity: 2.5,
    }), 9, connection);
    expect(connection.commit).toHaveBeenCalledTimes(1);
  });

  test('rejects non-numeric decimal strings in service validation', async () => {
    await expect(service.addBatch(1, {
      purchase_date: '2026-10-15', expiry_date: '2026-11-01',
      quantity: '2.50', purchase_price: 'not-a-number',
    }, 9)).rejects.toMatchObject({ code: 'BATCH_VALIDATION' });
    expect(pool.getConnection).not.toHaveBeenCalled();
  });

  test('rolls back batch creation when the purchase audit entry fails', async () => {
    const connection = {
      beginTransaction: jest.fn(), commit: jest.fn(), rollback: jest.fn(), release: jest.fn(),
    };
    pool.getConnection.mockResolvedValue(connection);
    products.findByIdAndShopId.mockResolvedValue({ id: 1 });
    batches.create.mockResolvedValue(22);
    batches.createTransaction.mockRejectedValue(new Error('audit insert failed'));

    await expect(service.addBatch(1, {
      purchase_date: '2026-10-15', expiry_date: '2026-11-01',
      quantity: 2, purchase_price: 10,
    }, 9)).rejects.toThrow('audit insert failed');

    expect(connection.rollback).toHaveBeenCalledTimes(1);
    expect(connection.commit).not.toHaveBeenCalled();
    expect(connection.release).toHaveBeenCalledTimes(1);
  });

test('records a stock adjustment in the same transaction as a quantity change', async () => {
  const connection = {
    beginTransaction: jest.fn(), commit: jest.fn(), rollback: jest.fn(), release: jest.fn(),
  };
  pool.getConnection.mockResolvedValue(connection);
  batches.findByIdWithProduct.mockResolvedValue({
    id: 22, product_id: 1, shop_id: 9, quantity: '5', purchase_date: '2026-10-10',
    expiry_date: '2026-11-10', purchase_price: '10', minimum_stock: 1,
  });
  batches.update.mockResolvedValue(true);
  batches.createTransaction.mockResolvedValue(33);

  await service.updateBatch(22, { quantity: 3, notes: 'Count correction' }, 9);

  expect(batches.update).toHaveBeenCalledWith(22, 9, { quantity: 3, notes: 'Count correction' }, connection);
  expect(batches.createTransaction).toHaveBeenCalledWith({
    product_id: 1, batch_id: 22, transaction_type: 'ADJUSTMENT_OUT', quantity: 2,
    notes: 'Count correction',
  }, 9, connection);
  expect(connection.commit).toHaveBeenCalledTimes(1);
  expect(connection.rollback).not.toHaveBeenCalled();
  expect(connection.release).toHaveBeenCalledTimes(1);
});

test('does not deactivate a batch with remaining quantity', async () => {
  const connection = {
    beginTransaction: jest.fn(), commit: jest.fn(), rollback: jest.fn(), release: jest.fn(),
  };
  pool.getConnection.mockResolvedValue(connection);
  batches.findByIdWithProduct.mockResolvedValue({ id: 22, quantity: '2' });

  await expect(service.deleteBatch(22, 9)).rejects.toMatchObject({ code: 'BATCH_CONFLICT' });

  expect(batches.deactivate).not.toHaveBeenCalled();
  expect(connection.rollback).toHaveBeenCalledTimes(1);
  expect(connection.commit).not.toHaveBeenCalled();
  expect(connection.release).toHaveBeenCalledTimes(1);
});

test('deactivates an empty batch while retaining stock and sale references', async () => {
  const connection = {
    beginTransaction: jest.fn(), commit: jest.fn(), rollback: jest.fn(), release: jest.fn(),
  };
  pool.getConnection.mockResolvedValue(connection);
  batches.findByIdWithProduct.mockResolvedValue({ id: 22, quantity: '0' });
  batches.hasStockReferences.mockResolvedValue(true);
  batches.hasSalesReferences.mockResolvedValue(true);
  batches.deactivate.mockResolvedValue(true);

  await expect(service.deleteBatch(22, 9)).resolves.toBe(true);

  expect(batches.deactivate).toHaveBeenCalledWith(22, 9, connection);
  expect(connection.commit).toHaveBeenCalledTimes(1);
  expect(connection.rollback).not.toHaveBeenCalled();
});

test('stock history enforces product ownership before querying transactions', async () => {
  products.findByIdAndShopId.mockResolvedValue(null);

  await expect(service.getStockHistory(1, 20, 0, 99))
    .rejects.toMatchObject({ code: 'RESOURCE_NOT_FOUND', statusCode: 404 });
  expect(batches.getTransactionsByProductId).not.toHaveBeenCalled();
});
});
