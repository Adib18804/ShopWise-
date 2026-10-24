const db = require('../config/database.js');

const PRODUCT_COLUMNS = `
  p.id, p.shop_id, p.category_id, p.name, p.sku, p.barcode, p.unit,
  p.selling_price, p.default_purchase_price, p.minimum_stock,
  p.target_stock_days, p.is_active, p.created_at, p.updated_at`;

class ProductRepository {
  async create(data) {
    const [result] = await db.execute(
      `INSERT INTO products
       (shop_id, category_id, name, sku, barcode, unit, selling_price,
        default_purchase_price, minimum_stock, target_stock_days, active_sku)
       SELECT s.id, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? FROM shops s
        WHERE s.id = ? AND s.deleted_at IS NULL`,
      [data.category_id ?? null, data.name, data.sku ?? null,
        data.barcode ?? null, data.unit, data.selling_price,
        data.default_purchase_price, data.minimum_stock ?? 0,
        data.target_stock_days ?? 7, data.sku ?? null, data.shop_id],
    );
    return result.insertId;
  }

  async findById(id, shopId) {
    const [rows] = await db.execute(
      `SELECT ${PRODUCT_COLUMNS} FROM products p
       JOIN shops s ON s.id = p.shop_id
       WHERE p.id = ? AND p.shop_id = ? AND p.deleted_at IS NULL AND s.deleted_at IS NULL`, [id, shopId],
    );
    return rows[0] ?? null;
  }

  async findByIdAndShopId(id, shopId, connection = db, forUpdate = false) {
    const [rows] = await connection.execute(
      `SELECT p.id, p.shop_id, p.category_id, p.name, p.sku, p.barcode, p.unit,
              p.selling_price, p.default_purchase_price, p.minimum_stock,
              p.target_stock_days, p.is_active, p.created_at, p.updated_at
         FROM products p JOIN shops s ON s.id = p.shop_id
        WHERE p.id = ? AND p.shop_id = ? AND p.is_active = TRUE
          AND p.deleted_at IS NULL AND s.deleted_at IS NULL
          ${forUpdate ? 'FOR UPDATE' : ''}`,
      [id, shopId],
    );
    return rows[0] ?? null;
  }

  async findByIdWithCategory(id, shopId) {
    const [rows] = await db.execute(
      `SELECT ${PRODUCT_COLUMNS}, c.name AS category_name
       FROM products p JOIN shops s ON s.id = p.shop_id
       LEFT JOIN categories c ON c.id = p.category_id AND c.shop_id = p.shop_id AND c.deleted_at IS NULL
       WHERE p.id = ? AND p.shop_id = ? AND p.deleted_at IS NULL AND s.deleted_at IS NULL`, [id, shopId],
    );
    return rows.length ? this.#mapProduct(rows[0]) : null;
  }

