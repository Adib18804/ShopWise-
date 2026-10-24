# Authentication Module Testing Guide

This guide explains how to test the complete authentication system (backend + frontend).

## Prerequisites

### Backend Setup

1. **MySQL Database Running**
   ```bash
   # Make sure MySQL is running and configured
   mysql -u root -p
   ```

2. **Environment Variables**
   ```bash
   cd backend
   # Copy .env.example to .env and configure
   cp .env.example .env
   ```

   Required variables in `.env`:
   ```
   PORT=3000
   DB_HOST=localhost
   DB_PORT=3306
   DB_USER=root
   DB_PASSWORD=your_password
   DB_NAME=shopwise
   JWT_SECRET=your_super_secret_jwt_key_minimum_32_characters
   JWT_EXPIRES_IN=24h
   ```

3. **Install Dependencies**
   ```bash
   cd backend
   npm install
   ```

4. **Run Database Migrations and Seed Data**
   ```bash
   # Run migrations to create tables
   npm run migrate

   # Seed test data
   npm run seed
   ```

   Test user credentials after seeding:
   - **Email**: rahim@test.com
   - **Password**: Test@123

### Frontend Setup

1. **Flutter Dependencies**
   ```bash
   cd shopwise_app
   flutter pub get
   ```

2. **Firebase Configuration** (Required for app initialization)
   - For testing, Firebase will initialize but auth features use our custom backend
   - Full Firebase configuration can be done later

3. **Android Emulator or Device**
   ```bash
   # Start emulator or connect device
   flutter devices
   ```

## Testing the Backend API

### Start Backend Server

```bash
cd backend
npm start
```

Server will start on `http://localhost:3000`

### Test API Endpoints with curl

#### 1. Register New User

```bash
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test User",
    "phone": "01712345678",
    "email": "test@example.com",
    "password": "Test@1234",
    "preferred_language": "bn"
  }'
```

**Expected Response** (201 Created):
```json
{
  "success": true,
  "message": "Registration successful",
  "data": {
    "user": {
      "id": 2,
      "name": "Test User",
      "phone": "01712345678",
      "email": "test@example.com",
      "preferred_language": "bn",
      "has_shop": false,
      "shop_id": null,
      "created_at": "2024-01-01T00:00:00.000Z",
      "updated_at": "2024-01-01T00:00:00.000Z"
    },
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

#### 2. Login with Email

```bash
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "rahim@test.com",
    "password": "Test@123"
  }'
```

#### 3. Login with Phone

```bash
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "01712345678",
    "password": "Test@123"
  }'
```

**Expected Response** (200 OK):
```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "user": {
      "id": 1,
      "name": "Rahim Khan",
      "phone": "01712345678",
      "email": "rahim@test.com",
      "preferred_language": "bn",
      "has_shop": true,
      "shop_id": 1,
      "shop": {
        "id": 1,
        "shop_name": "Rahim Store",
        "address": "123 Main St, Dhaka",
        "phone": "01712345678",
        "currency": "BDT"
      },
      "created_at": "2024-01-01T00:00:00.000Z",
      "updated_at": "2024-01-01T00:00:00.000Z"
    },
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

#### 4. Get Current User (Protected Route)

```bash
# Replace YOUR_JWT_TOKEN with actual token from login/register response
curl -X GET http://localhost:3000/api/v1/auth/me \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Expected Response** (200 OK):
```json
{
  "success": true,
  "message": "User retrieved successfully",
  "data": {
    "user": {
      "id": 1,
      "name": "Rahim Khan",
      "phone": "01712345678",
      "email": "rahim@test.com",
      "preferred_language": "bn",
      "has_shop": true,
      "shop_id": 1
    }
  }
}
```

#### 5. Logout

```bash
curl -X POST http://localhost:3000/api/v1/auth/logout \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### Test Validation Errors

#### Invalid Phone Number

```bash
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test User",
    "phone": "123456",
    "email": "test@example.com",
    "password": "Test@1234"
  }'
```

**Expected Response** (400 Bad Request):
```json
{
  "success": false,
  "message": "Validation failed",
  "errors": [
    {
      "field": "phone",
      "message": "Invalid Bangladesh phone number format"
    }
  ]
}
```

#### Weak Password

```bash
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test User",
    "phone": "01712345678",
    "email": "test@example.com",
    "password": "weak"
  }'
```

**Expected Response** (400 Bad Request):
```json
{
  "success": false,
  "message": "Validation failed",
  "errors": [
    {
      "field": "password",
      "message": "Password must be between 8 and 50 characters"
    }
  ]
}
```

#### Duplicate Email

```bash
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test User",
    "phone": "01787654321",
    "email": "rahim@test.com",
    "password": "Test@1234"
  }'
```

**Expected Response** (400 Bad Request):
```json
{
  "success": false,
  "message": "Email already exists",
  "errors": [
    {
      "field": "email",
      "message": "Email already exists"
    }
  ]
}
```

#### Invalid Credentials

