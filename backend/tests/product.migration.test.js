const { up } = require('../src/database/migrations/011_reconcile_product_contract');

function createConnection({ minimumStockExists = false, minimumStock = null } = {}) {
  const columns = new Set([
    'reorder_level', 'sku', 'barcode', 'selling_price',
    'default_purchase_price', 'target_stock_days', 'is_active',
  ]);
  if (minimumStockExists) columns.add('minimum_stock');

  const state = { columns, minimumStock, reorderLevel: 5, failLegacyCopy: false };
  const connection = {
    state,
    execute: jest.fn(async (_sql, params) => {
      const column = params[0];
      const exists = column === 'unique_sku_per_shop'
        ? true
        : column.startsWith('chk_') ? true : columns.has(column);
      return [[{ count: exists ? 1 : 0 }]];
    }),
    query: jest.fn(async (sql) => {
      if (sql.includes('ADD COLUMN minimum_stock')) columns.add('minimum_stock');
      if (sql.includes('SET minimum_stock = reorder_level')) {
        if (state.failLegacyCopy) {
          state.failLegacyCopy = false;
          throw new Error('simulated copy failure');
        }
        if (state.minimumStock == null) state.minimumStock = state.reorderLevel;
      }
      if (sql.includes('SET minimum_stock = 0')) {
        if (state.minimumStock == null) state.minimumStock = 0;
      }
      return [{ affectedRows: 1 }];
    }),
  };
  return connection;
}

describe('product contract migration', () => {
  test('retry copies legacy values after a failure following column creation', async () => {
    const connection = createConnection();
    connection.state.failLegacyCopy = true;

    await expect(up(connection)).rejects.toThrow('simulated copy failure');
    expect(connection.state.columns.has('minimum_stock')).toBe(true);
    expect(connection.state.minimumStock).toBeNull();

    await up(connection);
    expect(connection.state.minimumStock).toBe(5);
  });

  test('does not overwrite an existing canonical minimum_stock value', async () => {
    const connection = createConnection({ minimumStockExists: true, minimumStock: 8 });

    await up(connection);
    expect(connection.state.minimumStock).toBe(8);
  });
});
