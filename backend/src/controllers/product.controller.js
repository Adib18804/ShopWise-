const productService = require('../services/product.service.js');
const { successResponse, errorResponse } = require('../utils/response.util.js');
const { HTTP_STATUS } = require('../config/constants.js');
const logger = require('../utils/logger.util.js');

/**
 * Product controller
 */
class ProductController {
  /**
   * Create new product
   * POST /api/v1/products
   */
  async createProduct(req, res) {
    try {
      const {
        category_id, name, sku, barcode, unit, selling_price,
        default_purchase_price, minimum_stock, reorder_level, target_stock_days,
      } = req.body;
      const shopId = req.user.shop_id;
      
      if (!shopId) {
        return errorResponse(
          res,
          'Shop not found. Please create a shop first.',
          null,
          HTTP_STATUS.BAD_REQUEST,
        );
      }
      
      const product = await productService.createProduct(shopId, {
        category_id, name, sku, barcode, unit, selling_price,
        default_purchase_price, minimum_stock, reorder_level, target_stock_days,
      });
      
      return successResponse(
        res,
        'Product created successfully',
        { product },
        HTTP_STATUS.CREATED,
      );
    } catch (error) {
      logger.error('Create product error:', error);
      
      if (error.code === 'PRODUCT_005') {
        return errorResponse(res, error.message, null, HTTP_STATUS.NOT_FOUND);
      }

      if (['PRODUCT_001', 'PRODUCT_002', 'PRODUCT_003', 'PRODUCT_004', 'PRODUCT_009', 'PRODUCT_010'].includes(error.code)) {
        return errorResponse(
          res,
          error.message,
          null,
          HTTP_STATUS.BAD_REQUEST,
        );
      }
      
      return errorResponse(
        res,
        'Failed to create product',
        null,
        HTTP_STATUS.INTERNAL_SERVER_ERROR,
      );
    }
  }
  
  /**
   * Get all products for shop
   * GET /api/v1/products
   */
  async getProducts(req, res) {
    try {
      const shopId = req.user.shop_id;
      
      if (!shopId) {
        return errorResponse(
          res,
          'Shop not found',
          null,
          HTTP_STATUS.BAD_REQUEST,
        );
      }
      
      const { q, category_id, limit, offset } = req.query;
      
      const options = {
        search: q,
        category_id: category_id ? parseInt(category_id, 10) : undefined,
        limit: limit ? parseInt(limit, 10) : undefined,
        offset: offset ? parseInt(offset, 10) : undefined,
      };
      
      const result = await productService.getShopProducts(shopId, options);
      
      return successResponse(
        res,
        'Products retrieved successfully',
        result,
      );
    } catch (error) {
      logger.error('Get products error:', error);
      
      return errorResponse(
        res,
        'Failed to retrieve products',
        null,
        HTTP_STATUS.INTERNAL_SERVER_ERROR,
      );
    }
  }
  
  /**
   * Get product by ID
   * GET /api/v1/products/:id
   */
  async getProductById(req, res) {
    try {
      const productId = parseInt(req.params.id, 10);
      const shopId = req.user.shop_id;
      
      if (!shopId) {
        return errorResponse(
          res,
          'Shop not found',
          null,
          HTTP_STATUS.BAD_REQUEST,
        );
      }
      
      const product = await productService.getProductById(productId, shopId);
      
      return successResponse(
        res,
        'Product retrieved successfully',
        { product },
      );
    } catch (error) {
      logger.error('Get product by ID error:', error);
      
      if (error.code === 'PRODUCT_005') {
        return errorResponse(
          res,
          error.message,
          null,
          HTTP_STATUS.NOT_FOUND,
        );
      }
      
      if (error.code === 'PRODUCT_006') {
        return errorResponse(
          res,
          error.message,
          null,
          HTTP_STATUS.FORBIDDEN,
        );
      }
      
      return errorResponse(
        res,
        'Failed to retrieve product',
        null,
        HTTP_STATUS.INTERNAL_SERVER_ERROR,
      );
    }
  }
  
