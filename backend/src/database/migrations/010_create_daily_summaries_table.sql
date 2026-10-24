-- Migration: Create daily_summaries table
-- Description: Store pre-calculated daily business summaries

CREATE TABLE IF NOT EXISTS daily_summaries (
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
