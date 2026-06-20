import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:async';
import '../core/app_colors.dart';

class RouteAlertOverlay extends StatefulWidget {
  final int rotasCount;
  final VoidCallback onClose;

  const RouteAlertOverlay({
    super.key,
    required this.rotasCount,
    required this.onClose,
  });

  @override
  State<RouteAlertOverlay> createState() => _RouteAlertOverlayState();
}

class _RouteAlertOverlayState extends State<RouteAlertOverlay> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Inicia o timer de 5 segundos para fechar sozinho
    _timer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        widget.onClose();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 16, 24),
                decoration: BoxDecoration(
                  color: AppColors.backgroundBody.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.successGreen.withValues(alpha: 0.5), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.successGreen.withValues(alpha: 0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Cabeçalho com o botão X
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Icon(Icons.map_rounded, color: AppColors.successGreen, size: 36),
                        ),
                        IconButton(
                          onPressed: widget.onClose,
                          icon: const Icon(Icons.close_rounded, color: AppColors.textGrey, size: 28),
                          splashRadius: 24,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Mensagem Central
                    const Text(
                      'NOVA ROTA',
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'O gestor enviou ${widget.rotasCount} novos pontos para sua fila.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textGrey.withValues(alpha: 0.9),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
