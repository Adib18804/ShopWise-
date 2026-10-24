const batchService = require('../services/batch.service');
const { successResponse } = require('../utils/response.util');

/**
 * Add new stock batch
 * POST /api/v1/products/:id/batches
 */
const addBatch = async (req, res, next) => {
  try {
    const productId = parseInt(req.params.id);
    const shopId = req.user.shop_id;

    const result = await batchService.addBatch(productId, req.body, shopId);

    return successResponse(res, 'Stock batch added successfully', result, 201);
  } catch (error) {
    next(error);
  }
};

/**
 * Get product batches
 * GET /api/v1/products/:id/batches
 */
const getProductBatches = async (req, res, next) => {
  try {
    const productId = parseInt(req.params.id);
    const shopId = req.user.shop_id;
    const includeDepleted = req.query.include_depleted === 'true';

    const result = await batchService.getProductBatches(
      productId,
      includeDepleted,
      shopId
    );

    return successResponse(res, 'Batches retrieved successfully', result);
  } catch (error) {
    next(error);
  }
};

/**
 * Get batch by ID
 * GET /api/v1/batches/:id
 */
const getBatchById = async (req, res, next) => {
  try {
    const batchId = parseInt(req.params.id);
    const shopId = req.user.shop_id;

    const batch = await batchService.getBatchById(batchId, shopId);

    return successResponse(res, 'Batch retrieved successfully', { batch });
  } catch (error) {
    next(error);
  }
};

/**
 * Update batch
 * PUT /api/v1/batches/:id
 */
const updateBatch = async (req, res, next) => {
  try {
    const batchId = parseInt(req.params.id);
    const shopId = req.user.shop_id;

    const batch = await batchService.updateBatch(batchId, req.body, shopId);

    return successResponse(res, 'Batch updated successfully', { batch });
  } catch (error) {
    next(error);
  }
};

/**
 * Delete batch
 * DELETE /api/v1/batches/:id
 */
const deleteBatch = async (req, res, next) => {
  try {
    const batchId = parseInt(req.params.id);
    const shopId = req.user.shop_id;

    await batchService.deleteBatch(batchId, shopId);

    return successResponse(res, 'Batch deactivated successfully');
  } catch (error) {
    next(error);
  }
};

/**
 * Get stock transaction history
 * GET /api/v1/products/:id/stock-history
 */
const getStockHistory = async (req, res, next) => {
  try {
    const productId = parseInt(req.params.id);
    const shopId = req.user.shop_id;
    const limit = parseInt(req.query.limit) || 50;
    const offset = parseInt(req.query.offset) || 0;

    const result = await batchService.getStockHistory(
      productId,
      limit,
      offset,
      shopId
    );

    return successResponse(res, 'Stock history retrieved successfully', result);
  } catch (error) {
    next(error);
  }
};

/**
 * Get FEFO recommendations
 * GET /api/v1/products/:id/fefo
 */
const getFEFORecommendations = async (req, res, next) => {
  try {
    const productId = parseInt(req.params.id);
    const shopId = req.user.shop_id;

    const result = await batchService.getFEFORecommendations(productId, shopId);

    return successResponse(res, 'FEFO recommendations retrieved successfully', result);
  } catch (error) {
    next(error);
  }
};

module.exports = {
  addBatch,
  getProductBatches,
  getBatchById,
  updateBatch,
  deleteBatch,
  getStockHistory,
  getFEFORecommendations,
};
