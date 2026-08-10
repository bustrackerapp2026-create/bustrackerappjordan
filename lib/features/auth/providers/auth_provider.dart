import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import 'package:jordan_bus_tracker_new/models/user_model.dart';
import 'package:jordan_bus_tracker_new/services/firestore_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  firebase_auth.User? _user;
  UserModel? _userData;
  bool _isLoading = false;
  StreamSubscription<UserModel?>? _userDataSubscription;

  firebase_auth.User? get user => _user;
  UserModel? get userData => _userData;
  bool get isLoggedIn => _user != null;
  bool get isLoading => _isLoading;
  String? get userId => _user?.uid;

  AuthProvider() {
    _auth.authStateChanges().listen((user) {
      _user = user;
      if (user != null) {
        _subscribeToUserData(user.uid);
      } else {
        _cancelUserDataSubscription();
        _userData = null;
        notifyListeners();
      }
    });
  }

  void _subscribeToUserData(String uid) {
    _cancelUserDataSubscription();
    _userDataSubscription = _firestoreService.getUserDataStream(uid).listen(
      (data) {
        _userData = data;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('خطأ في جلب بث بيانات المستخدم: $e');
      },
    );
  }

  void _cancelUserDataSubscription() {
    _userDataSubscription?.cancel();
    _userDataSubscription = null;
  }

  Future<void> refreshUserData() async {
    if (_user != null) {
      _subscribeToUserData(_user!.uid);
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

  /// تغيير كلمة المرور بعد التحقق من كلمة المرور الحالية (Firebase Auth).
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('⚠️ يجب تسجيل الدخول أولاً');
    }

    if (newPassword.length < 6) {
      throw Exception('⚠️ كلمة السر الجديدة يجب أن تكون 6 أحرف على الأقل');
    }

    if (currentPassword == newPassword) {
      throw Exception('⚠️ كلمة السر الجديدة يجب أن تختلف عن الحالية');
    }

    try {
      _setLoading(true);

      final credential = firebase_auth.EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e.code));
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('⚠️ فشل تغيير كلمة المرور: $e');
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
      _cancelUserDataSubscription();
      await _auth.signOut();
      _user = null;
      _userData = null;
      notifyListeners();
    } catch (e) {
      throw Exception('فشل تسجيل الخروج: $e');
    }
  }

  @override
  void dispose() {
    _cancelUserDataSubscription();
    super.dispose();
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
        return '⚠️ كلمة المرور الحالية غير صحيحة';
      case 'email-already-in-use':
        return '⚠️ هذا البريد مستخدم بالفعل';
      case 'invalid-email':
        return '⚠️ صيغة البريد الإلكتروني غير صحيحة';
      case 'weak-password':
        return '⚠️ كلمة السر ضعيفة جداً (يجب أن تكون 6 أحرف على الأقل)';
      case 'requires-recent-login':
        return '🔒 لأسباب أمنية، سجّل الخروج ثم الدخول مجدداً وحاول تغيير كلمة المرور';
      case 'too-many-requests':
        return '⚠️ تم إرسال العديد من الطلبات. حاول لاحقاً';
      default:
        return '⚠️ حدث خطأ: $code';
    }
  }
}
