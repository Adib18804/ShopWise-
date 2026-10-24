# ShopWise - API Documentation

## Overview

ShopWise REST API v1 provides endpoints for authentication, shop management, product management, sales recording, stock tracking, and business intelligence analysis.

**Base URL:** `/api/v1`

**Protocol:** HTTP/HTTPS (HTTPS required in production)

**Data Format:** JSON

**Authentication:** JWT Bearer Token

---

## API Response Format

### Success Response

```json
{
  "success": true,
  "message": "Operation completed successfully",
  "data": {
    // Response data here
  }
}
```

### Error Response

```json
{
  "success": false,
  "message": "Error description",
  "errors": [
    {
      "field": "email",
      "message": "Email is required"
    }
  ]
}
```

### HTTP Status Codes

| Code | Meaning |
|------|---------|
| 200 | OK - Request successful |
| 201 | Created - Resource created successfully |
| 400 | Bad Request - Invalid input data |
| 401 | Unauthorized - Authentication required or failed |
| 403 | Forbidden - Insufficient permissions |
| 404 | Not Found - Resource not found |
| 422 | Unprocessable Entity - Validation failed |
| 500 | Internal Server Error - Server error |

---

## Authentication

All protected endpoints require a JWT Bearer token in the Authorization header:

```
Authorization: Bearer <your_jwt_token>
```

### JWT Token Structure

```json
{
  "user_id": 1,
  "shop_id": 1,
  "email": "user@example.com",
  "iat": 1697385600,
  "exp": 1697472000
}
```

**Token Expiration:** 24 hours

---

## API Endpoints

## 1. Authentication Endpoints

### 1.1 Register

**Endpoint:** `POST /api/v1/auth/register`

**Authentication:** None (Public)

**Description:** Register a new user account

**Request Body:**
```json
{
  "name": "Rahim Khan",
  "phone": "01712345678",
  "email": "rahim@example.com",
  "password": "SecurePass123!",
  "preferred_language": "bn"
}
```

**Validation Rules:**
- `name`: Required, 2-100 characters
- `phone`: Required, unique, valid BD phone format
- `email`: Required, unique, valid email format
- `password`: Required, min 8 characters, must contain uppercase, lowercase, number
- `preferred_language`: Optional, enum ['en', 'bn'], default 'bn'

**Success Response (201):**
```json
{
  "success": true,
  "message": "Registration successful",
  "data": {
    "user": {
      "id": 1,
      "name": "Rahim Khan",
      "phone": "01712345678",
      "email": "rahim@example.com",
      "preferred_language": "bn",
      "created_at": "2026-10-15T10:30:00Z"
    },
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

**Error Response (400):**
```json
{
  "success": false,
  "message": "Validation failed",
  "errors": [
    {
      "field": "email",
      "message": "Email already exists"
    },
    {
      "field": "password",
      "message": "Password must be at least 8 characters"
    }
  ]
}
```

---

### 1.2 Login

**Endpoint:** `POST /api/v1/auth/login`

**Authentication:** None (Public)

**Description:** Login with email/phone and password

**Request Body:**
```json
{
  "identifier": "rahim@example.com",
  "password": "SecurePass123!"
}
```

**Validation Rules:**
- `identifier`: Required (email or phone number)
- `password`: Required

**Success Response (200):**
```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "user": {
      "id": 1,
      "name": "Rahim Khan",
      "phone": "01712345678",
      "email": "rahim@example.com",
      "preferred_language": "bn",
      "has_shop": true,
      "shop_id": 1
    },
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

**Error Response (401):**
```json
{
  "success": false,
  "message": "Invalid credentials"
}
```

---

### 1.3 Get Current User

**Endpoint:** `GET /api/v1/auth/me`

**Authentication:** Required

**Description:** Get authenticated user details

**Success Response (200):**
```json
{
  "success": true,
  "message": "User retrieved successfully",
  "data": {
    "user": {
      "id": 1,
      "name": "Rahim Khan",
      "phone": "01712345678",
      "email": "rahim@example.com",
      "preferred_language": "bn",
      "has_shop": true,
      "shop_id": 1,
      "created_at": "2026-10-15T10:30:00Z"
    }
  }
}
```

---

### 1.4 Forgot Password

**Endpoint:** `POST /api/v1/auth/forgot-password`

**Authentication:** None (Public)

**Description:** Request password reset (sends reset token via email/SMS)

**Request Body:**
```json
{
  "email": "rahim@example.com"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Password reset instructions sent to your email"
}
```

---

### 1.5 Reset Password

**Endpoint:** `POST /api/v1/auth/reset-password`

**Authentication:** None (Public, but requires reset token)

**Description:** Reset password using reset token

**Request Body:**
```json
{
  "token": "reset_token_here",
  "new_password": "NewSecurePass123!"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Password reset successful"
}
```

---

### 1.6 Logout

**Endpoint:** `POST /api/v1/auth/logout`

**Authentication:** Required

**Description:** Logout (client should clear token)

