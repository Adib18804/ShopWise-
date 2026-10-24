const reportsService = require('../services/reports.service.js');
const { successResponse, errorResponse } = require('../utils/response.util.js');

const getDailySummary = async (req, res, next) => {
  try {
    const summary = await reportsService.getDailySummary(req.user.shop_id);
    return successResponse(res, 'Daily report retrieved successfully', summary);
  } catch (error) {
    if (error.statusCode === 400) {
      return errorResponse(res, error.message, null, 400);
    }
    return next(error);
  }
};

module.exports = { getDailySummary };