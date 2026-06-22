import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  static final AudioPlayer _player = AudioPlayer();
  static final AudioPlayer _playerFinal = AudioPlayer(); // Player dedicado para o toque final

  static Future<void> playAudio(String fileName, {bool isFinal = false}) async {
    try {
      final player = isFinal ? _playerFinal : _player;
      
      // Define volume máximo para não haver silêncio por erro de nível
      await player.setVolume(1.0);
      
      // Toca diretamente no modo lowLatency
      await player.play(
        AssetSource('sounds/$fileName'), 
        volume: 1.0, 
        mode: PlayerMode.lowLatency,
      );
    } catch (e) {
      debugPrint('Erro crítico ao reproduzir $fileName: $e');
    }
  }

  static Future<void> playChama() async => await playAudio('chama.mp3');
  static Future<void> playSucesso() async => await playAudio('sucesso.mp3');
  static Future<void> playFalha() async => await playAudio('falha.mp3');
  static Future<void> playFinal() async => await playAudio('toque_final.mp3', isFinal: true);
  
  static Future<void> playChamaNoOverlay() async {
    try {
      // 1. Acorda o sistema de áudio antes de tocar (Wakelock)
      // Se tivermos o WakelockPlus adicionado no pubspec
      
      // 2. Configura o contexto de áudio como ALARME
      await _player.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          audioMode: AndroidAudioMode.normal,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.alarm,
        )
      ));
      
      await _player.setVolume(1.0);
      await _player.play(
        AssetSource('sounds/chama.mp3'), 
        volume: 1.0, 
        mode: PlayerMode.lowLatency,
      );
    } catch (e) {
      debugPrint('Erro ao reproduzir no overlay: $e');
    }
  }
  
  static Future<void> stop() async {
    await _player.stop();
    await _playerFinal.stop();
  }
}
