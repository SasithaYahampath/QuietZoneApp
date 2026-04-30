import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/app_controller.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late double _noiseLimit;
  late int _alertDuration;
  late bool _notifEnabled;
  late bool _isDarkMode;
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final s = context.read<AppController>().settings;
      _noiseLimit = s.noiseLimit;
      _alertDuration = s.alertDurationMin;
      _notifEnabled = s.notificationsEnabled;
      _isDarkMode = s.isDarkMode;
      _isInitialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AppController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;

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
          const SizedBox(height: 16),

          // ── User profile card ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [const Color(0xFF2563EB), const Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.black : const Color(0xFF2563EB))
                      // ignore: deprecated_member_use
                      .withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white24,
                  child: Text(
                    (user?.displayName?.isNotEmpty == true
                            ? user!.displayName![0]
                            : user?.email?[0] ?? '?')
                        .toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? 'User',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.email ?? '',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.verified_rounded,
                    color: Colors.white70, size: 20),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Appearance ──────────────────────────────────────────────────
          _Card(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _Label('🌙 Dark Mode'),
                Switch(
                  value: _isDarkMode,
                  onChanged: (v) => setState(() => _isDarkMode = v),
                ),
              ],
            ),
          ]),

          const SizedBox(height: 16),

          // ── Noise Limit ──────────────────────────────────────────────────
          _Card(children: [
            const _Label('🔊 Noise Alert Limit'),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('30 dB',
                    style: TextStyle(
                        fontSize: 12,
                        color:
                            isDark ? Colors.white38 : const Color(0xFF94A3B8))),
                Text('${_noiseLimit.toStringAsFixed(0)} dB',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2563EB))),
                Text('80 dB',
                    style: TextStyle(
                        fontSize: 12,
                        color:
                            isDark ? Colors.white38 : const Color(0xFF94A3B8))),
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
              style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : const Color(0xFF64748B)),
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
                            : (isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        '$min min',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : (isDark
                                  ? Colors.white70
                                  : const Color(0xFF475569)),
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
            Text(
              'Receive alerts when noise exceeds your limit',
              style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : const Color(0xFF64748B)),
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
                  isDarkMode: _isDarkMode,
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
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '🔒 Privacy: Microphone is used only for real-time dB measurement. No audio is recorded or uploaded. Location is used only for place name and map display.',
              style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : const Color(0xFF475569)),
            ),
          ),

          const SizedBox(height: 16),

          // ── Sign Out ──────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    title: const Text('Sign Out',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Sign Out',
                            style: TextStyle(color: Color(0xFFEF4444))),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await AuthService.signOut();
                }
              },
              icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
              label: const Text(
                'Sign Out',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40)),
              ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFEEF2FF)),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
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
