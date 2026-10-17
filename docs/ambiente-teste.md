# V10 Teste — banco compartilhado e cards identificados

Branch ativa: `feat/roteiro-offline-testes-identificados`. Versão: 1.1.5+6.

O usuário autorizou em 17/10/2026 os testes no projeto atual usando cards claramente marcados como TESTE. Não criar outro banco nem modificar esquema, políticas/RLS, autenticação ou aplicativo publicado por esta etapa. As branches anteriores permanecem disponíveis.

## Configuração

Usar o flavor `homologacao` (pacote `.test`, nome V10 Teste). Copiar `config/shared-test.example.json` para `config/shared-test.local.json`, preencher a chave pública e o UUID do motorista dedicado cujo nome começa com `TESTE V10 - `. O acesso ao banco atual exige `SHARED_TEST_DATABASE: true` explicitamente. Arquivos locais não são versionados.

```powershell
flutter pub get
flutter analyze --no-fatal-infos
flutter test test/app_environment_test.dart test/navigation_destination_test.dart test/route_notification_test.dart test/shared_test_client_test.dart
flutter build apk --debug --flavor homologacao --dart-define-from-file=config/shared-test.local.json
```

O cliente HTTP adiciona filtro por nome TESTE V10 aos cards e por ID/nome ao motorista dedicado. Alterações fora das tabelas do fluxo de teste e uploads fora da pasta desse motorista são bloqueados neste cliente. Realtime e cache da home também ignoram cards sem a marca. Isso não muda nem substitui permissões no servidor.

## Fluxo a validar

1. Gestor cria `TESTE V10 - Teste 1`, `TESTE V10 - Teste 2` no dashboard de teste.
2. Com o motorista de teste offline, organiza e envia os IDs desses cards.
3. Os cards ficam em `entregas`, vinculados ao motorista, com status `em_rota` e ordem definida.
4. Ao abrir/reconectar o V10 Teste, a consulta REST recupera os pontos e gera aviso local sem exigir reenvio.
5. Reabrir não duplica os cards. Outro motorista não recebe esse roteiro.

O roteiro em entregas é o registro persistente. O despacho não escreve mais UUID em avisos_gestor.motorista_id, que é bigint no esquema atual. Nenhuma conversão de coluna/migração foi feita. Push com o processo encerrado continua pendente; não confundir com receber a rota ao abrir.

## Limites desta etapa

Sem merge, publicação ou instalação sobre o app oficial. Testar no celular ainda é necessário. A limpeza de pendências no logout, a concorrência da fila e a assinatura offline continuam pendentes; esta etapa não certifica o app inteiro para produção. A confirmação de UPDATE no sincronizador passou a exigir retorno do ID antes de remover a evidência local.

Limpeza dos registros: identificar os IDs exatos criados por este teste, conferir nome TESTE antes da exclusão e remover somente esses IDs. Não usar exclusão ampla por status, motorista ou texto genérico. Uma branch apagada não desfaz dados do banco.

O modo isolado anterior continua disponível, mas não é requisito para esta sequência autorizada pelo usuário.

## Aviso sonoro (1.1.5+6)

O histórico de IDs avisados é persistente por motorista e preservado ao sair da conta. Consultas concorrentes são serializadas. Lista vazia, subconjunto e reordenação não apagam esse histórico. Registra antes da chamada nativa; se o Android falhar ou negar permissão, os cards continuam chegando e a mesma entrega não fica tocando a cada consulta. Isso prioriza não repetir: uma interrupção entre gravação e exibição pode deixar um aviso sem som. Novos IDs continuam gerando um aviso por lote consultado.

O logout remove somente sessão e cache visual, sem apagar histórico de avisos ou fila de sincronização. Não desinstalar/limpar dados ao atualizar para preservar o histórico. Validar no celular: reabrir duas vezes sem som; sair e entrar sem som; atribuir novos cards TESTE e conferir um aviso; reabrir e confirmar silêncio.

Não há Firebase/FCM configurado no repositório. Push com processo encerrado ainda requer projeto Firebase, configuração Android do pacote de teste e envio autenticado no servidor. Nenhuma dependência incompleta ou alteração no banco foi adicionada por esta correção.
