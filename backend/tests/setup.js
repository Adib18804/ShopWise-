// Jest setup file
// This file runs before all tests

// Set test environment variables
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_key_for_testing_purposes_only';
process.env.DB_NAME = 'shopwise_test';

// Increase timeout for integration tests
jest.setTimeout(10000);

// Global test utilities can be added here
global.testUtils = {
  // Add test utilities as needed
};
