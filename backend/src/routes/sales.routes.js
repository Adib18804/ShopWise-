const express = require('express');
const salesController = require('../controllers/sales.controller.js');
const { authenticate } = require('../middleware/auth.middleware.js');

const router = express.Router();
router.post('/', authenticate, salesController.processSale);

module.exports = router;