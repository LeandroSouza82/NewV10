# Relatório — atualização e ordenação dos cards do NewV10

Data: 30/10/2026.
Repositório: `LeandroSouza82/NewV10`.
Branch: `fix/atualizar-cards-por-distancia`.
Base: `main`, commit `d3d39683ed19b22dcf9531ba37d764e8f14a4071`, já com a correção de navegação do PR #3.

## Problema e causa encontrada

O gesto de puxar a lista para baixo disparava o recálculo, esperava somente 500 ms e ordenava os valores disponíveis naquele momento. O serviço existente trabalha de forma assíncrona: quando a resposta chegava depois desse prazo, o listener atualizava os valores dos cards, mas não repetia a ordenação solicitada. Isso explica a combinação de distância atualizada com posição antiga do card. A alteração de navegação do PR #3 foi preservada; não se atribui a ela uma regressão sem evidência.

Além disso, a lista não definia `AlwaysScrollableScrollPhysics`. Quando os cards cabiam na tela, o gesto podia não armar o indicador de atualização.

## Correção

A alteração de produção está somente em `lib/widgets/draggable_route_list.dart`:

- O refresh agora aguarda a notificação de distâncias para todos os IDs da lista atual e só então ordena do menor para o maior valor.
- A espera fixa de 500 ms foi removida. O indicador acompanha a conclusão da atualização; há limite de espera de 20 segundos para não ficar preso sem resultado. Se o resultado chegar depois, a solicitação de ordenação ainda é atendida.
- Listas curtas também aceitam o gesto de puxar para atualizar.
- Atualizações passivas do GPS continuam atualizando os números sem ficar reorganizando os cards durante o uso.
- Um arraste manual cancela uma ordenação automática pendente; sair da tela conclui a espera com segurança.
- O listener é registrado antes de enviar a lista ao serviço, para também receber resultados imediatos de cache.

A comparação numérica e os cálculos das distâncias existentes foram preservados. A mudança usa a posição e os valores que o serviço já produz, sem criar outro mecanismo de localização.

## Preservação conferida

Comparação byte a byte com a base confirmou conteúdo idêntico em:

- `lib/services/location_service.dart`;
- `lib/core/utils/location_utils.dart`;
- `lib/core/utils/navigation_utils.dart`;
- `lib/main.dart`;
- `lib/views/home_view.dart`;
- `lib/services/supabase_service.dart`.

Não foram alterados cabeçalho, indicadores superiores, estilos/cores dos cards, botões de ação, endereços, GPS, cache de distância ou regras de coleta/baixa/falha. Nenhuma dependência do aplicativo foi adicionada pela correção.

## Validação

Ambiente: Flutter 3.41.9 e Dart 3.11.5.

- `flutter test --no-pub test/draggable_route_list_refresh_test.dart --reporter expanded`: **7 testes passaram** no projeto real, com o corpo original do widget e suas dependências. A distância é controlada no notifier para simular respostas; não é teste de GPS físico nem de rede real.
- `flutter analyze --no-pub lib/widgets/draggable_route_list.dart test/draggable_route_list_refresh_test.dart`: **No issues found**.
- O teste de resposta atrasada manteve o indicador pendente após 800 ms e confirmou a inversão dos clientes: B a 2,5 km acima de A a 5 km.
- O teste de lista curta executou um gesto real no widget, esperou o indicador entrar em atualização e confirmou a nova ordem. A simulação aguarda a animação do Flutter antes de publicar o resultado.
- Os outros cenários confirmaram que GPS passivo não muda a ordem, resultado parcial não encerra a espera, arraste manual prevalece, resposta tardia após timeout ainda ordena e sair da tela não gera erro.
- `pubspec.yaml` e `pubspec.lock` permaneceram inalterados.

Os testes de regressão estão em `test/draggable_route_list_refresh_test.dart`. Cobrem resposta após 800 ms, atualização passiva, gesto real em lista curta, resultado parcial, arraste manual durante a espera, timeout com resposta tardia e descarte da tela.

O arquivo de produção foi analisado sintaticamente pelo parser/formatter do Dart sem gravar formatação em massa. `git diff --check` passou.

## Validação no aparelho e entrega

Não houve geração, instalação de APK nem teste com GPS físico nesta execução. O aplicativo já instalado no celular não é alterado por um commit no GitHub. É necessário gerar e instalar a versão contendo esta branch para a conferência final.

Teste sugerido: manter o cliente A a 5 km acima do cliente B a 2,5 km; puxar para baixo e aguardar a atualização. O cliente B deve subir e os números dos cards devem acompanhar a nova ordem. Repetir com poucos cards e rede mais lenta; conferir que arrastar manualmente continua funcionando e que a navegação ROTA preserva o endereço já corrigido.
