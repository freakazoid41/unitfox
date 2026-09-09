import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Replicates the RNavNSheet look (full-width domed dock bar) without the
/// package: a 96px bar whose top edge rises to a center peak where the docked
/// menu button sits, rimmed by a thin brand-gradient glow. Zero dependencies.
/// The menu button opens the section grid; optional icons sit on the
/// shoulders — apartment switcher (left) and settings (right).
class BottomMenuBar extends StatefulWidget {
  final VoidCallback onMenuPressed;
  final VoidCallback? onSettingsPressed;
  final VoidCallback? onSwitcherPressed;

  const BottomMenuBar({
    super.key,
    required this.onMenuPressed,
    this.onSettingsPressed,
    this.onSwitcherPressed,
  });

  @override
  State<BottomMenuBar> createState() => _BottomMenuBarState();
}

class _BottomMenuBarState extends State<BottomMenuBar> {
  bool _pressed = false;
  bool _settingsPressed = false;
  bool _switcherPressed = false;

  void _tap(VoidCallback? action, ValueChanged<bool> setPressed) {
    if (action == null) return;
    HapticFeedback.selectionClick();
    setPressed(true);
    Future<void>.delayed(const Duration(milliseconds: 130), () {
      if (!mounted) return;
      setPressed(false);
      action();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      width: double.infinity,
      child: Stack(
        children: [
          // Bar body clipped to the domed top profile.
          ClipPath(
            clipper: _DockBarClipper(),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2A2A3E), AppBrand.charcoal],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          // Thin gradient glow rim along the top edge (drawn on top so the
          // center peak lights up under the docked button).
          CustomPaint(
            painter: _DockBarRimPainter([
              const Color(0xFF3E3E56),
              AppBrand.gradient[0],
              const Color(0xFF3E3E56),
            ]),
            child: const SizedBox.expand(),
          ),
          // Docked menu button straddling the center peak.
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 15),
              child: AnimatedScale(
                scale: _pressed ? 0.88 : 1.0,
                duration: const Duration(milliseconds: 130),
                curve: Curves.easeOutBack,
                child: GestureDetector(
                  onTap: () => _tap(widget.onMenuPressed,
                      (v) => setState(() => _pressed = v)),
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: AppBrand.gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppBrand.gradient[0].withValues(alpha: 0.55),
                          blurRadius: 18,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.menu, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),
          ),
          // Apartment switcher on the left shoulder of the dock.
          if (widget.onSwitcherPressed != null)
            Positioned(
              left: 34,
              bottom: 16,
              child: AnimatedScale(
                scale: _switcherPressed ? 0.85 : 1.0,
                duration: const Duration(milliseconds: 130),
                curve: Curves.easeOutBack,
                child: GestureDetector(
                  onTap: () => _tap(
                      widget.onSwitcherPressed,
                      (v) =>
                          setState(() => _switcherPressed = v)),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.apartment_outlined,
                      color: Colors.white.withValues(alpha: 0.75),
                      size: 26,
                    ),
                  ),
                ),
              ),
            ),
          // Settings icon on the right shoulder of the dock.
          if (widget.onSettingsPressed != null)
            Positioned(
              right: 34,
              bottom: 16,
              child: AnimatedScale(
                scale: _settingsPressed ? 0.85 : 1.0,
                duration: const Duration(milliseconds: 130),
                curve: Curves.easeOutBack,
                child: GestureDetector(
                  onTap: () => _tap(
                      widget.onSettingsPressed,
                      (v) =>
                          setState(() => _settingsPressed = v)),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.settings_outlined,
                      color: Colors.white.withValues(alpha: 0.75),
                      size: 26,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The RNavNSheet top profile: gentle shoulders that rise to a pointed center
/// peak (a 72px-wide dome at the top) where the dock button is seated.
Path _dockBarPath(Size size) {
  final w = size.width;
  const v = 10.0;
  return Path()
    ..moveTo(0, v * 3 + 5)
    ..quadraticBezierTo(w / 3 - 36, v * 3, w / 2 - 36, 30)
    ..quadraticBezierTo(w / 2, 0, w / 2 + 36, 30)
    ..quadraticBezierTo(w / 1.5 + 36, v * 3, w, v * 3 + 5);
}

class _DockBarClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => _dockBarPath(size)
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(covariant _DockBarClipper oldClipper) => false;
}

class _DockBarRimPainter extends CustomPainter {
  final List<Color> colors;

  const _DockBarRimPainter(this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(colors: colors)
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(_dockBarPath(size), paint);
  }

  @override
  bool shouldRepaint(covariant _DockBarRimPainter oldDelegate) =>
      oldDelegate.colors != colors;
}
