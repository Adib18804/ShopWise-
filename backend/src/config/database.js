const mysql = require('mysql2/promise');
const config = require('./env.js');

// Create connection pool
const pool = mysql.createPool({
  host: config.database.host,
  port: config.database.port,
  user: config.database.user,
  password: config.database.password,
  database: config.database.name,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  enableKeepAlive: true,
  keepAliveInitialDelay: 0,
  // Keep DATE columns as YYYY-MM-DD strings to avoid timezone shifts.
  dateStrings: true,
  multipleStatements: false, // Security: prevent SQL injection via multiple statements
});

// Handle pool errors
pool.on('error', (error) => {
  // The caller owns request/migration error handling. Never terminate the
  // entire process from an unobserved pool event.
  process.emitWarning(`Unexpected database pool error: ${error.message}`);
});

module.exports = pool;
