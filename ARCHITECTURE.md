# ShopWise - System Architecture

## Overview

ShopWise is a Smart Business Assistant for Small Grocery Shopkeepers in Bangladesh. It is a genuine Android mobile application (NOT a web app or WebView wrapper) that transforms basic shop data into actionable recommendations and alerts.

**Core Philosophy:**
```
Shop Data → Analysis → Risk/Opportunity Detection → Recommendation → Shopkeeper Decision
```

ShopWise is an **assistant**, not an autonomous manager. It never makes automatic purchases, price changes, or business decisions. The shopkeeper remains the sole decision-maker.

---

## Architecture Layers

### 1. Presentation Layer (Flutter - Android)
- **Framework:** Flutter 3.x with Dart
- **UI Design:** Material Design 3
- **State Management:** Riverpod
- **Navigation:** GoRouter / Flutter Navigator 2.0
- **Localization:** flutter_localizations (English + Bangla)
- **Storage:** flutter_secure_storage (token storage)
- **Notifications:** Firebase Cloud Messaging (FCM)

### 2. Business Logic Layer (Backend - Node.js)
- **Runtime:** Node.js 18+ LTS
- **Framework:** Express.js
- **Architecture:** Modular, feature-based organization
- **Authentication:** JWT (jsonwebtoken)
- **Password Hashing:** bcrypt
- **Validation:** express-validator
- **API Documentation:** Swagger/OpenAPI

### 3. Data Layer (MySQL Database)
- **Database:** MySQL 8.0+
- **Access:** mysql2 with connection pooling
- **Schema:** Normalized relational design
- **Migrations:** Custom SQL migration scripts
- **Seed Data:** Development seed scripts

### 4. Integration Layer
- **API Protocol:** RESTful HTTP/HTTPS
- **Data Format:** JSON
- **Authentication:** Bearer Token (JWT)
- **Push Notifications:** Firebase Admin SDK

---

## System Components

### Frontend Architecture (Flutter)

