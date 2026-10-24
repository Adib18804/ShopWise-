const { body } = require('express-validator');

/**
 * Validation rules for registration
 */
const registerValidation = [
  body('name')
    .trim()
    .notEmpty().withMessage('Name is required')
    .isLength({ min: 2, max: 100 }).withMessage('Name must be between 2 and 100 characters'),
  
  body('phone')
    .trim()
    .notEmpty().withMessage('Phone number is required')
    .matches(/^01[3-9]\d{8}$/).withMessage('Invalid Bangladesh phone number format'),
  
  body('email')
    .trim()
    .notEmpty().withMessage('Email is required')
    .isEmail().withMessage('Invalid email format')
    .normalizeEmail(),
  
  body('password')
    .notEmpty().withMessage('Password is required')
    .isLength({ min: 8, max: 50 }).withMessage('Password must be between 8 and 50 characters')
    .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/).withMessage('Password must contain at least one uppercase letter, one lowercase letter, and one number'),
  
  body('preferred_language')
    .optional()
    .isIn(['en', 'bn']).withMessage('Language must be either en or bn'),
];

/**
 * Validation rules for login
 */
const loginValidation = [
  body('identifier')
    .trim()
    .notEmpty().withMessage('Email or phone number is required'),
  
  body('password')
    .notEmpty().withMessage('Password is required'),
];

/**
 * Validation rules for forgot password
 */
const forgotPasswordValidation = [
  body('email')
    .trim()
    .notEmpty().withMessage('Email is required')
    .isEmail().withMessage('Invalid email format')
    .normalizeEmail(),
];

/**
 * Validation rules for reset password
 */
const resetPasswordValidation = [
  body('token')
    .trim()
    .notEmpty().withMessage('Reset token is required'),
  
  body('new_password')
    .notEmpty().withMessage('New password is required')
    .isLength({ min: 8, max: 50 }).withMessage('Password must be between 8 and 50 characters')
    .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/).withMessage('Password must contain at least one uppercase letter, one lowercase letter, and one number'),
];

module.exports = {
  registerValidation,
  loginValidation,
  forgotPasswordValidation,
  resetPasswordValidation,
};
