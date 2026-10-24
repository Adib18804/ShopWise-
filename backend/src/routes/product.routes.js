const express = require('express');
const productController = require('../controllers/product.controller.js');
const { authenticate } = require('../middleware/auth.middleware.js');
const validate = require('../middleware/validate.middleware.js');
const {
  createProductValidation,
  updateProductValidation,
  productIdValidation,
  searchProductValidation,
} = require('../validators/product.validator.js');

const router = express.Router();

// All product routes require authentication
router.use(authenticate);

/**
 * @route   GET /api/v1/products/low-stock
 * @desc    Get low stock products
 * @access  Private
 */
router.get(
  '/low-stock',
  productController.getLowStockProducts.bind(productController),
);

/**
 * @route   POST /api/v1/products
 * @desc    Create new product
 * @access  Private
 */
router.post(
  '/',
  createProductValidation,
  validate,
  productController.createProduct.bind(productController),
);

/**
 * @route   GET /api/v1/products
 * @desc    Get all products for shop
 * @access  Private
 */
router.get(
  '/',
  searchProductValidation,
  validate,
  productController.getProducts.bind(productController),
);

/**
 * @route   GET /api/v1/products/:id
 * @desc    Get product by ID
 * @access  Private
 */
router.get(
  '/:id',
  productIdValidation,
  validate,
  productController.getProductById.bind(productController),
);

/**
 * @route   PUT /api/v1/products/:id
 * @desc    Update product
 * @access  Private
 */
router.put(
  '/:id',
  productIdValidation,
  updateProductValidation,
  validate,
  productController.updateProduct.bind(productController),
);

/**
 * @route   DELETE /api/v1/products/:id
 * @desc    Delete product
 * @access  Private
 */
router.delete(
  '/:id',
  productIdValidation,
  validate,
  productController.deleteProduct.bind(productController),
);

module.exports = router;
