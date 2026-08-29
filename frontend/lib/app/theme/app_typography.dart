import 'package:flutter/material.dart';

class AppTypography {
  const AppTypography._();

  static const fontFamily = 'NotoSansSC';

  static const displayLarge = TextStyle(
    fontSize: 48,
    height: 56 / 48,
    fontWeight: FontWeight.w700,
  );
  static const headlineLarge = TextStyle(
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w600,
  );
  static const headlineMedium = TextStyle(
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w600,
  );
  static const bodyLarge = TextStyle(
    fontSize: 18,
    height: 28 / 18,
    fontWeight: FontWeight.w400,
  );
  static const bodyMedium = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
  );
  static const bodySmall = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  );
  static const labelMedium = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
  );

  /// 根据系统文字缩放设置缩放字号，确保可访问性。
  /// [base] 为设计稿字号，[context] 用于读取 MediaQuery.textScaler。
  static double scaled(BuildContext context, double base) {
    return MediaQuery.textScalerOf(context).scale(base);
  }

  /// 返回应用了系统缩放的 TextStyle 副本。
  static TextStyle scaledStyle(BuildContext context, TextStyle base) {
    return base.copyWith(fontSize: scaled(context, base.fontSize ?? 14));
  }
}
