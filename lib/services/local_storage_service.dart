import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  static const String _keyEmail = 'saved_email';
  static const String _keyRememberMe = 'remember_me';

  Future<void> saveLoginData(String email, bool rememberMe) async {
    final prefs = await SharedPreferences.getInstance();
    if (rememberMe) {
      await prefs.setString(_keyEmail, email);
      await prefs.setBool(_keyRememberMe, true);
    } else {
      await prefs.remove(_keyEmail);
      await prefs.setBool(_keyRememberMe, false);
    }
  }

  Future<Map<String, dynamic>> getLoginData() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_keyEmail);
    final rememberMe = prefs.getBool(_keyRememberMe) ?? false;

    return {
      'email': email,
      'rememberMe': rememberMe,
    };
  }

  Future<void> clearLoginData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyEmail);
    await prefs.setBool(_keyRememberMe, false);
  }
}
