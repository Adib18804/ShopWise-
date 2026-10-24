async function columnExists(connection, tableName, columnName) {
  const [rows] = await connection.execute(
    `SELECT COUNT(*) AS count FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?`,
    [tableName, columnName],
  );
  return Number(rows[0].count) > 0;
}

async function indexExists(connection, tableName, indexName) {
  const [rows] = await connection.execute(
    `SELECT COUNT(*) AS count FROM information_schema.STATISTICS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND INDEX_NAME = ?`,
    [tableName, indexName],
  );
  return Number(rows[0].count) > 0;
}

async function addDeletedAt(connection, tableName) {
  if (!await columnExists(connection, tableName, 'deleted_at')) {
    await connection.query(
      `ALTER TABLE ${tableName} ADD COLUMN deleted_at TIMESTAMP NULL DEFAULT NULL`,
    );
  }
}

async function replaceUniqueIndex(connection, tableName, oldIndex, generatedColumn, definition, newIndex, keyColumn) {
  if (!await columnExists(connection, tableName, generatedColumn)) {
    await connection.query(
      `ALTER TABLE ${tableName} ADD COLUMN ${generatedColumn} ${definition}`,
    );
  }
  if (await indexExists(connection, tableName, oldIndex)) {
    await connection.query(`ALTER TABLE ${tableName} DROP INDEX ${oldIndex}`);
  }
  if (!await indexExists(connection, tableName, newIndex)) {
    await connection.query(`CREATE UNIQUE INDEX ${newIndex} ON ${tableName} (shop_id, ${keyColumn})`);
  }
}

async function up(connection) {
  await addDeletedAt(connection, 'shops');
  await addDeletedAt(connection, 'categories');
  await addDeletedAt(connection, 'products');
  await addDeletedAt(connection, 'product_batches');

  if (!await columnExists(connection, 'shops', 'active_owner_id')) {
    await connection.query('ALTER TABLE shops ADD COLUMN active_owner_id INT NULL');
  }
  await connection.query(
    'UPDATE shops SET active_owner_id = CASE WHEN deleted_at IS NULL THEN owner_id ELSE NULL END',
  );
  if (await indexExists(connection, 'shops', 'owner_id')) {
    await connection.query('ALTER TABLE shops DROP INDEX owner_id');
  }
  if (!await indexExists(connection, 'shops', 'unique_active_shop_per_owner')) {
    await connection.query('CREATE UNIQUE INDEX unique_active_shop_per_owner ON shops (active_owner_id)');
  }

  if (!await columnExists(connection, 'categories', 'active_name')) {
    await connection.query('ALTER TABLE categories ADD COLUMN active_name VARCHAR(100) NULL');
  }
  await connection.query(
    'UPDATE categories SET active_name = CASE WHEN deleted_at IS NULL THEN name ELSE NULL END',
  );
  await replaceUniqueIndex(
    connection,
    'categories',
    'unique_category_per_shop',
    'active_name',
    'VARCHAR(100) NULL',
    'unique_active_category_per_shop',
    'active_name',
  );

  if (!await columnExists(connection, 'products', 'active_sku')) {
    await connection.query('ALTER TABLE products ADD COLUMN active_sku VARCHAR(100) NULL');
  }
  await connection.query(
    'UPDATE products SET active_sku = CASE WHEN deleted_at IS NULL AND is_active = TRUE THEN sku ELSE NULL END',
  );
  await replaceUniqueIndex(
    connection,
    'products',
    'unique_sku_per_shop',
    'active_sku',
    'VARCHAR(100) NULL',
    'unique_active_sku_per_shop',
    'active_sku',
  );
}

module.exports = { up };
