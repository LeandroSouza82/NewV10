-- Migration: trigger_push_nova_entrega
-- Data: 2026-10-17
-- Descrição: Dispara a Edge Function 'enviar-push-rota' automaticamente quando uma entrega for atribuída ao motorista (status = 'em_rota')

-- 1. Habilita a extensão pg_net se ainda não estiver ativa (padrão no Supabase)
CREATE EXTENSION IF NOT EXISTS pg_net;

-- 2. Função disparadora para chamar a Edge Function de Push Notification
CREATE OR REPLACE FUNCTION public.fn_trigger_push_nova_entrega()
RETURNS trigger AS $$
DECLARE
  edge_function_url text;
  anon_or_service_key text;
  payload jsonb;
BEGIN
  -- Só dispara se o status for 'em_rota' e houver motorista_id vinculado
  IF (NEW.status = 'em_rota' AND NEW.motorista_id IS NOT NULL) THEN
    -- Evita disparar repetido se já estava em_rota e não mudou o motorista
    IF (TG_OP = 'UPDATE' AND OLD.status = 'em_rota' AND OLD.motorista_id = NEW.motorista_id) THEN
      RETURN NEW;
    END IF;

    -- URL da Edge Function do projeto Supabase
    -- Substitua 'https://uqxoadxqcwidxqsfayem.supabase.co' pelo seu domínio se necessário
    edge_function_url := 'https://uqxoadxqcwidxqsfayem.supabase.co/functions/v1/enviar-push-rota';

    payload := jsonb_build_object(
      'motorista_id', NEW.motorista_id,
      'rota_id', NEW.id,
      'status', NEW.status
    );

    -- Disparo assíncrono via pg_net (não trava a transação do banco)
    PERFORM net.http_post(
      url := edge_function_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json'
      ),
      body := payload
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Cria a Trigger na tabela entregas
DROP TRIGGER IF EXISTS trg_push_nova_entrega ON public.entregas;

CREATE TRIGGER trg_push_nova_entrega
AFTER INSERT OR UPDATE OF status, motorista_id ON public.entregas
FOR EACH ROW
EXECUTE FUNCTION public.fn_trigger_push_nova_entrega();
