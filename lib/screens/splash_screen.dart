import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../widgets/equalizer.dart';
import 'home_screen.dart';

/// Abertura de 2,5 s com ícone, versão e créditos.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((i) {
      if (mounted) setState(() => _version = i.version);
    }).catchError((_) {});
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      ));
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    final short = MediaQuery.sizeOf(context).height < 500; // tela deitada
    final iconBox = short ? 84.0 : 120.0;
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.25),
            radius: 1.1,
            colors: [Color(0xFF3A2414), Color(0xFF110D0A)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: fade,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(flex: 3),
                ScaleTransition(
                  scale: Tween(begin: 0.85, end: 1.0).animate(
                      CurvedAnimation(parent: _c, curve: Curves.easeOutBack)),
                  child: Container(
                    width: iconBox,
                    height: iconBox,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF8A1F),
                      borderRadius: BorderRadius.circular(iconBox * 0.28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF8A1F).withValues(alpha: 0.45),
                          blurRadius: 40,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Icon(Icons.radio_rounded, size: iconBox * 0.6, color: const Color(0xFF16110D)),
                  ),
                ),
                SizedBox(height: short ? 12 : 26),
                Text(
                  'WebRádio',
                  style: TextStyle(fontSize: short ? 28 : 34, fontWeight: FontWeight.w900, letterSpacing: -0.8),
                ),
                const SizedBox(height: 10),
                const Equalizer(active: true, color: Color(0xFFFF8A1F), size: 26, bars: 5),
                const Spacer(flex: 4),
                if (_version.isNotEmpty)
                  Text('Versão $_version',
                      style: const TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 6),
                const Text('Criado por Luiz Alberto Cardoso',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                const Text('tecsattv@gmail.com',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
