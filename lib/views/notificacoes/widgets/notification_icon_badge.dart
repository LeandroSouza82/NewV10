import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';
import '../../../services/supabase_service.dart';

class NotificationIconBadge extends StatefulWidget {
  final Widget child;

  const NotificationIconBadge({
    super.key,
    required this.child,
  });

  @override
  State<NotificationIconBadge> createState() => _NotificationIconBadgeState();
}

class _NotificationIconBadgeState extends State<NotificationIconBadge> {
  final _motoristaId = SupabaseService.currentMotoristaId;

  Stream<int> _naoLidasStream() {
    if (_motoristaId == null) return Stream.value(0);
    return SupabaseService.client
        .from('avisos_gestor')
        .stream(primaryKey: ['id'])
        .map((lista) {
          return lista.where((aviso) {
            final motId = aviso['motorista_id'];
            final paraMim = motId == _motoristaId || motId == null;
            final lida = aviso['lida'] == true;
            return paraMim && !lida;
          }).length;
        });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _naoLidasStream(),
      builder: (context, snapshot) {
        final int count = snapshot.data ?? 0;

        if (count == 0) return widget.child;

        return Badge(
          label: Text(
            count > 9 ? '9+' : count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.redAccent,
          child: widget.child,
        );
      },
    );
  }
}
