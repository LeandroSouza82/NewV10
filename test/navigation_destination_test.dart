import 'package:flutter_test/flutter_test.dart';
import 'package:app_do_motorista/core/utils/navigation_destination.dart';

void main() {
  test('mantém latitude e longitude sem inversão e solicita navegação', () {
    final uri = buildNavigationDestination('Rua Exemplo, 95, São José, SC', -27.6, -48.6, 'maps')!;
    expect(uri.queryParameters['destination'], '-27.6,-48.6');
    expect(uri.queryParameters['dir_action'], 'navigate');
  });
  test('coordenadas inválidas usam o endereço completo com acentos', () {
    const address = 'Rua Exemplo, 95, São José, SC';
    for (final pair in [[double.nan, -48.6], [91.0, -48.6], [-27.6, double.infinity]]) {
      final uri = buildNavigationDestination(address, pair[0], pair[1], 'maps')!;
      expect(uri.queryParameters['destination'], address);
    }
  });
  test('sem destino não abre navegador e preserva preferência Waze', () {
    expect(buildNavigationDestination('', null, null, 'maps'), isNull);
    expect(buildNavigationDestination('', -27.6, -48.6, 'waze')!.queryParameters['ll'], '-27.6,-48.6');
  });
}
