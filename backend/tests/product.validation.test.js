const express = require('express');
const request = require('supertest');
const { createProductValidation, updateProductValidation } = require('../src/validators/product.validator');
const validate = require('../src/middleware/validate.middleware');

const app = express();
app.use(express.json());
app.post('/products', createProductValidation, validate, (req, res) => res.sendStatus(200));
app.put('/products/:id', updateProductValidation, validate, (req, res) => res.sendStatus(200));

describe('product request validation', () => {
  test('requires both prices in the create payload', async () => {
    const response = await request(app).post('/products').send({
      category_id: 1, name: 'Rice', unit: 'kg',
    });
    expect(response.status).toBe(422);
    expect(response.body.errors.map(error => error.field)).toEqual(expect.arrayContaining([
      'selling_price', 'default_purchase_price',
    ]));
  });

  test('accepts the full canonical create contract', async () => {
    const response = await request(app).post('/products').send({
      category_id: 1, name: 'Rice', sku: 'RICE-1', unit: 'kg',
      selling_price: 80, default_purchase_price: 70, minimum_stock: 4.5,
    });
    expect(response.status).toBe(200);
  });

  test('rejects an empty update and conflicting old/new threshold names', async () => {
    const empty = await request(app).put('/products/1').send({});
    expect(empty.status).toBe(422);
    const conflict = await request(app).put('/products/1').send({ minimum_stock: 2, reorder_level: 2 });
    expect(conflict.status).toBe(422);
  });
});
