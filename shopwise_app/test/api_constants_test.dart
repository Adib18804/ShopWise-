import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopwise_app/core/constants/api_constants.dart';

const configuredBaseUrl = String.fromEnvironment('SHOPWISE_API_BASE_URL');

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('uses emulator host on Android unless a deployment URL is configured', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    expect(
      ApiConstants.baseUrl,
      configuredBaseUrl.isNotEmpty
          ? configuredBaseUrl
          : 'http://10.0.2.2:3000/api/v1',
    );
  });

  test('uses localhost on non-Android platforms unless overridden', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    expect(
      ApiConstants.baseUrl,
      configuredBaseUrl.isNotEmpty
          ? configuredBaseUrl
          : 'http://localhost:3000/api/v1',
    );
  });
}
