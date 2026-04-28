import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/noise_record.dart';
import 'storage_service.dart';
import 'firestore_service.dart';
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

  // ── Routing ────────────────────────────────────────────────────────────────
  QuietSpot? spotToRoute;
  int currentTabIndex = 0;

  void setTabIndex(int index) {
    currentTabIndex = index;
    notifyListeners();
  }

  void triggerRoute(QuietSpot spot) {
    spotToRoute = spot;
    notifyListeners();
  }

  void clearRouteTrigger() {
    if (spotToRoute != null) {
      spotToRoute = null;
      notifyListeners();
    }
  }

  // ── History ────────────────────────────────────────────────────────────────
  List<NoiseRecord> records = [];
  Timer? _recordTimer;

  // ── Settings ───────────────────────────────────────────────────────────────
  AppSettings settings = const AppSettings();

  // ── Quiet spots (Sri Lanka Libraries) ──────────────────────────────────────
  final List<QuietSpot> quietSpots = const [
    // Colombo & Suburbs
    QuietSpot(name: 'Colombo Public Library', lat: 6.9116, lng: 79.8596, avgDb: 38),
    QuietSpot(name: 'National Library of Sri Lanka', lat: 6.9061, lng: 79.8686, avgDb: 35),
    QuietSpot(name: 'University of Colombo Library', lat: 6.9000, lng: 79.8614, avgDb: 40),
    QuietSpot(name: 'University of Moratuwa Library', lat: 6.7969, lng: 79.9018, avgDb: 42),
    QuietSpot(name: 'University of Kelaniya Library', lat: 6.9744, lng: 79.9161, avgDb: 40),
    QuietSpot(name: 'NSBM Green University Library', lat: 6.8211, lng: 80.0400, avgDb: 38), // NSBM Actual Coords
    QuietSpot(name: 'Gampaha Public Library', lat: 7.0911, lng: 79.9996, avgDb: 45),
    QuietSpot(name: 'Negombo Public Library', lat: 7.2111, lng: 79.8386, avgDb: 45),
    
    // Central Province
    QuietSpot(name: 'Kandy Public Library', lat: 7.2917, lng: 80.6358, avgDb: 42),
    QuietSpot(name: 'University of Peradeniya Library', lat: 7.2573, lng: 80.5970, avgDb: 35),
    QuietSpot(name: 'Nuwara Eliya Public Library', lat: 6.9708, lng: 80.7828, avgDb: 38),

    // Northern & Eastern
    QuietSpot(name: 'Jaffna Public Library', lat: 9.6644, lng: 80.0125, avgDb: 36),
    QuietSpot(name: 'Batticaloa Public Library', lat: 7.7142, lng: 81.6989, avgDb: 44),
    QuietSpot(name: 'Trincomalee Public Library', lat: 8.5711, lng: 81.2335, avgDb: 45),

    // Southern Province
    QuietSpot(name: 'Galle Public Library', lat: 6.0333, lng: 80.2167, avgDb: 42),
    QuietSpot(name: 'Matara Public Library', lat: 5.9496, lng: 80.5469, avgDb: 44),
    QuietSpot(name: 'University of Ruhuna Library', lat: 5.9381, lng: 80.5765, avgDb: 39),

    // Other Major Regions
    QuietSpot(name: 'Kurunegala Public Library', lat: 7.4851, lng: 80.3644, avgDb: 45),
    QuietSpot(name: 'Anuradhapura Public Library', lat: 8.3122, lng: 80.4131, avgDb: 42),
    QuietSpot(name: 'Ratnapura Public Library', lat: 6.6828, lng: 80.3992, avgDb: 45),
    QuietSpot(name: 'Badulla Public Library', lat: 6.9890, lng: 81.0558, avgDb: 43),
  ];

  List<QuietSpot> detectedQuietSpots = [];

  // ── Noisy spots (Factories & High Traffic) ─────────────────────────────────
  final List<QuietSpot> noisySpots = const [
    QuietSpot(name: 'Kelaniya Tire Factory', lat: 6.9600, lng: 79.9250, avgDb: 88),
    QuietSpot(name: 'Pettah Main Market', lat: 6.9381, lng: 79.8530, avgDb: 85),
    QuietSpot(name: 'Orugodawatta Intersection', lat: 6.9372, lng: 79.8785, avgDb: 86),
    QuietSpot(name: 'Sapugaskanda Refinery', lat: 6.9740, lng: 79.9400, avgDb: 90),
    QuietSpot(name: 'Biyagama Free Trade Zone', lat: 6.9535, lng: 79.9890, avgDb: 87),
    QuietSpot(name: 'Katunayake Airport Traffic', lat: 7.1685, lng: 79.8732, avgDb: 89),
    QuietSpot(name: 'Colombo Fort Railway Station', lat: 6.9338, lng: 79.8500, avgDb: 85),
    QuietSpot(name: 'Kelani Bridge Traffic', lat: 6.9550, lng: 79.8755, avgDb: 88),
  ];

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
    final record = NoiseRecord(
      timestamp: DateTime.now(),
      db: db,
      location: currentLocationName,
    );
    records.add(record);
    if (records.length > 500) records.removeAt(0);
    StorageService.saveRecords(records);
    
    // Sync to Firestore
    FirestoreService.addNoiseRecord(record);

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
      
      // Sync to Firestore
      FirestoreService.addQuietSpot(spot);
      
      notifyListeners();
    }
  }

  Future<void> clearHistory() async {
    records.clear();
    await StorageService.clearRecords();
    await FirestoreService.deleteAllNoiseRecords();
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
    await FirestoreService.deleteAllQuietSpots();
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
