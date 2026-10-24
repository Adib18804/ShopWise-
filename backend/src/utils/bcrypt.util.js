const bcrypt = require('bcrypt');
const config = require('../config/env.js');

/**
 * Hash password
 */
async function hashPassword(password) {
  return bcrypt.hash(password, config.security.bcryptSaltRounds);
}

/**
 * Compare password with hash
 */
async function comparePassword(password, hash) {
  return bcrypt.compare(password, hash);
}

module.exports = {
  hashPassword,
  comparePassword,
};
