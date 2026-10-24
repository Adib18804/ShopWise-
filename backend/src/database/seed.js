const fs = require('fs');
const path = require('path');
const db = require('../config/database.js');
const logger = require('../utils/logger.util.js');

/**
 * Run database seed data
 */
async function runSeeds() {
  logger.info('🌱 Starting database seeding...');
  
  try {
    const seedFile = path.join(__dirname, 'seeds', 'dev_seed.sql');
    
    if (!fs.existsSync(seedFile)) {
      logger.error('Seed file not found');
      process.exit(1);
    }
    
    logger.info('Loading seed data from dev_seed.sql');
    
    const sql = fs.readFileSync(seedFile, 'utf8');
    
    // Split SQL statements by semicolon
    const statements = sql
      .split(';')
      .map(stmt => stmt.trim())
      .filter(stmt => stmt.length > 0 && !stmt.startsWith('--'));
    
    for (const statement of statements) {
      if (statement) {
        await db.query(statement);
      }
    }
    
    logger.info('✅ Seed data loaded successfully');
    
    // Display summary
    const [users] = await db.query('SELECT COUNT(*) as count FROM users');
    const [shops] = await db.query('SELECT COUNT(*) as count FROM shops');
    const [products] = await db.query('SELECT COUNT(*) as count FROM products');
    const [batches] = await db.query('SELECT COUNT(*) as count FROM product_batches');
    const [sales] = await db.query('SELECT COUNT(*) as count FROM sales');
    
    logger.info('\n📊 Seed Data Summary:');
    logger.info(`   Users: ${users[0].count}`);
    logger.info(`   Shops: ${shops[0].count}`);
    logger.info(`   Products: ${products[0].count}`);
    logger.info(`   Batches: ${batches[0].count}`);
    logger.info(`   Sales: ${sales[0].count}`);
    logger.info('\n📝 Test Credentials:');
    logger.info('   Email: rahim@test.com');
    logger.info('   Password: Test@123');
    logger.info('   Phone: 01712345678\n');
    
    process.exit(0);
  } catch (error) {
    logger.error('❌ Seeding failed:', error);
    process.exit(1);
  }
}

// Run seeds
runSeeds();
