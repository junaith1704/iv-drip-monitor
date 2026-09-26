import 'package:flutter/material.dart';

/// Clinical medical-grade design system for the IV Drip Monitoring application.
class ClinicalTheme {
  // Primary Clinical Palette
  static const Color primaryBlue = Color(0xFF0284C7); // Clinical Sky/Navy Blue
  static const Color primaryDarkBlue = Color(0xFF0369A1);
  static const Color deepNavy = Color(0xFF0F172A); // Clinical text & header navy
  static const Color tealAccent = Color(0xFF0D9488); // Medical Teal

  // Neutral Foundations
  static const Color background = Color(0xFFF8FAFC); // Very soft medical grey-white
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color borderSubtle = Color(0xFFE2E8F0);
  static const Color borderMedium = Color(0xFFCBD5E1);

  // High Readability Typography Colors
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400

  // Status Colors (Color-coded device states)
  // 1. Running: Safe clinical emerald
  static const Color statusRunning = Color(0xFF16A34A);
  static const Color statusRunningBg = Color(0xFFECFDF5);
  static const Color statusRunningBorder = Color(0xFFA7F3D0);

  // 2. Stuck / Warning: Medical safety amber
  static const Color statusStuck = Color(0xFFD97706);
  static const Color statusStuckBg = Color(0xFFFFFBEB);
  static const Color statusStuckBorder = Color(0xFFFDE68A);

  // 3. Alarm / Safety Critical: High-contrast Alert Red
  static const Color statusAlarm = Color(0xFFDC2626);
  static const Color statusAlarmBg = Color(0xFFFEF2F2);
  static const Color statusAlarmBorder = Color(0xFFFECACA);

  // 4. Idle: Neutral Slate Grey
  static const Color statusIdle = Color(0xFF64748B);
  static const Color statusIdleBg = Color(0xFFF1F5F9);
  static const Color statusIdleBorder = Color(0xFFE2E8F0);

  // Helper method for resolving status color configuration
  static StatusColorConfig getStatusConfig(String status) {
    switch (status.toLowerCase()) {
      case 'running':
        return const StatusColorConfig(
          label: 'RUNNING',
          color: statusRunning,
          background: statusRunningBg,
          border: statusRunningBorder,
          icon: Icons.water_drop_rounded,
        );
      case 'stuck':
        return const StatusColorConfig(
          label: 'FLOW STOPPED / STUCK',
          color: statusStuck,
          background: statusStuckBg,
          border: statusStuckBorder,
          icon: Icons.warning_amber_rounded,
        );
      case 'alarm':
        return const StatusColorConfig(
          label: 'CRITICAL ALARM',
          color: statusAlarm,
          background: statusAlarmBg,
          border: statusAlarmBorder,
          icon: Icons.notifications_active_rounded,
        );
      case 'idle':
      default:
        return const StatusColorConfig(
          label: 'IDLE / AVAILABLE',
          color: statusIdle,
          background: statusIdleBg,
          border: statusIdleBorder,
          icon: Icons.pause_circle_outline_rounded,
        );
    }
  }

  // ThemeData constructor
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      primaryColor: primaryBlue,
      colorScheme: const ColorScheme.light(
        primary: primaryBlue,
        onPrimary: Colors.white,
        secondary: tealAccent,
        onSecondary: Colors.white,
        surface: surface,
        onSurface: textPrimary,
        error: statusAlarm,
        onError: Colors.white,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: surface,
        foregroundColor: deepNavy,
        iconTheme: IconThemeData(color: deepNavy),
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: deepNavy,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryBlue, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: statusAlarm),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: borderMedium),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class StatusColorConfig {
  final String label;
  final Color color;
  final Color background;
  final Color border;
  final IconData icon;

  const StatusColorConfig({
    required this.label,
    required this.color,
    required this.background,
    required this.border,
    required this.icon,
  });
}
