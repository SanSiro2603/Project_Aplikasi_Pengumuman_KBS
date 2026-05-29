import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppLogger {
  static Future<void> info(
    String source,
    String message, {
    Map<String, dynamic>? context,
  }) async {
    if (kDebugMode) {
      debugPrint('[INFO][$source] $message ${context ?? {}}');
    }
    await _send(
      source: source,
      level: 'info',
      message: message,
      stackTrace: null,
      context: context,
    );
  }

  static Future<void> error(
    String source,
    Object error, {
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) async {
    if (kDebugMode) {
      debugPrint('[ERROR][$source] $error');
      if (stackTrace != null) {
        debugPrint(stackTrace.toString());
      }
    }
    await _send(
      source: source,
      level: 'error',
      message: error.toString(),
      stackTrace: stackTrace?.toString(),
      context: context,
    );
  }

  static Future<void> _send({
    required String source,
    required String level,
    required String message,
    required String? stackTrace,
    required Map<String, dynamic>? context,
  }) async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      await client.from('app_errors').insert({
        'source': source,
        'level': level,
        'message': message.length > 1000 ? message.substring(0, 1000) : message,
        'stack_trace': stackTrace == null
            ? null
            : (stackTrace.length > 4000
                  ? stackTrace.substring(0, 4000)
                  : stackTrace),
        'context': context ?? <String, dynamic>{},
        'user_id': user?.id,
      });
    } catch (_) {
      // Logging must never crash app flow.
    }
  }
}