```bash
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "rahim@test.com",
    "password": "WrongPassword"
  }'
```

**Expected Response** (401 Unauthorized):
```json
{
  "success": false,
  "message": "Invalid credentials"
}
```

## Testing the Flutter App

### Run the Flutter App

```bash
cd shopwise_app
flutter run
```

### Testing Flow

1. **Splash Screen**
   - App shows splash screen with ShopWise logo
   - Checks authentication state
   - Navigates to Welcome or Dashboard based on auth state

2. **Welcome Screen**
   - Shows app logo and name
   - Two buttons: "লগইন করুন" (Login) and "নতুন অ্যাকাউন্ট তৈরি করুন" (Register)

3. **Register Screen**
   - Test with valid data:
     - Name: "Test User"
     - Phone: "01712345678"
     - Email: "newuser@test.com"
     - Password: "Test@1234"
     - Confirm Password: "Test@1234"
   - Test validation errors:
     - Empty fields
     - Invalid phone number (e.g., "123456")
     - Invalid email (e.g., "invalid.email")
     - Weak password (e.g., "weak")
     - Mismatched passwords
   - Test duplicate email/phone

4. **Login Screen**
   - Test with seeded user:
     - Identifier: "rahim@test.com"
     - Password: "Test@123"
   - Test with phone number:
     - Identifier: "01712345678"
     - Password: "Test@123"
   - Test validation errors:
     - Empty fields
     - Invalid credentials

5. **Dashboard Screen**
   - After successful login/register
   - Shows user name, email, phone
   - Shows shop status
   - Logout button in app bar
   - Test logout functionality

### Expected Behaviors

#### Successful Registration
1. Form validates all fields
2. API call to `/api/v1/auth/register`
3. Token saved to secure storage
4. Navigation to Dashboard
5. User info displayed

#### Successful Login
1. Form validates identifier and password
2. API call to `/api/v1/auth/login`
3. Token saved to secure storage
4. Navigation to Dashboard
5. User info displayed

#### Failed Registration/Login
1. Error message shown in SnackBar
2. User stays on same screen
3. Can retry with correct data

#### Token Persistence
1. Close and reopen app
2. Splash screen checks token
3. If valid token exists, navigate to Dashboard
4. If no token, navigate to Welcome screen

#### Logout
1. Confirmation dialog shown
2. Token cleared from secure storage
3. Navigation to Welcome screen
4. User logged out

## Debugging

### Backend Logs

```bash
# Backend logs show all requests
cd backend
npm start

# You'll see logs for:
# - Incoming requests
# - Validation errors
# - Authentication attempts
# - Database queries
```

### Flutter Logs

```bash
# Flutter logs show app state and API responses
flutter run

# You'll see logs for:
# - API calls
# - Auth state changes
# - Navigation events
# - Errors and exceptions
```

### Common Issues

#### Backend Won't Start
- Check if MySQL is running
- Verify `.env` file exists and is configured
- Check if port 3000 is available
- Run `npm install` to ensure dependencies are installed

#### Database Connection Error
- Verify MySQL credentials in `.env`
- Check if database `shopwise` exists
- Run migrations: `npm run migrate`

#### Flutter Build Error
- Run `flutter pub get`
- Check if Android SDK is installed
- Run `flutter doctor` to check setup

#### API Connection Error from Flutter
- Ensure backend is running on `http://localhost:3000`
- Android emulator uses `10.0.2.2` to access host machine
- API base URL in Flutter: `http://10.0.2.2:3000/api/v1`
- For physical device, use actual IP address

#### Token Not Persisting
- Check if `flutter_secure_storage` is properly installed
- For Android emulator, secure storage should work by default
- Try clearing app data and reinstalling

## Next Steps

After authentication is working:

1. ✅ Authentication module complete
2. ⏳ Implement shop setup module
3. ⏳ Implement products module
4. ⏳ Implement stock and batch management
5. ⏳ Implement sales tracking
6. ⏳ Implement analysis engine
7. ⏳ Implement dashboard with smart insights

## Test Checklist

### Backend Tests
- [ ] Register with valid data
- [ ] Register with invalid phone
- [ ] Register with weak password
- [ ] Register with duplicate email
- [ ] Register with duplicate phone
- [ ] Login with email
- [ ] Login with phone
- [ ] Login with invalid credentials
- [ ] Get current user with valid token
- [ ] Get current user with invalid token
- [ ] Logout

### Frontend Tests
- [ ] Splash screen loads
- [ ] Welcome screen displays
- [ ] Navigate to register screen
- [ ] Navigate to login screen
- [ ] Register form validation
- [ ] Register with valid data
- [ ] Register with duplicate data (error handling)
- [ ] Login form validation
- [ ] Login with email
- [ ] Login with phone
- [ ] Login with invalid credentials (error handling)
- [ ] Navigate to dashboard after login
- [ ] User info displayed on dashboard
- [ ] Logout functionality
- [ ] Token persistence (close and reopen app)

All tests should pass before proceeding to the next module!
