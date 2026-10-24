jest.mock('../src/repositories/shop.repository', () => ({
  ownerHasShop: jest.fn(),
  create: jest.fn(),
  findById: jest.fn(),
  findByOwnerId: jest.fn(),
  update: jest.fn(),
  delete: jest.fn(),
}));

const shops = require('../src/repositories/shop.repository');
const service = require('../src/services/shop.service');

describe('shop service ownership and lifecycle', () => {
  beforeEach(() => jest.clearAllMocks());

  test('creates one shop with the default currency and returns the persisted shop', async () => {
    shops.ownerHasShop.mockResolvedValue(false);
    shops.create.mockResolvedValue(14);
    shops.findById.mockResolvedValue({ id: 14, owner_id: 5, currency: 'BDT' });

    const result = await service.createShop(5, { shop_name: 'Asha Store' });

    expect(shops.create).toHaveBeenCalledWith(expect.objectContaining({ owner_id: 5, currency: 'BDT' }));
    expect(result).toEqual({ id: 14, owner_id: 5, currency: 'BDT' });
  });

  test('rejects a second shop for the same owner', async () => {
    shops.ownerHasShop.mockResolvedValue(true);

    await expect(service.createShop(5, { shop_name: 'Second Store' }))
      .rejects.toMatchObject({ code: 'SHOP_001' });
    expect(shops.create).not.toHaveBeenCalled();
  });

  test('prevents another user from updating a shop', async () => {
    shops.findById.mockResolvedValue({ id: 14, owner_id: 5 });

    await expect(service.updateShop(14, 99, { shop_name: 'Hijack' }))
      .rejects.toMatchObject({ code: 'SHOP_003' });
    expect(shops.update).not.toHaveBeenCalled();
  });

  test('translates duplicate-key create errors and reports a shop that cannot be reread', async () => {
    shops.ownerHasShop.mockResolvedValue(false);
    shops.create.mockRejectedValueOnce(Object.assign(new Error('duplicate'), { code: 'ER_DUP_ENTRY' }));
    await expect(service.createShop(5, { shop_name: 'Store' })).rejects.toMatchObject({ code: 'SHOP_001' });

    shops.create.mockRejectedValueOnce(new Error('connection lost'));
    await expect(service.createShop(5, { shop_name: 'Store' })).rejects.toThrow('connection lost');

    shops.create.mockResolvedValue(15);
    shops.findById.mockResolvedValueOnce(null);
    await expect(service.createShop(5, { shop_name: 'Store', currency: 'USD' })).rejects.toMatchObject({ code: 'SHOP_002' });
    expect(shops.create).toHaveBeenLastCalledWith(expect.objectContaining({ currency: 'USD' }));
  });

  test('enforces ownership when reading a shop and returns not-found for missing shops', async () => {
    shops.findById.mockResolvedValueOnce(null);
    await expect(service.getShopById(14, 5)).rejects.toMatchObject({ code: 'SHOP_002' });
    shops.findById.mockResolvedValueOnce({ id: 14, owner_id: 99 });
    await expect(service.getShopById(14, 5)).rejects.toMatchObject({ code: 'SHOP_003' });
    shops.findById.mockResolvedValueOnce({ id: 14, owner_id: 5 });
    await expect(service.getShopById(14, 5)).resolves.toMatchObject({ id: 14 });

    shops.findByOwnerId.mockResolvedValueOnce(null);
    await expect(service.getUserShop(5)).rejects.toMatchObject({ code: 'SHOP_002' });
    shops.findByOwnerId.mockResolvedValueOnce({ id: 14, owner_id: 99 });
    await expect(service.getUserShop(5)).rejects.toMatchObject({ code: 'SHOP_003' });
    shops.findByOwnerId.mockResolvedValueOnce({ id: 14, owner_id: 5 });
    await expect(service.getUserShop(5)).resolves.toMatchObject({ id: 14 });
  });

  test('handles missing and foreign shops on update and returns the reread result', async () => {
    shops.findById.mockResolvedValueOnce(null);
    await expect(service.updateShop(14, 5, {})).rejects.toMatchObject({ code: 'SHOP_002' });
    shops.findById.mockResolvedValueOnce({ id: 14, owner_id: 99 });
    await expect(service.updateShop(14, 5, {})).rejects.toMatchObject({ code: 'SHOP_003' });

    shops.findById.mockResolvedValueOnce({ id: 14, owner_id: 5 }).mockResolvedValueOnce(null);
    await expect(service.updateShop(14, 5, { shop_name: 'New' })).resolves.toBeNull();
    expect(shops.update).toHaveBeenCalledWith(14, 5, { shop_name: 'New' });
  });

  test('handles missing or foreign shops on delete and returns repository existence results', async () => {
    shops.findById.mockResolvedValueOnce(null);
    await expect(service.deleteShop(14, 5)).rejects.toMatchObject({ code: 'SHOP_002' });
    shops.findById.mockResolvedValueOnce({ id: 14, owner_id: 99 });
    await expect(service.deleteShop(14, 5)).rejects.toMatchObject({ code: 'SHOP_003' });
    shops.findById.mockResolvedValueOnce({ id: 14, owner_id: 5 });
    shops.delete.mockResolvedValueOnce(true);
    await expect(service.deleteShop(14, 5)).resolves.toBe(true);
    expect(shops.delete).toHaveBeenCalledWith(14, 5);

    shops.ownerHasShop.mockResolvedValueOnce(true).mockResolvedValueOnce(false);
    await expect(service.hasShop(5)).resolves.toBe(true);
    await expect(service.hasShop(6)).resolves.toBe(false);
  });
});
