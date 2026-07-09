import 'package:flutter/material.dart';
import 'widgets/lanterna_card.dart';
import 'widgets/scanner_malote_card.dart';
import 'widgets/diagnostico_card.dart';
import 'widgets/sos_card.dart';
import 'widgets/audio_card.dart';
import '../../theme/theme_controller.dart';

class InstrumentosView extends StatelessWidget {
  const InstrumentosView({super.key});


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text('Instrumentos e Ferramentas'),
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
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.instance.themeModeNotifier,
            builder: (context, mode, child) {
              final isDark = mode == ThemeMode.dark;
              return InkWell(
                onTap: () {
                  ThemeController.instance.toggleTheme();
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF00B0FF).withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: isDark 
                              ? [const Color(0xFFFFE082), const Color(0xFFFFB300)]
                              : [const Color(0xFF90A4AE), const Color(0xFF37474F)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: Icon(
                          isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isDark ? 'Modo Claro' : 'Modo Escuro',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Alternar visual',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? const Color(0xFFFFB300) : const Color(0xFF90A4AE),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
