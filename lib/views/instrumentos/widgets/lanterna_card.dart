import 'package:flutter/material.dart';
import 'package:torch_light/torch_light.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_do_motorista/core/app_colors.dart';

class LanternaCard extends StatefulWidget {
  const LanternaCard({super.key});

  @override
  State<LanternaCard> createState() => _LanternaCardState();
}

class _LanternaCardState extends State<LanternaCard> {
  bool _isOn = false;

  @override
  void dispose() {
    // Tenta desligar a lanterna por segurança ao sair da tela
    _desligarLanternaSilenciosamente();
    super.dispose();
  }

  Future<void> _desligarLanternaSilenciosamente() async {
    try {
      if (_isOn) {
        await TorchLight.disableTorch();
      }
    } catch (_) {
      // Ignora erros no dispose
    }
  }

  Future<void> _toggleTorch() async {
    try {
      if (!_isOn) {
        final status = await Permission.camera.request();
        if (status.isPermanentlyDenied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  '⚠️ Para ligar a lanterna, permita o acesso à câmera nas configurações do celular.',
                  style: TextStyle(color: AppColors.textWhite),
                ),
                backgroundColor: Colors.orangeAccent.withValues(alpha: 0.9),
                behavior: SnackBarBehavior.floating,
                action: SnackBarAction(
                  label: 'Abrir',
                  textColor: Colors.white,
                  onPressed: () => openAppSettings(),
                ),
              ),
            );
          }
          return;
        } else if (!status.isGranted) {
          return; // Usuário negou a permissão nesta rodada
        }
      }

      if (_isOn) {
        await TorchLight.disableTorch();
        setState(() => _isOn = false);
      } else {
        await TorchLight.enableTorch();
        setState(() => _isOn = true);
      }
    } catch (e) {
      debugPrint('Erro na lanterna: $e');
      if (mounted) {
        setState(() => _isOn = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '⚠️ Não foi possível ativar a lanterna. Verifique se o flash está disponível no seu aparelho.',
              style: TextStyle(color: AppColors.textWhite),
            ),
            backgroundColor: Colors.orangeAccent.withValues(alpha: 0.9),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _isOn ? Colors.amberAccent : AppColors.textGrey.withValues(alpha: 0.2);
    final shadowColor = _isOn ? Colors.amberAccent.withValues(alpha: 0.3) : Colors.transparent;
    final iconColor = _isOn ? Colors.amberAccent : AppColors.textGrey;
    final iconData = _isOn ? Icons.flashlight_on : Icons.flashlight_off;
    final title = _isOn ? 'Lanterna Ligada\n(Toque para apagar)' : 'Lanterna Rápida\n(Toque para ligar)';

    return InkWell(
      onTap: _toggleTorch,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              iconData,
              size: 48,
              color: iconColor,
            ),
            const SizedBox(height: 16),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
