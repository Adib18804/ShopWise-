jest.mock('../src/utils/logger.util', () => ({
  error: jest.fn(), info: jest.fn(), warn: jest.fn(),
}));

const request = require('supertest');
const app = require('../src/app');

const loadAppForEnvironment = (nodeEnv) => {
  const oldNodeEnv = process.env.NODE_ENV;
  const oldDbPassword = process.env.DB_PASSWORD;
  process.env.NODE_ENV = nodeEnv;
  if (nodeEnv === 'production' && !process.env.DB_PASSWORD) process.env.DB_PASSWORD = 'test-only-password';
  jest.resetModules();
  let isolatedApp;
  jest.isolateModules(() => { isolatedApp = require('../src/app'); });
  process.env.NODE_ENV = oldNodeEnv;
  if (oldDbPassword === undefined) delete process.env.DB_PASSWORD;
  else process.env.DB_PASSWORD = oldDbPassword;
  return isolatedApp;
};

const errorHandlerFrom = (targetApp) => targetApp._router.stack
  .filter((layer) => layer.handle.length === 4)
  .map((layer) => layer.handle)
  .pop();

const responseMock = () => {
  const res = { status: jest.fn(), json: jest.fn() };
  res.status.mockReturnValue(res);
  res.json.mockReturnValue(res);
  return res;
};

describe('Express app branches', () => {
  test('serves health without an Origin header and allows a configured origin', async () => {
    const noOrigin = await request(app).get('/api/health').expect(200);
    expect(noOrigin.body).toMatchObject({ status: 'healthy', environment: 'test' });

    const allowedOrigin = await request(app).get('/api/health')
      .set('Origin', 'http://localhost:3000').expect(200);
    expect(allowedOrigin.headers['access-control-allow-origin']).toBe('http://localhost:3000');
    expect(allowedOrigin.headers['access-control-allow-credentials']).toBe('true');
  });

  test('rejects an unconfigured origin and returns the not-found response for unknown routes', async () => {
    const blocked = await request(app).get('/api/health').set('Origin', 'https://not-allowed.example');
    expect(blocked.status).toBe(500);
    expect(blocked.body).toMatchObject({ success: false, message: 'Not allowed by CORS' });

    const missing = await request(app).get('/no-such-route').expect(404);
    expect(missing.body).toEqual({ success: false, message: 'Route not found' });
  });

  test('uses the development logger branch when NODE_ENV is development', async () => {
    const developmentApp = loadAppForEnvironment('development');
    await request(developmentApp).get('/api/health').expect(200);
  });

  test('error handler uses statusCode when present and falls back to 500', () => {
    const handler = errorHandlerFrom(app);
    const req = { path: '/forced-error', method: 'GET' };
    const mapped = responseMock();
    handler(Object.assign(new Error('mapped failure'), { statusCode: 418 }), req, mapped, jest.fn());
    expect(mapped.status).toHaveBeenCalledWith(418);
    expect(mapped.json).toHaveBeenCalledWith({ success: false, message: 'mapped failure' });

    const fallback = responseMock();
    handler(new Error('fallback failure'), req, fallback, jest.fn());
    expect(fallback.status).toHaveBeenCalledWith(500);
  });

  test('production error handler hides internal error details', async () => {
    const productionApp = loadAppForEnvironment('production');
    const response = await request(productionApp).get('/api/health')
      .set('Origin', 'https://not-allowed.example');
    expect(response.status).toBe(500);
    expect(response.body).toEqual({ success: false, message: 'Internal server error' });
  });
});
