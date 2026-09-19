import 'package:flutter/material.dart';
import 'colors.dart';

class AppTypography {
  AppTypography._();

  static const TextStyle display = TextStyle(
    fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.6, height: 1.1);
  static const TextStyle title = TextStyle(
    fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary);
  static const TextStyle heading = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary);
  static const TextStyle body = TextStyle(
    fontSize: 15, height: 1.4, color: AppColors.textPrimary);
  static const TextStyle secondary = TextStyle(
    fontSize: 14, height: 1.4, color: AppColors.textSecondary);
  static const TextStyle caption = TextStyle(
    fontSize: 12.5, color: AppColors.textSecondary);
  static const TextStyle code = TextStyle(
    fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: 8, color: AppColors.primaryDark);
}
