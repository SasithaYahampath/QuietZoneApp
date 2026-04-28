import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../services/app_controller.dart';
import '../models/noise_record.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AppController>();
    final db = ctrl.currentDb;
    final color = Color(AppController.dbColorValue(db));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      child: Column(
        children: [
          // ── dB Meter card ─────────────────────────────────────────────────
          _DbMeterCard(db: db, color: color, ctrl: ctrl),
          const SizedBox(height: 16),

          // ── Action buttons ────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _showNearestSpots(context, ctrl);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              icon: const Icon(Icons.map_rounded, size: 18),
              label: const Text('Find Quieter Place',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 16),

          // ── Alert banner ──────────────────────────────────────────────────
          if (ctrl.alertActive)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(20),
                border: const Border(
                    left: BorderSide(color: Color(0xFFEF4444), width: 5)),
              ),
              child: Row(children: [
                const Text('⚠️', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Noise Alert!',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(
                        'Exceeded ${ctrl.settings.noiseLimit.toStringAsFixed(0)} dB for ${ctrl.settings.alertDurationMin} min',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ]),
            ),

          // ★ Auto‑detected spots count
          if (ctrl.detectedQuietSpots.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '🤖 ${ctrl.detectedQuietSpots.length} auto‑detected quiet spots',
                style: const TextStyle(
                    color: Color(0xFF7C3AED), fontWeight: FontWeight.w600),
              ),
            ),

          // ── Start / Stop button ───────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                try {
                  ctrl.toggleMonitoring();
                } catch (e) {
                  if (context.mounted) {
                    final message = e.toString().contains('permission')
                        ? '🎤 Microphone permission is required. Please allow it in Settings.'
                        : 'Microphone permission required. Please allow and retry.';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(message)),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ctrl.isMonitoring
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF22C55E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40)),
                elevation: 4,
              ),
              icon: Icon(ctrl.isMonitoring
                  ? Icons.stop_circle_rounded
                  : Icons.mic_rounded),
              label: Text(
                ctrl.isMonitoring ? 'Stop Monitoring' : 'Start Monitoring',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Quiet locations card ──────────────────────────────────────────
          _QuietLocationsCard(ctrl: ctrl),
        ],
      ),
    );
  }

  void _showNearestSpots(BuildContext context, AppController ctrl) {
    if (ctrl.currentCoords == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please update your location on the map first.')),
      );
      return;
    }

    // Combine all spots and calculate distance
    final allSpots = [...ctrl.quietSpots, ...ctrl.detectedQuietSpots];
    const distanceCalc = Distance();
    
    // Create a list of Map containing spot and its distance
    final spotsWithDistance = allSpots.map((spot) {
      final dist = distanceCalc.distance(
        ctrl.currentCoords!,
        LatLng(spot.lat, spot.lng),
      );
      return {'spot': spot, 'distance': dist};
    }).toList();

    // Sort by distance ascending
    spotsWithDistance.sort((a, b) => 
        (a['distance'] as double).compareTo(b['distance'] as double));

    // Take top 3
    final top3 = spotsWithDistance.take(3).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nearest Quiet Spots',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select a location to view the route on the map.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
            const SizedBox(height: 16),
            ...top3.map((item) {
              final spot = item['spot'] as QuietSpot;
              final dist = item['distance'] as double;
              final distStr = dist < 1000 
                  ? '${dist.toStringAsFixed(0)} m' 
                  : '${(dist / 1000).toStringAsFixed(1)} km';
              
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEFF6FF),
                  child: Icon(Icons.location_on_rounded, color: Color(0xFF2563EB), size: 20),
                ),
                title: Text(spot.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Distance: $distStr • ${spot.avgDb.toStringAsFixed(0)} dB average'),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                onTap: () {
                  Navigator.pop(ctx);
                  ctrl.triggerRoute(spot);
                  ctrl.setTabIndex(1);
                },
              );
            }),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

// ── dB Meter Card (updated to show “no mic” state) ──────────────────────────
class _DbMeterCard extends StatelessWidget {
  final double db; // -1 → no mic, 0 → idle, >0 → live reading
  final Color color;
  final AppController ctrl;

  const _DbMeterCard(
      {required this.db, required this.color, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final pct = db > 0 ? ((db - 20) / 90).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
        border: Border.all(color: const Color(0xFFEEF2FF)),
      ),
      child: Column(children: [
        // Big dB number
        Text(
          db == -1
              ? '🎤 ?'
              : db > 0
                  ? '${db.toStringAsFixed(0)} dB'
                  : '-- dB',
          style: TextStyle(
            fontSize: 76,
            fontWeight: FontWeight.w800,
            color: db == -1 ? Colors.grey : color,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        const Text('LIVE SOUND LEVEL',
            style: TextStyle(
                fontSize: 12, letterSpacing: 1.5, color: Color(0xFF64748B))),
        const SizedBox(height: 14),

        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 10,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 12),

        // Status text
        Text(
          db == -1
              ? 'No microphone detected\n(on emulator?)\nTry a real device'
              : db > 0
                  ? AppController.dbStatusLabel(db)
                  : ctrl.isMonitoring
                      ? 'Listening...'
                      : 'Tap Start to measure',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 10),

        // Location row
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.location_on_rounded,
              color: Color(0xFF2563EB), size: 16),
          const SizedBox(width: 4),
          ctrl.isLocating
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF2563EB)))
              : Flexible(
                  child: Text(
                    ctrl.currentLocationName,
                    style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
        ]),
      ]),
    );
  }
}

// ── Quiet Locations Card (unchanged) ─────────────────────────────────────────
class _QuietLocationsCard extends StatelessWidget {
  final AppController ctrl;
  const _QuietLocationsCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEEF2FF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Text('🔇', style: TextStyle(fontSize: 18)),
            SizedBox(width: 8),
            Text('Quiet Locations',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          ...ctrl.quietSpots.map((spot) => _SpotRow(spot: spot)),
        ],
      ),
    );
  }
}

class _SpotRow extends StatelessWidget {
  final QuietSpot spot;
  const _SpotRow({required this.spot});

  @override
  Widget build(BuildContext context) {
    final color = spot.avgDb < 50
        ? const Color(0xFF15803D)
        : spot.avgDb < 65
            ? const Color(0xFFCA8A04)
            : const Color(0xFFDC2626);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
              child: Text(spot.name,
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              '${spot.avgDb.toStringAsFixed(0)} dB',
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
