const express = require('express');
const request = require('supertest');
const jwt = require('jsonwebtoken');
const config = require('../src/config/env');
const { verifyToken } = require('../src/utils/jwt.util');
const { apiLimiter, authLimiter } = require('../src/middleware/rateLimit.middleware');

test('JWT verification accepts HS256 and rejects a token signed with a different algorithm', () => {
  const payload = { user_id: 7, shop_id: 12, email: 'security@example.test' };
  const valid = jwt.sign(payload, config.jwt.secret, { algorithm: 'HS256' });
  const wrongAlgorithm = jwt.sign(payload, config.jwt.secret, { algorithm: 'HS384' });

  expect(verifyToken(valid)).toMatchObject(payload);
  expect(() => verifyToken(wrongAlgorithm)).toThrow('Invalid token');
});

test('global API limiter allows 100 requests per minute and blocks the next request', async () => {
  const app = express();
  app.use(apiLimiter);
  app.get('/', (req, res) => res.sendStatus(200));

  for (let attempt = 0; attempt < 100; attempt += 1) {
    const response = await request(app).get('/');
    expect(response.status).toBe(200);
  }
  const limited = await request(app).get('/');
  expect(limited.status).toBe(429);
});

test('authentication limiter allows five attempts per fifteen minutes and blocks the sixth', async () => {
  const app = express();
  app.use(authLimiter);
  app.post('/', (req, res) => res.sendStatus(200));

  for (let attempt = 0; attempt < 5; attempt += 1) {
    const response = await request(app).post('/');
    expect(response.status).toBe(200);
  }
  const limited = await request(app).post('/');
  expect(limited.status).toBe(429);
});
