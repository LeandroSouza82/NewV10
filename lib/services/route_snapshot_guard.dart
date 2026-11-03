class RouteSnapshotResult {
  final List<Map<String, dynamic>> routes;
  final bool completed;

  const RouteSnapshotResult(this.routes, this.completed);
}

/// Uma lista vazia não comprova conclusão. Confirma cada saída pelo status.
RouteSnapshotResult reconcileRouteSnapshot({
  required List<Map<String, dynamic>> previous,
  required List<Map<String, dynamic>> active,
  required List<Map<String, dynamic>> confirmed,
  required String driverId,
}) {
  const finished = {'concluido', 'entregue', 'sucesso', 'falha'};
  const removed = {'cancelado', 'arquivado'};
  String id(Map<String, dynamic> row) => row['id'].toString();
  String status(Map<String, dynamic> row) =>
      (row['status'] ?? '').toString().trim().toLowerCase();
  final result = {for (final row in active) id(row): row};
  final verified = {for (final row in confirmed) id(row): row};

  for (final old in previous) {
    if (result.containsKey(id(old))) continue;
    final row = verified[id(old)];
    if (row == null) {
      // Falha de leitura/permissão não deve apagar um pedido conhecido.
      result[id(old)] = old;
      continue;
    }
    final assigned = row['motorista_id']?.toString();
    if (assigned != driverId || finished.contains(status(row)) ||
        removed.contains(status(row))) {
      continue;
    }
    // Ainda pertence ao motorista e não há confirmação de encerramento.
    result[id(old)] = row;
  }

  final completed = previous.isNotEmpty && result.isEmpty &&
      previous.every((old) {
        final row = verified[id(old)];
        return row != null && row['motorista_id']?.toString() == driverId &&
            finished.contains(status(row));
      });
  return RouteSnapshotResult(result.values.toList(), completed);
}
