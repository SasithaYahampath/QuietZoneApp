import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/noise_record.dart';

class StorageService {
  static const _recordsKey = 'quietZoneRecords';
  static const _settingsKey = 'quietZoneSettings';
  static const _detectedSpotsKey = 'detectedQuietSpots'; // ★ new key

  // ────────── Records ─────────────────────────────────────────────
  static Future<List<NoiseRecord>> loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recordsKey);
    if (raw == null) return [];
    final List<dynamic> list = json.decode(raw);
    final records = list
        .map((e) => NoiseRecord.fromJson(e as Map<String, dynamic>))
        .toList();
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    return records.where((r) => r.timestamp.isAfter(cutoff)).toList();
  }

  static Future<void> saveRecords(List<NoiseRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed =
        records.length > 500 ? records.sublist(records.length - 500) : records;
    await prefs.setString(
        _recordsKey, json.encode(trimmed.map((r) => r.toJson()).toList()));
  }

  static Future<void> clearRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recordsKey);
  }

  // ────────── Settings ────────────────────────────────────────────
  static Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw == null) return const AppSettings();
    final map = json.decode(raw) as Map<String, dynamic>;
    return AppSettings.fromJson(map);
  }

  static Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, json.encode(settings.toJson()));
  }

  // ★ New: Detected quiet spots persistence
  static Future<List<QuietSpot>> loadDetectedQuietSpots() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_detectedSpotsKey);
    if (raw == null) return [];
    final List<dynamic> list = json.decode(raw);
    return list
        .map((e) => QuietSpot.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> saveDetectedQuietSpots(List<QuietSpot> spots) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _detectedSpotsKey, json.encode(spots.map((s) => s.toJson()).toList()));
  }

  static Future<void> clearDetectedQuietSpots() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_detectedSpotsKey);
  }
}

// ──────── AppSettings class (unchanged) ────────────────────────
class AppSettings {
  final double noiseLimit;
  final int alertDurationMin;
  final bool notificationsEnabled;
  final String lastLocationName;
  final bool isDarkMode; // ★ Added

  const AppSettings({
    this.noiseLimit = 50,
    this.alertDurationMin = 5,
    this.notificationsEnabled = true,
    this.lastLocationName = 'Detecting...',
    this.isDarkMode = false, // ★ Default to light
  });

  AppSettings copyWith({
    double? noiseLimit,
    int? alertDurationMin,
    bool? notificationsEnabled,
    String? lastLocationName,
    bool? isDarkMode, // ★ Added
  }) =>
      AppSettings(
        noiseLimit: noiseLimit ?? this.noiseLimit,
        alertDurationMin: alertDurationMin ?? this.alertDurationMin,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        lastLocationName: lastLocationName ?? this.lastLocationName,
        isDarkMode: isDarkMode ?? this.isDarkMode,
      );

  Map<String, dynamic> toJson() => {
        'noiseLimit': noiseLimit,
        'alertDurationMin': alertDurationMin,
        'notificationsEnabled': notificationsEnabled,
        'lastLocationName': lastLocationName,
        'isDarkMode': isDarkMode,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        noiseLimit: (json['noiseLimit'] as num?)?.toDouble() ?? 50,
        alertDurationMin: (json['alertDurationMin'] as int?) ?? 5,
        notificationsEnabled: (json['notificationsEnabled'] as bool?) ?? true,
        lastLocationName:
            (json['lastLocationName'] as String?) ?? 'Detecting...',
        isDarkMode: (json['isDarkMode'] as bool?) ?? false,
      );
}
