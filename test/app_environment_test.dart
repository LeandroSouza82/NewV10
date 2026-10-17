import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_do_motorista/core/app_environment.dart';

void main() {
  const ref = 'homologacaoficticia';
  String key(String project, [String role = 'anon']) => 'header.${base64Url.encode(utf8.encode(jsonEncode({'ref': project, 'role': role})))}.signature';
  AppEnvironment config({String flavor = 'teste', String project = ref, String? url, String? publicKey}) =>
      AppEnvironment.fromValues(flavor: flavor, projectRef: project,
          url: url ?? 'https://$project.supabase.co', publicKey: publicKey ?? key(project));

  test('missing configuration or flavor never falls back to production', () {
    expect(() => AppEnvironment.fromValues(flavor: '', projectRef: '', url: '', publicKey: ''), throwsFormatException);
    expect(() => config(project: ''), throwsFormatException);
    expect(() => config(publicKey: ''), throwsFormatException);
    expect(() => config(flavor: 'unknown'), throwsFormatException);
  });
  test('test flavor cannot connect to production', () {
    expect(() => config(project: AppEnvironment.productionProjectRef), throwsFormatException);
  });
  test('only HTTPS, matching project and public keys are accepted', () {
    expect(config().isTest, isTrue);
    expect(config(publicKey: 'sb_publishable_fake').isTest, isTrue);
    for (final candidate in [key('other'), key(ref, 'service_role'), 'sb_secret_fake', 'invalid']) {
      expect(() => config(publicKey: candidate), throwsFormatException);
    }
    for (final candidate in ['http://$ref.supabase.co', 'https://$ref.supabase.co.evil.test',
      'https://user@$ref.supabase.co', 'https://$ref.supabase.co/path', 'https://$ref.supabase.co?x=1']) {
      expect(() => config(url: candidate), throwsFormatException);
    }
  });
  test('production requires explicit flavor and known project', () {
    expect(() => config(flavor: 'producao'), throwsFormatException);
    expect(config(flavor: 'producao', project: AppEnvironment.productionProjectRef).isTest, isFalse);
  });
}
