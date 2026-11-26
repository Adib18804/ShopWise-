import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopwise_app/main.dart';
import 'package:shopwise_app/models/user_model.dart';
import 'package:shopwise_app/providers/auth_provider.dart';
import 'package:shopwise_app/providers/customer_provider.dart';
import 'package:shopwise_app/providers/insight_provider.dart';
import 'package:shopwise_app/providers/internet_status_provider.dart';
import 'package:shopwise_app/providers/reports_provider.dart';
import 'package:shopwise_app/providers/shop_provider.dart';
import 'package:shopwise_app/repositories/customer_repository.dart';
import 'package:shopwise_app/repositories/reports_repository.dart';
import 'package:shopwise_app/services/auth_service.dart';
import 'package:shopwise_app/services/shop_service.dart';
import 'package:shopwise_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:shopwise_app/widgets/layout/main_shell.dart';

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(this.testState) : super(AuthService());

  final AuthState testState;

  @override
  Future<void> initialize() async {
    state = testState;
  }
}

class _TestReportsNotifier extends ReportsController {
  _TestReportsNotifier() : super(ReportsRepository());

  @override
  Future<void> load() async {}
}

class _TestShopNotifier extends ShopNotifier {
  _TestShopNotifier() : super(ShopService());

  @override
  Future<void> initialize() async {}
}

class _TestCustomerNotifier extends CustomerNotifier {
  _TestCustomerNotifier() : super(CustomerRepository());

  @override
  void init() {}
}

class _TestInsightsNotifier extends InsightsNotifier {
  _TestInsightsNotifier(super.ref);

  @override
  Future<void> load() async {}
}

UserModel _testUser({required bool hasShop}) {
  final now = DateTime(2026);
  return UserModel(
    id: 1,
    name: 'Test Shopkeeper',
    phone: '01700000000',
    email: 'test@example.com',
    preferredLanguage: 'bn',
    hasShop: hasShop,
    shopId: hasShop ? 1 : null,
    shopType: hasShop ? 'general' : null,
    createdAt: now,
    updatedAt: now,
  );
}

Widget _appWithAuthState(AuthState authState) => ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => _TestAuthNotifier(authState)),
        shopProvider.overrideWith((ref) => _TestShopNotifier()),
        reportsProvider.overrideWith((ref) => _TestReportsNotifier()),
        customerProvider.overrideWith((ref) => _TestCustomerNotifier()),
        insightsProvider.overrideWith((ref) => _TestInsightsNotifier(ref)),
        internetStatusProvider.overrideWith((ref) => Stream<bool>.value(true)),
      ],
      child: const ShopWiseApp(),
    );

void main() {
  testWidgets('unauthenticated startup reaches the welcome screen', (
    tester,
  ) async {
    await tester.pumpWidget(_appWithAuthState(AuthState()));

    expect(find.text('ShopWise'), findsOneWidget);
    expect(find.text('স্মার্ট দোকান সহায়ক'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('লগইন করুন'), findsOneWidget);
    expect(find.text('নতুন অ্যাকাউন্ট তৈরি করুন'), findsOneWidget);
  });

  testWidgets('authenticated startup without a shop reaches shop setup', (
    tester,
  ) async {
    await tester.pumpWidget(
      _appWithAuthState(
        AuthState(user: _testUser(hasShop: false), isAuthenticated: true),
      ),
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('দোকান সেটআপ'), findsOneWidget);
  });

  testWidgets('authenticated startup with a shop reaches dashboard', (
    tester,
  ) async {
    await tester.pumpWidget(
      _appWithAuthState(
        AuthState(user: _testUser(hasShop: true), isAuthenticated: true),
      ),
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.byType(ShopWiseShell), findsOneWidget);
    expect(find.byType(DashboardScreen), findsOneWidget);
  });
}
