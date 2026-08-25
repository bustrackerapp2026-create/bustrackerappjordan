import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:jordan_bus_tracker_new/core/constants/bus_capacity.dart';
import 'package:jordan_bus_tracker_new/core/constants/user_roles.dart';
import 'package:jordan_bus_tracker_new/core/theme/app_theme.dart';
import 'package:jordan_bus_tracker_new/core/utils/validators.dart';
import 'package:jordan_bus_tracker_new/features/auth/providers/auth_provider.dart';
import 'package:jordan_bus_tracker_new/l10n/app_localizations.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _busNumberController = TextEditingController();
  final _routeController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String _selectedUserType = UserRoles.passenger;
  int? _selectedCapacity = BusCapacity.medium;

  bool get _showDriverFields => UserRoles.isDriverLike(_selectedUserType);

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _busNumberController.dispose();
    _routeController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final email = AppValidators.sanitizeEmail(_emailController.text);
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final phoneNumber = _phoneController.text.trim();
    final busNumber = _busNumberController.text.trim();
    final route = _routeController.text.trim();

    if (password != confirmPassword) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.passwordMismatch),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_showDriverFields && _selectedCapacity == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('⚠️ اختر نوع الباص / عدد الركاب'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();

      await authProvider.signUp(
        email: email,
        password: password,
        fullName: name,
        phoneNumber: phoneNumber.isNotEmpty ? phoneNumber : null,
        userType: _selectedUserType,
        busNumber: _showDriverFields ? busNumber : null,
        route: _showDriverFields ? route : null,
        capacity: _showDriverFields ? _selectedCapacity : null,
      );

      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.registerSuccess),
          backgroundColor: Colors.green,
        ),
      );

      navigator.pop();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDriverSelected = _selectedUserType == UserRoles.driver;
    final isPassengerSelected = _selectedUserType == UserRoles.passenger;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryColor,
              AppTheme.primaryColor.withValues(alpha: 0.7),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.directions_bus,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.appNameEn,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.registerTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.fullName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameController,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return l10n.enterFullName;
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            hintText: 'Ahmad Mohammad',
                            prefixIcon: const Icon(
                              Icons.person_outline,
                              color: AppTheme.primaryColor,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: AppTheme.primaryColor,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          l10n.phone,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            hintText: '079 0000 000',
                            prefixIcon: const Icon(
                              Icons.phone_outlined,
                              color: AppTheme.primaryColor,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: AppTheme.primaryColor,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          l10n.email,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: AppValidators.validateEmail,
                          decoration: InputDecoration(
                            hintText: 'example@gmail.com',
                            prefixIcon: const Icon(
                              Icons.email_outlined,
                              color: AppTheme.primaryColor,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: AppTheme.primaryColor,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          l10n.password,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          enableSuggestions: false,
                          validator: AppValidators.validatePassword,
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: AppTheme.primaryColor,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(
                                  () => _obscurePassword = !_obscurePassword,
                                );
                              },
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: AppTheme.primaryColor,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          l10n.confirmPassword,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          enableSuggestions: false,
                          validator: (value) {
                            final requiredValidation =
                                AppValidators.validateRequired(
                              value,
                              fieldName: l10n.confirmPassword,
                            );
                            if (requiredValidation != null) {
                              return requiredValidation;
                            }
                            if (value != _passwordController.text) {
                              return l10n.passwordsDoNotMatch;
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: AppTheme.primaryColor,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(
                                  () => _obscureConfirmPassword =
                                      !_obscureConfirmPassword,
                                );
                              },
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: AppTheme.primaryColor,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          l10n.accountType,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: Text('🚗 ${l10n.driver}'),
                                selected: isDriverSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(
                                      () => _selectedUserType = UserRoles.driver,
                                    );
                                  }
                                },
                                selectedColor: AppTheme.primaryColor,
                                backgroundColor: Colors.grey.shade200,
                                labelStyle: TextStyle(
                                  color: isDriverSelected
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ChoiceChip(
                                label: Text('🚶 ${l10n.passenger}'),
                                selected: isPassengerSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(
                                      () => _selectedUserType =
                                          UserRoles.passenger,
                                    );
                                  }
                                },
                                selectedColor: AppTheme.primaryColor,
                                backgroundColor: Colors.grey.shade200,
                                labelStyle: TextStyle(
                                  color: isPassengerSelected
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isDriverSelected
                              ? l10n.driverPendingNote
                              : l10n.passengerReadyNote,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDriverSelected
                                ? Colors.orange.shade700
                                : Colors.green.shade700,
                          ),
                        ),
                        if (_showDriverFields) ...[
                          const SizedBox(height: 20),
                          Text(
                            l10n.driverInfoRequired,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _busNumberController,
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (_showDriverFields &&
                                  (value == null || value.trim().isEmpty)) {
                                return l10n.enterBusNumber;
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              hintText: l10n.busNumberHint,
                              prefixIcon: const Icon(
                                Icons.directions_bus,
                                color: AppTheme.primaryColor,
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: AppTheme.primaryColor,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _routeController,
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (_showDriverFields &&
                                  (value == null || value.trim().isEmpty)) {
                                return l10n.enterRoute;
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              hintText: l10n.routeHint,
                              prefixIcon: const Icon(
                                Icons.route,
                                color: AppTheme.primaryColor,
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: AppTheme.primaryColor,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'نوع الباص / عدد الركاب',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int>(
                            initialValue: _selectedCapacity,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(
                                Icons.event_seat_outlined,
                                color: AppTheme.primaryColor,
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: AppTheme.primaryColor,
                                  width: 2,
                                ),
                              ),
                            ),
                            items: BusCapacity.options
                                .map(
                                  (c) => DropdownMenuItem<int>(
                                    value: c,
                                    child: Text(BusCapacity.label(c)),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedCapacity = v),
                            validator: (value) {
                              if (_showDriverFields && value == null) {
                                return 'اختر نوع الباص';
                              }
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    l10n.createAccountBtn,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              l10n.alreadyHaveAccount,
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(width: 4),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.primaryColor,
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(80, 30),
                              ),
                              child: Text(
                                l10n.login,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
