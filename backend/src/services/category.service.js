const categoryRepository = require('../repositories/category.repository.js');

/**
 * Category service
 */
class CategoryService {
  /**
   * Create new category
   */
  async createCategory(shopId, categoryData) {
    // Check if category name already exists in shop
    const nameExists = await categoryRepository.nameExistsInShop(
      shopId,
      categoryData.name,
    );
    
    if (nameExists) {
      const error = new Error('Category name already exists');
      error.code = 'CATEGORY_001';
      throw error;
    }
    
    // Create category
    const categoryId = await categoryRepository.create({
      shop_id: shopId,
      name: categoryData.name,
      description: categoryData.description,
    });
    if (!categoryId) {
      const error = new Error('Shop not found');
      error.code = 'CATEGORY_002';
      throw error;
    }
    
    // Get created category
    const category = await categoryRepository.findById(categoryId, shopId);
    
    return category;
  }
  
  /**
   * Get category by ID
   */
  async getCategoryById(categoryId, shopId) {
    const category = await categoryRepository.findById(categoryId, shopId);
    
    if (!category) {
      const error = new Error('Category not found');
      error.code = 'CATEGORY_002';
      throw error;
    }
    
    // Verify ownership
    if (category.shop_id !== shopId) {
      const error = new Error('Access denied');
      error.code = 'CATEGORY_003';
      throw error;
    }
    
    return category;
  }
  
  /**
   * Get all categories for shop
   */
  async getShopCategories(shopId, options = {}) {
    const categories = await categoryRepository.findByShopIdWithCounts(shopId);
    return categories;
  }
  
  /**
   * Update category
   */
  async updateCategory(categoryId, shopId, updateData) {
    // Get category and verify ownership
    const category = await categoryRepository.findById(categoryId, shopId);
    
    if (!category) {
      const error = new Error('Category not found');
      error.code = 'CATEGORY_002';
      throw error;
    }
    
    if (category.shop_id !== shopId) {
      const error = new Error('Access denied');
      error.code = 'CATEGORY_003';
      throw error;
    }
    
    // Check if new name already exists (if name is being changed)
    if (updateData.name && updateData.name !== category.name) {
      const nameExists = await categoryRepository.nameExistsInShop(
        shopId,
        updateData.name,
        categoryId,
      );
      
      if (nameExists) {
        const error = new Error('Category name already exists');
        error.code = 'CATEGORY_001';
        throw error;
      }
    }
    
    // Update category
    await categoryRepository.update(categoryId, shopId, updateData);
    
    // Get updated category
    const updatedCategory = await categoryRepository.findById(categoryId, shopId);
    
    return updatedCategory;
  }
  
  /**
   * Delete category
   */
  async deleteCategory(categoryId, shopId) {
    // Get category and verify ownership
    const category = await categoryRepository.findById(categoryId, shopId);
    
    if (!category) {
      const error = new Error('Category not found');
      error.code = 'CATEGORY_002';
      throw error;
    }
    
    if (category.shop_id !== shopId) {
      const error = new Error('Access denied');
      error.code = 'CATEGORY_003';
      throw error;
    }
    
    // Check if category has products
    const hasProducts = await categoryRepository.hasProducts(categoryId, shopId);
    
    if (hasProducts) {
      const error = new Error('Cannot delete category with products');
      error.code = 'CATEGORY_004';
      throw error;
    }
    
    // Delete category
    await categoryRepository.delete(categoryId, shopId);
    
    return true;
  }
}

module.exports = new CategoryService();
