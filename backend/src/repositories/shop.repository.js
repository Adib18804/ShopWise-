const db = require('../config/database.js');

/**
 * Shop repository for database operations
 */
class ShopRepository {
  /**
   * Create new shop
   */
  async create(shopData) {
    const { owner_id, shop_name, address, phone, currency } = shopData;
    
    const [result] = await db.query(
      `INSERT INTO shops (owner_id, shop_name, address, phone, currency, active_owner_id)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [owner_id, shop_name, address, phone, currency || 'BDT', owner_id],
    );
    
    return result.insertId;
  }
  
  /**
   * Find shop by ID
   */
  async findById(id, ownerId) {
    const [rows] = await db.query(
      `SELECT id, owner_id, shop_name, address, phone, currency, created_at, updated_at
       FROM shops WHERE id = ? AND owner_id = ? AND deleted_at IS NULL`,
      [id, ownerId],
    );
    
    return rows[0] || null;
  }
  
  /**
   * Find shop by owner ID
   */
  async findByOwnerId(ownerId) {
    const [rows] = await db.query(
      `SELECT id, owner_id, shop_name, address, phone, currency, created_at, updated_at
       FROM shops WHERE owner_id = ? AND deleted_at IS NULL`,
      [ownerId],
    );
    
    return rows[0] || null;
  }
  
  /**
   * Check if user already has a shop
   */
  async ownerHasShop(ownerId) {
    const [rows] = await db.query(
      'SELECT COUNT(*) as count FROM shops WHERE owner_id = ? AND deleted_at IS NULL',
      [ownerId],
    );
    
    return rows[0].count > 0;
  }
  
  /**
   * Update shop
   */
  async update(id, ownerId, shopData) {
    const fields = [];
    const values = [];
    
    if (shopData.shop_name !== undefined) {
      fields.push('shop_name = ?');
      values.push(shopData.shop_name);
    }
    
    if (shopData.address !== undefined) {
      fields.push('address = ?');
      values.push(shopData.address);
    }
    
    if (shopData.phone !== undefined) {
      fields.push('phone = ?');
      values.push(shopData.phone);
    }
    
    if (shopData.currency !== undefined) {
      fields.push('currency = ?');
      values.push(shopData.currency);
    }
    
    if (fields.length === 0) {
      return false;
    }
    
    values.push(id, ownerId);
    
    const [result] = await db.query(
      `UPDATE shops SET ${fields.join(', ')} WHERE id = ? AND owner_id = ? AND deleted_at IS NULL`,
      values,
    );
    
    return result.affectedRows > 0;
  }
  
  /**
   * Soft-delete a shop and its inventory records while preserving audit history.
   */
  async delete(id, ownerId) {
    const connection = await db.getConnection();
    try {
      await connection.beginTransaction();
      const [shops] = await connection.execute(
        'SELECT id FROM shops WHERE id = ? AND owner_id = ? AND deleted_at IS NULL FOR UPDATE',
        [id, ownerId],
      );
      if (!shops.length) {
        await connection.rollback();
        return false;
      }
      await connection.execute(
        `UPDATE product_batches pb JOIN products p ON p.id = pb.product_id
            SET pb.is_active = FALSE, pb.deleted_at = CURRENT_TIMESTAMP
          WHERE p.shop_id = ? AND pb.deleted_at IS NULL`, [id],
      );
      await connection.execute(
        'UPDATE products SET is_active = FALSE, deleted_at = CURRENT_TIMESTAMP, active_sku = NULL WHERE shop_id = ? AND deleted_at IS NULL',
        [id],
      );
      await connection.execute(
        'UPDATE categories SET deleted_at = CURRENT_TIMESTAMP, active_name = NULL WHERE shop_id = ? AND deleted_at IS NULL',
        [id],
      );
      const [result] = await connection.execute(
        'UPDATE shops SET deleted_at = CURRENT_TIMESTAMP, active_owner_id = NULL WHERE id = ? AND owner_id = ? AND deleted_at IS NULL',
        [id, ownerId],
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
  
  /**
   * Get shop with owner details
   */
  async findWithOwner(id, ownerId) {
    const [rows] = await db.query(
      `SELECT 
        s.id, s.owner_id, s.shop_name, s.address, s.phone, s.currency, s.created_at, s.updated_at,
        u.name as owner_name, u.email as owner_email, u.phone as owner_phone
       FROM shops s
       INNER JOIN users u ON s.owner_id = u.id
       WHERE s.id = ? AND s.owner_id = ? AND s.deleted_at IS NULL`,
      [id, ownerId],
    );
    
    if (rows.length === 0) {
      return null;
    }
    
    const row = rows[0];
    return {
      id: row.id,
      owner_id: row.owner_id,
      shop_name: row.shop_name,
      address: row.address,
      phone: row.phone,
      currency: row.currency,
      created_at: row.created_at,
      updated_at: row.updated_at,
      owner: {
        name: row.owner_name,
        email: row.owner_email,
        phone: row.owner_phone,
      },
    };
  }
}

module.exports = new ShopRepository();
