import 'package:flutter/material.dart';
import 'package:app_do_motorista/core/app_colors.dart';
import 'widgets/lanterna_card.dart';
import 'widgets/scanner_malote_card.dart';
import 'widgets/diagnostico_card.dart';
import 'widgets/sos_card.dart';
import 'widgets/audio_card.dart';

class InstrumentosView extends StatelessWidget {
  const InstrumentosView({super.key});


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBody,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundBody,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Instrumentos e Ferramentas',
          style: TextStyle(
            color: AppColors.textWhite,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textWhite),
      ),
      body: GridView.count(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        padding: const EdgeInsets.all(16),
        children: [
          const LanternaCard(),
          const ScannerMaloteCard(),
          const DiagnosticoCard(),
          const SosCard(),
          const AudioCard(),
        ],
      ),
    );
  }
}
