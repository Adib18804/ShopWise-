jest.mock('../src/services/batch.service', () => ({
  addBatch: jest.fn(), getProductBatches: jest.fn(), getBatchById: jest.fn(),
  updateBatch: jest.fn(), deleteBatch: jest.fn(), getStockHistory: jest.fn(),
  getFEFORecommendations: jest.fn(),
}));

const express = require('express');
const request = require('supertest');
const jwt = require('jsonwebtoken');
const config = require('../src/config/env');
const service = require('../src/services/batch.service');
const batchRoutes = require('../src/routes/batch.routes');

const app = express();
app.use(express.json());
app.use('/api/v1', batchRoutes);
app.use((error, req, res, next) => res.status(error.statusCode || 500).json({ message: error.message }));
const token = jwt.sign({ user_id: 6, shop_id: 9, email: 'shop@example.com' }, config.jwt.secret);

beforeEach(() => jest.clearAllMocks());

test('batch route requires authentication', async () => {
  const response = await request(app).get('/api/v1/products/1/batches');
  expect(response.status).toBe(401);
});

test('batch route passes authenticated shop context to the service', async () => {
  service.getProductBatches.mockResolvedValue({ product: { id: 1 }, batches: [] });
  const response = await request(app)
    .get('/api/v1/products/1/batches?include_depleted=true')
    .set('Authorization', `Bearer ${token}`);
  expect(response.status).toBe(200);
  expect(service.getProductBatches).toHaveBeenCalledWith(1, true, 9);
});

test('batch route rejects malformed date-only input before service access', async () => {
  const response = await request(app)
    .post('/api/v1/products/1/batches')
    .set('Authorization', `Bearer ${token}`)
    .send({ purchase_date: '2026-02-31', expiry_date: null, quantity: 2, purchase_price: 10 });
  expect(response.status).toBe(422);
  expect(service.addBatch).not.toHaveBeenCalled();
});
