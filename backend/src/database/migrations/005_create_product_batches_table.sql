-- Migration: Create product_batches table
-- Description: Track product inventory by batch (for FEFO and expiry management)

CREATE TABLE IF NOT EXISTS product_batches (
    id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    batch_number VARCHAR(100),
    purchase_date DATE NOT NULL,
    expiry_date DATE,
    quantity DECIMAL(10, 2) NOT NULL DEFAULT 0,
    purchase_price DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    
    INDEX idx_product (product_id),
    INDEX idx_expiry (expiry_date),
    INDEX idx_product_expiry (product_id, expiry_date),
    INDEX idx_quantity (quantity),
    
    CONSTRAINT chk_batch_quantity CHECK (quantity >= 0),
    CONSTRAINT chk_batch_purchase_price CHECK (purchase_price >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
