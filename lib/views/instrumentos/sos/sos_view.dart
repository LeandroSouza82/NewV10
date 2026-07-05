import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SosView extends StatefulWidget {
  const SosView({super.key});

  @override
  State<SosView> createState() => _SosViewState();
}

class _SosViewState extends State<SosView> with SingleTickerProviderStateMixin {
  // --- Estado do botão de pressão ---
  bool _isPressing = false;
  bool _isTriggered = false;
  bool _isLoadingGps = false;

  late AnimationController _progressController;
  static const _holdDuration = Duration(seconds: 3);

  // --- Localização obtida ---
  Position? _position;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: _holdDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _onAlertaAcionado();
        }
      });
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  void _onLongPressStart(LongPressStartDetails _) {
    if (_isTriggered) return;
    setState(() => _isPressing = true);
    HapticFeedback.heavyImpact();
    _progressController.forward(from: 0);
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    if (_isTriggered) return;
    if (_progressController.status != AnimationStatus.completed) {
      _progressController.reset();
      setState(() => _isPressing = false);
    }
  }

  Future<void> _onAlertaAcionado() async {
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.heavyImpact();

    setState(() {
      _isPressing = false;
      _isTriggered = true;
      _isLoadingGps = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (serviceEnabled &&
          permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
        if (mounted) setState(() => _position = pos);
      }
    } catch (_) {
      // GPS falhou, mas o SOS ainda será exibido sem coordenadas
    } finally {
      if (mounted) setState(() => _isLoadingGps = false);
    }
  }

  Future<void> _enviarWhatsApp() async {
    try {
      String mensagem;
      if (_position != null) {
        final lat = _position!.latitude.toStringAsFixed(6);
        final lng = _position!.longitude.toStringAsFixed(6);
        mensagem =
            '🆘 *ALERTA SOS - V10 Delivery*\n\nEstou em situação de emergência e preciso de ajuda!\n\n📍 Minha localização atual:\nhttps://maps.google.com/?q=$lat,$lng\n\n_Mensagem enviada automaticamente pelo app V10._';
      } else {
        mensagem =
            '🆘 *ALERTA SOS - V10 Delivery*\n\nEstou em situação de emergência e preciso de ajuda!\n\n⚠️ Não foi possível obter a localização GPS no momento.\n\n_Mensagem enviada automaticamente pelo app V10._';
      }

      final encoded = Uri.encodeComponent(mensagem);

      // Tenta whatsapp:// direto primeiro (mais confiável)
      final uriDirect = Uri.parse('whatsapp://send?text=$encoded');
      final uriFallback = Uri.parse('https://wa.me/?text=$encoded');

      if (await canLaunchUrl(uriDirect)) {
        await launchUrl(uriDirect, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(uriFallback)) {
        await launchUrl(uriFallback, mode: LaunchMode.externalApplication);
      } else {
        _mostrarSnackbar('⚠️ WhatsApp não encontrado. Ligue para o 190.');
      }
    } catch (e) {
      _mostrarSnackbar('⚠️ Falha ao abrir o WhatsApp. Ligue para o 190.');
    }
  }

  Future<void> _registrarNoCentral() async {
    try {
      await Supabase.instance.client.from('alertas_sos').insert({
        'latitude': _position?.latitude,
        'longitude': _position?.longitude,
        'criado_em': DateTime.now().toIso8601String(),
      });
      _mostrarSnackbar('✅ Alerta registrado na Central com sucesso!',
          cor: Colors.green);
    } catch (e) {
      _mostrarSnackbar(
          '⚠️ Sem conexão. Alerta não registrado. Use o WhatsApp ou ligue 190.');
    }
  }

  Future<void> _ligarEmergencia() async {
    try {
      final uri = Uri(scheme: 'tel', path: '190');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } else {
        _mostrarSnackbar('⚠️ Não foi possível abrir o discador. Ligue para o 190.');
      }
    } catch (_) {
      _mostrarSnackbar('⚠️ Erro ao abrir o discador do telefone.');
    }
  }

  void _mostrarSnackbar(String msg, {Color cor = const Color(0xFFFF5252)}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: cor,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _reiniciar() {
    _progressController.reset();
    setState(() {
      _isPressing = false;
      _isTriggered = false;
      _isLoadingGps = false;
      _position = null;
    });
  }

  // ─────────────── BUILD ───────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0000),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          '🆘 Emergência',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isTriggered ? _buildPainelAcionado() : _buildBotaoSOS(),
    );
  }

  // ── Painel depois de acionar ──
  Widget _buildPainelAcionado() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 72, color: Color(0xFFFF5252)),
          const SizedBox(height: 16),
          const Text(
            'ALERTA ACIONADO',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFFF5252),
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          if (_isLoadingGps)
            const Center(
              child: Column(
                children: [
                  SizedBox(height: 8),
                  CircularProgressIndicator(color: Color(0xFFFF5252)),
                  SizedBox(height: 8),
                  Text('Obtendo localização GPS...',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            )
          else
            Text(
              _position != null
                  ? '📍 ${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}'
                  : '⚠️ GPS não disponível — alerta sem coordenadas',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
          const SizedBox(height: 40),
          // Botão WhatsApp
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _isLoadingGps ? null : _enviarWhatsApp,
            icon: const Icon(Icons.chat, color: Colors.white),
            label: const Text(
              'Enviar Alerta no WhatsApp',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
          ),
          const SizedBox(height: 12),
          // Botão Central (Supabase)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A1A2E),
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFFF5252)),
              ),
            ),
            onPressed: _isLoadingGps ? null : _registrarNoCentral,
            icon: const Icon(Icons.cloud_upload_outlined, color: Color(0xFFFF5252)),
            label: const Text(
              'Registrar na Central (V10)',
              style: TextStyle(
                  color: Color(0xFFFF5252),
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
          ),
          const SizedBox(height: 12),
          // Botão Ligar 190
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              side: const BorderSide(color: Colors.white30),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _ligarEmergencia,
            icon: const Icon(Icons.phone, color: Colors.white54),
            label: const Text(
              'Ligar para 190 (Polícia)',
              style: TextStyle(
                  color: Colors.white54,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: _reiniciar,
            child: const Text(
              'Cancelar e voltar',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ── Botão de segurar 3s ──
  Widget _buildBotaoSOS() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'EM CASO DE EMERGÊNCIA',
          style: TextStyle(
              color: Colors.white60, fontSize: 13, letterSpacing: 2),
        ),
        const SizedBox(height: 8),
        const Text(
          'SEGURE O BOTÃO\nPOR 3 SEGUNDOS',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 48),
        // Botão circular animado com progresso — centralizado
        Center(
          child: GestureDetector(
            onLongPressStart: _onLongPressStart,
            onLongPressEnd: _onLongPressEnd,
            child: AnimatedBuilder(
              animation: _progressController,
              builder: (context, _) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glow externo pulsante ao pressionar
                    if (_isPressing)
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFF5252).withValues(alpha:
                              0.08 + 0.12 * _progressController.value),
                        ),
                      ),
                    // Anel de progresso
                    SizedBox(
                      width: 170,
                      height: 170,
                      child: CircularProgressIndicator(
                        value: _progressController.value,
                        strokeWidth: 5,
                        backgroundColor:
                            const Color(0xFFFF5252).withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFFF5252)),
                      ),
                    ),
                    // Botão central
                    Container(
                      width: 148,
                      height: 148,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isPressing
                            ? const Color(0xFFB71C1C)
                            : const Color(0xFFD32F2F),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF5252).withValues(alpha:
                                _isPressing ? 0.5 : 0.25),
                            blurRadius: _isPressing ? 30 : 15,
                            spreadRadius: _isPressing ? 4 : 2,
                          ),
                        ],
                      ),
                      // Apenas o ícone SOS (já contém as letras visualmente)
                      child: const Center(
                        child: Icon(Icons.sos, size: 72, color: Colors.white),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 48),
        Text(
          _isPressing ? 'Segure...' : 'Toque e segure para acionar',
          style: TextStyle(
            color:
                _isPressing ? const Color(0xFFFF5252) : Colors.white38,
            fontSize: 14,
            fontWeight:
                _isPressing ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        // Ligação rápida de emergência — 1 clique, sem aguardar 3s
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24, left: 32, right: 32),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Color(0xFFEF9A9A), width: 1.2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _ligarEmergencia,
              icon: const Icon(Icons.phone, color: Color(0xFFEF9A9A), size: 20),
              label: const Text(
                'Ligar 190 diretamente',
                style: TextStyle(
                  color: Color(0xFFEF9A9A),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
