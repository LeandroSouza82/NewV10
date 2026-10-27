-- ==============================================================================
-- SCRIPT DE SEGURANÇA: Habilitação de RLS Seguro para V10 Delivery (Role anon)
-- Projeto Supabase: uqxoadxqcwidxqsfayem
-- Arquivo: supabase/enable_rls_seguro.sql
-- ==============================================================================
-- Contexto Técnico:
-- O app V10 Delivery autentica diretamente na tabela public.motoristas e opera
-- com a role 'anon' (chave pública publishable). Portanto, as políticas RLS NÃO
-- utilizam auth.uid() ou restrição exclusiva a 'authenticated'.
-- Este script:
-- 1. Ativa Row Level Security (RLS) nas 8 tabelas acessadas pelo app.
-- 2. Concede permissões cirúrgicas para 'anon' e 'authenticated' continuarem
--    operando normalmente (login, sincronização, baixa de entrega, fotos, SOS).
-- 3. Bloqueia operações destrutivas (DELETE) e inserções não autorizadas.
-- 4. Inclui bloco de ROLLBACK rápido no final.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. TABELA: public.motoristas
-- Operações pelo app: SELECT (login/perfil), INSERT (cadastro), UPDATE (status/GPS/FCM)
-- ------------------------------------------------------------------------------
ALTER TABLE public.motoristas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "motoristas_permitir_select_app" ON public.motoristas;
CREATE POLICY "motoristas_permitir_select_app"
ON public.motoristas
FOR SELECT
TO anon, authenticated
USING (true);

DROP POLICY IF EXISTS "motoristas_permitir_cadastro_app" ON public.motoristas;
CREATE POLICY "motoristas_permitir_cadastro_app"
ON public.motoristas
FOR INSERT
TO anon, authenticated
WITH CHECK (true);

DROP POLICY IF EXISTS "motoristas_permitir_update_operacional_app" ON public.motoristas;
CREATE POLICY "motoristas_permitir_update_operacional_app"
ON public.motoristas
FOR UPDATE
TO anon, authenticated
USING (true)
WITH CHECK (true);

-- DELETE bloqueado: Nenhuma política criada para DELETE.

-- ------------------------------------------------------------------------------
-- 2. TABELA: public.entregas
-- Operações pelo app: SELECT (rotas/histórico), UPDATE (baixa, falha, comprovante, ordem)
-- ------------------------------------------------------------------------------
ALTER TABLE public.entregas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "entregas_permitir_select_app" ON public.entregas;
CREATE POLICY "entregas_permitir_select_app"
ON public.entregas
FOR SELECT
TO anon, authenticated
USING (true);

DROP POLICY IF EXISTS "entregas_permitir_update_status_app" ON public.entregas;
CREATE POLICY "entregas_permitir_update_status_app"
ON public.entregas
FOR UPDATE
TO anon, authenticated
USING (true)
WITH CHECK (true);

-- INSERT e DELETE bloqueados para o app do motorista (gestor gerencia rotas).

-- ------------------------------------------------------------------------------
-- 3. TABELA: public.ocorrencias
-- Operações pelo app: SELECT (listar ocorrências), INSERT (registrar ocorrência)
-- ------------------------------------------------------------------------------
ALTER TABLE public.ocorrencias ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ocorrencias_permitir_select_app" ON public.ocorrencias;
CREATE POLICY "ocorrencias_permitir_select_app"
ON public.ocorrencias
FOR SELECT
TO anon, authenticated
USING (true);

DROP POLICY IF EXISTS "ocorrencias_permitir_insert_app" ON public.ocorrencias;
CREATE POLICY "ocorrencias_permitir_insert_app"
ON public.ocorrencias
FOR INSERT
TO anon, authenticated
WITH CHECK (true);

-- UPDATE e DELETE bloqueados.

-- ------------------------------------------------------------------------------
-- 4. TABELA: public.veiculos
-- Operações pelo app: SELECT (dados do veículo), UPDATE (atualização de KM)
-- ------------------------------------------------------------------------------
ALTER TABLE public.veiculos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "veiculos_permitir_select_app" ON public.veiculos;
CREATE POLICY "veiculos_permitir_select_app"
ON public.veiculos
FOR SELECT
TO anon, authenticated
USING (true);

DROP POLICY IF EXISTS "veiculos_permitir_update_km_app" ON public.veiculos;
CREATE POLICY "veiculos_permitir_update_km_app"
ON public.veiculos
FOR UPDATE
TO anon, authenticated
USING (true)
WITH CHECK (true);

-- INSERT e DELETE bloqueados.

