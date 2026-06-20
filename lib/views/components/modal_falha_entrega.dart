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

class ModalFalhaEntrega extends StatefulWidget {
  final Map<String, dynamic> rota;
  final String tipo;
  final String clienteNome;
  final String endereco;

  const ModalFalhaEntrega({
    super.key,
    required this.rota,
    required this.tipo,
    required this.clienteNome,
    required this.endereco,
  });

  @override
  State<ModalFalhaEntrega> createState() => _ModalFalhaEntregaState();
}

class _ModalFalhaEntregaState extends State<ModalFalhaEntrega> {
  final List<String> _opcoesMotivo = [
    'Cliente Ausente',
    'Endereço não localizado',
    'Área de Risco',
    'Recusou Entrega',
    'Local Fechado',
    'Falta de documentos',
    'Ata não registrada',
    'Outros',
  ];
  String? _motivoSelecionado;
  final TextEditingController _observacaoController = TextEditingController();

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
    String textoDigitado = _observacaoController.text.trim();
    String obsFinal = textoDigitado.isNotEmpty ? textoDigitado : 'Não informada';

    return '''------------- *${widget.tipo.toUpperCase()}* -------------
*Status:* ❌ Falha
*Motivo:* ${_motivoSelecionado ?? 'Não informado'}
*Obs:* $obsFinal
*Cliente:* ${widget.clienteNome}
*Endereço:* ${widget.endereco}
*Motorista:* $motoristaNome
*Hora:* $horaFormatada'''.trim();
  }

  Future<void> _confirmar() async {
    if (_motivoSelecionado == null) {
      setState(() {
        _erroValidacao = '⚠️ Por favor, selecione o motivo da falha.';
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
    final String motivo = _motivoSelecionado!;
    final String observacoes = _observacaoController.text.trim();
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
      await _salvarOfflineECompartilhar(entregaId, tempImagePath, motivo, observacoes, motoristaNome);
      return;
    }

    try {
      String? fotoUrl;
      if (_foto != null) {
        final motoristaId = SupabaseService.currentMotoristaId ?? 'offline';
        final fileName = 'falha_${entregaId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final fullPath = '$motoristaId/entregas/$fileName';

        await SupabaseService.client.storage.from('entregas').upload(
          fullPath,
          _foto!,
        );

        fotoUrl = SupabaseService.client.storage.from('entregas').getPublicUrl(fullPath);
      }

      final updateData = <String, dynamic>{
        'status': 'falha',
        'motivo_nao_entrega': motivo,
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
          const SnackBar(content: Text('Falha registrada com sucesso!'), backgroundColor: Colors.redAccent),
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
        Navigator.pop(context, true);
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
      await _salvarOfflineECompartilhar(entregaId, tempImagePath, motivo, observacoes, motoristaNome);
    } on TimeoutException catch (e) {
      print('ERRO DE TIMEOUT: $e');
      await _salvarOfflineECompartilhar(entregaId, tempImagePath, motivo, observacoes, motoristaNome);
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

  Future<void> _salvarOfflineECompartilhar(String entregaId, String? tempImagePath, String motivo, String observacoes, String motoristaNome) async {
    await SyncService.adicionarFila(entregaId, tempImagePath, motivo, 'falha', observacoes);

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
            const Text('Confirmar Falha', style: TextStyle(color: Colors.redAccent, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            const Text('Motivo da Falha?', style: TextStyle(color: AppColors.textGrey, fontSize: 14)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _opcoesMotivo.map((opcao) {
                  final isSelected = _motivoSelecionado == opcao;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(opcao),
                      selected: isSelected,
                      selectedColor: Colors.redAccent.withValues(alpha: 0.2),
                      backgroundColor: AppColors.cardBackground,
                      labelStyle: TextStyle(color: isSelected ? Colors.redAccent : AppColors.textWhite),
                      side: BorderSide(color: isSelected ? Colors.redAccent : AppColors.textGrey.withValues(alpha: 0.2)),
                      onSelected: (bool selected) {
                        setState(() {
                          _motivoSelecionado = selected ? opcao : null;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),
            TextField(
              controller: _observacaoController,
              maxLines: 2,
              style: const TextStyle(color: AppColors.textWhite),
              decoration: InputDecoration(
                labelText: 'Observação (Opcional)',
                labelStyle: const TextStyle(color: AppColors.textGrey),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.textGrey.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.redAccent),
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
                          Text('Tirar Foto do Local (Opcional)', style: TextStyle(color: AppColors.textGrey)),
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
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Confirmar Falha', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
