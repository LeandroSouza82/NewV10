import 'package:shared_preferences/shared_preferences.dart';

class OverlayDataHelper {
  static Future<void> resetarCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('overlay_memoria_entregas');
    await prefs.remove('overlay_memoria_coletas');
    await prefs.remove('overlay_memoria_servicos');
  }

  static Future<String> formatarResumoVolume(int totalEntregas, int totalColetas, int totalServicos) async {
    final prefs = await SharedPreferences.getInstance();
    int totalPedidos = totalEntregas + totalColetas + totalServicos;

    // O '<br>' garante a quebra de linha no parse de HTML do Android
    String strEntregas = "<br>🚚 $totalEntregas Entregas";
    String strColetas = "<br>🔄 $totalColetas Coletas";
    String strServicos = "<br>⚙️ $totalServicos Serviços";

    // Busca da memória persistente (Isolate-safe)
    int? memoriaEntregas = prefs.getInt('overlay_memoria_entregas');
    int? memoriaColetas = prefs.getInt('overlay_memoria_coletas');
    int? memoriaServicos = prefs.getInt('overlay_memoria_servicos');

    // Primeira carga: se não tiver memória, assume os totais atuais para não saltar
    // Usa SharedPreferences para evitar amnésia em execuções de background (Isolate)
    if (memoriaEntregas == null || memoriaColetas == null || memoriaServicos == null) {
      memoriaEntregas = totalEntregas;
      memoriaColetas = totalColetas;
      memoriaServicos = totalServicos;
    } else {
      // Se não for primeira carga, calcula diferenças para as bolhas coloridas
      int diffEntregas = totalEntregas - memoriaEntregas;
      int diffColetas = totalColetas - memoriaColetas;
      int diffServicos = totalServicos - memoriaServicos;

      // Trava de Lote Inicial: Só mostra incremento se a memória anterior era maior que 0
      // Evita mostrar saltos absurdos (+47) na primeira carga de dados válida
      if (diffEntregas > 0 && memoriaEntregas > 0) {
        strEntregas += " <font color=\"#3182CE\"><b> 🔵 (+$diffEntregas)</b></font>";
      }
      if (diffColetas > 0 && memoriaColetas > 0) {
        strColetas += " <font color=\"#DD6B20\"><b> 🟠 (+$diffColetas)</b></font>";
      }
      if (diffServicos > 0 && memoriaServicos > 0) {
        strServicos += " <font color=\"#805AD5\"><b> 🟣 (+$diffServicos)</b></font>";
      }
    }

    // Salva os totais novos imediatamente na memória
    await prefs.setInt('overlay_memoria_entregas', totalEntregas);
    await prefs.setInt('overlay_memoria_coletas', totalColetas);
    await prefs.setInt('overlay_memoria_servicos', totalServicos);

    return "📦 $totalPedidos Pedidos no Total$strEntregas$strColetas$strServicos";
  }
}
