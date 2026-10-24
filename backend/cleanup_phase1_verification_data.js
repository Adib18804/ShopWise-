require('dotenv').config();

const mysql = require('mysql2/promise');
const config = require('./src/config/env');

// Only synthetic Phase 1 verification accounts using the inspected prefixes
// and reserved example.test domain can be selected for deletion.
const TARGET_EMAIL_PATTERNS = [
  'authcheck-%@example.test',
  'fefo-%@example.test',
  'phase1-%@example.test',
  'lock-%@example.test',
  'rollback-%@example.test',
  'softdelete-%@example.test',
  'verify-a-%@example.test',
  'verify-b-%@example.test',
];

const connectionOptions = {
  host: config.database.host,
  port: config.database.port,
  user: config.database.user,
  password: config.database.password,
  database: config.database.name,
  dateStrings: true,
};

const placeholders = (count) => Array(count).fill('?').join(', ');

async function main() {
  if (config.database.name !== 'shopwise_dev') {
    throw new Error(`Refusing cleanup: expected shopwise_dev, got ${config.database.name}`);
  }

  const connection = await mysql.createConnection(connectionOptions);
  try {
    if (process.argv.includes('--inspect')) {
      const [rows] = await connection.execute(
        `SELECT u.id, u.email, s.id AS shop_id, s.deleted_at AS shop_deleted_at
           FROM users u LEFT JOIN shops s ON s.owner_id = u.id
          WHERE u.email LIKE '%@example.test'
          ORDER BY u.email, s.id`,
      );
      process.stdout.write(`${JSON.stringify({ mode: 'inspect', database: config.database.name, rows }, null, 2)}\n`);
      return;
    }

    const [targets] = await connection.execute(
      `SELECT u.id, u.email, s.id AS shop_id, s.deleted_at AS shop_deleted_at
         FROM users u LEFT JOIN shops s ON s.owner_id = u.id
        WHERE (${TARGET_EMAIL_PATTERNS.map(() => 'u.email LIKE ?').join(' OR ')})
        ORDER BY u.id, s.id`,
      TARGET_EMAIL_PATTERNS,
    );
    const userIds = [...new Set(targets.map((row) => row.id))];
    const shops = targets.filter((row) => row.shop_id !== null);

    if (!process.argv.includes('--apply')) {
      process.stdout.write(`${JSON.stringify({
        mode: 'dry-run',
        database: config.database.name,
        emailPatterns: TARGET_EMAIL_PATTERNS,
        matchedUsers: userIds.length,
        matchedShops: shops.length,
        softDeletedShops: shops.filter((row) => row.shop_deleted_at !== null).length,
        activeShops: shops.filter((row) => row.shop_deleted_at === null).length,
        targets,
      }, null, 2)}\n`);
      return;
    }

    await connection.beginTransaction();
    try {
      const deletedShops = [];
      for (const row of shops) {
        const [result] = await connection.execute(
          'DELETE FROM shops WHERE id = ? AND owner_id = ?',
          [row.shop_id, row.id],
        );
        deletedShops.push(result.affectedRows);
      }

      let deletedUsers = 0;
      for (const userId of userIds) {
        const [result] = await connection.execute(
          `DELETE FROM users WHERE id = ? AND (${TARGET_EMAIL_PATTERNS.map(() => 'email LIKE ?').join(' OR ')})`,
          [userId, ...TARGET_EMAIL_PATTERNS],
        );
        deletedUsers += result.affectedRows;
      }

      const [remainingUsers] = await connection.execute(
        `SELECT COUNT(*) AS count FROM users WHERE (${TARGET_EMAIL_PATTERNS.map(() => 'email LIKE ?').join(' OR ')})`,
        TARGET_EMAIL_PATTERNS,
      );
      const shopIds = shops.map((row) => row.shop_id);
      let remainingShopsCount = 0;
      if (shopIds.length) {
        const [remainingShops] = await connection.execute(
          `SELECT COUNT(*) AS count FROM shops WHERE id IN (${placeholders(shopIds.length)})`,
          shopIds,
        );
        remainingShopsCount = Number(remainingShops[0].count);
      }

      if (Number(remainingUsers[0].count) !== 0 || remainingShopsCount !== 0) {
        throw new Error('Cleanup verification failed; matching users or shops remain');
      }

      await connection.commit();
      process.stdout.write(`${JSON.stringify({
        mode: 'applied',
        database: config.database.name,
        emailPatterns: TARGET_EMAIL_PATTERNS,
        matchedUsers: userIds.length,
        matchedShops: shops.length,
        softDeletedShops: shops.filter((row) => row.shop_deleted_at !== null).length,
        activeShops: shops.filter((row) => row.shop_deleted_at === null).length,
        deletedUsers,
        directlyDeletedShops: deletedShops.reduce((total, count) => total + count, 0),
        deletedShops: shops.length - remainingShopsCount,
        cascadedShopDeletes: shops.length - remainingShopsCount
          - deletedShops.reduce((total, count) => total + count, 0),
        remainingUsers: Number(remainingUsers[0].count),
        remainingShops: remainingShopsCount,
      }, null, 2)}\n`);
    } catch (error) {
      await connection.rollback();
      throw error;
    }
  } finally {
    await connection.end();
  }
}

main().catch((error) => {
  process.stderr.write(`Cleanup failed: ${error.message}\n`);
  process.exitCode = 1;
});
