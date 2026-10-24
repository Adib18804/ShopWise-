const fs = require('fs');
const path = require('path');
const db = require('../config/database.js');
const logger = require('../utils/logger.util.js');
const { parseSqlStatements } = require('./migration.util.js');

const MIGRATION_TABLE = 'schema_migrations';

async function runMigrations() {
  let connection;
  try {
    connection = await db.getConnection();
    await connection.query(`
      CREATE TABLE IF NOT EXISTS ${MIGRATION_TABLE} (
        migration_name VARCHAR(255) PRIMARY KEY,
        applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    `);

    const migrationsDir = path.join(__dirname, 'migrations');
    const files = fs.readdirSync(migrationsDir)
      .filter(file => /^(\d+)_.*\.(sql|js)$/.test(file))
      .sort();

    for (const file of files) {
      const [applied] = await connection.execute(
        `SELECT migration_name FROM ${MIGRATION_TABLE} WHERE migration_name = ?`,
        [file],
      );
      if (applied.length) {
        logger.info(`Skipping applied migration: ${file}`);
        continue;
      }

      logger.info(`Running migration: ${file}`);
      if (file.endsWith('.sql')) {
        const sql = fs.readFileSync(path.join(migrationsDir, file), 'utf8');
        const statements = parseSqlStatements(sql);
        if (statements.length === 0) throw new Error(`Migration is empty: ${file}`);
        for (const statement of statements) await connection.query(statement);
      } else {
        const migration = require(path.join(migrationsDir, file));
        if (typeof migration.up !== 'function') {
          throw new Error(`JavaScript migration must export up(connection): ${file}`);
        }
        await migration.up(connection);
      }

      // DDL implicitly commits in MySQL. Record completion only after every
      // statement succeeds, so failures remain retryable and visible.
      await connection.execute(
        `INSERT INTO ${MIGRATION_TABLE} (migration_name) VALUES (?)`,
        [file],
      );
      logger.info(`Completed migration: ${file}`);
    }
    logger.info('All migrations are applied.');
  } finally {
    if (connection) connection.release();
    await db.end();
  }
}

if (require.main === module) {
  runMigrations().catch((error) => {
    logger.error('Migration failed; it was not recorded as applied.', error);
    process.exitCode = 1;
  });
}

module.exports = { runMigrations };
