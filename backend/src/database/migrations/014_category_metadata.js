async function columnExists(connection, columnName) {
  const [rows] = await connection.execute(
    `SELECT COUNT(*) AS count
       FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'categories' AND COLUMN_NAME = ?`,
    [columnName],
  );
  return Number(rows[0].count) > 0;
}

async function up(connection) {
  if (!await columnExists(connection, 'description')) {
    await connection.query('ALTER TABLE categories ADD COLUMN description TEXT NULL AFTER name');
  }
  if (!await columnExists(connection, 'updated_at')) {
    await connection.query(
      'ALTER TABLE categories ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER created_at',
    );
  }
}

module.exports = { up };
