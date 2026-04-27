import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late double _noiseLimit;
  late int _alertDuration;
  late bool _notifEnabled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = context.read<AppController>().settings;
    _noiseLimit = s.noiseLimit;
    _alertDuration = s.alertDurationMin;
    _notifEnabled = s.notificationsEnabled;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AppController>();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Text('⚙️', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text('Settings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 20),

          // ── Noise Limit ──────────────────────────────────────────────────
          _Card(children: [
            const _Label('🔊 Noise Alert Limit'),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('30 dB',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                Text('${_noiseLimit.toStringAsFixed(0)} dB',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2563EB))),
                const Text('80 dB',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              ],
            ),
            Slider(
              value: _noiseLimit,
              min: 30,
              max: 80,
              divisions: 50,
              activeColor: const Color(0xFF2563EB),
              onChanged: (v) => setState(() => _noiseLimit = v),
            ),
            Text(
              _noiseLimit < 45
                  ? 'Very sensitive — triggers in quiet environments'
                  : _noiseLimit < 60
                      ? 'Normal — good for offices'
                      : 'Low sensitivity — only loud environments',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ]),

          const SizedBox(height: 16),

          // ── Alert Duration ───────────────────────────────────────────────
          _Card(children: [
            const _Label('⏱️ Alert Duration'),
            const SizedBox(height: 12),
            Row(
              children: [3, 5, 10].map((min) {
                final selected = _alertDuration == min;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _alertDuration = min),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF2563EB)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        '$min min',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color:
                              selected ? Colors.white : const Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ]),

          const SizedBox(height: 16),

          // ── Notifications ────────────────────────────────────────────────
          _Card(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _Label('🔔 Notifications'),
                Switch(
                  value: _notifEnabled,
                  onChanged: (v) => setState(() => _notifEnabled = v),
                ),
              ],
            ),
            const Text(
              'Receive alerts when noise exceeds your limit',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ]),

          const SizedBox(height: 16),

          // ── Location ─────────────────────────────────────────────────────
          _Card(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _Label('📍 Current Location'),
                ctrl.isLocating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF2563EB)))
                    : TextButton(
                        onPressed: ctrl.fetchLocation,
                        child: const Text('Refresh',
                            style: TextStyle(
                                color: Color(0xFF2563EB), fontSize: 12)),
                      ),
              ],
            ),
            Text(
              ctrl.currentLocationName,
              style: const TextStyle(
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.w600,
                  fontSize: 14),
            ),
          ]),

          const SizedBox(height: 24),

          // ── Save ─────────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final newSettings = ctrl.settings.copyWith(
                  noiseLimit: _noiseLimit,
                  alertDurationMin: _alertDuration,
                  notificationsEnabled: _notifEnabled,
                );
                await ctrl.updateSettings(newSettings);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Settings saved!'),
                      duration: Duration(seconds: 2),
                      backgroundColor: Color(0xFF22C55E),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40)),
              ),
              child: const Text('Save Settings',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),

          const SizedBox(height: 16),

          // ── Privacy note ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '🔒 Privacy: Microphone is used only for real-time dB measurement. No audio is recorded or uploaded. Location is used only for place name and map display.',
              style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

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
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600));
}
