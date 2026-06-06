import 'dart:async';
import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../logging/app_logger.dart';
import '../ui/app_feedback.dart';
import 'update_manifest.dart';

class AppUpdateService {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();

  static const String _cacheManifestKey = 'app_update_latest_manifest_v1';
  static const Duration _manifestTimeout = Duration(seconds: 8);
  static const Duration _checkCooldown = Duration(seconds: 25);
  static DateTime? _lastCheckAt;
  static bool _dialogOpen = false;

  Future<void> prefetchManifest() async {
    await getManifest(forceRefresh: true);
  }

  Future<UpdateManifest?> getManifest({bool forceRefresh = false}) async {
    final sourceUrl = AppConfig.updateManifestUrl.trim();
    if (sourceUrl.isEmpty || sourceUrl.contains('<')) {
      return _loadCachedManifest();
    }

    final prefs = await SharedPreferences.getInstance();
    if (!forceRefresh && _isCoolingDown()) {
      final cached = _tryParseManifest(prefs.getString(_cacheManifestKey));
      if (cached != null) return cached;
    }

    try {
      final uri = Uri.parse(sourceUrl);
      final response = await http.get(uri).timeout(_manifestTimeout);
      if (response.statusCode != 200) {
        throw StateError('Manifest returned ${response.statusCode}');
      }

      final manifest = _tryParseManifest(response.body);
      if (manifest == null) {
        throw const FormatException('Invalid latest.json format');
      }

      await prefs.setString(_cacheManifestKey, response.body);
      _lastCheckAt = DateTime.now();
      return manifest;
    } catch (error, stackTrace) {
      await AppLogger.error(
        'update.fetch_manifest',
        error,
        stackTrace: stackTrace,
      );
      return _loadCachedManifest();
    }
  }

  Future<UpdateDecision?> evaluateUpdate() async {
    final manifest = await getManifest(forceRefresh: true);
    if (manifest == null) return null;

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 0;
    final currentMajor = _majorVersionOf(packageInfo.version);

    final hasNewerVersion =
        manifest.latestVersionCode > currentVersionCode &&
        manifest.latestVersionName.isNotEmpty;
    if (!hasNewerVersion) return null;

    final forceByMinimum =
        currentVersionCode < manifest.minSupportedVersionCode;
    final forceByMajorJump = currentMajor < manifest.latestMajorVersion;
    final forceUpdate =
        manifest.forceUpdate || forceByMinimum || forceByMajorJump;

    final deviceAbi = await _resolveDeviceAbi();
    final download =
        manifest.selectDownload(deviceAbi) ??
        manifest.downloads.values.firstOrNull;
    if (download == null || download.url.isEmpty) {
      await AppLogger.error(
        'update.download_missing',
        StateError('No download URL available for ABI $deviceAbi'),
      );
      return null;
    }

    return UpdateDecision(
      manifest: manifest,
      download: download,
      deviceAbi: deviceAbi,
      isForceUpdate: forceUpdate,
      currentVersionName: packageInfo.version,
      currentVersionCode: currentVersionCode,
      reason: forceByMinimum
          ? UpdateReason.minSupported
          : (forceByMajorJump
                ? UpdateReason.majorUpgrade
                : UpdateReason.optional),
    );
  }

  Future<void> checkAndPrompt(BuildContext context) async {
    if (_dialogOpen) return;
    final decision = await evaluateUpdate();
    if (decision == null || !context.mounted) return;

    _dialogOpen = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: !decision.isForceUpdate,
        builder: (context) {
          return PopScope(
            canPop: !decision.isForceUpdate,
            child: AlertDialog(
              title: Text(
                decision.isForceUpdate
                    ? 'Update Wajib Tersedia'
                    : 'Update Tersedia',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Versi Anda ${decision.currentVersionName} (${decision.currentVersionCode})',
                  ),
                  Text(
                    'Versi terbaru ${decision.manifest.latestVersionName} (${decision.manifest.latestVersionCode})',
                  ),
                  const SizedBox(height: 10),
                  Text('Arsitektur: ${decision.deviceAbi}'),
                  Text(
                    'Ukuran download: ${_formatBytes(decision.download.sizeBytes)}',
                  ),
                  if (decision.manifest.releaseNotes.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Catatan rilis:',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(decision.manifest.releaseNotes),
                  ],
                ],
              ),
              actions: [
                if (!decision.isForceUpdate)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Nanti'),
                  ),
                FilledButton(
                  onPressed: () async {
                    final uri = Uri.tryParse(decision.download.url);
                    if (uri == null) {
                      if (context.mounted) {
                        AppFeedback.error(context, 'Link update tidak valid.');
                      }
                      return;
                    }

                    final opened = await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );
                    if (!opened && context.mounted) {
                      AppFeedback.error(context, 'Gagal membuka link update.');
                    }
                    if (!decision.isForceUpdate && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Update Sekarang'),
                ),
              ],
            ),
          );
        },
      );
    } finally {
      _dialogOpen = false;
    }
  }

  bool _isCoolingDown() {
    final now = DateTime.now();
    final last = _lastCheckAt;
    if (last == null) return false;
    return now.difference(last) < _checkCooldown;
  }

  Future<UpdateManifest?> _loadCachedManifest() async {
    final prefs = await SharedPreferences.getInstance();
    return _tryParseManifest(prefs.getString(_cacheManifestKey));
  }

  UpdateManifest? _tryParseManifest(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return UpdateManifest.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  int _majorVersionOf(String versionName) {
    final majorText = versionName.split('.').firstOrNull ?? '0';
    return int.tryParse(majorText) ?? 0;
  }

  Future<String> _resolveDeviceAbi() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return 'universal';
    }

    try {
      final info = await DeviceInfoPlugin().androidInfo;
      final abis = info.supportedAbis;
      if (abis.isNotEmpty) {
        return abis.first;
      }
    } catch (error, stackTrace) {
      await AppLogger.error('update.detect_abi', error, stackTrace: stackTrace);
    }
    return 'arm64-v8a';
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '-';
    const kilo = 1024;
    const mega = kilo * 1024;
    if (bytes >= mega) {
      return '${(bytes / mega).toStringAsFixed(1)} MB';
    }
    return '${(bytes / kilo).toStringAsFixed(1)} KB';
  }
}

class UpdateDecision {
  UpdateDecision({
    required this.manifest,
    required this.download,
    required this.deviceAbi,
    required this.isForceUpdate,
    required this.currentVersionName,
    required this.currentVersionCode,
    required this.reason,
  });

  final UpdateManifest manifest;
  final UpdateDownload download;
  final String deviceAbi;
  final bool isForceUpdate;
  final String currentVersionName;
  final int currentVersionCode;
  final UpdateReason reason;
}

enum UpdateReason { optional, majorUpgrade, minSupported }

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