```
lib/
├── core/
│   ├── constants/
│   │   ├── api_constants.dart          # API endpoints, base URLs
│   │   ├── app_constants.dart          # App-wide constants
│   │   └── string_constants.dart       # Non-localized strings
│   ├── theme/
│   │   ├── app_theme.dart              # Material 3 theme
│   │   ├── colors.dart                 # Color palette
│   │   └── text_styles.dart            # Typography
│   ├── localization/
│   │   ├── app_localizations.dart      # L10n setup
│   │   ├── l10n_en.dart                # English translations
│   │   └── l10n_bn.dart                # Bangla translations
│   ├── network/
│   │   ├── api_client.dart             # HTTP client wrapper
│   │   ├── api_interceptor.dart        # Request/response interceptor
│   │   └── api_exception.dart          # Custom exceptions
│   ├── storage/
│   │   ├── secure_storage.dart         # Token storage
│   │   └── preferences_storage.dart    # User preferences
│   └── utils/
│       ├── validators.dart             # Form validators
│       ├── formatters.dart             # Data formatters
│       └── date_helper.dart            # Date utilities
│
├── models/
│   ├── user_model.dart
│   ├── shop_model.dart
│   ├── product_model.dart
│   ├── batch_model.dart
│   ├── sale_model.dart
│   ├── notification_model.dart
│   ├── analysis_models.dart
│   └── api_response_model.dart
│
├── services/
│   ├── auth_service.dart               # Authentication API calls
│   ├── shop_service.dart               # Shop API calls
│   ├── product_service.dart            # Product API calls
│   ├── stock_service.dart              # Stock API calls
│   ├── sales_service.dart              # Sales API calls
│   ├── analysis_service.dart           # Analysis API calls
│   └── notification_service.dart       # Notification API calls
│
├── providers/
│   ├── auth_provider.dart              # Auth state management
│   ├── shop_provider.dart              # Shop state
│   ├── product_provider.dart           # Product state
│   ├── sales_provider.dart             # Sales state
│   ├── dashboard_provider.dart         # Dashboard state
│   └── notification_provider.dart      # Notification state
│
├── features/
│   ├── auth/
│   │   ├── screens/
│   │   │   ├── splash_screen.dart
│   │   │   ├── welcome_screen.dart
│   │   │   ├── login_screen.dart
│   │   │   ├── register_screen.dart
│   │   │   ├── forgot_password_screen.dart
│   │   │   └── reset_password_screen.dart
│   │   └── widgets/
│   │       ├── auth_text_field.dart
│   │       └── auth_button.dart
│   │
│   ├── onboarding/
│   │   └── screens/
│   │       └── shop_setup_screen.dart
│   │
│   ├── dashboard/
│   │   ├── screens/
│   │   │   └── home_screen.dart
│   │   └── widgets/
│   │       ├── summary_card.dart
│   │       ├── attention_card.dart
│   │       └── suggestion_card.dart
│   │
│   ├── products/
│   │   ├── screens/
│   │   │   ├── product_list_screen.dart
│   │   │   ├── product_detail_screen.dart
│   │   │   ├── add_product_screen.dart
│   │   │   └── edit_product_screen.dart
│   │   └── widgets/
│   │       ├── product_card.dart
│   │       └── product_form.dart
│   │
│   ├── stock/
│   │   ├── screens/
│   │   │   ├── stock_history_screen.dart
│   │   │   ├── batch_list_screen.dart
│   │   │   ├── add_stock_screen.dart
│   │   │   └── add_batch_screen.dart
│   │   └── widgets/
│   │       ├── batch_card.dart
│   │       └── stock_transaction_item.dart
│   │
│   ├── sales/
│   │   ├── screens/
│   │   │   ├── sales_list_screen.dart
│   │   │   ├── record_sale_screen.dart
│   │   │   └── sale_detail_screen.dart
│   │   └── widgets/
│   │       ├── sale_card.dart
│   │       └── sale_item_card.dart
│   │
│   ├── insights/
│   │   ├── screens/
│   │   │   ├── insights_screen.dart
│   │   │   ├── expiry_risk_screen.dart
│   │   │   ├── stock_risk_screen.dart
│   │   │   ├── restock_screen.dart
│   │   │   ├── slow_moving_screen.dart
│   │   │   └── profit_screen.dart
│   │   └── widgets/
│   │       ├── risk_card.dart
│   │       ├── recommendation_card.dart
│   │       └── simple_chart.dart
│   │
│   ├── notifications/
│   │   ├── screens/
│   │   │   └── notification_list_screen.dart
│   │   └── widgets/
│   │       └── notification_card.dart
│   │
│   └── profile/
│       ├── screens/
│       │   ├── profile_screen.dart
│       │   ├── shop_settings_screen.dart
│       │   ├── notification_settings_screen.dart
│       │   ├── language_settings_screen.dart
│       │   ├── change_password_screen.dart
│       │   └── about_screen.dart
│       └── widgets/
│           ├── profile_menu_item.dart
│           └── settings_tile.dart
│
├── widgets/
│   ├── common/
│   │   ├── app_button.dart
│   │   ├── app_text_field.dart
│   │   ├── loading_indicator.dart
│   │   ├── empty_state.dart
│   │   ├── error_state.dart
│   │   └── confirmation_dialog.dart
│   └── layout/
│       ├── app_scaffold.dart
│       └── bottom_nav_bar.dart
│
├── routes/
│   ├── app_router.dart                 # Route configuration
│   └── route_names.dart                # Route name constants
│
└── main.dart                           # App entry point
```

### Backend Architecture (Node.js/Express)

