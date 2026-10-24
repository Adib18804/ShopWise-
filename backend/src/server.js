const app = require('./app.js');
const config = require('./config/env.js');
const logger = require('./utils/logger.util.js');

// Start server
const server = app.listen(config.port, () => {
  logger.info(`
╔════════════════════════════════════════════════════════╗
║                                                        ║
║  ✨ ShopWise Backend API                              ║
║                                                        ║
║  🚀 Server running on port ${config.port}                       ║
║  🌍 Environment: ${config.nodeEnv.padEnd(30)} ║
║  📊 Database: ${config.database.name.padEnd(30)} ║
║  🔒 JWT Auth: Enabled                                 ║
║                                                        ║
║  📖 API Docs: ${config.api.baseUrl.padEnd(30)} ║
║  ❤️  Health Check: http://localhost:${config.port}/api/health  ║
║                                                        ║
╚════════════════════════════════════════════════════════╝
  `);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM signal received: closing HTTP server');
  server.close(() => {
    logger.info('HTTP server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  logger.info('SIGINT signal received: closing HTTP server');
  server.close(() => {
    logger.info('HTTP server closed');
    process.exit(0);
  });
});

// Handle unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled Rejection at:', promise, 'reason:', reason);
});

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  logger.error('Uncaught Exception:', error);
  process.exit(1);
});

module.exports = server;
