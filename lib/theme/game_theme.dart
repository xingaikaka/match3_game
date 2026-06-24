import 'package:flutter/material.dart';

class GameTheme {
  // 背景：深紫渐变
  static const Color bgTop    = Color(0xFF1A0533);
  static const Color bgBottom = Color(0xFF3B1278);

  // 棋盘格子
  static const Color cellBg       = Color(0x22FFFFFF);
  static const Color cellSelected = Color(0x66FFDD00);
  static const Color cellMatched  = Color(0x00FFFFFF);

  // UI 文字
  static const Color textBright  = Color(0xFFFFFFFF);
  static const Color textMuted   = Color(0xAAFFFFFF);
  static const Color accentGold  = Color(0xFFFFD700);
  static const Color accentGreen = Color(0xFF4ADE80);
  static const Color accentRed   = Color(0xFFFF6B6B);

  // 分数条
  static const Color barBg   = Color(0x33FFFFFF);
  static const Color barFill = Color(0xFF9B59B6);

  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgTop, bgBottom],
  );

  static BoxDecoration get boardDecoration => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(alpha: 0.10),
        Colors.white.withValues(alpha: 0.04),
      ],
    ),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
  );

  static TextStyle scoreLabel(BuildContext ctx) => const TextStyle(
    color: textMuted, fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 1,
  );

  static TextStyle scoreValue(BuildContext ctx) => const TextStyle(
    color: textBright, fontSize: 26, fontWeight: FontWeight.w800,
  );
}
