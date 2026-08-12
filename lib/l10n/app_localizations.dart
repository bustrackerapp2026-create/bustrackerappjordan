import 'package:flutter/material.dart';

/// نظام ترجمة خفيف وقابل للتوسعة (عربي / إنجليزي).
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
  String get confirmLogout => _t('تأكيد الخروج', 'Confirm logout');
  String get version => _t('الإصدار', 'Version');
  String get loadingAccount =>
      _t('جاري تحميل بيانات الحساب...', 'Loading account data...');
  String get chooseLanguage => _t('اختر اللغة', 'Choose language');
  String get notificationsComingSoon =>
      _t('📬 سيتم فتح الإشعارات قريباً', '📬 Notifications coming soon');
  String get help => _t('المساعدة', 'Help');
  String get aboutApp => _t('عن التطبيق', 'About');
  String get account => _t('الحساب', 'Account');
  String get editProfile => _t('تعديل الملف الشخصي', 'Edit profile');
  String get changePassword => _t('تغيير كلمة المرور', 'Change password');
  String get myTrips => _t('رحلاتي', 'My trips');
  String get home => _t('الرئيسية', 'Home');
  String get points => _t('النقاط', 'Points');
  String get delete => _t('حذف', 'Delete');
  String get execute => _t('تنفيذ', 'Run');
  String get refresh => _t('تحديث', 'Refresh');
  String get retry => _t('إعادة المحاولة', 'Retry');
  String get pleaseLogin => _t('يرجى تسجيل الدخول', 'Please sign in');
  String get errorPrefix => _t('خطأ', 'Error');
  String get processing => _t('جاري...', 'Working...');
  String get now => _t('الآن', 'Just now');
  String get dinar => _t('دينار', 'JOD');
  String get approve => _t('موافقة', 'Approve');
  String get reject => _t('رفض', 'Reject');
  String get live => _t('مباشر', 'Live');
  String get searchHint =>
      _t('ابحث عن وجهة أو خط...', 'Search destination or route...');

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

  String get registerTitle => _t('إنشاء حساب جديد', 'Create new account');
  String get fullName => _t('الاسم الكامل', 'Full name');
  String get phone => _t('رقم الهاتف', 'Phone number');
  String get confirmPassword => _t('تأكيد كلمة السر', 'Confirm password');
  String get accountType => _t('نوع الحساب', 'Account type');
  String get driver => _t('سائق', 'Driver');
  String get passenger => _t('راكب', 'Passenger');
  String get admin => _t('مشرف', 'Admin');
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

  String get pendingTitle =>
      _t('⏳ حسابك قيد المراجعة', '⏳ Your account is under review');
  String get pendingMessage => _t(
        'تم إنشاء حساب السائق بنجاح، وسيتم تفعيله من قبل الإدارة بعد التأكد من البيانات.',
        'Your driver account was created successfully and will be activated by admin after verification.',
      );
  String get rejectedTitle =>
      _t('❌ تم رفض طلبك', '❌ Your request was rejected');
  String get rejectedMessage => _t(
        'عذراً، لم تتم الموافقة على طلبك. يرجى التواصل مع الدعم لمعرفة السبب.',
        'Sorry, your request was not approved. Please contact support for details.',
      );

  String get navMap => _t('الخريطة', 'Map');
  String get navOperations => _t('العمليات', 'Operations');
  String get navRequests => _t('الطلبات', 'Requests');
  String get navMyAccount => _t('حسابي', 'Account');
  String get navMyTrips => _t('رحلاتي', 'My trips');
  String get navHome => _t('الرئيسية', 'Home');
  String get navPoints => _t('النقاط', 'Points');
  String get navSettings => _t('الإعدادات', 'Settings');

  String get adminDashboardTitle =>
      _t('لوحة التحكم - الأدمن', 'Admin dashboard');
  String get driverDashboard => _t('لوحة السائق', 'Driver dashboard');
  String get passengerDashboard => _t('لوحة الراكب', 'Passenger dashboard');

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
  String get shareMyLocation => _t('مشاركة موقعي', 'Share my location');
  String get shareMyLocationSubtitle => _t(
        'إظهار موقعي للإدارة أثناء انتظار الباص',
        'Show my location to admin while waiting for the bus',
      );
  String get workData => _t('بيانات العمل', 'Work details');
  String get routeLine => _t('المسار / الخط', 'Route / line');
  String get notSpecified => _t('غير محدد', 'Not specified');
  String get verified => _t('معتمد', 'Verified');
  String get awaitingApproval => _t('بانتظار الاعتماد', 'Awaiting approval');
  String get supportAndInfo => _t('الدعم والمعلومات', 'Support & info');
  String get privacyPolicy => _t('سياسة الخصوصية', 'Privacy policy');
  String get tripsAndUsage => _t('الرحلات والاستخدام', 'Trips & usage');
  String get favoritePickupPoints =>
      _t('نقاط التجمع المفضلة', 'Favorite pickup points');
  String get comingSoon => _t('قريباً', 'Coming soon');

  String get operationsTitle => _t('📊 العمليات', '📊 Operations');
  String get tabCurrent => _t('الحالية', 'Active');
  String get tabPast => _t('السابقة', 'Past');
  String get pleaseLoginOperations =>
      _t('يرجى تسجيل الدخول لعرض العمليات', 'Please sign in to view operations');
  String get pleaseLoginRequests =>
      _t('يرجى تسجيل الدخول لعرض الطلبات', 'Please sign in to view requests');
  String get pleaseLoginTrips =>
      _t('يرجى تسجيل الدخول لعرض رحلاتك', 'Please sign in to view your trips');
  String get noActiveTrips =>
      _t('لا توجد رحلات نشطة حالياً', 'No active trips right now');
  String get noActiveTripsHint =>
      _t('ستظهر الرحلات التي قبلتها هنا.', 'Accepted trips will appear here.');
  String get noPastTrips =>
      _t('لا توجد رحلات سابقة', 'No past trips');
  String get noPastTripsHint =>
      _t('ستظهر الرحلات المكتملة أو الملغية هنا.',
          'Completed or cancelled trips will appear here.');
  String get noPastTripsPassengerHint =>
      _t('سوف تظهر رحلاتك هنا بعد حجز أول رحلة.',
          'Your trips will appear here after your first booking.');
  String get statusCompleted => _t('✅ مكتملة', '✅ Completed');
  String get statusCancelled => _t('❌ ملغية', '❌ Cancelled');
  String get statusActive => _t('🚀 نشطة', '🚀 Active');
  String get statusPending => _t('⏳ قيد الانتظار', '⏳ Pending');
  String get statusInProgress => _t('🚀 قيد التنفيذ', '🚀 In progress');
  String get passengerLabel => _t('الراكب', 'Passenger');
  String get endTrip => _t('إنهاء الرحلة', 'End trip');
  String get startTrip => _t('بدء الرحلة', 'Start trip');
  String get tripEnded =>
      _t('✅ تم إنهاء الرحلة بنجاح', '✅ Trip ended successfully');
  String get tripCancelled =>
      _t('🗑️ تم إلغاء الرحلة', '🗑️ Trip cancelled');
  String get tripStatusUpdateFailed =>
      _t('❌ فشل تحديث حالة الرحلة، يرجى المحاولة لاحقاً.',
          '❌ Failed to update trip status. Try again later.');
  String get incomingRequests =>
      _t('📋 الطلبات الواردة', '📋 Incoming requests');
  String get noIncomingRequests =>
      _t('لا توجد طلبات واردة حالياً', 'No incoming requests');
  String get noIncomingRequestsHint =>
      _t('ستظهر طلبات الركاب هنا عند حجزهم لرحلة.',
          'Passenger requests will appear here when they book.');
  String get loadRequestsError =>
      _t('حدث خطأ أثناء تحميل الطلبات.', 'Failed to load requests.');
  String get loadTripsError =>
      _t('حدث خطأ أثناء تحميل الرحلات.', 'Failed to load trips.');
  String get acceptRequest => _t('✅ قبول الطلب', '✅ Accept request');
  String get accepting => _t('جاري القبول...', 'Accepting...');
  String acceptPassengerSuccess(String id) =>
      _t('✅ تم قبول طلب الراكب $id بنجاح!', '✅ Accepted passenger $id successfully!');
  String get tripNotFound =>
      _t('⚠️ الرحلة غير موجودة أو تم حذفها.',
          '⚠️ Trip not found or was deleted.');
  String get tripTakenByOther =>
      _t('⚠️ تم قبول هذه الرحلة من قبل سائق آخر.',
          '⚠️ This trip was accepted by another driver.');
  String get acceptRequestFailed =>
      _t('❌ فشل قبول الطلب، يرجى المحاولة لاحقاً.',
          '❌ Failed to accept request. Try again later.');

  String daysAgo(int n) => isArabic
      ? 'قبل $n يوم${n > 1 ? 'اً' : ''}'
      : '$n day${n > 1 ? 's' : ''} ago';
  String hoursAgo(int n) => isArabic
      ? 'قبل $n ساعة${n > 1 ? 'اً' : ''}'
      : '$n hour${n > 1 ? 's' : ''} ago';
  String minutesAgo(int n) => isArabic
      ? 'قبل $n دقيقة${n > 1 ? 'اً' : ''}'
      : '$n min${n > 1 ? 's' : ''} ago';

  String get driverOnlineMsg =>
      _t('🟢 أنت متصل — يظهر موقعك للركاب الآن',
          '🟢 You are online — passengers can see you');
  String get driverOfflineMsg =>
      _t('⚪ تم إيقاف المشاركة', '⚪ Location sharing stopped');
  String get onlineStatusFailed =>
      _t('تعذر تحديث حالة الاتصال', 'Could not update online status');
  String get followCameraOn =>
      _t('📡 متابعة الكاميرا مفعّلة', '📡 Camera follow enabled');
  String get followCameraOff =>
      _t('✋ متابعة الكاميرا متوقفة', '✋ Camera follow disabled');
  String get tapMapToAddPoint =>
      _t('📍 اضغط على الخريطة لإضافة نقطة', '📍 Tap the map to add a point');
  String get cancelled => _t('❌ تم الإلغاء', '❌ Cancelled');
  String get connected => _t('متصل', 'Online');
  String get disconnected => _t('غير متصل', 'Offline');
  String get lineLabel => _t('الخط', 'Line');
  String get goOnline => _t('اتصال', 'Go online');
  String get goOffline => _t('قطع الاتصال', 'Go offline');
  String get tripLabel => _t('رحلة', 'Trip');
  String get activeTrip => _t('رحلة نشطة', 'Active trip');
  String get tripWithFollow => _t('رحلة + متابعة', 'Trip + follow');
  String speedKmh(String value) => _t('$value كم/س', '$value km/h');
  String get speedPlaceholder => _t('-- كم/س', '-- km/h');
  String onlineWithRoute(String route) =>
      _t('🟢 متصل — الخط: $route', '🟢 Online — line: $route');
  String get offlineStatus => _t('⚪ غير متصل', '⚪ Offline');

  String get mapLayersSettings =>
      _t('⚙️ إعدادات طبقات الخريطة', '⚙️ Map layer settings');
  String get chooseMapStyle =>
      _t('اختر ستايل المظهر:', 'Choose map style:');
  String get mapStyleStreets => _t('شوارع', 'Streets');
  String get mapStyleSatellite => _t('قمر صناعي', 'Satellite');
  String get mapStyleOutdoors => _t('طبيعة', 'Outdoors');
  String get customizeLabels =>
      _t('تخصيص الأسماء والمعالم:', 'Customize labels:');
  String get labelsHideHint =>
      _t('عند الإيقاف تختفي التسميات من الخريطة فوراً',
          'Turning off hides labels on the map immediately');
  String get placeLabels =>
      _t('📍 المدن والأماكن الكبرى', '📍 Cities & places');
  String get poiLabels =>
      _t('🏛️ معالم الجذب (POI)', '🏛️ Points of interest');
  String get poiLabelsSubtitle =>
      _t('مطاعم، مستشفيات، مدارس...', 'Restaurants, hospitals, schools...');
  String get roadLabels => _t('🛣️ أسماء الشوارع', '🛣️ Road names');

  String get pickupLabelSizeTitle =>
      _t('حجم نص نقاط التجمع', 'Pickup point label size');
  String get pickupLabelSizeHint => _t(
        'يطبّق على أسماء النقاط المضافة في كل الخرائط',
        'Applies to added point names on all maps',
      );
  String get pickupLabelSizeNormal => _t('عادي', 'Normal');
  String get pickupLabelSizeLarge => _t('كبير', 'Large');
  String get pickupLabelSizeXLarge => _t('أكبر', 'Extra large');
  String get pickupLabelSizeChanged =>
      _t('✅ تم تحديث حجم نص النقاط', '✅ Pickup label size updated');

  String routeFiltered(String route) =>
      _t('🔄 تم تصفية الخط: $route', '🔄 Filtered route: $route');
  String get tapMapAddNewPoint =>
      _t('📍 اضغط على الخريطة لإضافة نقطة جديدة',
          '📍 Tap the map to add a new point');
  String get cancelAddPoint =>
      _t('❌ تم إلغاء إضافة النقطة', '❌ Add point cancelled');
  String get liveTracking => _t('🚌 تتبع حي', '🚌 Live tracking');
  String liveBusesCount(int n) =>
      _t('$n باص متصل الآن', '$n bus${n == 1 ? '' : 'es'} online now');
  String get noLiveBuses =>
      _t('لا يوجد باصات متصلة حالياً', 'No buses online right now');

  String get pendingPointsTitle =>
      _t('📍 نقاط التجمع المعلقة', '📍 Pending pickup points');
  String get noPendingPoints =>
      _t('لا توجد نقاط تجمع معلقة', 'No pending pickup points');
  String get noPendingPointsHint =>
      _t('جميع النقاط المضافة تمت الموافقة عليها أو رفضها.',
          'All submitted points were approved or rejected.');
  String get showOnMap =>
      _t('عرض الموقع على الخريطة', 'Show on map');
  String get rejectPoint => _t('رفض النقطة', 'Reject point');
  String rejectPointConfirm(String name) =>
      _t('هل أنت متأكد من رفض النقطة "$name"؟',
          'Are you sure you want to reject "$name"?');
  String pointApproved(String name) =>
      _t('✅ تم الموافقة على النقطة "$name" بنجاح!',
          '✅ Point "$name" approved!');
  String pointRejected(String name) =>
      _t('🗑️ تم رفض النقطة "$name" بنجاح.',
          '🗑️ Point "$name" rejected.');
  String get underReview => _t('قيد المراجعة', 'Under review');

  String get systemOverview =>
      _t('نظرة عامة على النظام', 'System overview');
  String get totalUsers =>
      _t('إجمالي المستخدمين:', 'Total users:');
  String activeNow(int n) =>
      _t('نشط الآن: $n', 'Active now: $n');
  String get registeredStats =>
      _t('إحصائيات المسجلين', 'Registered stats');
  String get activeUsersNow =>
      _t('المستخدمين النشطين الآن', 'Users active now');
  String get driverRequestsStatus =>
      _t('حالة طلبات السائقين', 'Driver request status');
  String get pickupPointsSection =>
      _t('مواقف ونقاط التجمع', 'Pickup points');
  String get total => _t('الإجمالي', 'Total');
  String get dbConnectionFailed =>
      _t('تعذر الاتصال بقاعدة البيانات', 'Could not connect to database');
  String get retryRefresh => _t('إعادة التحديث', 'Refresh again');
  String get labelBus => _t('باص', 'Bus');
  String get labelService => _t('سرفيس', 'Service');
  String get labelBusCompany => _t('باص شركة', 'Company bus');
  String get labelBuses => _t('الباصات', 'Buses');
  String get labelPassengers => _t('الركاب', 'Passengers');
  String get labelServices => _t('السرافيس', 'Services');
  String get labelOthers => _t('أخرى', 'Others');
  String get labelPending => _t('المعلقون', 'Pending');
  String get labelVerified => _t('الموثقون', 'Verified');
  String get labelRejected => _t('المرفوضون', 'Rejected');
  String get labelApproved => _t('موثقة', 'Approved');
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
