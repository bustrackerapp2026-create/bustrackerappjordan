import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

// ✅ استخدام Package Import الموحد
import 'package:jordan_bus_tracker_new/models/user_model.dart';
import 'package:jordan_bus_tracker_new/services/firestore_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  firebase_auth.User? _user;
  UserModel? _userData;
  bool _isLoading = false;

  firebase_auth.User? get user => _user;
  UserModel? get userData => _userData;
  bool get isLoggedIn => _user != null;
  bool get isLoading => _isLoading;
  String? get userId => _user?.uid;

  AuthProvider() {
    _auth.authStateChanges().listen((user) async {
      _user = user;
      if (user != null) {
        if (_userData?.uid != user.uid) {
          await _loadUserData(user.uid);
        }
      } else {
        _userData = null;
        notifyListeners();
      }
    });
  }

  Future<void> _loadUserData(String uid) async {
    try {
      _userData = await _firestoreService.getUserData(uid);
    } catch (e) {
      debugPrint('خطأ في جلب بيانات المستخدم: $e');
      _userData = null;
    }
    notifyListeners();
  }

  Future<void> refreshUserData() async {
    if (_user != null) {
      await _loadUserData(_user!.uid);
    }
  }

  Future<void> signIn(String email, String password) async {
    try {
      _setLoading(true);
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e.code));
    } finally {
      _setLoading(false);
    }
  }

  // ✅ دالة signUp تحتوي صراحة على المعامل phoneNumber
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String userType,
    String? phoneNumber,
    String? busNumber,
    String? route,
  }) async {
    try {
      _setLoading(true);

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        final newUser = UserModel(
          uid: credential.user!.uid,
          email: email,
          fullName: fullName,
          userType: userType,
          phoneNumber: phoneNumber ?? '',
          busNumber: busNumber ?? '',
          route: route ?? '',
          isVerified: false,
        );

        await _firestoreService.saveUserData(newUser);
        _userData = newUser;
        _user = credential.user;
        notifyListeners();
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e.code));
    } finally {
      _setLoading(false);
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e.code));
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _user = null;
      _userData = null;
      notifyListeners();
    } catch (e) {
      throw Exception('فشل تسجيل الخروج: $e');
    }
  }

  Future<void> sendEmailVerification() async {
    try {
      await _user?.sendEmailVerification();
    } catch (e) {
      throw Exception('فشل إرسال رابط التحقق: $e');
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return '⚠️ لم يتم العثور على مستخدم بهذا البريد';
      case 'wrong-password':
      case 'invalid-credential':
        return '⚠️ بيانات الدخول غير صحيحة';
      case 'email-already-in-use':
        return '⚠️ هذا البريد مستخدم بالفعل';
      case 'invalid-email':
        return '⚠️ صيغة البريد الإلكتروني غير صحيحة';
      case 'weak-password':
        return '⚠️ كلمة السر ضعيفة جداً (يجب أن تكون 6 أحرف على الأقل)';
      case 'too-many-requests':
        return '⚠️ تم إرسال العديد من الطلبات. حاول لاحقاً';
      default:
        return '⚠️ حدث خطأ: $code';
    }
  }
}
