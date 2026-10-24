# ShopWise - Database Design

## Overview

ShopWise uses **MySQL 8.0+** with a normalized relational database design optimized for small grocery shop data management and analysis.

**Key Principles:**
- Normalized to 3NF (Third Normal Form)
- Strong data ownership isolation (shop-level)
- Proper foreign key constraints
- Strategic indexing for performance
- Audit trails with timestamps
- Support for multi-batch inventory tracking

---

## Entity Relationship Diagram (ERD)

```
┌─────────────────┐
│     users       │
│─────────────────│
│ PK id           │
│    name         │
│    phone        │
│    email        │◄─────┐
│    password_hash│      │
│    preferred_   │      │
│      language   │      │
│    created_at   │      │
│    updated_at   │      │
└─────────────────┘      │
                         │ FK owner_id
                         │
                  ┌──────┴──────────┐
                  │     shops       │
                  │─────────────────│
                  │ PK id           │
                  │ FK owner_id     │
                  │    shop_name    │
                  │    address      │
                  │    phone        │
                  │    currency     │
                  │    created_at   │
                  │    updated_at   │
                  └──────┬──────────┘
                         │
         ┌───────────────┼───────────────┬────────────────┐
         │               │               │                │
         │ FK shop_id    │ FK shop_id    │ FK shop_id     │ FK shop_id
         ↓               ↓               ↓                ↓
┌─────────────────┐ ┌─────────────┐ ┌──────────────┐ ┌────────────────┐
│   categories    │ │  products   │ │    sales     │ │ notifications  │
│─────────────────│ │─────────────│ │──────────────│ │────────────────│
│ PK id           │ │ PK id       │ │ PK id        │ │ PK id          │
│ FK shop_id      │ │ FK shop_id  │ │ FK shop_id   │ │ FK user_id     │
│    name         │ │ FK category │ │    total_amt │ │    type        │
│    created_at   │ │    name     │ │    sale_date │ │    title       │
└─────────────────┘ │    sku      │ │    created_at│ │    message     │
         ▲          │    barcode  │ └──────┬───────┘ │    severity    │
         │          │    unit     │        │         │    reference_  │
         │          │    selling_ │        │         │      type      │
         │          │      price  │        │         │    reference_id│
         │ FK       │    default_ │        │         │    is_read     │
         │ category │      purchase│       │         │    created_at  │
         │   _id    │      _price │        │         └────────────────┘
         │          │    minimum_ │        │
         │          │      stock  │        │ FK sale_id
         │          │    target_  │        ↓
         │          │      stock_ │ ┌──────────────┐
         │          │      days   │ │  sale_items  │
         │          │    is_active│ │──────────────│
         │          │    created_ │ │ PK id        │
         │          │      at     │ │ FK sale_id   │
         │          │    updated_ │ │ FK product_id│
         │          │      at     │ │ FK batch_id  │
         │          └─────┬───────┘ │    quantity  │
         │                │         │    selling_  │
         │                │         │      price   │
         │                │         │    purchase_ │
         │                │ FK      │      price   │
         │                │ product │    subtotal  │
         │                │  _id    └──────────────┘
         │                │
         │                ├──────────────────┐
         │                ↓                  ↓
         │         ┌──────────────┐   ┌─────────────────┐
         │         │product_batch │   │stock_transact.. │
         │         │──────────────│   │─────────────────│
         │         │ PK id        │   │ PK id           │
         │         │ FK product_id│   │ FK product_id   │
         │         │    batch_num │   │ FK batch_id     │
         │         │    purchase_ │   │    transaction_ │
         │         │      date    │   │      type       │
         │         │    expiry_   │   │    quantity     │
         │         │      date    │   │    reference_id │
         │         │    quantity  │   │    notes        │
         │         │    purchase_ │   │    created_at   │
         │         │      price   │   └─────────────────┘
         │         │    created_at│
         │         │    updated_at│
         │         └──────────────┘
         │
         │ FK shop_id
         ↓
┌──────────────────┐
│ daily_summaries  │
│──────────────────│
│ PK id            │
│ FK shop_id       │
│    summary_date  │
│    summary_text  │
│    low_stock_cnt │
│    expiry_risk_  │
│      count       │
│    expiry_risk_  │
│      value       │
│    sales_amount  │
│    estimated_    │
│      profit      │
│    created_at    │
└──────────────────┘
```

---

## Database Schema

### 1. users

**Purpose:** Store user account information

