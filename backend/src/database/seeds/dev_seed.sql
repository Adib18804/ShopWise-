-- Development Seed Data for ShopWise
-- This file provides realistic test data for development and testing

-- Clear existing data (in reverse order of foreign keys)
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE daily_summaries;
TRUNCATE TABLE notifications;
TRUNCATE TABLE stock_transactions;
TRUNCATE TABLE sale_items;
TRUNCATE TABLE sales;
TRUNCATE TABLE product_batches;
TRUNCATE TABLE products;
TRUNCATE TABLE categories;
TRUNCATE TABLE shops;
TRUNCATE TABLE users;
SET FOREIGN_KEY_CHECKS = 1;

-- Insert test user
-- Password: Test@123 (hashed with bcrypt, salt rounds: 10)
INSERT INTO users (id, name, phone, email, password_hash, preferred_language) VALUES
(1, 'Rahim Khan', '01712345678', 'rahim@test.com', '$2b$10$rZ5zqE5pKX9Z5nE9nE9nEOqX9Z5nE9nE9nE9nE9nE9nE9nE9nE9nE', 'bn');

-- Insert shop
INSERT INTO shops (id, owner_id, shop_name, address, phone, currency) VALUES
(1, 1, 'Rahim Grocery Store', '123 Main Street, Mirpur, Dhaka-1216', '01712345678', 'BDT');

-- Insert categories
INSERT INTO categories (id, shop_id, name) VALUES
(1, 1, 'Dairy Products'),
(2, 1, 'Beverages'),
(3, 1, 'Snacks'),
(4, 1, 'Cooking Essentials'),
(5, 1, 'Personal Care');

-- Insert products
INSERT INTO products (id, shop_id, category_id, name, sku, unit, selling_price, default_purchase_price, minimum_stock, target_stock_days, is_active) VALUES
-- Dairy Products
(1, 1, 1, 'Fresh Milk 1L', 'MILK-001', 'piece', 85.00, 70.00, 10, 7, TRUE),
(2, 1, 1, 'Yogurt 500ml', 'YOGURT-001', 'piece', 60.00, 45.00, 15, 7, TRUE),

-- Beverages
(3, 1, 2, 'Soft Drink 500ml', 'SOFT-001', 'piece', 35.00, 28.00, 20, 7, TRUE),
(4, 1, 2, 'Mineral Water 1L', 'WATER-001', 'piece', 20.00, 15.00, 30, 7, TRUE),

-- Snacks
(5, 1, 3, 'Biscuits 200g', 'BISCUIT-001', 'packet', 45.00, 35.00, 25, 7, TRUE),
(6, 1, 3, 'Chips 50g', 'CHIPS-001', 'packet', 20.00, 15.00, 40, 7, TRUE),
(7, 1, 3, 'Noodles 300g', 'NOODLES-001', 'packet', 30.00, 22.00, 20, 7, TRUE),

-- Cooking Essentials
(8, 1, 4, 'Rice 1kg', 'RICE-001', 'kg', 60.00, 50.00, 50, 14, TRUE),
(9, 1, 4, 'Cooking Oil 1L', 'OIL-001', 'piece', 180.00, 160.00, 10, 7, TRUE),
(10, 1, 4, 'Salt 1kg', 'SALT-001', 'kg', 35.00, 28.00, 15, 14, TRUE),

-- Personal Care
(11, 1, 5, 'Soap Bar', 'SOAP-001', 'piece', 45.00, 35.00, 20, 7, TRUE),
(12, 1, 5, 'Toothpaste', 'TOOTH-001', 'piece', 85.00, 70.00, 15, 7, TRUE);

-- Insert product batches (with various expiry scenarios)
INSERT INTO product_batches (product_id, batch_number, purchase_date, expiry_date, quantity, purchase_price) VALUES
-- Milk - Critical expiry risk (5 days)
(1, 'BATCH-M001', '2026-10-10', '2026-10-20', 10, 70.00),
-- Milk - Medium expiry risk (12 days)
(1, 'BATCH-M002', '2026-10-12', '2026-10-27', 15, 70.00),

-- Yogurt - High expiry risk (8 days)
(2, 'BATCH-Y001', '2026-10-08', '2026-10-23', 12, 45.00),
-- Yogurt - Normal
(2, 'BATCH-Y002', '2026-10-14', '2026-11-14', 18, 45.00),

-- Soft Drink - Normal (45 days)
(3, 'BATCH-S001', '2026-09-01', '2026-11-30', 25, 28.00),

