-- Migration: Create stock_transactions table
-- Description: Audit trail for all stock movements

CREATE TABLE IF NOT EXISTS stock_transactions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    batch_id INT,
    transaction_type ENUM('PURCHASE', 'SALE', 'ADJUSTMENT', 'RETURN', 'EXPIRED', 'DAMAGED') NOT NULL,
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
