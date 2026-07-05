import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class SignaturePad extends StatefulWidget {
  final Function(bool temAssinatura) onChanged;

  const SignaturePad({super.key, required this.onChanged});

  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  final List<List<Offset>> _tracos = [];
  List<Offset> _tracoAtual = [];

  void _limpar() {
    setState(() => _tracos.clear());
    widget.onChanged(false);
  }

  /// Exporta o conteúdo desenhado para um Uint8List (PNG)
  Future<Uint8List?> exportToImage({
    int width = 800,
    int height = 300,
    Color backgroundColor = const Color(0xFF1A2E4A),
    Color strokeColor = Colors.white,
  }) async {
    if (_tracos.isEmpty) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));

    // Pinta o fundo
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), bgPaint);

    // Mapeia os traços (que estavam na escala de 150px de altura) para o novo tamanho
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    final Size size = renderBox?.size ?? const Size(400, 150);

    final scaleX = width / size.width;
    final scaleY = height / size.height;

    final pathPaint = Paint()
      ..color = strokeColor
      ..strokeWidth = 2.5 * ((scaleX + scaleY) / 2) // Aumenta o traço proporcionalmente
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final traco in _tracos) {
      if (traco.length < 2) continue;
      final path = Path();
      path.moveTo(traco.first.dx * scaleX, traco.first.dy * scaleY);
      for (int i = 1; i < traco.length; i++) {
        path.lineTo(traco[i].dx * scaleX, traco[i].dy * scaleY);
      }
      canvas.drawPath(path, pathPaint);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    final temAssinatura = _tracos.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: temAssinatura
                      ? Colors.green.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.15),
                  width: 1.5,
                  style: BorderStyle.solid,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: GestureDetector(
                  // HIT TEST OPAQUE é a chave para o ListView do BottomSheet não engolir o toque
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (d) {
                    setState(() {
                      _tracoAtual = [d.localPosition];
                      _tracos.add(_tracoAtual);
                    });
                    widget.onChanged(true);
                  },
                  onPanUpdate: (d) {
                    setState(() {
                      _tracoAtual.add(d.localPosition);
                    });
                  },
                  onPanEnd: (_) {
                    _tracoAtual = [];
                  },
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _SignaturePainter(_tracos),
                      child: const SizedBox(
                        width: double.infinity,
                        height: 150,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (!temAssinatura)
              const Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.draw_outlined,
                            color: Colors.white24, size: 24),
                        SizedBox(height: 6),
                        Text(
                          'Assine aqui com o dedo',
                          style: TextStyle(
                            color: Colors.white24,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (temAssinatura)
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: _limpar,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Limpar',
                      style: TextStyle(
                        color: Color(0xFFFC8181),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (temAssinatura)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF48BB78), size: 14),
                SizedBox(width: 4),
                Text(
                  'Assinatura capturada',
                  style: TextStyle(
                    color: Color(0xFF48BB78),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> tracos;

  _SignaturePainter(this.tracos);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final traco in tracos) {
      if (traco.length < 2) continue;
      final path = Path();
      path.moveTo(traco.first.dx, traco.first.dy);
      for (int i = 1; i < traco.length; i++) {
        path.lineTo(traco[i].dx, traco[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter old) => true;
}
