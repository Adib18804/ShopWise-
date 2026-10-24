import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_colors.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/sales/screens/create_sale_screen.dart';

// TODO: Import when implemented
// import 'core/theme/app_theme.dart';
// import 'routes/app_router.dart';
// import 'core/localization/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase is not configured or used by the Phase 1 app yet. Initializing it
  // here would block the first frame when web Firebase options are unavailable.

  // Set preferred orientations (portrait only)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    const ProviderScope(
      child: ShopWiseApp(),
    ),
  );
}

class ShopWiseApp extends StatelessWidget {
  const ShopWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShopWise',
      routes: {
        '/sales/new': (_) => const CreateSaleScreen(),
      },
      debugShowCheckedModeBanner: false,

      // TODO: Uncomment when theme is implemented
      // theme: AppTheme.lightTheme,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          error: AppColors.error,
        ),
      ),

      // TODO: Uncomment when localization is implemented
      // localizationsDelegates: AppLocalizations.localizationsDelegates,
      // supportedLocales: AppLocalizations.supportedLocales,
      // locale: const Locale('bn'), // Default to Bangla

      // TODO: Uncomment when router is implemented
      // routerConfig: appRouter,

      // Start with splash screen
      home: const SplashScreen(),
    );
  }
}
