import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
import 'permissions_gate.dart';
import 'screens/code_screen.dart';
import 'screens/login_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/shell.dart';
import 'screens/update_ui.dart';
import 'services/auth_service.dart';
import 'services/update_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: C.surface,
  ));
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.mastermusic.master_music.audio',
    androidNotificationChannelName: 'Master Music',
    androidNotificationOngoing: true,
  );
  await Supabase.initialize(url: Config.supabaseUrl, anonKey: Config.supabaseKey);
  runApp(const MasterMusicApp());
}

class MasterMusicApp extends StatelessWidget {
  const MasterMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Config.appName,
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      home: const _Splash(),
    );
  }
}

class _Splash extends StatefulWidget {
  const _Splash();

  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> {
  bool _done = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: _done
          ? const _AuthGate()
          : Scaffold(
              key: const ValueKey('splash'),
              body: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2A0F5C), C.bg, Color(0xFF4A0E3A)],
                  ),
                ),
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 1100),
                    curve: Curves.elasticOut,
                    builder: (context, v, child) => Opacity(
                      opacity: v.clamp(0.0, 1.0),
                      child: Transform.scale(scale: 0.5 + 0.5 * v, child: child),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(40),
                          boxShadow: [BoxShadow(color: C.pink.withAlpha(120), blurRadius: 60, offset: const Offset(0, 20))],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(40),
                          child: Image.asset('assets/logo.png', width: 140, height: 140),
                        ),
                      ),
                      const SizedBox(height: 26),
                      const Text('Master Music', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                      const SizedBox(height: 6),
                      const Text('Sua música, sem limites', style: TextStyle(color: C.muted)),
                    ]),
                  ),
                ),
              ),
            ),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  StreamSubscription<AuthState>? _sub;

  Future<void> _checkUpdate() async {
    final info = await UpdateService.check();
    if (info == null || !mounted) return;
    final cur = await UpdateService.currentVersion();
    if (!mounted) return;
    await showUpdateSheet(context, info, cur);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdate());
    AuthFlow.I.addListener(_rebuild);
    AuthFlow.I.handleOAuthReturn();
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((s) {
      if (s.event == AuthChangeEvent.signedIn) AuthFlow.I.handleOAuthReturn();
      if (s.event == AuthChangeEvent.passwordRecovery) AuthFlow.I.recovery = true;
      _rebuild();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    AuthFlow.I.removeListener(_rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    final flow = AuthFlow.I;
    if (flow.recovery && session != null && flow.pendingEmail == null) {
      return ResetPasswordScreen(onDone: () {});
    }
    if (flow.pendingEmail != null) return const CodeScreen();
    return session == null ? const LoginScreen() : const PermissionGate(child: Shell());
  }
}
