import 'package:flutter/material.dart';
import '../../services/audio_service.dart';

class SomView extends StatefulWidget {
  const SomView({super.key});

  @override
  State<SomView> createState() => _SomViewState();
}

class _SomViewState extends State<SomView> {
  final AudioService _audioService = AudioService.instance;

  @override
  void initState() {
    super.initState();
    // Garante que o serviço está carregado, embora idealmente já devesse estar.
    _audioService.init().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _onGeralChanged(bool value) async {
    await _audioService.setSomGeralAtivo(value);
    setState(() {});
  }

  void _onNovaChamadaChanged(bool value) async {
    await _audioService.setSomNovaChamada(value);
    setState(() {});
  }

  void _onRotaFinalizadaChanged(bool value) async {
    await _audioService.setSomRotaFinalizada(value);
    setState(() {});
  }

  void _onAlertaFalhaChanged(bool value) async {
    await _audioService.setSomAlertaFalha(value);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bool geralAtivo = _audioService.somGeralAtivo;
    
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Configurações de Áudio',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Card Principal - Mudo Geral
          Card(
            color: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: geralAtivo ? const Color(0xFF00E5FF).withValues(alpha: 0.5) : Colors.white12,
              ),
            ),
            child: SwitchListTile(
              activeTrackColor: const Color(0xFF00E5FF).withValues(alpha: 0.4),
              activeThumbColor: const Color(0xFF00E5FF),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              title: const Text(
                'Ativar Todos os Sons',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                geralAtivo ? 'Os alertas sonoros estão habilitados' : 'Aplicativo em modo mudo',
                style: TextStyle(
                  color: geralAtivo ? const Color(0xFF00E5FF) : Colors.white54,
                  fontSize: 13,
                ),
              ),
              value: geralAtivo,
              onChanged: _onGeralChanged,
              secondary: Icon(
                geralAtivo ? Icons.volume_up : Icons.volume_off,
                color: geralAtivo ? const Color(0xFF00E5FF) : Colors.white54,
                size: 32,
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              'ALERTAS INDIVIDUAIS',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          
          // Card Agrupado - Alertas
          Card(
            color: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildAudioTile(
                  title: 'Nova Chamada / Pedido',
                  subtitle: 'Toca ao receber nova entrega',
                  icon: Icons.notifications_active,
                  value: _audioService.somNovaChamada,
                  onChanged: geralAtivo ? _onNovaChamadaChanged : null,
                  onTest: _audioService.tocarNovaChamada,
                ),
                const Divider(color: Colors.white12, height: 1, indent: 20, endIndent: 20),
                _buildAudioTile(
                  title: 'Rota Concluída',
                  subtitle: 'Toca ao finalizar entrega ou bipar malote',
                  icon: Icons.flag,
                  value: _audioService.somRotaFinalizada,
                  onChanged: geralAtivo ? _onRotaFinalizadaChanged : null,
                  onTest: _audioService.tocarRotaFinalizada,
                ),
                const Divider(color: Colors.white12, height: 1, indent: 20, endIndent: 20),
                _buildAudioTile(
                  title: 'Alertas e Falhas',
                  subtitle: 'Toca em caso de erro de rota ou malote inválido',
                  icon: Icons.warning_amber_rounded,
                  iconColor: const Color(0xFFFF5252),
                  value: _audioService.somAlertaFalha,
                  onChanged: geralAtivo ? _onAlertaFalhaChanged : null,
                  onTest: _audioService.tocarAlertaFalha,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioTile({
    required String title,
    required String subtitle,
    required IconData icon,
    Color iconColor = const Color(0xFF00E5FF),
    required bool value,
    required void Function(bool)? onChanged,
    required VoidCallback onTest,
  }) {
    final bool isEnabled = onChanged != null;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: SwitchListTile(
              activeTrackColor: iconColor.withValues(alpha: 0.4),
              activeThumbColor: iconColor,
              contentPadding: const EdgeInsets.only(left: 20, right: 8),
              title: Text(
                title,
                style: TextStyle(
                  color: isEnabled ? Colors.white : Colors.white38,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                subtitle,
                style: TextStyle(
                  color: isEnabled ? Colors.white70 : Colors.white24,
                  fontSize: 12,
                ),
              ),
              value: value,
              onChanged: onChanged,
              secondary: Icon(
                icon,
                color: isEnabled ? iconColor : Colors.white24,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.volume_up_rounded, 
              color: isEnabled ? Colors.white70 : Colors.white24,
            ),
            tooltip: 'Testar Som',
            onPressed: isEnabled ? onTest : null,
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