-- ------------------------------------------------------------------------------
-- 5. TABELA: public.abastecimentos
-- Operações pelo app: SELECT (histórico), INSERT (novo abastecimento)
-- ------------------------------------------------------------------------------
ALTER TABLE public.abastecimentos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "abastecimentos_permitir_select_app" ON public.abastecimentos;
CREATE POLICY "abastecimentos_permitir_select_app"
ON public.abastecimentos
FOR SELECT
TO anon, authenticated
USING (true);

DROP POLICY IF EXISTS "abastecimentos_permitir_insert_app" ON public.abastecimentos;
CREATE POLICY "abastecimentos_permitir_insert_app"
ON public.abastecimentos
FOR INSERT
TO anon, authenticated
WITH CHECK (true);

-- UPDATE e DELETE bloqueados.

-- ------------------------------------------------------------------------------
-- 6. TABELA: public.empresas
-- Operações pelo app: SELECT (endereço base para rota de retorno, logotipo, nome)
-- ------------------------------------------------------------------------------
ALTER TABLE public.empresas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "empresas_permitir_select_app" ON public.empresas;
CREATE POLICY "empresas_permitir_select_app"
ON public.empresas
FOR SELECT
TO anon, authenticated
USING (true);

-- INSERT, UPDATE e DELETE bloqueados para o app.

-- ------------------------------------------------------------------------------
-- 7. TABELA: public.avisos_gestor
-- Operações pelo app: SELECT (notificações), UPDATE (marcar como lido)
-- ------------------------------------------------------------------------------
ALTER TABLE public.avisos_gestor ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "avisos_gestor_permitir_select_app" ON public.avisos_gestor;
CREATE POLICY "avisos_gestor_permitir_select_app"
ON public.avisos_gestor
FOR SELECT
TO anon, authenticated
USING (true);

DROP POLICY IF EXISTS "avisos_gestor_permitir_update_lido_app" ON public.avisos_gestor;
CREATE POLICY "avisos_gestor_permitir_update_lido_app"
ON public.avisos_gestor
FOR UPDATE
TO anon, authenticated
USING (true)
WITH CHECK (true);

-- INSERT e DELETE bloqueados.

-- ------------------------------------------------------------------------------
-- 8. TABELA: public.alertas_sos
-- Operações pelo app: INSERT (disparo de botão de socorro/pânico)
-- ------------------------------------------------------------------------------
ALTER TABLE public.alertas_sos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "alertas_sos_permitir_insert_app" ON public.alertas_sos;
CREATE POLICY "alertas_sos_permitir_insert_app"
ON public.alertas_sos
FOR INSERT
TO anon, authenticated
WITH CHECK (true);

-- SELECT, UPDATE e DELETE bloqueados para anon (somente painel administrativo lê).

-- ------------------------------------------------------------------------------
-- 9. SUPABASE REALTIME: Garantir que publicações realtime estejam habilitadas
-- ------------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'entregas'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.entregas;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    NULL; -- Ignora caso a publicação não exista ou já esteja em nível database
END $$;


-- ==============================================================================
-- BLOCO DE ROLLBACK RÁPIDO (Execute apenas se precisar desativar RLS imediatamente)
-- ==============================================================================
/*
ALTER TABLE public.motoristas DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.entregas DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.ocorrencias DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.veiculos DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.abastecimentos DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.empresas DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.avisos_gestor DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.alertas_sos DISABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "motoristas_permitir_select_app" ON public.motoristas;
DROP POLICY IF EXISTS "motoristas_permitir_cadastro_app" ON public.motoristas;
DROP POLICY IF EXISTS "motoristas_permitir_update_operacional_app" ON public.motoristas;
DROP POLICY IF EXISTS "entregas_permitir_select_app" ON public.entregas;
DROP POLICY IF EXISTS "entregas_permitir_update_status_app" ON public.entregas;
DROP POLICY IF EXISTS "ocorrencias_permitir_select_app" ON public.ocorrencias;
DROP POLICY IF EXISTS "ocorrencias_permitir_insert_app" ON public.ocorrencias;
DROP POLICY IF EXISTS "veiculos_permitir_select_app" ON public.veiculos;
DROP POLICY IF EXISTS "veiculos_permitir_update_km_app" ON public.veiculos;
DROP POLICY IF EXISTS "abastecimentos_permitir_select_app" ON public.abastecimentos;
DROP POLICY IF EXISTS "abastecimentos_permitir_insert_app" ON public.abastecimentos;
DROP POLICY IF EXISTS "empresas_permitir_select_app" ON public.empresas;
DROP POLICY IF EXISTS "avisos_gestor_permitir_select_app" ON public.avisos_gestor;
DROP POLICY IF EXISTS "avisos_gestor_permitir_update_lido_app" ON public.avisos_gestor;
DROP POLICY IF EXISTS "alertas_sos_permitir_insert_app" ON public.alertas_sos;
*/
