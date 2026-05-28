import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class NotificationService {
  static const String _oneSignalAppId = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: 'fc4e17b3-f7e6-4336-9537-67814918be90',
  );
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    if (_oneSignalAppId.isEmpty) {
      debugPrint(
        'OneSignal belum dikonfigurasi. Jalankan dengan --dart-define=ONESIGNAL_APP_ID=YOUR_APP_ID',
      );
      return;
    }

    OneSignal.Debug.setLogLevel(
      kDebugMode ? OSLogLevel.verbose : OSLogLevel.none,
    );
    OneSignal.initialize(_oneSignalAppId);
    _initialized = true;
    OneSignal.User.pushSubscription.addObserver((stateChanges) async {
      await _saveSubscriptionId(stateChanges.current.id);
    });

    await syncSettingsFromLocal();
    await _syncSubscriptionIdWithRetry();
  }

  static Future<bool> requestPermissionAndRegisterToken() async {
    if (!_initialized) {
      await initialize();
    }

    if (_oneSignalAppId.isEmpty) return false;

    final granted = await OneSignal.Notifications.requestPermission(true);
    if (granted) {
      await OneSignal.User.pushSubscription.optIn();
    } else {
      await OneSignal.User.pushSubscription.optOut();
    }

    await syncSettingsFromLocal();
    await _syncSubscriptionIdWithRetry();
    return granted;
  }

  static Future<void> syncSettingsFromLocal() async {
    if (!_initialized || _oneSignalAppId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final hasPrompted = prefs.getBool('notif_prompt_done') ?? false;
    final notifAllowed = prefs.getBool('notif_allowed') ?? false;
    final modePerCategory =
        prefs.getBool('notif_sound_mode_per_category') ?? false;
    final singleSoundEnabled =
        prefs.getBool('notif_sound_single_enabled') ??
        (prefs.getBool('notif_sound_allowed') ?? false);

    // Avoid forcing opt-out before user has made an explicit consent choice.
    if (hasPrompted) {
      if (notifAllowed) {
        await OneSignal.User.pushSubscription.optIn();
      } else {
        await OneSignal.User.pushSubscription.optOut();
      }
    }

    final tags = <String, String>{
      'notif_allowed': notifAllowed ? '1' : '0',
      'sound_mode_per_category': modePerCategory ? '1' : '0',
      'sound_default_enabled': singleSoundEnabled ? '1' : '0',
    };

    const categories = [
      'umum',
      'kesehatan',
      'infrastruktur',
      'keuangan',
      'acara',
    ];
    for (final category in categories) {
      final enabled =
          prefs.getBool('notif_sound_category_$category') ?? singleSoundEnabled;
      tags['sound_category_$category'] = enabled ? '1' : '0';
    }

    await OneSignal.User.addTags(tags);
    await _syncSubscriptionIdWithRetry();
  }

  static Future<void> _syncSubscriptionIdWithRetry() async {
    // OneSignal subscription id can be null briefly right after startup/permission.
    for (final delay in <Duration>[
      Duration.zero,
      const Duration(seconds: 2),
      const Duration(seconds: 5),
    ]) {
      if (delay != Duration.zero) {
        await Future<void>.delayed(delay);
      }
      final id = OneSignal.User.pushSubscription.id;
      if ((id ?? '').trim().isNotEmpty) {
        await _saveSubscriptionId(id);
        return;
      }
    }
  }

  static Future<void> _saveSubscriptionId(String? subscriptionId) async {
    final id = subscriptionId?.trim() ?? '';
    if (id.isEmpty) return;
    try {
      await Supabase.instance.client.from('device_tokens').insert({
        'token': id,
      });
    } catch (e) {
      debugPrint('Failed saving OneSignal subscription id: $e');
    }
  }
}
