import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService {
  // Singleton
  AudioService._privateConstructor();
  static final AudioService instance = AudioService._privateConstructor();

  final AudioPlayer _player = AudioPlayer();
  final AudioPlayer _playerFinal = AudioPlayer();
  bool _isInitialized = false;

  bool somGeralAtivo = true;
  bool somNovaChamada = true;
  bool somRotaFinalizada = true;
  bool somRotaCompleta = true;
  bool somAlertaFalha = true;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      somGeralAtivo = prefs.getBool('somGeralAtivo') ?? true;
      somNovaChamada = prefs.getBool('somNovaChamada') ?? true;
      somRotaFinalizada = prefs.getBool('somRotaFinalizada') ?? true;
      somRotaCompleta = prefs.getBool('somRotaCompleta') ?? true;
      somAlertaFalha = prefs.getBool('somAlertaFalha') ?? true;
      
      if (!_isInitialized) {
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
        _player.onPlayerComplete.listen((_) => _player.release());
        _playerFinal.onPlayerComplete.listen((_) => _playerFinal.release());
        _isInitialized = true;
      }
    } catch (_) {}
  }

  Future<void> _salvarPreferencia(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
  }

  Future<void> setSomGeralAtivo(bool ativo) async {
    somGeralAtivo = ativo;
    await _salvarPreferencia('somGeralAtivo', ativo);
  }

  Future<void> setSomNovaChamada(bool ativo) async {
    somNovaChamada = ativo;
    await _salvarPreferencia('somNovaChamada', ativo);
  }

  Future<void> setSomRotaFinalizada(bool ativo) async {
    somRotaFinalizada = ativo;
    await _salvarPreferencia('somRotaFinalizada', ativo);
  }

  Future<void> setSomRotaCompleta(bool ativo) async {
    somRotaCompleta = ativo;
    await _salvarPreferencia('somRotaCompleta', ativo);
  }

  Future<void> setSomAlertaFalha(bool ativo) async {
    somAlertaFalha = ativo;
    await _salvarPreferencia('somAlertaFalha', ativo);
  }

  Future<void> _tocarSom(String fileName, {bool isFinal = false}) async {
    try {
      final player = isFinal ? _playerFinal : _player;
      await player.stop();
      await player.setVolume(1.0);
      await player.play(
        AssetSource('sounds/$fileName'), 
        volume: 1.0, 
        mode: PlayerMode.lowLatency,
      );
    } catch (_) {
      // Captura silenciosa
    }
  }

  // --- MÉTODOS DE TESTE (UI) ---
  Future<void> tocarNovaChamada() async => await playChama();
  Future<void> tocarRotaFinalizada() async => await playSucesso();
  Future<void> tocarRotaCompleta() async => await playFinal();
  Future<void> tocarAlertaFalha() async => await playFalha();

  // --- BLOCO DE DISPARO BLINDADO ---

  static Future<void> playChama() async {
    final prefs = await SharedPreferences.getInstance();
    final geral = prefs.getBool('somGeralAtivo') ?? true;
    final especifico = prefs.getBool('somNovaChamada') ?? true;
    
    if (geral && especifico) {
      await AudioService.instance._tocarSom('chama.mp3');
    }
  }

  static Future<void> playSucesso() async {
    final prefs = await SharedPreferences.getInstance();
    final geral = prefs.getBool('somGeralAtivo') ?? true;
    // Assumindo 'somRotaFinalizada' como chave de sucesso individual
    final especifico = prefs.getBool('somRotaFinalizada') ?? true; 
    
    if (geral && especifico) {
      await AudioService.instance._tocarSom('sucesso.mp3');
    }
  }

  static Future<void> playFalha() async {
    final prefs = await SharedPreferences.getInstance();
    final geral = prefs.getBool('somGeralAtivo') ?? true;
    final especifico = prefs.getBool('somAlertaFalha') ?? true;
    
    if (geral && especifico) {
      await AudioService.instance._tocarSom('falha.mp3');
    }
  }

  static Future<void> playFinal() async {
    final prefs = await SharedPreferences.getInstance();
    final geral = prefs.getBool('somGeralAtivo') ?? true;
    final especifico = prefs.getBool('somRotaCompleta') ?? true;
    
    if (geral && especifico) {
      await AudioService.instance._tocarSom('toque_final.mp3', isFinal: true);
    }
  }
  static Future<void> stop() async {
    await AudioService.instance._player.stop();
    await AudioService.instance._playerFinal.stop();
  }
}
