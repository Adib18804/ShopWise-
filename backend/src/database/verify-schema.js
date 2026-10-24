const db = require('../config/database.js');
const logger = require('../utils/logger.util.js');

const requiredTables = [
  'users', 'shops', 'categories', 'products', 'product_batches', 'sales',
  'sale_items', 'stock_transactions', 'notifications', 'daily_summaries',
  'schema_migrations',
];
const requiredColumns = {
  shops: ['owner_id', 'shop_name', 'deleted_at', 'active_owner_id'],
  categories: ['shop_id', 'name', 'description', 'created_at', 'updated_at', 'deleted_at', 'active_name'],
  products: ['shop_id', 'category_id', 'name', 'sku', 'barcode', 'unit',
    'selling_price', 'default_purchase_price', 'minimum_stock',
    'target_stock_days', 'is_active', 'deleted_at', 'active_sku'],
  product_batches: ['product_id', 'purchase_date', 'expiry_date', 'quantity',
    'purchase_price', 'is_active', 'deleted_at'],
  stock_transactions: ['product_id', 'batch_id', 'transaction_type', 'quantity', 'reference_id'],
};
const requiredUniqueIndexes = {
  shops: { unique_active_shop_per_owner: ['active_owner_id'] },
  categories: { unique_active_category_per_shop: ['shop_id', 'active_name'] },
  products: { unique_active_sku_per_shop: ['shop_id', 'active_sku'] },
};

async function verifySchema() {
  try {
    const [tableRows] = await db.execute(
      `SELECT TABLE_NAME, ENGINE, TABLE_COLLATION FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = DATABASE() ORDER BY TABLE_NAME`,
    );
    const actualTables = new Set(tableRows.map((row) => row.TABLE_NAME));
    const missingTables = requiredTables.filter((name) => !actualTables.has(name));
    if (missingTables.length) throw new Error(`Missing required tables: ${missingTables.join(', ')}`);

    const [columns] = await db.execute(
      `SELECT TABLE_NAME, COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_DEFAULT,
              COLUMN_KEY, EXTRA
         FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() ORDER BY TABLE_NAME, ORDINAL_POSITION`,
    );
    const byTable = new Map();
    columns.forEach((column) => {
      if (!byTable.has(column.TABLE_NAME)) byTable.set(column.TABLE_NAME, new Set());
      byTable.get(column.TABLE_NAME).add(column.COLUMN_NAME);
    });
    Object.entries(requiredColumns).forEach(([table, names]) => {
      const present = byTable.get(table) ?? new Set();
      const missing = names.filter((name) => !present.has(name));
      if (missing.length) throw new Error(`${table} is missing columns: ${missing.join(', ')}`);
    });

    const [indexes] = await db.execute(
      `SELECT TABLE_NAME, INDEX_NAME, NON_UNIQUE, SEQ_IN_INDEX, COLUMN_NAME
         FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE()
        ORDER BY TABLE_NAME, INDEX_NAME, SEQ_IN_INDEX`,
    );
    const expectedIndexes = [];
    Object.entries(requiredUniqueIndexes).forEach(([table, tableIndexes]) => {
      Object.entries(tableIndexes).forEach(([indexName, expectedColumns]) => {
        expectedIndexes.push({ table, indexName, expectedColumns });
      });
    });
    const missingUniqueIndex = expectedIndexes.find(({ table, indexName, expectedColumns }) => {
      const actualColumns = indexes
        .filter((index) => index.TABLE_NAME === table && index.INDEX_NAME === indexName)
        .sort((left, right) => left.SEQ_IN_INDEX - right.SEQ_IN_INDEX);
      return actualColumns.some((index) => Number(index.NON_UNIQUE) !== 0)
        || actualColumns.map((index) => index.COLUMN_NAME).join(',') !== expectedColumns.join(',');
    });
    if (missingUniqueIndex) {
      const { table, indexName, expectedColumns } = missingUniqueIndex;
      throw new Error(`${table} is missing required unique index ${indexName} (${expectedColumns.join(', ')})`);
    }
    const [constraints] = await db.execute(
      `SELECT tc.TABLE_NAME, tc.CONSTRAINT_NAME, tc.CONSTRAINT_TYPE,
              kcu.COLUMN_NAME, kcu.REFERENCED_TABLE_NAME, kcu.REFERENCED_COLUMN_NAME
         FROM information_schema.TABLE_CONSTRAINTS tc
         LEFT JOIN information_schema.KEY_COLUMN_USAGE kcu
           ON kcu.CONSTRAINT_SCHEMA = tc.CONSTRAINT_SCHEMA
          AND kcu.TABLE_NAME = tc.TABLE_NAME
          AND kcu.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
        WHERE tc.CONSTRAINT_SCHEMA = DATABASE()
        ORDER BY tc.TABLE_NAME, tc.CONSTRAINT_NAME, kcu.ORDINAL_POSITION`,
    );
    const [checks] = await db.execute(
      `SELECT tc.TABLE_NAME, tc.CONSTRAINT_NAME, cc.CHECK_CLAUSE
         FROM information_schema.TABLE_CONSTRAINTS tc
         JOIN information_schema.CHECK_CONSTRAINTS cc
           ON cc.CONSTRAINT_SCHEMA = tc.CONSTRAINT_SCHEMA
          AND cc.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
        WHERE tc.CONSTRAINT_SCHEMA = DATABASE() AND tc.CONSTRAINT_TYPE = 'CHECK'
        ORDER BY tc.TABLE_NAME, tc.CONSTRAINT_NAME`,
    );
    const [migrations] = await db.execute(
      'SELECT migration_name, applied_at FROM schema_migrations ORDER BY migration_name',
    );

    logger.info(JSON.stringify({
      database: process.env.DB_NAME || 'configured database',
      tables: tableRows,
      columns,
      indexes,
      constraints,
      checks,
      appliedMigrations: migrations,
    }, null, 2));
    return true;
  } catch (error) {
    logger.error('Database schema verification failed:', error);
    process.exitCode = 1;
    return false;
  } finally {
    await db.end();
  }
}

if (require.main === module) verifySchema();
module.exports = { verifySchema };
