import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  static TextStyle heading1({Color? color}) => GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle heading2({Color? color}) => GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle heading3({Color? color}) => GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle subheading({Color? color}) => GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle bodyLarge({Color? color}) => GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle bodyMedium({Color? color}) => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color ?? AppColors.textSecondary,
      );

  static TextStyle bodySmall({Color? color}) => GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: color ?? AppColors.textSecondary,
      );

  static TextStyle label({Color? color}) => GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.textSecondary,
      );

  static TextStyle buttonText({Color? color}) => GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.white,
      );

  static TextStyle caption({Color? color}) => GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: color ?? AppColors.textSecondary,
      );

  static TextStyle toolTip({Color? color}) => GoogleFonts.poppins(
    fontSize: 8,
    fontWeight: FontWeight.w400,
    color: color ?? AppColors.textSecondary,
  );

  static TextStyle amount({Color? color}) => GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: color ?? AppColors.textPrimary,
      );
}
