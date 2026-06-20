// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_colors.dart';
import '../../services/supabase_service.dart';
import '../../services/sync_service.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class ModalBaixaEntrega extends StatefulWidget {
  final Map<String, dynamic> rota;
  final String tipo;
  final String clienteNome;
  final String endereco;

  const ModalBaixaEntrega({
    super.key, 
    required this.rota,
    required this.tipo,
    required this.clienteNome,
    required this.endereco,
  });

  @override
  State<ModalBaixaEntrega> createState() => _ModalBaixaEntregaState();
}

class _ModalBaixaEntregaState extends State<ModalBaixaEntrega> {
  final List<String> _opcoesRecebedor = ['Zelador', 'Síndico', 'Porteiro', 'Faxineiro', 'Morador', 'Locker', 'Correios', 'Outros'];
  String? _recebedorSelecionado;
  final TextEditingController _nomeObservacaoController = TextEditingController();
  
  File? _foto;
  bool _isLoading = false;
  String? _erroValidacao;

  Future<void> _tirarFoto() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 10,
      maxWidth: 600,
      maxHeight: 600,
    );

    if (image != null) {
      setState(() {
        _foto = File(image.path);
      });
    }
  }

  String _gerarMensagemWhatsApp(String motoristaNome) {
    final horaFormatada = DateFormat('HH:mm').format(DateTime.now());
    String textoDigitado = _nomeObservacaoController.text.trim();
    String recebedorFinal = textoDigitado.isNotEmpty ? '${_recebedorSelecionado ?? ''} $textoDigitado'.trim() : (_recebedorSelecionado ?? 'Não informado');

    return '''------------- *${widget.tipo.toUpperCase()}* -------------
*Status:* ✅ Sucesso
*Recebido por:* $recebedorFinal
*Cliente:* ${widget.clienteNome}
*Endereço:* ${widget.endereco}
*Motorista:* $motoristaNome
*Hora:* $horaFormatada'''.trim();
  }

  Future<void> _confirmar() async {
    if (_recebedorSelecionado == null) {
      setState(() {
        _erroValidacao = '⚠️ Por favor, selecione quem recebeu.';
      });
      return;
    } else {
      setState(() {
        _erroValidacao = null;
      });
    }

    setState(() {
      _isLoading = true;
    });

    final String entregaId = widget.rota['id'].toString();
    final String recebedor = _recebedorSelecionado!;
    final String observacoes = _nomeObservacaoController.text.trim();
    final String? tempImagePath = _foto?.path;

    // Adiciona imediatamente à lista de exclusão para evitar efeito ioiô
    SyncService.idsFinalizadosLocalmente.add(entregaId);

    final prefs = await SharedPreferences.getInstance();
    final motoristaNome = prefs.getString('nome_motorista') ?? 'Leandro';

    bool hasInternet = true;
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        hasInternet = false;
      }
    } on SocketException catch (_) {
      hasInternet = false;
    }

    if (!hasInternet) {
      // Estritamente offline sem mascarar erro de banco
      await _salvarOfflineECompartilhar(entregaId, tempImagePath, recebedor, observacoes, motoristaNome);
      return;
    }

    try {
      String? fotoUrl;
      if (_foto != null) {
        // Tenta upload direto
        final motoristaId = SupabaseService.currentMotoristaId ?? 'offline';
        final fileName = 'baixa_${entregaId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final fullPath = '$motoristaId/entregas/$fileName';
        
        await SupabaseService.client.storage.from('entregas').upload(
          fullPath,
          _foto!,
        );
        
        fotoUrl = SupabaseService.client.storage.from('entregas').getPublicUrl(fullPath);
      }

      final updateData = {
        'status': 'concluido',
        'recebedor_tipo': recebedor,
        'observacoes': observacoes,
        'data_conclusao': DateTime.now().toUtc().toIso8601String(),
      };
      if (fotoUrl != null) {
        updateData['foto_url'] = fotoUrl;
      }

      await SupabaseService.client.from('entregas').update(updateData).eq('id', entregaId);

      // Sucesso absoluto online
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dados enviados com sucesso!'), backgroundColor: AppColors.successGreen),
        );
      }

      final texto = _gerarMensagemWhatsApp(motoristaNome);
      if (tempImagePath != null) {
        await SharePlus.instance.share(ShareParams(files: [XFile(tempImagePath)], text: texto));
        if (await File(tempImagePath).exists()) {
          await File(tempImagePath).delete();
        }
      } else {
        await SharePlus.instance.share(ShareParams(text: texto));
      }

      if (mounted) {
        Navigator.pop(context, true); // Retorna true para remover da lista localmente
      }
    } on PostgrestException catch (e) {
      print('ERRO SUPABASE (BANCO): $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar no banco: ${e.message}'), backgroundColor: Colors.redAccent),
        );
      }
    } on StorageException catch (e) {
      print('ERRO SUPABASE (STORAGE): $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar foto: ${e.message}'), backgroundColor: Colors.redAccent),
        );
      }
    } on SocketException catch (e) {
      print('ERRO DE REDE: $e');
      await _salvarOfflineECompartilhar(entregaId, tempImagePath, recebedor, observacoes, motoristaNome);
    } on TimeoutException catch (e) {
      print('ERRO DE TIMEOUT: $e');
      await _salvarOfflineECompartilhar(entregaId, tempImagePath, recebedor, observacoes, motoristaNome);
    } catch (e) {
      print('ERRO GENÉRICO NO SUPABASE: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar no banco: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _salvarOfflineECompartilhar(String entregaId, String? tempImagePath, String recebedor, String observacoes, String motoristaNome) async {
    await SyncService.adicionarFila(entregaId, tempImagePath, recebedor, '', observacoes);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Salvo localmente. Sincronizando em segundo plano...'), backgroundColor: Colors.orange),
      );
    }

    final texto = _gerarMensagemWhatsApp(motoristaNome);
    if (tempImagePath != null) {
      await SharePlus.instance.share(ShareParams(files: [XFile(tempImagePath)], text: texto));
    } else {
      await SharePlus.instance.share(ShareParams(text: texto));
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.backgroundBody,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          top: 24,
          left: 24,
          right: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
            const Text('Confirmar Entrega', style: TextStyle(color: AppColors.textWhite, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            const Text('Quem recebeu?', style: TextStyle(color: AppColors.textGrey, fontSize: 14)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _opcoesRecebedor.map((opcao) {
                  final isSelected = _recebedorSelecionado == opcao;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(opcao),
                      selected: isSelected,
                      selectedColor: AppColors.successGreen.withValues(alpha: 0.2),
                      backgroundColor: AppColors.cardBackground,
                      labelStyle: TextStyle(color: isSelected ? AppColors.successGreen : AppColors.textWhite),
                      side: BorderSide(color: isSelected ? AppColors.successGreen : AppColors.textGrey.withValues(alpha: 0.2)),
                      onSelected: (bool selected) {
                        setState(() {
                          _recebedorSelecionado = selected ? opcao : null;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            
            const SizedBox(height: 16),
            TextField(
              controller: _nomeObservacaoController,
              maxLines: 2,
              style: const TextStyle(color: AppColors.textWhite),
              decoration: InputDecoration(
                labelText: 'Nome / Observação',
                labelStyle: const TextStyle(color: AppColors.textGrey),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.textGrey.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppColors.successGreen),
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: AppColors.cardBackground,
              ),
            ),

            const SizedBox(height: 24),
            GestureDetector(
              onTap: _tirarFoto,
              child: Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.textGrey.withValues(alpha: 0.3)),
                  image: _foto != null ? DecorationImage(image: FileImage(_foto!), fit: BoxFit.cover) : null,
                ),
                child: _foto == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_outlined, color: AppColors.textWhite, size: 32),
                          SizedBox(height: 8),
                          Text('Tirar Foto do Pacote (Opcional)', style: TextStyle(color: AppColors.textGrey)),
                        ],
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 24),

            if (_erroValidacao != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Center(
                  child: Text(
                    _erroValidacao!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _confirmar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.successGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Confirmar Entrega', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
