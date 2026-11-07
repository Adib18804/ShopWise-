/*
 * One-time trusted setup tool for the ShopWise feedback administrator.
 *
 * Usage:
 *   node set_firebase_admin_claim.js <firebase-auth-uid> [--revoke]
 *
 * Authenticate using GOOGLE_APPLICATION_CREDENTIALS or Google Application
 * Default Credentials. Never put a service-account key in the repository.
 */
'use strict';

let admin;
try {
  admin = require('firebase-admin');
} catch (_) {
  console.error(
    'firebase-admin is not installed. From backend/, run: ' +
      'npm install --no-save --package-lock=false firebase-admin',
  );
  process.exit(1);
}

const uid = process.argv[2];
const revoke = process.argv[3] === '--revoke';

if (!uid || uid.startsWith('--')) {
  console.error(
    'Usage: node set_firebase_admin_claim.js <firebase-auth-uid> [--revoke]',
  );
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
});

async function main() {
  const auth = admin.auth();
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
      'Check that Application Default Credentials are configured and have ' +
      'Firebase Authentication Admin privileges.',
  );
  process.exitCode = 1;
});
