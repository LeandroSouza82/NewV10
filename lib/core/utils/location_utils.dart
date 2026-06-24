import 'dart:math';

class LocationUtils {
  /// Calcula a distância aproximada por ruas aplicando o coeficiente de circuitação (1.45)
  static double obterDistanciaLogistica({
    required double latAtual,
    required double lngAtual,
    required double latDestino,
    required double lngDestino,
  }) {
    const double raioTerra = 6371.0; // Raio em KM
    
    double dLat = _grausParaRadianos(latDestino - latAtual);
    double dLng = _grausParaRadianos(lngDestino - lngAtual);
    
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_grausParaRadianos(latAtual)) * cos(_grausParaRadianos(latDestino)) * sin(dLng / 2) * sin(dLng / 2);
        
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double linhaReta = raioTerra * c;
    
    // Aplica o fator de 1.45x para simular as curvas e quadras reais da rua
    return linhaReta * 1.45;
  }

  static double _grausParaRadianos(double graus) {
    return graus * (pi / 180);
  }
}
