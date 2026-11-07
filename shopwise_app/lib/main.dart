import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/sales/screens/create_sale_screen.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env before anything Firebase-related so DefaultFirebaseOptions
  // can read the keys.  The file is bundled as a Flutter asset (see pubspec.yaml)
  // but is excluded from git via .gitignore.
  await dotenv.load();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService.instance.init();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(AppTheme.systemUiOverlay);

  runApp(
    const ProviderScope(
      child: ShopWiseApp(),
    ),
  );
}

class ShopWiseApp extends StatelessWidget {
  const ShopWiseApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
      title: 'ShopWise',
      routes: {
        '/sales/new': (_) => const CreateSaleScreen(),
      },
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashScreen(),
    );
}
