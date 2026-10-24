jest.mock('../src/repositories/user.repository', () => ({
  emailExists: jest.fn(),
  phoneExists: jest.fn(),
  create: jest.fn(),
  findWithShop: jest.fn(),
  findByEmailOrPhone: jest.fn(),
  findById: jest.fn(),
  findByEmail: jest.fn(),
  update: jest.fn(),
}));
jest.mock('../src/utils/bcrypt.util', () => ({
  hashPassword: jest.fn(),
  comparePassword: jest.fn(),
}));
jest.mock('../src/utils/jwt.util', () => ({ generateToken: jest.fn() }));

const users = require('../src/repositories/user.repository');
const passwords = require('../src/utils/bcrypt.util');
const tokens = require('../src/utils/jwt.util');
const service = require('../src/services/auth.service');

describe('auth service', () => {
  beforeEach(() => jest.clearAllMocks());

  test('registers with a hashed password, default language, and token without returning the hash', async () => {
    users.emailExists.mockResolvedValue(false);
    users.phoneExists.mockResolvedValue(false);
    passwords.hashPassword.mockResolvedValue('stored-hash');
    users.create.mockResolvedValue(8);
    users.findWithShop.mockResolvedValue({
      id: 8, name: 'Asha', email: 'asha@example.test', password_hash: 'stored-hash', shop_id: null,
    });
    tokens.generateToken.mockReturnValue('signed-token');

    const result = await service.register({
      name: 'Asha', phone: '01700000000', email: 'asha@example.test', password: 'secret123',
    });

    expect(users.create).toHaveBeenCalledWith(expect.objectContaining({
      password_hash: 'stored-hash', preferred_language: 'bn',
    }));
    expect(tokens.generateToken).toHaveBeenCalledWith({
      user_id: 8, shop_id: null, email: 'asha@example.test',
    });
    expect(result.token).toBe('signed-token');
    expect(result.user).not.toHaveProperty('password_hash');
  });

  test('rejects duplicate email before hashing or creating a user', async () => {
    users.emailExists.mockResolvedValue(true);

    await expect(service.register({
      name: 'Asha', phone: '01700000000', email: 'asha@example.test', password: 'secret123',
    })).rejects.toMatchObject({ code: 'AUTH_005', field: 'email' });

    expect(passwords.hashPassword).not.toHaveBeenCalled();
    expect(users.create).not.toHaveBeenCalled();
  });

  test('rejects invalid login credentials without issuing a token', async () => {
    users.findByEmailOrPhone.mockResolvedValue({ id: 8, password_hash: 'stored-hash' });
    passwords.comparePassword.mockResolvedValue(false);

    await expect(service.login('asha@example.test', 'wrong')).rejects.toMatchObject({ code: 'AUTH_001' });
    expect(users.findWithShop).not.toHaveBeenCalled();
    expect(tokens.generateToken).not.toHaveBeenCalled();
  });

  test('rejects duplicate phone during registration and honors an explicit language', async () => {
    users.emailExists.mockResolvedValue(false);
    users.phoneExists.mockResolvedValue(true);
    await expect(service.register({ email: 'a@b.test', phone: '01700000000' }))
      .rejects.toMatchObject({ code: 'AUTH_006', field: 'phone' });
    expect(passwords.hashPassword).not.toHaveBeenCalled();

    users.phoneExists.mockResolvedValue(false);
    passwords.hashPassword.mockResolvedValue('hash');
    users.create.mockResolvedValue(9);
    users.findWithShop.mockResolvedValue({ id: 9, email: 'a@b.test', shop_id: 2, password_hash: 'hash' });
    tokens.generateToken.mockReturnValue('token');
    await service.register({ email: 'a@b.test', phone: '01700000000', preferred_language: 'en' });
    expect(users.create).toHaveBeenCalledWith(expect.objectContaining({ preferred_language: 'en' }));
  });

  test('logs in successfully and rejects a missing account', async () => {
    users.findByEmailOrPhone.mockResolvedValueOnce(null);
    await expect(service.login('missing', 'pass')).rejects.toMatchObject({ code: 'AUTH_001' });

    users.findByEmailOrPhone.mockResolvedValueOnce({ id: 8, password_hash: 'hash' });
    passwords.comparePassword.mockResolvedValue(true);
    users.findWithShop.mockResolvedValue({ id: 8, email: 'a@b.test', shop_id: 3, password_hash: 'hash' });
    tokens.generateToken.mockReturnValue('login-token');
    const result = await service.login('a@b.test', 'pass');
    expect(result.token).toBe('login-token');
    expect(result.user).not.toHaveProperty('password_hash');
    expect(tokens.generateToken).toHaveBeenCalledWith({ user_id: 8, shop_id: 3, email: 'a@b.test' });
  });

  test('gets current user and refreshes a session, mapping missing users to AUTH_004', async () => {
    users.findWithShop.mockResolvedValueOnce(null);
    await expect(service.getCurrentUser(77)).rejects.toMatchObject({ code: 'AUTH_004' });
    users.findWithShop.mockResolvedValueOnce({ id: 8, shop_id: null });
    await expect(service.getCurrentUser(8)).resolves.toMatchObject({ id: 8 });

    users.findWithShop.mockResolvedValueOnce(null);
    await expect(service.refreshSession(77)).rejects.toMatchObject({ code: 'AUTH_004' });
    users.findWithShop.mockResolvedValueOnce({ id: 8, email: 'a@b.test', shop_id: 3 });
    tokens.generateToken.mockReturnValue('refreshed');
    await expect(service.refreshSession(8)).resolves.toMatchObject({ token: 'refreshed' });
  });

  test('updates profiles and checks only changed email and phone values', async () => {
    users.findById.mockResolvedValueOnce(null);
    await expect(service.updateProfile(8, {})).rejects.toMatchObject({ code: 'AUTH_004' });

    users.findById.mockResolvedValue({ id: 8, email: 'old@b.test', phone: '01700000000' });
    users.emailExists.mockResolvedValueOnce(true);
    await expect(service.updateProfile(8, { email: 'used@b.test' }))
      .rejects.toMatchObject({ code: 'AUTH_005', field: 'email' });

    users.emailExists.mockResolvedValueOnce(false);
    users.phoneExists.mockResolvedValueOnce(true);
    await expect(service.updateProfile(8, { email: 'new@b.test', phone: '01700000001' }))
      .rejects.toMatchObject({ code: 'AUTH_006', field: 'phone' });

    users.emailExists.mockResolvedValueOnce(false);
    users.phoneExists.mockResolvedValueOnce(false);
    users.findWithShop.mockResolvedValueOnce({ id: 8, email: 'new@b.test' });
    await expect(service.updateProfile(8, { email: 'new@b.test', phone: '01700000001' }))
      .resolves.toMatchObject({ id: 8 });
    expect(users.update).toHaveBeenCalledWith(8, { email: 'new@b.test', phone: '01700000001' });

    users.findById.mockResolvedValue({ id: 8, email: 'old@b.test', phone: '01700000000' });
    users.findWithShop.mockResolvedValueOnce({ id: 8 });
    await expect(service.updateProfile(8, { name: 'Same contact details' })).resolves.toEqual({ id: 8 });
    expect(users.emailExists).toHaveBeenCalledTimes(3);
    expect(users.phoneExists).toHaveBeenCalledTimes(2);
  });

  test('changes passwords and handles missing users and incorrect current passwords', async () => {
    users.findById.mockResolvedValueOnce(null);
    await expect(service.changePassword(8, 'old', 'new')).rejects.toMatchObject({ code: 'AUTH_004' });

    users.findById.mockResolvedValue({ id: 8, email: 'a@b.test' });
    users.findByEmail.mockResolvedValue({ password_hash: 'old-hash' });
    passwords.comparePassword.mockResolvedValueOnce(false);
    await expect(service.changePassword(8, 'wrong', 'new'))
      .rejects.toMatchObject({ code: 'AUTH_007', message: 'Current password is incorrect' });

    passwords.comparePassword.mockResolvedValueOnce(true);
    passwords.hashPassword.mockResolvedValueOnce('new-hash');
    await expect(service.changePassword(8, 'old', 'new')).resolves.toBe(true);
    expect(users.update).toHaveBeenCalledWith(8, { password_hash: 'new-hash' });
  });
});
