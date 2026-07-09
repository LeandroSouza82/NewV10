import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../services/supabase_service.dart';

class MeuVeiculoView extends StatefulWidget {
  const MeuVeiculoView({super.key});

  @override
  State<MeuVeiculoView> createState() => _MeuVeiculoViewState();
}

class _MeuVeiculoViewState extends State<MeuVeiculoView> {
  final _motoristaId = SupabaseService.currentMotoristaId;
  Map<String, dynamic>? _veiculo;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _carregarVeiculo();
  }

  int _getInt(dynamic val, int padrao) {
    if (val == null) return padrao;
    if (val is int) return val;
    if (val is double) return val.toInt();
    return int.tryParse(val.toString()) ?? padrao;
  }

  Future<void> _carregarVeiculo() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      if (_motoristaId == null) throw Exception('Motorista não logado.');
      
      // Busca o primeiro veículo ativo vinculado a este motorista
      final response = await SupabaseService.client
          .from('veiculos')
          .select()
          .eq('motorista_id', _motoristaId)
          .eq('ativo', true)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _veiculo = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) { debugPrint('Erro ao buscar veículo: $e'); }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _atualizarHodometro(int novoKm) async {
    if (_veiculo == null) return;
    try {
      await SupabaseService.client
          .from('veiculos')
          .update({'km_atual': novoKm})
          .eq('id', _veiculo!['id']);
      
      await _carregarVeiculo();
    } catch (e) {
      if (kDebugMode) { debugPrint('Erro ao atualizar hodômetro: $e'); }
    }
  }

  Future<void> _salvarAbastecimento(double valor, double litros, int km) async {
    try {
      final kmAtual = _getInt(_veiculo?['km_atual'], 0);
      
      // Validação de KM: O KM inserido deve ser maior que o anterior (hodômetro)
      if (_veiculo != null && km <= kmAtual) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('O KM inserido deve ser maior que o anterior para calcular o consumo.'),
              backgroundColor: Colors.orangeAccent,
            ),
          );
        }
        return; // Aborta o salvamento
      }

      final currentUserId = SupabaseService.client.auth.currentUser?.id;

      await SupabaseService.client
          .from('abastecimentos')
          .insert({
            'user_id': currentUserId, // Campo injetado para respeitar RLS e busca
            'motorista_id': _motoristaId, // Mantido por retrocompatibilidade
            'veiculo_id': _veiculo?['id'],
            'valor_total': valor,
            'litros': litros,
            'km_registro': km, // km_registro enviado corretamente
            'created_at': DateTime.now().toIso8601String(),
          });
      
      if (_veiculo != null) {
        await _atualizarHodometro(km);
      } else {
        if (mounted) {
          setState(() {}); // Força o rebuild da tela para atualizar a Stream/UI
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Abastecimento registrado com sucesso!'), backgroundColor: AppColors.successGreen),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) { debugPrint('Erro ao salvar abastecimento: $e'); }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao registrar abastecimento: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _reiniciarCicloHard() async {
    if (_veiculo == null) return;
    try {
      final totalCiclo = _getInt(_veiculo?['km_intervalo_troca'], 1000);

      // 1. Zerar o hodômetro base e próxima troca
      await SupabaseService.client
          .from('veiculos')
          .update({
            'km_atual': 0,
            'km_proxima_troca': totalCiclo
          })
          .eq('id', _veiculo!['id']);
          
      // 2. Apagar os abastecimentos antigos para reiniciar o cálculo de média
      await SupabaseService.client
          .from('abastecimentos')
          .delete()
          .eq('veiculo_id', _veiculo!['id']);

      await _carregarVeiculo();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Sistema zerado! Novo ciclo iniciado a partir de 0 km.'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) { debugPrint('Erro ao reiniciar ciclo: $e'); }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Erro ao reiniciar ciclo: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _mostrarConfirmacaoReiniciar() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: const Text('Reiniciar todos os cálculos?', style: TextStyle(color: AppColors.textWhite)),
          content: const Text(
            'Isso definirá o hodômetro como 0 km, reiniciará a contagem da próxima troca de óleo e limpará o histórico de consumo atual. Deseja começar um novo ciclo?',
            style: TextStyle(color: AppColors.textGrey, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: AppColors.textGrey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(context);
                _reiniciarCicloHard();
              },
              child: const Text('Sim, reiniciar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _mostrarModalHodometro() {
    final currentKm = _getInt(_veiculo?['km_atual'], 0);
    final controller = TextEditingController(text: currentKm > 0 ? currentKm.toString() : '');
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: const Text('Atualizar Hodômetro', style: TextStyle(color: AppColors.textWhite)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.textWhite),
                decoration: const InputDecoration(
                  labelText: 'Novo KM',
                  labelStyle: TextStyle(color: AppColors.textGrey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textGrey)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                ),
              ),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context); // Fecha o modal de hodômetro
                  _mostrarConfirmacaoReiniciar(); // Abre o modal de confirmação
                },
                icon: const Icon(Icons.refresh, color: Colors.orangeAccent, size: 20),
                label: const Text(
                  'Reiniciar Contagem / Trocar Moto',
                  style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: AppColors.textGrey)),
            ),
            TextButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('⚠️ Digite a quilometragem atual que marca no painel da moto.'),
                      backgroundColor: Colors.orangeAccent,
                    ),
                  );
                  return; // Não prossegue com o salvamento
                }

                final novoKm = int.tryParse(text);
                if (novoKm != null) {
                  Navigator.pop(context);
                  _atualizarHodometro(novoKm);
                }
              },
              child: const Text('Salvar', style: TextStyle(color: Colors.blueAccent)),
            ),
          ],
        );
      },
    );
  }

  void _mostrarBottomSheetAbastecimento() {
    final valorController = TextEditingController();
    final litrosController = TextEditingController();
    final currentKm = _getInt(_veiculo?['km_atual'], 0);
    final kmController = TextEditingController(text: currentKm > 0 ? currentKm.toString() : '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundBody,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  const Text(
                    'Registrar Abastecimento',
                    style: TextStyle(color: AppColors.textWhite, fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: valorController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: AppColors.textWhite),
                    decoration: InputDecoration(
                      labelText: 'Valor Total (R\$)',
                      labelStyle: TextStyle(color: AppColors.textGrey.withValues(alpha: 0.8)),
                      filled: true,
                      fillColor: AppColors.cardBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      final val = double.tryParse(value?.replaceAll(',', '.') ?? '') ?? 0;
                      if (val <= 0) return 'Informe o valor gasto';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: litrosController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+[\.,]?\d*')),
                    ],
                    style: const TextStyle(color: AppColors.textWhite),
                    decoration: InputDecoration(
                      labelText: 'Litros (ex: 10,5)',
                      labelStyle: TextStyle(color: AppColors.textGrey.withValues(alpha: 0.8)),
                      filled: true,
                      fillColor: AppColors.cardBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      final val = double.tryParse(value?.replaceAll(',', '.') ?? '') ?? 0;
                      if (val <= 0) return 'Informe a quantidade de litros';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildInputModal('KM no Posto', kmController, TextInputType.number),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      if (!formKey.currentState!.validate()) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('⚠️ Por favor, preencha o valor e os litros antes de registrar.'),
                            backgroundColor: Colors.orangeAccent,
                          ),
                        );
                        return;
                      }

                      final valor = double.tryParse(valorController.text.replaceAll(',', '.')) ?? 0;
                      final litros = double.tryParse(litrosController.text.replaceAll(',', '.')) ?? 0;
                      final km = int.tryParse(kmController.text) ?? 0;

                      if (valor > 0 && litros > 0 && km > 0) {
                        Navigator.pop(context);
                        _salvarAbastecimento(valor, litros, km);
                      }
                    },
                    child: const Text('Confirmar e Salvar', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 32),
                ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputModal(String label, TextEditingController controller, TextInputType keyboardType) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.textWhite),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textGrey.withValues(alpha: 0.8)),
        filled: true,
        fillColor: AppColors.cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBody,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundBody,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Meu Veículo',
          style: TextStyle(color: AppColors.textWhite, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: AppColors.textWhite),
        actions: _veiculo != null
            ? [
                IconButton(
                  icon: const Icon(Icons.swap_horiz, color: Colors.blueAccent),
                  tooltip: 'Trocar Veículo',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          backgroundColor: AppColors.cardBackground,
                          title: const Text('Deseja selecionar outro veículo?', style: TextStyle(color: AppColors.textWhite)),
                          content: const Text(
                            'Isso atualizará o modelo ativo no seu painel. O histórico do veículo atual será mantido, mas um novo ciclo de manutenção será iniciado.',
                            style: TextStyle(color: AppColors.textGrey, height: 1.5),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancelar', style: TextStyle(color: AppColors.textGrey)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                _mostrarBottomSheetCadastroVeiculo();
                              },
                              child: const Text('Sim, Trocar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ]
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : _hasError
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.orangeAccent.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        const Text(
                          '⚠️ Não foi possível carregar a lista de veículos no momento. Tente novamente.',
                          style: TextStyle(color: AppColors.textGrey, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          label: const Text('Recarregar', style: TextStyle(color: Colors.white)),
                          onPressed: _carregarVeiculo,
                        ),
                      ],
                    ),
                  ),
                )
          : _veiculo == null
              ? _buildVeiculoNaoEncontrado()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildVeiculoCard(),
                      const SizedBox(height: 16),
                      _buildOdometroCard(),
                      const SizedBox(height: 16),
                      _buildManutencaoCard(),
                      const SizedBox(height: 16),
                      _buildConsumoCard(),
                    ],
                  ),
                ),
      bottomNavigationBar: _veiculo != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.local_gas_station, color: Colors.white),
                  label: const Text(
                    'Registrar Abastecimento',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _mostrarBottomSheetAbastecimento,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildConsumoCard() {
    final userId = SupabaseService.client.auth.currentUser?.id;

    Stream<List<Map<String, dynamic>>> queryStream;

    if (userId != null && userId.isNotEmpty) {
      queryStream = SupabaseService.client
          .from('abastecimentos')
          .stream(primaryKey: ['id'])
          .eq('motorista_id', userId)
          .order('created_at', ascending: false)
          .limit(2);
    } else {
      queryStream = SupabaseService.client
          .from('abastecimentos')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .limit(2);
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: queryStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          
        } else if (snapshot.hasError) {
          if (kDebugMode) { debugPrint('Erro no Stream do Supabase (ABASTECIMENTOS): ${snapshot.error}'); }
        }
        
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(color: Colors.blueAccent),
          ));
        }
        
        final abastecimentos = snapshot.data ?? [];
        
        String mediaText = 'Nenhum abastecimento registrado ainda.';
        String subText = '';
        
        if (abastecimentos.length == 1) {
          mediaText = 'Primeiro abastecimento salvo.';
          subText = 'Registre o próximo para calcular a média.';
        } else if (abastecimentos.length >= 2) {
          final ultimo = abastecimentos[0];
          final penultimo = abastecimentos[1];
          
          final double valorTotal = double.tryParse((ultimo['valor_total'] ?? 0.0).toString()) ?? 0.0;
          final int kmAtual = int.tryParse((ultimo['km_registro'] ?? 0).toString()) ?? 0;
          final int kmAnterior = int.tryParse((penultimo['km_registro'] ?? 0).toString()) ?? 0;
          final double litros = double.tryParse((ultimo['litros'] ?? 1.0).toString()) ?? 1.0;

          final kmRodados = kmAtual - kmAnterior;
          final mediaKmL = kmRodados > 0 ? (kmRodados / litros) : 0.0;
          final custoKm = kmRodados > 0 ? (valorTotal / kmRodados) : 0.0;
          
          if (kmRodados > 0 && litros > 0) {
            mediaText = 'Média: ${mediaKmL.toStringAsFixed(1)} km/L';
            subText = 'Custo real: R\$ ${custoKm.toStringAsFixed(2)} / km rodado';
          } else {
            mediaText = 'Rodagem insuficiente para cálculo de média.';
            subText = 'Verifique os dados de KM dos abastecimentos.';
          }
        }
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.textGrey.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_gas_station, color: Colors.cyanAccent, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Desempenho e Consumo',
                      style: TextStyle(color: AppColors.textGrey, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mediaText,
                      style: TextStyle(
                        color: abastecimentos.length >= 2 && mediaText.startsWith('Média') ? Colors.cyanAccent : AppColors.textWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (subText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subText,
                        style: TextStyle(color: AppColors.textGrey.withValues(alpha: 0.8), fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _mostrarBottomSheetCadastroVeiculo() {
    final Map<String, List<String>> modelosPorMarca = {
      'Honda': ['CG 160 Titan', 'CG 160 Fan', 'CG 160 Cargo', 'CG 160 Start', 'NXR 160 Bros', 'Biz 125', 'Biz 110i', 'PCX 160', 'CB 300F Twister', 'Sahara 300 / XRE', 'Pop 110i', 'Outro'],
      'Yamaha': ['Crosser 150 Z/S', 'Factor 150', 'Factor 125i', 'Fazer FZ15', 'Fazer FZ25 (250)', 'Lander 250', 'NMAX 160', 'Fluo 125', 'Neo 125', 'YBR 125', 'Outro'],
      'Bajaj': ['Dominar 160', 'Dominar 200', 'Dominar 400', 'Outro'],
      'Mottu': ['Mottu Sport 110i', 'Mottu-E (Elétrica)', 'Outro'],
      'Suzuki': ['Yes 125', 'Intruder 125', 'GSR 150i', 'Burgman 125', 'V-Strom 250', 'Outro'],
      'Haojue': ['DR 160', 'Chopper Road 150', 'Master Ride 150', 'DK 150', 'Lindy 125', 'Outro'],
      'Shineray': ['Worker 125', 'SH 125 / Jef 150s', 'Rio 125', 'Cinqüentinha 50cc', 'Outro'],
      'Dafra': ['Apache RTR 200', 'Cruisym 150', 'NH 190', 'Outro'],
      'BMW': ['G 310 GS', 'G 310 R', 'F 800 GS', 'Outro'],
      'Kawasaki': ['Versys-X 300', 'Z400', 'Ninja 400', 'Outro'],
      'Royal Enfield': ['Hunter 350', 'Meteor 350', 'Himalayan 411/450', 'Outro'],
      'Outra': ['Modelo Genérico / Outro']
    };

    String? marcaSelecionada;
    String? modeloSelecionado;
    String? selectedAno;
    String? selectedCor;
    
    final placaController = TextEditingController();
    final kmController = TextEditingController();
    final outroModeloController = TextEditingController();

    final anos = List.generate(DateTime.now().year - 1990 + 1, (index) => (DateTime.now().year - index).toString());
    final cores = ['Preto', 'Branco', 'Prata', 'Cinza', 'Vermelho', 'Azul', 'Amarelo', 'Verde', 'Laranja', 'Outra'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundBody,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 24),
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Cadastrar Meu Veículo',
                      style: TextStyle(color: AppColors.textWhite, fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('dropdown_marca'),
                      initialValue: marcaSelecionada,
                      isExpanded: true,
                      dropdownColor: Colors.grey[900],
                      style: const TextStyle(color: AppColors.textWhite),
                      decoration: InputDecoration(
                        labelText: 'Marca',
                        labelStyle: TextStyle(color: AppColors.textGrey.withValues(alpha: 0.8)),
                        filled: true,
                        fillColor: AppColors.cardBackground,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      items: modelosPorMarca.keys.map((marca) => DropdownMenuItem(value: marca, child: Text(marca))).toList(),
                      onChanged: (val) {
                        setModalState(() {
                          marcaSelecionada = val;
                          modeloSelecionado = null; // Limpa o modelo para evitar crashes
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('dropdown_modelo'),
                      initialValue: modeloSelecionado,
                      isExpanded: true,
                      dropdownColor: Colors.grey[900],
                      style: const TextStyle(color: AppColors.textWhite),
                      decoration: InputDecoration(
                        labelText: 'Modelo',
                        labelStyle: TextStyle(color: AppColors.textGrey.withValues(alpha: 0.8)),
                        filled: true,
                        fillColor: AppColors.cardBackground,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      items: (modelosPorMarca[marcaSelecionada] ?? []).map((modelo) => DropdownMenuItem(value: modelo, child: Text(modelo))).toList(),
                      onChanged: marcaSelecionada == null ? null : (val) => setModalState(() => modeloSelecionado = val),
                    ),
                    if (modeloSelecionado == 'Outro' || modeloSelecionado == 'Modelo Genérico / Outro') ...[
                      const SizedBox(height: 16),
                      _buildInputModal('Especificar Modelo', outroModeloController, TextInputType.text),
                    ],
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('dropdown_ano'),
                      initialValue: selectedAno,
                      isExpanded: true,
                      dropdownColor: Colors.grey[900],
                      style: const TextStyle(color: AppColors.textWhite),
                      decoration: InputDecoration(
                        labelText: 'Ano',
                        labelStyle: TextStyle(color: AppColors.textGrey.withValues(alpha: 0.8)),
                        filled: true,
                        fillColor: AppColors.cardBackground,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      items: anos.map((ano) => DropdownMenuItem(value: ano, child: Text(ano))).toList(),
                      onChanged: (val) => setModalState(() => selectedAno = val),
                    ),
                    const SizedBox(height: 16),
                    _buildInputModal('Placa', placaController, TextInputType.text),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('dropdown_cor'),
                      initialValue: selectedCor,
                      isExpanded: true,
                      dropdownColor: Colors.grey[900],
                      style: const TextStyle(color: AppColors.textWhite),
                      decoration: InputDecoration(
                        labelText: 'Cor',
                        labelStyle: TextStyle(color: AppColors.textGrey.withValues(alpha: 0.8)),
                        filled: true,
                        fillColor: AppColors.cardBackground,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      items: cores.map((cor) => DropdownMenuItem(value: cor, child: Text(cor))).toList(),
                      onChanged: (val) => setModalState(() => selectedCor = val),
                    ),
                    const SizedBox(height: 16),
                    _buildInputModal('KM Atual (Hodômetro)', kmController, TextInputType.number),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final placa = placaController.text.trim();
                        final km = int.tryParse(kmController.text) ?? 0;
                        
                        String finalModeloStr = modeloSelecionado ?? '';
                        if (finalModeloStr == 'Outro' || finalModeloStr == 'Modelo Genérico / Outro') {
                          finalModeloStr = outroModeloController.text.trim();
                          if (finalModeloStr.isEmpty) finalModeloStr = 'Personalizado';
                        }
                        
                        final String modeloFinalParaSalvar = "${marcaSelecionada ?? ''} - $finalModeloStr";
                        
                        final ano = selectedAno ?? '';
                        final cor = selectedCor ?? '';

                        if (marcaSelecionada != null && modeloSelecionado != null && ano.isNotEmpty && placa.isNotEmpty && cor.isNotEmpty && km > 0) {
                          Navigator.pop(context);
                          await _salvarNovoVeiculo(modeloFinalParaSalvar, ano, placa, cor, km);
                        }
                      },
                      child: const Text('Salvar Veículo', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          );
          },
        );
      },
    );
  }

  Future<void> _salvarNovoVeiculo(String modelo, String ano, String placa, String cor, int kmAtual) async {
    try {
      final String currentId = _motoristaId ?? SupabaseService.client.auth.currentUser?.id ?? 'ID_FALLBACK_TEMPORARIO';

      if (_veiculo != null) {
        // Desativar veículo antigo antes de salvar o novo
        await SupabaseService.client
            .from('veiculos')
            .update({'ativo': false})
            .eq('id', _veiculo!['id']);
      }

      await SupabaseService.client
          .from('veiculos')
          .insert({
            'motorista_id': currentId,
            'modelo': modelo,
            'ano': ano,
            'placa': placa,
            'cor': cor,
            'km_atual': kmAtual,
            'km_proxima_troca': null,
            'km_intervalo_troca': null,
            'ativo': true,
          });
      
      await _carregarVeiculo();
    } catch (e) {
      if (kDebugMode) { debugPrint('Erro ao cadastrar veículo: $e'); }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao cadastrar veículo: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Widget _buildVeiculoNaoEncontrado() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_car_outlined, size: 64, color: AppColors.textGrey.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'Nenhum veículo vinculado.',
            style: TextStyle(color: AppColors.textGrey.withValues(alpha: 0.7), fontSize: 16),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Cadastrar Meu Veículo',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            onPressed: _mostrarBottomSheetCadastroVeiculo,
          ),
        ],
      ),
    );
  }

  Widget _buildVeiculoCard() {
    final modelo = _veiculo?['modelo'] ?? 'Modelo Desconhecido';
    final ano = _veiculo?['ano'] ?? '----';
    final placa = _veiculo?['placa'] ?? 'SEM PLACA';
    final cor = _veiculo?['cor'] ?? 'Não informada';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '$modelo • $ano',
                  style: const TextStyle(color: AppColors.textWhite, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.successGreen.withValues(alpha: 0.5)),
                ),
                child: const Text(
                  'Em Operação',
                  style: TextStyle(color: AppColors.successGreen, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildInfoMiniItem(Icons.credit_card, placa.toString().toUpperCase()),
              const SizedBox(width: 24),
              _buildInfoMiniItem(Icons.color_lens_outlined, cor.toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoMiniItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textGrey, size: 16),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: AppColors.textWhite, fontSize: 14)),
      ],
    );
  }

  Widget _buildOdometroCard() {
    final kmAtual = _getInt(_veiculo?['km_atual'], 0);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('KM Atual (Hodômetro)', style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
              const SizedBox(height: 4),
              Text(
                '${kmAtual.toString()} km',
                style: const TextStyle(color: AppColors.textWhite, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          IconButton(
            onPressed: _mostrarModalHodometro,
            icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent),
            tooltip: 'Atualizar KM',
          ),
        ],
      ),
    );
  }

  Future<void> _salvarConfiguracaoOleo(int intervalo) async {
    try {
      final veiculoId = _veiculo?['id'];
      if (veiculoId == null) return;
      
      final kmAtual = _getInt(_veiculo?['km_atual'], 0);
      final proximaTroca = kmAtual + intervalo;

      await SupabaseService.client
          .from('veiculos')
          .update({
            'km_intervalo_troca': intervalo,
            'km_proxima_troca': proximaTroca,
          })
          .eq('id', veiculoId);
          
      await _carregarVeiculo();
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Configuração de troca de óleo atualizada com sucesso!'), 
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Não foi possível salvar a configuração agora. Verifique sua conexão e tente novamente.'), 
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
    }
  }

  void _mostrarModalConfigurarOleo() {
    int intervaloSelecionado = _getInt(_veiculo?['km_intervalo_troca'], 1000);
    final personalizadoController = TextEditingController();
    final opcoes = [1000, 1500, 2000, 2500, 3000];
    bool isPersonalizado = !opcoes.contains(intervaloSelecionado);
    
    if (isPersonalizado) {
      personalizadoController.text = intervaloSelecionado.toString();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundBody,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16.0),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Configurar Troca de Óleo',
                        style: TextStyle(color: AppColors.textWhite, fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: opcoes.map((valor) {
                          final selected = !isPersonalizado && intervaloSelecionado == valor;
                          return ChoiceChip(
                            label: Text('$valor km'),
                            selected: selected,
                            selectedColor: Colors.blueAccent.withValues(alpha: 0.3),
                            backgroundColor: AppColors.cardBackground,
                            labelStyle: TextStyle(color: selected ? Colors.blueAccent : AppColors.textGrey, fontWeight: selected ? FontWeight.bold : FontWeight.normal),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: selected ? Colors.blueAccent : Colors.white10),
                            ),
                            onSelected: (val) {
                              setModalState(() {
                                isPersonalizado = false;
                                intervaloSelecionado = valor;
                              });
                            },
                          );
                        }).toList()
                          ..add(
                            ChoiceChip(
                              label: const Text('Personalizado'),
                              selected: isPersonalizado,
                              selectedColor: Colors.blueAccent.withValues(alpha: 0.3),
                              backgroundColor: AppColors.cardBackground,
                              labelStyle: TextStyle(color: isPersonalizado ? Colors.blueAccent : AppColors.textGrey, fontWeight: isPersonalizado ? FontWeight.bold : FontWeight.normal),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: isPersonalizado ? Colors.blueAccent : Colors.white10),
                              ),
                              onSelected: (val) {
                                setModalState(() {
                                  isPersonalizado = true;
                                });
                              },
                            )
                          ),
                      ),
                      if (isPersonalizado) ...[
                        const SizedBox(height: 24),
                        TextField(
                          controller: personalizadoController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: const TextStyle(color: AppColors.textWhite),
                          decoration: InputDecoration(
                            labelText: 'Intervalo Personalizado (km)',
                            labelStyle: TextStyle(color: AppColors.textGrey.withValues(alpha: 0.8)),
                            filled: true,
                            fillColor: AppColors.cardBackground,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          onChanged: (val) {
                            intervaloSelecionado = int.tryParse(val) ?? 0;
                          },
                        ),
                      ],
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          if (intervaloSelecionado > 0) {
                            _salvarConfiguracaoOleo(intervaloSelecionado);
                          }
                        },
                        child: const Text('Salvar Configuração', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildManutencaoCard() {
    final kmAtual = _getInt(_veiculo?['km_atual'], 0);
    
    if (_veiculo?['km_intervalo_troca'] == null || _veiculo?['km_proxima_troca'] == null) {
      return GestureDetector(
        onTap: _mostrarModalConfigurarOleo,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.textGrey.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.build_circle_outlined, color: AppColors.textGrey, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Próxima Troca de Óleo',
                        style: TextStyle(color: AppColors.textGrey, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _mostrarModalConfigurarOleo,
                    icon: const Icon(Icons.settings_outlined, color: AppColors.textGrey, size: 20),
                    tooltip: 'Configurar Troca de Óleo',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 0.0,
                  backgroundColor: AppColors.textGrey.withValues(alpha: 0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.textGrey),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pendente',
                    style: TextStyle(color: AppColors.textGrey, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  Flexible(
                    child: Text(
                      '⚙️ Toque para definir a troca',
                      style: TextStyle(color: AppColors.textWhite, fontSize: 13, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final totalCiclo = _getInt(_veiculo?['km_intervalo_troca'], 1000); 
    final kmTroca = _getInt(_veiculo?['km_proxima_troca'], kmAtual + totalCiclo);
    
    final int diff = kmTroca - kmAtual;
    
    Color statusColor;
    String statusTitle;
    String statusSubtitle;
    
    if (diff <= 0) {
      statusColor = Colors.redAccent;
      statusTitle = 'Óleo Vencido!';
      statusSubtitle = 'Troque imediatamente';
    } else if (diff <= 200) {
      statusColor = Colors.orangeAccent;
      statusTitle = 'ATENÇÃO: Troca próxima';
      statusSubtitle = 'Faltam $diff km';
    } else {
      statusColor = AppColors.successGreen;
      statusTitle = 'Tudo em ordem';
      statusSubtitle = 'Faltam $diff km';
    }
    
    int rodadoNoCiclo = totalCiclo - (diff > 0 ? diff : 0);
    if (rodadoNoCiclo < 0) rodadoNoCiclo = 0;
    
    final double progresso = totalCiclo > 0 ? (rodadoNoCiclo / totalCiclo).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.build_circle_outlined, color: statusColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Próxima Troca de Óleo',
                    style: TextStyle(color: statusColor, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _mostrarModalConfigurarOleo,
                icon: const Icon(Icons.settings_outlined, color: AppColors.textGrey, size: 20),
                tooltip: 'Configurar Troca de Óleo',
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progresso,
              backgroundColor: AppColors.textGrey.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                statusTitle,
                style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Text(
                statusSubtitle,
                style: const TextStyle(color: AppColors.textWhite, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
