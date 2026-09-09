import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Small rounded country-flag chip drawn natively (no emoji, no assets) so it
/// renders identically on iOS, Android and Web.
class LanguageFlag extends StatelessWidget {
  final String code;
  const LanguageFlag({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 18,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: Colors.black26),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: CustomPaint(painter: _FlagPainter(code)),
      ),
    );
  }
}

class _FlagPainter extends CustomPainter {
  final String code;
  const _FlagPainter(this.code);

  static const _white = Color(0xFFFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    switch (code) {
      case 'en':
        _paintEn(canvas, size);
      case 'tr':
        _paintTr(canvas, size);
      case 'ru':
        _bands(
          canvas,
          size,
          horizontal: true,
          colors: const [
            Color(0xFFFFFFFF),
            Color(0xFF0039A6),
            Color(0xFFD52B1E)
          ],
        );
      case 'fr':
        _bands(
          canvas,
          size,
          horizontal: false,
          colors: const [Color(0xFF002395), _white, Color(0xFFED2939)],
        );
      case 'de':
        _bands(
          canvas,
          size,
          horizontal: true,
          colors: const [
            Color(0xFF000000),
            Color(0xFFDD0000),
            Color(0xFFFFCE00)
          ],
        );
      case 'hi':
        _paintIn(canvas, size);
    }
  }

  /// Three equal stripes, vertical (FR) or horizontal (DE/RU).
  static void _bands(
    Canvas canvas,
    Size size, {
    required bool horizontal,
    required List<Color> colors,
  }) {
    final paint = Paint();
    for (var i = 0; i < 3; i++) {
      paint.color = colors[i];
      final Rect rect;
      if (horizontal) {
        rect = Rect.fromLTWH(
            0, size.height * i / 3, size.width, size.height / 3);
      } else {
        rect = Rect.fromLTWH(
            size.width * i / 3, 0, size.width / 3, size.height);
      }
      canvas.drawRect(rect, paint);
    }
  }

  void _paintEn(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF012169));

    Paint stroke(Color c, double width) => Paint()
      ..color = c
      ..strokeWidth = width
      ..strokeCap = StrokeCap.butt;

    // Saint Andrew's cross (diagonals): white over blue, red inside white.
    canvas.drawLine(Offset(0, 0), Offset(w, h), stroke(_white, h * 0.24));
    canvas.drawLine(Offset(w, 0), Offset(0, h), stroke(_white, h * 0.24));
    canvas.drawLine(
        Offset(0, 0), Offset(w, h), stroke(const Color(0xFFC8102E), h * 0.09));
    canvas.drawLine(
        Offset(w, 0), Offset(0, h), stroke(const Color(0xFFC8102E), h * 0.09));

    // Saint George's cross: white then red.
    canvas.drawRect(
      Rect.fromCenter(center: center, width: w * 0.26, height: h),
      Paint()..color = _white,
    );
    canvas.drawRect(
      Rect.fromCenter(center: center, width: w, height: h * 0.48),
      Paint()..color = _white,
    );
    canvas.drawRect(
      Rect.fromCenter(center: center, width: w * 0.14, height: h),
      Paint()..color = const Color(0xFFC8102E),
    );
    canvas.drawRect(
      Rect.fromCenter(center: center, width: w, height: h * 0.26),
      Paint()..color = const Color(0xFFC8102E),
    );
  }

  void _paintTr(Canvas canvas, Size size) {
    final h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFE30A17));

    final cy = h / 2;
    final r = h * 0.30;
    final cx = size.width * 0.36;
    // Crescent: white disc with a red bite taken out of its right edge.
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = _white);
    canvas.drawCircle(
      Offset(cx + r * 0.45, cy),
      r * 0.80,
      Paint()..color = const Color(0xFFE30A17),
    );
    _star(
      canvas,
      Offset(size.width * 0.68, cy),
      h * 0.17,
      Paint()..color = _white,
    );
  }

  void _paintIn(Canvas canvas, Size size) {
    _bands(
      canvas,
      size,
      horizontal: true,
      colors: const [Color(0xFFFF9933), _white, Color(0xFF138808)],
    );
    // Ashoka Chakra (simplified to a navy ring).
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.height * 0.15,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF000080),
    );
  }

  static void _star(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final angle = -math.pi / 2 + i * math.pi / 5;
      final rad = i.isEven ? r : r * 0.42;
      final p =
          Offset(c.dx + rad * math.cos(angle), c.dy + rad * math.sin(angle));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close(), paint);
  }

  @override
  bool shouldRepaint(covariant _FlagPainter oldDelegate) =>
      oldDelegate.code != code;
}
