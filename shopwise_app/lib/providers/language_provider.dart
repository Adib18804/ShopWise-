import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Supported UI languages.
enum AppLanguage { bn, en }

/// State holder for the active language.
class LanguageState {
  final AppLanguage language;

  const LanguageState(this.language);
}

/// Toggles the whole UI between Bengali and English.
///
/// Persisting the choice (e.g. SharedPreferences) is intentionally left out for
/// the prototype — the default is Bengali, matching the target shopkeeper.
class LanguageNotifier extends StateNotifier<LanguageState> {
  LanguageNotifier() : super(const LanguageState(AppLanguage.bn));

  void toggle() {
    state = LanguageState(
      state.language == AppLanguage.bn ? AppLanguage.en : AppLanguage.bn,
    );
  }

  void setLanguage(AppLanguage language) {
    state = LanguageState(language);
  }
}

final languageProvider =
    StateNotifierProvider<LanguageNotifier, LanguageState>((ref) {
  return LanguageNotifier();
});

/// Bilingual string catalogue + small formatting helpers (date, amounts,
/// Bengali digits). Kept as a simple map-driven class rather than ARB files so
/// the prototype stays in one place. Watching [appLocalizationsProvider]
/// rebuilds the UI the moment the language changes.
class AppLocalizations {
  AppLocalizations(this.language);

  final AppLanguage language;

  bool get isBn => language == AppLanguage.bn;

  // --- Generic UI strings -------------------------------------------------
  String get appName => 'ShopWise';
  String get todaySummary => isBn ? 'আজকের সারসংক্ষেপ' : "Today's Summary";
  String get welcome => isBn ? 'স্বাগতম' : 'Welcome';
  String get todaysSales => isBn ? 'আজকের বিক্রি' : "Today's Sales";
  String get itemsSold => isBn ? 'আইটেম বিক্রি' : 'Items Sold';
  String get smartInsights => isBn ? 'স্মার্ট ইনসাইটস' : 'Smart Insights';
  String get quickActions => isBn ? 'দ্রুত কাজ' : 'Quick Actions';

  String get stockOutRisk => isBn ? 'স্টক শেষ হওয়ার ঝুঁকি' : 'Stock-Out Risk';
  String get expiryRisk => isBn ? 'মেয়াদ শেষের ঝুঁকি' : 'Expiry Risk';
  String get deadStock => isBn ? 'ধীর গতির স্টক' : 'Slow-Moving Stock';

  String get addProduct => isBn ? 'পণ্য যোগ করুন' : 'Add Product';
  String get newSale => isBn ? 'নতুন বিক্রি' : 'New Sale';
  String get viewReports => isBn ? 'রিপোর্ট দেখুন' : 'View Reports';
  String get viewDetails => isBn ? 'বিস্তারিত দেখুন' : 'View details';

  String get valueAtRisk => isBn ? 'ঝুঁকিতে মূল্য' : 'Value at risk';
  String get stockValue => isBn ? 'স্টক মূল্য' : 'Stock value';
  String get noAlerts => isBn ? 'কোনো ঝুঁকি নেই' : 'No risks detected';
  String get noAlertsHere =>
      isBn ? 'এই বিভাগে কোনো ঝুঁকি নেই' : 'No risks in this section';

  String get logout => isBn ? 'লগআউট' : 'Logout';
  String get confirmLogoutTitle => isBn ? 'লগআউট' : 'Logout';
  String get confirmLogoutMessage =>
      isBn ? 'আপনি কি লগআউট করতে চান?' : 'Do you want to log out?';
  String get yes => isBn ? 'হ্যাঁ' : 'Yes';
  String get no => isBn ? 'না' : 'No';

  String get loading => isBn ? 'লোড হচ্ছে...' : 'Loading...';
  String get retry => isBn ? 'আবার চেষ্টা' : 'Retry';
  String get refreshFailed => isBn ? 'তথ্য আনা যায়নি' : 'Failed to load data';

  // --- Alert-specific strings ----------------------------------------------
  String get outOfStock => isBn ? 'স্টক শেষ' : 'Out of stock';
  String get currentStock => isBn ? 'বর্তমান স্টক' : 'Current stock';
  String get suggestedRestock => isBn ? 'রিস্টক পরামর্শ' : 'Suggested restock';
  String get noSalesIn30 => isBn ? '৩০ দিনে কোনো বিক্রি নেই' : 'No sales in 30 days';
  String get neverSold => isBn ? 'এখনো বিক্রি হয়নি' : 'Never sold';
  String get lastSale => isBn ? 'শেষ বিক্রি' : 'Last sale';
  String get quantity => isBn ? 'পরিমাণ' : 'Quantity';
  String get batch => isBn ? 'ব্যাচ' : 'Batch';

