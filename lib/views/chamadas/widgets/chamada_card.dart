import 'package:flutter/material.dart';
import '../../../models/chamada_model.dart';
import 'package:intl/intl.dart';

class ChamadaCard extends StatefulWidget {
  final ChamadaModel chamada;
  final VoidCallback? onAceitar;
  final VoidCallback? onRecusar;

  const ChamadaCard({
    super.key, 
    required this.chamada,
    this.onAceitar,
    this.onRecusar,
  });

  @override
  State<ChamadaCard> createState() => _ChamadaCardState();
}

class _ChamadaCardState extends State<ChamadaCard> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 0.2, end: 0.6).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.chamada.status == StatusChamada.recebida) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant ChamadaCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.chamada.status == StatusChamada.recebida) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController.stop();
      _pulseController.value = 0.0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // --- Cores Semânticas ---
  Color _getTipoColor() {
    if (widget.chamada.tipo == TipoChamada.multipla) {
      return const Color(0xFFD4A017); // Amarelo/Laranja pra roteiro
    }
    
    switch (widget.chamada.tipoPedido?.toUpperCase()) {
      case 'ENTREGA':
        return const Color(0xFF63B3ED);
      case 'COLETA':
        return const Color(0xFFD4A017);
      case 'OUTROS':
        return const Color(0xFF9F7AEA);
      default:
        return const Color(0xFF63B3ED);
    }
  }

  Color _getBorderColor(double pulseValue) {
    switch (widget.chamada.status) {
      case StatusChamada.recebida:
        return _getTipoColor().withValues(alpha: pulseValue);
      case StatusChamada.visualizada:
        return Colors.white.withValues(alpha: 0.10);
      case StatusChamada.expirada:
        return Colors.red.withValues(alpha: 0.15);
    }
  }

  // --- Widgets Auxiliares ---
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _getTipoColor(),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              widget.chamada.tipo == TipoChamada.multipla 
                  ? 'ROTEIRO' 
                  : (widget.chamada.tipoPedido?.toUpperCase() ?? 'ENTREGA'),
              style: TextStyle(
                color: _getTipoColor(),
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        _buildStatusBadge(),
      ],
    );
  }

  Widget _buildStatusBadge() {
    switch (widget.chamada.status) {
      case StatusChamada.recebida:
        return Row(
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFF48BB78).withValues(alpha: _pulseAnimation.value * 1.5 > 1 ? 1 : _pulseAnimation.value * 1.5),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF48BB78).withValues(alpha: _pulseAnimation.value),
                        blurRadius: 6,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                );
              }
            ),
            const SizedBox(width: 6),
            const Text(
              'Recebida',
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        );
      case StatusChamada.visualizada:
        return const Row(
          children: [
            Icon(Icons.check, color: Colors.white54, size: 14),
            SizedBox(width: 4),
            Text('Visualizada', style: TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        );
      case StatusChamada.expirada:
        return Row(
          children: [
            Icon(Icons.close, color: Colors.red.withValues(alpha: 0.8), size: 14),
            const SizedBox(width: 4),
            Text('Expirada', style: TextStyle(color: Colors.red.withValues(alpha: 0.8), fontSize: 12)),
          ],
        );
    }
  }

  Widget _buildSimplesContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.chamada.cliente ?? '-',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          '${widget.chamada.endereco ?? '-'} · ${widget.chamada.bairro ?? '-'}',
          style: const TextStyle(color: Colors.white70, fontSize: 15),
        ),
        Text(
          widget.chamada.cidade ?? '-',
          style: const TextStyle(color: Colors.white70, fontSize: 15),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFD4A017).withValues(alpha: 0.1),
            border: Border.all(color: const Color(0xFFD4A017), width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.navigation, color: Color(0xFFD4A017), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '➤ ${widget.chamada.distancia?.toStringAsFixed(1) ?? '--'} km da sua posição atual',
                  style: const TextStyle(color: Color(0xFFD4A017), fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMultiplaContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${widget.chamada.totalPedidos ?? 0} PEDIDOS',
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ),
            Text(
              '${widget.chamada.kmTotal?.toStringAsFixed(1) ?? '--'} KM TOTAL',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(color: Colors.white10, height: 1),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
              child: Text('🚚 ${widget.chamada.totalEntregas ?? 0} Entrega', style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFD4A017).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
              child: Text('📦 ${widget.chamada.totalColetas ?? 0} Coleta', style: const TextStyle(color: Color(0xFFD4A017), fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF9F7AEA).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
              child: Text('⚙️ ${widget.chamada.totalOutros ?? 0} Outros', style: const TextStyle(color: Color(0xFF9F7AEA), fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Timeline
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF48BB78), shape: BoxShape.circle)),
                Container(width: 2, height: 26, color: Colors.white24),
                Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFF56565), shape: BoxShape.circle)), // Coral/Red
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (widget.chamada.inicioEndereco != null && 
                     widget.chamada.inicioEndereco!.toLowerCase().contains('ponto') == false && 
                     widget.chamada.inicioEndereco!.trim().isNotEmpty) 
                        ? widget.chamada.inicioEndereco!.trim() 
                        : (widget.chamada.cliente ?? 'Origem').replaceAll('ponto', '').trim(),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text('${(widget.chamada.totalPedidos ?? 2) - 2} paradas intermediárias', 
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text(
                    (widget.chamada.fimEndereco != null && 
                     widget.chamada.fimEndereco!.toLowerCase().contains('ponto') == false && 
                     widget.chamada.fimEndereco!.trim().isNotEmpty) 
                        ? widget.chamada.fimEndereco!.trim() 
                        : (widget.chamada.cliente ?? 'Destino Final').replaceAll('ponto', '').trim(),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        )
      ],
    );
  }



  Widget _buildFooter() {
    final format = DateFormat('HH:mm');
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Botões de Ação (Apenas se as callbacks forem fornecidas)
        if (widget.onAceitar != null || widget.onRecusar != null)
          Expanded(
            child: Row(
              children: [
                if (widget.onRecusar != null)
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: widget.onRecusar,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('RECUSAR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                if (widget.onRecusar != null && widget.onAceitar != null)
                  const SizedBox(width: 8),
                if (widget.onAceitar != null)
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: widget.onAceitar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5FF),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: const Text('ACEITAR ROTA', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          )
        else 
          const Spacer(),
          
        // Horário original
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.access_time, color: Colors.white54, size: 14),
              const SizedBox(width: 4),
              Text(
                format.format(widget.chamada.horario),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMultipla = widget.chamada.tipo == TipoChamada.multipla || (widget.chamada.totalPedidos != null && widget.chamada.totalPedidos! > 1);

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final borderOpacidade = widget.chamada.status == StatusChamada.recebida ? _pulseAnimation.value : 1.0;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2740),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _getBorderColor(borderOpacidade),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(color: Colors.white10, height: 1),
              ),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isMultipla) _buildSimplesContent(),
                      if (isMultipla) _buildMultiplaContent(),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(color: Colors.white10, height: 1),
              ),
              _buildFooter(),
            ],
          ),
        );
      }
    );
  }
}
