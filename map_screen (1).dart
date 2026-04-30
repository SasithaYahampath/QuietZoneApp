import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../services/app_controller.dart';
import '../models/noise_record.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  List<LatLng>? _routePoints;
  bool _isLoadingRoute = false;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AppController>();
    final userPos = ctrl.currentCoords;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Center of Sri Lanka to view all libraries initially
    const defaultCenter = LatLng(7.8731, 80.7718);

    // Check if we need to route to a specific spot automatically
    if (ctrl.spotToRoute != null) {
      final spot = ctrl.spotToRoute!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ctrl.clearRouteTrigger();
        if (userPos != null) {
          final dest = LatLng(spot.lat, spot.lng);
          _mapController.move(dest, 16);
          _fetchAndShowRoute(origin: userPos, dest: dest);
        }
      });
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Text('🗺️', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text('Quiet Zones Map',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              height: 380,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: userPos ?? defaultCenter,
                  initialZoom: userPos != null ? 15 : 7.5,
                ),
                children: [
                  TileLayer(
                    urlTemplate: isDark
                        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                        : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'com.example.quiet_zone_app',
                  ),

                  // ── predefined quiet spots (green) ─────────────────────
                  MarkerLayer(
                    markers: ctrl.quietSpots.map((spot) {
                      final pos = LatLng(spot.lat, spot.lng);
                      return Marker(
                        point: pos,
                        width: 180,
                        height: 60,
                        alignment: Alignment.topCenter,
                        child: GestureDetector(
                          onTap: () {
                            _mapController.move(pos, 16);
                            _showSpotSheet(context, spot, isDetected: false);
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF22C55E),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF22C55E)
                                          // ignore: deprecated_member_use
                                          .withOpacity(0.4),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    )
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.volume_off_rounded,
                                        color: Colors.white, size: 12),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        spot.name,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              CustomPaint(
                                size: const Size(10, 6),
                                painter:
                                    _TrianglePainter(const Color(0xFF22C55E)),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  // ── auto‑detected quiet spots (purple) ────────────────
                  MarkerLayer(
                    markers: ctrl.detectedQuietSpots.map((spot) {
                      final pos = LatLng(spot.lat, spot.lng);
                      return Marker(
                        point: pos,
                        width: 180,
                        height: 60,
                        alignment: Alignment.topCenter,
                        child: GestureDetector(
                          onTap: () {
                            _mapController.move(pos, 16);
                            _showSpotSheet(context, spot, isDetected: true);
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C3AED),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF7C3AED)
                                          // ignore: deprecated_member_use
                                          .withOpacity(0.4),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    )
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.auto_awesome,
                                        color: Colors.white, size: 12),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        spot.name,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              CustomPaint(
                                size: const Size(10, 6),
                                painter:
                                    _TrianglePainter(const Color(0xFF7C3AED)),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  // ── noisy spots (red) ─────────────────────────────────
                  MarkerLayer(
                    markers: ctrl.noisySpots.map((spot) {
                      final pos = LatLng(spot.lat, spot.lng);
                      return Marker(
                        point: pos,
                        width: 180,
                        height: 60,
                        alignment: Alignment.topCenter,
                        child: GestureDetector(
                          onTap: () {
                            _mapController.move(pos, 16);
                            _showSpotSheet(context, spot, isDetected: false);
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFEF4444)
                                          // ignore: deprecated_member_use
                                          .withOpacity(0.4),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    )
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.warning_rounded,
                                        color: Colors.white, size: 12),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        spot.name,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              CustomPaint(
                                size: const Size(10, 6),
                                painter:
                                    _TrianglePainter(const Color(0xFFEF4444)),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  // ── user marker ───────────────────────────────────────
                  if (userPos != null)
                    MarkerLayer(markers: [
                      Marker(
                        point: userPos,
                        width: 44,
                        height: 44,
                        child: Stack(alignment: Alignment.center, children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: Color(0x301976D2),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1976D2),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [
                                BoxShadow(
                                    color: Color(0x551976D2),
                                    blurRadius: 8,
                                    spreadRadius: 2)
                              ],
                            ),
                          ),
                        ]),
                      ),
                    ]),

                  // ── route polyline ────────────────────────────────────
                  if (_routePoints != null && _routePoints!.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints!,
                          color: const Color(0xFF2563EB),
                          strokeWidth: 5,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(children: [
              _legendRow('🟢', 'Green = known quiet spots', isDark),
              _legendRow('🟣', 'Purple = auto‑detected spots', isDark),
              _legendRow('🔵', 'Blue dot = your live location', isDark),
              _legendRow('🔷', 'Blue line = route to selected spot', isDark),
            ]),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await ctrl.fetchLocation();
                if (ctrl.currentCoords != null) {
                  _mapController.move(ctrl.currentCoords!, 15);
                }
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                side: const BorderSide(color: Color(0xFF2563EB)),
              ),
              icon: ctrl.isLocating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF2563EB)))
                  : const Icon(Icons.my_location_rounded,
                      color: Color(0xFF2563EB), size: 18),
              label: const Text('Update My Location',
                  style: TextStyle(
                      color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── bottom sheet (modified to handle isDetected) ──────────────────────
  void _showSpotSheet(BuildContext context, QuietSpot spot,
      {required bool isDetected}) {
    final ctrl = context.read<AppController>();
    final origin = ctrl.currentCoords;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (isDetected) const Text('🤖 ', style: TextStyle(fontSize: 20)),
              Expanded(
                child: Text(spot.name,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black)),
              ),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDetected
                    ? const Color(0xFFEDE9FE)
                    : const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                '🔇 ${spot.avgDb.toStringAsFixed(0)} dB average',
                style: TextStyle(
                    color: isDetected
                        ? const Color(0xFF7C3AED)
                        : const Color(0xFF15803D),
                    fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isDetected
                  ? 'Auto‑detected by the app while monitoring.'
                  : 'Average noise level ${spot.avgDb.toStringAsFixed(0)} dB — ideal for studying or focused work.',
              style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : const Color(0xFF475569)),
            ),
            const SizedBox(height: 20),

            // route buttons
            if (origin != null)
              _isLoadingRoute
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _fetchAndShowRoute(
                                origin: origin,
                                dest: LatLng(spot.lat, spot.lng),
                              );
                            },
                            icon: const Icon(Icons.route_rounded),
                            label: const Text('Show Route'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (_routePoints != null)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                _clearRoute();
                                Navigator.pop(ctx);
                              },
                              icon: const Icon(Icons.clear_rounded),
                              label: const Text('Clear Route'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFEF4444),
                                side:
                                    const BorderSide(color: Color(0xFFEF4444)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30)),
                              ),
                            ),
                          ),
                      ],
                    )
            else
              const Text(
                'Location not available. Please update your location first.',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
          ],
        ),
      ),
    );
  }

  // ─── OSRM route fetching (unchanged) ──────────────────────────────────
  Future<void> _fetchAndShowRoute({
    required LatLng origin,
    required LatLng dest,
  }) async {
    setState(() => _isLoadingRoute = true);
    try {
      final url = 'https://router.project-osrm.org/route/v1/driving/'
          '${origin.longitude},${origin.latitude};'
          '${dest.longitude},${dest.latitude}'
          '?overview=full&geometries=geojson';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final route = data['routes'][0];
        final geometry = route['geometry'];
        final coordinates = geometry['coordinates'] as List;

        final points = coordinates.map((coord) {
          return LatLng(coord[1].toDouble(), coord[0].toDouble());
        }).toList();

        setState(() {
          _routePoints = points;
          _isLoadingRoute = false;
        });

        if (points.isNotEmpty && mounted) {
          final bounds = LatLngBounds.fromPoints(points);
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.all(50),
            ),
          );
        }
      } else {
        throw Exception('OSRM returned ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get route: $e')),
        );
      }
      setState(() => _isLoadingRoute = false);
    }
  }

  void _clearRoute() {
    setState(() => _routePoints = null);
  }

  Widget _legendRow(String emoji, String text, bool isDark) {
    return Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 14)),
      const SizedBox(width: 8),
      Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : const Color(0xFF475569)))),
    ]);
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    paint.color = color;
    final path = ui.Path();
    path.moveTo(0, 0);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width, 0);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
