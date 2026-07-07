// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../../services/supabase_service.dart';
import '../../services/sync_service.dart';
import '../../services/audio_service.dart';

class MotivoFalha {
  final String id;
  final String label;
  final IconData icone;
  const MotivoFalha(this.id, this.label, this.icone);
}

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
  static const List<MotivoFalha> _motivos = [
    MotivoFalha('Cliente Ausente', 'Cliente ausente', Icons.door_front_door_outlined),
    MotivoFalha('Recusou Entrega', 'Cliente recusou', Icons.close_rounded),
    MotivoFalha('Endereço incorreto', 'Endereço incorreto', Icons.location_on_outlined),
    MotivoFalha('Sem caixa de correio', 'Sem caixa de correio', Icons.markunread_mailbox_outlined),
    MotivoFalha('Falta de documentos', 'Falta de documentos físicos', Icons.description_outlined),
    MotivoFalha('Ata não registrada', 'ATA não registrada', Icons.assignment_outlined),
    MotivoFalha('Local Fechado', 'Sem acesso ao local', Icons.lock_outline),
    MotivoFalha('Outros', 'Outro motivo', Icons.warning_amber_rounded),
  ];

  String? _motivoSelecionado;
  final TextEditingController _descricaoController = TextEditingController();
  File? _foto;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _descricaoController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    super.dispose();
  }

  bool get _motivoOk => _motivoSelecionado != null;
  bool get _podeRegistrar => _motivoOk;

  Future<void> _tirarFoto() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 35,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (image != null) setState(() => _foto = File(image.path));
  }

  Future<void> _escolherDaGaleria() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 35,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (image != null) setState(() => _foto = File(image.path));
  }

  String _gerarMensagemWhatsApp(String motoristaNome, String observacaoFinal) {
    final agora = DateTime.now();
    final horas = '${agora.hour.toString().padLeft(2, '0')}:${agora.minute.toString().padLeft(2, '0')}';
    final dataFormatada = '${agora.day.toString().padLeft(2, '0')}/${agora.month.toString().padLeft(2, '0')}/${agora.year}';
    
    const diasSemana = [
      'segunda-feira', 'terça-feira', 'quarta-feira', 
      'quinta-feira', 'sexta-feira', 'sábado', 'domingo'
    ];
    final diaExtenso = diasSemana[agora.weekday - 1];
    
    final nomeMot = motoristaNome.trim().isEmpty ? 'Leandro' : motoristaNome;

    return '*Status:* ❌ Falha\n'
        '*Motivo:* ${_motivoSelecionado ?? _descricaoController.text.trim()}\n'
        '*Cliente:* ${widget.clienteNome}\n'
        '*Endereco:* ${widget.endereco}\n'
        '*Motorista:* $nomeMot\n'
        '*Hora:* $horas\n'
        '*Dia:* $diaExtenso $dataFormatada';
  }

  Future<void> _confirmar() async {
    if (!_podeRegistrar) return;

    await AudioService.playFalha();
    setState(() => _isLoading = true);

    final String entregaId = widget.rota['id'].toString();
    final String motivo = _motivoSelecionado!;
    final String textoDigitado = _descricaoController.text.trim();
    String observacaoFinal = textoDigitado;

    if (widget.tipo.toLowerCase() == 'outros') {
      observacaoFinal = textoDigitado.isEmpty ? motivo : '$motivo - $textoDigitado';
    } else {
      observacaoFinal = textoDigitado.isEmpty ? 'Nenhuma' : textoDigitado;
    }
    final String? tempImagePath = _foto?.path;

    SyncService.idsFinalizadosLocalmente.add(entregaId);

    final prefs = await SharedPreferences.getInstance();
    final motoristaNome = prefs.getString('nome_motorista') ?? 'Motorista';

    bool hasInternet = true;
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isEmpty || result[0].rawAddress.isEmpty) hasInternet = false;
    } on SocketException catch (_) {
      hasInternet = false;
    }

    if (!hasInternet) {
      await _salvarOfflineECompartilhar(entregaId, tempImagePath, motivo, observacaoFinal, motoristaNome);
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
        'tipo_recebedor': null,
        'observacoes': observacaoFinal,
        'data_conclusao': DateTime.now().toUtc().toIso8601String(),
      };
      
      if (fotoUrl != null) updateData['foto_url'] = fotoUrl;

      await SupabaseService.client.from('entregas').update(updateData).eq('id', entregaId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Falha registrada com sucesso!'), backgroundColor: Colors.redAccent),
        );
      }

      final texto = _gerarMensagemWhatsApp(motoristaNome, observacaoFinal);
      if (tempImagePath != null) {
        await SharePlus.instance.share(ShareParams(files: [XFile(tempImagePath)], text: texto));
        final f = File(tempImagePath);
        if (await f.exists()) await f.delete();
      } else {
        await SharePlus.instance.share(ShareParams(text: texto));
      }

      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      print('ERRO SUPABASE (BANCO): $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao salvar no banco: ${e.message}'), backgroundColor: Colors.redAccent,
        ));
      }
    } on StorageException catch (e) {
      print('ERRO SUPABASE (STORAGE): $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao enviar arquivo: ${e.message}'), backgroundColor: Colors.redAccent,
        ));
      }
    } on SocketException catch (e) {
      print('ERRO DE REDE: $e');
      await _salvarOfflineECompartilhar(entregaId, tempImagePath, motivo, observacaoFinal, motoristaNome);
    } on TimeoutException catch (e) {
      print('ERRO DE TIMEOUT: $e');
      await _salvarOfflineECompartilhar(entregaId, tempImagePath, motivo, observacaoFinal, motoristaNome);
    } catch (e) {
      print('ERRO GENERICO: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao salvar: $e'), backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _salvarOfflineECompartilhar(String entregaId, String? tempImagePath, String motivo, String observacoes, String motoristaNome) async {
    await SyncService.adicionarFila(entregaId, tempImagePath, motivo, 'falha', observacoes);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Salvo localmente. Sincronizando em segundo plano...'), backgroundColor: Colors.orange),
      );
    }
    final texto = _gerarMensagemWhatsApp(motoristaNome, observacoes);
    if (tempImagePath != null) {
      await SharePlus.instance.share(ShareParams(files: [XFile(tempImagePath)], text: texto));
    } else {
      await SharePlus.instance.share(ShareParams(text: texto));
    }
    if (mounted) Navigator.pop(context, true);
  }

  void _mostrarOpcoesImagem() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF112240),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Colors.white),
              title: const Text('Câmera', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _tirarFoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Colors.white),
              title: const Text('Galeria', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _escolherDaGaleria();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1a2740),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                _buildHeader(),
                const SizedBox(height: 20),
                _buildAviso(),
                const SizedBox(height: 18),
                _buildSectionLabel('MOTIVO DA FALHA *', 'role para ver mais ↓'),
                const SizedBox(height: 12),
                _buildMotivosList(),
                const SizedBox(height: 16),
                _buildSectionLabel('DESCRIÇÃO', '(opcional)'),
                const SizedBox(height: 8),
                _buildDescricaoField(),
                const SizedBox(height: 20),
                _buildSectionLabel('FOTO DE EVIDÊNCIA', '(opcional)'),
                const SizedBox(height: 8),
                _buildFotoSection(),
                const SizedBox(height: 16),
                _buildChecklist(),
                const SizedBox(height: 16),
                _buildBotaoEnvio(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final enderecoResumido = widget.endereco.length > 45 ? '${widget.endereco.substring(0, 45)}...' : widget.endereco;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFE53E3E).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE53E3E).withValues(alpha: 0.25)),
          ),
          child: const Icon(Icons.warning_rounded, color: Color(0xFFE53E3E), size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Registrar Falha',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                '${widget.clienteNome} · $enderecoResumido',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAviso() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE53E3E).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE53E3E).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Text('📢', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'A ocorrência será enviada ao gestor automaticamente após o registro.',
              style: TextStyle(color: const Color(0xFFFF6464).withValues(alpha: 0.85), fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label, String actionText) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        Text(
          actionText,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.25),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMotivosList() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 196),
      child: Stack(
        children: [
          ListView.separated(
            shrinkWrap: true,
            itemCount: _motivos.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final m = _motivos[index];
              final selecionado = _motivoSelecionado == m.id;
              
              return GestureDetector(
                onTap: () => setState(() => _motivoSelecionado = m.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: selecionado ? const Color(0xFFE53E3E).withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selecionado ? const Color(0xFFE53E3E).withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.08),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: selecionado ? const Color(0xFFE53E3E).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          m.icone,
                          color: selecionado ? const Color(0xFFFC8181) : Colors.white.withValues(alpha: 0.5),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          m.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selecionado ? FontWeight.w700 : FontWeight.w500,
                            color: selecionado ? const Color(0xFFFC8181) : Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selecionado ? const Color(0xFFE53E3E) : Colors.transparent,
                          border: Border.all(
                            color: selecionado ? Colors.transparent : Colors.white.withValues(alpha: 0.15),
                            width: 1.5,
                          ),
                        ),
                        child: selecionado ? const Icon(Icons.check, color: Colors.white, size: 12) : null,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 24,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xFF1a2740), Colors.transparent],
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescricaoField() {
    final text = _descricaoController.text.trim();
    return TextField(
      controller: _descricaoController,
      maxLines: 3,
      style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
      decoration: InputDecoration(
        hintText: 'Descreva o que aconteceu...',
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.25),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: text.isNotEmpty ? const Color(0xFFE53E3E).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE53E3E), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildFotoSection() {
    final temFoto = _foto != null;
    
    if (temFoto) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(_foto!, width: double.infinity, height: 140, fit: BoxFit.cover),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => setState(() => _foto = null),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: _mostrarOpcoesImagem,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 20),
            const SizedBox(width: 10),
            Text(
              'Tirar Foto como Evidência',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklist() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _checklistItem('Motivo selecionado', _motivoOk, false),
          const SizedBox(height: 6),
          _checklistItem('Descrição adicionada', _descricaoController.text.trim().isNotEmpty, true),
          const SizedBox(height: 6),
          _checklistItem('Foto de evidência', _foto != null, true),
        ],
      ),
    );
  }

  Widget _checklistItem(String label, bool ok, bool opcional) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ok ? (opcional ? const Color(0xFFD4A017) : const Color(0xFFE53E3E)) : Colors.white.withValues(alpha: 0.1),
          ),
          child: ok ? const Icon(Icons.check, color: Colors.white, size: 9) : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: ok ? Colors.white.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ),
        if (opcional)
          Text(
            'OPCIONAL',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.2),
              letterSpacing: 0.5,
            ),
          ),
      ],
    );
  }

  Widget _buildBotaoEnvio() {
    final ativo = _podeRegistrar && !_isLoading;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        gradient: ativo
            ? const LinearGradient(
                colors: [Color(0xFFC53030), Color(0xFFE53E3E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: ativo ? null : Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        boxShadow: ativo
            ? [
                BoxShadow(
                  color: const Color(0xFFE53E3E).withValues(alpha: 0.35),
                  offset: const Offset(0, 4),
                  blurRadius: 20,
                )
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: ativo ? _confirmar : null,
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (ativo) const Text('⚠️', style: TextStyle(fontSize: 14)),
                      if (ativo) const SizedBox(width: 6),
                      Text(
                        ativo ? 'Registrar Falha' : 'Selecione o motivo da falha',
                        style: TextStyle(
                          color: ativo ? Colors.white : Colors.white.withValues(alpha: 0.25),
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
