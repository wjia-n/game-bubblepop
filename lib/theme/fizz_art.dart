import 'dart:math';
import 'package:flutter/material.dart';
import 'fizz_themes.dart';

/// Soda-shop design helpers for Bubble Pop: warm woods, brass fittings,
/// ivory labels, physically glossy bubbles. No neon, no cyberpunk.
class Fizz {
  static const displayFont = 'serif';

  static TextStyle display(double size,
          {Color? color, FizzThemeDef? theme}) =>
      TextStyle(
        fontFamily: displayFont,
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? theme?.accentLight ?? const Color(0xFFF0D98A),
        letterSpacing: 1.2,
        shadows: const [
          Shadow(color: Color(0xFF1A0F08), offset: Offset(0, 2), blurRadius: 4),
        ],
      );

  static TextStyle body(double size, {Color? color, FizzThemeDef? theme}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color ?? theme?.ivory ?? const Color(0xFFF8F1E2),
        height: 1.35,
      );

  static TextStyle label(double size, {Color? color, FizzThemeDef? theme}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? theme?.accentLight ?? const Color(0xFFF0D98A),
        letterSpacing: 0.8,
      );

  static ThemeData theme([FizzThemeDef? t]) {
    t ??= FizzThemes.byId('sodaclassic');
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: t.bgDeep,
      colorScheme: ColorScheme(
        brightness: Brightness.dark,
        primary: t.accent,
        onPrimary: t.bgDeep,
        secondary: t.accentLight,
        onSecondary: t.bgDeep,
        surface: t.bgMid,
        onSurface: t.ivory,
        error: t.bubbleColors[0],
        onError: t.ivory,
      ),
      textTheme: TextTheme(
        displayLarge: display(34, theme: t),
        displayMedium: display(26, theme: t),
        titleLarge: display(22, theme: t),
        bodyLarge: body(16, theme: t),
        bodyMedium: body(14, theme: t),
        labelLarge: label(14, theme: t),
      ),
      dialogTheme: DialogThemeData(backgroundColor: t.bgMid),
    );
  }
}

/// Warm soda-fountain backdrop with a soft vignette, theme-aware.
class SodaBackdrop extends StatelessWidget {
  final Widget child;
  final FizzThemeDef? theme;
  const SodaBackdrop({super.key, required this.child, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? FizzThemes.byId('sodaclassic');
    return Container(
      decoration: BoxDecoration(color: t.bgDeep),
      child: CustomPaint(
        painter: _SodaPainter(t),
        child: child,
      ),
    );
  }
}

class _SodaPainter extends CustomPainter {
  final FizzThemeDef t;
  _SodaPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final vignette = RadialGradient(
      center: const Alignment(0, -0.3),
      radius: 1.2,
      colors: [
        t.bgMid.withValues(alpha: 0.6),
        t.bgDeep.withValues(alpha: 0.0),
        Colors.black.withValues(alpha: 0.55),
      ],
      stops: const [0.0, 0.55, 1.0],
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = vignette.createShader(Offset.zero & size),
    );
    // Faint rising-bubble specks, like carbonation.
    final rnd = Random(7);
    for (int i = 0; i < 26; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final r = 1.5 + rnd.nextDouble() * 3.5;
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color = t.ivory.withValues(alpha: 0.05)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A chunky wooden counter button with metal trim — physically pressable.
class FizzButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final double width;
  final double fontSize;
  final FizzThemeDef? theme;

  const FizzButton({
    super.key,
    required this.label,
    required this.onTap,
    this.width = 240,
    this.fontSize = 19,
    this.theme,
  });

  @override
  State<FizzButton> createState() => _FizzButtonState();
}

class _FizzButtonState extends State<FizzButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme ?? FizzThemes.byId('sodaclassic');
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap!();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: widget.width,
        padding: const EdgeInsets.symmetric(vertical: 14),
        transform: Matrix4.translationValues(0, _pressed ? 3 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [t.woodMid, t.woodDark],
          ),
          border: Border.all(color: t.accent, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              offset: Offset(0, _pressed ? 2 : 6),
              blurRadius: _pressed ? 4 : 10,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(widget.label,
            style: Fizz.label(widget.fontSize, theme: t)),
      ),
    );
  }
}

/// Brass toggle switch.
class FizzToggle extends StatelessWidget {
  final FizzThemeDef theme;
  final bool value;
  final ValueChanged<bool> onChanged;
  const FizzToggle(
      {super.key,
      required this.theme,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 58,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: value
              ? theme.accent.withValues(alpha: 0.85)
              : Colors.black.withValues(alpha: 0.4),
          border: Border.all(color: theme.accentLight, width: 1.5),
        ),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 24,
          height: 24,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [theme.ivory, theme.accentLight],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                offset: const Offset(0, 2),
                blurRadius: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Volume slider styled as a brass rail with a wooden bead.
class BeadSlider extends StatelessWidget {
  final FizzThemeDef theme;
  final double value;
  final ValueChanged<double> onChanged;
  const BeadSlider(
      {super.key,
      required this.theme,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 6,
        activeTrackColor: theme.accent,
        inactiveTrackColor: Colors.black.withValues(alpha: 0.45),
        thumbShape: _BeadThumb(theme: theme),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
      ),
      child: Slider(value: value, onChanged: onChanged),
    );
  }
}

class _BeadThumb extends SliderComponentShape {
  final FizzThemeDef theme;
  _BeadThumb({required this.theme});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size(26, 26);

