import 'dart:math' as math;
import 'package:flutter/material.dart';

class RadarScannerWidget extends StatefulWidget {
  final bool isScanning;
  final String statusGeral; // 'Pendente', 'OK', 'Alerta', 'Erro'

  const RadarScannerWidget({
    super.key,
    required this.isScanning,
    required this.statusGeral,
  });

  @override
  State<RadarScannerWidget> createState() => _RadarScannerWidgetState();
}

class _RadarScannerWidgetState extends State<RadarScannerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _radarColor {
    if (widget.isScanning) return const Color(0xFF00E5FF); // ciano
    switch (widget.statusGeral) {
      case 'OK':
        return const Color(0xFF00E676); // verde neon
      case 'Alerta':
        return const Color(0xFFFFAB00); // âmbar
      case 'Erro':
        return const Color(0xFFFF1744); // vermelho
      default:
        return const Color(0xFF00E5FF);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _RadarPainter(
              sweep: _controller.value,
              color: _radarColor,
              isScanning: widget.isScanning,
            ),
          );
        },
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double sweep;
  final Color color;
  final bool isScanning;

  _RadarPainter({
    required this.sweep,
    required this.color,
    required this.isScanning,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Círculos concêntricos
    final circlePaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, radius * i / 4, circlePaint);
    }

    // Linha de cruz central
    final crossPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      crossPaint,
    );
    canvas.drawLine(
      Offset(0, center.dy),
      Offset(size.width, center.dy),
      crossPaint,
    );

    if (isScanning) {
      // Feixe de varredura girando
      final sweepAngle = sweep * 2 * math.pi - math.pi / 2;
      final sweepPaint = Paint()
        ..shader = SweepGradient(
          center: Alignment.center,
          startAngle: sweepAngle - 1.2,
          endAngle: sweepAngle,
          colors: [Colors.transparent, color.withValues(alpha: 0.8)],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        sweepAngle - 1.2,
        1.2,
        true,
        sweepPaint,
      );

      // Ponto brilhante na ponta do feixe
      final dotX = center.dx + radius * math.cos(sweepAngle);
      final dotY = center.dy + radius * math.sin(sweepAngle);
      final dotPaint = Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(dotX, dotY), 4, dotPaint);
    }

    // Borda externa
    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius - 1, borderPaint);

    // Glow externo quando scanning
    if (isScanning) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(center, radius, glowPaint);
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.sweep != sweep || old.color != color || old.isScanning != isScanning;
}