```
backend/
├── src/
│   ├── config/
│   │   ├── database.js                 # MySQL connection config
│   │   ├── env.js                      # Environment variables
│   │   ├── firebase.js                 # Firebase Admin SDK config
│   │   └── constants.js                # Backend constants
│   │
│   ├── database/
│   │   ├── migrations/
│   │   │   ├── 001_create_users_table.sql
│   │   │   ├── 002_create_shops_table.sql
│   │   │   ├── 003_create_categories_table.sql
│   │   │   ├── 004_create_products_table.sql
│   │   │   ├── 005_create_product_batches_table.sql
│   │   │   ├── 006_create_sales_table.sql
│   │   │   ├── 007_create_sale_items_table.sql
│   │   │   ├── 008_create_stock_transactions_table.sql
│   │   │   ├── 009_create_notifications_table.sql
│   │   │   └── 010_create_daily_summaries_table.sql
│   │   ├── seeds/
│   │   │   └── dev_seed.sql            # Development seed data
│   │   └── connection.js               # DB connection pool
│   │
│   ├── middleware/
│   │   ├── auth.middleware.js          # JWT verification
│   │   ├── validate.middleware.js      # Request validation
│   │   ├── error.middleware.js         # Error handler
│   │   ├── logger.middleware.js        # Request logger
│   │   ├── cors.middleware.js          # CORS configuration
│   │   └── rateLimit.middleware.js     # Rate limiting
│   │
│   ├── validators/
│   │   ├── auth.validator.js
│   │   ├── shop.validator.js
│   │   ├── product.validator.js
│   │   ├── stock.validator.js
│   │   └── sales.validator.js
│   │
│   ├── models/
│   │   ├── user.model.js
│   │   ├── shop.model.js
│   │   ├── product.model.js
│   │   ├── batch.model.js
│   │   ├── sale.model.js
│   │   ├── notification.model.js
│   │   └── daily_summary.model.js
│   │
│   ├── repositories/
│   │   ├── user.repository.js
│   │   ├── shop.repository.js
│   │   ├── product.repository.js
│   │   ├── batch.repository.js
│   │   ├── sale.repository.js
│   │   ├── stock.repository.js
│   │   └── notification.repository.js
│   │
│   ├── services/
│   │   ├── auth.service.js             # Authentication logic
│   │   ├── shop.service.js             # Shop business logic
│   │   ├── product.service.js          # Product business logic
│   │   ├── stock.service.js            # Stock management
│   │   ├── sales.service.js            # Sales processing
│   │   ├── notification.service.js     # Notification management
│   │   └── fcm.service.js              # Firebase push notifications
│   │
│   ├── analysis/
│   │   ├── expiryAnalyzer.js           # Expiry risk analysis
│   │   ├── stockRiskAnalyzer.js        # Stock-out prediction
│   │   ├── restockAnalyzer.js          # Restock recommendations
│   │   ├── slowMovingAnalyzer.js       # Slow-moving detection
│   │   ├── fefoAnalyzer.js             # FEFO logic
│   │   ├── profitAnalyzer.js           # Profit calculations
│   │   └── dailySummaryGenerator.js    # Daily summary generation
│   │
│   ├── controllers/
│   │   ├── auth.controller.js
│   │   ├── shop.controller.js
│   │   ├── category.controller.js
│   │   ├── product.controller.js
│   │   ├── stock.controller.js
│   │   ├── sales.controller.js
│   │   ├── dashboard.controller.js
│   │   ├── analysis.controller.js
│   │   └── notification.controller.js
│   │
│   ├── routes/
│   │   ├── auth.routes.js
│   │   ├── shop.routes.js
│   │   ├── category.routes.js
│   │   ├── product.routes.js
│   │   ├── stock.routes.js
│   │   ├── sales.routes.js
│   │   ├── dashboard.routes.js
│   │   ├── analysis.routes.js
│   │   ├── notification.routes.js
│   │   └── index.js                    # Route aggregator
│   │
│   ├── utils/
│   │   ├── jwt.util.js                 # JWT helpers
│   │   ├── bcrypt.util.js              # Password hashing
│   │   ├── date.util.js                # Date calculations
│   │   ├── response.util.js            # Standard responses
│   │   └── logger.util.js              # Logging utility
│   │
│   ├── app.js                          # Express app setup
│   └── server.js                       # Server entry point
│
├── tests/
│   ├── unit/
│   │   ├── analysis/
│   │   │   ├── expiryAnalyzer.test.js
│   │   │   ├── stockRiskAnalyzer.test.js
│   │   │   ├── restockAnalyzer.test.js
│   │   │   └── slowMovingAnalyzer.test.js
│   │   └── services/
│   │       ├── auth.service.test.js
│   │       └── sales.service.test.js
│   ├── integration/
│   │   ├── auth.integration.test.js
│   │   ├── products.integration.test.js
│   │   └── sales.integration.test.js
│   └── setup.js
│
├── .env.example                        # Environment template
├── .gitignore
├── package.json
└── README.md
```

---

## Data Flow

### 1. Authentication Flow
```
Mobile App → POST /api/v1/auth/login → Backend validates credentials
                                      ↓
                                  Generate JWT token
                                      ↓
                            Return token + user data
                                      ↓
              Mobile stores token in secure storage
                                      ↓
              All subsequent requests include Bearer token
```