**Success Response (200):**
```json
{
  "success": true,
  "message": "Logout successful"
}
```

---

## 2. Shop Endpoints

### 2.1 Create Shop

**Endpoint:** `POST /api/v1/shop`

**Authentication:** Required

**Description:** Create shop after registration (one shop per user)

**Request Body:**
```json
{
  "shop_name": "Rahim Grocery Store",
  "address": "123 Main Street, Dhaka",
  "phone": "01712345678",
  "currency": "BDT"
}
```

**Validation Rules:**
- `shop_name`: Required, 2-200 characters
- `address`: Optional
- `phone`: Optional, valid phone format
- `currency`: Optional, default 'BDT'

**Success Response (201):**
```json
{
  "success": true,
  "message": "Shop created successfully",
  "data": {
    "shop": {
      "id": 1,
      "owner_id": 1,
      "shop_name": "Rahim Grocery Store",
      "address": "123 Main Street, Dhaka",
      "phone": "01712345678",
      "currency": "BDT",
      "created_at": "2026-10-15T10:35:00Z"
    }
  }
}
```

**Error Response (400):**
```json
{
  "success": false,
  "message": "User already has a shop"
}
```

---

### 2.2 Get Shop

**Endpoint:** `GET /api/v1/shop`

**Authentication:** Required

**Description:** Get authenticated user's shop details

**Success Response (200):**
```json
{
  "success": true,
  "message": "Shop retrieved successfully",
  "data": {
    "shop": {
      "id": 1,
      "owner_id": 1,
      "shop_name": "Rahim Grocery Store",
      "address": "123 Main Street, Dhaka",
      "phone": "01712345678",
      "currency": "BDT",
      "created_at": "2026-10-15T10:35:00Z",
      "updated_at": "2026-10-15T10:35:00Z"
    }
  }
}
```

---

### 2.3 Update Shop

**Endpoint:** `PUT /api/v1/shop`

**Authentication:** Required

**Description:** Update shop details

**Request Body:**
```json
{
  "shop_name": "Rahim Grocery Store & Sweets",
  "address": "123 Main Street, Dhaka",
  "phone": "01712345678"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Shop updated successfully",
  "data": {
    "shop": {
      "id": 1,
      "shop_name": "Rahim Grocery Store & Sweets",
      "address": "123 Main Street, Dhaka",
      "phone": "01712345678",
      "currency": "BDT",
      "updated_at": "2026-10-15T11:00:00Z"
    }
  }
}
```

---

## 3. Category Endpoints

### 3.1 Get Categories

**Endpoint:** `GET /api/v1/categories`

**Authentication:** Required

**Description:** Get all categories for authenticated user's shop

**Success Response (200):**
```json
{
  "success": true,
  "message": "Categories retrieved successfully",
  "data": {
    "categories": [
      {
        "id": 1,
        "shop_id": 1,
        "name": "Dairy Products",
        "created_at": "2026-10-15T10:40:00Z"
      },
      {
        "id": 2,
        "shop_id": 1,
        "name": "Beverages",
        "created_at": "2026-10-15T10:40:00Z"
      }
    ]
  }
}
```

---

### 3.2 Create Category

**Endpoint:** `POST /api/v1/categories`

**Authentication:** Required

**Description:** Create new category

**Request Body:**
```json
{
  "name": "Snacks"
}
```

**Success Response (201):**
```json
{
  "success": true,
  "message": "Category created successfully",
  "data": {
    "category": {
      "id": 3,
      "shop_id": 1,
      "name": "Snacks",
      "created_at": "2026-10-15T11:00:00Z"
    }
  }
}
```

---

### 3.3 Update Category

**Endpoint:** `PUT /api/v1/categories/:id`

**Authentication:** Required

**Description:** Update category name

**Request Body:**
```json
{
  "name": "Snacks & Biscuits"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Category updated successfully",
  "data": {
    "category": {
      "id": 3,
      "shop_id": 1,
      "name": "Snacks & Biscuits",
      "created_at": "2026-10-15T11:00:00Z"
    }
  }
}
```

---

### 3.4 Delete Category

**Endpoint:** `DELETE /api/v1/categories/:id`

**Authentication:** Required

