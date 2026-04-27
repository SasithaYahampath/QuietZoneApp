import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/noise_record.dart';
import 'storage_service.dart';
import 'location_service.dart';
import 'notification_service.dart';

class AppController extends ChangeNotifier {
  // ── Monitoring ─────────────────────────────────────────────────────────────
  bool isMonitoring = false;
  double currentDb = 0; // -1 means “no microphone input”
  StreamSubscription<NoiseReading>? _noiseSub;
  NoiseMeter? _noiseMeter;

  // ── Location ───────────────────────────────────────────────────────────────
  LatLng? currentCoords;
  String currentLocationName = 'Detecting...';
  bool isLocating = false;

  // ── Alert ──────────────────────────────────────────────────────────────────
  DateTime? _highNoiseStart;
  bool alertActive = false;

  // ── History ────────────────────────────────────────────────────────────────
  List<NoiseRecord> records = [];
  Timer? _recordTimer;

  // ── Settings ───────────────────────────────────────────────────────────────
  AppSettings settings = const AppSettings();

  // ── Quiet spots ────────────────────────────────────────────────────────────
  final List<QuietSpot> quietSpots = const [
    QuietSpot(name: 'NSBM Library', lat: 6.9271, lng: 79.8612, avgDb: 45),
    QuietSpot(name: 'Module 2 Building', lat: 6.9255, lng: 79.8625, avgDb: 38),
    QuietSpot(
        name: 'NSBM Library – Floor 2', lat: 6.9260, lng: 79.8605, avgDb: 36),
  ];

  List<QuietSpot> detectedQuietSpots = [];

  // ── Init ───────────────────────────────────────────────────────────────────
  Future<void> init() async {
    await NotificationService.init();
    settings = await StorageService.loadSettings();
    records = await StorageService.loadRecords();
    detectedQuietSpots = await StorageService.loadDetectedQuietSpots();
    notifyListeners();
    await fetchLocation();
  }

  // ── Location ───────────────────────────────────────────────────────────────
  Future<void> fetchLocation() async {
    isLocating = true;
    notifyListeners();
    final pos = await LocationService.getCurrentLocation();
    if (pos != null) {
      currentCoords = pos;
      currentLocationName = await LocationService.reverseGeocode(pos);
      settings = settings.copyWith(lastLocationName: currentLocationName);
      await StorageService.saveSettings(settings);
    }
    isLocating = false;
    notifyListeners();
  }

  // ── Start monitoring with permission and no‑mic detection ──────────────────
  Future<void> startMonitoring() async {
    if (isMonitoring) return;

    // Request microphone permission
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      notifyListeners();
      throw Exception('Microphone permission denied');
    }

