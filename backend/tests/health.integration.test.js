const request = require('supertest');
const app = require('../src/app');

test('health endpoint responds without requiring database access', async () => {
  const response = await request(app).get('/api/health');
  expect(response.status).toBe(200);
  expect(response.body.status).toBe('healthy');
});
