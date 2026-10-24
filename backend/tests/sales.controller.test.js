jest.mock('../src/services/sales.service.js', () => ({ processSale: jest.fn() }));

const express = require('express');
const request = require('supertest');
const jwt = require('jsonwebtoken');
const config = require('../src/config/env.js');
const salesService = require('../src/services/sales.service.js');
const salesRoutes = require('../src/routes/sales.routes.js');

const app = express();
app.use(express.json());
app.use('/api/v1/sales', salesRoutes);
app.use((error, req, res, next) => res.status(error.statusCode || 500)
  .json({ success: false, message: error.message }));

const token = () => jwt.sign(
  { user_id: 4, shop_id: 7, email: 'sales-test@example.test' },
  config.jwt.secret,
  { algorithm: 'HS256' },
);
const validSale = {
  items: [{ product_id: 12, quantity: '2.00', unit_price: '10.00' }],
  discount: '1.00',
  payments: [{ amount: '19.00', payment_method: 'cash' }],
};

describe('sales routes and controller', () => {
  beforeEach(() => jest.clearAllMocks());

  test('processes a sale using tenant/user IDs from authentication, not the body', async () => {
    const invoice = { id: 35, invoice_number: 'INV-000035', total_amount: '20.00' };
    salesService.processSale.mockResolvedValueOnce(invoice);

    const response = await request(app).post('/api/v1/sales')
      .set('Authorization', `Bearer ${token()}`)
      .send({ ...validSale, shop_id: 999 });

    expect(response.status).toBe(201);
    expect(response.body).toMatchObject({
      success: true,
      message: 'Sale processed successfully',
      data: invoice,
    });
    expect(salesService.processSale).toHaveBeenCalledWith(7, 4, {
      ...validSale,
      shop_id: 999,
    });
  });

  test('returns 401 when the request has no token', async () => {
    const response = await request(app).post('/api/v1/sales').send(validSale);
    expect(response.status).toBe(401);
    expect(response.body.success).toBe(false);
    expect(salesService.processSale).not.toHaveBeenCalled();
  });

  test.each([[400, 'invalid sale'], [409, 'Insufficient stock']])(
    'returns known service errors with status %i', async (statusCode, message) => {
      salesService.processSale.mockRejectedValueOnce(Object.assign(new Error(message), { statusCode }));
      const response = await request(app).post('/api/v1/sales')
        .set('Authorization', `Bearer ${token()}`)
        .send(validSale);
      expect(response.status).toBe(statusCode);
      expect(response.body).toMatchObject({ success: false, message });
    },
  );

  test('forwards unexpected service errors to the global handler', async () => {
    salesService.processSale.mockRejectedValueOnce(new Error('database unavailable'));
    const response = await request(app).post('/api/v1/sales')
      .set('Authorization', `Bearer ${token()}`)
      .send(validSale);
    expect(response.status).toBe(500);
    expect(response.body.message).toBe('database unavailable');
  });
});