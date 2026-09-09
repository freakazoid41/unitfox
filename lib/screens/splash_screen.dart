import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';
import '../theme.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeImage;
  late Animation<double> _fadeText;
  late Animation<double> _fadeLoader;
  late Animation<double> _logoMove;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _fadeImage = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );
    _fadeText = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.6, curve: Curves.easeOut),
      ),
    );
    _fadeLoader = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 0.7, curve: Curves.easeOut),
      ),
    );

    _logoMove = Tween<double>(begin: 0, end: -60).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.8, curve: Curves.easeInOut),
      ),
    );

    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppBrand.charcoal,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Centered logo
          Center(
            child: AnimatedBuilder(
              animation: _logoMove,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _logoMove.value),
                  child: FadeTransition(
                    opacity: _fadeImage,
                    child: Image.asset(
                      'assets/appicon.png',
                      width: 320,
                      height: 320,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.pets,
                        size: 120,
                        color: AppBrand.gradient[0],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Welcome text + loader at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 80,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: _fadeText,
                    child: Text(
                      ls(context).t('splash.welcome'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FadeTransition(
                    opacity: _fadeText,
                    child: Text(
                      ls(context).t('splash.subtitle'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  FadeTransition(
                    opacity: _fadeLoader,
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        color: AppBrand.gradient[0],
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
