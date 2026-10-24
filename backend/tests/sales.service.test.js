jest.mock('../src/config/database', () => ({ getConnection: jest.fn() }));
jest.mock('../src/repositories/invoice.repository', () => ({
  create: jest.fn(),
  findById: jest.fn(),
  createItems: jest.fn(),
  addPaidAmount: jest.fn(),
}));
jest.mock('../src/repositories/payment.repository', () => ({ create: jest.fn() }));
jest.mock('../src/utils/date.util', () => ({ getBusinessDate: jest.fn(() => '2026-10-25') }));

const pool = require('../src/config/database');
const invoiceRepository = require('../src/repositories/invoice.repository');
const paymentRepository = require('../src/repositories/payment.repository');
const service = require('../src/services/sales.service');

const eligibleBatches = [
  { id: 12, product_id: 4, quantity: '5.00', purchase_price: '7.25', expiry_date: '2026-11-30', purchase_date: '2026-10-01' },
  { id: 99, product_id: 4, quantity: '50.00', purchase_price: '1.00', expiry_date: '2026-10-24', purchase_date: '2026-10-01' },
  { id: 13, product_id: 4, quantity: '0.00', purchase_price: '6.00', expiry_date: '2026-11-01', purchase_date: '2026-09-01' },
  { id: 11, product_id: 4, quantity: '3.00', purchase_price: '8.50', expiry_date: '2026-10-29', purchase_date: '2026-10-02' },
];

const makeConnection = (batches = eligibleBatches) => {
  const connection = {
    beginTransaction: jest.fn().mockResolvedValue(undefined),
    commit: jest.fn().mockResolvedValue(undefined),
    rollback: jest.fn().mockResolvedValue(undefined),
    release: jest.fn(),
    execute: jest.fn(async (sql, params) => {
      if (sql.includes('FROM products p') && sql.includes('FOR UPDATE')) {
        return [[{ id: params[0], shop_id: params[1], name: 'Rice', unit: 'kg' }], undefined];
      }

      if (sql.includes('FROM product_batches b') && sql.includes('FOR UPDATE')) {
        const businessDate = params[2];
        const rows = batches
          .filter((batch) => Number(batch.quantity) > 0
            && (batch.expiry_date === null || batch.expiry_date >= businessDate))
          .sort((a, b) => {
            if (a.expiry_date == null && b.expiry_date != null) return 1;
            if (b.expiry_date == null && a.expiry_date != null) return -1;
            return String(a.expiry_date ?? '').localeCompare(String(b.expiry_date ?? ''))
              || String(a.purchase_date).localeCompare(String(b.purchase_date))
              || a.id - b.id;
          });
        return [rows, undefined];
      }

      if (sql.includes('UPDATE product_batches b')) return [{ affectedRows: 1 }, undefined];
      if (sql.includes('INSERT INTO stock_transactions')) return [{ affectedRows: 1 }, undefined];
      throw new Error(`Unexpected SQL in sales service test: ${sql}`);
    }),
  };
  return connection;
};

const defaultSale = (overrides = {}) => ({
  items: [{ product_id: 4, quantity: '6.00', unit_price: '10.00' }],
  discount: '0.00',
  payments: [{ amount: '20.00', payment_method: 'cash' }],
  ...overrides,
});

