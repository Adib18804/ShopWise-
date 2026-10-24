const db = require('../config/database.js');

/**
 * User repository for database operations
 */
class UserRepository {
  /**
   * Create new user
   */
  async create(userData) {
    const { name, phone, email, password_hash, preferred_language } = userData;
    
    const [result] = await db.query(
      `INSERT INTO users (name, phone, email, password_hash, preferred_language)
       VALUES (?, ?, ?, ?, ?)`,
      [name, phone, email, password_hash, preferred_language || 'bn'],
    );
    
    return result.insertId;
  }
  
  /**
   * Find user by ID
   */
  async findById(id) {
    const [rows] = await db.query(
      `SELECT id, name, phone, email, preferred_language, created_at, updated_at
       FROM users WHERE id = ?`,
      [id],
    );
    
    return rows[0] || null;
  }
  
  /**
   * Find user by email
   */
  async findByEmail(email) {
    const [rows] = await db.query(
      `SELECT id, name, phone, email, password_hash, preferred_language, created_at, updated_at
       FROM users WHERE email = ?`,
      [email],
    );
    
    return rows[0] || null;
  }
  
  /**
   * Find user by phone
   */
  async findByPhone(phone) {
    const [rows] = await db.query(
      `SELECT id, name, phone, email, password_hash, preferred_language, created_at, updated_at
       FROM users WHERE phone = ?`,
      [phone],
    );
    
    return rows[0] || null;
  }
  
  /**
   * Find user by email or phone
   */
  async findByEmailOrPhone(identifier) {
    const [rows] = await db.query(
      `SELECT id, name, phone, email, password_hash, preferred_language, created_at, updated_at
       FROM users WHERE email = ? OR phone = ?`,
      [identifier, identifier],
    );
    
    return rows[0] || null;
  }
  
  /**
   * Check if email exists
   */
  async emailExists(email) {
    const [rows] = await db.query(
      'SELECT COUNT(*) as count FROM users WHERE email = ?',
      [email],
    );
    
    return rows[0].count > 0;
  }
  
  /**
   * Check if phone exists
   */
  async phoneExists(phone) {
    const [rows] = await db.query(
      'SELECT COUNT(*) as count FROM users WHERE phone = ?',
      [phone],
    );
    
    return rows[0].count > 0;
  }
  
  /**
   * Update user
   */
  async update(id, userData) {
    const fields = [];
    const values = [];
    
    if (userData.name) {
      fields.push('name = ?');
      values.push(userData.name);
    }
    
    if (userData.phone) {
      fields.push('phone = ?');
      values.push(userData.phone);
    }
    
    if (userData.email) {
      fields.push('email = ?');
      values.push(userData.email);
    }
    
    if (userData.password_hash) {
      fields.push('password_hash = ?');
      values.push(userData.password_hash);
    }
    
    if (userData.preferred_language) {
      fields.push('preferred_language = ?');
      values.push(userData.preferred_language);
    }
    
    if (fields.length === 0) {
      return false;
    }
    
    values.push(id);
    
    const [result] = await db.query(
      `UPDATE users SET ${fields.join(', ')} WHERE id = ?`,
      values,
    );
    
    return result.affectedRows > 0;
  }
  
  /**
   * Get user with shop information
   */
  async findWithShop(id) {
    const [rows] = await db.query(
      `SELECT 
        u.id, u.name, u.phone, u.email, u.preferred_language, u.created_at, u.updated_at,
        s.id as shop_id, s.shop_name, s.address as shop_address, s.phone as shop_phone, s.currency
       FROM users u
       LEFT JOIN shops s ON u.id = s.owner_id AND s.deleted_at IS NULL
       WHERE u.id = ?`,
      [id],
    );
    
    if (rows.length === 0) {
      return null;
    }
    
    const user = {
      id: rows[0].id,
      name: rows[0].name,
      phone: rows[0].phone,
      email: rows[0].email,
      preferred_language: rows[0].preferred_language,
      created_at: rows[0].created_at,
      updated_at: rows[0].updated_at,
      has_shop: !!rows[0].shop_id,
      shop_id: rows[0].shop_id || null,
    };
    
    if (rows[0].shop_id) {
      user.shop = {
        id: rows[0].shop_id,
        shop_name: rows[0].shop_name,
        address: rows[0].shop_address,
        phone: rows[0].shop_phone,
        currency: rows[0].currency,
      };
    }
    
    return user;
  }
}

module.exports = new UserRepository();
