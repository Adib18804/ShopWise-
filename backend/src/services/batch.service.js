const pool = require('../config/database');
const batchRepository = require('../repositories/batch.repository');
const productRepository = require('../repositories/product.repository');
const { getBusinessDate, isDateOnly, dateOnlyDaysBetween } = require('../utils/date.util');

class BatchServiceError extends Error {
  constructor(code, message, statusCode) {
    super(message);
    this.code = code;
    this.statusCode = statusCode;
  }
}

const notFound = () => new BatchServiceError('RESOURCE_NOT_FOUND', 'Resource not found', 404);
const invalid = (message) => new BatchServiceError('BATCH_VALIDATION', message, 400);
const conflict = (message) => new BatchServiceError('BATCH_CONFLICT', message, 409);

const getOwnedProduct = async (productId, shopId, connection, forUpdate = false) => {
  if (!shopId) throw notFound();
  const product = await productRepository.findByIdAndShopId(productId, shopId, connection, forUpdate);
  if (!product) throw notFound();
  return product;
};

const getOwnedBatch = async (batchId, shopId, connection, forUpdate = false) => {
  if (!shopId) throw notFound();
  const batch = await batchRepository.findByIdWithProduct(batchId, shopId, connection, forUpdate);
  if (!batch) throw notFound();
  return batch;
};

const normalizeDate = (value) => {
  if (value == null) return null;
  if (typeof value === 'string') return value.slice(0, 10);
  return getBusinessDate(new Date(value));
};

const getDaysUntilExpiry = (expiryDate, today = getBusinessDate()) => {
  const date = normalizeDate(expiryDate);
  return date ? dateOnlyDaysBetween(today, date) : null;
};

const getBatchStatus = (batch, minimumStock = 0, today = getBusinessDate()) => {
  const quantity = Number(batch.quantity);
  if (quantity <= 0) return 'DEPLETED';
  const days = getDaysUntilExpiry(batch.expiry_date, today);
  if (days !== null && days < 0) return 'EXPIRED';
  if (days !== null && days <= 7) return 'NEAR_EXPIRY';
  if (quantity <= Number(minimumStock)) return 'LOW_STOCK';
  return 'ACTIVE';
};

const addBatch = async (productId, batchData, shopId) => {
  const today = getBusinessDate();
  if (!isDateOnly(batchData.purchase_date) || batchData.purchase_date > today) {
    throw invalid('Purchase date must be a valid date and cannot be in the future');
  }
  if (batchData.expiry_date != null) {
    if (!isDateOnly(batchData.expiry_date)) throw invalid('Expiry date must be a valid date');
    if (batchData.expiry_date <= batchData.purchase_date) {
      throw invalid('Expiry date must be after purchase date');
    }
  }
  const quantity = Number(batchData.quantity);
  const purchasePrice = Number(batchData.purchase_price);
  if (!Number.isFinite(quantity) || quantity <= 0) {
    throw invalid('Quantity must be a valid number greater than 0');
  }
  if (!Number.isFinite(purchasePrice) || purchasePrice < 0) {
    throw invalid('Purchase price must be a valid number 0 or greater');
  }

  const connection = await pool.getConnection();
  let batchId;
  try {
    await connection.beginTransaction();
    await getOwnedProduct(productId, shopId, connection, true);
    batchId = await batchRepository.create({ ...batchData, quantity, purchase_price: purchasePrice, product_id: productId }, shopId, connection);
    await batchRepository.createTransaction({
      product_id: productId,
      batch_id: batchId,
      transaction_type: 'PURCHASE',
      quantity,
      notes: `Stock purchase${batchData.batch_number ? ` - ${batchData.batch_number}` : ''}`,
    }, shopId, connection);
    await connection.commit();
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }

  const [batch, product] = await Promise.all([
    batchRepository.findById(batchId, shopId),
    getOwnedProduct(productId, shopId),
  ]);
  const currentStock = await batchRepository.getTotalStockByProductId(productId, shopId);
  return {
    batch: { ...batch, status: getBatchStatus(batch, product.minimum_stock) },
    product: {
      id: product.id, name: product.name, unit: product.unit,
      current_stock: currentStock,
    },
  };
};

const getProductBatches = async (productId, includeDepleted = false, shopId) => {
  const product = await getOwnedProduct(productId, shopId);
  const today = getBusinessDate();
  const batches = await batchRepository.findByProductId(productId, shopId, includeDepleted);
  return {
    product: {
      id: product.id, name: product.name, unit: product.unit,
      current_stock: await batchRepository.getTotalStockByProductId(productId, shopId),
    },
    batches: batches.map(batch => ({
      ...batch,
      days_until_expiry: getDaysUntilExpiry(batch.expiry_date, today),
      status: getBatchStatus(batch, product.minimum_stock, today),
    })),
  };
};

const getBatchById = async (batchId, shopId) => {
  const batch = await getOwnedBatch(batchId, shopId);
  const enriched = {
    ...batch,
    days_until_expiry: getDaysUntilExpiry(batch.expiry_date),
    status: getBatchStatus(batch, batch.minimum_stock),
  };
  return enriched;
};