describe('sales service processSale', () => {
  let connection;

  beforeEach(() => {
    jest.clearAllMocks();
    connection = makeConnection();
    pool.getConnection.mockResolvedValue(connection);
    invoiceRepository.create.mockResolvedValue({ id: 55, invoice_number: 'SW-7-000055' });
    invoiceRepository.createItems.mockResolvedValue(2);
    invoiceRepository.addPaidAmount.mockResolvedValue(true);
    invoiceRepository.findById.mockResolvedValue({
      id: 55, shop_id: 7, invoice_number: 'SW-7-000055',
      total_amount: '60.00', discount: '0.00', paid_amount: '20.00', due_amount: '40.00',
    });
    paymentRepository.create.mockResolvedValue(81);
  });

  test('allocates stock FEFO across batches and commits invoice, items, stock, and payment', async () => {
    const result = await service.processSale(7, 3, defaultSale());

    expect(connection.beginTransaction).toHaveBeenCalledTimes(1);
    expect(invoiceRepository.create).toHaveBeenCalledWith(expect.objectContaining({
      shop_id: 7,
      total_amount: '60.00',
      discount: '0.00',
      paid_amount: '0.00',
      status: 'completed',
    }), connection);

    const batchSelect = connection.execute.mock.calls.find(([sql]) => sql.includes('FROM product_batches b'));
    expect(batchSelect[0]).toContain('b.expiry_date >= ?');
    expect(batchSelect[0]).toContain('ORDER BY CASE WHEN b.expiry_date IS NULL THEN 1 ELSE 0 END');
    expect(batchSelect[0]).toContain('FOR UPDATE');

    const decrements = connection.execute.mock.calls
      .filter(([sql]) => sql.includes('UPDATE product_batches b'))
      .map(([, params]) => params);
    expect(decrements).toEqual([
      ['3.00', 11, 4, 7, '3.00'],
      ['3.00', 12, 4, 7, '3.00'],
    ]);

    expect(invoiceRepository.createItems).toHaveBeenCalledWith([
      expect.objectContaining({ product_id: 4, batch_id: 11, quantity: '3.00', purchase_price: '8.50' }),
      expect.objectContaining({ product_id: 4, batch_id: 12, quantity: '3.00', purchase_price: '7.25' }),
    ], 55, 7, connection);
    expect(connection.execute.mock.calls.filter(([sql]) => sql.includes('INSERT INTO stock_transactions')))
      .toHaveLength(2);
    expect(invoiceRepository.addPaidAmount).toHaveBeenCalledWith(55, 7, '20.00', connection);
    expect(paymentRepository.create).toHaveBeenCalledWith({
      invoice_id: 55, amount: '20.00', payment_method: 'cash',
    }, 7, connection);
    expect(invoiceRepository.findById).toHaveBeenCalledWith(55, 7, connection);
    expect(result).toMatchObject({
      invoice_number: 'SW-7-000055',
      total_amount: '60.00',
      items: [
        { batch_id: 11, quantity: '3.00', total_price: '30.00' },
        { batch_id: 12, quantity: '3.00', total_price: '30.00' },
      ],
      payments: [{ id: 81, amount: '20.00', payment_method: 'cash' }],
    });
    expect(connection.commit).toHaveBeenCalledTimes(1);
    expect(connection.rollback).not.toHaveBeenCalled();
    expect(connection.release).toHaveBeenCalledTimes(1);
  });

  test('excludes expired and depleted batches from FEFO allocations', async () => {
    await service.processSale(7, 3, defaultSale({
      items: [{ product_id: 4, quantity: '2.00', unit_price: '10.00' }],
      payments: [],
    }));

    expect(invoiceRepository.createItems).toHaveBeenCalledWith([
      expect.objectContaining({ batch_id: 11, quantity: '2.00' }),
    ], 55, 7, connection);
    const decrements = connection.execute.mock.calls
      .filter(([sql]) => sql.includes('UPDATE product_batches b'));
    expect(decrements).toHaveLength(1);
    expect(decrements[0][1][1]).toBe(11);
    expect(decrements.some(([, params]) => params[1] === 99 || params[1] === 13)).toBe(false);
    expect(connection.commit).toHaveBeenCalledTimes(1);
  });

  test('throws a conflict and rolls back when eligible stock is insufficient', async () => {
    connection = makeConnection([
      { id: 21, product_id: 4, quantity: '2.00', purchase_price: '3.00', expiry_date: '2026-11-01', purchase_date: '2026-10-01' },
    ]);
    pool.getConnection.mockResolvedValue(connection);

    await expect(service.processSale(7, 3, defaultSale({
      items: [{ product_id: 4, quantity: '3.00', unit_price: '10.00' }],
      payments: [],
    }))).rejects.toMatchObject({
      name: 'SalesServiceError', code: 'SALE_CONFLICT', statusCode: 409,
      message: expect.stringContaining('Insufficient stock for product Rice'),
    });

    expect(invoiceRepository.create).not.toHaveBeenCalled();
    expect(connection.commit).not.toHaveBeenCalled();
    expect(connection.rollback).toHaveBeenCalledTimes(1);
    expect(connection.release).toHaveBeenCalledTimes(1);
  });

  test('rejects a discount greater than the sale total and rolls back', async () => {
    await expect(service.processSale(7, 3, defaultSale({
      items: [{ product_id: 4, quantity: '1.00', unit_price: '10.00' }],
      discount: '10.01',
      payments: [],
    }))).rejects.toMatchObject({ code: 'SALE_VALIDATION', message: 'Discount cannot exceed the sale total' });

    expect(invoiceRepository.create).not.toHaveBeenCalled();
    expect(connection.rollback).toHaveBeenCalledTimes(1);
    expect(connection.commit).not.toHaveBeenCalled();
  });

  test('rejects payments greater than the discounted amount due and rolls back', async () => {
    await expect(service.processSale(7, 3, defaultSale({
      items: [{ product_id: 4, quantity: '1.00', unit_price: '10.00' }],
      discount: '1.00',
      payments: [{ amount: '9.01', payment_method: 'bkash' }],
    }))).rejects.toMatchObject({
      code: 'SALE_VALIDATION', message: 'Payments cannot exceed the amount due after discount',
    });

    expect(invoiceRepository.create).not.toHaveBeenCalled();
    expect(connection.rollback).toHaveBeenCalledTimes(1);
    expect(connection.commit).not.toHaveBeenCalled();
  });

  test('rolls back all stock and invoice work when invoice creation fails', async () => {
    const failure = new Error('invoice insert failed');
    invoiceRepository.create.mockRejectedValueOnce(failure);

    await expect(service.processSale(7, 3, defaultSale())).rejects.toBe(failure);
    expect(invoiceRepository.createItems).not.toHaveBeenCalled();
    expect(connection.commit).not.toHaveBeenCalled();
    expect(connection.rollback).toHaveBeenCalledTimes(1);
    expect(connection.release).toHaveBeenCalledTimes(1);
  });

  test('rolls back paid amount and sale writes when payment insertion fails', async () => {
    const failure = new Error('payment insert failed');
    paymentRepository.create.mockRejectedValueOnce(failure);

    await expect(service.processSale(7, 3, defaultSale())).rejects.toBe(failure);
    expect(invoiceRepository.addPaidAmount).toHaveBeenCalledWith(55, 7, '20.00', connection);
    expect(connection.commit).not.toHaveBeenCalled();
    expect(connection.rollback).toHaveBeenCalledTimes(1);
  });

  test('rolls back if a locked batch cannot be conditionally decremented', async () => {
    connection.execute.mockImplementation(async (sql, params) => {
      if (sql.includes('FROM products p') && sql.includes('FOR UPDATE')) {
        return [[{ id: params[0], shop_id: params[1], name: 'Rice', unit: 'kg' }], undefined];
      }
      if (sql.includes('FROM product_batches b') && sql.includes('FOR UPDATE')) {
        return [[{ ...eligibleBatches[3] }], undefined];
      }
      if (sql.includes('UPDATE product_batches b')) return [{ affectedRows: 0 }, undefined];
      throw new Error(`Unexpected SQL in stock race test: ${sql}`);
    });

    await expect(service.processSale(7, 3, defaultSale({
      items: [{ product_id: 4, quantity: '1.00', unit_price: '10.00' }],
      payments: [],
    }))).rejects.toMatchObject({ code: 'SALE_CONFLICT', statusCode: 409 });
    expect(connection.rollback).toHaveBeenCalledTimes(1);
    expect(connection.commit).not.toHaveBeenCalled();
  });

  test('validates empty, duplicate, and malformed sale input before opening a transaction', async () => {
    await expect(service.processSale(7, 3, { items: [] }))
      .rejects.toMatchObject({ code: 'SALE_002', statusCode: 400 });
    await expect(service.processSale(7, 3, defaultSale({ items: [
      { product_id: 4, quantity: 1, unit_price: 2 },
      { product_id: 4, quantity: 1, unit_price: 2 },
    ] }))).rejects.toMatchObject({ code: 'SALE_VALIDATION' });
    await expect(service.processSale(7, 3, defaultSale({ items: [
      { product_id: 4, quantity: 1, unit_price: Number.POSITIVE_INFINITY },
    ] }))).rejects.toMatchObject({ code: 'SALE_VALIDATION' });
    await expect(service.processSale(7, 3, defaultSale({ items: [
      { product_id: 4, quantity: '0.00', unit_price: '1.00' },
    ] }))).rejects.toMatchObject({ code: 'SALE_VALIDATION' });
    await expect(service.processSale(7, 3, defaultSale({ items: [
      { product_id: 4, quantity: '100000000.00', unit_price: '1.00' },
    ] }))).rejects.toMatchObject({ code: 'SALE_VALIDATION' });
    await expect(service.processSale(7, 3, defaultSale({
      payments: [{ amount: '1.00', payment_method: 'credit' }],
    }))).rejects.toMatchObject({ code: 'SALE_VALIDATION' });
    expect(pool.getConnection).not.toHaveBeenCalled();
  });

  test('maps a missing tenant product to not-found and rolls back', async () => {
    connection.execute.mockImplementationOnce(async () => [[], undefined]);
    await expect(service.processSale(7, 3, defaultSale())).rejects.toMatchObject({
      code: 'SALE_RESOURCE_NOT_FOUND', statusCode: 404,
    });
    expect(connection.rollback).toHaveBeenCalledTimes(1);
    expect(connection.commit).not.toHaveBeenCalled();
  });

  test('rolls back when a stock movement cannot be recorded', async () => {
    connection.execute.mockImplementation(async (sql, params) => {
      if (sql.includes('FROM products p') && sql.includes('FOR UPDATE')) {
        return [[{ id: params[0], shop_id: params[1], name: 'Rice', unit: 'kg' }], undefined];
      }
      if (sql.includes('FROM product_batches b') && sql.includes('FOR UPDATE')) {
        return [[{ ...eligibleBatches[3] }], undefined];
      }
      if (sql.includes('UPDATE product_batches b')) return [{ affectedRows: 1 }, undefined];
      if (sql.includes('INSERT INTO stock_transactions')) return [{ affectedRows: 0 }, undefined];
      throw new Error(`Unexpected SQL in stock transaction failure test: ${sql}`);
    });

    await expect(service.processSale(7, 3, defaultSale({
      items: [{ product_id: 4, quantity: '1.00', unit_price: '10.00' }],
      payments: [],
    }))).rejects.toMatchObject({ code: 'SALE_CONFLICT', statusCode: 409 });
    expect(connection.rollback).toHaveBeenCalledTimes(1);
    expect(connection.commit).not.toHaveBeenCalled();
  });

  test('rolls back when a payment cannot update the invoice or cannot be inserted', async () => {
    invoiceRepository.addPaidAmount.mockResolvedValueOnce(false);
    await expect(service.processSale(7, 3, defaultSale())).rejects.toMatchObject({
      code: 'SALE_CONFLICT', message: 'Payment would exceed the invoice amount due',
    });
    expect(paymentRepository.create).not.toHaveBeenCalled();
    expect(connection.rollback).toHaveBeenCalledTimes(1);

    jest.clearAllMocks();
    connection = makeConnection();
    pool.getConnection.mockResolvedValue(connection);
    invoiceRepository.create.mockResolvedValue({ id: 55, invoice_number: 'SW-7-000055' });
    invoiceRepository.createItems.mockResolvedValue(2);
    invoiceRepository.addPaidAmount.mockResolvedValue(true);
    invoiceRepository.findById.mockResolvedValue({ id: 55, shop_id: 7 });
    paymentRepository.create.mockResolvedValueOnce(null);

    await expect(service.processSale(7, 3, defaultSale())).rejects.toMatchObject({
      code: 'SALE_RESOURCE_NOT_FOUND', statusCode: 404,
    });
    expect(connection.rollback).toHaveBeenCalledTimes(1);
    expect(connection.commit).not.toHaveBeenCalled();
  });

  test('rolls back if commit fails and preserves rollback failure details', async () => {
    const commitFailure = new Error('commit failed');
    const rollbackFailure = new Error('rollback failed');
    connection.commit.mockRejectedValueOnce(commitFailure);
    connection.rollback.mockRejectedValueOnce(rollbackFailure);

    await expect(service.processSale(7, 3, defaultSale({ payments: [] }))).rejects.toMatchObject({
      message: 'commit failed', rollbackError: rollbackFailure,
    });
    expect(connection.rollback).toHaveBeenCalledTimes(1);
    expect(connection.release).toHaveBeenCalledTimes(1);
  });
});
