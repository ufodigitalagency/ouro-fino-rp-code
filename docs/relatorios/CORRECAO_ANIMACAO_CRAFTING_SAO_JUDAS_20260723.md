# Correcao da animacao do crafting de Sao Judas

Data: 2026-07-23

## Problema

O crafting chegava a 100%, mas era gravado como `cancelled` com o motivo
`animation_interrupted`. Os CraftIds reportados antes da correcao foram:

- `SJ-1-1784846640-39DI18`
- `SJ-1-1784846682-97DA43`

Os dois continuam no banco como `cancelled / animation_interrupted`. Nenhum
produto foi entregue e os materiais nao foram consumidos. Nenhum reembolso
adicional foi aplicado.

## Causa exata

O client executava a animacao com a mesma duracao da receita. Ao terminar o
tempo, a animacao podia parar naturalmente antes de o callback de conclusao
chamar o servidor. O monitor verificava `IsEntityPlayingAnim` sem tolerancia e
enviava `CancelSaoJudas(..., "animation_interrupted")` imediatamente.

A ordem anterior era:

1. barra atingia 100%;
2. animacao parava ou era limpa;
3. monitor solicitava cancelamento;
4. servidor gravava `cancelled`;
5. conclusao chegava tarde demais.

## Correcao client-side

Foi criada uma maquina de estados com:

`idle -> starting -> processing -> completing -> completed -> idle`

O cancelamento usa:

`processing -> cancelling -> cancelled -> idle`

Ao terminar o progresso, o client entra em `completing` antes de chamar
`CompleteSaoJudas`. O monitor nao pode mais cancelar depois dessa transicao. A
animacao somente e limpa depois da resposta do servidor.

A animacao `machinic_loop_mechandplayer` agora usa duracao `-1` e flag `49`,
mantendo o loop sob controle do fluxo de crafting.

O monitor possui:

- tolerancia inicial: 750 ms;
- tolerancia de ausencia: 750 ms;
- janela ignorada perto do fim: 1000 ms;
- intervalo de verificacao: 150 ms.

Uma unica leitura negativa de `IsEntityPlayingAnim` nao cancela mais a sessao.
Morte, entrada em veiculo, ragdoll e afastamento continuam interrompendo o
processo.

## Correcao server-side

A conclusao foi centralizada em `completeSaoJudasSession`. As respostas agora
informam explicitamente `Success`, `Status` e `Reason`.

O servidor:

- aceita somente `client_cancelled`, `animation_interrupted` e
  `progress_cancelled` como motivos enviados pelo client;
- recusa `animation_interrupted` tardio e retorna `ready_to_complete`;
- usa tolerancia final de 350 ms sem liberar produto antes do tempo;
- mantem consumo, entrega e persistencia idempotentes por sessao;
- oferece consulta somente leitura por `GetSaoJudasCraftStatus` quando a
  resposta de conclusao for incerta.

## Testes no FiveM

Os testes foram executados em um FXServer local com um cliente FiveM real,
passaporte 1, usando a bancada e o fluxo client/server do resource.

### Cancelamento manual em 50%

- CraftId: `SJ-1-1784848332-08CP89`
- Resultado: `cancelled / progress_cancelled`
- Materiais: preservados
- Produto: nenhum

### Fabricacao normal completa

- CraftId: `SJ-1-1784848360-04LY82`
- Resultado: `completed`
- Antes da resposta, o log mostrou `state=completing` e a animacao ativa
- Materiais consumidos: 30 copper, 30 aluminum e 2 sheetmetal
- Produto entregue: 1 lockpick (Gazua)

### Interrupcao precoce

- CraftId: `SJ-1-1784848570-11XI43`
- Animacao interrompida em aproximadamente 1,5 segundo
- Cancelamento ocorreu somente depois da tolerancia de ausencia
- Resultado: `cancelled / animation_interrupted`
- Materiais: preservados
- Produto: nenhum

### Interrupcao entre 95% e 100%

- CraftId: `SJ-1-1784848604-79FG38`
- Animacao interrompida em aproximadamente 9,5 segundos
- Resultado: `completed`
- Nenhum cancelamento falso foi emitido
- O client entrou em `completing` e o servidor decidiu pelo tempo real

As duas conclusoes separadas validaram a repeticao sem
`animation_interrupted` no fim. O produto extra criado somente para o segundo
ensaio foi removido apos a verificacao. O inventario final manteve apenas a
Gazua legitima da fabricacao normal.

## Validacoes adicionais

- Os resources `sao_judas_operations` e `crafting` reiniciaram no FXServer sem
  erro de carga Lua.
- O codigo temporario usado para os ensaios foi removido.
- `Debug` voltou para `false`.
- O diff nao altera receitas, materiais, duracoes, drops, permissoes, cofre ou
  banco F9.

Os cenarios de dois jogadores simultaneos, perda de funcao durante o craft e
restart no meio da sessao nao foram reproduzidos nesta rodada por haver apenas
um cliente local conectado. As validacoes server-side existentes para contexto,
sessao unica, materiais reservados e parada de resource foram preservadas.

## Reinicio

Como `crafting` depende de `sao_judas_operations`, aplicar na ordem:

```text
restart sao_judas_operations
start crafting
```
