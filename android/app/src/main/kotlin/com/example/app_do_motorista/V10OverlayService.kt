package com.example.app_do_motorista

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.WindowManager
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.android.FlutterTextureView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.android.FlutterSurfaceView
import io.flutter.embedding.android.TransparencyMode
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import androidx.core.app.NotificationCompat
import android.provider.Settings

class V10OverlayService : Service() {

    private var windowManager: WindowManager? = null
    private var flutterView: FlutterView? = null
    private var flutterEngine: FlutterEngine? = null
    private var methodChannel: MethodChannel? = null

    companion object {
        const val OVERLAY_CHANNEL = "com.v10.delivery/overlay_isolate"
        const val ACTION_FECHAR = "FECHAR_OVERLAY"
    }

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "v10_overlay_channel"
            val channel = NotificationChannel(
                channelId,
                "Serviço de Alertas",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)

            val notification = NotificationCompat.Builder(this, channelId)
                .setContentTitle("V10 Delivery")
                .setContentText("Aguardando novas rotas...")
                .setSmallIcon(android.R.drawable.ic_dialog_info) // Fallback seguro nativo
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setSilent(true)
                .setOngoing(true)
                .build()

            startForeground(1101, notification)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        android.util.Log.d("V10_OVERLAY", "a) Serviço de Overlay acionado. Intent: ${intent?.action}")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!Settings.canDrawOverlays(this)) {
                android.util.Log.e("V10_OVERLAY", "b) Erro ao renderizar: Falta de permissão SYSTEM_ALERT_WINDOW no onStartCommand")
                stopSelf()
                return START_NOT_STICKY
            } else {
                android.util.Log.d("V10_OVERLAY", "b) Permissão verificada com sucesso no Serviço.")
            }
        }

        if (intent?.action == ACTION_FECHAR) {
            fecharOverlay()
            return START_NOT_STICKY
        }

        val jsonPayload = intent?.getStringExtra("rota_json") ?: ""
        
        if (flutterView == null) {
            setupFlutterOverlay(jsonPayload)
        } else {
            methodChannel?.invokeMethod("novaRota", jsonPayload)
        }

        return START_NOT_STICKY
    }

    private fun setupFlutterOverlay(jsonPayload: String) {
        android.util.Log.d("V10_OVERLAY", "c) Inicializando FlutterEngine exclusivo para o Overlay...")
        try {
            flutterEngine = FlutterEngine(this)
            flutterEngine?.dartExecutor?.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(
                    io.flutter.FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                    "overlayMain"
                )
            )
            android.util.Log.d("V10_OVERLAY", "c) FlutterEngine criado e entrypoint 'overlayMain' ativado.")
        } catch (e: Exception) {
            android.util.Log.e("V10_OVERLAY", "c) Erro ao renderizar: Falha ao inicializar o FlutterEngine: ${e.message}")
        }

        // Usamos um FlutterTextureView para permitir transparência completa (SurfaceView as vezes dá fundo preto)
        val textureView = FlutterTextureView(this)
        textureView.isOpaque = false
        
        flutterView = FlutterView(this, textureView)

        // 1. Força o engine a processar frames
        flutterEngine?.lifecycleChannel?.appIsResumed()

        // 2. Aguarda o engine estar pronto antes de adicionar ao WindowManager
        flutterView?.addOnFirstFrameRenderedListener(object : io.flutter.embedding.engine.renderer.FlutterUiDisplayListener {
            override fun onFlutterUiDisplayed() {
                android.util.Log.d("V10Overlay", "Primeiro frame renderizado!")
            }
            override fun onFlutterUiNoLongerDisplayed() {}
        })

        // 3. Anexa o FlutterView ao engine
        flutterView?.attachToFlutterEngine(flutterEngine!!)

        // 4. Força estado resumed DEPOIS de anexar
        flutterEngine?.lifecycleChannel?.appIsResumed()

        // CORREÇÃO: Dart avisa quando estiver pronto, em vez de delay arbitrário!
        methodChannel = MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, OVERLAY_CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "fechar" -> {
                    fecharOverlay()
                    result.success(true)
                }
                "overlayReady" -> {
                    // Assim que o Flutter avisar que bootou o OverlayApp, mandamos os dados
                    methodChannel?.invokeMethod("novaRota", jsonPayload)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // O Dart agora avisa "overlayReady" pelo methodChannel para pedir a rota.

        val layoutFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val displayMetrics = resources.displayMetrics
        val params = WindowManager.LayoutParams(
            displayMetrics.widthPixels,
            WindowManager.LayoutParams.WRAP_CONTENT,
            layoutFlag,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
            WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
        }

        // 5. Só então adiciona ao WindowManager
        try {
            android.util.Log.d("V10_OVERLAY", "d) Executando attachToWindow: windowManager.addView(...)")
            windowManager?.addView(flutterView, params)
            android.util.Log.d("V10_OVERLAY", "✅ d) Card adicionado com sucesso no WindowManager")
        } catch (e: Exception) {
            android.util.Log.e("V10_OVERLAY", "d) Erro ao renderizar: Falha no attachToWindow do WindowManager: ${e.message}")
            stopSelf()
        }
    }

    private fun fecharOverlay() {
        flutterView?.let {
            if (it.isAttachedToWindow) {
                windowManager?.removeView(it)
            }
            it.detachFromFlutterEngine()
        }
        flutterView = null
        
        flutterEngine?.destroy()
        flutterEngine = null
        
        stopSelf()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        fecharOverlay()
        super.onDestroy()
    }
}
