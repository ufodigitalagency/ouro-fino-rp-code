# Correção do minigame de Gazua - 24/07/2026

## Escopo

Correção restrita ao contrato do minigame `taskbar` e ao fluxo dos itens
`lockpick` e `lockpickplus` do resource `inventory`. Não foram alterados
desmanche, pagamentos, lavagem, bancada de São Judas, F9, cofres ou economia.

## Auditoria

- Item e desbloqueio: `resources/[scripts]/inventory/server-side/itens.lua`.
- Minigame: `resources/[scripts]/taskbar/client-side/core.lua`.
- NUI do minigame: `resources/[scripts]/taskbar/web-side`.
- Ponte vRP antiga: `resources/vrp/modules/vrp.lua`, função `vRP.Task`.
- Seleção do veículo: `resources/vrp/client/vehicles.lua`, função
  `VehicleList`.
- Integração do Pombal: o desmanche consulta
  `Entity(vehicle).state.Lockpick` em
  `resources/[scripts]/inventory/server-side/pombal_dismantle.lua`.

O fluxo anterior executava o minigame por rodadas e recebia um booleano. A
NUI, porém, enviava `Success` e `Failure` sem identificar tentativa ou rodada.
O client também mantinha `Results` e `Progress` compartilhados entre as
rodadas. Assim, um callback atrasado de uma rodada anterior podia encerrar a
rodada seguinte com o resultado incorreto. O servidor recebia apenas o
booleano final de `vRP.Task`, sem contagem de acertos/falhas ou estado terminal
para conferir.

## Causa

A causa não era uma condição Lua que preservava deliberadamente um sucesso
parcial no laço: o laço antigo já interrompia em `not Minigame`. A falha estava
no contrato assíncrono ao redor dele:

1. callbacks da NUI sem identidade de rodada;
2. estado client global reutilizado entre rodadas;
3. ausência de trava para a primeira resposta terminal;
4. retorno final reduzido a booleano e aceito sem evidência das rodadas;
5. fluxo da Gazua começando a animação longa antes do sucesso completo.

## Contrato novo

O `taskbar` agora expõe `TaskDetailed`, que retorna uma tabela explícita:

```lua
{
    Success = true | false,
    Status = "success" | "failed" | "cancelled",
    Terminal = true,
    RequiredRounds = number,
    SuccessfulRounds = number,
    FailedRounds = number,
    Rounds = { ... }
}
```

Cada rodada recebe um token baseado em `attemptId`, número da rodada e timer.
O bridge `round-guard.js` inclui esse token nos callbacks da NUI. O client
aceita somente callback com o token atual e somente a primeira resposta
terminal.

O servidor considera sucesso apenas quando todas as condições são verdadeiras:

```lua
type(Result) == "table"
and Result.Success == true
and Result.Status == "success"
and Result.Terminal == true
and SuccessfulRounds == RequiredRounds
and FailedRounds == 0
```

`Lil.Task` continua disponível para os demais scripts e converte o contrato
detalhado em booleano explícito, preservando compatibilidade.

## Fluxo da Gazua

Cada tentativa possui `AttemptId`, passaporte, source, network ID, placa,
modelo, item completo, slot, início, expiração, status e travas de consumo e
desbloqueio. Um passaporte não pode manter duas tentativas simultâneas.

Estados utilizados:

```text
starting -> minigame -> failed/cancelled
starting -> minigame -> succeeded -> unlocking -> completed
```

Falha ou cancelamento agora:

- encerra a tentativa;
- cancela animações;
- limpa `Active` e `Buttons`;
- mantém o veículo bloqueado;
- não cria `state.Lockpick`;
- não inicia a progressbar longa;
- aplica uma única vez a regra de desgaste existente.

Sucesso completo agora:

- revalida item, jogador, veículo e tentativa no servidor;
- inicia a animação/progressbar somente depois do minigame;
- revalida novamente após os 15 segundos;
- desbloqueia uma única vez;
- cria `state.Lockpick` somente após desbloqueio efetivo de veículo NPC;
- preserva o dispatch existente.