**Description:** Delete category (sets products' category_id to NULL)

**Success Response (200):**
```json
{
  "success": true,
  "message": "Category deleted successfully"
}
```

---

## 4. Product Endpoints

### 4.1 Get Products

**Endpoint:** `GET /api/v1/products`

**Authentication:** Required

**Description:** Get active shop products with pagination, search, and category filtering

**Query Parameters:**
- `q`: Search product name, SKU, or barcode
- `limit`: Number of products (optional, max: 100)
- `offset`: Starting product (optional, default: 0)
- `category_id`: Filter by category

**Example:** `GET /api/v1/products?q=milk&limit=20&offset=0&category_id=1`

**Success Response (200):**
```json
{
  "success": true,
  "message": "Products retrieved successfully",
  "data": {
    "products": [
      {
        "id": 1,
        "shop_id": 1,
        "category_id": 1,
        "name": "Fresh Milk 1L",
        "sku": "MILK-001",
        "barcode": "1234567890123",
        "unit": "piece",
        "selling_price": 85.00,
        "default_purchase_price": 70.00,
        "minimum_stock": 10,
        "target_stock_days": 7,
        "total_stock": 25,
        "is_active": true,
        "created_at": "2026-10-15T10:45:00Z",
        "updated_at": "2026-10-15T10:45:00Z",
        "batch_count": 2,
        "category": { "id": 1, "name": "Dairy Products" }
      }
    ],
    "total": 45,
    "limit": 20,
    "offset": 0
  }
}
```

---

### 4.2 Get Product Details

**Endpoint:** `GET /api/v1/products/:id`

**Authentication:** Required

**Description:** Get product details and current batch-derived stock totals

**Success Response (200):**
```json
{
  "success": true,
  "message": "Product retrieved successfully",
  "data": {
    "product": {
      "id": 1,
      "shop_id": 1,
      "category_id": 1,
      "name": "Fresh Milk 1L",
      "sku": "MILK-001",
      "barcode": "1234567890123",
      "unit": "piece",
      "selling_price": 85.00,
      "default_purchase_price": 70.00,
      "minimum_stock": 10,
      "target_stock_days": 7,
      "total_stock": 25,
      "is_active": true,
      "created_at": "2026-10-15T10:45:00Z",
      "updated_at": "2026-10-15T10:45:00Z",
      "batch_count": 2,
      "category": { "id": 1, "name": "Dairy Products" }
    }
  }
}
```

---

### 4.3 Create Product

**Endpoint:** `POST /api/v1/products`

**Authentication:** Required

**Description:** Create new product

**Request Body:**
```json
{
  "category_id": 1,
  "name": "Fresh Milk 1L",
  "sku": "MILK-001",
  "barcode": "1234567890123",
  "unit": "piece",
  "selling_price": 85.00,
  "default_purchase_price": 70.00,
  "minimum_stock": 10,
  "target_stock_days": 7
}
```

**Validation Rules:**
- `name`: Required, 2-200 characters
- `category_id`: Optional, must exist in shop's categories
- `sku`: Optional, must be unique per shop
- `barcode`: Optional
- `unit`: Required, default 'piece'
- `selling_price`: Required, >= 0
- `default_purchase_price`: Required, >= 0
- `minimum_stock`: Optional, >= 0, default 0
- `target_stock_days`: Optional, >= 1, default 7

**Success Response (201):**
```json
{
  "success": true,
  "message": "Product created successfully",
  "data": {
    "product": {
      "id": 1,
      "shop_id": 1,
      "category_id": 1,
      "name": "Fresh Milk 1L",
      "sku": "MILK-001",
      "barcode": "1234567890123",
      "unit": "piece",
      "selling_price": 85.00,
      "default_purchase_price": 70.00,
      "minimum_stock": 10,
        "target_stock_days": 7,
        "total_stock": 0,
      "is_active": true,
        "batch_count": 0,
        "category": { "id": 1, "name": "Dairy Products" },
        "created_at": "2026-10-15T11:00:00Z",
        "updated_at": "2026-10-15T11:00:00Z"
    }
  }
}
```

---

### 4.4 Update Product

**Endpoint:** `PUT /api/v1/products/:id`

**Authentication:** Required

**Description:** Update product details

**Request Body:**
```json
{
  "name": "Fresh Milk 1L (Premium)",
  "selling_price": 90.00,
  "default_purchase_price": 75.00,
  "minimum_stock": 15
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Product updated successfully",
  "data": {
    "product": {
      "id": 1,
      "name": "Fresh Milk 1L (Premium)",
      "selling_price": 90.00,
      "default_purchase_price": 75.00,
      "minimum_stock": 15,
      "updated_at": "2026-10-15T11:30:00Z"
    }
  }
}
```

---

### 4.5 Delete/Deactivate Product

**Endpoint:** `DELETE /api/v1/products/:id`

**Authentication:** Required

**Description:** Deactivate product (sets `is_active = false`; historical data is retained)

**Success Response (200):**
```json
{
  "success": true,
  "message": "Product deactivated successfully"
}
```

---

## 5. Stock & Batch Endpoints

### 5.1 Add Stock/Batch

**Endpoint:** `POST /api/v1/products/:id/batches`

**Authentication:** Required

**Description:** Add new stock batch to product

**Request Body:**
```json
{
  "batch_number": "BATCH-003",
  "purchase_date": "2026-10-15",
  "expiry_date": "2026-11-15",
  "quantity": 20,
  "purchase_price": 72.00
}
```

**Validation Rules:**
- `batch_number`: Optional
- `purchase_date`: Required, date format, not future date
- `expiry_date`: Optional (for non-perishables), must be > purchase_date
- `quantity`: Required, > 0
- `purchase_price`: Required, >= 0

**Success Response (201):**
```json
{
  "success": true,
  "message": "Stock batch added successfully",
  "data": {
    "batch": {
      "id": 3,
      "product_id": 1,
      "batch_number": "BATCH-003",
      "purchase_date": "2026-10-15",
      "expiry_date": "2026-11-15",
      "quantity": 20,
      "purchase_price": 72.00,
      "created_at": "2026-10-15T11:45:00Z",
      "status": "ACTIVE"
    },
    "product": {
      "id": 1,
      "name": "Fresh Milk 1L",
      "current_stock": 45
    }
  }
}
```

---

### 5.2 Get Product Batches

**Endpoint:** `GET /api/v1/products/:id/batches`

**Authentication:** Required

**Description:** Get all batches for a product

**Query Parameters:**
- `include_depleted`: Include batches with quantity = 0 (default: false)

**Success Response (200):**
```json
{
  "success": true,
  "message": "Batches retrieved successfully",
  "data": {
    "product": {
      "id": 1,
      "name": "Fresh Milk 1L",
      "current_stock": 45
    },
    "batches": [
      {
        "id": 1,
        "batch_number": "BATCH-001",
        "purchase_date": "2026-10-10",
        "expiry_date": "2026-10-20",
        "quantity": 10,
        "purchase_price": 70.00,
        "days_until_expiry": 5,
        "status": "NEAR_EXPIRY"
      },
      {
        "id": 2,
        "batch_number": "BATCH-002",
        "purchase_date": "2026-10-12",
        "expiry_date": "2026-10-27",
        "quantity": 15,
        "purchase_price": 70.00,
        "days_until_expiry": 12,
        "status": "ACTIVE"
      },
      {
        "id": 3,
        "batch_number": "BATCH-003",
        "purchase_date": "2026-10-15",
        "expiry_date": "2026-11-15",
        "quantity": 20,
        "purchase_price": 72.00,
        "days_until_expiry": 31,
        "status": "ACTIVE"
      }
    ]
  }
}
```

---

### 5.3 Update Batch

**Endpoint:** `PUT /api/v1/batches/:id`

**Authentication:** Required

**Description:** Update batch details. When `quantity` is provided, it is the target on-hand quantity for the batch, not a quantity delta. The API records the difference as `ADJUSTMENT_IN` or `ADJUSTMENT_OUT`; the quantity update and history record are committed atomically. To add purchased stock, use `POST /api/v1/products/:id/batches`.

**Request Body:**
```json
{
  "quantity": 18,
  "notes": "2 units damaged"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Batch updated successfully",
  "data": {
    "batch": {
      "id": 3,
      "quantity": 18,
      "status": "ACTIVE",
      "updated_at": "2026-10-15T12:00:00Z"
    }
  }
}
```

---

### 5.4 Get Stock History

**Endpoint:** `GET /api/v1/products/:id/stock-history`

**Authentication:** Required

**Description:** Get stock transaction history for a product

**Query Parameters:**
- `limit`: Number of records (default: 50)
- `offset`: Starting record (default: 0)

**Success Response (200):**
```json
{
  "success": true,
  "message": "Stock history retrieved successfully",
  "data": {
    "product": {
      "id": 1,
      "name": "Fresh Milk 1L"
    },
    "transactions": [
      {
        "id": 15,
        "transaction_type": "SALE",
        "quantity": 5,
        "batch_id": 1,
        "batch_number": "BATCH-001",
        "reference_id": 10,
        "notes": null,
        "created_at": "2026-10-15T09:30:00Z"
      },
      {
        "id": 14,
        "transaction_type": "PURCHASE",
        "quantity": 20,
        "batch_id": 3,
        "batch_number": "BATCH-003",
        "reference_id": null,
        "notes": "New stock added",
        "created_at": "2026-10-15T08:00:00Z"
      }
    ],
    "pagination": { "total": 2, "limit": 50, "offset": 0, "hasMore": false }
  }
}
```

### 5.5 FEFO Recommendations

**Endpoint:** `GET /api/v1/products/:id/fefo`

**Authentication:** Required

Returns only active, non-depleted batches with a non-null expiry date that has not passed. Batches without an expiry date are omitted, following the policy in `BUSINESS_LOGIC.md`.

### 5.6 Batch Lookup and Deactivation

- `GET /api/v1/batches/:id` returns a batch only when it belongs to the authenticated user's shop.
- `DELETE /api/v1/batches/:id` deactivates a zero-quantity batch and retains its history references. It returns `409` while quantity remains.

### Batch deletion and FEFO behavior

`DELETE /api/v1/batches/:id` deactivates a batch when its remaining quantity is zero. A batch with remaining stock returns `409`. Deactivation keeps stock and sale history references intact.

Batch statuses are calculated on read, with this priority: `DEPLETED`, `EXPIRED`, `NEAR_EXPIRY` (0–7 calendar days), `LOW_STOCK` (batch quantity is at or below the product's `minimum_stock`), then `ACTIVE`. Dates are calendar dates in the Bangladesh business timezone. FEFO excludes depleted, expired, and no-expiry batches; dated active batches sort by expiry date, purchase date, then batch ID.

---

## 6. Sales Endpoints

### 6.1 Get Sales

**Endpoint:** `GET /api/v1/sales`

**Authentication:** Required

**Description:** Get sales history with pagination and filters

**Query Parameters:**
- `page`: Page number (default: 1)
- `limit`: Items per page (default: 20)
- `start_date`: Filter sales from date (YYYY-MM-DD)
- `end_date`: Filter sales to date (YYYY-MM-DD)

**Example:** `GET /api/v1/sales?page=1&start_date=2026-10-01&end_date=2026-10-15`

**Success Response (200):**
```json
{
  "success": true,
  "message": "Sales retrieved successfully",
  "data": {
    "sales": [
      {
        "id": 10,
        "shop_id": 1,
        "total_amount": 425.00,
        "sale_date": "2026-10-15",
        "item_count": 5,
        "created_at": "2026-10-15T09:30:00Z"
      },
      {
        "id": 9,
        "shop_id": 1,
        "total_amount": 180.00,
        "sale_date": "2026-10-14",
        "item_count": 2,
        "created_at": "2026-10-14T14:20:00Z"
      }
    ],
    "pagination": {
      "current_page": 1,
      "per_page": 20,
      "total": 145,
      "total_pages": 8,
      "has_more": true
    },
    "summary": {
      "total_sales_amount": 12450.00,
      "total_transactions": 145
    }
  }
}
```

---

### 6.2 Get Sale Details

**Endpoint:** `GET /api/v1/sales/:id`

**Authentication:** Required

**Description:** Get detailed sale information with items

**Success Response (200):**
```json
{
  "success": true,
  "message": "Sale retrieved successfully",
  "data": {
    "sale": {
      "id": 10,
      "shop_id": 1,
      "total_amount": 425.00,
      "sale_date": "2026-10-15",
      "created_at": "2026-10-15T09:30:00Z"
    },
    "items": [
      {
        "id": 25,
        "product_id": 1,
        "product_name": "Fresh Milk 1L",
        "batch_id": 1,
        "batch_number": "BATCH-001",
        "quantity": 5,
        "selling_price": 85.00,
        "purchase_price": 70.00,
        "subtotal": 425.00,
        "profit": 75.00
      }
    ],
    "summary": {
      "total_amount": 425.00,
      "total_profit": 75.00,
      "items_count": 1
    }
  }
}
```

---

### 6.3 Record Sale

**Endpoint:** `POST /api/v1/sales`

**Authentication:** Required

**Description:** Record a new sale transaction

**Request Body:**
```json
{
  "sale_date": "2026-10-15",
  "items": [
    {
      "product_id": 1,
      "batch_id": 1,
      "quantity": 5,
      "selling_price": 85.00
    },
    {
      "product_id": 2,
      "quantity": 3,
      "selling_price": 45.00
    }
  ]
}
```

**Validation Rules:**
- `sale_date`: Required, date format, not future date
- `items`: Required, array, min 1 item
- `items[].product_id`: Required, must exist in shop
- `items[].batch_id`: Optional (recommended for FEFO)
- `items[].quantity`: Required, > 0, must not exceed available stock
- `items[].selling_price`: Required, >= 0

**Success Response (201):**
```json
{
  "success": true,
  "message": "Sale recorded successfully",
  "data": {
    "sale": {
      "id": 11,
      "shop_id": 1,
      "total_amount": 560.00,
      "sale_date": "2026-10-15",
      "created_at": "2026-10-15T12:30:00Z"
    },
    "items": [
      {
        "id": 26,
        "product_id": 1,
        "product_name": "Fresh Milk 1L",
        "quantity": 5,
        "selling_price": 85.00,
        "subtotal": 425.00
      },
      {
        "id": 27,
        "product_id": 2,
        "product_name": "Biscuits 200g",
        "quantity": 3,
        "selling_price": 45.00,
        "subtotal": 135.00
      }
    ],
    "summary": {
      "total_amount": 560.00,
      "estimated_profit": 95.00
    }
  }
}
```

**Error Response (400):**
```json
{
  "success": false,
  "message": "Insufficient stock",
  "errors": [
    {
      "field": "items[0].quantity",
      "message": "Requested 5 units but only 3 available for product 'Fresh Milk 1L'"
    }
  ]
}
```

---

## 7. Dashboard Endpoint

### 7.1 Get Dashboard Summary

**Endpoint:** `GET /api/v1/dashboard/summary`

**Authentication:** Required

**Description:** Get comprehensive dashboard data with insights and recommendations

**Success Response (200):**
```json
{
  "success": true,
  "message": "Dashboard summary retrieved successfully",
  "data": {
    "today_summary": {
      "date": "2026-10-15",
      "sales_amount": 1250.00,
      "estimated_profit": 185.00,
      "transactions_count": 8,
      "low_stock_count": 3,
      "expiry_risk_count": 5,
      "expiry_risk_value": 1850.00
    },
    "attention_needed": [
      {
        "type": "STOCK_OUT",
        "severity": "WARNING",
        "title": "Milk may run out soon",
        "message": "Fresh Milk 1L may run out within approximately 3 days based on recent sales",
        "product_id": 1,
        "product_name": "Fresh Milk 1L",
        "current_stock": 12,
        "avg_daily_sales": 4.2,
        "estimated_days": 2.86
      },
      {
        "type": "EXPIRY_RISK",
        "severity": "CRITICAL",
        "title": "Products expiring soon",
        "message": "5 products may expire within 7 days",
        "expiry_risk_value": 850.00,
        "products_count": 5
      },
      {
        "type": "SLOW_MOVING",
        "severity": "INFO",
        "title": "Slow-moving products",
        "message": "3 products have had no sales in the last 30 days",
        "products_count": 3
      }
    ],
    "smart_suggestions": [
      {
        "type": "RESTOCK",
        "product_id": 1,
        "product_name": "Fresh Milk 1L",
        "message": "Consider restocking approximately 20 units",
        "reason": "Based on average daily sales of 4.2 units and target coverage of 7 days",
        "recommended_quantity": 20,
        "current_stock": 12
      },
      {
        "type": "FEFO",
        "product_id": 1,
        "product_name": "Fresh Milk 1L",
        "batch_id": 1,
        "batch_number": "BATCH-001",
        "message": "Sell BATCH-001 first (expires in 5 days)",
        "expiry_date": "2026-10-20",
        "days_until_expiry": 5
      }
    ],
    "weekly_trend": {
      "sales_amount": 8750.00,
      "profit": 1320.00,
      "trend": "up",
      "change_percentage": 12.5
    }
  }
}
```

---

## 8. Analysis Endpoints

### 8.1 Get Expiry Risk Analysis

**Endpoint:** `GET /api/v1/analysis/expiry-risk`

**Authentication:** Required

**Description:** Get products/batches at risk of expiry

**Query Parameters:**
- `risk_window`: Days to check (default: 14, options: 7, 14, 30)

**Success Response (200):**
```json
{
  "success": true,
  "message": "Expiry risk analysis retrieved successfully",
  "data": {
    "summary": {
      "total_at_risk_batches": 8,
      "total_value_at_risk": 2450.00,
      "critical_count": 2,
      "high_risk_count": 3,
      "medium_risk_count": 3
    },
    "batches": [
      {
        "id": 1,
        "product_id": 1,
        "product_name": "Fresh Milk 1L",
        "batch_number": "BATCH-001",
        "expiry_date": "2026-10-20",
        "days_until_expiry": 5,
        "quantity": 10,
        "purchase_price": 70.00,
        "value_at_risk": 700.00,
        "risk_level": "CRITICAL"
      },
      {
        "id": 4,
        "product_id": 2,
        "product_name": "Biscuits 200g",
        "batch_number": "BATCH-B01",
        "expiry_date": "2026-10-22",
        "days_until_expiry": 7,
        "quantity": 25,
        "purchase_price": 35.00,
        "value_at_risk": 875.00,
        "risk_level": "HIGH"
      }
    ]
  }
}
```

---

### 8.2 Get Stock-Out Risk Analysis

**Endpoint:** `GET /api/v1/analysis/stock-risk`

**Authentication:** Required

**Description:** Get products at risk of running out

**Success Response (200):**
```json
{
  "success": true,
  "message": "Stock-out risk analysis retrieved successfully",
  "data": {
    "summary": {
      "total_at_risk": 5,
      "critical_count": 2,
      "warning_count": 3
    },
    "products": [
      {
        "id": 1,
        "name": "Fresh Milk 1L",
        "current_stock": 12,
        "minimum_stock": 10,
        "avg_daily_sales": 4.2,
        "estimated_stock_days": 2.86,
        "risk_level": "CRITICAL",
        "message": "May run out within approximately 3 days"
      },
      {
        "id": 3,
        "name": "Bread",
        "current_stock": 8,
        "minimum_stock": 5,
        "avg_daily_sales": 1.5,
        "estimated_stock_days": 5.33,
        "risk_level": "WARNING",
        "message": "May run out within approximately 5 days"
      }
    ]
  }
}
```

---

### 8.3 Get Restock Recommendations

**Endpoint:** `GET /api/v1/analysis/restock`

**Authentication:** Required

**Description:** Get restock recommendations based on sales trends

**Success Response (200):**
```json
{
  "success": true,
  "message": "Restock recommendations retrieved successfully",
  "data": {
    "recommendations": [
      {
        "product_id": 1,
        "product_name": "Fresh Milk 1L",
        "current_stock": 12,
        "target_stock": 29,
        "recommended_quantity": 17,
        "avg_daily_sales": 4.2,
        "target_coverage_days": 7,
        "reason": "Based on average daily sales of 4.2 units and target coverage of 7 days",
        "priority": "HIGH"
      },
      {
        "product_id": 5,
        "product_name": "Cooking Oil 1L",
        "current_stock": 5,
        "target_stock": 21,
        "recommended_quantity": 16,
        "avg_daily_sales": 3.0,
        "target_coverage_days": 7,
        "reason": "Based on average daily sales of 3.0 units and target coverage of 7 days",
        "priority": "MEDIUM"
      }
    ]
  }
}
```

---

### 8.4 Get Slow-Moving Products

**Endpoint:** `GET /api/v1/analysis/slow-moving`

**Authentication:** Required

**Description:** Get products with low or no sales activity

**Query Parameters:**
- `threshold_days`: Days without sales (default: 30)

**Success Response (200):**
```json
{
  "success": true,
  "message": "Slow-moving products retrieved successfully",
  "data": {
    "summary": {
      "total_slow_moving": 4,
      "total_stock_value": 3250.00
    },
    "products": [
      {
        "id": 8,
        "name": "Rice 1kg",
        "current_stock": 50,
        "days_since_last_sale": 45,
        "total_sold_last_30_days": 0,
        "stock_value": 2500.00,
        "status": "DEAD_STOCK",
        "message": "No sales recorded for 45 days. Review before purchasing more."
      },
      {
        "id": 7,
        "name": "Noodles",
        "current_stock": 30,
        "days_since_last_sale": 22,
        "total_sold_last_30_days": 2,
        "avg_daily_sales": 0.07,
        "stock_value": 750.00,
        "status": "SLOW_MOVING",
        "message": "Very low sales activity. Consider promotional action."
      }
    ]
  }
}
```

---

### 8.5 Get FEFO Recommendations

**Endpoint:** `GET /api/v1/analysis/fefo`

**Authentication:** Required

**Description:** Get First Expire First Out selling recommendations

**Success Response (200):**
```json
{
  "success": true,
  "message": "FEFO recommendations retrieved successfully",
  "data": {
    "recommendations": [
      {
        "product_id": 1,
        "product_name": "Fresh Milk 1L",
        "total_stock": 45,
        "batches": [
          {
            "batch_id": 1,
            "batch_number": "BATCH-001",
            "expiry_date": "2026-10-20",
            "days_until_expiry": 5,
            "quantity": 10,
            "priority": 1,
            "recommendation": "Sell this batch first (expires in 5 days)"
          },
          {
            "batch_id": 2,
            "batch_number": "BATCH-002",
            "expiry_date": "2026-10-27",
            "days_until_expiry": 12,
            "quantity": 15,
            "priority": 2,
            "recommendation": "Sell after BATCH-001 is depleted"
          },
          {
            "batch_id": 3,
            "batch_number": "BATCH-003",
            "expiry_date": "2026-11-15",
            "days_until_expiry": 31,
            "quantity": 20,
            "priority": 3,
            "recommendation": "Reserve for later"
          }
        ]
      }
    ]
  }
}
```

---

### 8.6 Get Profit Analysis

**Endpoint:** `GET /api/v1/analysis/profit`

**Authentication:** Required

**Description:** Get profit and revenue insights

**Query Parameters:**
- `period`: Analysis period (today, week, month, default: month)

**Success Response (200):**
```json
{
  "success": true,
  "message": "Profit analysis retrieved successfully",
  "data": {
    "period": "month",
    "start_date": "2026-09-15",
    "end_date": "2026-10-15",
    "summary": {
      "total_revenue": 45230.00,
      "total_cost": 38150.00,
      "gross_profit": 7080.00,
      "profit_margin": 15.65,
      "transactions_count": 186
    },
    "top_selling_products": [
      {
        "product_id": 1,
        "product_name": "Fresh Milk 1L",
        "quantity_sold": 126,
        "revenue": 10710.00,
        "cost": 8820.00,
        "profit": 1890.00,
        "profit_margin": 17.65
      },
      {
        "product_id": 2,
        "product_name": "Biscuits 200g",
        "quantity_sold": 98,
        "revenue": 4410.00,
        "cost": 3430.00,
        "profit": 980.00,
        "profit_margin": 22.22
      }
    ],
    "highest_profit_products": [
      {
        "product_id": 1,
        "product_name": "Fresh Milk 1L",
        "profit": 1890.00,
        "profit_margin": 17.65
      }
    ],
    "low_margin_products": [
      {
        "product_id": 4,
        "product_name": "Rice 1kg",
        "profit_margin": 4.5,
        "message": "Consider reviewing pricing"
      }
    ]
  }
}
```

---

### 8.7 Get Daily Summary

**Endpoint:** `GET /api/v1/analysis/daily-summary`

**Authentication:** Required

**Description:** Get or generate daily business summary

**Query Parameters:**
- `date`: Summary date (YYYY-MM-DD, default: today)

**Success Response (200):**
```json
{
  "success": true,
  "message": "Daily summary retrieved successfully",
  "data": {
    "summary": {
      "id": 45,
      "shop_id": 1,
      "summary_date": "2026-10-15",
      "summary_text": "আজ ৩টি পণ্যের স্টক কম। ৫টি পণ্য শীঘ্রই মেয়াদ শেষ হবে। আনুমানিক মেয়াদ ঝুঁকির মূল্য: ৳১,৮৫০। আজকের বিক্রয়: ৳১,২৫০। আনুমানিক লাভ: ৳১৮৫।",
      "low_stock_count": 3,
      "expiry_risk_count": 5,
      "expiry_risk_value": 1850.00,
      "sales_amount": 1250.00,
      "estimated_profit": 185.00,
      "created_at": "2026-10-15T18:00:00Z"
    }
  }
}
```

---

## 9. Notification Endpoints

### 9.1 Get Notifications

**Endpoint:** `GET /api/v1/notifications`

**Authentication:** Required

**Description:** Get user notifications with filters

**Query Parameters:**
- `page`: Page number (default: 1)
- `limit`: Items per page (default: 20)
- `is_read`: Filter by read status (true/false)
- `type`: Filter by notification type

**Success Response (200):**
```json
{
  "success": true,
  "message": "Notifications retrieved successfully",
  "data": {
    "notifications": [
      {
        "id": 45,
        "user_id": 1,
        "type": "STOCK_OUT",
        "title": "Low Stock Alert",
        "message": "Fresh Milk 1L may run out within 3 days",
        "severity": "WARNING",
        "reference_type": "PRODUCT",
        "reference_id": 1,
        "is_read": false,
        "created_at": "2026-10-15T08:00:00Z"
      },
      {
        "id": 44,
        "user_id": 1,
        "type": "EXPIRY_RISK",
        "title": "Expiry Alert",
        "message": "BATCH-001 of Fresh Milk 1L expires in 5 days",
        "severity": "CRITICAL",
        "reference_type": "BATCH",
        "reference_id": 1,
        "is_read": false,
        "created_at": "2026-10-15T07:00:00Z"
      }
    ],
    "pagination": {
      "current_page": 1,
      "per_page": 20,
      "total": 67,
      "total_pages": 4,
      "has_more": true
    },
    "unread_count": 12
  }
}
```

---

### 9.2 Mark Notification as Read

**Endpoint:** `PATCH /api/v1/notifications/:id/read`

**Authentication:** Required

**Description:** Mark a notification as read

**Success Response (200):**
```json
{
  "success": true,
  "message": "Notification marked as read"
}
```

---

### 9.3 Mark All Notifications as Read

**Endpoint:** `PATCH /api/v1/notifications/read-all`

**Authentication:** Required

**Description:** Mark all user's notifications as read

**Success Response (200):**
```json
{
  "success": true,
  "message": "All notifications marked as read",
  "data": {
    "updated_count": 12
  }
}
```

---

## Error Codes Reference

| Code | Message | Description |
|------|---------|-------------|
| AUTH_001 | Invalid credentials | Login failed - wrong email/password |
| AUTH_002 | Token expired | JWT token has expired |
| AUTH_003 | Invalid token | JWT token is malformed or invalid |
| AUTH_004 | User not found | User does not exist |
| AUTH_005 | Email already exists | Registration failed - duplicate email |
| AUTH_006 | Phone already exists | Registration failed - duplicate phone |
| SHOP_001 | Shop not found | User doesn't have a shop |
| SHOP_002 | Shop already exists | User already has a shop |
| PROD_001 | Product not found | Product doesn't exist or doesn't belong to shop |
| PROD_002 | Insufficient stock | Requested quantity exceeds available stock |
| PROD_003 | SKU already exists | Duplicate SKU in shop |
| BATCH_001 | Batch not found | Batch doesn't exist |
| BATCH_002 | Invalid expiry date | Expiry date must be after purchase date |
| SALE_001 | Invalid sale date | Sale date cannot be in the future |
| SALE_002 | Empty sale items | Sale must have at least one item |
| VAL_001 | Validation failed | Generic validation error |
| SRV_001 | Internal server error | Unexpected server error |

---

## Rate Limiting

**Default Limits:**
- Authentication endpoints: 5 requests per minute per IP
- Other endpoints: 60 requests per minute per user

**Rate Limit Headers:**
```
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 45
X-RateLimit-Reset: 1697386200
```

---

## Webhooks (Future Enhancement)

Placeholder for future webhook support for events like:
- Low stock detected
- Product expiring soon
- Daily summary generated

---

## API Versioning

Current version: **v1**

Future versions will be accessible via:
- `/api/v2/...`

Version 1 will be maintained for backward compatibility.

---

## Testing Endpoints

### Health Check

**Endpoint:** `GET /api/health`

**Authentication:** None

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2026-10-15T12:00:00Z",
  "version": "1.0.0",
  "database": "connected"
}
```

---

## Postman Collection

A Postman collection with all endpoints and example requests will be provided in:
`/docs/ShopWise_API.postman_collection.json`

---

## Conclusion

This API provides complete functionality for ShopWise application covering:

✅ Authentication & Authorization
✅ Shop Management
✅ Product & Category Management
✅ Multi-Batch Stock Tracking
✅ Sales Recording & History
✅ Comprehensive Business Intelligence
✅ Real-time Notifications
✅ Dashboard Analytics

All endpoints enforce shop-level data isolation and follow RESTful conventions with consistent response formats.