  async findByShopId(shopId, options = {}) {
    const { category_id, search, limit, offset } = options;
    let query = `SELECT ${PRODUCT_COLUMNS}, c.name AS category_name,
        COALESCE(stock.total_stock, 0) AS total_stock,
        COALESCE(batch_counts.batch_count, 0) AS batch_count
      FROM products p
      LEFT JOIN categories c ON c.id = p.category_id AND c.shop_id = p.shop_id AND c.deleted_at IS NULL
      LEFT JOIN (
        SELECT product_id, SUM(quantity) AS total_stock
        FROM product_batches WHERE is_active = TRUE AND deleted_at IS NULL GROUP BY product_id
      ) stock ON stock.product_id = p.id
      LEFT JOIN (
        SELECT product_id, COUNT(*) AS batch_count
        FROM product_batches WHERE is_active = TRUE AND deleted_at IS NULL GROUP BY product_id
      ) batch_counts ON batch_counts.product_id = p.id
      JOIN shops s ON s.id = p.shop_id
      WHERE p.shop_id = ? AND p.is_active = TRUE AND p.deleted_at IS NULL AND s.deleted_at IS NULL`;
    const params = [shopId];
    if (category_id) { query += ' AND p.category_id = ?'; params.push(category_id); }
    if (search) {
      query += ' AND (p.name LIKE ? OR p.sku LIKE ? OR p.barcode LIKE ?)';
      const term = `%${search}%`;
      params.push(term, term, term);
    }
    query += ' ORDER BY p.name ASC';
    if (limit !== undefined) {
      query += ' LIMIT ?'; params.push(Number(limit));
      if (offset !== undefined) { query += ' OFFSET ?'; params.push(Number(offset)); }
    }
    const [rows] = await db.execute(query, params);
    return rows.map(row => this.#mapProduct(row));
  }

  async countByShopId(shopId, options = {}) {
    let query = `SELECT COUNT(*) AS count FROM products p JOIN shops s ON s.id = p.shop_id
      WHERE p.shop_id = ? AND p.is_active = TRUE AND p.deleted_at IS NULL AND s.deleted_at IS NULL`;
    const params = [shopId];
    if (options.category_id) { query += ' AND p.category_id = ?'; params.push(options.category_id); }
    if (options.search) {
      query += ' AND (p.name LIKE ? OR p.sku LIKE ? OR p.barcode LIKE ?)';
      const term = `%${options.search}%`; params.push(term, term, term);
    }
    const [rows] = await db.execute(query, params);
    return Number(rows[0].count);
  }

  async nameExistsInShop(shopId, name, excludeId = null) {
    let query = `SELECT COUNT(*) AS count FROM products p JOIN shops s ON s.id = p.shop_id
      WHERE p.shop_id = ? AND p.name = ? AND p.is_active = TRUE
        AND p.deleted_at IS NULL AND s.deleted_at IS NULL`;
    const params = [shopId, name];
    if (excludeId) { query += ' AND p.id <> ?'; params.push(excludeId); }
    const [rows] = await db.execute(query, params);
    return Number(rows[0].count) > 0;
  }

  async barcodeExistsInShop(shopId, barcode, excludeId = null) {
    return this.#valueExists('barcode', shopId, barcode, excludeId);
  }

  async skuExistsInShop(shopId, sku, excludeId = null) {
    return this.#valueExists('sku', shopId, sku, excludeId);
  }

  async #valueExists(column, shopId, value, excludeId) {
    if (!value) return false;
    // `column` is private and selected only by the two fixed callers above.
    let query = `SELECT COUNT(*) AS count FROM products p JOIN shops s ON s.id = p.shop_id
      WHERE p.shop_id = ? AND p.${column} = ? AND p.is_active = TRUE
        AND p.deleted_at IS NULL AND s.deleted_at IS NULL`;
    const params = [shopId, value];
    if (excludeId) { query += ' AND p.id <> ?'; params.push(excludeId); }
    const [rows] = await db.execute(query, params);
    return Number(rows[0].count) > 0;
  }

  async update(id, shopId, data) {
    const fieldMap = {
      category_id: 'category_id', name: 'name', sku: 'sku', barcode: 'barcode',
      unit: 'unit', selling_price: 'selling_price',
      default_purchase_price: 'default_purchase_price',
      minimum_stock: 'minimum_stock', target_stock_days: 'target_stock_days',
    };
    const fields = [];
    const values = [];
    for (const [key, column] of Object.entries(fieldMap)) {
      if (data[key] !== undefined) {
        fields.push(`${column} = ?`); values.push(data[key]);
        if (key === 'sku') { fields.push('active_sku = ?'); values.push(data[key]); }
      }
    }
    if (!fields.length) return false;
    values.push(id, shopId);
    const [result] = await db.execute(
      `UPDATE products p JOIN shops s ON s.id = p.shop_id
          SET ${fields.map((field) => `p.${field}`).join(', ')}
        WHERE p.id = ? AND p.shop_id = ? AND p.deleted_at IS NULL AND s.deleted_at IS NULL`, values,
    );
    return result.affectedRows > 0;
  }

