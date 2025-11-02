import 'package:flutter/material.dart';
import '../core/app_theme.dart';

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed; // nullable now
  final Color? color;
  final bool isLoading;

  const AppButton({
    required this.label,
    this.onPressed, // nullable
    this.color,
    this.isLoading = false,
    super.key, // FIX: Converted 'Key? key' to 'super.key'
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOut,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed, // null is allowed now
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? AppTheme.primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          shadowColor: Colors.black26,
        ),
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // Ensure text is visible on colored button
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}