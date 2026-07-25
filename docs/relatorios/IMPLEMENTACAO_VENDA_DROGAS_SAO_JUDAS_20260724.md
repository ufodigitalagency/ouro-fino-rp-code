# Implementacao da venda de drogas para NPCs - Sao Judas

Data: 2026-07-24

## Resultado

Foi criado o resource `sao_judas_street_sales` para substituir somente a venda
legada de drogas a NPCs. Os efeitos de consumo existentes no `inventory`
continuam ativos. O novo fluxo usa o target global de ped civil e apresenta a
opcao `OFERECER PRODUTO` apenas para integrantes autorizados de Sao Judas com
produto elegivel.

O servidor e a autoridade sobre autorizacao, NPC, distancia, routing bucket,
produto, quantidade, preco, reacao, inventario, pagamento, cofre, reputacao,
cooldowns e conclusao. O client cuida apenas da selecao e apresentacao da cena.

## Autorizacao no F9

- grupo obrigatorio: `SaoJudas`;
- lideranca nivel 1: acesso automatico;
- demais patentes: tag reservada `Operador de Distribuicao`;
- gerenciamento: tela de Tags ja existente no painel F9;
- persistencia: tabela existente `painel_creative_tags`;
- nao foi criado painel, modal, subcargo ou hierarquia paralela.

A tag e protegida no server do painel: somente a lideranca pode atribuir ou
remover, apenas em membros atuais de Sao Judas, e ela nao pode ser renomeada,
duplicada ou excluida manualmente.

## Produtos habilitados

| Item | Quantidade | Preco unitario inicial |
|---|---:|---:|
| `joint` | 1-3 | 75-100 |
| `cocaine` | 1-3 | 75-100 |
| `meth` | 1-3 | 75-100 |
| `weedsack` | 1 | 500-625 |
| `cokesack` | 1 | 500-625 |
| `methsack` | 1 | 500-625 |

Os demais itens do catalogo permanecem documentados e desabilitados. Nenhuma
droga, receita ou item novo foi criado.

## Fluxo e reacoes

1. O target identifica um ped civil ambientado e elegivel.
2. O servidor cria um `saleId`, bloqueia vendedor e NPC e retorna os produtos
   realmente presentes no inventario.
3. O jogador escolhe o produto no menu existente `keyboard`.
4. O servidor escolhe quantidade, preco, demanda e uma reacao.
5. Aceite executa a troca sincronizada; recusa, denuncia e afastamento possuem
   animacao/comportamento proprio.
6. Na conclusao, o servidor revalida todo o estado antes de remover produto e
   pagar.

Chances iniciais configuraveis:

- aceita: 65%;
- recusa: 22%;
- denuncia: 8%;
- afasta-se: 5%.

O dispatch inicia desabilitado para testes. Quando habilitado, usa o dispatch
real da base com coordenada aproximada e somente na reacao de denuncia.

## Economia

O pagamento e sempre `dirtydollar`:

- trabalhador: 85%;
- cofre sujo de Sao Judas: 15%.

O credito da faccao reutiliza
`exports.sao_judas_operations:CreditDirty`. O identificador da venda e usado
como referencia idempotente. Se o credito do cofre falhar, o pagamento pessoal
e revertido e o produto e devolvido; uma falha de rollback e registrada como
critica para intervencao administrativa, sem repeticao silenciosa.

## Reputacao

A tabela `sao_judas_distribution_reputation` persiste vendas, unidades, valor
bruto, recusas, denuncias, ultima venda e nivel. Os cinco niveis iniciais sao:

1. Iniciante;
2. Conhecido;
3. Vendedor;
4. Distribuidor;
5. Referencia.

A reputacao aplica bonus pequenos e configuraveis de preco e aceitacao. Cada
venda possui `ReputationApplied`, impedindo aplicar o progresso duas vezes.

## Antifraude e concorrencia

- uma sessao por jogador e um vendedor por NPC;
- limite de tentativas por minuto;
- cooldown por jogador e por NPC;
- cooldown persistente do NPC por chave composta;
- validacao de tipo do ped, vida, veiculo, distancia e routing bucket;
- bloqueio em safe zone, morte ou veiculo;
- sessao com validade e cleanup em cancelamento/desconexao/restart;
- allowlist server-side de produtos;
- valores e reacoes nunca aceitos do client;
- vendas antigas em andamento sao canceladas na inicializacao;
- venda legada no `inventory` desabilitada em client e server.

## Banco de dados

Tabelas criadas automaticamente:

- `sao_judas_street_sales`: sessao, NPC, produto, valores, reacao, status,
  timestamps e controle de reputacao;
- `sao_judas_distribution_reputation`: progresso permanente por passaporte.

A tabela financeira existente de Sao Judas continua sendo a unica fonte do
saldo do cofre.

## Diagnostico

Com debug habilitado, apenas o passaporte configurado como dono pode executar:

```text
/saojudas_sales_debug
```

O console do FXServer tambem pode executar `saojudas_sales_debug`. O snapshot
mostra autorizacao, produtos, NPC, sessao, distancia, bucket, regiao, demanda,
reacao, cooldown, reputacao, pagamento, cofre, banco e configuracao.

Teste estatico reproduzivel:

```powershell
& .\tools\test-sao-judas-street-sales.ps1
```

## Arquivos

- `resources/[scripts]/sao_judas_street_sales/fxmanifest.lua`;
- `resources/[scripts]/sao_judas_street_sales/config.lua`;
- `resources/[scripts]/sao_judas_street_sales/client.lua`;
- `resources/[scripts]/sao_judas_street_sales/server.lua`;
- `resources/[scripts]/sao_judas_operations/config.lua`;
- `resources/[scripts]/sao_judas_operations/server.lua`;
- `resources/[scripts]/painel/server-side/core.lua`;
- `resources/[scripts]/target/client-side/core.lua`;
- `resources/[scripts]/inventory/client-side/drugs.lua`;
- `resources/[scripts]/inventory/server-side/drugs.lua`;
- `tools/test-sao-judas-street-sales.ps1`.

## Reinicio

Em uma janela de manutencao, reiniciar nesta ordem:

```text
restart painel
restart target
restart sao_judas_operations
start inventory
start crafting
start sao_judas_street_sales
```

Um restart completo do servidor inicia tudo pela categoria `[scripts]` e evita
que dependentes do `target` permaneçam parados.

## Validacao executada

- resource iniciado e reiniciado pelo FXServer sem erro;
- comando de diagnostico executado no console;
- tabelas e tag operacional confirmadas no MariaDB;
- nove arquivos Lua analisados sintaticamente com `luaparser`;
- teste estatico passou para dependencias, economia, permissao, cofre, target,
  reputacao, idempotencia e desligamento do legado.

## Limitacoes e teste em jogo

O ambiente automatizado nao possui um jogador conectado. Portanto ainda devem
ser validados manualmente: visibilidade do target, menu de produto, animacoes,
as quatro reacoes, cancelamento por movimento, inventario cheio, concorrencia
com dois jogadores e exibicao exata das notificacoes. O suporte a imagens no
menu depende do componente `keyboard`; os indices dos itens sao enviados, mas
o menu existente pode apresentar somente texto.

As areas customizadas de demanda estao vazias nesta primeira versao. A cidade
usa multiplicador normal e a variacao baixa/normal/alta continua ativa. O
dispatch deve permanecer desligado ate a aprovacao do fluxo em jogo.
