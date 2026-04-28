import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/noise_record.dart';

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ── User document ──────────────────────────────────────────────────────────
  static Future<void> updateUserProfile({
    String? name,
    String? lastLocation,
  }) async {
    if (_uid == null) return;
    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (name != null) data['name'] = name;
    if (lastLocation != null) data['lastLocation'] = lastLocation;
    await _db.collection('users').doc(_uid).set(data, SetOptions(merge: true));
  }

  // ── Noise Records ──────────────────────────────────────────────────────────
  static CollectionReference<Map<String, dynamic>> get _recordsCol =>
      _db.collection('users').doc(_uid).collection('noise_records');

  static Future<void> addNoiseRecord(NoiseRecord record) async {
    if (_uid == null) return;
    await _recordsCol.add({
      'db': record.db,
      'location': record.location,
      'timestamp': Timestamp.fromDate(record.timestamp),
    });
  }

  static Future<List<NoiseRecord>> fetchNoiseRecords({int limit = 500}) async {
    if (_uid == null) return [];
    final snap = await _recordsCol
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((doc) {
      final d = doc.data();
      return NoiseRecord(
        db: (d['db'] as num).toDouble(),
        location: d['location'] as String? ?? '',
        timestamp: (d['timestamp'] as Timestamp).toDate(),
      );
    }).toList();
  }

  static Future<void> deleteAllNoiseRecords() async {
    if (_uid == null) return;
    final snap = await _recordsCol.get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ── Detected Quiet Spots ───────────────────────────────────────────────────
  static CollectionReference<Map<String, dynamic>> get _spotsCol =>
      _db.collection('users').doc(_uid).collection('quiet_spots');

  static Future<void> addQuietSpot(QuietSpot spot) async {
    if (_uid == null) return;
    await _spotsCol.add({
      'name': spot.name,
      'lat': spot.lat,
      'lng': spot.lng,
      'avgDb': spot.avgDb,
      'detectedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<List<QuietSpot>> fetchQuietSpots() async {
    if (_uid == null) return [];
    final snap = await _spotsCol.get();
    return snap.docs.map((doc) {
      final d = doc.data();
      return QuietSpot(
        name: d['name'] as String,
        lat: (d['lat'] as num).toDouble(),
        lng: (d['lng'] as num).toDouble(),
        avgDb: (d['avgDb'] as num).toDouble(),
      );
    }).toList();
  }

  static Future<void> deleteAllQuietSpots() async {
    if (_uid == null) return;
    final snap = await _spotsCol.get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
