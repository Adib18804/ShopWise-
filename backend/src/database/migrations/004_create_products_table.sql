-- Migration: Create products table
-- Description: Store product master data

CREATE TABLE IF NOT EXISTS products (
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
    UNIQUE KEY unique_sku_per_shop (shop_id, sku),
    
    CONSTRAINT chk_selling_price CHECK (selling_price >= 0),
    CONSTRAINT chk_purchase_price CHECK (default_purchase_price >= 0),
    CONSTRAINT chk_minimum_stock CHECK (minimum_stock >= 0),
    CONSTRAINT chk_target_stock_days CHECK (target_stock_days >= 1)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
