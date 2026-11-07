# Feedback administrator setup

Firebase custom claims must be granted by a trusted Admin SDK environment; the
Flutter app must never assign its own `admin` claim.

1. Find the intended owner's Firebase Authentication UID in Firebase Console.
2. Download or select a service-account credential with Firebase Authentication
   user-management privileges. Keep the credential outside this repository.
3. From `backend/`, install the Admin SDK locally without saving it to the
   backend API's package manifest:

   ```powershell
   npm install --no-save --package-lock=false firebase-admin
   $env:GOOGLE_APPLICATION_CREDENTIALS = 'C:\secure\shopwise-admin-service-account.json'
   node .\set_firebase_admin_claim.js OWNER_FIREBASE_UID
   ```

4. Sign in again in ShopWise (or force-refresh the ID token). The More sheet
   reads the refreshed token and shows **Admin Panel** only when `admin: true`.

To revoke the claim, run:

```powershell
node .\set_firebase_admin_claim.js OWNER_FIREBASE_UID --revoke
```

Do not commit service-account files. The script preserves any other existing
custom claims when granting or revoking this one.
