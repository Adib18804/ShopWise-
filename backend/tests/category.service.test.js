jest.mock('../src/repositories/category.repository', () => ({
  nameExistsInShop: jest.fn(),
  create: jest.fn(),
  findById: jest.fn(),
  findByShopIdWithCounts: jest.fn(),
  update: jest.fn(),
  hasProducts: jest.fn(),
  delete: jest.fn(),
}));

const categories = require('../src/repositories/category.repository');
const service = require('../src/services/category.service');

describe('category service ownership and lifecycle', () => {
  beforeEach(() => jest.clearAllMocks());

  test('creates a category within the requested shop', async () => {
    categories.nameExistsInShop.mockResolvedValue(false);
    categories.create.mockResolvedValue(21);
    categories.findById.mockResolvedValue({ id: 21, shop_id: 7, name: 'Dairy' });

    const category = await service.createCategory(7, { name: 'Dairy', description: 'Milk products' });

    expect(categories.create).toHaveBeenCalledWith({
      shop_id: 7, name: 'Dairy', description: 'Milk products',
    });
    expect(category.shop_id).toBe(7);
  });

  test('rejects duplicate category names within a shop', async () => {
    categories.nameExistsInShop.mockResolvedValue(true);

    await expect(service.createCategory(7, { name: 'Dairy' }))
      .rejects.toMatchObject({ code: 'CATEGORY_001' });
    expect(categories.create).not.toHaveBeenCalled();
  });

  test('prevents cross-shop update and deletion', async () => {
    categories.findById.mockResolvedValue({ id: 21, shop_id: 8, name: 'Dairy' });

    await expect(service.updateCategory(21, 7, { name: 'Food' }))
      .rejects.toMatchObject({ code: 'CATEGORY_003' });
    await expect(service.deleteCategory(21, 7)).rejects.toMatchObject({ code: 'CATEGORY_003' });
    expect(categories.update).not.toHaveBeenCalled();
    expect(categories.delete).not.toHaveBeenCalled();
  });

  test('preserves categories that still have product references', async () => {
    categories.findById.mockResolvedValue({ id: 21, shop_id: 7, name: 'Dairy' });
    categories.hasProducts.mockResolvedValue(true);

    await expect(service.deleteCategory(21, 7)).rejects.toMatchObject({ code: 'CATEGORY_004' });
    expect(categories.delete).not.toHaveBeenCalled();
  });
});
