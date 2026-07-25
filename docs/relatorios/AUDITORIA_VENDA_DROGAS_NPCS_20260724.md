# Auditoria da venda de drogas para NPCs - 2026-07-24

## Resumo executivo

Existe um fluxo legado de venda para NPCs dentro do resource `inventory`:

- client: `resources/[scripts]/inventory/client-side/drugs.lua`;
- server: `resources/[scripts]/inventory/server-side/drugs.lua`;
- estado compartilhado: tabela global `Drugs` em `inventory/server-side/core.lua`;
- pagamento policial: export `exports.vrp:CallPolice`;
- progressao anterior: experiencia generica `Traffic`.

O fluxo nao deve continuar ativo em paralelo. Ele pode fornecer referencias de
animacao, itens e precos, mas sua selecao de ped, sessao e pagamento precisam
ser substituidos por uma implementacao server-side autoritativa.

## Fluxo legado

1. Uma thread client procura o ped mais proximo percorrendo `GetGamePool("CPed")`.
2. O jogador pressiona E perto do NPC.
3. `CheckDrugs` escolhe o primeiro item disponivel durante um `pairs(List)`.
4. O client controla o NPC, inicia animacoes e aguarda o tempo informado.
5. O client chama `PaymentDrugs` quando considera a animacao concluida.
6. O server remove o item, aplica bonus e gera `dirtydollar`.
7. O dispatch generico pode ser acionado.

## Itens e economia legados

| Item | Nome real | Quantidade | Preco unitario | Tempo | Chance policial configurada |
|---|---|---:|---:|---:|---:|
| `joint` | Cigarro de Cannabis | 2-4 | 75-100 | 15 s | 10% |
| `cocaine` | Carreira de Cocaina | 2-4 | 75-100 | 15 s | 10% |
| `meth` | Metanfetamina | 2-4 | 75-100 | 15 s | 10% |
| `weedsack` | Pacote de Cannabis | 1 | 500-625 | 30 s | 27,5% |
| `cokesack` | Pacote de Cocaina | 1 | 500-625 | 30 s | 27,5% |
| `methsack` | Pacote de Metanfetamina | 1 | 500-625 | 30 s | 27,5% |

Observacao: no export `CallPolice`, `Percentage` representa a chance de o
alerta ser ignorado. Por isso 900 equivale a aproximadamente 10% de chamada e
725 a aproximadamente 27,5%.

## Falhas encontradas

- varredura pesada de todos os peds com espera de 1 ms quando existe alvo;
- tecla E paralela ao target oficial;
- nenhuma autorizacao de Sao Judas;
- escolha do produto por ordem nao deterministica de `pairs`;
- nenhuma escolha explicita de produto pelo jogador;
- nenhum `saleId` server-side;
- nenhum estado persistente de venda;
- nenhum bloqueio server-side por NPC;
- nenhum cooldown server-side por NPC;
- nenhuma validacao server-side da entidade, modelo, tipo, vida ou bucket;
- nenhuma revalidacao server-side de distancia na conclusao;
- o client decide quando a venda terminou;
- pagamento nao idempotente por operacao;
- ausencia de recusa, denuncia e afastamento como resultados reais;
- ausencia de bloqueio de safe zone;
- ausencia de reputacao especifica de Sao Judas;
- pagamento integral ao jogador, sem divisao com o cofre;
- bonus de VIP, spray e buff tornam o valor mais dificil de auditar;
- o NPC pode ficar marcado ou com tarefas alteradas sem cleanup central.

## Catalogo real de drogas

As imagens abaixo existem em `resources/vrp/config/inventory/<Index>.png`.
Nenhum desses itens possui `Durability` no catalogo atual.

| Index | Nome | Peso | Economy | Uso/efeito confirmado | Fonte confirmada | Venda legado |
|---|---|---:|---:|---|---|---|
| `joint` | Cigarro de Cannabis | 0,25 | 25 | fumado com isqueiro; stress e efeito `Joint` | `drugs_bench`; rota 1-3 (25%) | sim |
| `weedsack` | Pacote de Cannabis | 2,50 | 250 | pacote de 10 `joint`; sem uso direto | `drugs_bench` | sim |
| `cocaine` | Carreira de Cocaina | 0,25 | 25 | animacao, stress e efeito `Cocaine` | `drugs_bench`; rota 1-3 (25%) | sim |
| `cokesack` | Pacote de Cocaina | 2,50 | 250 | pacote de 10 `cocaine`; sem uso direto | `drugs_bench` | sim |
| `meth` | Metanfetamina | 0,25 | 25 | efeito `Methamphetamine` e armadura | `drugs_bench`; rota 1-3 (25%) | sim |
| `methsack` | Pacote de Metanfetamina | 2,50 | 250 | pacote de 10 `meth`; sem uso direto | `drugs_bench` | sim |
| `crack` | Seringa de Crack | 0,25 | 375 | efeito `Crack` e timer quimico | `drugs_bench` | nao |
| `heroin` | Seringa de Heroina | 0,25 | 525 | efeito `Heroin` e timer quimico | `drugs_bench` | nao |
| `metadone` | Seringa de Metadona | 0,25 | 475 | efeito `Metadone` e timer quimico | `drugs_bench` | nao |
| `codeine` | Seringa de Codeina | 0,25 | 425 | catalogo e receita; sem consumidor direto localizado | `drugs_bench` | nao |
| `amphetamine` | Seringa de Anfetamina | 0,25 | 325 | catalogo e receita; sem consumidor direto localizado | `drugs_bench` | nao |

Para preservar a economia aprovada, a primeira versao segura deve habilitar
somente os seis itens que ja participavam da venda legada. Os demais ficam
documentados e desabilitados ate aprovacao explicita de preco e gameplay.

## F9 e autorizacao operacional

O grupo canonico e `SaoJudas`, com alias legado `Vagos`. O nivel 1 e a
lideranca. O F9 ja possui tags persistentes e independentes de patente na
tabela `painel_creative_tags`, incluindo atribuicao e remocao por membro.

A funcao `Operador de Distribuicao` sera uma tag operacional reservada de
`SaoJudas`, gerenciada pela tela de Tags ja existente no F9. Isso permite que
ela conviva com qualquer patente sem criar painel, modal ou hierarquia
paralela.

## Integracoes oficiais encontradas

- cofre: `exports.sao_judas_operations:CreditDirty`;
- membro: `exports.sao_judas_operations:IsMember`;
- lideranca: `exports.sao_judas_operations:IsLeader`;
- safe zone: state bag server-side `Player(source).state.Safezone`;
- target: branch global de peds civis em `target/client-side/core.lua`;
- menu: `exports.keyboard:Instagram` com opcoes Label/Value;
- pagamento: `vRP.TakeItem`, `vRP.CheckWeight`, `vRP.MaxItens` e
  `vRP.GenerateItem`;
- dispatch: `exports.vrp:CallPolice` com coordenada aproximada fornecida pelo
  novo sistema.

## Decisao de arquitetura

Criar `resources/[scripts]/sao_judas_street_sales` e desativar apenas a entrada
de venda legada no `inventory`. Os efeitos de uso de drogas permanecem
inalterados. O novo resource centraliza sessoes, NPCs, reputacao, pagamento,
cofre, cooldown e diagnostico, sem duplicar saldo financeiro ou painel F9.

