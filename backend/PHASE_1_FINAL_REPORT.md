# ShopWise Phase 1 Final Report

**Status:** Phase 1 complete and ready for Phase 2  
**Report date:** 25 October 2026

## 1. Executive Summary

Phase 1 stabilization and verification are complete. The backend security controls, shop and inventory foundations, Android runtime fixes, and automated quality gates have been verified. The backend test suite passes all configured coverage thresholds, and the project is ready to begin Phase 2: Sales Engine.

## 2. Tech Stack

- **Backend:** Node.js, Express.js, REST API, JWT, bcrypt
- **Database:** MySQL 8.0
- **Mobile client:** Flutter and Dart, with Riverpod, Dio, and secure token storage
- **Test tooling:** Jest and Supertest

## 3. Security Audit

- **JWT algorithm pinning:** JWT verification explicitly restricts accepted tokens to HS256.
- **Rate limiting:** A global API limiter and stricter authentication limiter protect API and authentication routes.
- **Tenant isolation:** Repository queries scope shop data to the authenticated shop and user context.
- **Soft delete:** Shops and related tenant records use `deleted_at`; active-record queries filter deleted rows.

These controls were covered by the Phase 1 security and repository/API verification tests.

## 4. Quality Assurance: Tests and Coverage

The final backend test run passed **25 test suites and 150 tests**. All configured global coverage thresholds are met.

| Coverage metric | Result |
|---|---:|
| Statements | 85.16% |
| Branches | 78.73% |
| Functions | 83.78% |
| Lines | 85.34% |

Command: `npm test -- --runInBand --coverage`

## 5. Bug Fixes

**Bug 3 - Batch Type Cast:** Flutter batch model parsing was corrected to handle MySQL decimal values, including prices represented as decimal strings. Runtime verification confirmed values such as `45.50` parse correctly.

## 6. Architecture

The backend follows the **Repository -> Service -> Controller -> Route** pattern. Database access and tenant scoping remain in repositories, business rules in services, HTTP mapping in controllers, and route definitions apply authentication and validation middleware.

## 7. Cleanup

- Firebase initialization, configuration, test mocks, environment placeholders, and the `firebase-admin` dependency were removed under the project's "No Firebase" rule.
- The cleanup script hard-deleted **25** synthetic verification users matching the inspected Phase 1 test prefixes under `@example.test`, plus **24 associated shops**. Of those shops, **9 were directly deleted** (all soft-deleted); **15 active shops** were removed by the users' foreign-key cascade. Post-delete verification found **0** remaining users or shops matching the cleanup patterns.

Cleanup was performed with `cleanup_phase1_verification_data.js`, which verifies the configured database is `shopwise_dev`, defaults to dry-run mode, targets only the inspected synthetic email prefixes, and verifies deleted IDs/counts before commit.

## 8. Next Steps

Phase 2, the **Sales Engine**, is ready to begin. Its scope should build on the Phase 1 product, batch, and stock transaction foundations while preserving tenant isolation and shopkeeper decision-making.
