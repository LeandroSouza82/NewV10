import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ModalOcorrencia
// Formulário de registro de ocorrência com número do gestor persistido.
// ─────────────────────────────────────────────────────────────────────────────
class ModalOcorrencia extends StatefulWidget {
  final String entregaId;
  final String nomeCliente;
  final String endereco;

  const ModalOcorrencia({
    super.key,
    required this.entregaId,
    required this.nomeCliente,
    required this.endereco,
  });

  /// Abre o modal como BottomSheet e retorna true se a ocorrência foi salva.
  static Future<bool> mostrar(
    BuildContext context, {
    required String entregaId,
    required String nomeCliente,
    required String endereco,
  }) async {
    final messenger = ScaffoldMessenger.of(context);

    final resultado = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ModalOcorrencia(
        entregaId: entregaId,
        nomeCliente: nomeCliente,
        endereco: endereco,
      ),
    );

    if (resultado == true) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Ocorrência registrada com sucesso!'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    return resultado ?? false;
  }

  @override
  State<ModalOcorrencia> createState() => _ModalOcorrenciaState();
}

// ─────────────────────────────────────────────────────────────────────────────
class _ModalOcorrenciaState extends State<ModalOcorrencia> {
  static const _keyNumeroGestor = 'numero_gestor';

  static const List<String> _motivos = [
    'Cliente Ausente',
    'Área de Risco',
    'Endereço não localizado',
    'Endereço Incorreto',
    'Ata não registrada',
    'Falta de documentos físicos',
    'Não deixou o documento',
    'Sem documento para coletar',
    'Interfone quebrado',
    'Sem caixa de correio',
    'Outros',
  ];

