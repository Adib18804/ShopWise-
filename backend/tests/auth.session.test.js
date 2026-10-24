jest.mock('../src/repositories/user.repository', () => ({ findWithShop: jest.fn() }));

const jwt = require('jsonwebtoken');
const config = require('../src/config/env');
const userRepository = require('../src/repositories/user.repository');
const authService = require('../src/services/auth.service');

test('refreshSession issues a token with the newly-created shop context', async () => {
  userRepository.findWithShop.mockResolvedValue({
    id: 21, email: 'shop@example.com', shop_id: 8, has_shop: true,
  });
  const session = await authService.refreshSession(21);
  const decoded = jwt.verify(session.token, config.jwt.secret);
  expect(session.user.shop_id).toBe(8);
  expect(decoded).toMatchObject({ user_id: 21, shop_id: 8, email: 'shop@example.com' });
});
