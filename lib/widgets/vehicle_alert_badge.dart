import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class VehicleAlertBadge extends StatefulWidget {
  final Widget child;

  const VehicleAlertBadge({super.key, required this.child});

  @override
  State<VehicleAlertBadge> createState() => _VehicleAlertBadgeState();
}

class _VehicleAlertBadgeState extends State<VehicleAlertBadge> {
  final _motoristaId = SupabaseService.currentMotoristaId;

  Stream<bool> _alertaVeiculoStream() {
    final String? motId = _motoristaId;
    if (motId == null) return Stream.value(false);
    return SupabaseService.client
        .from('veiculos')
        .stream(primaryKey: ['id'])
        .eq('motorista_id', motId)
        .map((lista) {
          final ativos = lista.where((v) => v['ativo'] == true).toList();
          if (ativos.isEmpty) return false;
          final veiculo = ativos.first;
          final int kmAtual = veiculo['km_atual'] is int
              ? veiculo['km_atual']
              : int.tryParse(veiculo['km_atual']?.toString() ?? '0') ?? 0;
          
          final int kmTroca = veiculo['km_proxima_troca'] is int
              ? veiculo['km_proxima_troca']
              : int.tryParse(veiculo['km_proxima_troca']?.toString() ?? '0') ?? (kmAtual + 1000);
              
          final diff = kmTroca - kmAtual;
          return diff <= 200; // Alerta se faltar 200km ou menos
        });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _alertaVeiculoStream(),
      builder: (context, snapshot) {
        final hasAlert = snapshot.data ?? false;

        if (!hasAlert) return widget.child;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            widget.child,
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.orangeAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class VehicleDrawerBadge extends StatefulWidget {
  const VehicleDrawerBadge({super.key});

  @override
  State<VehicleDrawerBadge> createState() => _VehicleDrawerBadgeState();
}

class _VehicleDrawerBadgeState extends State<VehicleDrawerBadge> {
  final _motoristaId = SupabaseService.currentMotoristaId;

  Stream<Color?> _statusVeiculoStream() {
    final String? motId = _motoristaId;
    if (motId == null) return Stream.value(null);
    return SupabaseService.client
        .from('veiculos')
        .stream(primaryKey: ['id'])
        .eq('motorista_id', motId)
        .map((lista) {
          final ativos = lista.where((v) => v['ativo'] == true).toList();
          if (ativos.isEmpty) return null;
          final veiculo = ativos.first;
          final int kmAtual = veiculo['km_atual'] is int
              ? veiculo['km_atual']
              : int.tryParse(veiculo['km_atual']?.toString() ?? '0') ?? 0;
          
          final int kmTroca = veiculo['km_proxima_troca'] is int
              ? veiculo['km_proxima_troca']
              : int.tryParse(veiculo['km_proxima_troca']?.toString() ?? '0') ?? (kmAtual + 1000);
              
          final diff = kmTroca - kmAtual;
          if (diff <= 0) return Colors.redAccent;
          if (diff <= 200) return Colors.orangeAccent;
          return null;
        });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Color?>(
      stream: _statusVeiculoStream(),
      builder: (context, snapshot) {
        final color = snapshot.data;
        if (color == null) return const SizedBox.shrink();

        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
