# V10 Teste — ambiente separado (etapa 1, 17/10/2026)

Branch: `feat/roteiro-offline-seguro`. Versão: 1.1.3+4. Sem merge/publicação em produção.

## Instalação identificável e configuração reproduzível

- Flavor `homologacao` (padrão): pacote `com.example.app_do_motorista.test`, nome “V10 Teste”, sufixo de versão `-teste`, faixa TESTE na interface. O sufixo vale tanto para debug quanto para release.
- Flavor `producao`: mantém o pacote original e nome “V10 Delivery”. Não usar nesta etapa. A assinatura release ainda é a configuração antiga de debug e não é certificada para distribuição oficial.
- A configuração do banco é recebida por dart-define. Não há URL/chave de produção como fallback. O flavor real compilado define o ambiente; não há um APP_ENV separado que permita ligar o flavor de teste à produção conhecida.
- Configuração ausente/inválida mostra uma tela explicativa antes de inicializar Supabase, permissões, sincronização e presença.

## Preparação no Windows

1. Usar um banco separado de homologação e o esquema real do projeto V10, com dados fictícios. O acesso ao projeto V10/estrutura não estava disponível nesta sessão; essa etapa permanece pendente.
2. Copiar `config/test.example.json` para `config/test.local.json` e preencher `SUPABASE_PROJECT_REF`, `SUPABASE_URL` e `SUPABASE_ANON_KEY` do mesmo projeto de testes. Somente chave pública; não usar service_role ou sb_secret. O arquivo local é ignorado pelo Git.
3. Executar:

```powershell
flutter pub get
flutter analyze --no-fatal-infos
flutter test test/app_environment_test.dart test/navigation_destination_test.dart test/route_notification_test.dart
flutter build apk --debug --flavor homologacao --dart-define-from-file=config/test.local.json
```

APK esperado: `build/app/outputs/flutter-apk/app-homologacao-debug.apk`. Conferir ID/nome/versão antes de instalar e manter o app oficial instalado. Não desinstalar o app oficial nem remover dados/pendências dele.

Com o template vazio, o APK apenas mostra o bloqueio de configuração; não é uma versão pronta para testar entregas. A CI usa esse template intencionalmente para compilar sem credenciais e sem banco real.

## Limites

A guarda recusa o projeto de produção conhecido, URL divergente e chave administrativa. Ela não substitui permissões/RLS, não certifica qualquer banco desconhecido como ambiente fictício e não verifica online a propriedade de uma chave publishable. Conferir esses pontos antes da homologação real.

Os problemas da fila offline encontrados na auditoria ainda não foram corrigidos nesta etapa: perda no logout, concorrência, associação ao motorista, confirmação de UPDATE e preservação da assinatura. Não usar o APK para operação real.

A suíte Flutter e o APK precisam de execução no ambiente Android/CI; não há SDK Flutter/Dart disponível localmente nesta sessão. Não declarar homologação concluída só por um build passar. O teste widget de SplashView e o script de diagnóstico realtime antigos não foram executados nesta etapa.

Próximo aceite: rota de A enviada enquanto A está offline, recebida ao abrir/reconectar, ordem preservada, B sem acesso, sem duplicação e comprovantes conservados offline.

Referências: https://docs.flutter.dev/deployment/flavors e https://supabase.com/docs/guides/deployment/managing-environments
