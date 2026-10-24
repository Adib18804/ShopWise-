const shopRepository = require('../repositories/shop.repository.js');
const { ERROR_CODES } = require('../config/constants.js');

/**
 * Shop service
 */
class ShopService {
  /**
   * Create new shop
   */
  async createShop(ownerId, shopData) {
    // Check if user already has a shop
    const hasShop = await shopRepository.ownerHasShop(ownerId);
    if (hasShop) {
      const error = new Error('User already has a shop');
      error.code = 'SHOP_001';
      throw error;
    }
    
    // Create shop
    let shopId;
    try {
      shopId = await shopRepository.create({
        owner_id: ownerId,
        shop_name: shopData.shop_name,
        address: shopData.address,
        phone: shopData.phone,
        currency: shopData.currency || 'BDT',
      });
    } catch (error) {
      if (error.code === 'ER_DUP_ENTRY') {
        const duplicate = new Error('User already has a shop');
        duplicate.code = 'SHOP_001';
        throw duplicate;
      }
      throw error;
    }
    
    // Get created shop
    const shop = await shopRepository.findById(shopId, ownerId);
    if (!shop) {
      const error = new Error('Shop could not be created');
      error.code = 'SHOP_002';
      throw error;
    }
    
    return shop;
  }
  
  /**
   * Get shop by ID
   */
  async getShopById(shopId, userId) {
    const shop = await shopRepository.findById(shopId, userId);
    
    if (!shop) {
      const error = new Error('Shop not found');
      error.code = 'SHOP_002';
      throw error;
    }
    if (shop.owner_id !== userId) {
      const error = new Error('Access denied');
      error.code = 'SHOP_003';
      throw error;
    }
    
    // Verify ownership
    return shop;
  }
  
  /**
   * Get user's shop
   */
  async getUserShop(userId) {
    const shop = await shopRepository.findByOwnerId(userId);
    
    if (!shop) {
      const error = new Error('Shop not found');
      error.code = 'SHOP_002';
      throw error;
    }
    if (shop.owner_id !== userId) {
      const error = new Error('Access denied');
      error.code = 'SHOP_003';
      throw error;
    }
    
    return shop;
  }
  
  /**
   * Update shop
   */
  async updateShop(shopId, userId, updateData) {
    // Get shop and verify ownership
    const shop = await shopRepository.findById(shopId, userId);
    
    if (!shop) {
      const error = new Error('Shop not found');
      error.code = 'SHOP_002';
      throw error;
    }
    if (shop.owner_id !== userId) {
      const error = new Error('Access denied');
      error.code = 'SHOP_003';
      throw error;
    }
    
    // Update shop
    await shopRepository.update(shopId, userId, updateData);
    
    // Get updated shop
    const updatedShop = await shopRepository.findById(shopId, userId);
    
    return updatedShop;
  }
  
  /**
   * Delete shop
   */
  async deleteShop(shopId, userId) {
    // Get shop and verify ownership
    const shop = await shopRepository.findById(shopId, userId);
    
    if (!shop) {
      const error = new Error('Shop not found');
      error.code = 'SHOP_002';
      throw error;
    }
    if (shop.owner_id !== userId) {
      const error = new Error('Access denied');
      error.code = 'SHOP_003';
      throw error;
    }
    
    // Delete shop
    await shopRepository.delete(shopId, userId);
    
    return true;
  }
  
  /**
   * Check if user has shop
   */
  async hasShop(userId) {
    return await shopRepository.ownerHasShop(userId);
  }
}

module.exports = new ShopService();
