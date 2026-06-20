import 'package:flutter_test/flutter_test.dart';

import 'package:app_do_motorista/main.dart';

void main() {
  testWidgets('App renders SplashView', (WidgetTester tester) async {
    await tester.pumpWidget(const AppDoMotorista());

    expect(find.text('V10'), findsOneWidget);
  });
}
