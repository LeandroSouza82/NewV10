// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'supabase_service.dart';

class SyncService {
  static const String _filaKey = 'fila_entregas_offline';
  static bool _isSyncing = false;
  static List<String> idsFinalizadosLocalmente = [];

  // Inicia o listener de conectividade
  static void initialize() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.isNotEmpty && results.first != ConnectivityResult.none) {
        sincronizarFila();
      }
    });
    // Tenta sincronizar logo ao abrir
    sincronizarFila();
  }

  // Adiciona um item na fila offline copiando a foto para o app dir
  static Future<void> adicionarFila(String entregaId, String? tempImagePath, String recebedor, String unidade, String observacoes) async {
    final prefs = await SharedPreferences.getInstance();
    
    String? permanentPath;
    if (tempImagePath != null && tempImagePath.isNotEmpty) {
      // Copiar foto temporária para diretório permanente do app (evitar limpeza do OS)
      final directory = await getApplicationDocumentsDirectory();
      permanentPath = '${directory.path}/baixa_${entregaId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(tempImagePath).copy(permanentPath);
    }

    final novoItem = {
      'entrega_id': entregaId,
      'foto_path': permanentPath,
      'recebedor': recebedor,
      'unidade': unidade,
      'observacoes': observacoes,
      'timestamp': DateTime.now().toIso8601String(),
    };

    final filaJson = prefs.getStringList(_filaKey) ?? [];
    filaJson.add(jsonEncode(novoItem));
    
    await prefs.setStringList(_filaKey, filaJson);
    
    // Tenta sincronizar caso haja alguma rede que não detectamos, mas de forma segura
    sincronizarFila();
  }

  // Sincroniza a fila se houver internet
  static Future<void> sincronizarFila() async {
    if (_isSyncing) return;
    
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.isEmpty || connectivityResult.first == ConnectivityResult.none) {
      return; // Sem internet
    }

    final prefs = await SharedPreferences.getInstance();
    final filaJson = prefs.getStringList(_filaKey) ?? [];

    if (filaJson.isEmpty) return;

    _isSyncing = true;
    List<String> itensRestantes = List.from(filaJson);

    for (String itemJson in filaJson) {
      try {
        final item = jsonDecode(itemJson);
        String? fotoUrl;
        
        if (item['foto_path'] != null && item['foto_path'].toString().isNotEmpty) {
          final file = File(item['foto_path']);
          if (await file.exists()) {
            final motoristaId = SupabaseService.currentMotoristaId ?? 'offline';
            final fileName = 'baixa_${item['entrega_id']}_${DateTime.now().millisecondsSinceEpoch}.jpg';
            final fullPath = '$motoristaId/entregas/$fileName';
            
            await SupabaseService.client.storage.from('entregas').upload(
              fullPath,
              file,
            );
            
            fotoUrl = SupabaseService.client.storage.from('entregas').getPublicUrl(fullPath);
          }
        }

        // Atualiza o banco
        final updateData = {
          'status': 'concluido',
          'recebedor_tipo': item['recebedor'],
          'unidade_recebedor': item['unidade'],
          'observacoes': item['observacoes'],
          'data_conclusao': DateTime.now().toUtc().toIso8601String(),
        };
        if (fotoUrl != null) {
          updateData['foto_url'] = fotoUrl;
        }

        await SupabaseService.client.from('entregas').update(updateData).eq('id', item['entrega_id']);

        // Deletar foto permanente local se existir
        if (item['foto_path'] != null && item['foto_path'].toString().isNotEmpty) {
          if (await File(item['foto_path']).exists()) {
            await File(item['foto_path']).delete();
          }
        }
        
        // Remove da fila com sucesso ou caso arquivo não exista mais
        itensRestantes.remove(itemJson);
        await prefs.setStringList(_filaKey, itensRestantes);

        // Limpa da lista de exclusão local pós-sync confirmado
        idsFinalizadosLocalmente.remove(item['entrega_id'].toString());
      } catch (e) {
        print('Erro ao sincronizar item: $e');
        // Para a execução para evitar flood em caso de falha de rede contínua
        break;
      }
    }

    _isSyncing = false;
  }
}
