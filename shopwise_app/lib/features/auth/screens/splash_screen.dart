import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/shop_provider.dart';
import '../../../core/theme/app_colors.dart';
import 'welcome_screen.dart';
import '../../shop/screens/shop_setup_screen.dart';
import '../../dashboard/screens/dashboard_screen.dart';

/// Splash screen - checks auth state and navigates accordingly
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeApp();
      }
    });
  }

  Future<void> _initializeApp() async {
    // Initialize auth state
    await ref.read(authProvider.notifier).initialize();

    // Wait a bit for splash screen visibility
    await Future<void>.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Navigate based on auth state
    final authState = ref.read(authProvider);
    
    if (authState.isAuthenticated && authState.user != null) {
      // User is logged in, check shop status
      final user = authState.user!;
      
      if (user.hasShop) {
        // User has shop, initialize shop data and go to dashboard
        await ref.read(shopProvider.notifier).initialize();
        
        if (!mounted) return;
        
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => const DashboardScreen(),
          ),
        );
      } else {
        // User needs to set up shop
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => const ShopSetupScreen(),
          ),
        );
      }
    } else {
      // User not logged in, go to welcome screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const WelcomeScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo/icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.store,
                size: 60,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            // App name
            const Text(
              'ShopWise',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            // Subtitle
            const Text(
              'স্মার্ট দোকান সহায়ক',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 48),
            // Loading indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
