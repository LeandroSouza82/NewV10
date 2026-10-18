// Supabase Edge Function: enviar-push-rota
// Dispara notificação FCM HTTP v1 de Alta Prioridade para o motorista
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Gera o Google OAuth2 Access Token a partir da Service Account usando Web Crypto nativa do Deno
async function getGoogleAccessToken(serviceAccount: {
  client_email: string;
  private_key: string;
}): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const claimSet = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  };

  const encodeBase64Url = (obj: unknown) => {
    const jsonStr = typeof obj === "string" ? obj : JSON.stringify(obj);
    return btoa(jsonStr).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  };

  const unsignedToken = `${encodeBase64Url(header)}.${encodeBase64Url(claimSet)}`;

  // Converte a PEM private key para CryptoKey
  const pem = serviceAccount.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const binaryKey = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(unsignedToken)
  );

  const base64UrlSignature = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");

  const signedJwt = `${unsignedToken}.${base64UrlSignature}`;

  // Troca o JWT assinado pelo access token do Google
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: signedJwt,
    }),
  });

  const data = await response.json();
  if (!response.ok) {
    throw new Error(`Erro ao obter access token do Google: ${JSON.stringify(data)}`);
  }

  return data.access_token;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();

    // Suporta tanto chamada direta quanto Database Webhook do Supabase (payload de record em 'entregas')
    const record = body.record || body;
    const motoristaId = record.motorista_id || body.motorista_id;
    const rotaId = record.id || record.rota_id || body.rota_id;
    const status = record.status || body.status;

    // Se vier de trigger/webhook em 'entregas', só dispara se o status for 'em_rota'
    if (body.record && status !== "em_rota") {
      return new Response(
        JSON.stringify({ message: "Status não é em_rota, ignorado." }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!motoristaId) {
      return new Response(JSON.stringify({ error: "motorista_id não informado" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Inicializa o cliente Supabase com service_role
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // 1. Busca o fcm_token do motorista
    const { data: motorista, error: motoristaError } = await supabaseClient
      .from("motoristas")
      .select("id, nome, fcm_token")
      .eq("id", motoristaId)
      .single();

    if (motoristaError || !motorista?.fcm_token) {
      return new Response(
        JSON.stringify({
          error: "Motorista não encontrado ou fcm_token vazio no banco",
          motoristaId,
        }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Carrega credenciais do Firebase do ambiente
    const serviceAccountRaw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    if (!serviceAccountRaw) {
      return new Response(
        JSON.stringify({
          error: "Secret FIREBASE_SERVICE_ACCOUNT não configurado no Supabase Edge Functions",
          fcm_token_destino: motorista.fcm_token,
        }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const serviceAccount = JSON.parse(serviceAccountRaw);
    const projectId = serviceAccount.project_id;
    const accessToken = await getGoogleAccessToken(serviceAccount);

    // 3. Monta o Payload data-only de Prioridade Alta (FCM HTTP v1).
    // Sem bloco "notification": o app exibe a notificação local (logo V10, som "chama"),
    // evitando duas notificações para o mesmo evento.
    const fcmMessage = {
      message: {
        token: motorista.fcm_token,
        data: {
          tipo: "nova_rota",
          rota_id: String(rotaId || ""),
        },
        android: {
          priority: "high", // Desperta o aparelho em Doze / Standby
        },
      },
    };

    // 4. Dispara a mensagem via FCM HTTP v1
    const fcmResponse = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify(fcmMessage),
      }
    );

    const fcmResult = await fcmResponse.json();

    if (!fcmResponse.ok) {
      return new Response(
        JSON.stringify({ error: "Falha ao enviar pelo FCM", details: fcmResult }),
        { status: fcmResponse.status, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        motorista: motorista.nome,
        messageId: fcmResult.name,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err.message || "Erro interno" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
