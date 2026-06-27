import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'overlay_data_helper.dart';

/// Bridge nativa para o V10FloatingService (Overlay Bottom Sheet).
/// Usa MethodChannel para comunicar com o lado Kotlin.
class V10OverlayBridge {
  static const MethodChannel _channel = MethodChannel('com.v10.delivery/overlay');

  /// Processa a lista de pedidos e gera um resumo inteligente para o overlay.
  /// Envia [total_volume] e [trajeto_resumo] ao painel nativo.
  static Future<void> abrirPainelNovaRota(Map<String, dynamic> dados) async {
    // Caso venha um único registro (ex: Realtime Channel), trata como lista de 1
    await abrirPainelResumo([dados]);
  }

  /// Recebe a lista completa de pedidos e monta o resumo inteligente.
  static Future<void> abrirPainelResumo(List<Map<String, dynamic>> pedidos) async {
    try {
      final resumo = await _montarResumo(pedidos);

      await _channel.invokeMethod('abrirPainel', {
        'total_volume': resumo['total_volume'],
        'trajeto_resumo': resumo['trajeto_resumo'],
      });
      debugPrint('✅ V10OverlayBridge: Painel resumo aberto com sucesso.');
    } catch (e) {
      debugPrint('❌ V10OverlayBridge: Erro ao abrir painel: $e');
    }
  }

  /// Fecha o painel nativo programaticamente.
  static Future<void> fecharPainel() async {
    try {
      await _channel.invokeMethod('fecharPainel');
      debugPrint('✅ V10OverlayBridge: Painel nativo fechado.');
    } catch (e) {
      debugPrint('❌ V10OverlayBridge: Erro ao fechar painel: $e');
    }
  }

  /// Monta as strings de resumo a partir da lista de pedidos.
  static Future<Map<String, String>> _montarResumo(List<Map<String, dynamic>> pedidos) async {
    // Conta por tipo
    int entregas = 0;
    int coletas = 0;
    int servicos = 0;

    for (final p in pedidos) {
      final tipo = (p['tipo']?.toString() ?? '').toLowerCase();
      if (tipo.contains('recolha') || tipo.contains('coleta')) {
        coletas++;
      } else if (tipo.contains('outros') || tipo.contains('ata') || tipo.contains('serviço') || tipo.contains('servico')) {
        servicos++;
      } else {
        entregas++;
      }
    }

    // 1. Calcula o Volume Total usando a classe inteligente
    final totalVolume = await OverlayDataHelper.formatarResumoVolume(entregas, coletas, servicos);

    // 2. Calcula trajeto_resumo
    String trajetoResumo = '📍  Rota recebida';

    if (pedidos.isNotEmpty) {
      final primeiro = _extrairLocal(pedidos.first);
      final ultimo = pedidos.length > 1 ? _extrairLocal(pedidos.last) : null;

      if (primeiro.isNotEmpty && ultimo != null && ultimo.isNotEmpty && primeiro != ultimo) {
        trajetoResumo = '📍  $primeiro · $ultimo';
      } else if (primeiro.isNotEmpty) {
        trajetoResumo = '📍  $primeiro';
      }
    }

    return {
      'total_volume': totalVolume,
      'trajeto_resumo': trajetoResumo,
    };
  }

  /// Extrai o bairro/cidade do endereço de um pedido.
  /// Tenta pegar a penúltima parte (geralmente bairro ou cidade)
  /// de um endereço no formato "Rua X, 123, Bairro, Cidade - UF".
  static String _extrairLocal(Map<String, dynamic> pedido) {
    final endereco = pedido['endereco']?.toString() ?? '';
    if (endereco.isEmpty) return '';

    // Remove o "- UF" do final se existir
    final semUF = endereco.split(' - ').first;
    final partes = semUF.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    // Pega a última parte (geralmente cidade ou bairro)
    if (partes.length >= 2) {
      return partes.last;
    }
    // Se só tem 1 parte, retorna ela mesma (truncada)
    return partes.isNotEmpty ? (partes.last.length > 25 ? '${partes.last.substring(0, 25)}...' : partes.last) : '';
  }
}