### 2. Data Entry Flow
```
Shopkeeper enters product/sale data → Mobile validates input
                                                ↓
                            POST request with Bearer token
                                                ↓
                            Backend validates JWT + data
                                                ↓
                              Verify shop ownership
                                                ↓
                            Save to MySQL database
                                                ↓
                            Trigger analysis engine
                                                ↓
                          Generate recommendations
                                                ↓
                          Create notifications if needed
                                                ↓
                          Return success + updated data
```

### 3. Dashboard Loading Flow
```
Mobile app opens Home screen → GET /api/v1/dashboard/summary
                                                ↓
                                Backend authenticates request
                                                ↓
                              Get shop_id from JWT
                                                ↓
                            Run all analysis modules
                                                ↓
                          Aggregate insights + metrics
                                                ↓
                          Return dashboard data
                                                ↓
              Mobile renders summary, alerts, suggestions
```

### 4. Analysis Engine Flow
```
Trigger (new sale, batch added, scheduled job)
                    ↓
        Load shop data from database
                    ↓
        Run parallel analysis modules:
        - Expiry Risk Analyzer
        - Stock-Out Risk Analyzer
        - Restock Analyzer
        - Slow-Moving Analyzer
        - FEFO Analyzer
        - Profit Analyzer
                    ↓
        Aggregate results
                    ↓
        Generate Daily Summary
                    ↓
        Create notifications for critical items
                    ↓
        Send FCM push notifications
                    ↓
        Store notification records
```

---

## Security Architecture

### Authentication & Authorization
- **JWT Token:** Signed with HS256, 24-hour expiration
- **Token Storage:** flutter_secure_storage (Android Keystore)
- **Password Hashing:** bcrypt with salt rounds = 10
- **Authorization:** Middleware extracts user_id and shop_id from JWT
- **Data Isolation:** All queries filter by authenticated shop_id

### API Security
- **HTTPS Only:** Production requires TLS/SSL
- **CORS:** Configured for mobile app origin
- **Rate Limiting:** Express rate limit middleware
- **Input Validation:** express-validator on all endpoints
- **SQL Injection Prevention:** Parameterized queries
- **XSS Prevention:** Sanitized inputs
- **Error Sanitization:** No sensitive data in error responses

### Data Security
- **Password Storage:** Never store plaintext passwords
- **Token Transmission:** Always via HTTPS Bearer header
- **Environment Variables:** All secrets in .env (never committed)
- **Database Access:** Connection pool with limited privileges
- **Shop Data Isolation:** User A cannot access User B's data

---

## State Management (Riverpod)

### Provider Types

1. **StateProvider:** Simple state (loading, language selection)
2. **StateNotifierProvider:** Complex state with actions (auth, products, sales)
3. **FutureProvider:** Async data loading (dashboard, analytics)
4. **StreamProvider:** Real-time updates (notifications)

### State Structure

```dart
// Auth State
class AuthState {
  final bool isAuthenticated;
  final User? user;
  final String? token;
  final AuthStatus status; // initial, loading, authenticated, error
}

// Product State
class ProductState {
  final List<Product> products;
  final ProductStatus status;
  final String? error;
  final bool hasMore;
  final int page;
}

// Dashboard State
class DashboardState {
  final DashboardSummary? summary;
  final List<Alert> alerts;
  final List<Suggestion> suggestions;
  final DashboardStatus status;
}
```

---

## Navigation Structure

### Bottom Navigation (Main Tabs)
1. **Home** - Dashboard with smart summary
2. **Products** - Product list and management
3. **Sales** - Sales recording and history
4. **Insights** - Analytics and intelligence
5. **Profile** - Settings and account

### Screen Hierarchy

```
Splash Screen
    ↓
Welcome Screen (if first launch)
    ↓
Login Screen ←→ Register Screen
    ↓              ↓
    ↓         Shop Setup Screen
    ↓              ↓
    └──────────────┘
           ↓
    Bottom Nav (Home, Products, Sales, Insights, Profile)
           ↓
    [Protected Screens]
```

---

## Performance Optimization

### Frontend
- **Lazy Loading:** Products/sales paginated (20 items per page)
- **Image Caching:** Cached network images
- **State Caching:** Provider caching for frequently accessed data
- **Debouncing:** Search input debounced (300ms)
- **Efficient Rebuilds:** const widgets, keys, memoization

### Backend
- **Database Indexing:** Indexes on foreign keys, frequently queried fields
- **Connection Pooling:** MySQL connection pool (max 10 connections)
- **Query Optimization:** Joins limited, select only needed fields
- **Caching Strategy:** In-memory cache for daily summaries (future enhancement)
- **Pagination:** All list endpoints support limit/offset

