const { body, param, query } = require('express-validator');

/**
 * Validation rules for creating product
 */
const createProductValidation = [
  body('name')
    .trim()
    .notEmpty().withMessage('Product name is required')
    .isLength({ min: 2, max: 200 }).withMessage('Product name must be between 2 and 200 characters'),
  
  body('category_id')
    .optional({ nullable: true })
    .isInt({ min: 1 }).withMessage('Valid category ID is required'),

  body('sku')
    .optional({ nullable: true, checkFalsy: true })
    .trim()
    .isLength({ max: 100 }).withMessage('SKU must not exceed 100 characters'),
  
  body('barcode')
    .optional()
    .trim()
    .isLength({ max: 100 }).withMessage('Barcode must not exceed 100 characters'),
  
  body('unit')
    .trim()
    .notEmpty().withMessage('Unit is required')
    .isIn(['piece', 'kg', 'liter', 'packet', 'box', 'dozen']).withMessage('Invalid unit'),
  
  body('selling_price')
    .notEmpty().withMessage('Selling price is required')
    .isFloat({ min: 0 }).withMessage('Selling price must be 0 or greater'),

  body('default_purchase_price')
    .notEmpty().withMessage('Default purchase price is required')
    .isFloat({ min: 0 }).withMessage('Default purchase price must be 0 or greater'),

  body('minimum_stock')
    .optional()
    .isFloat({ min: 0 }).withMessage('Minimum stock must be 0 or greater'),

  body('reorder_level')
    .optional()
    .isFloat({ min: 0 }).withMessage('Reorder level must be 0 or greater'),

  body('target_stock_days')
    .optional()
    .isInt({ min: 1 }).withMessage('Target stock days must be at least 1'),
];

/**
 * Validation rules for updating product
 */
const updateProductValidation = [
  body().custom((value) => {
    const fields = Object.keys(value || {});
    const allowed = new Set([
      'category_id', 'name', 'sku', 'barcode', 'unit', 'selling_price',
      'default_purchase_price', 'minimum_stock', 'reorder_level', 'target_stock_days',
    ]);
    if (!fields.length) throw new Error('At least one product field is required');
    if (fields.some(field => !allowed.has(field))) throw new Error('Update contains unsupported fields');
    if (value.minimum_stock !== undefined && value.reorder_level !== undefined) {
      throw new Error('Provide minimum_stock or legacy reorder_level, not both');
    }
    return true;
  }),
  body('name')
    .optional()
    .trim()
    .isLength({ min: 2, max: 200 }).withMessage('Product name must be between 2 and 200 characters'),
  
  body('category_id')
    .optional({ nullable: true })
    .isInt({ min: 1 }).withMessage('Valid category ID is required'),
  
  body('barcode')
    .optional()
    .trim()
    .isLength({ max: 100 }).withMessage('Barcode must not exceed 100 characters'),
  
  body('unit')
    .optional()
    .trim()
    .isIn(['piece', 'kg', 'liter', 'packet', 'box', 'dozen']).withMessage('Invalid unit'),
  
  body('sku')
    .optional({ nullable: true })
    .trim()
    .isLength({ max: 100 }).withMessage('SKU must not exceed 100 characters'),

  body('selling_price')
    .optional()
    .isFloat({ min: 0 }).withMessage('Selling price must be 0 or greater'),

  body('default_purchase_price')
    .optional()
    .isFloat({ min: 0 }).withMessage('Default purchase price must be 0 or greater'),

  body('minimum_stock')
    .optional()
    .isFloat({ min: 0 }).withMessage('Minimum stock must be 0 or greater'),

  body('reorder_level')
    .optional()
    .isFloat({ min: 0 }).withMessage('Reorder level must be 0 or greater'),

  body('target_stock_days')
    .optional()
    .isInt({ min: 1 }).withMessage('Target stock days must be at least 1'),
];

/**
 * Validation rules for product ID parameter
 */
const productIdValidation = [
  param('id')
    .isInt({ min: 1 }).withMessage('Invalid product ID'),
];

/**
 * Validation rules for product search
 */
const searchProductValidation = [
  query('q')
    .optional()
    .trim()
    .isLength({ min: 1 }).withMessage('Search query must not be empty'),
  
  query('category_id')
    .optional()
    .isInt({ min: 1 }).withMessage('Invalid category ID'),
  
  query('limit')
    .optional()
    .isInt({ min: 1, max: 100 }).withMessage('Limit must be between 1 and 100'),
  
  query('offset')
    .optional()
    .isInt({ min: 0 }).withMessage('Offset must be non-negative'),
];

module.exports = {
  createProductValidation,
  updateProductValidation,
  productIdValidation,
  searchProductValidation,
};
