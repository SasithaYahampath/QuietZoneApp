import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'services/app_controller.dart';
import 'services/auth_service.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? firebaseError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    firebaseError = e.toString();
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppController()..init(),
      child: QuietZoneApp(firebaseError: firebaseError),
    ),
  );
}

class QuietZoneApp extends StatelessWidget {
  final String? firebaseError;
  const QuietZoneApp({super.key, this.firebaseError});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AppController>();
    return MaterialApp(
      title: 'Quiet Zone',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      themeMode: ctrl.settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: firebaseError != null
          ? FirebaseErrorScreen(error: firebaseError!)
          : const AuthGate(),
    );
  }
}

// ── Firebase Error Screen ──────────────────────────────────────────────────────
class FirebaseErrorScreen extends StatelessWidget {
  final String error;
  const FirebaseErrorScreen({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              const Text(
                'Firebase Setup Required',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your app needs the Firebase config files. Run this command in your project terminal:',
                style: TextStyle(
                    color: Color(0xFF94A3B8), fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: const SelectableText(
                  'dart pub global activate flutterfire_cli\nflutterfire configure --project=quietzone-4f8d0',
                  style: TextStyle(
                    color: Color(0xFF22C55E),
                    fontSize: 13,
                    fontFamily: 'monospace',
                    height: 1.8,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Then hot-restart the app. This generates\nlib/firebase_options.dart automatically.',
                style: TextStyle(
                    color: Color(0xFF64748B), fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0x22EF4444),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x44EF4444)),
                ),
                child: Text(
                  'Error: $error',
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Auth Gate ──────────────────────────────────────────────────────────────────
// Listens to Firebase auth state and shows either the app or the login screen.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        // Still connecting to Firebase
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }
        // Signed in → show main app
        if (snapshot.hasData) {
          return const MainShell();
        }
        // Not signed in → show login
        return const LoginScreen();
      },
    );
  }
}

// ── Splash Screen ──────────────────────────────────────────────────────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/logo.png', width: 80, height: 80),
            const SizedBox(height: 20),
            const Text(
              'Quiet Zone',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              color: Color(0xFF2563EB),
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Main Shell ─────────────────────────────────────────────────────────────────
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    HomeScreen(),
    MapScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  static const List<BottomNavigationBarItem> _navItems = [
    BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
    BottomNavigationBarItem(icon: Icon(Icons.map_rounded), label: 'Map'),
    BottomNavigationBarItem(
        icon: Icon(Icons.bar_chart_rounded), label: 'History'),
    BottomNavigationBarItem(
        icon: Icon(Icons.settings_rounded), label: 'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    // Listen for tab changes triggered by swiping (if any) or controller logic
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging &&
          _currentIndex != _tabController.index) {
        setState(() => _currentIndex = _tabController.index);
        context.read<AppController>().setTabIndex(_tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Sign Out',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF64748B))),
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
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final ctrl = context.watch<AppController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Sync tab controller with global state
    if (_tabController.index != ctrl.currentTabIndex) {
      _tabController.animateTo(ctrl.currentTabIndex);
      _currentIndex = ctrl.currentTabIndex;
    }

    final isVeryNoisy = ctrl.isVeryNoisy;

    return Scaffold(
      backgroundColor: isVeryNoisy
          ? (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2))
          : Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              bottom: 16,
              left: 16,
              right: 16,
            ),
            decoration: BoxDecoration(
              color: isVeryNoisy
                  ? const Color(0xFFEF4444)
                  : (isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFF2563EB)),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  // ignore: deprecated_member_use
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Image.asset('assets/logo.png', width: 28, height: 28),
                    const SizedBox(width: 8),
                    const Text(
                      'Sound Monitor',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                // User avatar + sign-out
                GestureDetector(
                  onTap: _confirmSignOut,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      // ignore: deprecated_member_use
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.white24,
                          child: Icon(Icons.person_rounded,
                              size: 16, color: Colors.white),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          user?.displayName?.split(' ').first ?? 'Account',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.logout_rounded,
                            color: Colors.white70, size: 14),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Tab pages ────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: _tabs,
            ),
          ),
        ],
      ),

      // ── Bottom nav ───────────────────────────────────────────────────
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          boxShadow: [
            BoxShadow(
              // ignore: deprecated_member_use
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, -2),
            )
          ],
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (i) {
              context.read<AppController>().setTabIndex(i);
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            selectedItemColor: const Color(0xFF2563EB),
            unselectedItemColor:
                isDark ? Colors.white38 : const Color(0xFF94A3B8),
            selectedFontSize: 11,
            unselectedFontSize: 11,
            elevation: 0,
            items: _navItems,
          ),
        ),
      ),
    );
  }
}