## Segurança server-side

Antes do fluxo e antes do desbloqueio final são conferidos:

- source e passaporte da tentativa;
- `AttemptId` ativo e TTL;
- item exato e slot ainda válidos;
- entidade e network ID;
- placa e modelo selecionados originalmente;
- distância máxima de 6 metros;
- routing bucket;
- lock state ainda bloqueado;
- rate limit;
- estado terminal e trava de desbloqueio único.

Não existe evento client que receba um booleano e destranque livremente um
veículo.

## Gazua normal e Gazua ++

Regras preservadas:

| Item | Fora do veículo | Dentro do veículo | Velocidade | Desgaste existente |
|---|---:|---:|---:|---:|
| `lockpick` | 5 rodadas | 10 rodadas | 5000 | 12,5% fora do veículo |
| `lockpickplus` | 5 rodadas | 5 rodadas | 5000 | sem desgaste nesse fluxo |

Não foi criada tolerância oculta para Gazua ++. Qualquer falha terminal encerra
a tentativa dos dois itens.

## Dispatch e desmanche

O comportamento econômico e policial existente foi mantido: o dispatch ocorre
no ramo de sucesso, como antes. A correção não alterou sua chance nem seu
conteúdo.

O Pombal continua reconhecendo o veículo pela state bag `Lockpick`. A diferença
é que essa state bag só nasce depois de minigame completo, progresso concluído,
revalidação e desbloqueio efetivo. Falha parcial, cancelamento e tentativa
expirada não geram registro de furto.

## Testes no FiveM

Os testes foram executados com FXServer e um cliente FiveM real conectados. Um
harness temporário injetou resultados determinísticos no mesmo
`TaskDetailed`, mantendo seleção de veículo, inventário, tentativa server-side,
progressbar, lock state e state bag reais. O harness foi removido antes da
entrega.

| Cenário | Resultado observado |
|---|---|
| Falha imediata | 0 acertos, 1 falha, lock state 2, sem furto, sem `Active` |
| Acerto seguido de falha | 1 acerto, 1 falha, `finalStatus=failed`, lock state 2, sem furto |
| Sucesso completo | 5 acertos, 0 falhas, progresso de 15 s, veículo aberto, `Lockpick=1` |
| Cancelamento | `finalStatus=cancelled`, lock state 2, sem furto |
| Callback duplo | primeira falha aceita; sucesso tardio rejeitado; resultado final `false` |
| Gazua ++ com acerto e falha | 1 acerto, 1 falha, lock state 2, sem furto |
| Sem item | tentativa recusada; veículo permaneceu bloqueado |
| Distante | tentativa recusada; veículo permaneceu bloqueado |
| Veículo já aberto | tentativa recusada; nenhum furto criado |
| AttemptId expirado | sucesso visual recusado na revalidação; veículo bloqueado |
| Network ID inválido | entidade recusada antes da tentativa |

Evidência principal do caso relatado:

```text
successfulRounds=1
failedRounds=1
finalStatus=failed
vehicleUnlocked=false
stolenRecord=false
doorLock=2
```

Evidência do sucesso completo:

```text
successfulRounds=5
failedRounds=0
finalStatus=completed
vehicleUnlocked=true
stolenRecord=true
```

O bridge NUI também foi testado em Node com duas aberturas consecutivas. Os
callbacks carregaram, respectivamente, `attempt:1` e `attempt:2`, sem reutilizar
o token anterior.

Após remover o harness, `taskbar` e `inventory` foram reiniciados novamente e
carregaram sem erro novo de Lua.

## Arquivos alterados

- `resources/[scripts]/taskbar/client-side/core.lua`
- `resources/[scripts]/taskbar/web-side/index.html`
- `resources/[scripts]/taskbar/web-side/round-guard.js`
- `resources/[scripts]/inventory/fxmanifest.lua`
- `resources/[scripts]/inventory/lockpick-server/core.lua`
- `docs/relatorios/CORRECAO_MINIGAME_LOCKPICK_20260724.md`

## Reinício

```text
restart taskbar
restart inventory
```
