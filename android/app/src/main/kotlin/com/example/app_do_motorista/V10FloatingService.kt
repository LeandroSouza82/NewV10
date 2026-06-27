package com.example.app_do_motorista

import android.app.Service
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import androidx.core.text.HtmlCompat

class V10FloatingService : Service() {

    companion object {
        private const val TAG = "V10FloatingService"
        const val ACTION_FECHAR = "com.v10.delivery.ACTION_FECHAR"
    }

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null

    // Timer para fechar automaticamente (15s)
    private val timerHandler = Handler(Looper.getMainLooper())
    private val closeRunnable = Runnable {
        Log.d(TAG, "Timer de 15s esgotado. Fechando painel.")
        removerPainel()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Se a action é FECHAR, remove a view e para o serviço
        if (intent?.action == ACTION_FECHAR) {
            removerPainel()
            return START_NOT_STICKY
        }

        // Extrai os dados de resumo do Intent
        val totalVolume = intent?.getStringExtra("total_volume") ?: "📦  Nova rota"
        val trajetoResumo = intent?.getStringExtra("trajeto_resumo") ?: "📍  Rota recebida"

        criarOuAtualizarPainel(totalVolume, trajetoResumo)

        return START_NOT_STICKY
    }

    private fun criarOuAtualizarPainel(totalVolume: String, trajetoResumo: String) {
        if (windowManager == null) {
            windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        }

        // Reinicia o timer de 15 segundos
        timerHandler.removeCallbacks(closeRunnable)
        timerHandler.postDelayed(closeRunnable, 15000)

        // Trava de Concorrência: Verifica se a view já existe e está atrelada à janela (evita crash ao tentar adicionar 2x)
        if (overlayView != null && overlayView?.windowToken != null) {
            Log.d(TAG, "Painel já ativo. Atualizando textos e resetando timer.")
            val tvVolume = overlayView?.findViewById<TextView>(R.id.tvVolume)
            val tvTrajeto = overlayView?.findViewById<TextView>(R.id.tvTrajeto)

            // Parse nativo de HTML para aplicar quebras de linha (<br>), cores e negritos enviados pelo Dart
            tvVolume?.text = HtmlCompat.fromHtml(totalVolume, HtmlCompat.FROM_HTML_MODE_COMPACT)
            tvTrajeto?.text = trajetoResumo
            return
        }

        // Caso contrário, infla uma nova view
        val inflater = getSystemService(LAYOUT_INFLATER_SERVICE) as LayoutInflater
        overlayView = inflater.inflate(R.layout.v10_overlay_panel, null)

        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            layoutType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        )

        params.gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL

        overlayView?.let { view ->
            val tvVolume = view.findViewById<TextView>(R.id.tvVolume)
            // Parse nativo de HTML para aplicar quebras de linha (<br>), cores e negritos enviados pelo Dart
            tvVolume?.text = HtmlCompat.fromHtml(totalVolume, HtmlCompat.FROM_HTML_MODE_COMPACT)
            view.findViewById<TextView>(R.id.tvTrajeto)?.text = trajetoResumo

            view.findViewById<TextView>(R.id.btnAnular)?.setOnClickListener {
                Log.d(TAG, "Botão ANULAR pressionado.")
                removerPainel()
            }

            view.findViewById<TextView>(R.id.btnIrParaApp)?.setOnClickListener {
                Log.d(TAG, "Botão IR PARA O APP pressionado.")
                abrirApp()
                removerPainel()
            }
        }

        try {
            windowManager?.addView(overlayView, params)
            Log.d(TAG, "Painel overlay adicionado com sucesso.")
        } catch (e: Exception) {
            Log.e(TAG, "Erro ao adicionar overlay: ${e.message}")
            stopSelf()
        }
    }

    private fun abrirApp() {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        startActivity(launchIntent)
    }

    private fun removerPainel() {
        timerHandler.removeCallbacks(closeRunnable)
        try {
            if (overlayView != null && overlayView?.windowToken != null) {
                windowManager?.removeView(overlayView)
                Log.d(TAG, "Painel overlay removido da janela.")
            }
            overlayView = null
        } catch (e: Exception) {
            Log.e(TAG, "Erro ao remover overlay: ${e.message}")
        }
        stopSelf()
    }

    override fun onDestroy() {
        super.onDestroy()
        removerPainel()
    }
}
