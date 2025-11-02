import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../common/app_button.dart';
import '../../../providers/auth_provider.dart';
import '../../../common/app_textfield.dart'; // ✨ IMPORT AppTextField

class ForgotPasswordScreen extends StatefulWidget {
  // ✨ 1. ADD initialEmail FIELD
  final String? initialEmail;

  const ForgotPasswordScreen({
    super.key,
    this.initialEmail, // Accept initial email
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // ✨ 2. INITIALIZE CONTROLLER WITH PASSED EMAIL
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      emailController.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool error = false}) {
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

  Future<void> _sendResetEmail() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false); 

    try {
      await authProvider.sendPasswordResetEmail(emailController.text.trim());
      
      // Delay showing the snackbar until after the await for clean screen transition
      if (mounted) {
        _showSnackBar(
          "Password reset email sent! Check your inbox or spam folder.",
        );
      }

      // Delay a little so user sees the success message
      await Future.delayed(const Duration(seconds: 2));
      
      // Guard navigation check after delay
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          e.toString().replaceAll('Exception: ', ''),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Forgot Password")),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Enter your registered email",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // ✨ 3. REPLACE TextFormField with AppTextField for consistency
                    AppTextField(
                      controller: emailController,
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      validator: _validateEmail,
                      prefixIcon: const Icon(Icons.email),
                    ),
                    const SizedBox(height: 24),
                    // ✨ 4. USE AppButton's isLoading property
                    AppButton(
                      label: "Send Reset Link",
                      onPressed: _sendResetEmail,
                      isLoading: _loading,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}