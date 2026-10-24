const shopService = require('../services/shop.service.js');
const authService = require('../services/auth.service.js');
const { successResponse, errorResponse } = require('../utils/response.util.js');
const { HTTP_STATUS } = require('../config/constants.js');
const logger = require('../utils/logger.util.js');

/**
 * Shop controller
 */
class ShopController {
  /**
   * Create new shop
   * POST /api/v1/shop
   */
  async createShop(req, res) {
    try {
      const { shop_name, address, phone, currency } = req.body;
      const userId = req.user.id;
      
      const shop = await shopService.createShop(userId, {
        shop_name,
        address,
        phone,
        currency,
      });
      const session = await authService.refreshSession(userId);
      
      return successResponse(
        res,
        'Shop created successfully',
        { shop, user: session.user, token: session.token },
        HTTP_STATUS.CREATED,
      );
    } catch (error) {
      logger.error('Create shop error:', error);
      
      if (error.code === 'SHOP_001') {
        return errorResponse(
          res,
          error.message,
          null,
          HTTP_STATUS.BAD_REQUEST,
        );
      }
      
      return errorResponse(
        res,
        'Failed to create shop',
        null,
        HTTP_STATUS.INTERNAL_SERVER_ERROR,
      );
    }
  }
  
  /**
   * Get user's shop
   * GET /api/v1/shop
   */
  async getMyShop(req, res) {
    try {
      const userId = req.user.id;
      
      const shop = await shopService.getUserShop(userId);
      
      return successResponse(res, 'Shop retrieved successfully', { shop });
    } catch (error) {
      logger.error('Get shop error:', error);
      
      if (error.code === 'SHOP_002') {
        return errorResponse(
          res,
          error.message,
          null,
          HTTP_STATUS.NOT_FOUND,
        );
      }
      
      return errorResponse(
        res,
        'Failed to retrieve shop',
        null,
        HTTP_STATUS.INTERNAL_SERVER_ERROR,
      );
    }
  }
  
  /**
   * Get shop by ID
   * GET /api/v1/shop/:id
   */
  async getShopById(req, res) {
    try {
      const shopId = parseInt(req.params.id, 10);
      const userId = req.user.id;
      
      const shop = await shopService.getShopById(shopId, userId);
      
      return successResponse(res, 'Shop retrieved successfully', { shop });
    } catch (error) {
      logger.error('Get shop by ID error:', error);
      
      if (error.code === 'SHOP_002') {
        return errorResponse(
          res,
          error.message,
          null,
          HTTP_STATUS.NOT_FOUND,
        );
      }
      
      if (error.code === 'SHOP_003') {
        return errorResponse(
          res,
          error.message,
          null,
          HTTP_STATUS.FORBIDDEN,
        );
      }
      
      return errorResponse(
        res,
        'Failed to retrieve shop',
        null,
        HTTP_STATUS.INTERNAL_SERVER_ERROR,
      );
    }
  }
  
  /**
   * Update shop
   * PUT /api/v1/shop/:id
   */
  async updateShop(req, res) {
    try {
      const shopId = parseInt(req.params.id, 10);
      const userId = req.user.id;
      const { shop_name, address, phone, currency } = req.body;
      
      const shop = await shopService.updateShop(shopId, userId, {
        shop_name,
        address,
        phone,
        currency,
      });
      
      return successResponse(res, 'Shop updated successfully', { shop });
    } catch (error) {
      logger.error('Update shop error:', error);
      
      if (error.code === 'SHOP_002') {
        return errorResponse(
          res,
          error.message,
          null,
          HTTP_STATUS.NOT_FOUND,
        );
      }
      
      if (error.code === 'SHOP_003') {
        return errorResponse(
          res,
          error.message,
          null,
          HTTP_STATUS.FORBIDDEN,
        );
      }
      
      return errorResponse(
        res,
        'Failed to update shop',
        null,
        HTTP_STATUS.INTERNAL_SERVER_ERROR,
      );
    }
  }
  
  /**
   * Delete shop
   * DELETE /api/v1/shop/:id
   */
  async deleteShop(req, res) {
    try {
      const shopId = parseInt(req.params.id, 10);
      const userId = req.user.id;
      
      await shopService.deleteShop(shopId, userId);
      
      return successResponse(res, 'Shop deleted successfully');
    } catch (error) {
      logger.error('Delete shop error:', error);
      
      if (error.code === 'SHOP_002') {
        return errorResponse(
          res,
          error.message,
          null,
          HTTP_STATUS.NOT_FOUND,
        );
      }
      
      if (error.code === 'SHOP_003') {
        return errorResponse(
          res,
          error.message,
          null,
          HTTP_STATUS.FORBIDDEN,
        );
      }
      
      return errorResponse(
        res,
        'Failed to delete shop',
        null,
        HTTP_STATUS.INTERNAL_SERVER_ERROR,
      );
    }
  }
  
  /**
   * Check if user has shop
   * GET /api/v1/shop/check
   */
  async checkShop(req, res) {
    try {
      const userId = req.user.id;
      
      const hasShop = await shopService.hasShop(userId);
      
      return successResponse(res, 'Shop check completed', { hasShop });
    } catch (error) {
      logger.error('Check shop error:', error);
      
      return errorResponse(
        res,
        'Failed to check shop',
        null,
        HTTP_STATUS.INTERNAL_SERVER_ERROR,
      );
    }
  }
}

module.exports = new ShopController();
