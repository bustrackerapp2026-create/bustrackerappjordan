import 'package:flutter/material.dart';

/// نظام ترجمة خفيف وقابل للتوسعة (عربي / إنجليزي).
/// أضف مفاتيح جديدة هنا ثم استخدمها عبر AppLocalizations.of(context).
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    final loc = Localizations.of<AppLocalizations>(context, AppLocalizations);
    return loc ?? AppLocalizations(const Locale('ar'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('ar'),
    Locale('en'),
  ];

  bool get isArabic => locale.languageCode == 'ar';
  bool get isEnglish => locale.languageCode == 'en';

  String _t(String ar, String en) => isArabic ? ar : en;

  // ── عام ──────────────────────────────────────────
  String get appName => _t('متتبع الحافلات', 'Bus Tracker');
  String get appNameEn => 'Jordan Bus Tracker';
  String get appTagline =>
      _t('تتبع الحافلات · نقاط التجمع · الأردن', 'Bus tracking · Pickup points · Jordan');
  String get language => _t('اللغة', 'Language');
  String get arabic => _t('العربية', 'Arabic');
  String get english => 'English';
  String get cancel => _t('إلغاء', 'Cancel');
  String get confirm => _t('تأكيد', 'Confirm');
  String get save => _t('حفظ', 'Save');
  String get logout => _t('تسجيل الخروج', 'Log out');
  String get logoutConfirm =>
      _t('هل أنت متأكد من رغبتك في تسجيل الخروج؟', 'Are you sure you want to log out?');
  String get version => _t('الإصدار', 'Version');
  String get loadingAccount =>
      _t('جاري تحميل بيانات الحساب...', 'Loading account data...');
  String get chooseLanguage => _t('اختر اللغة', 'Choose language');

  // ── تسجيل الدخول ─────────────────────────────────
  String get login => _t('تسجيل الدخول', 'Log in');
  String get loginSubtitle =>
      _t('أدخل بيانات حسابك للوصول إلى التطبيق', 'Enter your account details to access the app');
  String get welcomeLogin =>
      _t('مرحباً بك · سجّل دخولك للمتابعة', 'Welcome · Sign in to continue');
  String get email => _t('البريد الإلكتروني', 'Email');
  String get password => _t('كلمة السر', 'Password');
  String get rememberMe => _t('تذكرني', 'Remember me');
  String get forgotPassword => _t('نسيت كلمة السر؟', 'Forgot password?');
  String get noAccount => _t('ليس لديك حساب؟', "Don't have an account?");
  String get createAccount => _t('إنشاء حساب جديد', 'Create new account');
  String get enterEmailFirst =>
      _t('⚠️ الرجاء إدخال البريد الإلكتروني أولاً', '⚠️ Please enter your email first');
  String get resetLinkSent =>
      _t('📧 تم إرسال رابط إعادة تعيين كلمة السر إلى بريدك',
          '📧 Password reset link sent to your email');

  // ── التسجيل ──────────────────────────────────────
  String get registerTitle => _t('إنشاء حساب جديد', 'Create new account');
  String get fullName => _t('الاسم الكامل', 'Full name');
  String get phone => _t('رقم الهاتف', 'Phone number');
  String get confirmPassword => _t('تأكيد كلمة السر', 'Confirm password');
  String get accountType => _t('نوع الحساب', 'Account type');
  String get driver => _t('سائق', 'Driver');
  String get passenger => _t('راكب', 'Passenger');
  String get driverPendingNote =>
      _t('📌 سيتم تفعيل حساب السائق بعد موافقة الإدارة.',
          '📌 Driver account will be activated after admin approval.');
  String get passengerReadyNote =>
      _t('📌 يمكنك استخدام التطبيق فوراً كراكب.',
          '📌 You can use the app immediately as a passenger.');
  String get driverInfoRequired =>
      _t('معلومات السائق (مطلوبة)', 'Driver info (required)');
  String get busNumber => _t('رقم الباص', 'Bus number');
  String get busNumberHint =>
      _t('رقم الباص (مثل: 123)', 'Bus number (e.g. 123)');
  String get route => _t('المسار', 'Route');
  String get routeHint =>
      _t('المسار (مثل: عمان - الزرقاء)', 'Route (e.g. Amman - Zarqa)');
  String get createAccountBtn => _t('إنشاء حساب', 'Create account');
  String get alreadyHaveAccount =>
      _t('لديك حساب بالفعل؟', 'Already have an account?');
  String get passwordMismatch =>
      _t('⚠️ كلمة السر غير متطابقة', '⚠️ Passwords do not match');
  String get registerSuccess =>
      _t('✅ تم إنشاء الحساب بنجاح! سيتم تفعيل حساب السائق بعد المراجعة.',
          '✅ Account created! Driver accounts are activated after review.');
  String get enterFullName =>
      _t('الرجاء إدخال الاسم الكامل', 'Please enter full name');
  String get enterBusNumber =>
      _t('الرجاء إدخال رقم الباص', 'Please enter bus number');
  String get enterRoute =>
      _t('الرجاء إدخال المسار', 'Please enter route');
  String get passwordsDoNotMatch =>
      _t('كلمة السر غير متطابقة', 'Passwords do not match');

  // ── الإعدادات ────────────────────────────────────
  String get settings => _t('الإعدادات', 'Settings');
  String get darkMode => _t('الوضع الليلي', 'Dark mode');
  String get darkModeOn =>
      _t('المظهر الداكن مفعّل', 'Dark appearance is on');
  String get darkModeOff =>
      _t('تفعيل المظهر الداكن', 'Enable dark appearance');
  String get notifications => _t('الإشعارات', 'Notifications');
  String get notificationsSubtitle =>
      _t('تنبيهات الرحلات والطلبات', 'Trip and request alerts');
  String get languageChanged =>
      _t('🌐 تم تغيير اللغة', '🌐 Language changed');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['ar', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
