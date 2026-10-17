import 'dart:convert';

class AppEnvironment {
  static const productionProjectRef = 'uqxoadxqcwidxqsfayem';
  final String flavor;
  final String projectRef;
  final String url;
  final String publicKey;
  final bool isSharedTest;
  final String testDriverId;
  static AppEnvironment? active;
  bool get isTest => flavor == 'homologacao';

  const AppEnvironment._(this.flavor, this.projectRef, this.url, this.publicKey, this.isSharedTest, this.testDriverId);

  factory AppEnvironment.fromBuild() => AppEnvironment.fromValues(
    flavor: const String.fromEnvironment('FLUTTER_APP_FLAVOR'),
    projectRef: const String.fromEnvironment('SUPABASE_PROJECT_REF'),
    url: const String.fromEnvironment('SUPABASE_URL'),
    publicKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    sharedTest: const bool.fromEnvironment('SHARED_TEST_DATABASE'),
    testDriverId: const String.fromEnvironment('TEST_DRIVER_ID'),
  );

  factory AppEnvironment.fromValues({
    required String flavor,
    required String projectRef,
    required String url,
    required String publicKey,
    bool sharedTest = false,
    String testDriverId = '',
  }) {
    if (flavor != 'homologacao' && flavor != 'producao') {
      throw const FormatException('Escolha a versão teste ao gerar o aplicativo.');
    }
    final ref = projectRef.trim();
    final key = publicKey.trim();
    final uri = Uri.tryParse(url);
    if (!RegExp(r'^[a-z0-9]+$').hasMatch(ref) || uri == null ||
        uri.scheme != 'https' || uri.authority != '$ref.supabase.co' ||
        (uri.path.isNotEmpty && uri.path != '/') || uri.hasQuery || uri.hasFragment) {
      throw const FormatException('Configure a URL e a referência do mesmo projeto Supabase.');
    }
    if (flavor == 'homologacao' && ref == productionProjectRef && !sharedTest) {
      throw const FormatException('Conexão bloqueada: V10 Teste não pode usar o banco de produção.');
    }
    if (flavor == 'producao' && ref != productionProjectRef) {
      throw const FormatException('O projeto configurado não corresponde à produção conhecida.');
    }
    if (sharedTest && (flavor != 'homologacao' || ref != productionProjectRef ||
        !RegExp(r'^[a-fA-F0-9]{8}(-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12}$').hasMatch(testDriverId))) {
      throw const FormatException('Configure o projeto atual e o UUID do motorista TESTE.');
    }
    if (key.isEmpty) {
      throw const FormatException('Configure a chave pública do projeto selecionado.');
    }
    if (!key.startsWith('sb_publishable_')) {
      try {
        final claims = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(key.split('.')[1]))));
        if (claims['role'] != 'anon' || claims['ref'] != ref) throw const FormatException();
      } catch (_) {
        throw const FormatException('Use a chave pública do mesmo projeto, nunca uma chave administrativa.');
      }
    }
    return AppEnvironment._(flavor, ref, uri.origin, key, sharedTest, testDriverId);
  }
}
