require('dotenv').config();

const config = {
  // Server
  nodeEnv: process.env.NODE_ENV || 'development',
  port: parseInt(process.env.PORT, 10) || 3000,

  // Database
  database: {
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT, 10) || 3306,
    name: process.env.DB_NAME || 'shopwise_dev',
    user: process.env.DB_USER || 'shopwise_user',
    password: process.env.DB_PASSWORD || '',
  },

  // JWT
  jwt: {
    secret: process.env.JWT_SECRET,
    expiresIn: process.env.JWT_EXPIRES_IN || '24h',
  },

  // API
  api: {
    baseUrl: process.env.API_BASE_URL || 'http://localhost:3000/api/v1',
  },

  // CORS
  cors: {
    allowedOrigins: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
  },

  // Rate Limiting
  rateLimit: {
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS, 10) || 60000,
    maxRequests: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS, 10) || 100,
    authWindowMs: parseInt(process.env.AUTH_RATE_LIMIT_WINDOW_MS, 10) || 15 * 60 * 1000,
    authMaxRequests: parseInt(process.env.AUTH_RATE_LIMIT_MAX_REQUESTS, 10) || 5,
  },

  // Logging
  logging: {
    level: process.env.LOG_LEVEL || 'info',
    file: process.env.LOG_FILE || 'logs/shopwise.log',
  },

  // Analysis Configuration
  analysis: {
    expiryRiskWindowDays: parseInt(process.env.EXPIRY_RISK_WINDOW_DAYS, 10) || 14,
    stockAnalysisPeriodDays: parseInt(process.env.STOCK_ANALYSIS_PERIOD_DAYS, 10) || 30,
    slowMovingThresholdDays: parseInt(process.env.SLOW_MOVING_THRESHOLD_DAYS, 10) || 30,
    defaultTargetStockDays: parseInt(process.env.DEFAULT_TARGET_STOCK_DAYS, 10) || 7,
  },

  // Notifications
  notifications: {
    enablePushNotifications: process.env.ENABLE_PUSH_NOTIFICATIONS === 'true',
    dailySummaryTime: process.env.DAILY_SUMMARY_TIME || '18:00',
  },

  // Security
  security: {
    bcryptSaltRounds: parseInt(process.env.BCRYPT_SALT_ROUNDS, 10) || 10,
  },
};

// Validation
if (!config.jwt.secret || config.jwt.secret.length < 32) {
  throw new Error('JWT_SECRET must be set to at least 32 characters');
}

if (config.nodeEnv === 'production') {
  if (!config.database.password) {
    throw new Error('DB_PASSWORD must be set in production environment');
  }
}

module.exports = config;
