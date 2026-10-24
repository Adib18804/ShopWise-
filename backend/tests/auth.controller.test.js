jest.mock('../src/services/auth.service', () => ({
  register: jest.fn(), login: jest.fn(), getCurrentUser: jest.fn(),
}));
jest.mock('../src/utils/logger.util', () => ({ error: jest.fn(), info: jest.fn(), warn: jest.fn() }));
jest.mock('../src/middleware/rateLimit.middleware', () => ({
  authLimiter: (req, res, next) => next(),
  apiLimiter: (req, res, next) => next(),
}));

const express = require('express');
const request = require('supertest');
const jwt = require('jsonwebtoken');
const config = require('../src/config/env');
const service = require('../src/services/auth.service');
const routes = require('../src/routes/auth.routes');

const app = express();
app.use(express.json());
app.use('/api/v1/auth', routes);
const token = () => jwt.sign({ user_id: 4, shop_id: 7, email: 'test@example.test' }, config.jwt.secret, { algorithm: 'HS256' });
const auth = (call) => call.set('Authorization', `Bearer ${token()}`);
const registration = { name: 'Asha', phone: '01712345678', email: 'asha@example.test', password: 'StrongPass1' };

describe('auth controller HTTP behavior', () => {
  beforeEach(() => jest.clearAllMocks());

  test('validates registration and login payloads before invoking services', async () => {
    expect((await request(app).post('/api/v1/auth/register').send({})).status).toBe(422);
    expect((await request(app).post('/api/v1/auth/login').send({ identifier: '', password: '' })).status).toBe(422);
    expect(service.register).not.toHaveBeenCalled();
    expect(service.login).not.toHaveBeenCalled();
    await request(app).get('/api/v1/auth/me').expect(401);
    await request(app).post('/api/v1/auth/logout').expect(401);
  });

  test('registers successfully and maps duplicate email, phone, and unexpected errors', async () => {
    service.register.mockResolvedValueOnce({ user: { id: 4 }, token: 'jwt' });
    const created = await request(app).post('/api/v1/auth/register').send(registration);
    expect(created.status).toBe(201);
    expect(created.body.data).toMatchObject({ user: { id: 4 }, token: 'jwt' });
    expect(service.register).toHaveBeenCalledWith({ ...registration, preferred_language: undefined });

    service.register.mockRejectedValueOnce(Object.assign(new Error('email taken'), { code: 'AUTH_005' }));
    const duplicateEmail = await request(app).post('/api/v1/auth/register').send(registration);
    expect(duplicateEmail.status).toBe(400);
    expect(duplicateEmail.body.errors[0]).toMatchObject({ field: 'email' });

    service.register.mockRejectedValueOnce(Object.assign(new Error('phone taken'), { code: 'AUTH_006' }));
    const duplicatePhone = await request(app).post('/api/v1/auth/register').send(registration);
    expect(duplicatePhone.status).toBe(400);
    expect(duplicatePhone.body.errors[0]).toMatchObject({ field: 'phone' });

    service.register.mockRejectedValueOnce(new Error('unexpected'));
    expect((await request(app).post('/api/v1/auth/register').send(registration)).status).toBe(500);
  });

  test('logs in and maps invalid credentials separately from server errors', async () => {
    service.login.mockResolvedValueOnce({ user: { id: 4 }, token: 'jwt' });
    const success = await request(app).post('/api/v1/auth/login')
      .send({ identifier: 'asha@example.test', password: 'StrongPass1' });
    expect(success.status).toBe(200);
    expect(service.login).toHaveBeenCalledWith('asha@example.test', 'StrongPass1');

    service.login.mockRejectedValueOnce(Object.assign(new Error('wrong password'), { code: 'AUTH_001' }));
    expect((await request(app).post('/api/v1/auth/login')
      .send({ identifier: 'asha@example.test', password: 'StrongPass1' })).status).toBe(401);
    service.login.mockRejectedValueOnce(new Error('database failure'));
    expect((await request(app).post('/api/v1/auth/login')
      .send({ identifier: 'asha@example.test', password: 'StrongPass1' })).status).toBe(500);
  });

  test('returns current user and maps missing-user and unexpected service errors', async () => {
    service.getCurrentUser.mockResolvedValueOnce({ id: 4, email: 'asha@example.test' });
    const success = await auth(request(app).get('/api/v1/auth/me'));
    expect(success.status).toBe(200);
    expect(service.getCurrentUser).toHaveBeenCalledWith(4);

    service.getCurrentUser.mockRejectedValueOnce(Object.assign(new Error('missing'), { code: 'AUTH_004' }));
    expect((await auth(request(app).get('/api/v1/auth/me'))).status).toBe(401);
    service.getCurrentUser.mockRejectedValueOnce(new Error('unexpected'));
    expect((await auth(request(app).get('/api/v1/auth/me'))).status).toBe(500);
  });

  test('handles logout, forgot password, and the not-yet-implemented reset response', async () => {
    expect((await auth(request(app).post('/api/v1/auth/logout'))).status).toBe(200);
    const forgot = await request(app).post('/api/v1/auth/forgot-password').send({ email: 'asha@example.test' });
    expect(forgot.status).toBe(200);
    expect(forgot.body.message).toContain('If an account with that email exists');
    const reset = await request(app).post('/api/v1/auth/reset-password')
      .send({ token: 'reset-token', new_password: 'StrongPass1' });
    expect(reset.status).toBe(404);
    expect(reset.body.message).toContain('not yet implemented');
  });
});
