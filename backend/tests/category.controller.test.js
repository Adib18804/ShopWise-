jest.mock('../src/services/category.service', () => ({
  createCategory: jest.fn(), getShopCategories: jest.fn(), getCategoryById: jest.fn(),
  updateCategory: jest.fn(), deleteCategory: jest.fn(),
}));
jest.mock('../src/utils/logger.util', () => ({ error: jest.fn(), info: jest.fn(), warn: jest.fn() }));

const express = require('express');
const request = require('supertest');
const jwt = require('jsonwebtoken');
const config = require('../src/config/env');
const service = require('../src/services/category.service');
const routes = require('../src/routes/category.routes');

const app = express();
app.use(express.json());
app.use('/api/v1/categories', routes);
const token = (shop_id = 7) => jwt.sign({ user_id: 4, shop_id, email: 'test@example.test' }, config.jwt.secret, { algorithm: 'HS256' });
const auth = (call, shop_id) => call.set('Authorization', `Bearer ${token(shop_id)}`);

describe('category controller HTTP behavior', () => {
  beforeEach(() => jest.clearAllMocks());

  test('requires auth and validates category requests', async () => {
    await request(app).get('/api/v1/categories').expect(401);
    expect((await auth(request(app).post('/api/v1/categories')).send({ name: 'x' })).status).toBe(422);
    expect((await auth(request(app).get('/api/v1/categories/nope'))).status).toBe(422);
    expect((await auth(request(app).put('/api/v1/categories/1')).send({})).status).toBe(200);
    expect(service.createCategory).not.toHaveBeenCalled();
  });

  test('creates and lists categories; handles missing shop and service failures', async () => {
    service.createCategory.mockResolvedValueOnce({ id: 1, name: 'Dairy' });
    const created = await auth(request(app).post('/api/v1/categories')).send({ name: 'Dairy' });
    expect(created.status).toBe(201);
    expect(service.createCategory).toHaveBeenCalledWith(7, { name: 'Dairy', description: undefined });
    service.getShopCategories.mockResolvedValueOnce([{ id: 1 }]);
    expect((await auth(request(app).get('/api/v1/categories'))).status).toBe(200);
    expect(service.getShopCategories).toHaveBeenCalledWith(7);

    expect((await auth(request(app).get('/api/v1/categories'), null)).status).toBe(400);
    service.getShopCategories.mockRejectedValueOnce(new Error('db failure'));
    expect((await auth(request(app).get('/api/v1/categories'))).status).toBe(500);
  });

  test('maps create errors and category get errors to expected HTTP responses', async () => {
    service.createCategory.mockRejectedValueOnce(Object.assign(new Error('duplicate'), { code: 'CATEGORY_001' }));
    expect((await auth(request(app).post('/api/v1/categories')).send({ name: 'Dairy' })).status).toBe(400);
    service.createCategory.mockRejectedValueOnce(Object.assign(new Error('shop missing'), { code: 'CATEGORY_002' }));
    expect((await auth(request(app).post('/api/v1/categories')).send({ name: 'Dairy' })).status).toBe(404);
    service.createCategory.mockRejectedValueOnce(new Error('unexpected'));
    expect((await auth(request(app).post('/api/v1/categories')).send({ name: 'Dairy' })).status).toBe(500);

    service.getCategoryById.mockResolvedValueOnce({ id: 2 });
    expect((await auth(request(app).get('/api/v1/categories/2'))).status).toBe(200);
    service.getCategoryById.mockRejectedValueOnce(Object.assign(new Error('missing'), { code: 'CATEGORY_002' }));
    expect((await auth(request(app).get('/api/v1/categories/3'))).status).toBe(404);
    service.getCategoryById.mockRejectedValueOnce(Object.assign(new Error('foreign'), { code: 'CATEGORY_003' }));
    expect((await auth(request(app).get('/api/v1/categories/4'))).status).toBe(403);
    service.getCategoryById.mockRejectedValueOnce(new Error('unexpected'));
    expect((await auth(request(app).get('/api/v1/categories/5'))).status).toBe(500);
    expect((await auth(request(app).get('/api/v1/categories/2'), null)).status).toBe(400);
  });

  test('updates categories and maps validation, ownership, missing, and server errors', async () => {
    service.updateCategory.mockResolvedValueOnce({ id: 1, name: 'Milk' });
    expect((await auth(request(app).put('/api/v1/categories/1')).send({ name: 'Milk' })).status).toBe(200);
    expect(service.updateCategory).toHaveBeenCalledWith(1, 7, { name: 'Milk', description: undefined });
    service.updateCategory.mockRejectedValueOnce(Object.assign(new Error('bad input'), { code: 'CATEGORY_001' }));
    expect((await auth(request(app).put('/api/v1/categories/1')).send({ name: 'Milk' })).status).toBe(400);
    service.updateCategory.mockRejectedValueOnce(Object.assign(new Error('missing'), { code: 'CATEGORY_002' }));
    expect((await auth(request(app).put('/api/v1/categories/1')).send({ name: 'Milk' })).status).toBe(404);
    service.updateCategory.mockRejectedValueOnce(Object.assign(new Error('foreign'), { code: 'CATEGORY_003' }));
    expect((await auth(request(app).put('/api/v1/categories/1')).send({ name: 'Milk' })).status).toBe(403);
    service.updateCategory.mockRejectedValueOnce(new Error('unexpected'));
    expect((await auth(request(app).put('/api/v1/categories/1')).send({ name: 'Milk' })).status).toBe(500);
    expect((await auth(request(app).put('/api/v1/categories/1'), null).send({ name: 'Milk' })).status).toBe(400);
  });

  test('deletes categories and maps missing, forbidden, conflict, and unexpected errors', async () => {
    service.deleteCategory.mockResolvedValueOnce(true);
    expect((await auth(request(app).delete('/api/v1/categories/1'))).status).toBe(200);
    expect(service.deleteCategory).toHaveBeenCalledWith(1, 7);
    for (const [code, expected] of [['CATEGORY_002', 404], ['CATEGORY_003', 403], ['CATEGORY_004', 400]]) {
      service.deleteCategory.mockRejectedValueOnce(Object.assign(new Error('mapped'), { code }));
      expect((await auth(request(app).delete('/api/v1/categories/2'))).status).toBe(expected);
    }
    service.deleteCategory.mockRejectedValueOnce(new Error('unexpected'));
    expect((await auth(request(app).delete('/api/v1/categories/3'))).status).toBe(500);
    expect((await auth(request(app).delete('/api/v1/categories/1'), null)).status).toBe(400);
  });
});
