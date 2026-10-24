const salesService = require('../services/sales.service.js');
const { successResponse, errorResponse } = require('../utils/response.util.js');

/** Process a sale for the authenticated user's shop. */
const processSale = async (req, res, next) => {
  try {
    const { shop_id: shopId, id: userId } = req.user;
    const invoice = await salesService.processSale(shopId, userId, req.body);
    return successResponse(res, 'Sale processed successfully', invoice, 201);
  } catch (error) {
    if ([400, 404, 409].includes(error.statusCode)) {
      return errorResponse(res, error.message, null, error.statusCode);
    }
    return next(error);
  }
};

module.exports = { processSale };