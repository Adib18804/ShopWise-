const authService = require('../services/auth.service.js');
const { successResponse, errorResponse, unauthorizedResponse } = require('../utils/response.util.js');
const { HTTP_STATUS } = require('../config/constants.js');
const logger = require('../utils/logger.util.js');

/**
 * Authentication controller
 */
class AuthController {
  /**
   * Register new user
   * POST /api/v1/auth/register
   */
  async register(req, res) {
    try {
      const { name, phone, email, password, preferred_language } = req.body;
      
      const result = await authService.register({
        name,
        phone,
        email,
        password,
        preferred_language,
      });
      
      return successResponse(
        res,
        'Registration successful',
        result,
        HTTP_STATUS.CREATED,
      );
    } catch (error) {
      logger.error('Registration error:', error);
      
      if (error.code === 'AUTH_005') {
        return errorResponse(
          res,
          error.message,
          [{ field: 'email', message: 'Email already exists' }],
          HTTP_STATUS.BAD_REQUEST,
        );
      }
      
      if (error.code === 'AUTH_006') {
        return errorResponse(
          res,
          error.message,
          [{ field: 'phone', message: 'Phone number already exists' }],
          HTTP_STATUS.BAD_REQUEST,
        );
      }
      
      return errorResponse(
        res,
        'Registration failed',
        null,
        HTTP_STATUS.INTERNAL_SERVER_ERROR,
      );
    }
  }
  
  /**
   * Login user
   * POST /api/v1/auth/login
   */
  async login(req, res) {
    try {
      const { identifier, password } = req.body;
      
      const result = await authService.login(identifier, password);
      
      return successResponse(res, 'Login successful', result);
    } catch (error) {
      logger.error('Login error:', error);
      
      if (error.code === 'AUTH_001') {
        return unauthorizedResponse(res, 'Invalid credentials');
      }
      
      return errorResponse(
        res,
        'Login failed',
        null,
        HTTP_STATUS.INTERNAL_SERVER_ERROR,
      );
    }
  }
  
  /**
   * Get current user
   * GET /api/v1/auth/me
   */
  async me(req, res) {
    try {
      const user = await authService.getCurrentUser(req.user.id);
      
      return successResponse(res, 'User retrieved successfully', { user });
    } catch (error) {
      logger.error('Get current user error:', error);
      
      if (error.code === 'AUTH_004') {
        return unauthorizedResponse(res, 'User not found');
      }
      
      return errorResponse(
        res,
        'Failed to retrieve user',
        null,
        HTTP_STATUS.INTERNAL_SERVER_ERROR,
      );
    }
  }
  
  /**
   * Logout user
   * POST /api/v1/auth/logout
   */
  async logout(req, res) {
    try {
      // JWT is stateless, so we just return success
      // Client should remove token from storage
      return successResponse(res, 'Logout successful');
    } catch (error) {
      logger.error('Logout error:', error);
      return errorResponse(
        res,
        'Logout failed',
        null,
        HTTP_STATUS.INTERNAL_SERVER_ERROR,
      );
    }
  }
  
  /**
   * Forgot password
   * POST /api/v1/auth/forgot-password
   */
  async forgotPassword(req, res) {
    try {
      const { email } = req.body;
      
      // TODO: Implement password reset token generation and email sending
      // For now, return success (to be implemented in future)
      
      return successResponse(
        res,
        'If an account with that email exists, password reset instructions have been sent',
      );
    } catch (error) {
      logger.error('Forgot password error:', error);
      return errorResponse(
        res,
        'Failed to process password reset request',
        null,
        HTTP_STATUS.INTERNAL_SERVER_ERROR,
      );
    }
  }
  
  /**
   * Reset password
   * POST /api/v1/auth/reset-password
   */
  async resetPassword(req, res) {
    try {
      const { token, new_password } = req.body;
      
      // TODO: Implement password reset token verification and password update
      // For now, return not implemented (to be implemented in future)
      
      return errorResponse(
        res,
        'Password reset not yet implemented',
        null,
        HTTP_STATUS.NOT_FOUND,
      );
    } catch (error) {
      logger.error('Reset password error:', error);
      return errorResponse(
        res,
        'Failed to reset password',
        null,
        HTTP_STATUS.INTERNAL_SERVER_ERROR,
      );
    }
  }
}

module.exports = new AuthController();
