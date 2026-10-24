const { HTTP_STATUS } = require('../config/constants.js');

/**
 * Standard success response
 */
function successResponse(res, message, data = null, statusCode = HTTP_STATUS.OK) {
  const response = {
    success: true,
    message,
  };

  if (data !== null) {
    response.data = data;
  }

  return res.status(statusCode).json(response);
}

/**
 * Standard error response
 */
function errorResponse(res, message, errors = null, statusCode = HTTP_STATUS.BAD_REQUEST) {
  const response = {
    success: false,
    message,
  };

  if (errors !== null) {
    response.errors = errors;
  }

  return res.status(statusCode).json(response);
}

/**
 * Validation error response
 */
function validationErrorResponse(res, errors) {
  return errorResponse(
    res,
    'Validation failed',
    errors,
    HTTP_STATUS.UNPROCESSABLE_ENTITY,
  );
}

/**
 * Unauthorized error response
 */
function unauthorizedResponse(res, message = 'Unauthorized') {
  return errorResponse(res, message, null, HTTP_STATUS.UNAUTHORIZED);
}

/**
 * Not found error response
 */
function notFoundResponse(res, message = 'Resource not found') {
  return errorResponse(res, message, null, HTTP_STATUS.NOT_FOUND);
}

/**
 * Internal server error response
 */
function serverErrorResponse(res, message = 'Internal server error') {
  return errorResponse(res, message, null, HTTP_STATUS.INTERNAL_SERVER_ERROR);
}

module.exports = {
  successResponse,
  errorResponse,
  validationErrorResponse,
  unauthorizedResponse,
  notFoundResponse,
  serverErrorResponse,
};
