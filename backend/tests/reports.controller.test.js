jest.mock('../src/services/reports.service.js', () => ({ getDailySummary: jest.fn() }));

const express = require('express');
const request = require('supertest');
const jwt = require('jsonwebtoken');
const config = require('../src/config/env.js');
const service = require('../src/services/reports.service.js');
const routes = require('../src/routes/reports.routes.js');

const app = express();
app.use('/api/v1/reports', routes);
app.use((error, req, res, next) => res.status(error.statusCode || 500).json({ message: error.message }));
const token = jwt.sign({ user_id: 4, shop_id: 17, email: 'report@example.test' }, config.jwt.secret, { algorithm: 'HS256' });

describe('daily report endpoint', () => {
  beforeEach(() => jest.clearAllMocks());

  test('requires authentication', async () => {
    await request(app).get('/api/v1/reports/daily-summary').expect(401);
    expect(service.getDailySummary).not.toHaveBeenCalled();
  });

  test('returns the report for the authenticated shop', async () => {
    const report = { date: '2026-10-25', total_sales_amount: '50.00', total_items_sold: '2.00', total_due_amount: '10.00', sales_trend: [] };
    service.getDailySummary.mockResolvedValueOnce(report);
    const response = await request(app).get('/api/v1/reports/daily-summary')
      .set('Authorization', `Bearer ${token}`);
    expect(response.status).toBe(200);
    expect(response.body.data).toEqual(report);
    expect(service.getDailySummary).toHaveBeenCalledWith(17);
  });

  test('maps missing shop context to 400 and forwards unexpected failures', async () => {
    service.getDailySummary.mockRejectedValueOnce(Object.assign(new Error('A valid shop is required'), { statusCode: 400 }));
    await request(app).get('/api/v1/reports/daily-summary')
      .set('Authorization', `Bearer ${token}`).expect(400);
    service.getDailySummary.mockRejectedValueOnce(new Error('database unavailable'));
    await request(app).get('/api/v1/reports/daily-summary')
      .set('Authorization', `Bearer ${token}`).expect(500);
  });
});