jest.mock('../src/config/database', () => ({ query: jest.fn() }));

const db = require('../src/config/database');
const users = require('../src/repositories/user.repository');

const userRow = (overrides = {}) => ({
  id: 8,
  name: 'Asha',
  phone: '01300000000',
  email: 'asha@example.test',
  password_hash: 'hash',
  preferred_language: 'bn',
  created_at: new Date('2026-01-01T00:00:00Z'),
  updated_at: new Date('2026-01-02T00:00:00Z'),
  ...overrides,
});

describe('user repository', () => {
  beforeEach(() => jest.clearAllMocks());

  test('creates users with the default language or the supplied language', async () => {
    db.query.mockResolvedValueOnce([{ insertId: 8 }, undefined]);
    await expect(users.create({ name: 'Asha', phone: '01300000000', email: 'a@example.test', password_hash: 'hash' }))
      .resolves.toBe(8);
    expect(db.query.mock.calls[0][1]).toEqual(['Asha', '01300000000', 'a@example.test', 'hash', 'bn']);

    db.query.mockResolvedValueOnce([{ insertId: 9 }, undefined]);
    await expect(users.create({
      name: 'Rafi', phone: '01300000001', email: 'r@example.test', password_hash: 'hash', preferred_language: 'en',
    })).resolves.toBe(9);
    expect(db.query.mock.calls[1][1][4]).toBe('en');
  });

  test('propagates duplicate email and phone errors', async () => {
    const duplicate = Object.assign(new Error('duplicate user'), { code: 'ER_DUP_ENTRY' });
    db.query.mockRejectedValueOnce(duplicate);
    await expect(users.create({ email: 'taken@example.test' })).rejects.toBe(duplicate);
  });

  test.each([
    ['findById', 8],
    ['findByEmail', 'asha@example.test'],
    ['findByPhone', '01300000000'],
    ['findByEmailOrPhone', 'asha@example.test'],
  ])('%s returns a matching row and null when absent', async (method, identifier) => {
    db.query.mockResolvedValueOnce([[userRow()], undefined]);
    await expect(users[method](identifier)).resolves.toMatchObject({ id: 8 });
    db.query.mockResolvedValueOnce([[], undefined]);
    await expect(users[method](identifier)).resolves.toBeNull();
  });

  test('checks email and phone existence for both found and missing values', async () => {
    db.query.mockResolvedValueOnce([[{ count: '1' }], undefined]);
    await expect(users.emailExists('asha@example.test')).resolves.toBe(true);
    db.query.mockResolvedValueOnce([[{ count: 0 }], undefined]);
    await expect(users.emailExists('new@example.test')).resolves.toBe(false);

    db.query.mockResolvedValueOnce([[{ count: 2 }], undefined]);
    await expect(users.phoneExists('01300000000')).resolves.toBe(true);
    db.query.mockResolvedValueOnce([[{ count: 0 }], undefined]);
    await expect(users.phoneExists('01300000001')).resolves.toBe(false);
  });

  test('updates supplied fields and returns false for an empty update', async () => {
    await expect(users.update(8, {})).resolves.toBe(false);
    expect(db.query).not.toHaveBeenCalled();

    db.query.mockResolvedValueOnce([{ affectedRows: 1 }, undefined]);
    await expect(users.update(8, {
      name: 'Asha Begum', phone: '01300000002', email: 'new@example.test',
      password_hash: 'new-hash', preferred_language: 'en',
    })).resolves.toBe(true);
    const [sql, params] = db.query.mock.calls[0];
    expect(sql).toContain('UPDATE users SET name = ?, phone = ?, email = ?, password_hash = ?, preferred_language = ?');
    expect(params).toEqual(['Asha Begum', '01300000002', 'new@example.test', 'new-hash', 'en', 8]);

    db.query.mockResolvedValueOnce([{ affectedRows: 0 }, undefined]);
    await expect(users.update(999, { name: 'Missing' })).resolves.toBe(false);
  });

  test('finds a user with an active shop and excludes soft-deleted shops', async () => {
    db.query.mockResolvedValueOnce([[
      {
        ...userRow(), shop_id: 12, shop_name: 'Asha Store', shop_address: 'Dhaka',
        shop_phone: '01311111111', currency: 'BDT',
      },
    ], undefined]);
    await expect(users.findWithShop(8)).resolves.toMatchObject({
      id: 8,
      has_shop: true,
      shop_id: 12,
      shop: { id: 12, shop_name: 'Asha Store' },
    });
    expect(db.query.mock.calls[0][0]).toContain('s.deleted_at IS NULL');

    db.query.mockResolvedValueOnce([[
      { ...userRow(), shop_id: null, shop_name: null },
    ], undefined]);
    const withoutShop = await users.findWithShop(8);
    expect(withoutShop).toMatchObject({ has_shop: false, shop_id: null });
    expect(withoutShop.shop).toBeUndefined();
  });

  test('returns null for a missing user and propagates database errors', async () => {
    db.query.mockResolvedValueOnce([[], undefined]);
    await expect(users.findWithShop(404)).resolves.toBeNull();

    const failure = new Error('database unavailable');
    db.query.mockRejectedValueOnce(failure);
    await expect(users.findById(8)).rejects.toBe(failure);
  });
});
