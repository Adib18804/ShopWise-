async function columnExists(connection, column) {
  const [rows] = await connection.execute(
    `SELECT COUNT(*) AS count
       FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'products' AND COLUMN_NAME = ?`,
    [column],
  );
  return Number(rows[0].count) > 0;
}

async function indexExists(connection, indexName) {
  const [rows] = await connection.execute(
    `SELECT COUNT(*) AS count FROM information_schema.STATISTICS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'products' AND INDEX_NAME = ?`,
    [indexName],
  );
  return Number(rows[0].count) > 0;
}

async function checkExists(connection, constraintName) {
  const [rows] = await connection.execute(
    `SELECT COUNT(*) AS count FROM information_schema.TABLE_CONSTRAINTS
      WHERE CONSTRAINT_SCHEMA = DATABASE() AND TABLE_NAME = 'products'
        AND CONSTRAINT_NAME = ? AND CONSTRAINT_TYPE = 'CHECK'`,
    [constraintName],
  );
  return Number(rows[0].count) > 0;
}

async function up(connection) {
  const additions = [
    ['sku', 'VARCHAR(100) NULL'],
    ['barcode', 'VARCHAR(100) NULL'],
    ['selling_price', 'DECIMAL(10,2) NOT NULL DEFAULT 0'],
    ['default_purchase_price', 'DECIMAL(10,2) NOT NULL DEFAULT 0'],
    ['target_stock_days', 'INT NOT NULL DEFAULT 7'],
    ['is_active', 'BOOLEAN NOT NULL DEFAULT TRUE'],
  ];

  // Keep this column nullable until legacy values have been copied. If an
  // earlier attempt added the column but failed during the copy, NULL values
  // let a retry distinguish rows that still need migration from canonical
  // minimum_stock values that should be preserved.
  if (!await columnExists(connection, 'minimum_stock')) {
    await connection.query(
      'ALTER TABLE products ADD COLUMN minimum_stock DECIMAL(10,2) NULL DEFAULT NULL',
    );
  }
  if (await columnExists(connection, 'reorder_level')) {
    await connection.query(
      'UPDATE products SET minimum_stock = reorder_level WHERE minimum_stock IS NULL AND reorder_level IS NOT NULL',
    );
  }
  await connection.query('UPDATE products SET minimum_stock = 0 WHERE minimum_stock IS NULL');
  await connection.query(
    'ALTER TABLE products MODIFY COLUMN minimum_stock DECIMAL(10,2) NOT NULL DEFAULT 0',
  );

  for (const [column, definition] of additions) {
    const existed = await columnExists(connection, column);
    if (!existed) {
      await connection.query(`ALTER TABLE products ADD COLUMN ${column} ${definition}`);
    }
  }

  if (!await indexExists(connection, 'unique_sku_per_shop')) {
    await connection.query('CREATE UNIQUE INDEX unique_sku_per_shop ON products (shop_id, sku)');
  }
  const checks = [
    ['chk_selling_price', 'selling_price >= 0'],
    ['chk_purchase_price', 'default_purchase_price >= 0'],
    ['chk_minimum_stock', 'minimum_stock >= 0'],
    ['chk_target_stock_days', 'target_stock_days >= 1'],
  ];
  for (const [name, expression] of checks) {
    if (!await checkExists(connection, name)) {
      await connection.query(`ALTER TABLE products ADD CONSTRAINT ${name} CHECK (${expression})`);
    }
  }
}

module.exports = { up };
