-- Migration: add_fcm_token_to_motoristas
-- Data: 2026-10-17
-- Descrição: Adiciona cirurgicamente a coluna fcm_token na tabela public.motoristas para suporte a Push Notifications (FCM).

ALTER TABLE public.motoristas 
ADD COLUMN IF NOT EXISTS fcm_token text;

COMMENT ON COLUMN public.motoristas.fcm_token IS 'Token do dispositivo registrado no Firebase Cloud Messaging (FCM) para push notifications de novas rotas';
