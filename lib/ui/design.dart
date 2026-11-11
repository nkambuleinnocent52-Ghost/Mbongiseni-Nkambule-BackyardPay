import 'dart:math' as math;

import 'package:flutter/material.dart';

abstract final class Palette {
  static const background = Color(0xFF090A0C);
  static const surface = Color(0xFF151619);
  static const elevated = Color(0xFF1C1D21);
  static const border = Color(0xFF303136);
  static const gold = Color(0xFFE8BE62);
  static const goldLight = Color(0xFFFFE3A0);
  static const text = Color(0xFFF5F1E7);
  static const muted = Color(0xFFB3B0A8);
  static const green = Color(0xFF85DCB0);
  static const red = Color(0xFFFF9292);
}

ThemeData backyardTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: Palette.gold,
        brightness: Brightness.dark,
      ).copyWith(
        primary: Palette.gold,
        onPrimary: const Color(0xFF211B0D),
        secondary: Palette.goldLight,
        surface: Palette.surface,
        onSurface: Palette.text,
        outline: Palette.border,
        error: Palette.red,
      );
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.background,
    fontFamily: 'BackyardSans',
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: Palette.text,
      displayColor: Palette.text,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.background,
      foregroundColor: Palette.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Palette.text,
        fontFamily: 'BackyardSans',
        fontSize: 19,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: Palette.surface,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Palette.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF111215),
      labelStyle: const TextStyle(color: Palette.muted),
      floatingLabelStyle: const TextStyle(color: Palette.gold),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 19),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Palette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Palette.gold, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.gold,
        foregroundColor: const Color(0xFF201A0D),
        minimumSize: const Size(0, 50),
        shape: shape,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.goldLight,
        side: const BorderSide(color: Palette.border),
        shape: shape,
        minimumSize: const Size(0, 48),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Palette.goldLight),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Palette.surface,
      selectedColor: const Color(0xFF473A20),
      side: const BorderSide(color: Palette.border),
      labelStyle: const TextStyle(color: Palette.text),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    ),
    dividerTheme: const DividerThemeData(
      color: Palette.border,
      thickness: 1,
      space: 28,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Palette.elevated,
      contentTextStyle: TextStyle(color: Palette.text),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Palette.elevated,
      shape: shape,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Palette.gold,
      textColor: Palette.text,
      subtitleTextStyle: TextStyle(color: Palette.muted, height: 1.6),
    ),
  );
}

class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 46});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Palette.goldLight, Palette.gold, Color(0xFFA47723)],
      ),
      borderRadius: BorderRadius.circular(size * .27),
      boxShadow: [
        BoxShadow(color: Palette.gold.withValues(alpha: .14), blurRadius: 28),
      ],
    ),
    child: Icon(
      Icons.home_work_rounded,
      color: const Color(0xFF17130B),
      size: size * .56,
    ),
  );
}

class GoldHero extends StatelessWidget {
  final Widget child;
  final double height;
  const GoldHero({super.key, required this.child, this.height = 230});
  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(minHeight: height),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: const Color(0xFF534325)),
      gradient: const LinearGradient(
        colors: [Color(0xFF20201D), Color(0xFF0D0E10)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: GoldRibbonPainter()),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF151619),
                  const Color(0xFF151619).withValues(alpha: .90),
                  MediaQuery.sizeOf(context).width < 600
                      ? const Color(0xFF151619).withValues(alpha: .68)
                      : Colors.transparent,
                ],
                stops: const [0, .48, 1],
              ),
            ),
          ),
        ),
        Padding(padding: const EdgeInsets.all(28), child: child),
      ],
    ),
  );
}

class GoldRibbonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    canvas.save();
    canvas.clipRect(Offset.zero & s);
    for (var i = 0; i < 9; i++) {
      final y = s.height * (.12 + i * .13);
      final p = Path()
        ..moveTo(s.width * .25, y)
        ..cubicTo(
          s.width * .62,
          y + s.height * .65,
          s.width * .65,
          y - s.height * .65,
          s.width * 1.12,
          y - s.height * .08,
        )
        ..lineTo(s.width * 1.12, y + s.height * .045)
        ..cubicTo(
          s.width * .67,
          y - s.height * .48,
          s.width * .62,
          y + s.height * .85,
          s.width * .25,
          y + s.height * .06,
        )
        ..close();
      final rect = Rect.fromLTWH(
        0,
        0,
        math.max(s.width, 1.0),
        math.max(s.height, 1.0),
      );
      canvas.drawPath(
        p,
        Paint()
          ..shader = LinearGradient(
            colors: i.isEven
                ? [
                    const Color(0xFF38270B),
                    Palette.gold,
                    const Color(0xFFFFE793),
                    const Color(0xFF795016),
                  ]
                : [
                    const Color(0xFF131417),
                    const Color(0xFF37342A),
                    const Color(0xFF0B0C0E),
                  ],
          ).createShader(rect),
      );
      canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .7
          ..color = Palette.gold.withValues(alpha: i.isEven ? .7 : .08),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GoldRibbonPainter oldDelegate) => false;
}

class StatusPill extends StatelessWidget {
  final String label;
  const StatusPill(this.label, {super.key});
  @override
  Widget build(BuildContext context) {
    final value = label.toLowerCase();
    final color = value == 'paid' || value == 'confirmed'
        ? Palette.green
        : value.contains('reject') || value.contains('overdue')
        ? Palette.red
        : Palette.gold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  final String label, value, caption;
  final IconData icon;
  final bool highlight;
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.caption = '',
    this.highlight = false,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    constraints: const BoxConstraints(minHeight: 156),
    decoration: BoxDecoration(
      color: highlight ? const Color(0xFF282214) : Palette.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: highlight ? const Color(0xFF65502A) : Palette.border,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Palette.muted, fontSize: 14),
              ),
            ),
            Icon(icon, color: Palette.gold, size: 20),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          value,
          style: TextStyle(
            fontSize: value.length > 11
                ? 17
                : MediaQuery.sizeOf(context).width < 600
                ? 21
                : 24,
            fontWeight: FontWeight.w700,
            color: highlight ? Palette.goldLight : Palette.text,
          ),
        ),
        if (caption.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            caption,
            style: const TextStyle(
              color: Palette.muted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ],
    ),
  );
}
