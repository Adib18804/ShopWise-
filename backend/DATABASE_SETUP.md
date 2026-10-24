# ShopWise Database Setup Guide

This guide will help you set up the MySQL database for ShopWise backend.

## Prerequisites

- MySQL 8.0+ installed and running
- Node.js 18+ installed
- Backend dependencies installed (`npm install`)

## Quick Start

### 1. Install MySQL (if not already installed)

**Windows:**
- Download MySQL Installer from https://dev.mysql.com/downloads/installer/
- Run installer and select "MySQL Server"
- Set root password during installation

**macOS:**
```bash
brew install mysql
brew services start mysql
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt update
sudo apt install mysql-server
sudo systemctl start mysql
```

### 2. Create Database and User

Open MySQL command line:
```bash
mysql -u root -p
```

Run the following commands:
```sql
-- Create database
CREATE DATABASE shopwise_dev CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Create user (change password!)
CREATE USER 'shopwise_user'@'localhost' IDENTIFIED BY 'your_secure_password';

-- Grant privileges
GRANT ALL PRIVILEGES ON shopwise_dev.* TO 'shopwise_user'@'localhost';

-- Apply changes
FLUSH PRIVILEGES;

-- Verify
SHOW DATABASES;

-- Exit
EXIT;
```

### 3. Configure Environment Variables

Copy `.env.example` to `.env`:
```bash
cp .env.example .env
```

Update database credentials in `.env`:
```env
DB_HOST=localhost
DB_PORT=3306
DB_NAME=shopwise_dev
DB_USER=shopwise_user
DB_PASSWORD=your_secure_password
```

### 4. Test Database Connection

```bash
node src/database/test-connection.js
```

Expected output:
```
✅ Database connection successful! Test query result: 2
📊 Found 0 tables in database:
```

### 5. Run Migrations

This will create all database tables:
```bash
npm run migrate
```

Expected output:
```
🔧 Starting database migrations...
Found 10 migration files
Running migration: 001_create_users_table.sql
✅ 001_create_users_table.sql completed
Running migration: 002_create_shops_table.sql
✅ 002_create_shops_table.sql completed
...
✅ All migrations completed successfully
```

### 6. Load Seed Data (Optional - for development)

```bash
npm run seed
```

This will load test data including:
- Test user: `rahim@test.com` / `Test@123`
- Sample shop: "Rahim Grocery Store"
- 12 products across 5 categories
- Multiple batches with various expiry dates
- 15 sales transactions
- Stock transaction history

Expected output:
```
🌱 Starting database seeding...
✅ Seed data loaded successfully

📊 Seed Data Summary:
   Users: 1
   Shops: 1
   Products: 12
   Batches: 13
   Sales: 15

📝 Test Credentials:
   Email: rahim@test.com
   Password: Test@123
   Phone: 01712345678
```

## Verify Setup

Test the connection again to see all tables:
```bash
node src/database/test-connection.js
```

You should see 10 tables:
1. users
2. shops
3. categories
4. products
5. product_batches
6. sales
7. sale_items
8. stock_transactions
9. notifications
10. daily_summaries

## Database Schema

### Tables Overview

| Table | Purpose | Records (Seed) |
|-------|---------|----------------|
| users | User accounts | 1 |
| shops | Shop information | 1 |
| categories | Product categories | 5 |
| products | Product master data | 12 |
| product_batches | Batch inventory tracking | 13 |
| sales | Sale transaction headers | 15 |
| sale_items | Sale transaction details | ~40 |
| stock_transactions | Stock movement audit trail | ~10 |
| notifications | In-app notifications | 3 |
| daily_summaries | Pre-calculated summaries | 1 |

### Key Relationships

```
users (1) ──→ (1) shops
shops (1) ──→ (*) categories
shops (1) ──→ (*) products
categories (1) ──→ (*) products
products (1) ──→ (*) product_batches
products (1) ──→ (*) stock_transactions
shops (1) ──→ (*) sales
sales (1) ──→ (*) sale_items
products (1) ──→ (*) sale_items
product_batches (1) ──→ (*) sale_items
users (1) ──→ (*) notifications
shops (1) ──→ (*) daily_summaries
```

## Useful Database Commands

### View all data

```bash
mysql -u shopwise_user -p shopwise_dev
```

