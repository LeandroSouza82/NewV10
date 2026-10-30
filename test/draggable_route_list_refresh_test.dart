import 'package:app_do_motorista/core/utils/location_utils.dart';
import 'package:app_do_motorista/widgets/draggable_route_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = DistanciaService.instance;

  List<Map<String, dynamic>> routes() => [
    {
      'id': 'a',
      'cliente': 'Cliente A',
      'endereco': 'Rua A, 10',
      'distancia': 1.0,
    },
    {
      'id': 'b',
      'cliente': 'Cliente B',
      'endereco': 'Rua B, 20',
      'distancia': 8.0,
    },
  ];

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DraggableRouteList(rotasIniciais: routes())),
      ),
    );
    await tester.pump();
  }

  Future<void> publish(WidgetTester tester) async {
    service.distanciasNotifier.value = {'a': '5.0 km', 'b': '~2.5 km'};
    await tester.pump();
  }

  double top(WidgetTester tester, String name) =>
      tester.getTopLeft(find.text(name)).dy;

  setUp(service.resetar);
  tearDown(service.resetar);

  testWidgets('refresh aguarda distancias que chegam depois de 500 ms', (
    tester,
  ) async {
    await mount(tester);
    final indicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    var finished = false;
    final refresh = indicator.onRefresh().then((_) => finished = true);

    await tester.pump(const Duration(milliseconds: 800));
    expect(finished, isFalse);
    expect(top(tester, 'Cliente A'), lessThan(top(tester, 'Cliente B')));

    await publish(tester);
    await refresh;
    expect(finished, isTrue);
    expect(top(tester, 'Cliente B'), lessThan(top(tester, 'Cliente A')));
    expect(find.text('~2.5 km'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GPS passivo atualiza os valores sem trocar a ordem dos cards', (
    tester,
  ) async {
    await mount(tester);
    await publish(tester);
    expect(top(tester, 'Cliente A'), lessThan(top(tester, 'Cliente B')));
    expect(find.text('5.0 km'), findsOneWidget);
  });

  testWidgets('lista curta permite o gesto real de puxar para atualizar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester);
    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    expect(list.physics, isA<AlwaysScrollableScrollPhysics>());

    await tester.drag(find.text('Cliente A'), const Offset(0, 700));
    // Inicia e conclui a animação de encaixe antes de publicar a resposta.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester
          .widget<RefreshProgressIndicator>(
            find.byType(RefreshProgressIndicator),
          )
          .value,
      isNull,
    );
    await publish(tester);
    await tester.pumpAndSettle();
    expect(top(tester, 'Cliente B'), lessThan(top(tester, 'Cliente A')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('resultado parcial nao encerra a ordenacao da lista atual', (
    tester,
  ) async {
    await mount(tester);
    final indicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    var finished = false;
    final refresh = indicator.onRefresh().then((_) => finished = true);
    service.distanciasNotifier.value = {'a': '5.0 km'};
    await tester.pump();
    expect(finished, isFalse);
    await publish(tester);
    await refresh;
    expect(top(tester, 'Cliente B'), lessThan(top(tester, 'Cliente A')));
  });

  testWidgets('arrastar manualmente prevalece sobre refresh atrasado', (
    tester,
  ) async {
    await mount(tester);
    final indicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    final refresh = indicator.onRefresh();
    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    list.onReorder(1, 0);
    await tester.pump();
    await refresh;

    service.distanciasNotifier.value = {'a': '1.0 km', 'b': '8.0 km'};
    await tester.pump();
    expect(top(tester, 'Cliente B'), lessThan(top(tester, 'Cliente A')));
  });

  testWidgets('sem resultado libera indicador e aceita distancias tardias', (
    tester,
  ) async {
    await mount(tester);
    final indicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    final refresh = indicator.onRefresh();
    await tester.pump(const Duration(seconds: 21));
    await refresh;
    expect(
      find.textContaining('As distâncias ainda não atualizaram'),
      findsOneWidget,
    );

    await publish(tester);
    expect(top(tester, 'Cliente B'), lessThan(top(tester, 'Cliente A')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('sair da tela durante refresh conclui a espera com seguranca', (
    tester,
  ) async {
    await mount(tester);
    final indicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    final refresh = indicator.onRefresh();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await refresh;
    service.distanciasNotifier.value = {'a': '5.0 km', 'b': '2.5 km'};
    await tester.pump(const Duration(seconds: 21));
    expect(tester.takeException(), isNull);
  });
}