```sql
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(20) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    preferred_language ENUM('en', 'bn') DEFAULT 'bn',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_phone (phone),
    INDEX idx_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**Fields:**
- `id`: Primary key, auto-increment
- `name`: User's full name
- `phone`: Unique phone number (used for login)
- `email`: Unique email address (used for login)
- `password_hash`: bcrypt hashed password (never store plaintext)
- `preferred_language`: User's language preference (en/bn)
- `created_at`: Account creation timestamp
- `updated_at`: Last update timestamp

**Indexes:**
- Primary key on `id`
- Index on `phone` (login queries)
- Index on `email` (login queries)

---

### 2. shops

**Purpose:** Store shop/business information (one shop per user)

```sql
CREATE TABLE shops (
    id INT AUTO_INCREMENT PRIMARY KEY,
    owner_id INT UNIQUE NOT NULL,
    shop_name VARCHAR(200) NOT NULL,
    address TEXT,
    phone VARCHAR(20),
    currency VARCHAR(10) DEFAULT 'BDT',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_owner (owner_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**Fields:**
- `id`: Primary key, shop identifier
- `owner_id`: Foreign key to users table (UNIQUE - one shop per user)
- `shop_name`: Name of the shop
- `address`: Shop physical address
- `phone`: Shop contact number
- `currency`: Currency code (default: BDT - Bangladeshi Taka)
- `created_at`: Shop creation timestamp
- `updated_at`: Last update timestamp

**Relationships:**
- One user can have one shop (1:1)
- Cascade delete: If user deleted, shop is deleted

---

### 3. categories

**Purpose:** Product category management (shop-specific)

```sql
CREATE TABLE categories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    shop_id INT NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE CASCADE,
    UNIQUE KEY unique_category_per_shop (shop_id, name),
    INDEX idx_shop (shop_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**Fields:**
- `id`: Primary key
- `shop_id`: Foreign key to shops table
- `name`: Category name (e.g., "Dairy", "Beverages", "Snacks")
- `description`: Optional category notes
- `created_at`: Creation timestamp
- `updated_at`: Last update timestamp

**Constraints:**
- Category name must be unique per shop
- Shop-specific data isolation

**Seed Examples:**
- Dairy Products (দুগ্ধজাত পণ্য)
- Beverages (পানীয়)
- Snacks (স্ন্যাকস)
- Cooking Essentials (রান্নার উপকরণ)
- Personal Care (ব্যক্তিগত যত্ন)

---

### 4. products

**Purpose:** Store product master data

```sql
CREATE TABLE products (
    id INT AUTO_INCREMENT PRIMARY KEY,
    shop_id INT NOT NULL,
    category_id INT,
    name VARCHAR(200) NOT NULL,
    sku VARCHAR(100),
    barcode VARCHAR(100),
    unit VARCHAR(50) NOT NULL DEFAULT 'piece',
    selling_price DECIMAL(10, 2) NOT NULL,
    default_purchase_price DECIMAL(10, 2) NOT NULL,
    minimum_stock DECIMAL(10, 2) DEFAULT 0,
    target_stock_days INT DEFAULT 7,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL,
    
    INDEX idx_shop (shop_id),
    INDEX idx_category (category_id),
    INDEX idx_active (is_active),
    INDEX idx_shop_active (shop_id, is_active),
    UNIQUE KEY unique_sku_per_shop (shop_id, sku)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**Fields:**
- `id`: Primary key
- `shop_id`: Foreign key to shops table (DATA ISOLATION)
- `category_id`: Foreign key to categories table
- `name`: Product name (e.g., "Fresh Milk 1L")
- `sku`: Stock Keeping Unit (optional, shop-defined)
- `barcode`: Product barcode (optional)
- `unit`: Unit of measurement (piece, kg, liter, packet, etc.)
- `selling_price`: Current selling price
- `default_purchase_price`: Default/typical purchase price
- `minimum_stock`: Minimum stock threshold for alerts
- `target_stock_days`: Target number of days of stock to maintain
- `is_active`: Product active status (soft delete)
- `created_at`: Product creation timestamp
- `updated_at`: Last update timestamp

**Business Rules:**
- `selling_price` must be >= 0
- `default_purchase_price` must be >= 0
- `minimum_stock` must be >= 0
- `target_stock_days` should be >= 1

---

### 5. product_batches

**Purpose:** Track product inventory by batch (for FEFO and expiry management)

```sql
CREATE TABLE product_batches (
    id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    batch_number VARCHAR(100),
    purchase_date DATE NOT NULL,
    expiry_date DATE,
    quantity DECIMAL(10, 2) NOT NULL DEFAULT 0,
    purchase_price DECIMAL(10, 2) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    
    INDEX idx_product (product_id),
    INDEX idx_expiry (expiry_date),
    INDEX idx_product_expiry (product_id, expiry_date),
    INDEX idx_quantity (quantity)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**Fields:**
- `id`: Primary key
- `product_id`: Foreign key to products table
- `batch_number`: Batch identifier (optional, shopkeeper-defined)
- `purchase_date`: Date the batch was purchased
- `expiry_date`: Batch expiry date (nullable for non-perishables)
- `quantity`: Current quantity in stock
- `purchase_price`: Actual purchase price for this batch
- `is_active`: Whether the batch participates in current stock and FEFO results; deactivation preserves audit references
- `created_at`: Batch creation timestamp
- `updated_at`: Last update timestamp (quantity changes)

**Business Rules:**
- `quantity` can be 0 (depleted batch)
- `quantity` must be >= 0
- `expiry_date` can be NULL (non-perishable items)
- Multiple batches can exist for same product

**FEFO Logic:**
- Active dated batches sort by `expiry_date`, `purchase_date`, then `id`
- Depleted and expired batches are excluded from FEFO recommendations
- Batches with `expiry_date IS NULL` are omitted from FEFO recommendations, matching `BUSINESS_LOGIC.md`
- Deactivated batches do not count toward stock and are not returned in the active batch list

---

### 6. sales

**Purpose:** Store sales transaction headers

```sql
CREATE TABLE sales (
    id INT AUTO_INCREMENT PRIMARY KEY,
    shop_id INT NOT NULL,
    total_amount DECIMAL(10, 2) NOT NULL,
    sale_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE CASCADE,
    
    INDEX idx_shop (shop_id),
    INDEX idx_sale_date (sale_date),
    INDEX idx_shop_date (shop_id, sale_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**Fields:**
- `id`: Primary key
- `shop_id`: Foreign key to shops table (DATA ISOLATION)
- `total_amount`: Total sale amount
- `sale_date`: Date of sale (can be backdated if entering historical data)
- `created_at`: Record creation timestamp

**Business Rules:**
- `total_amount` must be >= 0
- `sale_date` should be <= current date (future dates not allowed)

---

### 7. sale_items

**Purpose:** Store individual items in a sale transaction

```sql
CREATE TABLE sale_items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    sale_id INT NOT NULL,
    product_id INT NOT NULL,
    batch_id INT,
    quantity DECIMAL(10, 2) NOT NULL,
    selling_price DECIMAL(10, 2) NOT NULL,
    purchase_price DECIMAL(10, 2) NOT NULL,
    subtotal DECIMAL(10, 2) NOT NULL,
    
    FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT,
    FOREIGN KEY (batch_id) REFERENCES product_batches(id) ON DELETE SET NULL,
    
    INDEX idx_sale (sale_id),
    INDEX idx_product (product_id),
    INDEX idx_batch (batch_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**Fields:**
- `id`: Primary key
- `sale_id`: Foreign key to sales table
- `product_id`: Foreign key to products table (RESTRICT - prevent deletion of sold products)
- `batch_id`: Foreign key to product_batches table (nullable - batch tracking optional)
- `quantity`: Quantity sold
- `selling_price`: Price at which item was sold
- `purchase_price`: Purchase price (for profit calculation)
- `subtotal`: Calculated: quantity × selling_price

**Business Rules:**
- `quantity` must be > 0
- `selling_price` must be >= 0
- `purchase_price` must be >= 0
- `subtotal` = quantity × selling_price

**Profit Calculation:**
- Gross Profit = subtotal - (quantity × purchase_price)

---

### 8. stock_transactions

**Purpose:** Audit trail for all stock movements

```sql
CREATE TABLE stock_transactions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    batch_id INT,
    transaction_type ENUM('PURCHASE', 'SALE', 'ADJUSTMENT_IN', 'ADJUSTMENT_OUT', 'RETURN', 'EXPIRED', 'DAMAGED') NOT NULL,
    quantity DECIMAL(10, 2) NOT NULL,
    reference_id INT,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    FOREIGN KEY (batch_id) REFERENCES product_batches(id) ON DELETE SET NULL,
    
    INDEX idx_product (product_id),
    INDEX idx_batch (batch_id),
    INDEX idx_type (transaction_type),
    INDEX idx_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**Fields:**
- `id`: Primary key
- `product_id`: Foreign key to products table
- `batch_id`: Foreign key to product_batches table (nullable)
- `transaction_type`: Type and direction of stock movement
  - `PURCHASE`, `ADJUSTMENT_IN`, `RETURN`: Stock added
  - `SALE`, `ADJUSTMENT_OUT`, `EXPIRED`, `DAMAGED`: Stock removed
- `quantity`: Always a positive amount; direction comes from `transaction_type`
- `reference_id`: Reference to related record (sale_id, batch_id, etc.)
- `notes`: Optional notes/reason
- `created_at`: Transaction timestamp

**Usage:**
- Complete audit trail of stock movements
- Used for stock history display
- Helps analyze stock turnover
- Net stock impact is additions minus removals. Quantity changes and their audit rows are written in one database transaction.

---

### 9. notifications

**Purpose:** Store in-app notifications and alerts

```sql
CREATE TABLE notifications (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    type ENUM('EXPIRY_RISK', 'STOCK_OUT', 'RESTOCK', 'SLOW_MOVING', 'DAILY_SUMMARY', 'SYSTEM') NOT NULL,
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    severity ENUM('INFO', 'WARNING', 'CRITICAL') DEFAULT 'INFO',
    reference_type ENUM('PRODUCT', 'BATCH', 'SALE', 'SHOP', 'NONE') DEFAULT 'NONE',
    reference_id INT,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    
    INDEX idx_user (user_id),
    INDEX idx_user_read (user_id, is_read),
    INDEX idx_created (created_at),
    INDEX idx_type (type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**Fields:**
- `id`: Primary key
- `user_id`: Foreign key to users table
- `type`: Notification category
- `title`: Short notification title
- `message`: Detailed notification message
- `severity`: Urgency level (INFO, WARNING, CRITICAL)
- `reference_type`: Type of referenced entity
- `reference_id`: ID of referenced entity (product_id, batch_id, etc.)
- `is_read`: Read status
- `created_at`: Notification timestamp

**Notification Types:**
- `EXPIRY_RISK`: Product/batch nearing expiry
- `STOCK_OUT`: Product may run out soon
- `RESTOCK`: Restock recommendation
- `SLOW_MOVING`: Product has low sales
- `DAILY_SUMMARY`: Daily business summary
- `SYSTEM`: System/app announcements

---

### 10. daily_summaries

**Purpose:** Store pre-calculated daily business summaries

```sql
CREATE TABLE daily_summaries (
    id INT AUTO_INCREMENT PRIMARY KEY,
    shop_id INT NOT NULL,
    summary_date DATE NOT NULL,
    summary_text TEXT,
    low_stock_count INT DEFAULT 0,
    expiry_risk_count INT DEFAULT 0,
    expiry_risk_value DECIMAL(10, 2) DEFAULT 0,
    sales_amount DECIMAL(10, 2) DEFAULT 0,
    estimated_profit DECIMAL(10, 2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE CASCADE,
    
    UNIQUE KEY unique_summary_per_day (shop_id, summary_date),
    INDEX idx_shop (shop_id),
    INDEX idx_date (summary_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**Fields:**
- `id`: Primary key
- `shop_id`: Foreign key to shops table
- `summary_date`: Date of the summary
- `summary_text`: Generated summary text (Bangla/English)
- `low_stock_count`: Number of products with low stock
- `expiry_risk_count`: Number of batches at expiry risk
- `expiry_risk_value`: Total value at risk from expiry
- `sales_amount`: Total sales for the day
- `estimated_profit`: Estimated gross profit for the day
- `created_at`: Summary generation timestamp

**Business Rules:**
- One summary per shop per date
- Generated by scheduled job or on-demand
- Used for dashboard quick display

---

## Data Ownership & Isolation

### Critical Security Rule

**Every shop-specific query MUST filter by shop_id derived from the authenticated user's JWT token.**

### Implementation Pattern

```javascript
// ❌ WRONG - Trusts shop_id from client
const products = await db.query(
    'SELECT * FROM products WHERE shop_id = ?',
    [req.body.shop_id]  // NEVER trust client input for shop_id
);

// ✅ CORRECT - Uses shop_id from authenticated JWT
const products = await db.query(
    'SELECT * FROM products WHERE shop_id = ?',
    [req.user.shop_id]  // shop_id extracted from verified JWT
);
```

### Shop Data Isolation Rules

1. **Users Table**: No isolation needed (user owns their own record)
2. **Shops Table**: Filter by `owner_id = req.user.id`
3. **Categories Table**: Filter by `shop_id = req.user.shop_id`
4. **Products Table**: Filter by `shop_id = req.user.shop_id`
5. **Product Batches**: Filter via `product_id` WHERE `products.shop_id = req.user.shop_id`
6. **Sales Table**: Filter by `shop_id = req.user.shop_id`
7. **Sale Items**: Filter via `sale_id` WHERE `sales.shop_id = req.user.shop_id`
8. **Stock Transactions**: Filter via `product_id` WHERE `products.shop_id = req.user.shop_id`
9. **Notifications**: Filter by `user_id = req.user.id`
10. **Daily Summaries**: Filter by `shop_id = req.user.shop_id`

---

## Indexes Strategy

### Primary Indexes (Already Covered)
- All primary keys automatically indexed
- Foreign keys indexed for JOIN performance

### Additional Strategic Indexes

**products**
- `idx_shop_active (shop_id, is_active)`: Active products list
- `idx_category (category_id)`: Products by category

**product_batches**
- `idx_product_expiry (product_id, expiry_date)`: FEFO and expiry analysis
- `idx_expiry (expiry_date)`: Expiry risk queries

**sales**
- `idx_shop_date (shop_id, sale_date)`: Sales history by date range

**stock_transactions**
- `idx_product (product_id)`: Stock history per product
- `idx_created (created_at)`: Recent transactions

**notifications**
- `idx_user_read (user_id, is_read)`: Unread notifications query

---

## Database Queries Examples

### 1. Get Current Stock for Product

```sql
SELECT 
    p.id,
    p.name,
    COALESCE(SUM(pb.quantity), 0) as current_stock
FROM products p
LEFT JOIN product_batches pb ON p.id = pb.product_id
WHERE p.shop_id = ? AND p.id = ? AND p.is_active = TRUE
GROUP BY p.id, p.name;
```

### 2. Get Batches with Expiry Risk (Next 14 Days)

```sql
SELECT 
    pb.id,
    pb.batch_number,
    pb.expiry_date,
    pb.quantity,
    pb.purchase_price,
    p.name as product_name,
    DATEDIFF(pb.expiry_date, CURDATE()) as days_until_expiry,
    (pb.quantity * pb.purchase_price) as value_at_risk
FROM product_batches pb
JOIN products p ON pb.product_id = p.id
WHERE p.shop_id = ?
  AND pb.quantity > 0
  AND pb.expiry_date IS NOT NULL
  AND pb.expiry_date BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 14 DAY)
ORDER BY pb.expiry_date ASC;
```

### 3. Calculate Average Daily Sales (Last 30 Days)

```sql
SELECT 
    p.id as product_id,
    p.name as product_name,
    COALESCE(SUM(si.quantity), 0) as total_sold,
    COALESCE(SUM(si.quantity) / 30, 0) as avg_daily_sales
FROM products p
LEFT JOIN sale_items si ON p.id = si.product_id
LEFT JOIN sales s ON si.sale_id = s.id AND s.sale_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
WHERE p.shop_id = ? AND p.is_active = TRUE
GROUP BY p.id, p.name;
```

### 4. Get Today's Sales Summary

```sql
SELECT 
    COUNT(DISTINCT s.id) as total_transactions,
    COALESCE(SUM(s.total_amount), 0) as total_sales,
    COALESCE(SUM(si.quantity * (si.selling_price - si.purchase_price)), 0) as estimated_profit
FROM sales s
LEFT JOIN sale_items si ON s.id = si.sale_id
WHERE s.shop_id = ? AND s.sale_date = CURDATE();
```

### 5. Detect Slow-Moving Products (No Sales in 30 Days)

```sql
SELECT 
    p.id,
    p.name,
    COALESCE(SUM(pb.quantity), 0) as current_stock,
    MAX(s.sale_date) as last_sale_date,
    DATEDIFF(CURDATE(), MAX(s.sale_date)) as days_since_last_sale
FROM products p
LEFT JOIN product_batches pb ON p.id = pb.product_id
LEFT JOIN sale_items si ON p.id = si.product_id
LEFT JOIN sales s ON si.sale_id = s.id
WHERE p.shop_id = ? AND p.is_active = TRUE
GROUP BY p.id, p.name
HAVING days_since_last_sale >= 30 OR days_since_last_sale IS NULL
ORDER BY days_since_last_sale DESC;
```

---

## Migration Strategy

### Migration Files Order

1. `001_create_users_table.sql`
2. `002_create_shops_table.sql`
3. `003_create_categories_table.sql`
4. `004_create_products_table.sql`
5. `005_create_product_batches_table.sql`
6. `006_create_sales_table.sql`
7. `007_create_sale_items_table.sql`
8. `008_create_stock_transactions_table.sql`
9. `009_create_notifications_table.sql`
10. `010_create_daily_summaries_table.sql`
11. `011_reconcile_product_contract.js` (conditional legacy schema repair)
12. `012_stock_transaction_semantics.sql`
13. `013_product_batch_deactivation.js`
14. `014_category_metadata.js` (adds category description and update timestamp)

### Migration Runner

`npm run migrate` creates a `schema_migrations` ledger and executes each migration once. SQL comments are removed with a quote-aware parser before statements are sent to MySQL. A migration is recorded only after all its statements succeed. Because MySQL DDL auto-commits, interrupted migrations can leave partial DDL; migrations must be safe to retry and failures remain unrecorded.

After migration, run `npm run db:verify` to verify required tables and inspect columns, indexes, foreign keys, unique constraints, check constraints, and the applied migration list.

---

## Seed Data Structure

### Development Seed Data

**Users:**
- Test User: Rahim Khan (phone: 01712345678, email: rahim@test.com)

**Shop:**
- Rahim Grocery Store (রহিম মুদি দোকান)

**Categories:**
- Dairy Products (দুগ্ধজাত পণ্য)
- Beverages (পানীয়)
- Snacks (স্ন্যাকস)
- Cooking Essentials (রান্নার উপকরণ)

**Products:**
- Fresh Milk 1L (তাজা দুধ)
- Biscuits 200g (বিস্কুট)
- Soft Drink 500ml (কোমল পানীয়)
- Rice 1kg (চাল)
- Cooking Oil 1L (রান্নার তেল)
- Bread (রুটি)
- Eggs (per piece) (ডিম)
- Noodles (নুডলস)

**Batches:**
- Milk: 2 batches (one expiring in 5 days, one in 12 days)
- Biscuits: 1 batch (expiring in 20 days)
- Soft Drink: 1 batch (expiring in 45 days)
- Others: Various batches with different expiry dates

**Sales:**
- Last 30 days of sales data
- Mix of high-selling and slow-moving products
- Milk: High sales (4 units/day average)
- Biscuits: Medium sales (2 units/day)
- Noodles: Low sales (0.5 units/day)
- Rice: No recent sales (slow-moving example)

---

## Database Performance Considerations

### Connection Pooling

```javascript
// backend/src/database/connection.js
const mysql = require('mysql2/promise');

const pool = mysql.createPool({
    host: process.env.DB_HOST,
    port: process.env.DB_PORT,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0,
    enableKeepAlive: true,
    keepAliveInitialDelay: 0
});

module.exports = pool;
```

### Query Optimization Rules

1. **Always use prepared statements** (prevent SQL injection + performance)
2. **Limit result sets** (use LIMIT for lists, pagination)
3. **Select only needed columns** (avoid SELECT *)
4. **Use indexes effectively** (covered above)
5. **Avoid N+1 queries** (use JOINs or batch queries)
6. **Cache frequently accessed data** (daily summaries, dashboard)

---

## Backup Strategy

### Production Backup Recommendations

1. **Daily automated backups** (mysqldump or MySQL Enterprise Backup)
2. **Backup retention**: 30 days
3. **Point-in-time recovery**: Enable binary logs
4. **Test restores**: Monthly restore testing
5. **Off-site storage**: Store backups in different location/cloud

### Backup Script Example

```bash
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups/shopwise"
DB_NAME="shopwise_prod"

mysqldump -u $DB_USER -p$DB_PASSWORD \
    --single-transaction \
    --routines \
    --triggers \
    $DB_NAME | gzip > $BACKUP_DIR/shopwise_$DATE.sql.gz

# Keep only last 30 days
find $BACKUP_DIR -name "shopwise_*.sql.gz" -mtime +30 -delete
```

---

## Conclusion

This database design provides:

✅ **Strong data isolation** - Shop-level security
✅ **Multi-batch tracking** - FEFO capability
✅ **Audit trails** - Complete stock transaction history
✅ **Performance** - Strategic indexes for fast queries
✅ **Scalability** - Normalized design supports growth
✅ **Data integrity** - Foreign keys and constraints
✅ **Analysis-ready** - Structure optimized for ShopWise intelligence features

The schema fully supports all ShopWise features: expiry intelligence, stock-out prediction, restock recommendations, slow-moving detection, FEFO, profit analysis, and daily summaries.