-- Water - Normal (90 days)
(4, 'BATCH-W001', '2026-09-15', '2027-01-15', 35, 15.00),

-- Biscuits - Medium expiry risk (20 days)
(5, 'BATCH-B001', '2026-09-25', '2026-11-05', 30, 35.00),

-- Chips - Normal (60 days)
(6, 'BATCH-C001', '2026-09-20', '2026-12-20', 45, 15.00),

-- Noodles - Very slow moving (30 days, no recent sales)
(7, 'BATCH-N001', '2026-08-15', '2027-02-15', 25, 22.00),

-- Rice - Dead stock (no recent sales, 50 units)
(8, 'BATCH-R001', '2026-07-01', NULL, 50, 50.00),

-- Cooking Oil - Low stock
(9, 'BATCH-O001', '2026-10-01', '2027-04-01', 8, 160.00),

-- Salt - No expiry, good stock
(10, 'BATCH-SA001', '2026-09-01', NULL, 20, 28.00),

-- Soap - Normal
(11, 'BATCH-SO001', '2026-09-10', '2027-09-10', 25, 35.00),

-- Toothpaste - Normal
(12, 'BATCH-T001', '2026-09-15', '2028-09-15', 18, 70.00);

-- Insert sales (last 30 days with varying patterns)
-- Recent sales (last 7 days)
INSERT INTO sales (id, shop_id, total_amount, sale_date) VALUES
-- Today
(1, 1, 425.00, '2026-10-15'),
(2, 1, 180.00, '2026-10-15'),
-- Yesterday
(3, 1, 350.00, '2026-10-14'),
(4, 1, 520.00, '2026-10-14'),
-- 2 days ago
(5, 1, 290.00, '2026-10-13'),
-- 3 days ago
(6, 1, 410.00, '2026-10-12'),
-- 4 days ago
(7, 1, 385.00, '2026-10-11'),
-- 5 days ago
(8, 1, 465.00, '2026-10-10'),
-- 6 days ago
(9, 1, 330.00, '2026-10-09'),
-- Older sales (8-30 days ago) with less frequency
(10, 1, 395.00, '2026-10-08'),
(11, 1, 420.00, '2026-10-06'),
(12, 1, 310.00, '2026-10-04'),
(13, 1, 380.00, '2026-10-02'),
(14, 1, 445.00, '2026-09-30'),
(15, 1, 360.00, '2026-09-28');

-- Insert sale items (showing product sales patterns)
INSERT INTO sale_items (sale_id, product_id, batch_id, quantity, selling_price, purchase_price, subtotal) VALUES
-- Sale 1 (Today) - Milk selling fast
(1, 1, 1, 5, 85.00, 70.00, 425.00),

-- Sale 2 (Today) - Mixed items
(2, 5, 5, 2, 45.00, 35.00, 90.00),
(2, 6, 6, 3, 20.00, 15.00, 60.00),
(2, 4, 4, 1, 20.00, 15.00, 20.00),

-- Sale 3 (Yesterday) - Oil and milk
(3, 9, 9, 1, 180.00, 160.00, 180.00),
(3, 1, 1, 2, 85.00, 70.00, 170.00),

-- Sale 4 (Yesterday) - Multiple items
(4, 1, 1, 3, 85.00, 70.00, 255.00),
(4, 2, 1, 2, 60.00, 45.00, 120.00),
(4, 5, 5, 2, 45.00, 35.00, 90.00),
(4, 11, 11, 1, 45.00, 35.00, 45.00),

-- Sale 5 (2 days ago)
(5, 1, 1, 2, 85.00, 70.00, 170.00),
(5, 3, 3, 2, 35.00, 28.00, 70.00),
(5, 4, 4, 2, 20.00, 15.00, 40.00),

-- Sale 6 (3 days ago)
(6, 1, 2, 4, 85.00, 70.00, 340.00),
(6, 12, 12, 1, 85.00, 70.00, 70.00),

-- Sale 7 (4 days ago)
(7, 1, 2, 3, 85.00, 70.00, 255.00),
(7, 5, 5, 2, 45.00, 35.00, 90.00),
(7, 6, 6, 2, 20.00, 15.00, 40.00),

-- Sale 8 (5 days ago)
(8, 1, 2, 4, 85.00, 70.00, 340.00),
(8, 9, 9, 1, 180.00, 160.00, 180.00),

-- Sale 9 (6 days ago)
(9, 2, 1, 3, 60.00, 45.00, 180.00),
(9, 5, 5, 2, 45.00, 35.00, 90.00),
(9, 6, 6, 3, 20.00, 15.00, 60.00),

