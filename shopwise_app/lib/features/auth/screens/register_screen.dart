import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_button.dart';
import 'login_screen.dart';
import '../../shop/screens/shop_setup_screen.dart';

/// Register screen
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final success = await ref.read(authProvider.notifier).register(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          preferredLanguage: 'bn',
        );

    if (!mounted) return;

    if (success) {
      // Navigate to shop setup (new users don't have shop)
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const ShopSetupScreen(),
        ),
      );
    } else {
      // Show error
      final error = ref.read(authProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Registration failed'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                const Text(
                  'নিবন্ধন করুন',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'আপনার নতুন অ্যাকাউন্ট তৈরি করুন',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Name field
                AuthTextField(
                  controller: _nameController,
                  label: 'পূর্ণ নাম',
                  hint: 'আপনার নাম লিখুন',
                  keyboardType: TextInputType.name,
                  prefixIcon: const Icon(Icons.person_outline),
                  enabled: !authState.isLoading,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'নাম প্রয়োজন';
                    }
                    if (value.trim().length < 2) {
                      return 'নাম কমপক্ষে ২ অক্ষর হতে হবে';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Phone field
                AuthTextField(
                  controller: _phoneController,
                  label: 'ফোন নম্বর',
                  hint: '01XXXXXXXXX',
                  keyboardType: TextInputType.phone,
                  prefixIcon: const Icon(Icons.phone_outlined),
                  enabled: !authState.isLoading,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'ফোন নম্বর প্রয়োজন';
                    }
                    // Bangladesh phone number validation
                    if (!RegExp(r'^01[3-9]\d{8}$').hasMatch(value.trim())) {
                      return 'সঠিক বাংলাদেশী ফোন নম্বর লিখুন';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Email field
                AuthTextField(
                  controller: _emailController,
                  label: 'ইমেইল',
                  hint: 'example@email.com',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: const Icon(Icons.email_outlined),
                  enabled: !authState.isLoading,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'ইমেইল প্রয়োজন';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(value.trim())) {
                      return 'সঠিক ইমেইল ঠিকানা লিখুন';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Password field
                AuthTextField(
                  controller: _passwordController,
                  label: 'পাসওয়ার্ড',
                  hint: 'কমপক্ষে ৮ অক্ষর',
                  obscureText: _obscurePassword,
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  enabled: !authState.isLoading,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'পাসওয়ার্ড প্রয়োজন';
                    }
                    if (value.length < 8) {
                      return 'পাসওয়ার্ড কমপক্ষে ৮ অক্ষর হতে হবে';
                    }
                    if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(value)) {
                      return 'পাসওয়ার্ডে বড় হাতের অক্ষর, ছোট হাতের অক্ষর এবং সংখ্যা থাকতে হবে';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Confirm password field
                AuthTextField(
                  controller: _confirmPasswordController,
                  label: 'পাসওয়ার্ড নিশ্চিত করুন',
                  hint: 'পাসওয়ার্ড পুনরায় লিখুন',
                  obscureText: _obscureConfirmPassword,
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                  enabled: !authState.isLoading,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'পাসওয়ার্ড নিশ্চিত করুন';
                    }
                    if (value != _passwordController.text) {
                      return 'পাসওয়ার্ড মিলছে না';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                
                // Register button
                AuthButton(
                  text: 'নিবন্ধন করুন',
                  onPressed: _handleRegister,
                  isLoading: authState.isLoading,
                ),
                const SizedBox(height: 24),
                
                // Login link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'ইতিমধ্যে অ্যাকাউন্ট আছে? ',
                      style: TextStyle(color: Colors.black54),
                    ),
                    TextButton(
                      onPressed: authState.isLoading
                          ? null
                          : () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute<void>(
                                  builder: (_) => const LoginScreen(),
                                ),
                              );
                            },
                      child: const Text(
                        'লগইন করুন',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