  String runsOutIn(int days) =>
      isBn ? '${_num(days)} দিনে শেষ হতে পারে' : 'may run out in $days days';
  String expiresIn(int days) {
    if (days == 0) return isBn ? 'আজ মেয়াদ শেষ' : 'expires today';
    if (days == 1) return isBn ? 'আগামীকাল মেয়াদ শেষ' : 'expires tomorrow';
    return isBn ? '${_num(days)} দিনে মেয়াদ শেষ' : 'expires in $days days';
  }

  String get expired => isBn ? 'মেয়াদ শেষ' : 'Expired';

  String itemsAtRisk(int n) =>
      isBn ? '${_num(n)} টি পণ্য ঝুঁকিতে' : '$n items at risk';
  String itemsExpiring(int n) =>
      isBn ? '${_num(n)} টি মেয়াদ শেষ হচ্ছে' : '$n expiring soon';
  String slowItems(int n) =>
      isBn ? '${_num(n)} টি ধীরগতির পণ্য' : '$n slow-moving items';

  // --- Formatting ----------------------------------------------------------
  String get currencySymbol => '৳';

  /// Formats a money amount with the currency symbol. Bengali gets Bengali
  /// digits.
  String formatAmount(double amount) => '$currencySymbol${_num(amount)}';

  /// Formats a stock quantity with its unit. Whole numbers stay whole; halves
  /// keep two decimals. Bengali gets Bengali digits.
  String formatQty(num qty, [String unit = '']) {
    final digits = _num(qty);
    return unit.isEmpty ? digits : '$digits $unit';
  }

  /// Calendar date, fully localised (weekday, day, month, year).
  String formatDate(DateTime date) {
    final weekday = _weekdays[language]![date.weekday - 1];
    final month = _months[language]![date.month - 1];
    final day = _num(date.day);
    final year = _num(date.year);
    return '$weekday, $day $month $year';
  }

  /// Date + time, e.g. "শুক্রবার, ৬ নভেম্বর ২০২৬, ১৪:৩০".
  String formatDateTime(DateTime? date) {
    if (date == null) return neverSold;
    final d = formatDate(date);
    final h = _digits(date.hour.toString().padLeft(2, '0'));
    final m = _digits(date.minute.toString().padLeft(2, '0'));
    return '$d, $h:$m';
  }

  // --- Internal helpers ---------------------------------------------------
  /// A [num] as a localised string (Bengali digits when [isBn]).
  String _num(num value) {
    final s = value is int
        ? value.toString()
        : (value == value.roundToDouble()
            ? value.toInt().toString()
            : value.toStringAsFixed(2));
    return _digits(s);
  }

  /// Converts the digits of any string to Bengali when [isBn].
  String _digits(String s) {
    if (!isBn) return s;
    return s.replaceAllMapped(RegExp('[0-9]'), (m) => _bnDigits[m[0]!]!);
  }

  static const Map<AppLanguage, List<String>> _weekdays = {
    AppLanguage.en: [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ],
    AppLanguage.bn: [
      'সোমবার', 'মঙ্গলবার', 'বুধবার', 'বৃহস্পতিবার', 'শুক্রবার', 'শনিবার', 'রবিবার'
    ],
  };

  static const Map<AppLanguage, List<String>> _months = {
    AppLanguage.en: [
      'January', 'February', 'March', 'April', 'May', 'June', 'July',
      'August', 'September', 'October', 'November', 'December'
    ],
    AppLanguage.bn: [
      'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন', 'জুলাই',
      'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর'
    ],
  };

  static const Map<String, String> _bnDigits = {
    '0': '০', '1': '১', '2': '২', '3': '৩', '4': '৪',
    '5': '৫', '6': '৬', '7': '৭', '8': '৮', '9': '৯',
  };
}

/// Reactive localisations: rebuilds whenever the language changes.
final appLocalizationsProvider = Provider<AppLocalizations>((ref) {
  return AppLocalizations(ref.watch(languageProvider).language);
});
