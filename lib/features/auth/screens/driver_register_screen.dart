import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:jordan_bus_tracker_new/core/constants/bus_capacity.dart';
import 'package:jordan_bus_tracker_new/core/constants/user_roles.dart';
import 'package:jordan_bus_tracker_new/core/theme/app_theme.dart';
import 'package:jordan_bus_tracker_new/core/utils/validators.dart';
import 'package:jordan_bus_tracker_new/features/auth/providers/auth_provider.dart';
import 'package:jordan_bus_tracker_new/l10n/app_localizations.dart';

/// تسجيل حساب سائق — الأساس فقط:
/// الاسم، التواصل، رقم اللوحة (ترميز + رقم)، السعة، والإثباتات.
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
  final _plateCodeController = TextEditingController();
  final _plateNumberController = TextEditingController();
  final _imagePicker = ImagePicker();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  int? _selectedCapacity = BusCapacity.medium;

  XFile? _driverLicenseFile;
  XFile? _vehicleLicenseFile;
  XFile? _routeLicenseFile;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _plateCodeController.dispose();
    _plateNumberController.dispose();
    super.dispose();
  }

  InputDecoration _decoration({
    required String hint,
    IconData? icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      prefixIcon: icon == null
          ? null
          : Icon(icon, color: AppTheme.primaryColor, size: 22),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF5F8FC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.red.shade300),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.4),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13.5,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }

  Widget _sectionCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Future<void> _pickDocument({
    required void Function(XFile file) onPicked,
  }) async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;
    setState(() => onPicked(file));
  }

  Widget _documentTile({
    required String title,
    required String subtitle,
    required XFile? file,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    final hasFile = file != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasFile
            ? AppTheme.primaryColor.withValues(alpha: 0.06)
            : const Color(0xFFF5F8FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasFile
              ? AppTheme.primaryColor.withValues(alpha: 0.25)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasFile ? Icons.check_circle_rounded : Icons.upload_file_rounded,
            color: hasFile ? AppTheme.primaryColor : Colors.grey.shade500,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  hasFile ? (file.name) : subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onPick,
            child: Text(hasFile ? 'تغيير' : 'رفع'),
          ),
          if (hasFile)
            IconButton(
              onPressed: onClear,
              icon: Icon(Icons.close_rounded, color: Colors.grey.shade600),
              tooltip: 'إزالة',
            ),
        ],
      ),
    );
  }

  String _composeBusNumber() {
    final code = _plateCodeController.text.trim();
    final number = _plateNumberController.text.trim();
    if (code.isEmpty || number.isEmpty) return '';
    return '$code-$number';
  }

  Future<void> _uploadProofs(String uid) async {
    final storage = FirebaseStorage.instance;
    final base = 'driver_proofs/$uid';

    Future<void> putOne(String name, XFile? file) async {
      if (file == null) return;
      final ref = storage.ref('$base/$name');
      await ref.putFile(File(file.path));
    }

    await putOne('driver_license', _driverLicenseFile);
    await putOne('vehicle_license', _vehicleLicenseFile);
    await putOne('route_license', _routeLicenseFile);
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

    final busNumber = _composeBusNumber();
    if (busNumber.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('أدخل رقم اللوحة والترميز (مثال: 3569 و 14)'),
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

    if (_driverLicenseFile == null ||
        _vehicleLicenseFile == null ||
        _routeLicenseFile == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('ارفع رخصة السائق ورخصة المركبة ورخصة الخط'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final phone = _phoneController.text.trim();
      final auth = context.read<AuthProvider>();
      await auth.signUp(
        email: AppValidators.sanitizeEmail(_emailController.text),
        password: password,
        fullName: _nameController.text.trim(),
        phoneNumber: phone.isEmpty ? null : phone,
        userType: UserRoles.driver,
        busNumber: busNumber,
        capacity: _selectedCapacity,
      );

      final uid = auth.userId?.trim();
      if (uid != null && uid.isNotEmpty) {
        try {
          await _uploadProofs(uid);
        } catch (_) {
          if (mounted) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text(
                  'تم إنشاء الحساب، لكن تعذر رفع بعض الإثباتات. يمكنك إكمالها لاحقًا.',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }

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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FB),
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.16),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.drive_eta_rounded,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'أدخل بياناتك ورقم اللوحة والإثباتات لإنشاء الحساب.\n'
                        'المسار المعتمد سيُربط برقم الباص لاحقًا.',
                        style: TextStyle(
                          height: 1.45,
                          color: scheme.onSurface.withValues(alpha: 0.78),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _sectionCard(
                children: [
                  _sectionTitle('البيانات الشخصية', Icons.person_outline_rounded),
                  const SizedBox(height: 14),
                  _fieldLabel('الاسم'),
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'أدخل الاسم' : null,
                    decoration: _decoration(
                      hint: 'الاسم',
                      icon: Icons.person_outline,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _fieldLabel(l10n.phone),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: _decoration(
                      hint: '079 0000 000',
                      icon: Icons.phone_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _sectionCard(
                children: [
                  _sectionTitle('بيانات الحساب', Icons.lock_outline_rounded),
                  const SizedBox(height: 14),
                  _fieldLabel(l10n.email),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    textDirection: TextDirection.ltr,
                    validator: AppValidators.validateEmail,
                    decoration: _decoration(
                      hint: 'example@gmail.com',
                      icon: Icons.email_outlined,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _fieldLabel(l10n.password),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    textDirection: TextDirection.ltr,
                    validator: AppValidators.validatePassword,
                    decoration: _decoration(
                      hint: '••••••••',
                      icon: Icons.lock_outline,
                      suffix: IconButton(
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _fieldLabel(l10n.confirmPassword),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    textInputAction: TextInputAction.next,
                    textDirection: TextDirection.ltr,
                    decoration: _decoration(
                      hint: '••••••••',
                      icon: Icons.lock_outline,
                      suffix: IconButton(
                        onPressed: () => setState(
                          () => _obscureConfirmPassword =
                              !_obscureConfirmPassword,
                        ),
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _sectionCard(
                children: [
                  _sectionTitle('بيانات الباص', Icons.directions_bus_rounded),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _fieldLabel('رقم اللوحة'),
                            TextFormField(
                              controller: _plateNumberController,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              textDirection: TextDirection.ltr,
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'أدخل رقم اللوحة'
                                      : null,
                              decoration: _decoration(
                                hint: '3569',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _fieldLabel('الترميز'),
                            TextFormField(
                              controller: _plateCodeController,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              textDirection: TextDirection.ltr,
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'أدخل الترميز'
                                      : null,
                              decoration: _decoration(
                                hint: '14',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'مثال: رقم اللوحة 3569 — الترميز 14',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _fieldLabel('سعة الباص'),
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
                            child: Text(BusCapacity.label(c)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCapacity = v),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _sectionCard(
                children: [
                  _sectionTitle('الإثباتات', Icons.folder_open_rounded),
                  const SizedBox(height: 6),
                  Text(
                    'ارفع صورة واضحة لكل مستند مطلوب.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _documentTile(
                    title: 'رخصة السائق',
                    subtitle: 'اضغط لرفع صورة الرخصة',
                    file: _driverLicenseFile,
                    onPick: () => _pickDocument(
                      onPicked: (f) => _driverLicenseFile = f,
                    ),
                    onClear: () => setState(() => _driverLicenseFile = null),
                  ),
                  _documentTile(
                    title: 'رخصة المركبة',
                    subtitle: 'اضغط لرفع صورة رخصة المركبة',
                    file: _vehicleLicenseFile,
                    onPick: () => _pickDocument(
                      onPicked: (f) => _vehicleLicenseFile = f,
                    ),
                    onClear: () => setState(() => _vehicleLicenseFile = null),
                  ),
                  _documentTile(
                    title: 'رخصة الخط',
                    subtitle: 'اضغط لرفع صورة رخصة الخط',
                    file: _routeLicenseFile,
                    onPick: () => _pickDocument(
                      onPicked: (f) => _routeLicenseFile = f,
                    ),
                    onClear: () => setState(() => _routeLicenseFile = null),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
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
