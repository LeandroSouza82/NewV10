import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:app_do_motorista/core/app_environment.dart';
import 'package:app_do_motorista/services/shared_test_client.dart';

void main() {
  const driver = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  const origin = 'https://uqxoadxqcwidxqsfayem.supabase.co';
  AppEnvironment config({bool enabled = true, String id = driver}) => AppEnvironment.fromValues(
      flavor: 'homologacao', projectRef: AppEnvironment.productionProjectRef,
      url: origin, publicKey: 'sb_publishable_fake', sharedTest: enabled, testDriverId: id);
  test('shared database is opt-in and requires a dedicated driver', () {
    expect(() => config(enabled: false), throwsFormatException);
    expect(() => config(id: ''), throwsFormatException);
    expect(config().isSharedTest, isTrue);
  });
  test('reads and writes include test card filter and preserve requested IDs', () async {
    final calls = <http.Request>[];
    final client = SharedTestClient(config(), client: MockClient((request) async {
      calls.add(request);return http.Response('[]',200);
    }));
    await client.get(Uri.parse('$origin/rest/v1/entregas?motorista_id=eq.$driver'));
    await client.patch(Uri.parse('$origin/rest/v1/entregas?id=eq.12'), body: jsonEncode({'status':'concluido'}));
    for (final request in calls) {
      expect(request.url.queryParameters['cliente'], 'ilike.TESTE V10 - *');
    }
    expect(calls.last.url.queryParameters['id'], 'eq.12');
    expect(jsonDecode(calls.last.body)['status'], 'concluido');
    client.close();
  });
  test('real driver login and presence are additionally filtered by configured test driver', () async {
    late http.Request captured;
    final client=SharedTestClient(config(),client:MockClient((request) async {captured=request;return http.Response('[]',200);}));
    await client.patch(Uri.parse('$origin/rest/v1/motoristas?id=eq.other'),body:'{"esta_online":true}');
    expect(captured.url.queryParametersAll['id'],['eq.other','eq.$driver']);
    expect(captured.url.queryParameters['nome'],'ilike.TESTE V10 - *');
    client.close();
  });
  test('wide writes, unrelated tables and files never reach network', () async {
    var calls=0;
    final client=SharedTestClient(config(),client:MockClient((request) async {calls++;return http.Response('[]',200);}));
    for(final path in ['/rest/v1/entregas','/rest/v1/logs_roteirizacao?id=eq.1','/rest/v1/rpc/reset','/storage/v1/object/entregas/other/photo.jpg']) {
      await expectLater(client.patch(Uri.parse(origin+path),body:'{}'),throwsA(isA<http.ClientException>()));
    }
    expect(calls,0);
    await client.post(Uri.parse('$origin/storage/v1/object/entregas/$driver/photo.jpg'),body:[1,2]);
    expect(calls,1);
    client.close();
  });
  test('real cached card is distinguished from marked test card', () {
    expect(isTestCard({'cliente':'Cliente real'}),isFalse);
    expect(isTestCard({'cliente':'TESTE V10 - Teste 1'}),isTrue);
  });
}
