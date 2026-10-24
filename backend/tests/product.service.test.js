jest.mock('../src/repositories/product.repository', () => ({
  create: jest.fn(), findByIdWithDetails: jest.fn(), findById: jest.fn(), findByIdAndShopId: jest.fn(),
  nameExistsInShop: jest.fn(), barcodeExistsInShop: jest.fn(), skuExistsInShop: jest.fn(),
  update: jest.fn(), deactivate: jest.fn(), findByShopId: jest.fn(),
  countByShopId: jest.fn(), findLowStockProducts: jest.fn(), hasBatches: jest.fn(), hasSales: jest.fn(),
}));
jest.mock('../src/repositories/category.repository', () => ({ findById: jest.fn() }));

const products = require('../src/repositories/product.repository');
const categories = require('../src/repositories/category.repository');
const service = require('../src/services/product.service');

describe('product service canonical contract', () => {
  beforeEach(() => jest.clearAllMocks());

  test('maps the existing reorder field into minimum_stock and persists required prices', async () => {
    categories.findById.mockResolvedValue({ id: 4, shop_id: 7 });
    products.nameExistsInShop.mockResolvedValue(false);
    products.barcodeExistsInShop.mockResolvedValue(false);
    products.skuExistsInShop.mockResolvedValue(false);
    products.create.mockResolvedValue(12);
    products.findByIdWithDetails.mockResolvedValue({ id: 12, minimum_stock: 3 });

    await service.createProduct(7, {
      category_id: 4,
      name: 'Rice',
      unit: 'kg',
      selling_price: 80,
      default_purchase_price: 70,
      reorder_level: 3,
    });

    expect(products.create).toHaveBeenCalledWith(expect.objectContaining({
      shop_id: 7,
      selling_price: 80,
      default_purchase_price: 70,
      minimum_stock: 3,
    }));
    expect(products.create.mock.calls[0][0]).not.toHaveProperty('reorder_level');
  });

  test('preserves a zero minimum stock on update', async () => {
    products.findByIdAndShopId.mockResolvedValue({ id: 12, shop_id: 7, is_active: 1, minimum_stock: 5 });
    products.update.mockResolvedValue(true);
    products.findByIdWithDetails.mockResolvedValue({ id: 12, minimum_stock: 0 });

    await service.updateProduct(12, 7, { minimum_stock: 0 });

    expect(products.update).toHaveBeenCalledWith(12, 7, { minimum_stock: 0 });
  });

  test('deactivates a product to preserve business history', async () => {
    products.findByIdAndShopId.mockResolvedValue({ id: 12, shop_id: 7, is_active: 1 });
    products.deactivate.mockResolvedValue(true);
    await expect(service.deleteProduct(12, 7)).resolves.toBe(true);
    expect(products.deactivate).toHaveBeenCalledWith(12, 7);
  });
});