```sql
-- View users
SELECT * FROM users;

-- View products with current stock
SELECT 
    p.name,
    COALESCE(SUM(pb.quantity), 0) as current_stock,
    p.selling_price
FROM products p
LEFT JOIN product_batches pb ON p.id = pb.product_id
GROUP BY p.id, p.name, p.selling_price;

-- View sales summary
SELECT 
    DATE(sale_date) as date,
    COUNT(*) as transactions,
    SUM(total_amount) as total_sales
FROM sales
GROUP BY DATE(sale_date)
ORDER BY date DESC;

-- View expiry risk
SELECT 
    p.name,
    pb.batch_number,
    pb.expiry_date,
    pb.quantity,
    DATEDIFF(pb.expiry_date, CURDATE()) as days_until_expiry
FROM product_batches pb
JOIN products p ON pb.product_id = p.id
WHERE pb.expiry_date IS NOT NULL
  AND pb.quantity > 0
  AND pb.expiry_date <= DATE_ADD(CURDATE(), INTERVAL 14 DAY)
ORDER BY pb.expiry_date ASC;
```

### Reset database

⚠️ **Warning:** This will delete all data!

```sql
-- Drop all tables
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS daily_summaries;
DROP TABLE IF EXISTS notifications;
DROP TABLE IF EXISTS stock_transactions;
DROP TABLE IF EXISTS sale_items;
DROP TABLE IF EXISTS sales;
DROP TABLE IF EXISTS product_batches;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS shops;
DROP TABLE IF EXISTS users;
SET FOREIGN_KEY_CHECKS = 1;
```

Then run migrations and seeds again:
```bash
npm run migrate
npm run seed
```

## Troubleshooting

### Connection refused

**Problem:** `Error: connect ECONNREFUSED 127.0.0.1:3306`

**Solution:**
- Check if MySQL is running: `sudo systemctl status mysql` (Linux) or check Services (Windows)
- Start MySQL: `sudo systemctl start mysql` (Linux) or start service (Windows)

### Access denied

**Problem:** `Error: Access denied for user 'shopwise_user'@'localhost'`

**Solution:**
- Verify credentials in `.env` file
- Check user exists: `SELECT User, Host FROM mysql.user;`
- Recreate user with proper privileges (see step 2)

### Database doesn't exist

**Problem:** `Error: Unknown database 'shopwise_dev'`

**Solution:**
```bash
mysql -u root -p
CREATE DATABASE shopwise_dev CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

### Foreign key constraint fails

**Problem:** During migration or seed

**Solution:**
- Drop all tables and re-run migrations
- Check migration file order (001, 002, etc.)
- Ensure migrations run in correct sequence

### Duplicate entry error

**Problem:** When running seed multiple times

**Solution:**
The seed file includes `TRUNCATE` commands to clear existing data. If you still get errors:
```bash
mysql -u shopwise_user -p shopwise_dev
SET FOREIGN_KEY_CHECKS = 0;
-- Truncate each table manually
TRUNCATE TABLE users;
-- ... other tables
SET FOREIGN_KEY_CHECKS = 1;
```

## Production Setup

For production environment:

1. **Create production database:**
```sql
CREATE DATABASE shopwise_prod CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

2. **Create production user with strong password:**
```sql
CREATE USER 'shopwise_prod'@'localhost' IDENTIFIED BY 'very_strong_random_password';
GRANT ALL PRIVILEGES ON shopwise_prod.* TO 'shopwise_prod'@'localhost';
FLUSH PRIVILEGES;
```

3. **Update production `.env`:**
```env
NODE_ENV=production
DB_NAME=shopwise_prod
DB_USER=shopwise_prod
DB_PASSWORD=very_strong_random_password
```

4. **Run migrations only (NO seed data):**
```bash
NODE_ENV=production npm run migrate
```

5. **Set up automated backups:**
```bash
# Daily backup cron job
0 2 * * * mysqldump -u shopwise_prod -p'password' shopwise_prod > /backups/shopwise_$(date +\%Y\%m\%d).sql
```

## Database Performance

### Indexes

All critical indexes are created by migrations:
- Foreign keys automatically indexed
- Compound indexes on frequently queried fields
- Date indexes for time-based queries

### Query Optimization

- Use `EXPLAIN` to analyze slow queries
- Add indexes for custom queries if needed
- Consider connection pooling (already configured)

### Monitoring

Monitor database performance:
```sql
-- Show processlist
SHOW PROCESSLIST;

-- Show table sizes
SELECT 
    table_name,
    ROUND(((data_length + index_length) / 1024 / 1024), 2) AS "Size (MB)"
FROM information_schema.TABLES
WHERE table_schema = 'shopwise_dev'
ORDER BY (data_length + index_length) DESC;
```

## Support

For more information:
- `/DATABASE.md` - Complete database design documentation
- `/ARCHITECTURE.md` - System architecture
- `/API.md` - API endpoints

## Next Steps

After database setup:
1. ✅ Database created and migrated
2. ✅ Seed data loaded (optional)
3. ⏭️ Start backend server: `npm run dev`
4. ⏭️ Test API endpoints
5. ⏭️ Connect Flutter frontend
