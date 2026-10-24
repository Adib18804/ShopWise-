const express = require('express');

const router = express.Router();

const authRoutes = require('./auth.routes.js');
const shopRoutes = require('./shop.routes.js');
const categoryRoutes = require('./category.routes.js');
const productRoutes = require('./product.routes.js');
const batchRoutes = require('./batch.routes.js');
const salesRoutes = require('./sales.routes.js');
const reportsRoutes = require('./reports.routes.js');

router.use('/auth', authRoutes);
router.use('/shop', shopRoutes);
router.use('/categories', categoryRoutes);
router.use('/products', productRoutes);
router.use('/', batchRoutes);
router.use('/sales', salesRoutes);
router.use('/reports', reportsRoutes);

router.get('/', (req, res) => {
  res.json({
    success: true,
    message: 'ShopWise API v1',
    endpoints: {
      auth: '/api/v1/auth',
      shop: '/api/v1/shop',
      categories: '/api/v1/categories',
      products: '/api/v1/products',
      sales: '/api/v1/sales',
      reports: '/api/v1/reports/daily-summary',
    },
  });
});

module.exports = router;