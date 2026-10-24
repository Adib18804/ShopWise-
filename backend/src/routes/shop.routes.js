const express = require('express');
const shopController = require('../controllers/shop.controller.js');
const { authenticate } = require('../middleware/auth.middleware.js');
const validate = require('../middleware/validate.middleware.js');
const {
  createShopValidation,
  updateShopValidation,
  shopIdValidation,
} = require('../validators/shop.validator.js');

const router = express.Router();

// All shop routes require authentication
router.use(authenticate);

/**
 * @route   POST /api/v1/shop
 * @desc    Create new shop
 * @access  Private
 */
router.post(
  '/',
  createShopValidation,
  validate,
  shopController.createShop.bind(shopController),
);

/**
 * @route   GET /api/v1/shop
 * @desc    Get user's shop
 * @access  Private
 */
router.get(
  '/',
  shopController.getMyShop.bind(shopController),
);

/**
 * @route   GET /api/v1/shop/check
 * @desc    Check if user has shop
 * @access  Private
 */
router.get(
  '/check',
  shopController.checkShop.bind(shopController),
);

/**
 * @route   GET /api/v1/shop/:id
 * @desc    Get shop by ID
 * @access  Private
 */
router.get(
  '/:id',
  shopIdValidation,
  validate,
  shopController.getShopById.bind(shopController),
);

/**
 * @route   PUT /api/v1/shop/:id
 * @desc    Update shop
 * @access  Private
 */
router.put(
  '/:id',
  shopIdValidation,
  updateShopValidation,
  validate,
  shopController.updateShop.bind(shopController),
);

/**
 * @route   DELETE /api/v1/shop/:id
 * @desc    Delete shop
 * @access  Private
 */
router.delete(
  '/:id',
  shopIdValidation,
  validate,
  shopController.deleteShop.bind(shopController),
);

module.exports = router;
