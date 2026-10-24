const categoryService = require('../services/category.service.js');
const { successResponse, errorResponse } = require('../utils/response.util.js');
const { HTTP_STATUS } = require('../config/constants.js');
const logger = require('../utils/logger.util.js');

/**
 * Category controller
 */
class CategoryController {
  /**
   * Create new category
   * POST /api/v1/categories
   */
  async createCategory(req, res) {
    try {
      const { name, description } = req.body;
      const shopId = req.user.shop_id;
      
      if (!shopId) {
        return errorResponse(
          res,
          'Shop not found. Please create a shop first.',
          null,
          HTTP_STATUS.BAD_REQUEST,
        );
      }
      
      const category = await categoryService.createCategory(shopId, {
        name,
        description,
      });
      
      return successResponse(
        res,
        'Category created successfully',
        { category },
        HTTP_STATUS.CREATED,
      );
    } catch (error) {
      logger.error('Create category error:', error);
      
      if (error.code === 'CATEGORY_001') {
        return errorResponse(
          res,
          error.message,
          null,
          HTTP_STATUS.BAD_REQUEST,
        );
      }
      if (error.code === 'CATEGORY_002') {
        return errorResponse(res, error.message, null, HTTP_STATUS.NOT_FOUND);
      }
      
      return errorResponse(
        res,
        'Failed to create category',
        null,
        HTTP_STATUS.INTERNAL_SERVER_ERROR,
      );
    }
  }
  
  /**
   * Get all categories for shop
   * GET /api/v1/categories
   */
  async getCategories(req, res) {
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
      
      const categories = await categoryService.getShopCategories(shopId);
      
      return successResponse(
        res,
        'Categories retrieved successfully',
        { categories },
      );
    } catch (error) {
      logger.error('Get categories error:', error);
      
      return errorResponse(
        res,
        'Failed to retrieve categories',
        null,
        HTTP_STATUS.INTERNAL_SERVER_ERROR,
      );
    }
  }
  
  /**
   * Get category by ID
   * GET /api/v1/categories/:id
   */
  async getCategoryById(req, res) {
    try {
      const categoryId = parseInt(req.params.id, 10);
      const shopId = req.user.shop_id;
      
      if (!shopId) {
        return errorResponse(
          res,
          'Shop not found',
          null,
          HTTP_STATUS.BAD_REQUEST,
        );
      }
      
      const category = await categoryService.getCategoryById(categoryId, shopId);
      
      return successResponse(
        res,
        'Category retrieved successfully',
        { category },
      );
    } catch (error) {
      logger.error('Get category by ID error:', error);
      
      if (error.code === 'CATEGORY_002') {
        return errorResponse(
          res,
          error.message,
          null,
          HTTP_STATUS.NOT_FOUND,
        );
      }
      
      if (error.code === 'CATEGORY_003') {
        return errorResponse(
          res,
          error.message,
          null,
          HTTP_STATUS.FORBIDDEN,
        );
      }
      
      return errorResponse(
        res,
        'Failed to retrieve category',
        null,
        HTTP_STATUS.INTERNAL_SERVER_ERROR,
      );
    }
  }
  
  /**
   * Update category
   * PUT /api/v1/categories/:id
   */
  async updateCategory(req, res) {
    try {
      const categoryId = parseInt(req.params.id, 10);
      const shopId = req.user.shop_id;
      const { name, description } = req.body;
      
      if (!shopId) {
        return errorResponse(
          res,
          'Shop not found',
          null,
          HTTP_STATUS.BAD_REQUEST,
        );
      }
      
      const category = await categoryService.updateCategory(
        categoryId,
        shopId,
        { name, description },
      );
      
      return successResponse(
        res,
        'Category updated successfully',
        { category },
      );
    } catch (error) {
      logger.error('Update category error:', error);
      
      if (error.code === 'CATEGORY_001') {
        return errorResponse(
          res,
          error.message,
          null,
          HTTP_STATUS.BAD_REQUEST,
        );
      }
      
      if (error.code === 'CATEGORY_002') {
        return errorResponse(
          res,
          error.message,
          null,
          HTTP_STATUS.NOT_FOUND,
        );
      }
      
      if (error.code === 'CATEGORY_003') {
        return errorResponse(
          res,
          error.message,
          null,
          HTTP_STATUS.FORBIDDEN,
        );
      }
      
      return errorResponse(
        res,
        'Failed to update category',
        null,
        HTTP_STATUS.INTERNAL_SERVER_ERROR,
      );
    }
  }
  
  /**
   * Delete category
   * DELETE /api/v1/categories/:id
   */
  async deleteCategory(req, res) {
    try {
      const categoryId = parseInt(req.params.id, 10);
      const shopId = req.user.shop_id;
      
      if (!shopId) {
        return errorResponse(
          res,
          'Shop not found',
          null,
          HTTP_STATUS.BAD_REQUEST,
        );
      }
      
      await categoryService.deleteCategory(categoryId, shopId);
      
      return successResponse(res, 'Category deleted successfully');
    } catch (error) {
      logger.error('Delete category error:', error);
      
      if (error.code === 'CATEGORY_002') {
        return errorResponse(
          res,
          error.message,
          null,
          HTTP_STATUS.NOT_FOUND,
        );
      }
      
      if (error.code === 'CATEGORY_003') {
        return errorResponse(
          res,
          error.message,
          null,
          HTTP_STATUS.FORBIDDEN,
        );
      }
      
      if (error.code === 'CATEGORY_004') {
        return errorResponse(
          res,
          error.message,
          null,
          HTTP_STATUS.BAD_REQUEST,
        );
      }
      
      return errorResponse(
        res,
        'Failed to delete category',
        null,
        HTTP_STATUS.INTERNAL_SERVER_ERROR,
      );
    }
  }
}

module.exports = new CategoryController();
