import 'dart:async';

import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class AppFeedback {
  const AppFeedback._();

  static void success(BuildContext context, String message) {
    _show(
      context,
      message,
      backgroundColor: const Color(0xFF168A4D),
      icon: HugeIcons.strokeRoundedCheckmarkCircle02,
    );
  }

  static void error(BuildContext context, String message) {
    _show(
      context,
      message,
      backgroundColor: const Color(0xFFD14343),
      icon: HugeIcons.strokeRoundedAlert02,
      duration: const Duration(seconds: 4),
    );
  }

  static void warning(BuildContext context, String message) {
    _show(
      context,
      message,
      backgroundColor: const Color(0xFFB7791F),
      icon: HugeIcons.strokeRoundedAlert01,
    );
  }

  static void info(BuildContext context, String message) {
    _show(
      context,
      message,
      backgroundColor: const Color(0xFF2563A9),
      icon: HugeIcons.strokeRoundedInformationCircle,
    );
  }

  static void _show(
    BuildContext context,
    String message, {
    required Color backgroundColor,
    required IconData icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    unawaited(
      Flushbar<void>(
        messageText: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
        icon: Icon(icon, color: Colors.white, size: 22),
        duration: duration,
        flushbarPosition: FlushbarPosition.TOP,
        flushbarStyle: FlushbarStyle.FLOATING,
        margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        borderRadius: BorderRadius.circular(14),
        backgroundColor: backgroundColor,
        boxShadows: [
          BoxShadow(
            color: backgroundColor.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        animationDuration: const Duration(milliseconds: 350),
        isDismissible: true,
      ).show(context),
    );
  }
}
