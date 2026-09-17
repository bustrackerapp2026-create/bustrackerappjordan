import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:jordan_bus_tracker_new/core/constants/bus_capacity.dart';
import 'package:jordan_bus_tracker_new/core/constants/user_roles.dart';
import 'package:jordan_bus_tracker_new/core/theme/app_theme.dart';
import 'package:jordan_bus_tracker_new/core/utils/validators.dart';
import 'package:jordan_bus_tracker_new/features/auth/providers/auth_provider.dart';
import 'package:jordan_bus_tracker_new/l10n/app_localizations.dart';

/// تسجيل حساب سائق — الأساس فقط:
/// الاسم، التواصل، رقم الباص، السعة.
///
/// اختيار المسار المعتمد أُخرج من هذه المرحلة عمدًا:
/// المسار سيُربط لاحقًا برقم الباص وليس بالسائق.
class DriverRegisterScreen extends StatefulWidget {
  const DriverRegisterScreen({super.key});

  @override
  State<DriverRegisterScreen> createState() => _DriverRegisterScreenState();
}

class _DriverRegisterScreenState extends State<DriverRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _busNumberController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  int? _selectedCapacity = BusCapacity.medium;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _busNumberController.dispose();
    super.dispose();
  }

  InputDecoration _decoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppTheme.primaryColor),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();
    if (password != confirm) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.passwordMismatch),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final busNumber = _busNumberController.text.trim();
    if (busNumber.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('أدخل رقم الباص / السرفيس'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedCapacity == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('اختر سعة الباص'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final phone = _phoneController.text.trim();
      await context.read<AuthProvider>().signUp(
            email: AppValidators.sanitizeEmail(_emailController.text),
            password: password,
            fullName: _nameController.text.trim(),
            phoneNumber: phone.isEmpty ? null : phone,
            userType: UserRoles.driver,
            busNumber: busNumber,
            capacity: _selectedCapacity,
          );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${l10n.registerSuccess}\nبانتظار موافقة الأدمن على الحساب.',
          ),
          backgroundColor: Colors.green,
        ),
      );
      navigator.popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'تسجيل سائق',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.18),
                  ),
                ),
                child: const Text(
                  'أساس حساب السائق: البيانات الشخصية ورقم الباص.\n'
                  'المسار المعتمد سيُربط برقم الباص لاحقًا، وليس من شاشة التسجيل.',
                  style: TextStyle(height: 1.45),
                ),
              ),
              const SizedBox(height: 20),
              Text(l10n.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'أدخل الاسم' : null,
                decoration: _decoration(
                  hint: l10n.fullName,
                  icon: Icons.person_outline,
                ),
              ),
              const SizedBox(height: 16),
              Text(l10n.phone,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: _decoration(
                  hint: '079 0000 000',
                  icon: Icons.phone_outlined,
                ),
              ),
              const SizedBox(height: 16),
              Text(l10n.email,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: AppValidators.validateEmail,
                decoration: _decoration(
                  hint: 'example@gmail.com',
                  icon: Icons.email_outlined,
                ),
              ),
              const SizedBox(height: 16),
              Text(l10n.password,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                validator: AppValidators.validatePassword,
                decoration: _decoration(
                  hint: '••••••••',
                  icon: Icons.lock_outline,
                ).copyWith(
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(l10n.confirmPassword,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                textInputAction: TextInputAction.next,
                decoration: _decoration(
                  hint: '••••••••',
                  icon: Icons.lock_outline,
                ).copyWith(
                  suffixIcon: IconButton(
                    onPressed: () => setState(
                      () =>
                          _obscureConfirmPassword = !_obscureConfirmPassword,
                    ),
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'رقم الباص / السرفيس',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _busNumberController,
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'أدخل رقم الباص'
                    : null,
                decoration: _decoration(
                  hint: 'مثال: 12 أو سرفيس 45',
                  icon: Icons.confirmation_number_outlined,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'سعة الباص',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _selectedCapacity,
                decoration: _decoration(
                  hint: 'اختر السعة',
                  icon: Icons.event_seat_outlined,
                ),
                items: BusCapacity.options
                    .map(
                      (c) => DropdownMenuItem<int>(
                        value: c,
                        child: Text('$c راكب'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedCapacity = v),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          l10n.createAccountBtn,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
