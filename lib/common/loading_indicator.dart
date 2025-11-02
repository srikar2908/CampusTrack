import 'package:flutter/material.dart';
import '../core/app_theme.dart';

class LoadingIndicator extends StatelessWidget {
  final double size;
  final Color? color;

  const LoadingIndicator({
    this.size = 50, 
    this.color, 
    super.key, // FIX: Converted 'Key? key' to 'super.key'
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        height: size,
        width: size,
        child: CircularProgressIndicator(
          strokeWidth: 4,
          color: color ?? AppTheme.primaryColor,
        ),
      ),
    );
  }
}