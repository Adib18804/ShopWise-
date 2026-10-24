const { body, param, query } = require('express-validator');
const { getBusinessDate, isDateOnly } = require('../utils/date.util');

const positiveId = (message) => param('id').isInt({ min: 1 }).withMessage(message);
const validDate = (field, required = false) => {
  let rule = body(field);
  if (required) rule = rule.notEmpty().withMessage(`${field} is required`);
  else rule = rule.optional({ nullable: true });
  return rule.custom(value => {
    if (value == null || value === '') return !required;
    if (!isDateOnly(value)) throw new Error(`${field} must be a valid YYYY-MM-DD date`);
    return true;
  });
};

const addBatchRules = [
  positiveId('Valid product ID is required'),
  body('batch_number').optional({ nullable: true, checkFalsy: true }).trim()
    .isLength({ max: 100 }).withMessage('Batch number must not exceed 100 characters'),
  validDate('purchase_date', true),
  body('purchase_date').custom(value => {
    if (isDateOnly(value) && value > getBusinessDate()) {
      throw new Error('Purchase date cannot be in the future');
    }
    return true;
  }),
  validDate('expiry_date'),
  body('expiry_date').custom((value, { req }) => {
    if (value && isDateOnly(value) && isDateOnly(req.body.purchase_date)
      && value <= req.body.purchase_date) {
      throw new Error('Expiry date must be after purchase date');
    }
    return true;
  }),
  body('quantity').notEmpty().withMessage('Quantity is required')
    .isFloat({ min: 0.01 }).withMessage('Quantity must be greater than 0'),
  body('purchase_price').notEmpty().withMessage('Purchase price is required')
    .isFloat({ min: 0 }).withMessage('Purchase price must be 0 or greater'),
];

const updateBatchRules = [
  positiveId('Valid batch ID is required'),
  body().custom((value) => {
    const keys = Object.keys(value || {});
    const allowed = new Set(['quantity', 'purchase_price', 'expiry_date', 'notes']);
    if (!keys.length) throw new Error('At least one batch field is required');
    if (keys.some(key => !allowed.has(key))) throw new Error('Update contains unsupported fields');
    return true;
  }),
  body('quantity').optional().isFloat({ min: 0 }).withMessage('Quantity must be 0 or greater'),
  body('purchase_price').optional().isFloat({ min: 0 }).withMessage('Purchase price must be 0 or greater'),
  validDate('expiry_date'),
  body('notes').optional({ nullable: true }).trim()
    .isLength({ max: 500 }).withMessage('Notes must not exceed 500 characters'),
];

const getProductBatchesRules = [
  positiveId('Valid product ID is required'),
  query('include_depleted').optional().isBoolean()
    .withMessage('include_depleted must be a boolean value'),
];

const getStockHistoryRules = [
  positiveId('Valid product ID is required'),
  query('limit').optional().isInt({ min: 1, max: 100 }).withMessage('Limit must be between 1 and 100'),
  query('offset').optional().isInt({ min: 0 }).withMessage('Offset must be 0 or greater'),
];

const batchIdRules = [positiveId('Valid batch ID is required')];

module.exports = {
  addBatchRules, updateBatchRules, getProductBatchesRules,
  getStockHistoryRules, batchIdRules,
};