const updateBatch = async (batchId, updateData, shopId) => {
  const updateFields = ['quantity', 'purchase_price', 'expiry_date'];
  if (!updateFields.some(field => updateData[field] !== undefined)) {
    throw invalid('At least one batch field is required');
  }
  if (updateData.expiry_date != null && !isDateOnly(updateData.expiry_date)) {
    throw invalid('Expiry date must be a valid YYYY-MM-DD date');
  }
  if (updateData.quantity !== undefined
    && (!Number.isFinite(Number(updateData.quantity)) || Number(updateData.quantity) < 0)) {
    throw invalid('Quantity must be a valid number 0 or greater');
  }
  if (updateData.purchase_price !== undefined
    && (!Number.isFinite(Number(updateData.purchase_price)) || Number(updateData.purchase_price) < 0)) {
    throw invalid('Purchase price must be a valid number 0 or greater');
  }

  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const batch = await getOwnedBatch(batchId, shopId, connection, true);
    if (updateData.expiry_date != null
      && updateData.expiry_date <= normalizeDate(batch.purchase_date)) {
      throw invalid('Expiry date must be after purchase date');
    }
    const oldQuantity = Number(batch.quantity);
    const newQuantity = updateData.quantity === undefined ? oldQuantity : Number(updateData.quantity);
    await batchRepository.update(batchId, shopId, updateData, connection);
    if (newQuantity !== oldQuantity) {
      const quantityIncreased = newQuantity > oldQuantity;
      await batchRepository.createTransaction({
        product_id: batch.product_id,
        batch_id: batchId,
        transaction_type: quantityIncreased ? 'ADJUSTMENT_IN' : 'ADJUSTMENT_OUT',
        quantity: Math.abs(newQuantity - oldQuantity),
        notes: updateData.notes || 'Manual stock adjustment',
      }, shopId, connection);
    }
    await connection.commit();
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
  return getBatchById(batchId, shopId);
};

const deleteBatch = async (batchId, shopId) => {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const batch = await getOwnedBatch(batchId, shopId, connection, true);
    if (Number(batch.quantity) > 0) {
      throw conflict('A batch with remaining stock cannot be deactivated');
    }
    // References are intentionally retained; deactivation preserves audit and
    // sale relationships while removing the batch from current stock/FEFO.
    const hasStockHistory = await batchRepository.hasStockReferences(batchId, shopId, connection);
    const hasSalesHistory = await batchRepository.hasSalesReferences(batchId, shopId, connection);
    // Any references are retained by deactivating rather than deleting.
    void hasStockHistory;
    void hasSalesHistory;
    await batchRepository.deactivate(batchId, shopId, connection);
    await connection.commit();
    return true;
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
};

const getStockHistory = async (productId, limit = 50, offset = 0, shopId) => {
  const product = await getOwnedProduct(productId, shopId);
  const transactions = await batchRepository.getTransactionsByProductId(productId, shopId, limit, offset);
  const total = await batchRepository.getTransactionCountByProductId(productId, shopId);
  return {
    product: { id: product.id, name: product.name, unit: product.unit },
    transactions,
    pagination: { total, limit, offset, hasMore: offset + transactions.length < total },
  };
};

const getFEFORecommendations = async (productId, shopId) => {
  const product = await getOwnedProduct(productId, shopId);
  const today = getBusinessDate();
  const active = await batchRepository.findByProductId(productId, shopId, false);
  const sellable = active.filter(batch => {
    const days = getDaysUntilExpiry(batch.expiry_date, today);
    return Number(batch.quantity) > 0 && days !== null && days >= 0;
  });
  const batches = sellable.map((batch, index) => {
    const days = getDaysUntilExpiry(batch.expiry_date, today);
    return {
      batch_id: batch.id,
      batch_number: batch.batch_number,
      quantity: Number(batch.quantity),
      expiry_date: normalizeDate(batch.expiry_date),
      days_until_expiry: days,
      status: getBatchStatus(batch, product.minimum_stock, today),
      priority: index + 1,
      recommendation: index === 0
        ? `Sell this batch first (expires in ${days} days)`
        : 'Sell after the earlier-priority batches are depleted',
    };
  });
  return {
    product: {
      id: product.id, name: product.name, unit: product.unit,
      total_stock: await batchRepository.getTotalStockByProductId(productId, shopId),
    },
    batches,
    null_expiry_policy: 'Batches without an expiry date are omitted from FEFO recommendations, as defined in BUSINESS_LOGIC.md.',
  };
};

const getExpiringBatches = async (shopId, daysThreshold = 30) => {
  const today = getBusinessDate();
  const end = new Date(`${today}T00:00:00Z`);
  end.setUTCDate(end.getUTCDate() + daysThreshold);
  const endDate = end.toISOString().slice(0, 10);
  return batchRepository.findExpiringBatches(shopId, today, endDate);
};

module.exports = {
  addBatch, getProductBatches, getBatchById, updateBatch, deleteBatch,
  getStockHistory, getExpiringBatches, getFEFORecommendations,
  getBatchStatus, getDaysUntilExpiry,
};
