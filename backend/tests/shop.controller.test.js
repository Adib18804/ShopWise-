jest.mock('../src/services/shop.service', () => ({
  createShop: jest.fn(), getUserShop: jest.fn(), getShopById: jest.fn(),
  updateShop: jest.fn(), deleteShop: jest.fn(), hasShop: jest.fn(),
}));
jest.mock('../src/services/auth.service', () => ({ refreshSession: jest.fn() }));
jest.mock('../src/utils/logger.util', () => ({ error: jest.fn(), info: jest.fn(), warn: jest.fn() }));

const express = require('express');
const request = require('supertest');
const jwt = require('jsonwebtoken');
const config = require('../src/config/env');
const shopService = require('../src/services/shop.service');
const authService = require('../src/services/auth.service');
const routes = require('../src/routes/shop.routes');

const app = express();
app.use(express.json());
app.use('/api/v1/shop', routes);
const token = () => jwt.sign({ user_id: 4, shop_id: 7, email: 'test@example.test' }, config.jwt.secret, { algorithm: 'HS256' });
const auth = (call) => call.set('Authorization', `Bearer ${token()}`);
const shopPayload = { shop_name: 'Asha Store', address: 'Dhaka, Bangladesh', phone: '01712345678', currency: 'BDT' };

describe('shop controller HTTP behavior', () => {
  beforeEach(() => jest.clearAllMocks());

  test('requires auth and validates create, IDs, and update requests', async () => {
    await request(app).get('/api/v1/shop').expect(401);
    expect((await auth(request(app).post('/api/v1/shop')).send({})).status).toBe(422);
    expect((await auth(request(app).get('/api/v1/shop/nope'))).status).toBe(422);
    expect(shopService.createShop).not.toHaveBeenCalled();
  });

  test('creates shop, refreshes user session, and returns the refreshed token', async () => {
    shopService.createShop.mockResolvedValueOnce({ id: 7, shop_name: 'Asha Store' });
    authService.refreshSession.mockResolvedValueOnce({ user: { id: 4, shop_id: 7 }, token: 'refreshed' });
    const response = await auth(request(app).post('/api/v1/shop')).send(shopPayload);
    expect(response.status).toBe(201);
    expect(response.body.data).toMatchObject({ shop: { id: 7 }, user: { shop_id: 7 }, token: 'refreshed' });
    expect(shopService.createShop).toHaveBeenCalledWith(4, shopPayload);
    expect(authService.refreshSession).toHaveBeenCalledWith(4);
  });

  test('maps create errors including duplicate/conflict and unexpected failure', async () => {
    shopService.createShop.mockRejectedValueOnce(Object.assign(new Error('already exists'), { code: 'SHOP_001' }));
    expect((await auth(request(app).post('/api/v1/shop')).send(shopPayload)).status).toBe(400);
    shopService.createShop.mockRejectedValueOnce(new Error('unexpected'));
    expect((await auth(request(app).post('/api/v1/shop')).send(shopPayload)).status).toBe(500);
    shopService.createShop.mockResolvedValueOnce({ id: 7 });
    authService.refreshSession.mockRejectedValueOnce(new Error('session failed'));
    expect((await auth(request(app).post('/api/v1/shop')).send(shopPayload)).status).toBe(500);
  });

  test('gets own shop and checks existence with success and service errors', async () => {
    shopService.getUserShop.mockResolvedValueOnce({ id: 7 });
    expect((await auth(request(app).get('/api/v1/shop'))).status).toBe(200);
    expect(shopService.getUserShop).toHaveBeenCalledWith(4);
    shopService.getUserShop.mockRejectedValueOnce(Object.assign(new Error('missing'), { code: 'SHOP_002' }));
    expect((await auth(request(app).get('/api/v1/shop'))).status).toBe(404);
    shopService.getUserShop.mockRejectedValueOnce(new Error('unexpected'));
    expect((await auth(request(app).get('/api/v1/shop'))).status).toBe(500);

    shopService.hasShop.mockResolvedValueOnce(true);
    expect((await auth(request(app).get('/api/v1/shop/check'))).body.data.hasShop).toBe(true);
    shopService.hasShop.mockRejectedValueOnce(new Error('unexpected'));
    expect((await auth(request(app).get('/api/v1/shop/check'))).status).toBe(500);
  });

  test('gets shop by ID with not-found, forbidden, and unexpected mappings', async () => {
    shopService.getShopById.mockResolvedValueOnce({ id: 7 });
    expect((await auth(request(app).get('/api/v1/shop/7'))).status).toBe(200);
    expect(shopService.getShopById).toHaveBeenCalledWith(7, 4);
    shopService.getShopById.mockRejectedValueOnce(Object.assign(new Error('missing'), { code: 'SHOP_002' }));
    expect((await auth(request(app).get('/api/v1/shop/7'))).status).toBe(404);
    shopService.getShopById.mockRejectedValueOnce(Object.assign(new Error('foreign'), { code: 'SHOP_003' }));
    expect((await auth(request(app).get('/api/v1/shop/7'))).status).toBe(403);
    shopService.getShopById.mockRejectedValueOnce(new Error('unexpected'));
    expect((await auth(request(app).get('/api/v1/shop/7'))).status).toBe(500);
  });

  test('updates shop and maps ownership, missing, validation, and server errors', async () => {
    shopService.updateShop.mockResolvedValueOnce({ id: 7, shop_name: 'New name' });
    expect((await auth(request(app).put('/api/v1/shop/7')).send({ shop_name: 'New name' })).status).toBe(200);
    expect(shopService.updateShop).toHaveBeenCalledWith(7, 4, {
      shop_name: 'New name', address: undefined, phone: undefined, currency: undefined,
    });
    for (const [code, expected] of [['SHOP_002', 404], ['SHOP_003', 403]]) {
      shopService.updateShop.mockRejectedValueOnce(Object.assign(new Error('mapped'), { code }));
      expect((await auth(request(app).put('/api/v1/shop/7')).send({ shop_name: 'New name' })).status).toBe(expected);
    }
    shopService.updateShop.mockRejectedValueOnce(new Error('unexpected'));
    expect((await auth(request(app).put('/api/v1/shop/7')).send({ shop_name: 'New name' })).status).toBe(500);
  });

  test('deletes shop and maps not-found, forbidden, and server errors', async () => {
    shopService.deleteShop.mockResolvedValueOnce(true);
    expect((await auth(request(app).delete('/api/v1/shop/7'))).status).toBe(200);
    expect(shopService.deleteShop).toHaveBeenCalledWith(7, 4);
    for (const [code, expected] of [['SHOP_002', 404], ['SHOP_003', 403]]) {
      shopService.deleteShop.mockRejectedValueOnce(Object.assign(new Error('mapped'), { code }));
      expect((await auth(request(app).delete('/api/v1/shop/7'))).status).toBe(expected);
    }
    shopService.deleteShop.mockRejectedValueOnce(new Error('unexpected'));
    expect((await auth(request(app).delete('/api/v1/shop/7'))).status).toBe(500);
  });
});
