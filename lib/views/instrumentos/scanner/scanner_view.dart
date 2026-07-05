import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:app_do_motorista/core/app_colors.dart';

class ScannerView extends StatefulWidget {
  const ScannerView({super.key});

  @override
  State<ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<ScannerView> {
  bool _isScannerActive = true;
  String? _lastScannedCode;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final barcode = barcodes.first;
      if (barcode.rawValue != null && barcode.rawValue != _lastScannedCode) {
        _lastScannedCode = barcode.rawValue;
        HapticFeedback.heavyImpact(); // Vibrate lightly
        setState(() => _isScannerActive = false);
        _showBarcodeResultDialog(barcode.rawValue!);
      }
    }
  }

  void _showBarcodeResultDialog(String code) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: const Text(
            'Código Identificado',
            style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold),
          ),
          content: Text(
            code,
            style: const TextStyle(color: AppColors.textGrey, fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _lastScannedCode = null;
                  _isScannerActive = true;
                });
              },
              child: const Text('Escanear Outro', style: TextStyle(color: AppColors.textGrey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                Navigator.pop(context);
                setState(() {
                  _lastScannedCode = null;
                  _isScannerActive = true;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Código copiado para a área de transferência!', style: TextStyle(color: Colors.white)),
                    backgroundColor: AppColors.successGreen,
                  ),
                );
              },
              child: const Text('Copiar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _takeCompressedPhoto() async {
    try {
      // Pause scanner while taking photo
      setState(() => _isScannerActive = false);
      
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800, // COMPRESSÃO MÁXIMA OBRIGATÓRIA
        maxHeight: 800,
        imageQuality: 40, // Qualidade entre 35 e 45%
      );

      if (photo != null) {
        final File file = File(photo.path);
        final int sizeInBytes = await file.length();
        final double sizeInKb = sizeInBytes / 1024;
        
        debugPrint('Foto capturada e comprimida! Tamanho: ${sizeInKb.toStringAsFixed(2)} KB');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '📸 Foto salva! Tamanho ultraleve: ${sizeInKb.toStringAsFixed(0)} KB.',
                style: const TextStyle(color: AppColors.textWhite),
              ),
              backgroundColor: Colors.blueAccent,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erro ao capturar foto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '⚠️ Não foi possível iniciar a câmera. Verifique as permissões do aparelho.',
              style: TextStyle(color: AppColors.textWhite),
            ),
            backgroundColor: Colors.orangeAccent.withValues(alpha: 0.9),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isScannerActive = true);
      }
    }
  }

  void _showManualInputDialog() {
    final TextEditingController codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: const Text(
            'Digitar Manualmente',
            style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: codeController,
            style: const TextStyle(color: AppColors.textWhite),
            decoration: InputDecoration(
              hintText: 'Ex: MAL-105',
              hintStyle: TextStyle(color: AppColors.textGrey.withValues(alpha: 0.5)),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.textGrey.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.blueAccent),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: AppColors.textGrey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final text = codeController.text.trim();
                if (text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        '⚠️ Por favor, digite o número do malote.',
                        style: TextStyle(color: AppColors.textWhite),
                      ),
                      backgroundColor: Colors.orangeAccent.withValues(alpha: 0.9),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else {
                  Navigator.pop(context);
                  setState(() => _isScannerActive = false);
                  _showBarcodeResultDialog(text);
                }
              },
              child: const Text('Confirmar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Scanner de Malote',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          if (_isScannerActive)
            MobileScanner(
              onDetect: _onDetect,
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            ),
          
          // Overlay para alinhar o código e botão manual
          if (_isScannerActive)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blueAccent, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton.icon(
                    onPressed: _showManualInputDialog,
                    icon: const Icon(Icons.keyboard, color: Colors.white),
                    label: const Text(
                      'Digitar código manualmente',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.black54,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          color: AppColors.backgroundBody.withValues(alpha: 0.9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    setState(() {
                      _isScannerActive = true;
                      _lastScannedCode = null;
                    });
                  },
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                  label: const Text('Bipar Código', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cardBackground,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.blueAccent),
                    ),
                  ),
                  onPressed: _takeCompressedPhoto,
                  icon: const Icon(Icons.camera_alt, color: Colors.blueAccent),
                  label: const Text('Foto Super Leve', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
