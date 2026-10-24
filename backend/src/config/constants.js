/**
 * Application-wide constants
 */

// Transaction Types
const TRANSACTION_TYPES = {
  PURCHASE: 'PURCHASE',
  SALE: 'SALE',
  ADJUSTMENT_IN: 'ADJUSTMENT_IN',
  ADJUSTMENT_OUT: 'ADJUSTMENT_OUT',
  RETURN: 'RETURN',
  EXPIRED: 'EXPIRED',
  DAMAGED: 'DAMAGED',
};

// Notification Types
const NOTIFICATION_TYPES = {
  EXPIRY_RISK: 'EXPIRY_RISK',
  STOCK_OUT: 'STOCK_OUT',
  RESTOCK: 'RESTOCK',
  SLOW_MOVING: 'SLOW_MOVING',
  DAILY_SUMMARY: 'DAILY_SUMMARY',
  SYSTEM: 'SYSTEM',
};

// Notification Severity
const NOTIFICATION_SEVERITY = {
  INFO: 'INFO',
  WARNING: 'WARNING',
  CRITICAL: 'CRITICAL',
};

// Reference Types
const REFERENCE_TYPES = {
  PRODUCT: 'PRODUCT',
  BATCH: 'BATCH',
  SALE: 'SALE',
  SHOP: 'SHOP',
  NONE: 'NONE',
};

// Risk Levels
const RISK_LEVELS = {
  CRITICAL: 'CRITICAL',
  HIGH: 'HIGH',
  MEDIUM: 'MEDIUM',
  WARNING: 'WARNING',
  LOW_STOCK: 'LOW_STOCK',
  NORMAL: 'NORMAL',
  EXPIRED: 'EXPIRED',
};

// Stock Status
const STOCK_STATUS = {
  IN_STOCK: 'IN_STOCK',
  LOW_STOCK: 'LOW_STOCK',
  OUT_OF_STOCK: 'OUT_OF_STOCK',
  EXPIRING_SOON: 'EXPIRING_SOON',
  EXPIRED: 'EXPIRED',
};

// Product Status
const PRODUCT_STATUS = {
  ACTIVE: 'ACTIVE',
  INACTIVE: 'INACTIVE',
  DEAD_STOCK: 'DEAD_STOCK',
  SLOW_MOVING: 'SLOW_MOVING',
  NORMAL: 'NORMAL',
};

// Restock Priority
const RESTOCK_PRIORITY = {
  HIGH: 'HIGH',
  MEDIUM: 'MEDIUM',
  LOW: 'LOW',
};

// Analysis Periods
const ANALYSIS_PERIODS = {
  TODAY: 'today',
  WEEK: 'week',
  MONTH: 'month',
  CUSTOM: 'custom',
};

// Languages
const LANGUAGES = {
  ENGLISH: 'en',
  BANGLA: 'bn',
};

// Default Values
const DEFAULTS = {
  TARGET_STOCK_DAYS: 7,
  MINIMUM_STOCK: 0,
  CURRENCY: 'BDT',
  LANGUAGE: 'bn',
  UNIT: 'piece',
  PAGINATION_LIMIT: 20,
  MAX_PAGINATION_LIMIT: 100,
};

// Error Codes
const ERROR_CODES = {
  // Authentication
  AUTH_001: 'Invalid credentials',
  AUTH_002: 'Token expired',
  AUTH_003: 'Invalid token',
  AUTH_004: 'User not found',
  AUTH_005: 'Email already exists',
  AUTH_006: 'Phone already exists',
  
  // Shop
  SHOP_001: 'Shop not found',
  SHOP_002: 'Shop already exists',
  
  // Product
  PROD_001: 'Product not found',
  PROD_002: 'Insufficient stock',
  PROD_003: 'SKU already exists',
  
  // Batch
  BATCH_001: 'Batch not found',
  BATCH_002: 'Invalid expiry date',
  
  // Sale
  SALE_001: 'Invalid sale date',
  SALE_002: 'Empty sale items',
  
  // Validation
  VAL_001: 'Validation failed',
  
  // Server
  SRV_001: 'Internal server error',
};

// HTTP Status Codes
const HTTP_STATUS = {
  OK: 200,
  CREATED: 201,
  BAD_REQUEST: 400,
  UNAUTHORIZED: 401,
  FORBIDDEN: 403,
  NOT_FOUND: 404,
  UNPROCESSABLE_ENTITY: 422,
  TOO_MANY_REQUESTS: 429,
  INTERNAL_SERVER_ERROR: 500,
};

module.exports = {
  TRANSACTION_TYPES,
  NOTIFICATION_TYPES,
  NOTIFICATION_SEVERITY,
  REFERENCE_TYPES,
  RISK_LEVELS,
  STOCK_STATUS,
  PRODUCT_STATUS,
  RESTOCK_PRIORITY,
  ANALYSIS_PERIODS,
  LANGUAGES,
  DEFAULTS,
  ERROR_CODES,
  HTTP_STATUS,
};
