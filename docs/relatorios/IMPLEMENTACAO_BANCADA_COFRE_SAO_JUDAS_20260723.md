# Implementacao da bancada e do cofre de Sao Judas

Data: 2026-07-23

## Escopo entregue

- Bancada existente ativada em `-480.5672, 1614.7445, 369.4934`.
- Alinhamento local do personagem em `-480.64, 1613.86, 369.58, 0.0`.
- Interface e callbacks do resource `crafting` reutilizados.
- Acesso restrito ao chefe nivel 1 ou cargo `Operador de Fabricacao` de `SaoJudas`.
- Cinco receitas ilegais centralizadas na configuracao de `sao_judas_operations`.
- Receitas `lockpick`, `blocksignal` e `dismantle` removidas do modo Lester quando `ExclusiveRecipes = true`.
- Opcao `Adicionar dinheiro sujo` adicionada ao target financeiro existente.
- Deposito restrito ao chefe, com proximidade, routing bucket, limite, confirmacao, rate limit, ledger e rollback.

## Receitas finais

| Produto | Lote maximo | Duracao por unidade | Ingredientes por unidade |
|---|---:|---:|---|
| Gazua (`lockpick`) | 5 | 10 s | 30 cobre, 30 aluminio, 2 chapas de metal |
| Bloqueador (`blocksignal`) | 2 | 12 s | 80 plasticos |
| Cartao ilegivel (`dismantle`) | 2 | 12 s | 25 plasticos, 975 dolares sujos |
| Gazua ++ (`lockpickplus`) | 1 | 20 s | 5 gazuas, 100 cobres, 100 aluminios, 10 chapas, 2 molas, 4 componentes eletronicos |
| Pe de cabra (`WEAPON_CROWBAR`) | 1 | 15 s | 4 chapas, 20 aluminios, 1 mola |

O `dirtydollar` da receita de `dismantle` foi preservado porque ja fazia parte da receita original do Lester. Nenhuma taxa adicional foi criada.

## Seguranca da fabricacao

O servidor valida receita, quantidade, cargo, grupo, distancia, routing bucket, vida, materiais, peso, slots, limite diario e capacidade da bancada. A operacao recebe um `craftId` server-side e e persistida em `sao_judas_crafts`.

Os ingredientes ficam reservados por item e slot durante o progresso. O inventario e bloqueado e os materiais sao revalidados e consumidos uma unica vez na conclusao. Essa politica evita retirar itens antes da animacao e elimina a necessidade de recriar materiais em cancelamentos ou reinicios. Nenhum produto e entregue se a sessao for cancelada.

A bancada aceita uma sessao global por vez e uma sessao por passaporte. O servidor rejeita conclusao antecipada e cancela em caso de morte, afastamento, perda de permissao, desconexao, timeout, parada do crafting ou parada de `sao_judas_operations`.

## Deposito de dinheiro sujo

Fluxo:

1. O chefe informa um inteiro entre 1 e 500.000.
2. O servidor valida novamente cargo, distancia e saldo depois da confirmacao.
3. O `dirtydollar` exato e retirado do inventario.
4. A API `CreditDirty` credita `dirty_balance` com operation ID server-side.
5. A transacao e registrada em `sao_judas_vault_transactions`.
6. Se o credito falhar, o mesmo item e quantidade retornam ao slot de origem.

Nao foi criada opcao de retirada, conversao para `dollar` ou envio do saldo sujo ao F9.

## Arquivos

- `resources/[scripts]/sao_judas_operations/config.lua`
- `resources/[scripts]/sao_judas_operations/client.lua`
- `resources/[scripts]/sao_judas_operations/server.lua`
- `resources/[scripts]/crafting/fxmanifest.lua`
- `resources/[scripts]/crafting/shared-side/shared.lua`
- `resources/[scripts]/crafting/client-side/core.lua`
- `resources/[scripts]/crafting/server-side/core.lua`
- `docs/relatorios/AUDITORIA_CRAFTING_SAO_JUDAS_20260723.md`
- `docs/relatorios/IMPLEMENTACAO_BANCADA_COFRE_SAO_JUDAS_20260723.md`

## Diagnostico

Com `SaoJudasOperations.Debug = true`:

- `/saojudas_debug`: distancias client-side.
- `/saojudas_crafting_debug`: permissao, ocupacao e sessao da bancada.
- `/saojudas_vault_debug`: saldos e ultima movimentacao do cofre.

Os comandos server-side aceitam somente o dono de passaporte 1 quando executados por jogador.

## Verificacao executada

- Sintaxe dos seis arquivos Lua alterados validada com `luaparse`.
- Manifesto conferido com dependencias `oxmysql` e `sao_judas_operations`.
- Itens e materiais confirmados no catalogo real da base.
- Exclusividade das tres receitas legadas conferida estaticamente.
- `git diff --check` executado nos arquivos rastreados de `sao_judas_operations`.

## Teste dentro do FiveM

Ainda e necessario validar em jogo:

1. orientacao do heading `0.0` nos modelos masculino e feminino;
2. exibicao das cinco receitas e imagens pela NUI compilada;
3. cada receita com lote minimo e maximo;
4. cancelamento por morte, distancia e interrupcao da animacao;
5. dois jogadores disputando a bancada;
6. deposito valido, saldo insuficiente, clique duplo e rollback simulado;
7. persistencia das tabelas apos restart completo.

## Restart

```text
restart sao_judas_operations
restart crafting
```

Em primeiro teste, recomenda-se reiniciar o servidor completo para garantir a nova ordem de dependencia e a criacao das tabelas.
