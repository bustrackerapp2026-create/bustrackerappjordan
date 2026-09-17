import 'package:flutter/material.dart';

import 'register_role_screen.dart';

/// توافق خلفي: أي استدعاء قديم لـ RegisterScreen يوجّه لاختيار نوع الحساب.
class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RegisterRoleScreen();
  }
}
