const { body, param } = require('express-validator');

/**
 * Validation rules for creating shop
 */
const createShopValidation = [
  body('shop_name')
    .trim()
    .notEmpty().withMessage('Shop name is required')
    .isLength({ min: 2, max: 100 }).withMessage('Shop name must be between 2 and 100 characters'),
  
  body('address')
    .trim()
    .notEmpty().withMessage('Address is required')
    .isLength({ min: 5, max: 255 }).withMessage('Address must be between 5 and 255 characters'),
  
  body('phone')
    .trim()
    .notEmpty().withMessage('Phone number is required')
    .matches(/^01[3-9]\d{8}$/).withMessage('Invalid Bangladesh phone number format'),
  
  body('currency')
    .optional()
    .isIn(['BDT', 'USD', 'EUR']).withMessage('Currency must be BDT, USD, or EUR'),
];

/**
 * Validation rules for updating shop
 */
const updateShopValidation = [
  body('shop_name')
    .optional()
    .trim()
    .isLength({ min: 2, max: 100 }).withMessage('Shop name must be between 2 and 100 characters'),
  
  body('address')
    .optional()
    .trim()
    .isLength({ min: 5, max: 255 }).withMessage('Address must be between 5 and 255 characters'),
  
  body('phone')
    .optional()
    .trim()
    .matches(/^01[3-9]\d{8}$/).withMessage('Invalid Bangladesh phone number format'),
  
  body('currency')
    .optional()
    .isIn(['BDT', 'USD', 'EUR']).withMessage('Currency must be BDT, USD, or EUR'),
];

/**
 * Validation rules for shop ID parameter
 */
const shopIdValidation = [
  param('id')
    .isInt({ min: 1 }).withMessage('Invalid shop ID'),
];

module.exports = {
  createShopValidation,
  updateShopValidation,
  shopIdValidation,
};
