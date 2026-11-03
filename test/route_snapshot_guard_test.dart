import 'package:flutter_test/flutter_test.dart';
import 'package:app_do_motorista/services/route_snapshot_guard.dart';

void main() {
  Map<String, dynamic> route(String id, String status, {String driver = 'driver'}) =>
      {'id': id, 'status': status, 'motorista_id': driver};

  RouteSnapshotResult reconcile(List<Map<String, dynamic>> confirmed,
      {List<Map<String, dynamic>>? active}) => reconcileRouteSnapshot(
        previous: [route('2288', 'em_rota')],
        active: active ?? [], confirmed: confirmed, driverId: 'driver');

  test('lista vazia mantém Positano quando o banco ainda indica em_rota', () {
    final result = reconcile([route('2288', 'em_rota')]);
    expect(result.routes.single['id'], '2288');
    expect(result.completed, false);
  });

  test('leitura sem confirmação não apaga pedido nem anuncia conclusão', () {
    final result = reconcile([]);
    expect(result.routes.single['id'], '2288');
    expect(result.completed, false);
  });

  test('conclusão confirmada remove o pedido e permite o som uma vez', () {
    final result = reconcile([route('2288', 'concluido')]);
    expect(result.routes, isEmpty);
    expect(result.completed, true);
    final next = reconcileRouteSnapshot(previous: result.routes,
        active: [], confirmed: [], driverId: 'driver');
    expect(next.completed, false);
  });

  test('cancelamento, arquivamento e troca de motorista saem sem som de sucesso', () {
    for (final row in [route('2288', 'cancelado'), route('2288', 'arquivado'),
        route('2288', 'em_rota', driver: 'other')]) {
      final result = reconcile([row]);
      expect(result.routes, isEmpty);
      expect(result.completed, false);
    }
  });

  test('resposta parcial mantém os cards ainda ativos e inclui novos', () {
    final result = reconcileRouteSnapshot(
      previous: [route('1', 'em_rota'), route('2', 'em_rota')],
      active: [route('1', 'em_rota'), route('3', 'em_rota')],
      confirmed: [route('2', 'em_rota')], driverId: 'driver');
    expect(result.routes.map((row) => row['id']).toSet(), {'1', '2', '3'});
    expect(result.completed, false);
  });
}
