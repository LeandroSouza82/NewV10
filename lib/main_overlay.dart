import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_do_motorista/models/chamada_model.dart';
import 'package:app_do_motorista/views/chamadas/widgets/chamada_card.dart';



class OverlayApp extends StatefulWidget {
  const OverlayApp({super.key});

  @override
  State<OverlayApp> createState() => _OverlayAppState();
}

class _OverlayAppState extends State<OverlayApp> {
  static const MethodChannel _channel = MethodChannel('com.v10.delivery/overlay_isolate');
  ChamadaModel? _chamadaAtual;

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'novaRota') {
        try {
          final payload = call.arguments as String;
          if (payload.isNotEmpty) {
            final Map<String, dynamic> data = jsonDecode(payload);
            
            final model = ChamadaModel.fromJson(data);
            print('🧩 OVERLAY PARSE: Tipo=${model.tipo}, TotalPedidos=${model.totalPedidos}, KM=${model.kmTotal ?? model.distancia}');
            print('📥 OVERLAY RECEBEU: Tipo=${model.tipo} | TotalPedidos=${model.totalPedidos}');

            setState(() {
              _chamadaAtual = model;
            });
          }
        } catch (e) {
          debugPrint('Erro ao fazer parse da rota no overlay: $e');
        }
      }
    });

    // Avisa o Kotlin que a UI do Flutter está pronta e pode mandar a rota!
    _channel.invokeMethod('overlayReady');
  }

  void _fecharOverlay() {
    _channel.invokeMethod('fechar');
  }

  void _aceitarRota() {
    // Como estamos num isolate separado, a ação de aceitar a rota precisa 
    // ser repassada pro main app ou fazer a chamada de API direto daqui.
    // Por enquanto, apenas fecha o overlay, mas idealmente enviaria um intent pro MainActivity.
    debugPrint('Rota Aceita no Overlay');
    _fecharOverlay();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: _chamadaAtual == null
            ? const SizedBox.shrink()
            : Center(
                child: SafeArea(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.8,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ChamadaCard(
                        chamada: _chamadaAtual!,
                        onAceitar: _aceitarRota,
                        onRecusar: _fecharOverlay, // O botão RECUSAR simplesmente fecha o overlay
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
