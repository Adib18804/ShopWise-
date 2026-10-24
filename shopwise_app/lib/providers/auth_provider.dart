import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../models/auth_response_model.dart';
import '../services/auth_service.dart';
import '../core/network/api_exception.dart';

/// Auth state
class AuthState {
  final UserModel? user;
  final bool isLoading;
  final bool isAuthenticated;
  final String? error;

  AuthState({
    this.user,
    this.isLoading = false,
    this.isAuthenticated = false,
    this.error,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    bool? isAuthenticated,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      error: error,
    );
  }

  AuthState clearError() {
    return AuthState(
      user: user,
      isLoading: isLoading,
      isAuthenticated: isAuthenticated,
      error: null,
    );
  }
}

/// Auth state notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(AuthState());

  /// Initialize auth state (check if user is already logged in)
  Future<void> initialize() async {
    state = state.copyWith(isLoading: true);
    
    try {
      final isAuthenticated = await _authService.isAuthenticated();
      
      if (isAuthenticated) {
        final user = await _authService.getCurrentUser();
        state = AuthState(
          user: user,
          isAuthenticated: true,
          isLoading: false,
        );
      } else {
        state = AuthState(
          isAuthenticated: false,
          isLoading: false,
        );
      }
    } catch (e) {
      state = AuthState(
        isAuthenticated: false,
        isLoading: false,
        error: e is ApiException ? e.message : 'Failed to initialize auth',
      );
    }
  }

  /// Register new user
  Future<bool> register({
    required String name,
    required String phone,
    required String email,
    required String password,
    String preferredLanguage = 'bn',
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final AuthResponseModel response = await _authService.register(
        name: name,
        phone: phone,
        email: email,
        password: password,
        preferredLanguage: preferredLanguage,
      );
      
      state = AuthState(
        user: response.user,
        isAuthenticated: true,
        isLoading: false,
      );
      
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is ApiException ? e.message : 'Registration failed',
      );
      return false;
    }
  }

  /// Login user
  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final AuthResponseModel response = await _authService.login(
        identifier: identifier,
        password: password,
      );
      
      state = AuthState(
        user: response.user,
        isAuthenticated: true,
        isLoading: false,
      );
      
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is ApiException ? e.message : 'Login failed',
      );
      return false;
    }
  }

  /// Logout user
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    
    try {
      await _authService.logout();
      state = AuthState(
        isAuthenticated: false,
        isLoading: false,
      );
    } catch (e) {
      // Always log out locally even if API call fails
      state = AuthState(
        isAuthenticated: false,
        isLoading: false,
      );
    }
  }

  /// Refresh user data
  Future<void> refreshUser() async {
    try {
      final user = await _authService.getCurrentUser();
      state = state.copyWith(user: user);
    } catch (e) {
      if (e is ApiException && e.statusCode == 401) {
        // Session expired
        state = AuthState(
          isAuthenticated: false,
          isLoading: false,
          error: 'Session expired. Please login again.',
        );
      }
    }
  }

  /// Clear error
  void clearError() {
    state = state.clearError();
  }
}

/// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Auth state provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});