### Analysis Engine
- **Configurable Thresholds:** Avoid re-running on every request
- **Batch Processing:** Process multiple products in single query
- **Lazy Analysis:** Run only when data changes, not on every dashboard load

---

## Error Handling Strategy

### Frontend (Flutter)
- **Network Errors:** Show retry option with clear message
- **Validation Errors:** Inline form field errors
- **Auth Errors:** Auto-logout on 401, redirect to login
- **Server Errors:** User-friendly message + log technical details
- **Empty States:** Dedicated UI for "no data" scenarios

### Backend (Node.js)
- **Centralized Error Handler:** Single middleware for all errors
- **Error Types:** ValidationError, AuthError, NotFoundError, ServerError
- **Response Format:**
```json
{
  "success": false,
  "message": "User-friendly error message",
  "errors": [
    {
      "field": "email",
      "message": "Email is required"
    }
  ]
}
```

---

## Deployment Architecture

### Development Environment
```
[Flutter Dev] → http://localhost:3000 → [Node.js Dev Server] → [MySQL Local]
```

### Production Environment
```
[Flutter Android App] → https://api.shopwise.com → [Node.js on VPS/Cloud]
                                                            ↓
                                                      [MySQL Production]
                                                            ↓
                                                  [Firebase Cloud Messaging]
```

---

## Technology Stack Summary

| Layer | Technology | Purpose |
|-------|------------|---------|
| **Mobile** | Flutter 3.x | Cross-platform UI framework |
| **Language** | Dart | Mobile app programming |
| **State** | Riverpod | State management |
| **Storage** | flutter_secure_storage | Secure token storage |
| **HTTP** | dio | API client |
| **i18n** | flutter_localizations | Localization |
| **Push** | Firebase Cloud Messaging | Notifications |
| **Backend** | Node.js 18+ | Server runtime |
| **Framework** | Express.js | Web framework |
| **Auth** | jsonwebtoken | JWT generation/verification |
| **Password** | bcrypt | Password hashing |
| **Validation** | express-validator | Input validation |
| **Database** | MySQL 8.0+ | Relational database |
| **DB Client** | mysql2 | MySQL driver |
| **Testing** | Jest | Backend unit/integration tests |
| **API Docs** | Swagger/OpenAPI | API documentation |

---

## Development Phases

### Phase 1: Foundation (Week 1)
- Initialize backend project
- Initialize Flutter project
- Database schema creation
- Basic authentication

### Phase 2: Core Features (Week 2-3)
- Shop setup
- Product CRUD
- Stock and batch management
- Sales recording

### Phase 3: Intelligence (Week 4)
- Analysis engine modules
- Dashboard implementation
- Notifications system

### Phase 4: Polish (Week 5)
- Localization (Bangla)
- Insights screen
- Profile and settings
- UI refinements

### Phase 5: Quality (Week 6)
- Comprehensive testing
- Bug fixes
- Performance optimization
- Production configuration

### Phase 6: Release (Week 7)
- Android release build
- AAB generation
- Documentation
- Play Store preparation

---

## Key Design Decisions

### Why Flutter?
- Single codebase for Android (iOS future possibility)
- Material Design 3 support
- Excellent performance
- Rich widget ecosystem
- Strong community

### Why Node.js/Express?
- JavaScript ecosystem familiarity
- Fast development
- JSON-native
- Extensive middleware support
- Good for REST APIs

### Why MySQL?
- Relational data model fits shop data structure
- ACID compliance for sales/stock transactions
- Proven reliability
- Strong community support
- Free and open source

### Why JWT?
- Stateless authentication
- Mobile-friendly (no cookies)
- Self-contained (includes user/shop info)
- Standard-based

### Why Rule-Based Analysis (Not ML)?
- Predictable, explainable results
- No training data required
- Easier to debug and maintain
- Sufficient for project scope
- Academic feasibility

---

## Conclusion

This architecture provides a solid foundation for ShopWise that is:
- **Scalable:** Modular design allows feature additions
- **Secure:** Multi-layer security implementation
- **Maintainable:** Clear separation of concerns
- **Testable:** Independent modules with test coverage
- **Production-Ready:** Complete error handling and validation
- **User-Friendly:** Simple, Bangla-friendly mobile experience

The architecture respects the core principle: **ShopWise is an assistant, not a manager.**
