/*
 * One-time trusted setup tool for the ShopWise feedback administrator.
 *
 * Usage:
 *   node set_firebase_admin_claim.js <firebase-auth-uid> [--revoke]
 *
 * Keep service-account.json out of version control. It grants privileged
 * access to the Firebase project.
 */
'use strict';

const { cert, getApps, initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const serviceAccount = require('./service-account.json');

const uid = process.argv[2];
const revoke = process.argv[3] === '--revoke';

if (!uid || uid.startsWith('--')) {
  console.error(
    'Usage: node set_firebase_admin_claim.js <firebase-auth-uid> [--revoke]',
  );
  process.exit(1);
}

const app =
  getApps()[0] ||
  initializeApp({
    credential: cert(serviceAccount),
  });

async function main() {
  const auth = getAuth(app);
  const user = await auth.getUser(uid);
  const claims = { ...(user.customClaims || {}) };

  if (revoke) {
    delete claims.admin;
  } else {
    claims.admin = true;
  }

  await auth.setCustomUserClaims(uid, claims);
  console.log(
    `Admin claim ${revoke ? 'removed from' : 'granted to'} Firebase UID ${uid}. ` +
      'The user must refresh their ID token by signing in again.',
  );
}

main().catch((error) => {
  console.error(
    `Could not update admin claim: ${error.message}\n` +
      'Verify the service-account file and its Firebase Authentication ' +
      'Admin privileges.',
  );
  process.exitCode = 1;
});
