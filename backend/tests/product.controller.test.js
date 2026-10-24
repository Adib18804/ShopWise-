jest.mock('../src/services/product.service', () => ({
  createProduct: jest.fn(),
  getShopProducts: jest.fn(),
  getProductById: jest.fn(),
  updateProduct: jest.fn(),
  deleteProduct: jest.fn(),
  getLowStockProducts: jest.fn(),
}));
jest.mock('../src/utils/logger.util', () => ({ error: jest.fn(), info: jest.fn(), warn: jest.fn() }));

const express = require('express');
const request = require('supertest');
const jwt = require('jsonwebtoken');
const config = require('../src/config/env');
const productService = require('../src/services/product.service');
const productRoutes = require('../src/routes/product.routes');

const app = express();
app.use(express.json());
app.use('/api/v1/products', productRoutes);

const tokenForShop = (shopId = 7) => jwt.sign({
  user_id: 4,
  shop_id: shopId,
  email: 'controller@example.test',
}, config.jwt.secret, { algorithm: 'HS256' });

const validProduct = {
  name: 'Rice',
  unit: 'kg',
  selling_price: 45.5,
  default_purchase_price: 40.25,
};

const authorized = (call) => call.set('Authorization', `Bearer ${tokenForShop()}`);

describe('product controller HTTP behavior', () => {
  beforeEach(() => jest.clearAllMocks());

  test('requires authentication and validates request bodies before service calls', async () => {
    await request(app).get('/api/v1/products').expect(401);

    const invalid = await authorized(request(app).post('/api/v1/products')).send({ name: 'R' });
    expect(invalid.status).toBe(422);
    expect(invalid.body.message).toBe('Validation failed');
    expect(productService.createProduct).not.toHaveBeenCalled();

    const invalidSearch = await authorized(request(app).get('/api/v1/products?limit=1000'));
    expect(invalidSearch.status).toBe(422);
    expect(productService.getShopProducts).not.toHaveBeenCalled();

    const invalidId = await authorized(request(app).get('/api/v1/products/not-an-id'));
    expect(invalidId.status).toBe(422);
  });

  test('creates a product with the authenticated shop context and returns 201', async () => {
    productService.createProduct.mockResolvedValueOnce({ id: 12, name: 'Rice' });
    const response = await authorized(request(app).post('/api/v1/products'))
      .send({ ...validProduct, minimum_stock: 2 });

    expect(response.status).toBe(201);
    expect(response.body).toMatchObject({ success: true, data: { product: { id: 12 } } });
    expect(productService.createProduct).toHaveBeenCalledWith(7, expect.objectContaining({
      name: 'Rice', minimum_stock: 2,
    }));
  });

  test('returns 400 when the token has no shop and maps create service errors', async () => {
    const noShop = await request(app).post('/api/v1/products')
      .set('Authorization', `Bearer ${tokenForShop(null)}`)
      .send(validProduct);
    expect(noShop.status).toBe(400);
    expect(productService.createProduct).not.toHaveBeenCalled();

    productService.createProduct.mockRejectedValueOnce(Object.assign(new Error('duplicate product'), { code: 'PRODUCT_003' }));
    const badRequest = await authorized(request(app).post('/api/v1/products')).send(validProduct);
    expect(badRequest.status).toBe(400);
    expect(badRequest.body.message).toBe('duplicate product');

    productService.createProduct.mockRejectedValueOnce(Object.assign(new Error('shop missing'), { code: 'PRODUCT_005' }));
    await authorized(request(app).post('/api/v1/products')).send(validProduct).then((res) => expect(res.status).toBe(404));

    productService.createProduct.mockRejectedValueOnce(new Error('unexpected failure'));
    const serverError = await authorized(request(app).post('/api/v1/products')).send(validProduct);
    expect(serverError.status).toBe(500);
    expect(serverError.body.message).toBe('Failed to create product');
  });

  test('lists products with parsed filters, handles a missing shop, and maps failures to 500', async () => {
    productService.getShopProducts.mockResolvedValueOnce({ products: [{ id: 12 }], total: 1 });
    const response = await authorized(request(app).get('/api/v1/products?q=rice&category_id=3&limit=10&offset=2'));
    expect(response.status).toBe(200);
    expect(productService.getShopProducts).toHaveBeenCalledWith(7, {
      search: 'rice', category_id: 3, limit: 10, offset: 2,
    });

    const noShop = await request(app).get('/api/v1/products').set('Authorization', `Bearer ${tokenForShop(null)}`);
    expect(noShop.status).toBe(400);

    productService.getShopProducts.mockRejectedValueOnce(new Error('query failed'));
    const failure = await authorized(request(app).get('/api/v1/products'));
    expect(failure.status).toBe(500);
    expect(failure.body.message).toBe('Failed to retrieve products');
  });

  test('gets a product and maps not-found, forbidden, missing-shop, and unexpected errors', async () => {
    productService.getProductById.mockResolvedValueOnce({ id: 12 });
    const success = await authorized(request(app).get('/api/v1/products/12'));
    expect(success.status).toBe(200);
    expect(productService.getProductById).toHaveBeenCalledWith(12, 7);

    productService.getProductById.mockRejectedValueOnce(Object.assign(new Error('not found'), { code: 'PRODUCT_005' }));
    expect((await authorized(request(app).get('/api/v1/products/13'))).status).toBe(404);
    productService.getProductById.mockRejectedValueOnce(Object.assign(new Error('forbidden'), { code: 'PRODUCT_006' }));
    expect((await authorized(request(app).get('/api/v1/products/14'))).status).toBe(403);
    productService.getProductById.mockRejectedValueOnce(new Error('query failed'));
    const failure = await authorized(request(app).get('/api/v1/products/15'));
    expect(failure.status).toBe(500);
    expect(failure.body.message).toBe('Failed to retrieve product');

    const noShop = await request(app).get('/api/v1/products/12').set('Authorization', `Bearer ${tokenForShop(null)}`);
    expect(noShop.status).toBe(400);
  });

  test('updates a product and maps validation, authorization, not-found, and server errors', async () => {
    productService.updateProduct.mockResolvedValueOnce({ id: 12, name: 'Brown rice' });
    const success = await authorized(request(app).put('/api/v1/products/12')).send({ name: 'Brown rice' });
    expect(success.status).toBe(200);
    expect(productService.updateProduct).toHaveBeenCalledWith(12, 7, expect.objectContaining({ name: 'Brown rice' }));

    const invalid = await authorized(request(app).put('/api/v1/products/12')).send({ unsupported: true });
    expect(invalid.status).toBe(422);
    expect(productService.updateProduct).toHaveBeenCalledTimes(1);

    productService.updateProduct.mockRejectedValueOnce(Object.assign(new Error('invalid update'), { code: 'PRODUCT_010' }));
    expect((await authorized(request(app).put('/api/v1/products/12')).send({ name: 'Valid name' })).status).toBe(400);
    productService.updateProduct.mockRejectedValueOnce(Object.assign(new Error('missing'), { code: 'PRODUCT_005' }));
    expect((await authorized(request(app).put('/api/v1/products/12')).send({ name: 'Valid name' })).status).toBe(404);
    productService.updateProduct.mockRejectedValueOnce(Object.assign(new Error('forbidden'), { code: 'PRODUCT_006' }));
    expect((await authorized(request(app).put('/api/v1/products/12')).send({ name: 'Valid name' })).status).toBe(403);
    productService.updateProduct.mockRejectedValueOnce(new Error('unexpected'));
    const failure = await authorized(request(app).put('/api/v1/products/12')).send({ name: 'Valid name' });
    expect(failure.status).toBe(500);
    expect(failure.body.message).toBe('Failed to update product');

    const noShop = await request(app).put('/api/v1/products/12')
      .set('Authorization', `Bearer ${tokenForShop(null)}`).send({ name: 'Valid name' });
    expect(noShop.status).toBe(400);
  });

  test('deletes a product and maps access, not-found, conflict, and server errors', async () => {
    productService.deleteProduct.mockResolvedValueOnce(true);
    const success = await authorized(request(app).delete('/api/v1/products/12'));
    expect(success.status).toBe(200);
    expect(productService.deleteProduct).toHaveBeenCalledWith(12, 7);

    productService.deleteProduct.mockRejectedValueOnce(Object.assign(new Error('missing'), { code: 'PRODUCT_005' }));
    expect((await authorized(request(app).delete('/api/v1/products/12'))).status).toBe(404);
    productService.deleteProduct.mockRejectedValueOnce(Object.assign(new Error('forbidden'), { code: 'PRODUCT_006' }));
    expect((await authorized(request(app).delete('/api/v1/products/12'))).status).toBe(403);
    productService.deleteProduct.mockRejectedValueOnce(Object.assign(new Error('has history'), { code: 'PRODUCT_007' }));
    expect((await authorized(request(app).delete('/api/v1/products/12'))).status).toBe(400);
    productService.deleteProduct.mockRejectedValueOnce(new Error('unexpected'));
    const failure = await authorized(request(app).delete('/api/v1/products/12'));
    expect(failure.status).toBe(500);
    expect(failure.body.message).toBe('Failed to delete product');

    const noShop = await request(app).delete('/api/v1/products/12')
      .set('Authorization', `Bearer ${tokenForShop(null)}`);
    expect(noShop.status).toBe(400);
  });

  test('gets low-stock products and handles missing-shop and service errors', async () => {
    productService.getLowStockProducts.mockResolvedValueOnce([{ id: 12 }]);
    const response = await authorized(request(app).get('/api/v1/products/low-stock'));
    expect(response.status).toBe(200);
    expect(productService.getLowStockProducts).toHaveBeenCalledWith(7);

    const noShop = await request(app).get('/api/v1/products/low-stock')
      .set('Authorization', `Bearer ${tokenForShop(null)}`);
    expect(noShop.status).toBe(400);

    productService.getLowStockProducts.mockRejectedValueOnce(new Error('query failed'));
    const failure = await authorized(request(app).get('/api/v1/products/low-stock'));
    expect(failure.status).toBe(500);
    expect(failure.body.message).toBe('Failed to retrieve low stock products');
  });
});
