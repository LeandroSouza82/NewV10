enum TipoChamada { simples, multipla }
enum StatusChamada { recebida, visualizada, expirada }

class ChamadaModel {
  final String id;
  final TipoChamada tipo;
  final StatusChamada status;
  final DateTime horario;
  
  // Para rota simples
  final String? tipoPedido;    // ENTREGA, COLETA, OUTROS
  final String? cliente;
  final String? endereco;
  final String? bairro;
  final String? cidade;
  final double? distancia;
  
  // Para rota múltipla
  final int? totalPedidos;
  final double? kmTotal;
  final int? totalEntregas;
  final int? totalColetas;
  final int? totalOutros;
  final String? inicioCliente;
  final String? inicioEndereco;
  final String? fimCliente;
  final String? fimEndereco;

  ChamadaModel({
    required this.id,
    required this.tipo,
    required this.status,
    required this.horario,
    this.tipoPedido,
    this.cliente,
    this.endereco,
    this.bairro,
    this.cidade,
    this.distancia,
    this.totalPedidos,
    this.kmTotal,
    this.totalEntregas,
    this.totalColetas,
    this.totalOutros,
    this.inicioCliente,
    this.inicioEndereco,
    this.fimCliente,
    this.fimEndereco,
  });

  factory ChamadaModel.fromJson(Map<String, dynamic> json) {
    final String id = json['id']?.toString() ?? '';
    final String tipoOriginal = json['tipo']?.toString().toUpperCase() ?? 'ENTREGA';
    
    // a) Verifique se existe uma lista/array de pedidos
    int contagemListas = 0;
    if (json['pedidos'] is List) {
      contagemListas = (json['pedidos'] as List).length;
    } else if (json['paradas'] is List) contagemListas = (json['paradas'] as List).length;
    else if (json['entregas'] is List) contagemListas = (json['entregas'] as List).length;

    // b) Verifique variações de chaves numéricas
    int totalPedidos = contagemListas > 0 ? contagemListas : 1;
    if (totalPedidos <= 1) {
      final rawTotal = json['totalPedidos'] ?? json['total_pedidos'] ?? json['qtd_pedidos'];
      if (rawTotal != null) {
        totalPedidos = int.tryParse(rawTotal.toString()) ?? 1;
      }
    }

    // c) Verifique chaves booleanas/string
    final bool isRoteiroExplicit = json['isRoteiro'] == true || 
                                   json['is_roteiro'] == true || 
                                   json['tipo'] == 'multipla' || 
                                   json['tipo_chamada'] == 'multipla' || 
                                   tipoOriginal == 'ROTEIRO';

    final bool isRoteiro = isRoteiroExplicit || totalPedidos > 1;
    if (isRoteiro && totalPedidos <= 1) {
      totalPedidos = 2; // Força no mínimo 2 pedidos se a flag de roteiro estiver ativada mas a contagem faltar
    }
    
    final String tipoTag = (tipoOriginal.contains('COLETA') || tipoOriginal.contains('RECOLHA')) 
        ? 'COLETA' : (tipoOriginal.contains('OUTROS') ? 'OUTROS' : 'ENTREGA');

    double distCalc = json['distancia'] != null ? (double.tryParse(json['distancia'].toString()) ?? 0.0) : 0.0;

    String? limparEnd(dynamic val) {
      if (val == null) return null;
      final s = val.toString().trim();
      if (s.isEmpty || s == '.') return null;
      return s;
    }

    return ChamadaModel(
      id: id,
      tipo: isRoteiro ? TipoChamada.multipla : TipoChamada.simples,
      status: StatusChamada.recebida,
      horario: DateTime.now(),
      tipoPedido: tipoTag,
      cliente: json['cliente']?.toString() ?? 'Nova Rota Recebida',
      endereco: json['endereco']?.toString() ?? 'Endereço não informado',
      bairro: json['bairro']?.toString() ?? '',
      cidade: json['cidade']?.toString() ?? '',
      distancia: distCalc,
      totalPedidos: totalPedidos,
      kmTotal: json['km_total'] != null ? double.tryParse(json['km_total'].toString()) : distCalc,
      totalEntregas: json['total_entregas'] != null 
          ? (int.tryParse(json['total_entregas'].toString()) ?? 0) 
          : (isRoteiro ? totalPedidos : (tipoTag == 'ENTREGA' ? 1 : 0)),
      totalColetas: json['total_coletas'] != null ? int.tryParse(json['total_coletas'].toString()) : (tipoTag == 'COLETA' ? 1 : 0),
      totalOutros: json['total_outros'] != null ? int.tryParse(json['total_outros'].toString()) : (tipoTag == 'OUTROS' ? 1 : 0),
      inicioCliente: json['inicio_cliente']?.toString(),
      inicioEndereco: limparEnd(json['inicio_endereco']) ?? limparEnd(json['origem']) ?? limparEnd(json['endereco']),
      fimCliente: json['fim_cliente']?.toString(),
      fimEndereco: limparEnd(json['fim_endereco']) ?? limparEnd(json['destino']),
    );
  }
}
