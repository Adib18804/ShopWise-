const express = require('express');
const router = express.Router();
const batchController = require('../controllers/batch.controller');
const {
  addBatchRules,
  updateBatchRules,
  getProductBatchesRules,
  getStockHistoryRules,
  batchIdRules,
} = require('../validators/batch.validator');
const validate = require('../middleware/validate.middleware');
const { authenticate } = require('../middleware/auth.middleware');

// All batch routes require authentication
router.use(authenticate);

// Product batch routes
router.post(
  '/products/:id/batches',
  addBatchRules,
  validate,
  batchController.addBatch
);

router.get(
  '/products/:id/batches',
  getProductBatchesRules,
  validate,
  batchController.getProductBatches
);

router.get(
  '/products/:id/stock-history',
  getStockHistoryRules,
  validate,
  batchController.getStockHistory
);

router.get(
  '/products/:id/fefo',
  getStockHistoryRules,
  validate,
  batchController.getFEFORecommendations
);

// Individual batch routes
router.get(
  '/batches/:id',
  batchIdRules,
  validate,
  batchController.getBatchById
);

router.put(
  '/batches/:id',
  updateBatchRules,
  validate,
  batchController.updateBatch
);

router.delete(
  '/batches/:id',
  batchIdRules,
  validate,
  batchController.deleteBatch
);

module.exports = router;