  async deactivate(id, shopId) {
    const connection = await db.getConnection();
    try {
      await connection.beginTransaction();
      const [products] = await connection.execute(
        `SELECT p.id FROM products p JOIN shops s ON s.id = p.shop_id
          WHERE p.id = ? AND p.shop_id = ? AND p.deleted_at IS NULL AND s.deleted_at IS NULL FOR UPDATE`,
        [id, shopId],
      );
      if (!products.length) {
        await connection.rollback();
        return false;
      }
      await connection.execute(
        `UPDATE product_batches SET is_active = FALSE, deleted_at = CURRENT_TIMESTAMP
          WHERE product_id = ? AND deleted_at IS NULL`, [id],
      );
      const [result] = await connection.execute(
        `UPDATE products SET is_active = FALSE, deleted_at = CURRENT_TIMESTAMP, active_sku = NULL
          WHERE id = ? AND shop_id = ? AND deleted_at IS NULL`, [id, shopId],
      );
      await connection.commit();
      return result.affectedRows > 0;
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  }

  async hasBatches(id, shopId) {
    const [rows] = await db.execute(`SELECT COUNT(*) AS count FROM product_batches pb
      JOIN products p ON p.id = pb.product_id JOIN shops s ON s.id = p.shop_id
      WHERE pb.product_id = ? AND p.shop_id = ? AND pb.deleted_at IS NULL AND p.deleted_at IS NULL
        AND s.deleted_at IS NULL`, [id, shopId]);
    return Number(rows[0].count) > 0;
  }

  async hasSales(id, shopId) {
    const [rows] = await db.execute(`SELECT COUNT(*) AS count FROM sale_items si
      JOIN products p ON p.id = si.product_id JOIN shops s ON s.id = p.shop_id
      WHERE si.product_id = ? AND p.shop_id = ? AND p.deleted_at IS NULL AND s.deleted_at IS NULL`, [id, shopId]);
    return Number(rows[0].count) > 0;
  }

  async findByIdWithDetails(id, shopId) {
    const [rows] = await db.execute(
      `SELECT ${PRODUCT_COLUMNS}, c.name AS category_name,
          COALESCE(stock.total_stock, 0) AS total_stock,
          COALESCE(batch_counts.batch_count, 0) AS batch_count
       FROM products p JOIN shops s ON s.id = p.shop_id
       LEFT JOIN categories c ON c.id = p.category_id AND c.shop_id = p.shop_id AND c.deleted_at IS NULL
       LEFT JOIN (
         SELECT product_id, SUM(quantity) AS total_stock
         FROM product_batches WHERE is_active = TRUE AND deleted_at IS NULL GROUP BY product_id
       ) stock ON stock.product_id = p.id
       LEFT JOIN (
         SELECT product_id, COUNT(*) AS batch_count
         FROM product_batches WHERE is_active = TRUE AND deleted_at IS NULL GROUP BY product_id
       ) batch_counts ON batch_counts.product_id = p.id
       WHERE p.id = ? AND p.shop_id = ? AND p.deleted_at IS NULL AND s.deleted_at IS NULL`, [id, shopId],
    );
    return rows.length ? this.#mapProduct(rows[0]) : null;
  }

  async findLowStockProducts(shopId) {
    const products = await this.findByShopId(shopId);
    return products.filter(product => Number(product.total_stock) <= Number(product.minimum_stock));
  }

  #mapProduct(row) {
    return {
      id: row.id,
      shop_id: row.shop_id,
      category_id: row.category_id,
      name: row.name,
      sku: row.sku,
      barcode: row.barcode,
      unit: row.unit,
      selling_price: Number(row.selling_price),
      default_purchase_price: Number(row.default_purchase_price),
      minimum_stock: Number(row.minimum_stock),
      target_stock_days: row.target_stock_days,
      is_active: Boolean(row.is_active),
      total_stock: Number(row.total_stock ?? 0),
      batch_count: row.batch_count == null ? undefined : Number(row.batch_count),
      created_at: row.created_at,
      updated_at: row.updated_at,
      category: row.category_id == null ? null : { id: row.category_id, name: row.category_name },
    };
  }
}

module.exports = new ProductRepository();
