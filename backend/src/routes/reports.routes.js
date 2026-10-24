const express = require('express');
const reportsController = require('../controllers/reports.controller.js');
const { authenticate } = require('../middleware/auth.middleware.js');

const router = express.Router();
router.get('/daily-summary', authenticate, reportsController.getDailySummary);

module.exports = router;