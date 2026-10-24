async function up(connection) {
  const [rows] = await connection.execute(
    `SELECT COUNT(*) AS count
       FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = 'product_batches'
        AND COLUMN_NAME = 'is_active'`,
  );
  if (Number(rows[0].count) === 0) {
    await connection.query(
      'ALTER TABLE product_batches ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT TRUE AFTER purchase_price',
    );
  }
}

module.exports = { up };
