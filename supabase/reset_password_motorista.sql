-- Redefinição de senha do motorista (validação: e-mail + CPF).
-- Rode no SQL Editor do Supabase.

CREATE OR REPLACE FUNCTION public.redefinir_senha_motorista(
  p_email text,
  p_cpf text,
  p_nova_senha text
) RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email text := lower(trim(p_email));
  v_cpf   text := regexp_replace(coalesce(p_cpf, ''), '\D', '', 'g');
  v_senha text := trim(p_nova_senha);
  v_id    public.motoristas.id%TYPE;
BEGIN
  IF v_email = '' OR v_cpf = '' OR coalesce(v_senha, '') = '' THEN
    RAISE EXCEPTION 'Preencha todos os campos.';
  END IF;

  IF length(v_senha) < 6 THEN
    RAISE EXCEPTION 'A nova senha deve ter ao menos 6 caracteres.';
  END IF;

  SELECT id INTO v_id
  FROM public.motoristas
  WHERE lower(trim(email)) = v_email
    AND regexp_replace(coalesce(cpf, ''), '\D', '', 'g') = v_cpf
  LIMIT 1;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'E-mail ou CPF não conferem com o cadastro.';
  END IF;

  UPDATE public.motoristas SET senha = v_senha WHERE id = v_id;
  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.redefinir_senha_motorista(text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.redefinir_senha_motorista(text, text, text) TO anon, authenticated;