-- Sale 10-15 (Older sales) - Less frequent, mixed items
(10, 1, 2, 3, 85.00, 70.00, 255.00),
(10, 3, 3, 2, 35.00, 28.00, 70.00),
(10, 4, 4, 3, 20.00, 15.00, 60.00),

(11, 1, 2, 4, 85.00, 70.00, 340.00),
(11, 6, 6, 4, 20.00, 15.00, 80.00),

(12, 5, 5, 3, 45.00, 35.00, 135.00),
(12, 2, 2, 2, 60.00, 45.00, 120.00),
(12, 11, 11, 1, 45.00, 35.00, 45.00),

(13, 1, 2, 3, 85.00, 70.00, 255.00),
(13, 9, 9, 1, 180.00, 160.00, 180.00),

(14, 1, 2, 4, 85.00, 70.00, 340.00),
(14, 5, 5, 1, 45.00, 35.00, 45.00),
(14, 6, 6, 3, 20.00, 15.00, 60.00),

(15, 2, 2, 3, 60.00, 45.00, 180.00),
(15, 3, 3, 3, 35.00, 28.00, 105.00),
(15, 4, 4, 3, 20.00, 15.00, 60.00);

-- Insert stock transactions (history of stock movements)
INSERT INTO stock_transactions (product_id, batch_id, transaction_type, quantity, reference_id, notes) VALUES
-- Purchase transactions (when batches were added)
(1, 1, 'PURCHASE', 25, NULL, 'Initial stock - Batch M001'),
(1, 2, 'PURCHASE', 30, NULL, 'Restocking - Batch M002'),
(2, 1, 'PURCHASE', 20, NULL, 'Initial stock - Batch Y001'),
(2, 2, 'PURCHASE', 25, NULL, 'Restocking - Batch Y002'),
(5, 5, 'PURCHASE', 50, NULL, 'Initial stock - Batch B001'),
(9, 9, 'PURCHASE', 15, NULL, 'Initial stock - Batch O001'),

-- Sale transactions (from recent sales)
(1, 1, 'SALE', -5, 1, 'Sale transaction'),
(1, 1, 'SALE', -2, 3, 'Sale transaction'),
(1, 1, 'SALE', -3, 4, 'Sale transaction'),
(1, 1, 'SALE', -2, 5, 'Sale transaction'),
(1, 2, 'SALE', -4, 6, 'Sale transaction'),
(9, 9, 'SALE', -1, 3, 'Sale transaction'),
(9, 9, 'SALE', -1, 8, 'Sale transaction');

-- Sample notifications (will be generated dynamically by the system)
INSERT INTO notifications (user_id, type, title, message, severity, reference_type, reference_id, is_read) VALUES
(1, 'EXPIRY_RISK', 'Critical Expiry Alert', 'Fresh Milk 1L (BATCH-M001) expires in 5 days', 'CRITICAL', 'BATCH', 1, FALSE),
(1, 'STOCK_OUT', 'Low Stock Alert', 'Cooking Oil 1L may run out within 3 days', 'WARNING', 'PRODUCT', 9, FALSE),
(1, 'SLOW_MOVING', 'Slow-Moving Product', 'Rice 1kg has had no sales for 30 days', 'INFO', 'PRODUCT', 8, FALSE);

-- Sample daily summary (will be generated dynamically)
INSERT INTO daily_summaries (shop_id, summary_date, summary_text, low_stock_count, expiry_risk_count, expiry_risk_value, sales_amount, estimated_profit) VALUES
(1, '2026-10-15', 'আজ ১টি পণ্যের স্টক কম। ৩টি পণ্য শীঘ্রই মেয়াদ শেষ হবে। আনুমানিক মেয়াদ ঝুঁকির মূল্য: ৳১,৮৫০। আজকের বিক্রয়: ৳৬০৫। আনুমানিক লাভ: ৳১০৫।', 1, 3, 1850.00, 605.00, 105.00);

-- Verify data
SELECT 'Seed data loaded successfully!' as status;
SELECT COUNT(*) as user_count FROM users;
SELECT COUNT(*) as shop_count FROM shops;
SELECT COUNT(*) as category_count FROM categories;
SELECT COUNT(*) as product_count FROM products;
SELECT COUNT(*) as batch_count FROM product_batches;
SELECT COUNT(*) as sale_count FROM sales;
SELECT COUNT(*) as sale_item_count FROM sale_items;
SELECT COUNT(*) as notification_count FROM notifications;
