import 'package:flutter/material.dart';

import '../constants/app_assets.dart';
import '../l10n/app_localizations.dart';
import 'wishes_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    // Animation Controller für Fade-Out und Pulsieren
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    // Fade-Out Animation
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
      ),
    );

    // Pulsierender Glow-Effekt
    _glowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _animationController.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _animationController.forward();
        }
      });

    _animationController.forward();

    // Nach 3 Sekunden mit Fade-Out zur Hauptseite navigieren
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _animationController.animateTo(1.0).then((_) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const WishesPage(),
                transitionDuration: const Duration(milliseconds: 500),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
              ),
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo mit pulsierendem Glow-Effekt
              AnimatedBuilder(
                animation: _glowAnimation,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00F2FF).withValues(alpha: _glowAnimation.value * 0.6),
                          blurRadius: 60 * _glowAnimation.value,
                          spreadRadius: 20 * _glowAnimation.value,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/icon/vibesbox-logo.png',
                      height: 200,
                      fit: BoxFit.contain,
                      color: null,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (context, error, stackTrace) {
                        return AppAssets.placeholder(height: 200);
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 48),
              // Neon-blauer Ladebalken
              SizedBox(
                width: 200,
                height: 4,
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return LinearProgressIndicator(
                      value: _animationController.value,
                      backgroundColor: const Color(0xFF00F2FF).withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        const Color(0xFF00F2FF).withValues(alpha: 0.8 + (_glowAnimation.value * 0.2)),
                      ),
                      minHeight: 4,
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              // Optionaler Text (falls lokalisiert)
              Text(
                localizations.loading,
                style: const TextStyle(
                  color: Color(0xFF00F2FF),
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


