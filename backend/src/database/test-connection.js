const db = require('../config/database.js');
const logger = require('../utils/logger.util.js');

/**
 * Test database connection
 */
async function testConnection() {
  logger.info('🔌 Testing database connection...');
  
  try {
    const [result] = await db.query('SELECT 1 + 1 AS result');
    logger.info(`✅ Database connection successful! Test query result: ${result[0].result}`);
    
    // Check if tables exist
    const [tables] = await db.query('SHOW TABLES');
    logger.info(`\n📊 Found ${tables.length} tables in database:`);
    tables.forEach((table, index) => {
      const tableName = Object.values(table)[0];
      logger.info(`   ${index + 1}. ${tableName}`);
    });
    
    process.exit(0);
  } catch (error) {
    logger.error('❌ Database connection failed:', error.message);
    logger.error('\n💡 Troubleshooting:');
    logger.error('   1. Check if MySQL server is running');
    logger.error('   2. Verify database credentials in .env file');
    logger.error('   3. Ensure database exists: CREATE DATABASE shopwise_dev;');
    logger.error('   4. Check database user permissions\n');
    process.exit(1);
  }
}

testConnection();
