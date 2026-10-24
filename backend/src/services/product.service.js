const productRepository = require('../repositories/product.repository.js');
const categoryRepository = require('../repositories/category.repository.js');

/**
 * Product service
 */
class ProductService {
  /**
   * Create new product
   */
  async createProduct(shopId, productData) {
    const data = this.#normalizeData(productData);
    // Verify category belongs to shop
    const category = data.category_id == null
      ? null
      : await categoryRepository.findById(data.category_id, shopId);

    if (data.category_id != null && !category) {
      const error = new Error('Category not found');
      error.code = 'PRODUCT_001';
      throw error;
    }
    
    if (category && category.shop_id !== shopId) {
      const error = new Error('Category does not belong to your shop');
      error.code = 'PRODUCT_002';
      throw error;
    }
    
    // Check if product name already exists in shop
    const nameExists = await productRepository.nameExistsInShop(
      shopId,
      data.name,
    );
    
    if (nameExists) {
      const error = new Error('Product name already exists');
      error.code = 'PRODUCT_003';
      throw error;
    }
    
    // Check if barcode exists (if provided)
    if (data.barcode) {
      const barcodeExists = await productRepository.barcodeExistsInShop(
        shopId,
        data.barcode,
      );
      
      if (barcodeExists) {
        const error = new Error('Barcode already exists');
        error.code = 'PRODUCT_004';
        throw error;
      }
    }

    if (data.sku && await productRepository.skuExistsInShop(shopId, data.sku)) {
      const error = new Error('SKU already exists');
      error.code = 'PRODUCT_009';
      throw error;
    }
    
    // Create product
    const productId = await productRepository.create({ ...data, shop_id: shopId });
    if (!productId) {
      const error = new Error('Shop not found');
      error.code = 'PRODUCT_005';
      throw error;
    }
    
    // Get created product with details
    const product = await productRepository.findByIdWithDetails(productId, shopId);
    
    return product;
  }
  
  /**
   * Get product by ID
   */
  async getProductById(productId, shopId) {
    const product = await productRepository.findByIdWithDetails(productId, shopId);
    
    if (!product) {
      const error = new Error('Product not found');
      error.code = 'PRODUCT_005';
      throw error;
    }
    
    // Verify ownership
    if (product.shop_id !== shopId || !product.is_active) {
      const error = new Error('Access denied');
      error.code = 'PRODUCT_006';
      throw error;
    }
    
    return product;
  }
  
  /**
   * Get all products for shop
   */
  async getShopProducts(shopId, options = {}) {
    const products = await productRepository.findByShopId(shopId, options);
    const total = await productRepository.countByShopId(shopId, {
      category_id: options.category_id,
      search: options.search,
    });
    
    return {
      products,
      total,
      limit: options.limit,
      offset: options.offset,
    };
  }
  
  /**
   * Search products
   */
  async searchProducts(shopId, query, options = {}) {
    const products = await productRepository.findByShopId(shopId, {
      search: query,
      ...options,
    });
    
    return products;
  }
  
  /**
   * Update product
   */
  async updateProduct(productId, shopId, updateData) {
    const data = this.#normalizeData(updateData);
    if (Object.keys(data).length === 0) {
      const error = new Error('At least one product field is required');
      error.code = 'PRODUCT_010';
      throw error;
    }
    // Get product and verify ownership
    const product = await productRepository.findByIdAndShopId(productId, shopId);
    
    if (!product) {
      const error = new Error('Product not found');
      error.code = 'PRODUCT_005';
      throw error;
    }
    
    if (product.shop_id !== shopId || !product.is_active) {
      const error = new Error('Access denied');
      error.code = 'PRODUCT_006';
      throw error;
    }
    
    // Verify new category if being changed
    if (data.category_id !== undefined && data.category_id !== product.category_id) {
      const category = data.category_id == null ? null : await categoryRepository.findById(data.category_id, shopId);
      
      if (data.category_id != null && !category) {
        const error = new Error('Category not found');
        error.code = 'PRODUCT_001';
        throw error;
      }
      
      if (category && category.shop_id !== shopId) {
        const error = new Error('Category does not belong to your shop');
        error.code = 'PRODUCT_002';
        throw error;
      }
    }
    
    // Check if new name already exists (if name is being changed)
    if (data.name && data.name !== product.name) {
      const nameExists = await productRepository.nameExistsInShop(
        shopId,
        data.name,
        productId,
      );
      
      if (nameExists) {
        const error = new Error('Product name already exists');
        error.code = 'PRODUCT_003';
        throw error;
      }
    }
    
    // Check if new barcode already exists (if barcode is being changed)
    if (data.barcode !== undefined && data.barcode !== product.barcode) {
      const barcodeExists = await productRepository.barcodeExistsInShop(
        shopId,
        data.barcode,
        productId,
      );
      
      if (barcodeExists) {
        const error = new Error('Barcode already exists');
        error.code = 'PRODUCT_004';
        throw error;
      }
    }

    if (data.sku !== undefined && data.sku !== product.sku
      && await productRepository.skuExistsInShop(shopId, data.sku, productId)) {
      const error = new Error('SKU already exists');
      error.code = 'PRODUCT_009';
      throw error;
    }
    
    // Update product
    await productRepository.update(productId, shopId, data);
    
    // Get updated product with details
    const updatedProduct = await productRepository.findByIdWithDetails(productId, shopId);
    
    return updatedProduct;
  }
  
  /**
   * Delete product
   */
  async deleteProduct(productId, shopId) {
    // Get product and verify ownership
    const product = await productRepository.findByIdAndShopId(productId, shopId);
    
    if (!product) {
      const error = new Error('Product not found');
      error.code = 'PRODUCT_005';
      throw error;
    }
    
    // Preserve batch and sales history; products are deactivated, not deleted.
    await productRepository.deactivate(productId, shopId);
    
    return true;
  }
  
  /**
   * Get low stock products
   */
  async getLowStockProducts(shopId) {
    const products = await productRepository.findLowStockProducts(shopId);
    return products;
  }

  #normalizeData(data) {
    const normalized = { ...data };
    if (normalized.minimum_stock === undefined && normalized.reorder_level !== undefined) {
      normalized.minimum_stock = normalized.reorder_level;
    }
    delete normalized.reorder_level;
    for (const [key, value] of Object.entries(normalized)) {
      if (value === undefined) delete normalized[key];
    }
    return normalized;
  }
}

module.exports = new ProductService();