    _noiseMeter = NoiseMeter();
    try {
      _noiseSub = _noiseMeter!.noise.listen(
        (reading) {
          // Print to console so you can see real‑time values
          debugPrint('📢 db = ${reading.meanDecibel.toStringAsFixed(1)}');
          currentDb = reading.meanDecibel.clamp(20.0, 110.0);
          _checkAlert();
          notifyListeners();
        },
        onError: (error) {
          debugPrint('🔴 noise_meter error: $error');
          stopMonitoring();
        },
      );
      isMonitoring = true;
      notifyListeners();

      final startTime = DateTime.now();

      _recordTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (isMonitoring && currentDb > 0) {
          _addRecord(currentDb);
        }

        // After 3 seconds of no reading → likely no real mic (emulator, etc.)
        if (currentDb == 0 &&
            DateTime.now().difference(startTime).inSeconds > 3) {
          currentDb = -1; // special flag: no microphone available
          notifyListeners();
          _recordTimer?.cancel();
        }
      });

      await fetchLocation();
    } catch (e) {
      isMonitoring = false;
      notifyListeners();
      rethrow;
    }
  }

  void stopMonitoring() {
    _noiseSub?.cancel();
    _noiseSub = null;
    _recordTimer?.cancel();
    _recordTimer = null;
    isMonitoring = false;
    currentDb = 0;
    alertActive = false;
    _highNoiseStart = null;
    notifyListeners();
  }

  void toggleMonitoring() {
    if (isMonitoring) {
      stopMonitoring();
    } else {
      startMonitoring();
    }
  }

  // ── Alert ──────────────────────────────────────────────────────────────────
  void _checkAlert() {
    if (currentDb > settings.noiseLimit) {
      _highNoiseStart ??= DateTime.now();
      final elapsed = DateTime.now().difference(_highNoiseStart!);
      if (elapsed.inMinutes >= settings.alertDurationMin && !alertActive) {
        alertActive = true;
        if (settings.notificationsEnabled) {
          NotificationService.showNoiseAlert(
            db: currentDb,
            durationMin: settings.alertDurationMin,
            limit: settings.noiseLimit,
          );
        }
        notifyListeners();
      }
    } else {
      _highNoiseStart = null;
      if (alertActive) {
        alertActive = false;
        notifyListeners();
      }
    }
  }

  // ── History & auto‑detection ───────────────────────────────────────────────
  void _addRecord(double db) {
    records.add(NoiseRecord(
      timestamp: DateTime.now(),
      db: db,
      location: currentLocationName,
    ));
    if (records.length > 500) records.removeAt(0);
    StorageService.saveRecords(records);

    _maybeDetectQuietSpot(db);
    notifyListeners();
  }

  void _maybeDetectQuietSpot(double db) {
    const quietThreshold = 45.0;
    const minDistanceMeters = 100;

    if (db > quietThreshold) return;
    if (currentCoords == null) return;

    final myPos = currentCoords!;
    final alreadyExists = detectedQuietSpots.any((spot) {
      final spotPos = LatLng(spot.lat, spot.lng);
      final dist = const Distance().distance(myPos, spotPos);
      return dist < minDistanceMeters;
    });

    if (!alreadyExists) {
      final spot = QuietSpot(
        name: 'Quiet Spot #${detectedQuietSpots.length + 1}',
        lat: myPos.latitude,
        lng: myPos.longitude,
        avgDb: db,
      );
      detectedQuietSpots.add(spot);
      StorageService.saveDetectedQuietSpots(detectedQuietSpots);
      notifyListeners();
    }
  }

  Future<void> clearHistory() async {
    records.clear();
    await StorageService.clearRecords();
    notifyListeners();
  }

  // ── Settings ───────────────────────────────────────────────────────────────
  Future<void> updateSettings(AppSettings newSettings) async {
    settings = newSettings;
    await StorageService.saveSettings(settings);
    notifyListeners();
  }

  Future<void> clearDetectedSpots() async {
    detectedQuietSpots.clear();
    await StorageService.clearDetectedQuietSpots();
    notifyListeners();
  }

  // ── Stats ──────────────────────────────────────────────────────────────────
  Map<String, double?> get todayStats {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return _stats(records.where((r) => r.timestamp.isAfter(start)).toList());
  }

  Map<String, double?> get weekStats {
    final start = DateTime.now().subtract(const Duration(days: 7));
    return _stats(records.where((r) => r.timestamp.isAfter(start)).toList());
  }

  Map<String, double?> get locationStats {
    return _stats(
        records.where((r) => r.location == currentLocationName).toList());
  }

  Map<String, double?> _stats(List<NoiseRecord> list) {
    if (list.isEmpty) return {'min': null, 'max': null, 'avg': null};
    final dbs = list.map((r) => r.db).toList();
    return {
      'min': dbs.reduce((a, b) => a < b ? a : b),
      'max': dbs.reduce((a, b) => a > b ? a : b),
      'avg': dbs.reduce((a, b) => a + b) / dbs.length,
    };
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  static int dbColorValue(double db) {
    if (db > 85) return 0xFFEF4444;
    if (db > 70) return 0xFFF97316;
    return 0xFF22C55E;
  }

  static String dbStatusLabel(double db) {
    if (db > 85) return 'Very Loud 🔴';
    if (db > 70) return 'Noisy 🟠';
    if (db > 50) return 'Moderate 🟡';
    return 'Quiet 🟢';
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}
