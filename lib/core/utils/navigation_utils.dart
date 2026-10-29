/// Preserva o número informado no endereço, independente da geocodificação.
String limparEnderecoNavegacao(String? endereco) {
  var limpo = (endereco ?? '')
      .trim()
      .replaceFirst(
        RegExp(r'^(endere[cç][oõ]:?|end:?)\s*', caseSensitive: false),
        '',
      )
      .replaceAll(
        RegExp(r'\b(fpolis|floripa)\b', caseSensitive: false),
        'Florianópolis',
      )
      .trim();
  if (limpo.isNotEmpty &&
      !RegExp(
        r'\b(SC|Santa Catarina)\b',
        caseSensitive: false,
      ).hasMatch(limpo)) {
    limpo = '${limpo.replaceFirst(RegExp(r'[,\s]+$'), '')}, SC, Brasil';
  }
  return limpo;
}

Uri? criarUrlNavegacao(String? endereco, double? lat, double? lng) {
  final limpo = limparEnderecoNavegacao(endereco);
  final String destino;
  if (limpo.isNotEmpty) {
    destino = limpo;
  } else if (lat != null && lng != null && lat != 0 && lng != 0) {
    destino = '$lat,$lng';
  } else {
    return null;
  }
  final query = Uri.encodeComponent(destino);
  return Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=$query&travelmode=driving',
  );
}
