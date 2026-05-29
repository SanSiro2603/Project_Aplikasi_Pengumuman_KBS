import 'dart:convert';

class UpdateManifest {
  UpdateManifest({
    required this.latestVersionName,
    required this.latestVersionCode,
    required this.minSupportedVersionCode,
    required this.forceUpdate,
    required this.releaseNotes,
    required this.downloads,
    this.publishedAt,
  });

  final String latestVersionName;
  final int latestVersionCode;
  final int minSupportedVersionCode;
  final bool forceUpdate;
  final String releaseNotes;
  final DateTime? publishedAt;
  final Map<String, UpdateDownload> downloads;

  factory UpdateManifest.fromJson(Map<String, dynamic> json) {
    final rawDownloads = json['downloads'] as Map<String, dynamic>? ?? {};
    return UpdateManifest(
      latestVersionName: (json['latest_version_name'] ?? '').toString(),
      latestVersionCode: _asInt(json['latest_version_code']),
      minSupportedVersionCode: _asInt(json['min_supported_version_code']),
      forceUpdate: json['force_update'] == true,
      releaseNotes: (json['release_notes'] ?? '').toString(),
      publishedAt: json['published_at'] == null
          ? null
          : DateTime.tryParse(json['published_at'].toString()),
      downloads: rawDownloads.map(
        (key, value) =>
            MapEntry(key.toLowerCase(), UpdateDownload.fromJson(value)),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'latest_version_name': latestVersionName,
      'latest_version_code': latestVersionCode,
      'min_supported_version_code': minSupportedVersionCode,
      'force_update': forceUpdate,
      'release_notes': releaseNotes,
      'published_at': publishedAt?.toIso8601String(),
      'downloads': downloads.map((key, value) => MapEntry(key, value.toJson())),
    };
  }

  String toJsonString() => jsonEncode(toJson());

  UpdateDownload? selectDownload(String abi) {
    final normalized = abi.toLowerCase();
    if (downloads.containsKey(normalized)) {
      return downloads[normalized];
    }

    if (normalized.contains('arm64') && downloads.containsKey('arm64-v8a')) {
      return downloads['arm64-v8a'];
    }
    if (normalized.contains('armeabi') && downloads.containsKey('armeabi-v7a')) {
      return downloads['armeabi-v7a'];
    }
    if (normalized.contains('x86_64') && downloads.containsKey('x86_64')) {
      return downloads['x86_64'];
    }

    return downloads['arm64-v8a'] ?? downloads.values.firstOrNull;
  }

  int get latestMajorVersion {
    final rawMajor = latestVersionName.split('.').firstOrNull ?? '0';
    return int.tryParse(rawMajor) ?? 0;
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class UpdateDownload {
  UpdateDownload({
    required this.url,
    required this.sha256,
    required this.sizeBytes,
  });

  final String url;
  final String sha256;
  final int sizeBytes;

  factory UpdateDownload.fromJson(Object? json) {
    final map = json as Map<String, dynamic>? ?? const <String, dynamic>{};
    return UpdateDownload(
      url: (map['url'] ?? '').toString(),
      sha256: (map['sha256'] ?? '').toString(),
      sizeBytes: UpdateManifest._asInt(map['size_bytes']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'url': url,
      'sha256': sha256,
      'size_bytes': sizeBytes,
    };
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