  final _formKey = GlobalKey<FormState>();
  final _descricaoController = TextEditingController();
  final _gestorController = TextEditingController();
  String? _motivoSelecionado;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregarNumeroGestor();
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _gestorController.dispose();
    super.dispose();
  }

  Future<void> _carregarNumeroGestor() async {
    final prefs = await SharedPreferences.getInstance();
    final numero = prefs.getString(_keyNumeroGestor) ?? '';
    if (mounted) setState(() => _gestorController.text = numero);
  }

  Future<void> _salvarNumeroGestor(String numero) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNumeroGestor, numero.trim());
  }



  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Padding(
      // Sobe o conteúdo junto com o teclado — sem overflow
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF112240),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Handle ────────────────────────────────────────────────
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Cabeçalho ─────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.report_problem_rounded,
                        color: Colors.orangeAccent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Registrar Ocorrência',
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Dados do Cliente ───────────────────────────────────────
                if (widget.nomeCliente.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person_outline, size: 16, color: AppColors.textGrey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.nomeCliente,
                                style: const TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        if (widget.endereco.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textGrey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.endereco,
                                  style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ]
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Número do Gestor ───────────────────────────────────────
                TextFormField(
                  controller: _gestorController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 11,
                  style: const TextStyle(
                      color: AppColors.textWhite, fontSize: 14),
                  decoration: _inputDeco(
                    'Número do Gestor (DDD + número)',
                    Icons.chat_rounded,
                  ).copyWith(
                    counterText: '',
                    suffixIcon: Icon(
                      Icons.save_rounded,
                      size: 16,
                      color: AppColors.textGrey.withValues(alpha: 0.5),
                    ),
                  ),
                  onChanged: _salvarNumeroGestor,
                ),
                const SizedBox(height: 16),

                // ── Dropdown de Motivo ─────────────────────────────────────
                DropdownButtonFormField<String>(
                  initialValue: _motivoSelecionado,
                  dropdownColor: const Color(0xFF1A3358),
                  style: const TextStyle(
                      color: AppColors.textWhite, fontSize: 14),
                  iconEnabledColor: AppColors.textGrey,
                  decoration: _inputDeco(
                      'Tipo de Ocorrência', Icons.category_outlined),
                  hint: const Text(
                    'Selecione o motivo',
                    style:
                        TextStyle(color: AppColors.textGrey, fontSize: 14),
                  ),
                  items: _motivos
                      .map((m) =>
                          DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _motivoSelecionado = v),
                  validator: (v) =>
                      v == null ? 'Selecione um tipo de ocorrência' : null,
                ),
                const SizedBox(height: 16),

                // ── Descrição ──────────────────────────────────────────────
                TextFormField(
                  controller: _descricaoController,
                  maxLines: 3,
                  style: const TextStyle(
                      color: AppColors.textWhite, fontSize: 14),
                  decoration: _inputDeco(
                    'Descrição (opcional)',
                    Icons.notes_rounded,
                  ).copyWith(alignLabelWithHint: true),
                ),

                // ── Aviso WhatsApp ─────────────────────────────────────────
                if (_gestorController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.chat_rounded,
                          size: 13, color: Colors.greenAccent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Será enviado para o gestor via WhatsApp ao salvar.',
                          style: TextStyle(
                            color: AppColors.textGrey.withValues(alpha: 0.8),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 28),

                // ── Botões ─────────────────────────────────────────────────
                Row(
                  children: [
                    // Cancelar
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _salvando
                            ? null
                            : () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textGrey,
                          side: BorderSide(
                            color:
                                AppColors.textGrey.withValues(alpha: 0.3),
                          ),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Salvar
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _salvando
                            ? null
                            : () async {
                                if (!_formKey.currentState!.validate()) return;
                                setState(() => _salvando = true);
                                try {
                                  // 1. Log para confirmar que o clique passou da trava de layout
                                  

                                  await _salvarNumeroGestor(_gestorController.text);

                                  // 2. Tentar inserir no Supabase
                                  await Supabase.instance.client.from('ocorrencias').insert({
                                    if (widget.entregaId.isNotEmpty) 'entrega_id': widget.entregaId,
                                    'tipo_ocorrencia': _motivoSelecionado,
                                    'descricao': _descricaoController.text,
                                    'status': 'pendente',
                                  });
                                  

                                  // 3. Montar e abrir o WhatsApp
                                  final String telefoneInput = _gestorController.text.trim();
                                  if (telefoneInput.isNotEmpty) {
                                    final String telefoneLimpo = telefoneInput.replaceAll(RegExp(r'\D'), '');
                                    final String numeroFinal = telefoneLimpo.startsWith('55') ? telefoneLimpo : '55$telefoneLimpo';
                                    
                                    final String msg = '🚨 *Ocorrência registrada!*\n\n'
                                        '*Cliente:* ${widget.nomeCliente}\n'
                                        '*Endereço:* ${widget.endereco}\n'
                                        '*ID Entrega:* ${widget.entregaId}\n'
                                        '*Motivo:* $_motivoSelecionado\n'
                                        '*Detalhe:* ${_descricaoController.text}';
                                    final Uri url = Uri.parse('https://wa.me/$numeroFinal?text=${Uri.encodeComponent(msg)}');
                                    
                                    if (await canLaunchUrl(url)) {
                                      await launchUrl(
                                        url, 
                                        mode: LaunchMode.externalNonBrowserApplication, // Tenta abrir direto no app
                                      );
                                    } else {
                                      // Se falhar no modo estrito, tenta o modo padrão de qualquer forma
                                      await launchUrl(url, mode: LaunchMode.externalApplication);
                                    }
                                  }

                                  // 4. Fechar o modal
                                  if (context.mounted) Navigator.pop(context, true);

                                } catch (e) {
                                  // ESTE BALÃO VAI TE DIZER O ERRO REAL
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Erro: ${e.toString()}'), backgroundColor: Colors.red),
                                    );
                                  }
                                  if (kDebugMode) { debugPrint("ERRO CAPTURADO: $e"); }
                                } finally {
                                  if (mounted) setState(() => _salvando = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orangeAccent,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor:
                              Colors.orangeAccent.withValues(alpha: 0.4),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _salvando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black54,
                                ),
                              )
                            : const Text('Salvar Ocorrência'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  InputDecoration _inputDeco(String label, IconData icone) {
    return InputDecoration(
      labelText: label,
      labelStyle:
          const TextStyle(color: AppColors.textGrey, fontSize: 13),
      prefixIcon: Icon(icone, color: AppColors.textGrey, size: 20),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.orangeAccent.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }
}
