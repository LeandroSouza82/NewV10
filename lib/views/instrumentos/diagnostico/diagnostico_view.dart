import 'package:flutter/material.dart';
import 'controllers/diagnostico_controller.dart';
import 'widgets/radar_scanner_widget.dart';
import 'widgets/checklist_item_widget.dart';

class DiagnosticoView extends StatefulWidget {
  const DiagnosticoView({super.key});

  @override
  State<DiagnosticoView> createState() => _DiagnosticoViewState();
}

class _DiagnosticoViewState extends State<DiagnosticoView> {
  late DiagnosticoController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DiagnosticoController(setState);
    // Iniciar varredura automática ao abrir a tela
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.executarVarredura();
    });
  }

  String get _statusLabel {
    switch (_controller.statusGeral) {
      case 'OK':
        return '✅ Tudo funcionando normalmente';
      case 'Alerta':
        return '⚠️ Sinal instável detectado';
      case 'Erro':
        return '🔴 Falha crítica na conexão';
      default:
        return _controller.isScanning ? 'Varrendo sistemas...' : 'Pronto para varredura';
    }
  }

  Color get _statusColor {
    switch (_controller.statusGeral) {
      case 'OK':
        return const Color(0xFF00E676);
      case 'Alerta':
        return const Color(0xFFFFAB00);
      case 'Erro':
        return const Color(0xFFFF1744);
      default:
        return const Color(0xFF00E5FF);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Diagnóstico de Rede e GPS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: Column(
        children: [
          // RADAR SECTION
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                RadarScannerWidget(
                  isScanning: _controller.isScanning,
                  statusGeral: _controller.statusGeral,
                ),
                const SizedBox(height: 16),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                    color: _statusColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                  child: Text(_statusLabel),
                ),
              ],
            ),
          ),

          // CHECKLIST SECTION
          Expanded(
            child: ListView(
              children: [
                ChecklistItemWidget(item: _controller.itemRede),
                ChecklistItemWidget(item: _controller.itemGPS),
                ChecklistItemWidget(item: _controller.itemServidor),
              ],
            ),
          ),

          // BOTÃO DE NOVA VARREDURA
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                    foregroundColor: const Color(0xFF00E5FF),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
                    ),
                    elevation: 0,
                  ),
                  onPressed:
                      _controller.isScanning ? null : _controller.executarVarredura,
                  icon: _controller.isScanning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF00E5FF),
                          ),
                        )
                      : const Icon(Icons.radar),
                  label: Text(
                    _controller.isScanning ? 'Varrendo...' : 'Executar Nova Varredura',
                    style: const TextStyle(fontWeight: FontWeight.bold),
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
