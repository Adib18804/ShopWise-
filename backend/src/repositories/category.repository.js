const db = require('../config/database.js');

/**
 * Category repository for database operations
 */
class CategoryRepository {
  /**
   * Create new category
   */
  async create(categoryData) {
    const { shop_id, name, description } = categoryData;
    
    const [result] = await db.query(
      `INSERT INTO categories (shop_id, name, description, active_name)
       SELECT s.id, ?, ?, ? FROM shops s WHERE s.id = ? AND s.deleted_at IS NULL`,
      [name, description || null, name, shop_id],
    );
    
    return result.insertId;
  }
  
  /**
   * Find category by ID
   */
  async findById(id, shopId) {
    const [rows] = await db.query(
      `SELECT c.id, c.shop_id, c.name, c.description, c.created_at, c.updated_at
       FROM categories c JOIN shops s ON s.id = c.shop_id
       WHERE c.id = ? AND c.shop_id = ? AND c.deleted_at IS NULL AND s.deleted_at IS NULL`,
      [id, shopId],
    );
    
    return rows[0] || null;
  }
  
  /**
   * Find all categories by shop ID
   */
  async findByShopId(shopId, options = {}) {
    const { limit, offset } = options;
    
    let query = `
      SELECT c.id, c.shop_id, c.name, c.description, c.created_at, c.updated_at
      FROM categories c JOIN shops s ON s.id = c.shop_id
      WHERE c.shop_id = ? AND c.deleted_at IS NULL AND s.deleted_at IS NULL
      ORDER BY c.name ASC
    `;
    
    const params = [shopId];
    
    if (limit !== undefined) {
      query += ' LIMIT ?';
      params.push(limit);
      
      if (offset !== undefined) {
        query += ' OFFSET ?';
        params.push(offset);
      }
    }
    
    const [rows] = await db.query(query, params);
    return rows;
  }
  
  /**
   * Count categories by shop ID
   */
  async countByShopId(shopId) {
    const [rows] = await db.query(
      `SELECT COUNT(*) as count FROM categories c JOIN shops s ON s.id = c.shop_id
        WHERE c.shop_id = ? AND c.deleted_at IS NULL AND s.deleted_at IS NULL`,
      [shopId],
    );
    
    return rows[0].count;
  }
  
  /**
   * Check if category name exists in shop
   */
  async nameExistsInShop(shopId, name, excludeId = null) {
    let query = `SELECT COUNT(*) as count FROM categories c JOIN shops s ON s.id = c.shop_id
      WHERE c.shop_id = ? AND c.name = ? AND c.deleted_at IS NULL AND s.deleted_at IS NULL`;
    const params = [shopId, name];
    
    if (excludeId) {
      query += ' AND c.id != ?';
      params.push(excludeId);
    }
    
    const [rows] = await db.query(query, params);
    return rows[0].count > 0;
  }
  
  /**
   * Update category
   */
  async update(id, shopId, categoryData) {
    const fields = [];
    const values = [];
    
    if (categoryData.name !== undefined) {
      fields.push('name = ?');
      values.push(categoryData.name);
      fields.push('active_name = ?');
      values.push(categoryData.name);
    }
    
    if (categoryData.description !== undefined) {
      fields.push('description = ?');
      values.push(categoryData.description);
    }
    
    if (fields.length === 0) {
      return false;
    }
    
    values.push(id, shopId);
    
    const [result] = await db.query(
      `UPDATE categories c JOIN shops s ON s.id = c.shop_id SET ${fields.map((field) => `c.${field}`).join(', ')} WHERE c.id = ? AND c.shop_id = ? AND c.deleted_at IS NULL AND s.deleted_at IS NULL`,
      values,
    );
    
    return result.affectedRows > 0;
  }
  
  /**
   * Delete category
   */
  async delete(id, shopId) {
    const [result] = await db.query(
      `UPDATE categories c JOIN shops s ON s.id = c.shop_id
          SET c.deleted_at = CURRENT_TIMESTAMP, c.active_name = NULL
        WHERE c.id = ? AND c.shop_id = ? AND c.deleted_at IS NULL AND s.deleted_at IS NULL`,
      [id, shopId],
    );
    
    return result.affectedRows > 0;
  }
  
  /**
   * Check if category has products
   */
  async hasProducts(id, shopId) {
    const [rows] = await db.query(
      `SELECT COUNT(*) as count FROM products p JOIN categories c ON c.id = p.category_id
        JOIN shops s ON s.id = p.shop_id
       WHERE p.category_id = ? AND p.shop_id = ? AND p.deleted_at IS NULL
         AND p.is_active = TRUE AND c.deleted_at IS NULL AND s.deleted_at IS NULL`,
      [id, shopId],
    );
    
    return rows[0].count > 0;
  }
  
  /**
   * Get category with product count
   */
  async findWithProductCount(id, shopId) {
    const [rows] = await db.query(
      `SELECT 
        c.id, c.shop_id, c.name, c.description, c.created_at, c.updated_at,
        COUNT(CASE WHEN p.deleted_at IS NULL AND p.is_active = TRUE THEN p.id END) as product_count
       FROM categories c
       LEFT JOIN products p ON c.id = p.category_id AND p.shop_id = c.shop_id
       JOIN shops s ON s.id = c.shop_id
       WHERE c.id = ? AND c.shop_id = ? AND c.deleted_at IS NULL AND s.deleted_at IS NULL
       GROUP BY c.id`,
      [id, shopId],
    );
    
    return rows[0] || null;
  }
  
  /**
   * Get all categories with product counts for a shop
   */
  async findByShopIdWithCounts(shopId) {
    const [rows] = await db.query(
      `SELECT 
        c.id, c.shop_id, c.name, c.description, c.created_at, c.updated_at,
        COUNT(CASE WHEN p.deleted_at IS NULL AND p.is_active = TRUE THEN p.id END) as product_count
       FROM categories c
       LEFT JOIN products p ON c.id = p.category_id AND p.shop_id = c.shop_id
       JOIN shops s ON s.id = c.shop_id
       WHERE c.shop_id = ? AND c.deleted_at IS NULL AND s.deleted_at IS NULL
       GROUP BY c.id
       ORDER BY c.name ASC`,
      [shopId],
    );
    
    return rows;
  }
}

module.exports = new CategoryRepository();