  /**
   * Update product
   * PUT /api/v1/products/:id
   */
  async updateProduct(req, res) {
    try {
      const productId = parseInt(req.params.id, 10);
      const shopId = req.user.shop_id;
      const {
        category_id, name, sku, barcode, unit, selling_price,
        default_purchase_price, minimum_stock, reorder_level, target_stock_days,
      } = req.body;
      
      if (!shopId) {
        return errorResponse(
          res,
          'Shop not found',
          null,
          HTTP_STATUS.BAD_REQUEST,
        );
      }
      
      const product = await productService.updateProduct(
        productId,
        shopId,
        {
          category_id, name, sku, barcode, unit, selling_price,
          default_purchase_price, minimum_stock, reorder_level, target_stock_days,
        },
      );
      
      return successResponse(
        res,
        'Product updated successfully',
        { product },
      );
    } catch (error) {
      logger.error('Update product error:', error);
      
      if (['PRODUCT_001', 'PRODUCT_002', 'PRODUCT_003', 'PRODUCT_004', 'PRODUCT_009', 'PRODUCT_010'].includes(error.code)) {
        return errorResponse(
          res,
          error.message,
          null,
          HTTP_STATUS.BAD_REQUEST,
        );
      }
      
      if (error.code === 'PRODUCT_005') {
        return errorResponse(
          res,
          error.message,
          null,
          HTTP_STATUS.NOT_FOUND,
        );
      }
      
      if (error.code === 'PRODUCT_006') {
        return errorResponse(
          res,
          error.message,
          null,
          HTTP_STATUS.FORBIDDEN,
        );
      }
      
      return errorResponse(
        res,
        'Failed to update product',
        null,
        HTTP_STATUS.INTERNAL_SERVER_ERROR,
      );
    }
  }
  
  /**
   * Delete product
   * DELETE /api/v1/products/:id
   */
  async deleteProduct(req, res) {
    try {
      const productId = parseInt(req.params.id, 10);
      const shopId = req.user.shop_id;
      
      if (!shopId) {
        return errorResponse(
          res,
          'Shop not found',
          null,
          HTTP_STATUS.BAD_REQUEST,
        );
      }
      
      await productService.deleteProduct(productId, shopId);
      
      return successResponse(res, 'Product deactivated successfully');
    } catch (error) {
      logger.error('Delete product error:', error);
      
      if (error.code === 'PRODUCT_005') {
        return errorResponse(
          res,
          error.message,
          null,
          HTTP_STATUS.NOT_FOUND,
        );
      }
      
      if (error.code === 'PRODUCT_006') {
        return errorResponse(
          res,
          error.message,
          null,
          HTTP_STATUS.FORBIDDEN,
        );
      }
      
      if (['PRODUCT_007', 'PRODUCT_008'].includes(error.code)) {
        return errorResponse(
          res,
          error.message,
          null,
          HTTP_STATUS.BAD_REQUEST,
        );
      }
      
      return errorResponse(
        res,
        'Failed to delete product',
        null,
        HTTP_STATUS.INTERNAL_SERVER_ERROR,
      );
    }
  }
  
  /**
   * Get low stock products
   * GET /api/v1/products/low-stock
   */
  async getLowStockProducts(req, res) {
    try {
      const shopId = req.user.shop_id;
      
      if (!shopId) {
        return errorResponse(
          res,
          'Shop not found',
          null,
          HTTP_STATUS.BAD_REQUEST,
        );
      }
      
      const products = await productService.getLowStockProducts(shopId);
      
      return successResponse(
        res,
        'Low stock products retrieved successfully',
        { products },
      );
    } catch (error) {
      logger.error('Get low stock products error:', error);
      
      return errorResponse(
        res,
        'Failed to retrieve low stock products',
        null,
        HTTP_STATUS.INTERNAL_SERVER_ERROR,
      );
    }
  }
}

module.exports = new ProductController();
