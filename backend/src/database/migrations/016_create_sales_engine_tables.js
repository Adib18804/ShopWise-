async function tableExists(connection, tableName) {
  const [rows] = await connection.execute(
    `SELECT COUNT(*) AS count FROM information_schema.TABLES
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?`,
    [tableName],
  );
  return Number(rows[0].count) > 0;
}

async function columnExists(connection, tableName, columnName) {
  const [rows] = await connection.execute(
    `SELECT COUNT(*) AS count FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?`,
    [tableName, columnName],
  );
  return Number(rows[0].count) > 0;
}

async function indexExists(connection, tableName, indexName) {
  const [rows] = await connection.execute(
    `SELECT COUNT(*) AS count FROM information_schema.STATISTICS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND INDEX_NAME = ?`,
    [tableName, indexName],
  );
  return Number(rows[0].count) > 0;
}

async function constraintExists(connection, tableName, constraintName, type) {
  const [rows] = await connection.execute(
    `SELECT COUNT(*) AS count FROM information_schema.TABLE_CONSTRAINTS
      WHERE CONSTRAINT_SCHEMA = DATABASE() AND TABLE_NAME = ?
        AND CONSTRAINT_NAME = ? AND CONSTRAINT_TYPE = ?`,
    [tableName, constraintName, type],
  );
  return Number(rows[0].count) > 0;
}

async function addColumnIfMissing(connection, tableName, columnName, definition) {
  if (!await columnExists(connection, tableName, columnName)) {
    await connection.query(`ALTER TABLE ${tableName} ADD COLUMN ${columnName} ${definition}`);
  }
}

async function addIndexIfMissing(connection, tableName, indexName, definition) {
  if (!await indexExists(connection, tableName, indexName)) {
    await connection.query(`ALTER TABLE ${tableName} ADD ${definition}`);
  }
}

async function addCheckIfMissing(connection, tableName, constraintName, expression) {
  if (!await constraintExists(connection, tableName, constraintName, 'CHECK')) {
    await connection.query(
      `ALTER TABLE ${tableName} ADD CONSTRAINT ${constraintName} CHECK (${expression})`,
    );
  }
}

async function up(connection) {
  if (!await tableExists(connection, 'sales')) {
    throw new Error('Migration 016 requires the legacy sales table from migration 006');
  }
  if (!await tableExists(connection, 'sale_items')) {
    throw new Error('Migration 016 requires the legacy sale_items table from migration 007');
  }

  await connection.query(`
    CREATE TABLE IF NOT EXISTS sales_invoices (
      id INT AUTO_INCREMENT PRIMARY KEY,
      shop_id INT NOT NULL,
      invoice_number VARCHAR(50) NOT NULL,
      customer_id INT NULL,
      total_amount DECIMAL(10, 2) NOT NULL,
      discount DECIMAL(10, 2) NOT NULL DEFAULT 0,
      paid_amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
      due_amount DECIMAL(10, 2)
        GENERATED ALWAYS AS (total_amount - discount - paid_amount) STORED,
      status ENUM('completed', 'void') NOT NULL DEFAULT 'completed',
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      deleted_at TIMESTAMP NULL DEFAULT NULL,

      CONSTRAINT fk_sales_invoices_shop
        FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE RESTRICT,
      CONSTRAINT uq_sales_invoices_shop_number
        UNIQUE (shop_id, invoice_number),
      INDEX idx_sales_invoices_shop_created (shop_id, created_at, id),
      INDEX idx_sales_invoices_shop_status_created (shop_id, status, created_at, id),
      CONSTRAINT chk_sales_invoice_total CHECK (total_amount >= 0),
      CONSTRAINT chk_sales_invoice_discount
        CHECK (discount >= 0 AND discount <= total_amount),
      CONSTRAINT chk_sales_invoice_paid
        CHECK (paid_amount >= 0 AND paid_amount <= total_amount - discount)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);

  await connection.query(`
    CREATE TABLE IF NOT EXISTS payments (
      id INT AUTO_INCREMENT PRIMARY KEY,
      invoice_id INT NOT NULL,
      amount DECIMAL(10, 2) NOT NULL,
      payment_method ENUM('cash', 'bkash', 'nagad') NOT NULL,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

      CONSTRAINT fk_payments_invoice
        FOREIGN KEY (invoice_id) REFERENCES sales_invoices(id) ON DELETE RESTRICT,
      INDEX idx_payments_invoice_created (invoice_id, created_at, id),
      CONSTRAINT chk_payment_amount CHECK (amount > 0)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);

  // Keep legacy columns/FKs for Phase 1 reference checks and the existing
  // development seed script. New invoice-backed rows use invoice_id/unit_price.
  await connection.query(`
    ALTER TABLE sale_items
      MODIFY COLUMN sale_id INT NULL,
      MODIFY COLUMN selling_price DECIMAL(10, 2) NULL,
      MODIFY COLUMN subtotal DECIMAL(10, 2) NULL
  `);
  await addColumnIfMissing(connection, 'sale_items', 'invoice_id', 'INT NULL AFTER sale_id');
  await addColumnIfMissing(connection, 'sale_items', 'unit_price', 'DECIMAL(10, 2) NULL AFTER quantity');
  await addColumnIfMissing(
    connection,
    'sale_items',
    'total_price',
    'DECIMAL(10, 2) GENERATED ALWAYS AS (ROUND(quantity * unit_price, 2)) STORED',
  );
  await addColumnIfMissing(connection, 'sale_items', 'created_at', 'TIMESTAMP NULL DEFAULT NULL');

  await connection.query(`
    UPDATE sale_items si
      JOIN sales s ON s.id = si.sale_id
       SET si.created_at = s.created_at
     WHERE si.created_at IS NULL
  `);
  await connection.query(
    'ALTER TABLE sale_items MODIFY COLUMN created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP',
  );

  if (!await constraintExists(connection, 'sale_items', 'fk_sale_items_invoice', 'FOREIGN KEY')) {
    await connection.query(`
      ALTER TABLE sale_items
        ADD CONSTRAINT fk_sale_items_invoice
          FOREIGN KEY (invoice_id) REFERENCES sales_invoices(id) ON DELETE RESTRICT
    `);
  }
  await addIndexIfMissing(
    connection,
    'sale_items',
    'idx_sale_items_invoice_created',
    'INDEX idx_sale_items_invoice_created (invoice_id, created_at, id)',
  );
  await addCheckIfMissing(
    connection,
    'sale_items',
    'chk_sale_items_legacy_or_invoice',
    `((invoice_id IS NULL AND sale_id IS NOT NULL AND selling_price IS NOT NULL AND subtotal IS NOT NULL)
      OR (invoice_id IS NOT NULL AND sale_id IS NULL AND unit_price IS NOT NULL))`,
  );
  await addCheckIfMissing(
    connection,
    'sale_items',
    'chk_sale_item_unit_price',
    'unit_price IS NULL OR unit_price >= 0',
  );
}

module.exports = { up };
