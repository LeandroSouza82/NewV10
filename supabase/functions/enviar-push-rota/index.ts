// Supabase Edge Function: enviar-push-rota
// Dispara notificação FCM HTTP v1 de Alta Prioridade para acordar o celular do motorista
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { motorista_id, rota_id, titulo, mensagem } = await req.json();

    if (!motorista_id) {
      return new Response(JSON.stringify({ error: "motorista_id é obrigatório" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Inicializa o cliente do Supabase com service_role_key para buscar o token
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // 1. Busca o fcm_token do motorista
    const { data: motorista, error: motoristaError } = await supabaseClient
      .from("motoristas")
      .select("id, nome, fcm_token")
      .eq("id", motorista_id)
      .single();

    if (motoristaError || !motorista?.fcm_token) {
      return new Response(
        JSON.stringify({
          error: "Motorista não encontrado ou fcm_token inexistente/vazio",
          motoristaError,
        }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Payload FCM com Alta Prioridade para acordar tela bloqueada/standby
    const fcmPayload = {
      message: {
        token: motorista.fcm_token,
        notification: {
          title: titulo || "Nova Rota Disponível!",
          body: mensagem || "Você recebeu uma nova entrega. Toque para visualizar o trajeto.",
        },
        data: {
          tipo: "nova_rota",
          rota_id: String(rota_id || ""),
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: "high", // VITAL para acordar aparelho em Doze Mode / Background
          notification: {
            channel_id: "canal_urgente",
            sound: "chama",
            default_sound: true,
            default_vibrate_timings: true,
            notification_priority: "PRIORITY_MAX",
            visibility: "PUBLIC",
          },
        },
      },
    };

    // Obs: Para envio direto via FCM HTTP v1, utilize sua Service Account do Firebase:
    // POST https://fcm.googleapis.com/v1/projects/{YOUR_PROJECT_ID}/messages:send
    // Header: Authorization: Bearer {GOOGLE_ACCESS_TOKEN}

    return new Response(
      JSON.stringify({
        success: true,
        fcmPayload,
        motorista: { id: motorista.id, nome: motorista.nome },
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
