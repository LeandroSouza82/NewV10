import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  static final AudioPlayer _player = AudioPlayer();
  static final AudioPlayer _playerFinal = AudioPlayer();
  static final AudioPlayer _overlayPlayer = AudioPlayer();
  
  static bool _isInitialized = false;

  static Future<void> _initContexts() async {
    if (_isInitialized) return;

    // Configuração dos contextos para os diferentes players
    await _player.setAudioContext(AudioContext(
      android: AudioContextAndroid(
        audioMode: AndroidAudioMode.normal,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
      )
    ));
    await _playerFinal.setAudioContext(AudioContext(
      android: AudioContextAndroid(
        audioMode: AndroidAudioMode.normal,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
      )
    ));
    await _overlayPlayer.setAudioContext(AudioContext(
      android: AudioContextAndroid(
        audioMode: AndroidAudioMode.normal,
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.alarm, // O Android NÃO bloqueia alarmes
      )
    ));

    // Listeners para liberação de memória nativa assim que o som terminar
    // Evita o uso do dispose() que mata o objeto Dart e fecha a Stream permanentemente.
    _player.onPlayerComplete.listen((_) => _player.release());
    _playerFinal.onPlayerComplete.listen((_) => _playerFinal.release());
    _overlayPlayer.onPlayerComplete.listen((_) => _overlayPlayer.release());

    _isInitialized = true;
  }

  static Future<void> playAudio(String fileName, {bool isFinal = false}) async {
    try {
      await _initContexts();
      final player = isFinal ? _playerFinal : _player;
      
      await player.stop();
      await player.setVolume(1.0);
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
      await _initContexts();
      
      await _overlayPlayer.stop();
      await _overlayPlayer.setVolume(1.0);
      await _overlayPlayer.play(
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
    await _overlayPlayer.stop();
  }
}
