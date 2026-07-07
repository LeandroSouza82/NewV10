package com.example.app_do_motorista

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val MAIN_CHANNEL = "com.v10.delivery/main_overlay"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MAIN_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        result.success(Settings.canDrawOverlays(this))
                    } else {
                        result.success(true)
                    }
                }
                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        if (!Settings.canDrawOverlays(this)) {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            )
                            startActivityForResult(intent, 1234)
                            result.success(true)
                        } else {
                            result.success(true)
                        }
                    } else {
                        result.success(true)
                    }
                }
                "showOverlay" -> {
                    android.util.Log.d("V10_OVERLAY", "a) Recebido sinal do Flutter: showOverlay")
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
                        android.util.Log.e("V10_OVERLAY", "b) Erro na permissão SYSTEM_ALERT_WINDOW (showOverlay negado)")
                        result.error("PERMISSION_DENIED", "Overlay permission not granted", null)
                        return@setMethodCallHandler
                    }

                    android.util.Log.d("V10_OVERLAY", "b) Permissão concedida. Extraindo payload JSON...")
                    val jsonPayload = call.argument<String>("rota_json") ?: ""
                    val serviceIntent = Intent(this, V10OverlayService::class.java).apply {
                        putExtra("rota_json", jsonPayload)
                    }
                    
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            android.util.Log.d("V10_OVERLAY", "Iniciando V10OverlayService (Foreground)")
                            startForegroundService(serviceIntent)
                        } else {
                            android.util.Log.d("V10_OVERLAY", "Iniciando V10OverlayService (Normal)")
                            startService(serviceIntent)
                        }
                    } catch (e: Exception) {
                        android.util.Log.e("V10_OVERLAY", "Erro ao iniciar o serviço: ${e.message}")
                    }
                    
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