  @override
  void paint(PaintingContext context, Offset center,
      {required Animation<double> activationAnimation,
      required Animation<double> enableAnimation,
      required bool isDiscrete,
      required TextPainter labelPainter,
      required RenderBox parentBox,
      required SliderThemeData sliderTheme,
      required TextDirection textDirection,
      required double value,
      required double textScaleFactor,
      required Size sizeWithOverflow}) {
    final c = context.canvas;
    c.drawCircle(
        center, 13, Paint()..color = Colors.black.withValues(alpha: 0.4));
    c.drawCircle(
      center,
      11,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          radius: 1.1,
          colors: [theme.woodMid, theme.woodDark],
        ).createShader(Rect.fromCircle(center: center, radius: 11)),
    );
    c.drawCircle(
      center,
      11,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = theme.accent
        ..strokeWidth = 2,
    );
  }
}

/// Setting row: label left, control right.
class SettingRow extends StatelessWidget {
  final FizzThemeDef theme;
  final String label;
  final Widget control;
  const SettingRow(
      {super.key,
      required this.theme,
      required this.label,
      required this.control});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Fizz.body(16, theme: theme))),
          control,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pseudo-3D bubble painting. Bubbles are physical candy marbles: drop shadow,
// radial-lit body, gloss highlight, rim, and per-style material detail.
// ---------------------------------------------------------------------------
void paintBubble(
  Canvas canvas,
  Offset c,
  double r,
  Color color,
  int style, {
  double alpha = 1.0,
  double wobble = 0.0,
}) {
  final rnd = Random(color.value ^ style);
  // Drop shadow.
  canvas.drawCircle(
    c + Offset(r * 0.08, r * 0.14),
    r,
    Paint()..color = Colors.black.withValues(alpha: 0.30 * alpha),
  );
  // Body: radial light from top-left.
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.38, -0.42),
        radius: 1.15,
        colors: [
          _lighten(color, 0.42).withValues(alpha: alpha),
          color.withValues(alpha: alpha),
          _darken(color, 0.32).withValues(alpha: alpha),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: r)),
  );

  // Per-style material detail.
  switch (style) {
    case 1: // Candy Swirl
      for (int i = 0; i < 3; i++) {
        final a0 = rnd.nextDouble() * 2 * pi;
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r * (0.55 + i * 0.14)),
          a0,
          2.2,
          false,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.35 * alpha)
            ..strokeWidth = r * 0.16
            ..strokeCap = StrokeCap.round,
        );
      }
    case 2: // Marble veins
      for (int i = 0; i < 4; i++) {
        final p = Path()
          ..moveTo(c.dx - r + rnd.nextDouble() * r, c.dy - r * 0.6)
          ..quadraticBezierTo(
            c.dx + (rnd.nextDouble() - 0.5) * r,
            c.dy,
            c.dx - r + rnd.nextDouble() * r * 2,
            c.dy + r * 0.6,
          );
        canvas.drawPath(
          p,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.28 * alpha)
            ..strokeWidth = r * 0.09
            ..style = PaintingStyle.stroke,
        );
      }
    case 3: // Pearl nacre
      canvas.drawCircle(
        c + Offset(r * 0.12, r * 0.1),
        r * 0.72,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.22 * alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    case 4: // Wooden bead grain
      for (int i = 0; i < 5; i++) {
        final y = c.dy - r * 0.7 + i * r * 0.35;
        canvas.drawLine(
          Offset(c.dx - r * 0.85, y + (rnd.nextDouble() - 0.5) * 3),
          Offset(c.dx + r * 0.85, y + (rnd.nextDouble() - 0.5) * 3),
          Paint()
            ..color = Colors.black.withValues(alpha: 0.18 * alpha)
            ..strokeWidth = 1.6,
        );
      }
    case 5: // Frosted ice
      for (int i = 0; i < 14; i++) {
        final a = rnd.nextDouble() * 2 * pi;
        final d = rnd.nextDouble() * r * 0.8;
        canvas.drawCircle(
          c + Offset(cos(a) * d, sin(a) * d),
          r * 0.06,
          Paint()..color = Colors.white.withValues(alpha: 0.5 * alpha),
        );
      }
    case 6: // Metallic band
      canvas.drawRect(
        Rect.fromCenter(
            center: c, width: r * 2 * 0.98, height: r * 0.52),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.55 * alpha),
              Colors.white.withValues(alpha: 0.08 * alpha),
              Colors.black.withValues(alpha: 0.25 * alpha),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    case 7: // Jelly — extra squish highlight
      final wr = r * (1 + wobble * 0.12);
      canvas.drawOval(
        Rect.fromCenter(
            center: c + Offset(-r * 0.28, -r * 0.34),
            width: wr * 0.9,
            height: wr * 0.55),
        Paint()..color = Colors.white.withValues(alpha: 0.42 * alpha),
      );
    case 8: // Rainbow Gum
      const rainbow = [
        Color(0xFFE23E57),
        Color(0xFFFF8C42),
        Color(0xFFFFC93C),
        Color(0xFF4CC96F),
        Color(0xFF3FA7E8),
      ];
      for (int i = 0; i < rainbow.length; i++) {
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r * (0.92 - i * 0.15)),
          -0.6,
          1.9,
          false,
          Paint()
            ..color = rainbow[i].withValues(alpha: 0.55 * alpha)
            ..strokeWidth = r * 0.13
            ..strokeCap = StrokeCap.round,
        );
      }
    case 9: // Obsidian — dark glass, silver rim
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.38, -0.42),
            radius: 1.15,
            colors: [
              _lighten(color, 0.18).withValues(alpha: alpha),
              _darken(color, 0.45).withValues(alpha: alpha),
              Colors.black.withValues(alpha: alpha),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
  }

  // Inner ambient occlusion at the bottom.
  canvas.drawArc(
    Rect.fromCircle(center: c, radius: r * 0.94),
    0.5,
    pi - 1.0,
    false,
    Paint()
      ..color = Colors.black.withValues(alpha: 0.22 * alpha)
      ..strokeWidth = r * 0.16
      ..strokeCap = StrokeCap.round,
  );
  // Gloss highlight (top-left).
  canvas.drawOval(
    Rect.fromCenter(
        center: c + Offset(-r * 0.32, -r * 0.38),
        width: r * 0.62,
        height: r * 0.4),
    Paint()..color = Colors.white.withValues(alpha: 0.55 * alpha),
  );
  canvas.drawCircle(
    c + Offset(r * 0.34, -r * 0.42),
    r * 0.10,
    Paint()..color = Colors.white.withValues(alpha: 0.35 * alpha),
  );
  // Rim.
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.black.withValues(alpha: 0.28 * alpha)
      ..strokeWidth = max(1.0, r * 0.07),
  );
  canvas.drawCircle(
    c,
    r * 0.96,
    Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withValues(alpha: 0.22 * alpha)
      ..strokeWidth = max(0.8, r * 0.045),
  );
}

