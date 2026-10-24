const { validationResult } = require('express-validator');
const { validationErrorResponse } = require('../utils/response.util.js');

/**
 * Middleware to handle validation results
 */
function validate(req, res, next) {
  const errors = validationResult(req);
  
  if (!errors.isEmpty()) {
    const formattedErrors = errors.array().map((error) => ({
      field: error.path || error.param,
      message: error.msg,
    }));
    
    return validationErrorResponse(res, formattedErrors);
  }
  
  next();
}

module.exports = validate;
