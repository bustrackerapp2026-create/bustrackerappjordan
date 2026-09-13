import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:jordan_bus_tracker_new/core/constants/user_roles.dart';
import 'package:jordan_bus_tracker_new/models/planned_route.dart';
import 'package:jordan_bus_tracker_new/models/user_model.dart';
import 'package:jordan_bus_tracker_new/services/driver_line_assignment_service.dart';
import 'package:jordan_bus_tracker_new/services/driver_route_request_service.dart';
import 'package:jordan_bus_tracker_new/services/firestore_service.dart';
import 'package:jordan_bus_tracker_new/services/live_tracking_service.dart';
import 'package:jordan_bus_tracker_new/services/transit_line_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final LiveTrackingService _liveTracking = LiveTrackingService();
  final DriverLineAssignmentService _driverLineAssignmentService =
      DriverLineAssignmentService();
  final DriverRouteRequestService _driverRouteRequestService =
      DriverRouteRequestService();

  firebase_auth.User? _user;
  UserModel? _userData;
  bool _isLoading = false;
  StreamSubscription<UserModel?>? _userDataSubscription;

  VoidCallback? onBeforeSignOut;

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
        if (data != null) {
          _userData = data;
          notifyListeners();
        } else if (_userData == null) {
          notifyListeners();
        }
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
      try {
        final fresh = await _firestoreService.getUserData(_user!.uid);
        if (fresh != null) {
          _userData = fresh;
          notifyListeners();
        }
      } catch (e) {
        debugPrint('refreshUserData: $e');
      }
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

  Future<String?> _resolveLineIdForRoute(String routeId) async {
    final id = routeId.trim();
    if (id.isEmpty) return null;

    final catalogRef = FirebaseFirestore.instance.collection('routeCatalog');
    final byId = await catalogRef.doc(id).get();
    if (byId.exists && byId.data() != null) {
      final lineId = byId.data()!['lineId']?.toString().trim();
      if (lineId != null && lineId.isNotEmpty) return lineId;
    }

    final snap = await catalogRef
        .where('routeId', isEqualTo: id)
        .where('status', isEqualTo: 'approved')
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;

    final lineId = snap.docs.first.data()['lineId']?.toString().trim();
    return lineId == null || lineId.isEmpty ? null : lineId;
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String userType,
    String? phoneNumber,
    String? busNumber,
    String? route,
    String? routeId,
    String? lineId,
    int? capacity,
    String? routeRequestLineName,
    String? routeRequestStartName,
    String? routeRequestMiddleName,
    String? routeRequestEndName,
    RouteDirection? routeRequestDirection,
  }) async {
    try {
      _setLoading(true);

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        final driver = UserRoles.isDriverLike(userType);
        final hasRouteRequest = driver &&
            routeRequestLineName?.trim().isNotEmpty == true &&
            routeRequestStartName?.trim().isNotEmpty == true &&
            routeRequestEndName?.trim().isNotEmpty == true &&
            routeRequestDirection != null;

        final newUser = UserModel(
          uid: credential.user!.uid,
          email: email,
          fullName: fullName,
          userType: userType,
          phoneNumber: phoneNumber ?? '',
          busNumber: busNumber ?? '',
          route: route ?? '',
          routeId: routeId,
          capacity: driver ? capacity : null,
          isVerified: false,
        );

        await _firestoreService.saveUserData(newUser);

        if (driver && routeId != null && routeId.trim().isNotEmpty) {
          final resolvedLineId = lineId?.trim().isNotEmpty == true
              ? lineId!.trim()
              : await _resolveLineIdForRoute(routeId);

          if (resolvedLineId == null || resolvedLineId.isEmpty) {
            throw const TransitLineServiceException(
              'تعذر تحديد الخط التشغيلي المرتبط بالمسار المختار.',
              code: 'driver-line-not-found',
            );
          }

          await _driverLineAssignmentService.requestAssignment(
            driverId: credential.user!.uid,
            routeId: routeId,
            lineId: resolvedLineId,
          );
        }

        if (hasRouteRequest) {
          await _driverRouteRequestService.createRequest(
            driverId: credential.user!.uid,
            lineName: routeRequestLineName!.trim(),
            startName: routeRequestStartName!.trim(),
            middleName: routeRequestMiddleName?.trim(),
            endName: routeRequestEndName!.trim(),
            direction: routeRequestDirection,
          );
        }

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

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null || user.email!.trim().isEmpty) {
      throw Exception('⚠️ يجب تسجيل الدخول بحساب بريد إلكتروني أولاً');
    }

    final providers = user.providerData.map((p) => p.providerId).toList();
    if (!providers.contains('password')) {
      throw Exception(
        '⚠️ هذا الحساب لا يستخدم كلمة مرور (مزوّد آخر). استخدم «نسيت كلمة المرور» من شاشة الدخول إن وُجد بريد.',
      );
    }

    final current = currentPassword.trim();
    final next = newPassword.trim();

    if (next.length < 6) {
      throw Exception('⚠️ كلمة السر الجديدة يجب أن تكون 6 أحرف على الأقل');
    }

    if (current == next) {
      throw Exception('⚠️ كلمة السر الجديدة يجب أن تختلف عن الحالية');
    }

    try {
      _setLoading(true);

      final credential = firebase_auth.EmailAuthProvider.credential(
        email: user.email!,
        password: current,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(next);
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e.code));
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('⚠️ فشل تغيير كلمة المرور: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOutAfterPasswordChange() async {
    try {
      await _goOfflineIfDriver();
      onBeforeSignOut?.call();
      _cancelUserDataSubscription();
      await _auth.signOut();
      _user = null;
      _userData = null;
      notifyListeners();
    } catch (e) {
      debugPrint('signOutAfterPasswordChange: $e');
      try {
        await _auth.signOut();
      } catch (_) {}
      _user = null;
      _userData = null;
      notifyListeners();
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e.code));
    }
  }

  Future<void> _goOfflineIfDriver() async {
    final uid = _user?.uid ?? _userData?.uid;
    if (uid == null || uid.isEmpty) return;

    if (!UserRoles.isDriverLike(_userData?.userType)) return;

    try {
      await _liveTracking.setDriverOnlineStatus(
        uid: uid,
        isOnline: false,
        isTripActive: false,
      );
    } catch (e) {
      debugPrint('تعذر إطفاء حالة السائق عند الخروج: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _goOfflineIfDriver();
      onBeforeSignOut?.call();

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
      case 'weak-password':
        return 'كلمة المرور ضعيفة جداً';
      case 'email-already-in-use':
        return 'البريد الإلكتروني مستخدم بالفعل';
      case 'invalid-email':
        return 'البريد الإلكتروني غير صحيح';
      case 'user-not-found':
        return 'المستخدم غير موجود';
      case 'wrong-password':
        return 'كلمة المرور غير صحيحة';
      case 'too-many-requests':
        return 'محاولات كثيرة. حاول لاحقاً';
      case 'user-disabled':
        return 'تم تعطيل هذا الحساب';
      default:
        return 'حدث خطأ أثناء المصادقة: $code';
    }
  }
}
