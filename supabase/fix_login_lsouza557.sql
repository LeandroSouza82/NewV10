-- Login do app V10 valida na tabela public.motoristas (email + coluna senha),
-- NÃO usa auth.users. Rode no SQL Editor do Supabase.

-- 1) Diagnóstico
SELECT id, email, senha, aprovado FROM public.motoristas
WHERE lower(trim(email)) = 'lsouza557@gmail.com';

-- 2) Correção: normaliza e-mail, define senha (ALTERE 'NovaSenha123') e aprova
UPDATE public.motoristas
SET email = lower(trim(email)),
    senha = 'NovaSenha123',
    aprovado = true
WHERE lower(trim(email)) = 'lsouza557@gmail.com';

-- 3) Duplicatas (deve retornar 0 linhas)
SELECT lower(trim(email)), count(*) FROM public.motoristas
GROUP BY 1 HAVING count(*) > 1;

-- 4) RLS: o app usa a chave anon; precisa de SELECT/UPDATE em motoristas
SELECT policyname, cmd, roles, qual FROM pg_policies WHERE tablename = 'motoristas';

-- (Opcional) Também alinhar auth.users, caso queira usar Supabase Auth no futuro:
UPDATE auth.users
SET encrypted_password = crypt('NovaSenha123', gen_salt('bf')),
    email_confirmed_at = COALESCE(email_confirmed_at, now())
WHERE lower(email) = 'lsouza557@gmail.com';
