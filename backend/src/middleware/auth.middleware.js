const { verifyToken } = require('../utils/jwt.util.js');
const { unauthorizedResponse } = require('../utils/response.util.js');
const logger = require('../utils/logger.util.js');

/**
 * Authentication middleware
 * Verifies JWT token and attaches user data to request
 */
function authenticate(req, res, next) {
  try {
    // Get token from Authorization header
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return unauthorizedResponse(res, 'No token provided');
    }
    
    const token = authHeader.substring(7); // Remove 'Bearer ' prefix
    
    if (!token) {
      return unauthorizedResponse(res, 'No token provided');
    }
    
    // Verify token
    const decoded = verifyToken(token);
    
    // Attach user data to request
    req.user = {
      id: decoded.user_id,
      shop_id: decoded.shop_id,
      email: decoded.email,
    };
    
    next();
  } catch (error) {
    logger.error('Authentication error:', error.message);
    
    if (error.message === 'Token expired') {
      return unauthorizedResponse(res, 'Token expired');
    }
    
    if (error.message === 'Invalid token') {
      return unauthorizedResponse(res, 'Invalid token');
    }
    
    return unauthorizedResponse(res, 'Authentication failed');
  }
}

/**
 * Optional authentication middleware
 * Attaches user data if token is present, but doesn't fail if missing
 */
function optionalAuthenticate(req, res, next) {
  try {
    const authHeader = req.headers.authorization;
    
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.substring(7);
      
      if (token) {
        const decoded = verifyToken(token);
        req.user = {
          id: decoded.user_id,
          shop_id: decoded.shop_id,
          email: decoded.email,
        };
      }
    }
    
    next();
  } catch (error) {
    // Ignore errors for optional authentication
    next();
  }
}

module.exports = {
  authenticate,
  optionalAuthenticate,
};
