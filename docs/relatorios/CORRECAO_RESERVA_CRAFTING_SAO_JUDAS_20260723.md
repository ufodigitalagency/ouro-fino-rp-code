# Correcao da reserva de crafting de Sao Judas

Data: 2026-07-23

## Resultado

A falha foi confirmada como uma interpretacao incorreta do retorno de
`oxmysql:insert_async`. A tabela `sao_judas_crafts` usa `CraftId` textual como
chave primaria e nao possui coluna `AUTO_INCREMENT`. Por isso, um `INSERT`
valido podia persistir a linha e retornar `insertId = 0`. O codigo tratava esse
zero como falha e exibia "Nao foi possivel reservar esta fabricacao".

## Comportamento anterior

O fluxo anterior executava um `INSERT IGNORE` por `insert_async` e aceitava a
reserva apenas quando o retorno numerico era maior que zero. Esse criterio nao
serve para uma tabela sem chave auto incrementada.

Consequencia observada:

1. a linha era gravada com `Status = processing`;
2. a aplicacao recebia `0` como insertId;
3. a sessao nao era criada;
4. materiais e produto nao eram movimentados;
5. o registro permanecia orfao em `processing`.

## Correcao aplicada

Arquivo:

- `resources/[scripts]/crafting/server-side/core.lua`

Alteracoes:

- `insert_async` foi substituido por `update_async` com `INSERT INTO` normal;
- `INSERT IGNORE` foi removido para nao esconder colisao de chave ou erro SQL;
- a reserva e aceita somente quando `AffectedRows == 1`;
- `prepareSaoJudasDatabase()` agora retorna `true` ou `false,error`;
- `SaoJudasPrepared` so vira `true` depois do `CREATE TABLE` bem-sucedido;
- falhas de preparacao nao bloqueiam tentativas futuras;
- atualizacoes de status tambem validam uma linha afetada;
- o limite diario falha de forma fechada se o banco estiver indisponivel;
- em modo Debug, um `SELECT` confirma `CraftId` e `Status` apos a reserva.

O log de falha agora informa:

- passaporte;
- receita;
- `CraftId`;
- quantidade;
- tamanho do JSON de materiais;
- estado da preparacao;
- resultado do `pcall`;
- linhas afetadas;
- tipo do retorno;
- erro SQL real.

## Registros orfaos

A consulta solicitada encontrou quatro tentativas do passaporte 1 inseridas
como `processing` pelo falso negativo:

| CraftId | Receita | Correcao |
|---|---|---|
| `SJ-1-1784844794-74GW38` | `lockpick` | `cancelled / false_insert_failure` |
| `SJ-1-1784844551-80SM04` | `lockpick` | `cancelled / false_insert_failure` |
| `SJ-1-1784844507-58WX51` | `lockpick` | `cancelled / false_insert_failure` |
| `SJ-1-1784844498-25JB18` | `lockpick` | `cancelled / false_insert_failure` |

Foram atualizadas quatro linhas. Nenhum registro foi apagado, nenhum produto
foi entregue e nenhum material foi removido ou devolvido.

## Prova no banco

Foi executado um teste transacional com o mesmo formato de `INSERT` usado pela
aplicacao:

```text
affected_rows: 1
CraftId: AUDIT-RESERVATION-20260723
Status: processing
rows_after_rollback: 0
```

O teste comprovou que:

- a tabela aceita a reserva textual;
- o criterio correto e uma linha afetada;
- a linha fica imediatamente consultavel;
- o `ROLLBACK` removeu integralmente a linha de teste.

## Verificacao tecnica

- sintaxe do Lua validada com `luaparse`;
- `git diff --check` executado sem erro nos commits da correcao;
- `INSERT` real validado dentro de transacao e revertido;
- quatro registros orfaos corrigidos e preservados no historico.

## Teste dentro do FiveM

O teste em jogo ainda precisa ser executado pelo proprietario. Nao foi marcado
como aprovado sem essa evidencia.

Roteiro:

1. reiniciar `crafting`;
2. colocar 30 cobres, 30 aluminios e 2 chapas no inventario;
3. fabricar uma Gazua;
4. confirmar `affectedRows=1` no terminal com Debug ativo;
5. confirmar sessao criada e progresso de 10 segundos;
6. confirmar consumo exato dos tres materiais;
7. confirmar uma unica `lockpick` e `Status=completed`;
8. repetir com clique duplo e confirmar uma unica reserva;
9. cancelar outra fabricacao e confirmar `Status=cancelled`;
10. reiniciar o resource durante uma sessao e confirmar cancelamento sem
    entrega, perda ou duplicacao.

## Commits

- `ca63cf1 fix(crafting): use affected rows for Sao Judas craft reservation`
- `7f7d495 fix(crafting): expose real database reservation failures`

## Restart

```text
restart crafting
```
