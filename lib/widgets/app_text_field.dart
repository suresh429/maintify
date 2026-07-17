import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

/// Universal input field for the entire app.
/// Uses OutlineInputBorder with a floating label — replaces all bare TextFormField usage.
class AppTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int maxLines;
  final String? helperText;
  final bool readOnly;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;

  /// Override the focus/active border color (e.g. pass `theme.primary` for role color).
  final Color? focusColor;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.validator,
    this.onChanged,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.helperText,
    this.readOnly = false,
    this.onTap,
    this.focusNode,
    this.textInputAction,
    this.focusColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBorderColor = isDark ? Colors.white : (focusColor ?? AppColors.blue);
    // Floating label is always white in dark mode for maximum readability
    final floatingLabelColor = isDark ? Colors.white : (focusColor ?? AppColors.blue);
    final borderColor = isDark ? Colors.white.withOpacity(0.35) : cs.outline;
    final fillColor = cs.surface;

    return TextFormField(
      controller: controller,
      validator: validator,
      onChanged: onChanged,
      keyboardType: maxLines > 1 ? TextInputType.multiline : keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      obscureText: obscureText,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      focusNode: focusNode,
      textInputAction: textInputAction,
      style: AppTextStyles.bodyLarge(color: cs.onSurface),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: AppTextStyles.bodyMedium(
            color: cs.onSurfaceVariant.withOpacity(0.6)),
        labelStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          color: cs.onSurfaceVariant,
        ),
        floatingLabelStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: floatingLabelColor,
        ),
        prefixIcon: prefixIcon != null
            ? IconTheme(
                data: IconThemeData(color: cs.onSurfaceVariant, size: 20),
                child: prefixIcon!)
            : null,
        suffixIcon: suffixIcon,
        helperText: helperText,
        helperStyle: AppTextStyles.caption(color: cs.onSurfaceVariant),
        helperMaxLines: 2,
        errorStyle: AppTextStyles.caption(color: AppColors.overdue),
        errorMaxLines: 2,
        filled: true,
        fillColor: fillColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: activeBorderColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.overdue),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.overdue, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
      ),
    );
  }
}
