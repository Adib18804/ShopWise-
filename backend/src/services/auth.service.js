const userRepository = require('../repositories/user.repository.js');
const { hashPassword, comparePassword } = require('../utils/bcrypt.util.js');
const { generateToken } = require('../utils/jwt.util.js');
const { ERROR_CODES } = require('../config/constants.js');

/**
 * Authentication service
 */
class AuthService {
  /**
   * Register new user
   */
  async register(userData) {
    const { name, phone, email, password, preferred_language } = userData;
    
    // Check if email already exists
    const emailExists = await userRepository.emailExists(email);
    if (emailExists) {
      const error = new Error(ERROR_CODES.AUTH_005);
      error.code = 'AUTH_005';
      error.field = 'email';
      throw error;
    }
    
    // Check if phone already exists
    const phoneExists = await userRepository.phoneExists(phone);
    if (phoneExists) {
      const error = new Error(ERROR_CODES.AUTH_006);
      error.code = 'AUTH_006';
      error.field = 'phone';
      throw error;
    }
    
    // Hash password
    const password_hash = await hashPassword(password);
    
    // Create user
    const userId = await userRepository.create({
      name,
      phone,
      email,
      password_hash,
      preferred_language: preferred_language || 'bn',
    });
    
    // Get created user
    const user = await userRepository.findWithShop(userId);
    
    // Generate JWT token
    const token = generateToken({
      user_id: user.id,
      shop_id: user.shop_id,
      email: user.email,
    });
    
    // Remove sensitive data
    delete user.password_hash;
    
    return {
      user,
      token,
    };
  }
  
  /**
   * Login user
   */
  async login(identifier, password) {
    // Find user by email or phone
    const user = await userRepository.findByEmailOrPhone(identifier);
    
    if (!user) {
      const error = new Error(ERROR_CODES.AUTH_001);
      error.code = 'AUTH_001';
      throw error;
    }
    
    // Verify password
    const isPasswordValid = await comparePassword(password, user.password_hash);
    
    if (!isPasswordValid) {
      const error = new Error(ERROR_CODES.AUTH_001);
      error.code = 'AUTH_001';
      throw error;
    }
    
    // Get user with shop information
    const userWithShop = await userRepository.findWithShop(user.id);
    
    // Generate JWT token
    const token = generateToken({
      user_id: userWithShop.id,
      shop_id: userWithShop.shop_id,
      email: userWithShop.email,
    });
    
    // Remove sensitive data
    delete userWithShop.password_hash;
    
    return {
      user: userWithShop,
      token,
    };
  }
  
  /**
   * Get current user
   */
  async getCurrentUser(userId) {
    const user = await userRepository.findWithShop(userId);
    
    if (!user) {
      const error = new Error(ERROR_CODES.AUTH_004);
      error.code = 'AUTH_004';
      throw error;
    }
    
    return user;
  }

  /** Reissue the JWT after account context changes, such as shop creation. */
  async refreshSession(userId) {
    const user = await userRepository.findWithShop(userId);
    if (!user) {
      const error = new Error(ERROR_CODES.AUTH_004);
      error.code = 'AUTH_004';
      throw error;
    }
    const token = generateToken({
      user_id: user.id,
      shop_id: user.shop_id,
      email: user.email,
    });
    return { user, token };
  }
  
  /**
   * Update user profile
   */
  async updateProfile(userId, updateData) {
    const user = await userRepository.findById(userId);
    
    if (!user) {
      const error = new Error(ERROR_CODES.AUTH_004);
      error.code = 'AUTH_004';
      throw error;
    }
    
    // Check if email is being changed and already exists
    if (updateData.email && updateData.email !== user.email) {
      const emailExists = await userRepository.emailExists(updateData.email);
      if (emailExists) {
        const error = new Error(ERROR_CODES.AUTH_005);
        error.code = 'AUTH_005';
        error.field = 'email';
        throw error;
      }
    }
    
    // Check if phone is being changed and already exists
    if (updateData.phone && updateData.phone !== user.phone) {
      const phoneExists = await userRepository.phoneExists(updateData.phone);
      if (phoneExists) {
        const error = new Error(ERROR_CODES.AUTH_006);
        error.code = 'AUTH_006';
        error.field = 'phone';
        throw error;
      }
    }
    
    // Update user
    await userRepository.update(userId, updateData);
    
    // Get updated user
    return await userRepository.findWithShop(userId);
  }
  
  /**
   * Change password
   */
  async changePassword(userId, currentPassword, newPassword) {
    const user = await userRepository.findById(userId);
    
    if (!user) {
      const error = new Error(ERROR_CODES.AUTH_004);
      error.code = 'AUTH_004';
      throw error;
    }
    
    // Get user with password hash
    const userWithPassword = await userRepository.findByEmail(user.email);
    
    // Verify current password
    const isPasswordValid = await comparePassword(currentPassword, userWithPassword.password_hash);
    
    if (!isPasswordValid) {
      const error = new Error('Current password is incorrect');
      error.code = 'AUTH_007';
      throw error;
    }
    
    // Hash new password
    const password_hash = await hashPassword(newPassword);
    
    // Update password
    await userRepository.update(userId, { password_hash });
    
    return true;
  }
}

module.exports = new AuthService();
