// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'signature_pad.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../../core/app_colors.dart';
import '../../services/supabase_service.dart';
import '../../services/sync_service.dart';
import '../../services/audio_service.dart';

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
  static const List<String> _opcoesRecebedor = [
    'Destinatario',
    'Porteiro',
    'Zelador',
    'Sindico',
    'Vizinho',
    'Familiar',
    'Faxineiro',
    'Morador',
    'Locker',
    'Correios',
    'Outros',
  ];

  String? _recebedorSelecionado;
  final TextEditingController _nomeObsController = TextEditingController();
  File? _foto;
  bool _isLoading = false;

  final GlobalKey<SignaturePadState> _signatureKey = GlobalKey<SignaturePadState>();
  bool _assinaturaOk = false;
  bool _isSigning = false;

  @override
  void initState() {
    super.initState();
    _nomeObsController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nomeObsController.dispose();
    super.dispose();
  }

  bool get _isOutros => widget.tipo.toLowerCase() == 'outros' || widget.rota['tipoServico']?.toString().toLowerCase() == 'outros';

  bool get _isLockerOuCorreio => _recebedorSelecionado != null && 
      (_recebedorSelecionado!.toLowerCase() == 'correios' || _recebedorSelecionado!.toLowerCase() == 'locker');

  bool get _recebedorOk => _recebedorSelecionado != null;
  bool get _nomeOk => _nomeObsController.text.trim().isNotEmpty;
  bool get _formularioValido {
    if (_isOutros) return _recebedorOk;
    if (_isLockerOuCorreio) return _recebedorOk;
    return _recebedorOk && _nomeOk && _assinaturaOk;
  }

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

  Future<Uint8List?> _exportarAssinatura() async {
    try {
      return await _signatureKey.currentState?.exportToImage(
        width: 400,
        height: 150,
        backgroundColor: const Color(0xFF1A2E4A),
        strokeColor: Colors.white,
      );
    } catch (e) {
      print('Erro ao exportar assinatura: $e');
      return null;
    }
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

    if (_isOutros) {
      return '------------- *OUTROS/ATA* -------------\n\n'
          '*Status:* ✅ Sucesso\n'
          '*Observacoes:* ${_recebedorSelecionado ?? 'Ata Registrada'}\n'
          '*Cliente:* ${widget.clienteNome}\n'
          '*Endereco:* ${widget.endereco}\n'
          '*Motorista:* $nomeMot\n'
          '*Hora:* $horas\n'
          '*Dia:* $diaExtenso $dataFormatada';
    }

    final textoDigitado = _nomeObsController.text.trim();
    final recebedorFinal = textoDigitado.isNotEmpty
        ? '${_recebedorSelecionado ?? ''} $textoDigitado'.trim()
        : (_recebedorSelecionado ?? 'Nao informado');

    final isColeta = widget.tipo.toLowerCase() == 'coleta' ||
        widget.tipo.toLowerCase() == 'recolha';
    final displayTipo = isColeta ? 'COLETA' : widget.tipo.toUpperCase();

    return '------------- *$displayTipo* -------------\n'
        '*Status:* ✅ Sucesso\n'
        '*${isColeta ? 'Entregue por' : 'Recebido por'}:* $recebedorFinal\n'
        '*Cliente:* ${widget.clienteNome}\n'
        '*Endereco:* ${widget.endereco}\n'
        '*Motorista:* $nomeMot\n'
        '*Hora:* $horas\n'
        '*Dia:* $diaExtenso $dataFormatada';
  }

  Future<void> _confirmar() async {
    if (!_formularioValido) return;

    await AudioService.playSucesso();
    setState(() => _isLoading = true);

    final String entregaId = widget.rota['id'].toString();
    final String recebedor = _recebedorSelecionado!;
    final String textoDigitado = _nomeObsController.text.trim();

    String observacaoFinal;
    if (_isOutros) {
      observacaoFinal =
          textoDigitado.isEmpty ? recebedor : '$recebedor - $textoDigitado';
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
      await _salvarOfflineECompartilhar(
          entregaId, tempImagePath, recebedor, observacaoFinal, motoristaNome);
      return;
    }

    try {
      String? assinaturaUrl;
      final assinaturaBytes = await _exportarAssinatura();
      if (assinaturaBytes != null) {
        final motoristaId = SupabaseService.currentMotoristaId ?? 'offline';
        final sigFileName =
            'assinatura_${entregaId}_${DateTime.now().millisecondsSinceEpoch}.png';
        final sigPath = '$motoristaId/assinaturas/$sigFileName';
        await SupabaseService.client.storage
            .from('entregas')
            .uploadBinary(sigPath, assinaturaBytes,
                fileOptions: const FileOptions(contentType: 'image/png'));
        assinaturaUrl = SupabaseService.client.storage
            .from('entregas')
            .getPublicUrl(sigPath);
      }

      String? fotoUrl;
      if (_foto != null) {
        final motoristaId = SupabaseService.currentMotoristaId ?? 'offline';
        final fotoFileName =
            'baixa_${entregaId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final fotoPath = '$motoristaId/entregas/$fotoFileName';
        await SupabaseService.client.storage
            .from('entregas')
            .upload(fotoPath, _foto!);
        fotoUrl = SupabaseService.client.storage
            .from('entregas')
            .getPublicUrl(fotoPath);
      }

      final updateData = <String, dynamic>{
        'status': 'concluido',
        'recebedor_tipo': recebedor,
        'observacoes': observacaoFinal,
        'data_conclusao': DateTime.now().toUtc().toIso8601String(),
      };
      if (assinaturaUrl != null) updateData['assinatura_url'] = assinaturaUrl;
      if (fotoUrl != null) updateData['foto_url'] = fotoUrl;

      await SupabaseService.client
          .from('entregas')
          .update(updateData)
          .eq('id', entregaId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dados enviados com sucesso!'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }

      final texto = _gerarMensagemWhatsApp(motoristaNome, observacaoFinal);
      if (tempImagePath != null) {
        await SharePlus.instance
            .share(ShareParams(files: [XFile(tempImagePath)], text: texto));
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
          content: Text('Erro ao salvar no banco: ${e.message}'),
          backgroundColor: Colors.redAccent,
        ));
      }
    } on StorageException catch (e) {
      print('ERRO SUPABASE (STORAGE): $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao enviar arquivo: ${e.message}'),
          backgroundColor: Colors.redAccent,
        ));
      }
    } on SocketException catch (e) {
      print('ERRO DE REDE: $e');
      await _salvarOfflineECompartilhar(
          entregaId, tempImagePath, recebedor, observacaoFinal, motoristaNome);
    } on TimeoutException catch (e) {
      print('ERRO DE TIMEOUT: $e');
      await _salvarOfflineECompartilhar(
          entregaId, tempImagePath, recebedor, observacaoFinal, motoristaNome);
    } catch (e) {
      print('ERRO GENERICO: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao salvar: $e'),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _salvarOfflineECompartilhar(
    String entregaId,
    String? tempImagePath,
    String recebedor,
    String observacoes,
    String motoristaNome,
  ) async {
    await SyncService.adicionarFila(
        entregaId, tempImagePath, recebedor, '', observacoes);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Salvo localmente. Sincronizando em segundo plano...'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    final texto = _gerarMensagemWhatsApp(motoristaNome, observacoes);
    if (tempImagePath != null) {
      await SharePlus.instance
          .share(ShareParams(files: [XFile(tempImagePath)], text: texto));
    } else {
      await SharePlus.instance.share(ShareParams(text: texto));
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isColeta = widget.tipo.toLowerCase() == 'coleta' ||
        widget.tipo.toLowerCase() == 'recolha';
    final labelRecebedor = isColeta ? 'QUEM ENTREGOU?' : 'QUEM RECEBEU?';
    final hintNome = _recebedorSelecionado == 'Morador'
        ? 'Ex: Silvania - Apto 302, Bloco B'
        : 'Ex: Silvania';

    return SafeArea(
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0D1F38),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            physics: _isSigning ? const NeverScrollableScrollPhysics() : const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.textGrey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                _buildHeader(),
                const SizedBox(height: 24),
                _buildSectionLabel(labelRecebedor),
                const SizedBox(height: 10),
                _buildRecebedoresList(),
                const SizedBox(height: 20),
                if (!_isLockerOuCorreio) ...[
                  _buildSectionLabel(_isOutros ? 'NOME / OBSERVACAO' : 'NOME / OBSERVACAO *', optional: _isOutros),
                  const SizedBox(height: 8),
                  _buildNomeField(hintNome),
                  const SizedBox(height: 20),
                  _buildSectionLabel(_isOutros ? 'ASSINATURA DIGITAL' : 'ASSINATURA DIGITAL *', optional: _isOutros),
                  const SizedBox(height: 8),
                  _buildSignaturePad(),
                  const SizedBox(height: 20),
                ],
                _buildSectionLabel('FOTO DO PACOTE', optional: true),
                const SizedBox(height: 8),
                _buildFotoSection(),
                const SizedBox(height: 24),
                _buildChecklist(),
                const SizedBox(height: 12),
                _buildBotaoEnvio(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final enderecoResumido = widget.endereco.length > 45
        ? '${widget.endereco.substring(0, 45)}...'
        : widget.endereco;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.successGreen.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.check_circle_rounded,
              color: AppColors.successGreen, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Confirmar Entrega',
                style: TextStyle(
                    color: AppColors.textWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                '${widget.clienteNome} - $enderecoResumido',
                style: const TextStyle(
                    color: AppColors.textGrey, fontSize: 12, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label, {bool optional = false, String? actionText}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textGrey,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            if (optional) ...[
              const SizedBox(width: 6),
              Text(
                '(opcional)',
                style: TextStyle(
                  color: AppColors.textGrey.withValues(alpha: 0.6),
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
        if (actionText != null)
          Text(
            actionText,
            style: TextStyle(
              color: AppColors.textGrey.withValues(alpha: 0.5),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }

  IconData _getIconForRecebedor(String opcao) {
    switch (opcao) {
      case 'Destinatário':
      case 'Destinatario': return Icons.person_outline_rounded;
      case 'Porteiro': return Icons.badge_outlined;
      case 'Zelador': return Icons.key_outlined;
      case 'Sindico':
      case 'Síndico': return Icons.apartment_rounded;
      case 'Vizinho': return Icons.group_outlined;
      case 'Familiar': return Icons.family_restroom_rounded;
      case 'Faxineiro': return Icons.cleaning_services_rounded;
      case 'Morador': return Icons.home_outlined;
      case 'Locker': return Icons.inventory_2_outlined;
      case 'Correios': return Icons.local_shipping_outlined;
      case 'Ata Registrada': return Icons.assignment_rounded;
      default: return Icons.more_horiz_rounded;
    }
  }

  List<String> get _getOpcoesRecebedor {
    List<String> opcoes = List.from(_opcoesRecebedor);
    if (_isOutros && !opcoes.contains('Ata Registrada')) {
      opcoes.add('Ata Registrada');
    }
    return opcoes;
  }

  Widget _buildRecebedoresList() {
    final opcoes = _getOpcoesRecebedor;
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: AppColors.textGrey.withValues(alpha: 0.2), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: AppColors.textGrey.withValues(alpha: 0.2), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.successGreen, width: 1.5),
        ),
        filled: true,
        fillColor: const Color(0xFF1A2E4A),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      dropdownColor: const Color(0xFF112240),
      style: const TextStyle(color: AppColors.textWhite, fontSize: 14),
      value: _recebedorSelecionado,
      isExpanded: true,
      hint: Text('Selecione quem recebeu',
          style: TextStyle(
              color: AppColors.textGrey.withValues(alpha: 0.6), fontSize: 13)),
      items: opcoes.map((tipo) => DropdownMenuItem(
            value: tipo,
            child: Text(tipo, style: const TextStyle(fontSize: 14)),
          )).toList(),
      onChanged: (valor) {
        setState(() {
          _recebedorSelecionado = valor;
        });
      },
    );
  }

  Widget _buildNomeField(String hint) {
    return TextField(
      controller: _nomeObsController,
      style: const TextStyle(color: AppColors.textWhite, fontSize: 14),
      maxLines: 2,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: AppColors.textGrey.withValues(alpha: 0.6), fontSize: 13),
        filled: true,
        fillColor: const Color(0xFF1A2E4A),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: AppColors.textGrey.withValues(alpha: 0.2), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.successGreen, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildSignaturePad() {
    return Listener(
      onPointerDown: (event) {
        setState(() {
          _isSigning = true;
        });
      },
      onPointerUp: (event) {
        setState(() {
          _isSigning = false;
        });
      },
      behavior: HitTestBehavior.translucent,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: _isSigning ? AppColors.successGreen : AppColors.textGrey.withValues(alpha: 0.2),
            width: _isSigning ? 2.0 : 1.0,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SignaturePad(
          key: _signatureKey,
          onChanged: (temAssinatura) {
            if (_assinaturaOk != temAssinatura) {
              setState(() => _assinaturaOk = temAssinatura);
            }
          },
        ),
      ),
    );
  }

  Widget _buildFotoSection() {
    if (_foto != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(_foto!,
                width: double.infinity, height: 140, fit: BoxFit.cover),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => setState(() => _foto = null),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: _mostrarOpcoesImagem,
      child: Container(
        width: double.infinity,
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFF1A2E4A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.textGrey.withValues(alpha: 0.2), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_camera_outlined,
                color: AppColors.textGrey.withValues(alpha: 0.7), size: 20),
            const SizedBox(width: 8),
            Text(
              'Tirar Foto do Pacote',
              style: TextStyle(
                  color: AppColors.textGrey.withValues(alpha: 0.7),
                  fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarOpcoesImagem() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF112240),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.camera_alt_rounded, color: Colors.white),
              title: const Text('Camera',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _tirarFoto();
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library_rounded, color: Colors.white),
              title: const Text('Galeria',
                  style: TextStyle(color: Colors.white)),
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

  Widget _buildChecklist() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF112240),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _checklistItem('Quem recebeu', _recebedorOk),
          if (!_isOutros && !_isLockerOuCorreio) ...[
            const SizedBox(height: 8),
            _checklistItem('Nome preenchido', _nomeOk),
            const SizedBox(height: 8),
            _checklistItem('Assinatura digital', _assinaturaOk),
          ],
        ],
      ),
    );
  }

  Widget _checklistItem(String label, bool ok) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: ok
                ? AppColors.successGreen
                : AppColors.textGrey.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: ok
                ? null
                : Border.all(
                    color: AppColors.textGrey.withValues(alpha: 0.3),
                    width: 1),
          ),
          child: ok
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 13)
              : null,
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: ok ? AppColors.textWhite : AppColors.textGrey,
            fontSize: 13,
            fontWeight: ok ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildBotaoEnvio() {
    final ativo = _formularioValido && !_isLoading;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: ativo
            ? AppColors.successGreen
            : AppColors.textGrey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
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
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : Text(
                    _formularioValido
                        ? 'Confirmar Baixa'
                        : 'Preencha os campos obrigatorios',
                    style: TextStyle(
                      color: _formularioValido
                          ? Colors.white
                          : AppColors.textGrey,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
