import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Custom text field for authentication forms
class AuthTextField extends StatelessWidget {

  const AuthTextField({
    required this.controller, required this.label, required this.hint, super.key,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.enabled = true,
    this.maxLines = 1,
  });
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType keyboardType;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final bool enabled;
  final int maxLines;

  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          enabled: enabled,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: enabled ? Colors.grey[50] : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TextEditingController>('controller', controller));
    properties.add(StringProperty('label', label));
    properties.add(StringProperty('hint', hint));
    properties.add(DiagnosticsProperty<TextInputType>('keyboardType', keyboardType));
    properties.add(DiagnosticsProperty<bool>('obscureText', obscureText));
    properties.add(ObjectFlagProperty<String? Function(String?)?>.has('validator', validator));
    properties.add(DiagnosticsProperty<bool>('enabled', enabled));
    properties.add(IntProperty('maxLines', maxLines));
  }
}
