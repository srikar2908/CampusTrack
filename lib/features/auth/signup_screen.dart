import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/app_button.dart';
import '../../../common/app_textfield.dart';
import '../../../core/app_strings.dart';
import '../../../core/app_constants.dart';
import '../../../core/app_router.dart';
import '../../../providers/auth_provider.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final phoneController = TextEditingController();
  final officeController = TextEditingController();

  String selectedRole = AppConstants.userRole;
  bool loading = false;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    phoneController.dispose();
    officeController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool error = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Enter email';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w]{2,4}$');
    if (!emailRegex.hasMatch(value)) return 'Enter valid email';
    return null;
  }

  Future<void> _signup() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => loading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final success = await authProvider.register(
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        phoneNumber: phoneController.text.trim(),
        role: selectedRole,
        officeId: selectedRole == AppConstants.officeAdminRole
            ? officeController.text.trim()
            : null,
      );

      if (!mounted) return;

      if (success && authProvider.appUser != null) {
        AppRouter.navigateToDashboard(context);
      } else {
        _showSnackBar('Signup failed. Try again.');
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.signup)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // 👤 Full Name
              AppTextField(
                controller: nameController,
                label: 'Full Name',
                prefixIcon: const Icon(Icons.person),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Enter your full name' : null,
              ),
              const SizedBox(height: 12),

              // 📧 Email
              AppTextField(
                controller: emailController,
                label: AppStrings.email,
                prefixIcon: const Icon(Icons.email),
                validator: _validateEmail,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),

              // 🔒 Password with eye icon
              AppTextField(
                controller: passwordController,
                label: AppStrings.password,
                prefixIcon: const Icon(Icons.lock),
                obscureText: _obscurePassword,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter password';
                  if (v.length < 6) return 'Password must be at least 6 characters';
                  return null;
                },
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
              const SizedBox(height: 12),

              // 🔑 Confirm Password with eye icon
              AppTextField(
                controller: confirmPasswordController,
                label: 'Confirm Password',
                prefixIcon: const Icon(Icons.lock_outline),
                obscureText: _obscureConfirmPassword,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Confirm your password';
                  if (v != passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(
                        () => _obscureConfirmPassword = !_obscureConfirmPassword);
                  },
                ),
              ),
              const SizedBox(height: 12),

              // 📱 Phone Number
              AppTextField(
                controller: phoneController,
                label: AppStrings.phoneNumber,
                prefixIcon: const Icon(Icons.phone),
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter phone number';
                  if (v.length != 10 || !RegExp(r'^[0-9]+$').hasMatch(v)) {
                    return 'Enter valid 10-digit phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // 🏢 Role Dropdown
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                items: const [
                  DropdownMenuItem(
                    value: AppConstants.userRole,
                    child: Text('Student / Staff'),
                  ),
                  DropdownMenuItem(
                    value: AppConstants.officeAdminRole,
                    child: Text('Office Admin'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedRole = value);
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Select Role',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // 🏢 Office ID (only for admins)
              if (selectedRole == AppConstants.officeAdminRole)
                AppTextField(
                  controller: officeController,
                  label: 'Office ID',
                  prefixIcon: const Icon(Icons.business),
                  validator: (v) {
                    if (selectedRole == AppConstants.officeAdminRole &&
                        (v == null || v.isEmpty)) {
                      return 'Enter office ID';
                    }
                    return null;
                  },
                ),
              const SizedBox(height: 20),

              // 🔘 Signup Button
              AppButton(
                label: AppStrings.signup,
                onPressed: _signup,
                isLoading: loading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
