import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/app_environment.dart';

const testCardPrefix = 'TESTE V10 - ';
bool isTestCard(Map<String, dynamic> row) =>
    (row['cliente'] ?? '').toString().toUpperCase().startsWith(testCardPrefix);

class SharedTestClient extends http.BaseClient {
  final AppEnvironment environment;
  final http.Client inner;
  SharedTestClient(this.environment, {http.Client? client}) : inner = client ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    var url = request.url;
    if (url.origin != environment.url) throw http.ClientException('Projeto inesperado no modo TESTE.');
    var bytes = await request.finalize().toBytes();
    final write = request.method != 'GET' && request.method != 'HEAD';
    final match = RegExp(r'^/rest/v1/([^/]+)$').firstMatch(url.path);
    if (match != null) {
      final table = match.group(1)!;
      final params = url.queryParametersAll.map((k, v) => MapEntry(k, List<String>.from(v)));
      void scope(String key, String value) => params.putIfAbsent(key, () => []).add(value);
      dynamic payload = bytes.isNotEmpty && write ? jsonDecode(utf8.decode(bytes)) : null;
      if (table == 'entregas') {
        scope('cliente', 'ilike.TESTE V10 - *');
        if (write && request.method != 'PATCH') throw http.ClientException('Somente baixa de cards TESTE é permitida neste aplicativo.');
        if (write && !params.containsKey('id')) throw http.ClientException('Informe os IDs dos cards TESTE.');
        if (payload is Map && payload['cliente'] != null && !isTestCard(Map<String, dynamic>.from(payload))) {
          throw http.ClientException('Preserve a identificação TESTE V10.');
        }
        if (payload is Map && payload['motorista_id'] != null && payload['motorista_id'] != environment.testDriverId) {
          throw http.ClientException('Use o motorista TESTE.');
        }
      } else if (table == 'motoristas') {
        scope('id', 'eq.${environment.testDriverId}');
        scope('nome', 'ilike.TESTE V10 - *');
        if (write && request.method != 'PATCH') throw http.ClientException('Use o motorista TESTE já cadastrado.');
        if (payload is Map && payload['nome'] != null && !payload['nome'].toString().toUpperCase().startsWith(testCardPrefix)) {
          throw http.ClientException('Preserve o nome do motorista TESTE.');
        }
      } else if (write) {
        throw http.ClientException('Esta ação não faz parte do teste de envio de rotas.');
      }
      url = url.replace(queryParameters: params);
    } else if (write && url.path.startsWith('/rest/v1/')) {
      throw http.ClientException('RPC indisponível no modo TESTE.');
    } else if (write && url.path.startsWith('/storage/v1/')) {
      final allowed = ['/storage/v1/object/entregas/${environment.testDriverId}/',
        '/storage/v1/object/avatars/${environment.testDriverId}/'];
      if (!allowed.any(url.path.startsWith)) throw http.ClientException('Use somente arquivos do motorista TESTE.');
    }
    final scoped = http.Request(request.method, url)
      ..headers.addAll(request.headers)
      ..followRedirects = request.followRedirects
      ..maxRedirects = request.maxRedirects
      ..bodyBytes = bytes;
    return inner.send(scoped);
  }

  @override
  void close() => inner.close();
}
