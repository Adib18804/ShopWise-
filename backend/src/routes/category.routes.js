const express = require('express');
const categoryController = require('../controllers/category.controller.js');
const { authenticate } = require('../middleware/auth.middleware.js');
const validate = require('../middleware/validate.middleware.js');
const {
  createCategoryValidation,
  updateCategoryValidation,
  categoryIdValidation,
} = require('../validators/category.validator.js');

const router = express.Router();

// All category routes require authentication
router.use(authenticate);

/**
 * @route   POST /api/v1/categories
 * @desc    Create new category
 * @access  Private
 */
router.post(
  '/',
  createCategoryValidation,
  validate,
  categoryController.createCategory.bind(categoryController),
);

/**
 * @route   GET /api/v1/categories
 * @desc    Get all categories for shop
 * @access  Private
 */
router.get(
  '/',
  categoryController.getCategories.bind(categoryController),
);

/**
 * @route   GET /api/v1/categories/:id
 * @desc    Get category by ID
 * @access  Private
 */
router.get(
  '/:id',
  categoryIdValidation,
  validate,
  categoryController.getCategoryById.bind(categoryController),
);

/**
 * @route   PUT /api/v1/categories/:id
 * @desc    Update category
 * @access  Private
 */
router.put(
  '/:id',
  categoryIdValidation,
  updateCategoryValidation,
  validate,
  categoryController.updateCategory.bind(categoryController),
);

/**
 * @route   DELETE /api/v1/categories/:id
 * @desc    Delete category
 * @access  Private
 */
router.delete(
  '/:id',
  categoryIdValidation,
  validate,
  categoryController.deleteCategory.bind(categoryController),
);

module.exports = router;
