package com.example.app_do_motorista

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.v10.delivery/overlay"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "abrirPainel" -> {
                    val totalVolume = call.argument<String>("total_volume") ?: "📦  Nova rota"
                    val trajetoResumo = call.argument<String>("trajeto_resumo") ?: "📍  Rota recebida"

                    val serviceIntent = Intent(this, V10FloatingService::class.java).apply {
                        putExtra("total_volume", totalVolume)
                        putExtra("trajeto_resumo", trajetoResumo)
                    }
                    startService(serviceIntent)
                    result.success(true)
                }

                "fecharPainel" -> {
                    val serviceIntent = Intent(this, V10FloatingService::class.java).apply {
                        action = V10FloatingService.ACTION_FECHAR
                    }
                    startService(serviceIntent)
                    result.success(true)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