Color _lighten(Color c, double amt) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness + amt).clamp(0.0, 1.0)).toColor();
}

Color _darken(Color c, double amt) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness - amt).clamp(0.0, 1.0)).toColor();
}

/// Draws the wooden/brass launcher at [center] rotated to [aimAngle].
void paintLauncher(Canvas canvas, Offset center, double r, double aimAngle,
    int style, FizzThemeDef t) {
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(aimAngle + pi / 2);
  final bodyW = r * 2.6;
  final bodyH = r * 2.2;
  final body = Rect.fromCenter(
      center: Offset(0, -r * 0.4), width: bodyW, height: bodyH);

  // Style palettes.
  final List<List<Color>> palettes = [
    [t.woodMid, t.woodDark, t.accent], // Wooden Tap
    [t.accent, t.accentDark, t.accentLight], // Brass Cannon
    [const Color(0xFFB87333), const Color(0xFF7E4F22), const Color(0xFFE09E5A)], // Copper Pipe
    [const Color(0xFF7A8B3F), const Color(0xFF4A5527), const Color(0xFFB9C46A)], // Bamboo Tube
    [const Color(0xFFF0E6D2), t.accentDark, t.accentLight], // Ivory & Brass
    [const Color(0xFFD7DCE4), const Color(0xFF7E8698), const Color(0xFFF0F2F8)], // Chrome Works
  ];
  final p = palettes[style.clamp(0, palettes.length - 1)];

  // Shadow.
  canvas.drawRRect(
    RRect.fromRectAndRadius(body.shift(const Offset(3, 5)), const Radius.circular(12)),
    Paint()..color = Colors.black.withValues(alpha: 0.35),
  );
  // Body.
  canvas.drawRRect(
    RRect.fromRectAndRadius(body, const Radius.circular(12)),
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [p[1], p[0], p[1]],
      ).createShader(body),
  );
  // Bands.
  for (final dy in [-r * 1.1, r * 0.3]) {
    final band = Rect.fromCenter(
        center: Offset(0, dy), width: bodyW * 1.02, height: r * 0.34);
    canvas.drawRRect(
      RRect.fromRectAndRadius(band, const Radius.circular(6)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p[2], p[1]],
        ).createShader(band),
    );
  }
  // Nozzle.
  final nozzle = Rect.fromCenter(
      center: Offset(0, -r * 1.75), width: r * 1.1, height: r * 0.8);
  canvas.drawRRect(
    RRect.fromRectAndRadius(nozzle, const Radius.circular(5)),
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [p[2], p[1]],
      ).createShader(nozzle),
  );
  canvas.restore();
}
