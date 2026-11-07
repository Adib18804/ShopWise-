# ShopWise

**A smart, bilingual retail assistant for small businesses in Bangladesh.**

ShopWise helps a shopkeeper keep track of products, batches, sales, customers, and credit while surfacing useful stock and expiry insights. It is designed to assist the shopkeeper: recommendations explain the signals behind them, and the shopkeeper decides what action to take.

> **Project status:** The Flutter app currently uses Firebase Authentication and Cloud Firestore for its feature data. A separate Node.js/Express/MySQL REST backend is also included in this repository. The Flutter app's current repositories and services do not use that REST backend as their data source. See [Architecture](#architecture-and-data-flow) before configuring either part.

## Contents

- [Features](#features)
- [Supported business types](#supported-business-types)
- [Screens and navigation](#screens-and-navigation)
- [Architecture and data flow](#architecture-and-data-flow)
- [Technology stack](#technology-stack)
- [Getting started](#getting-started)
- [Firebase configuration and security](#firebase-configuration-and-security)
- [Running the REST backend](#running-the-rest-backend)
- [Tests and quality checks](#tests-and-quality-checks)
- [Project layout](#project-layout)
- [Project documentation](#project-documentation)
- [Security notes](#security-notes)

## Features

### Shop onboarding and accounts

- Email/password registration and login through Firebase Authentication.
- Shop setup is completed after registration and stores the selected business type.
- Authentication state is restored at app startup; incomplete shop setup returns the user to onboarding.
- Shop and user profiles are stored in Firestore.

### Products, categories, and stock

- Create, view, edit, search, filter, and deactivate shop products and categories.
- Product data includes category, unit, selling price, purchase price, minimum/target stock, and stock totals; business-specific fields are available where appropriate.
- Add and update stock batches, review batch details and stock history, and deactivate batches.
- FEFO (First Expire, First Out) recommendations prioritize the earliest-expiring valid batch.
- Stock filters include all products, low stock, expiring soon, and slow moving.

### Sales and book issue workflow

- Build a cart, adjust quantities, apply a discount, choose a payment method, and record a payment.
- Sales are saved as invoices. Batch and product stock is updated with the sale in a Firestore transaction.
- The app allocates stock by expiry order where batches have expiry dates.
- Review sale history and invoice details.
- For libraries, the sales workflow is presented as book issue and captures a return date.

### Customers and Baki (credit)

- Create and manage customer/member records.
- Track outstanding customer balances and record payments against dues.
- Contact customers with phone and SMS actions; a due reminder can include the shop and outstanding amount.

### Dashboard, reports, and smart insights

- Dashboard summaries include today's sales and a recent sales trend.
- Daily report shows sales amount, items sold, due amount, and a seven-day sales chart.
- Stock insights flag low/out-of-stock items, expiry risks, and slow-moving/dead stock where relevant.
- Recommendation details explain why an alert is shown (for example, recent sales velocity and estimated days of stock remaining).
- Local notifications can surface expiry and stock warnings.

## Supported business types

The selected `shop_type` is stored on the shop document and controls relevant labels and fields.

| Type | App behavior |
| --- | --- |
| **General Store** | General inventory, stock-out and slow-moving insights, expiry tracking, and FEFO support. |
| **Pharmacy** | Batch number and expiry information are required for stock batches; expiry risks receive high priority. |
| **Stationery** | Expiry-related fields and alerts are hidden. |
| **Library** | Sales are labeled as book issue, customers as members, and issue records include a return date. Product forms support book details such as author and ISBN. |

## Screens and navigation

The authenticated app uses a five-slot bottom navigation shell:

1. **Home** — dashboard, sales summary, and insights.
2. **Stock** — product list, search, filters, and product details.
3. **New sale / issue** — central action button opens the cart and checkout flow.
4. **Insights** — daily report and sales trend.
5. **More** — sale history, customers/members, and account actions.

Additional screens cover welcome, registration, login, shop setup, categories, product forms, batch management, FEFO suggestions, and stock history. The interface uses a Teal and Orange theme and supports Bengali and English labels in the app.

## Architecture and data flow

This repository contains two backend/data paths:

```text
Flutter app (shopwise_app/)
  ├─ Riverpod state management
  ├─ Firebase Authentication
  └─ Cloud Firestore
       └─ shops/{uid}/{products,batches,categories,invoices,customers}

REST backend (backend/)
  └─ Express routes → Controllers → Services → Repositories → MySQL
```

The Flutter app uses Firestore-backed providers, services, and repositories for shop setup, catalog, batches, sales, customer balances, reports, and insights. Firestore transactions keep a sale invoice and its associated stock changes together.

The separate REST API uses the **Repository → Service → Controller → Route** pattern, JWT authentication, MySQL connection pooling, tenant-scoped repository queries, and migrations. It exposes its own sales and daily report endpoints. It is not currently the data source used by the Flutter feature repositories; do not assume records automatically synchronize between Firestore and MySQL.

### Firestore data layout

The current rules and app data access use owner-keyed shop documents:

```text
users/{uid}
shops/{uid}
  ├─ products/{productId}
  ├─ batches/{batchId}
  ├─ categories/{categoryId}
  ├─ invoices/{invoiceId}
  └─ customers/{customerId}
```

The shop document ID matches the Firebase Authentication UID. The checked-in `shopwise_app/firestore.rules` restricts user documents and shop documents/subcollections to the authenticated owner. Deploy and validate these rules in the Firebase project before using real customer data.

## Technology stack

| Area | Technologies |
| --- | --- |
| Mobile app | Flutter, Dart, Material, Riverpod |
| App authentication/data | Firebase Authentication, Cloud Firestore |
| Charts and device actions | `fl_chart`, `url_launcher`, local notifications |
| REST API | Node.js, Express.js, JWT, bcrypt, express-validator |
| REST database | MySQL 8, `mysql2` |
| Backend tests | Jest, Supertest |

The Flutter project also includes Dio/Retrofit and secure-storage dependencies from its API-oriented foundation. The current feature repositories described above use Firestore.

## Getting started

### Flutter app

Prerequisites: Flutter/Dart compatible with the constraints in `shopwise_app/pubspec.yaml`, an Android SDK/emulator or Android device, and a Firebase project with Email/Password Authentication and Cloud Firestore enabled.

1. Configure the Firebase values expected by `shopwise_app/lib/firebase_options.dart` in a local `shopwise_app/.env` file. The file is loaded as a Flutter asset and should not be committed. Required variable names:

   ```dotenv
   FIREBASE_ANDROID_API_KEY=
   FIREBASE_ANDROID_APP_ID=
   FIREBASE_MESSAGING_SENDER_ID=
   FIREBASE_PROJECT_ID=
   FIREBASE_STORAGE_BUCKET=
   FIREBASE_IOS_API_KEY=
   FIREBASE_IOS_APP_ID=
   FIREBASE_IOS_BUNDLE_ID=
   FIREBASE_WEB_API_KEY=
   FIREBASE_WEB_APP_ID=
   FIREBASE_AUTH_DOMAIN=
   FIREBASE_WEB_MEASUREMENT_ID=
   FIREBASE_WINDOWS_APP_ID=
   FIREBASE_WINDOWS_MEASUREMENT_ID=
   ```

   Only the keys for the target platform are needed at runtime. Use your own Firebase project's configuration; never copy credentials from another environment.

2. From the Flutter project directory, install packages and run the app:

   ```bash
   cd shopwise_app
   flutter pub get
   flutter run
   ```

3. Configure and deploy Firestore Security Rules from `shopwise_app/firestore.rules`. Do not use Firestore Test Mode for production data.

### Optional Node.js/MySQL REST backend

Prerequisites: Node.js 18 or newer, npm 9 or newer, and MySQL 8 or newer.

1. Install dependencies and create a local environment file:

   ```bash
   cd backend
   npm install
   cp .env.example .env
   ```

   On Windows PowerShell, use `Copy-Item .env.example .env` instead of `cp` if needed.

2. Edit `backend/.env` with a development database, credentials, and a strong local JWT secret. The template includes the supported settings for port, MySQL, JWT, CORS, rate limits, logging, analysis, and notifications. Do not commit `.env` or put secrets in this README.

3. Create the configured MySQL database and grant the configured user access. Then apply and verify the migrations:

   ```bash
   npm run migrate
   npm run db
   ```

   The migration sequence is in `backend/src/database/migrations/` and includes the sales engine schema migration. Seeding is optional for local development:

   ```bash
   npm run seed
   ```

4. Start the API:

   ```bash
   npm run dev
   ```

   The default API base URL is `http://localhost:3000/api/v1`; the health check is `http://localhost:3000/api/health`. For an Android emulator, the host machine is usually reached through `10.0.2.2` rather than `localhost` from inside the emulator. The Flutter app's active Firestore feature path does not call this API automatically.

## Firebase configuration and security

- Firebase is initialized in `shopwise_app/lib/main.dart` after `.env` is loaded.
- Firebase Authentication uses email/password.
- Firestore documents are scoped under `shops/{uid}` and access is intended to be owner-only through `shopwise_app/firestore.rules`.
- Keep `.env`, platform service-account/config files, signing keys, and production credentials out of Git.
- A Firebase API key is not an authorization boundary by itself; enforce access through Firebase Authentication, deployed Firestore rules, and appropriate Firebase/Google Cloud restrictions.

## REST API overview

The backend mounts versioned routes under `/api/v1`:

| Area | Routes currently present |
| --- | --- |
| Authentication | `/auth` — register, login, current user, logout, password reset |
| Shop | `/shop` — create, read/check, update, delete shop |
| Categories | `/categories` — CRUD |
| Products | `/products` — CRUD, search/list, low-stock list |
| Batches and stock | `/products/:id/batches`, `/products/:id/stock-history`, `/products/:id/fefo`, `/batches/:id` |
| Sales | `POST /sales` — process a sale |
| Reports | `GET /reports/daily-summary` — daily totals and seven-day trend |

Private routes require a JWT. Global API and stricter authentication rate limits are configured in the Express app. For detailed contracts, see [API.md](API.md); the route source in `backend/src/routes/` is authoritative if older planning documentation differs.

## Tests and quality checks

Run backend tests and coverage from `backend/`:

```bash
npm test -- --runInBand --coverage
```

Run Flutter tests from `shopwise_app/`:

```bash
flutter test
```

Other backend checks:

```bash
npm run lint
npm run migrate
npm run db
```

The test directories are `backend/tests/` and `shopwise_app/test/`. Test results can vary with local tooling and environment; run the commands above to verify the current checkout.

## Project layout

```text
ShopWise/
├─ ARCHITECTURE.md
├─ API.md
├─ BUSINESS_LOGIC.md
├─ DATABASE.md
├─ AUTHENTICATION_TESTING.md
├─ backend/
│  ├─ src/
│  │  ├─ config/          # Environment and MySQL configuration
│  │  ├─ controllers/     # HTTP request handling
│  │  ├─ middleware/      # Authentication, validation, rate limiting
│  │  ├─ repositories/    # SQL persistence and tenant-scoped queries
│  │  ├─ services/        # Backend business logic
│  │  ├─ routes/          # Express API routes
│  │  └─ database/        # Migrations, seed, schema verification
│  ├─ tests/
│  └─ package.json
└─ shopwise_app/
   ├─ lib/
   │  ├─ core/            # Theme, networking, shared configuration
   │  ├─ features/        # Auth, shop, dashboard, stock, products, sales,
   │  │                    # categories, customers, and reports screens
   │  ├─ models/
   │  ├─ providers/       # Riverpod state management
   │  ├─ repositories/    # Firestore-backed data operations
   │  ├─ services/
   │  └─ widgets/
   ├─ test/
   ├─ firestore.rules
   └─ pubspec.yaml
```

## Project documentation

- [Architecture](ARCHITECTURE.md)
- [API reference](API.md)
- [Business logic](BUSINESS_LOGIC.md)
- [Database design](DATABASE.md)
- [Authentication testing notes](AUTHENTICATION_TESTING.md)
- [Backend setup](backend/README.md)
- [Backend database setup](backend/DATABASE_SETUP.md)
- [Phase 1 backend report](backend/PHASE_1_FINAL_REPORT.md)

Some root documents describe the original planned MySQL-backed architecture and may include design-stage scope. For current implementation details, use the Flutter source, Firestore rules, backend routes, and migrations.

## Security notes

- Never commit `.env` files, Firebase private service-account keys, MySQL passwords, JWT secrets, or Android signing credentials.
- Use least-privilege MySQL accounts for the REST backend.
- Keep backend tenant scoping and soft-delete filters in place for tenant-owned records.
- Deploy Firestore owner-scoped rules before using production data; do not rely on client-side shop IDs for authorization.
- Review Firebase Authentication, Firestore rules, and API key restrictions before production deployment.

## License

The backend package declares the MIT license. Confirm the repository owner's intended license for the complete project before treating all app and design assets as MIT-licensed.
