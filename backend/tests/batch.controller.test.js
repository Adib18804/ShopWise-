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
const routes = require('../src/routes/batch.routes');

const app = express();
app.use(express.json());
app.use('/api/v1', routes);
app.use((error, req, res, next) => res.status(error.statusCode || 500).json({ success: false, message: error.message }));
const token = () => jwt.sign({ user_id: 4, shop_id: 7, email: 'test@example.test' }, config.jwt.secret, { algorithm: 'HS256' });
const auth = (call) => call.set('Authorization', `Bearer ${token()}`);
const validBatch = { purchase_date: '2026-10-20', expiry_date: '2026-11-20', quantity: 5, purchase_price: 40 };

describe('batch controller HTTP behavior', () => {
  beforeEach(() => jest.clearAllMocks());

  test('requires authentication and validates batch IDs and payloads', async () => {
    await request(app).get('/api/v1/batches/1').expect(401);
    expect((await auth(request(app).post('/api/v1/products/2/batches')).send({})).status).toBe(422);
    expect((await auth(request(app).get('/api/v1/products/0/batches'))).status).toBe(422);
    expect((await auth(request(app).put('/api/v1/batches/2')).send({ unsupported: true })).status).toBe(422);
    expect(service.addBatch).not.toHaveBeenCalled();
  });

  test('adds and lists product batches with parsed tenant and query arguments', async () => {
    service.addBatch.mockResolvedValueOnce({ batch: { id: 10 } });
    const added = await auth(request(app).post('/api/v1/products/2/batches')).send(validBatch);
    expect(added.status).toBe(201);
    expect(service.addBatch).toHaveBeenCalledWith(2, validBatch, 7);

    service.getProductBatches.mockResolvedValueOnce([{ id: 10 }]);
    const listed = await auth(request(app).get('/api/v1/products/2/batches?include_depleted=true'));
    expect(listed.status).toBe(200);
    expect(service.getProductBatches).toHaveBeenCalledWith(2, true, 7);
    service.getProductBatches.mockResolvedValueOnce([]);
    await auth(request(app).get('/api/v1/products/2/batches?include_depleted=false')).expect(200);
    expect(service.getProductBatches).toHaveBeenLastCalledWith(2, false, 7);
  });

  test('gets, updates, and deactivates a batch', async () => {
    service.getBatchById.mockResolvedValueOnce({ id: 10 });
    expect((await auth(request(app).get('/api/v1/batches/10'))).status).toBe(200);
    expect(service.getBatchById).toHaveBeenCalledWith(10, 7);

    service.updateBatch.mockResolvedValueOnce({ id: 10, quantity: 8 });
    const updated = await auth(request(app).put('/api/v1/batches/10')).send({ quantity: 8 });
    expect(updated.status).toBe(200);
    expect(service.updateBatch).toHaveBeenCalledWith(10, { quantity: 8 }, 7);

    service.deleteBatch.mockResolvedValueOnce(true);
    expect((await auth(request(app).delete('/api/v1/batches/10'))).status).toBe(200);
    expect(service.deleteBatch).toHaveBeenCalledWith(10, 7);
  });

  test('gets stock history with default and explicit pagination, plus FEFO recommendations', async () => {
    service.getStockHistory.mockResolvedValueOnce({ rows: [] });
    expect((await auth(request(app).get('/api/v1/products/2/stock-history'))).status).toBe(200);
    expect(service.getStockHistory).toHaveBeenCalledWith(2, 50, 0, 7);
    service.getStockHistory.mockResolvedValueOnce({ rows: [{ id: 1 }] });
    await auth(request(app).get('/api/v1/products/2/stock-history?limit=10&offset=3')).expect(200);
    expect(service.getStockHistory).toHaveBeenLastCalledWith(2, 10, 3, 7);

    service.getFEFORecommendations.mockResolvedValueOnce([{ batch_id: 10 }]);
    expect((await auth(request(app).get('/api/v1/products/2/fefo'))).status).toBe(200);
    expect(service.getFEFORecommendations).toHaveBeenCalledWith(2, 7);
  });

  test('forwards service errors to the Express error handler', async () => {
    service.addBatch.mockRejectedValueOnce(Object.assign(new Error('bad batch'), { statusCode: 400 }));
    expect((await auth(request(app).post('/api/v1/products/2/batches')).send(validBatch)))
      .toMatchObject({ status: 400, body: { message: 'bad batch' } });
    service.getBatchById.mockRejectedValueOnce(Object.assign(new Error('foreign batch'), { statusCode: 403 }));
    expect((await auth(request(app).get('/api/v1/batches/10'))).status).toBe(403);
    service.updateBatch.mockRejectedValueOnce(Object.assign(new Error('not found'), { statusCode: 404 }));
    expect((await auth(request(app).put('/api/v1/batches/10')).send({ quantity: 8 })).status).toBe(404);
    service.deleteBatch.mockRejectedValueOnce(new Error('database failure'));
    expect((await auth(request(app).delete('/api/v1/batches/10'))).status).toBe(500);
  });
});
