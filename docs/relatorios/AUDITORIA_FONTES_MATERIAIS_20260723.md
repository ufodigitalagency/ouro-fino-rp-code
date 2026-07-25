# Auditoria de fontes e consumos da bancada de Sao Judas

Data: 2026-07-23

## Escopo e criterio

Foram auditados `copper`, `aluminum`, `sheetmetal`, `plastic`, `metalspring`,
`electroniccomponents`, `lockpick` e `dirtydollar`. Uma referencia em receita,
loja de venda ou reciclagem foi classificada como consumo, e nao como fonte.

As listas processadas por `RandPercentage` usam pesos relativos. Assim,
`Chance = 50` nao significa necessariamente 50%: a probabilidade depende da
soma dos pesos da lista.

Nenhuma recompensa ou receita foi alterada nesta auditoria.

## Resumo executivo

| Item | Oferta jogavel atual | Diagnostico |
|---|---|---|
| `copper` | eletricista, lixo, caminhoneiro, guincho, suprimentos, furtos e troca por limalha | abundante, mas concentrado em poucos trabalhos |
| `aluminum` | lixo, caminhoneiro, guincho, suprimentos, furtos e troca por limalha | abundante |
| `plastic` | lixo, caminhoneiro, guincho, suprimentos, furtos e troca por limalha | muito abundante |
| `sheetmetal` | lixo raro, suprimentos, furto de porta-malas/casas | escasso e irregular |
| `metalspring` | nenhuma fonte jogavel direta localizada | gargalo bloqueante |
| `electroniccomponents` | lixo muito raro e furtos | raro e irregular |
| `lockpick` | Sao Judas, cemiterio, loot de armas, furtos e rota Lenhador | varias fontes, algumas incoerentes com o tema |
| `dirtydollar` | aviaozinho, desmanche, trafico, roubos, carro-forte, propriedades e furtos | oferta ampla |

## Catalogo dos materiais

| Indice | Nome | Peso | Economia |
|---|---|---:|---:|
| `copper` | Cobre | 0,045 | 10 |
| `aluminum` | Aluminio | 0,045 | 10 |
| `plastic` | Plastico | 0,045 | 8 |
| `sheetmetal` | Chapa de Metal | 0,65 | 65 |
| `metalspring` | Mola de Metal | 0,35 | 425 |
| `electroniccomponents` | Componentes Eletronicos | 0,35 | 375 |
| `lockpick` | Gazua | 1,25 | 725 |
| `dirtydollar` | Dolar Sujo | 0 | 1 |

## Fontes basicas jogaveis

### Coleta de lixo (`Products["Trasher"]`)

- uma recompensa e sorteada por ciclo de 5 segundos;
- exige e consome `binbag`;
- lista total: peso 466;
- plastico: peso 100, 6 a 10, cerca de 21,46% por ciclo;
- aluminio: peso 50, 4 a 8, cerca de 10,73%;
- cobre: peso 50, 4 a 8, cerca de 10,73%;
- chapa: peso 5, 1 a 2, cerca de 1,07%;
- componentes: peso 3, 1 a 2, cerca de 0,64%.

O limite teorico pelo timer seria 720 ciclos/h, mas esse numero nao representa
gameplay real: depende de saco de lixo, deslocamento, disponibilidade de alvo e
inventario. O evento deve ser monitorado porque a recompensa e valiosa em alta
frequencia.

### Eletricista (`cfWorks`)

- 1 cobre por reparo;
- cooldown configurado no client: 60 segundos;
- pagamento adicional: 45 dolares e 80 XP;
- teto teorico declarado: 60 cobres/h.

Risco alto: o evento server-side `cfWorks:eletricistaReward` entrega a
recompensa sem validar distancia, prop ou cooldown no servidor. A taxa real nao
deve ser usada para balanceamento antes de endurecer essa validacao.

### Caminhoneiro (`trucker`)

Uma recompensa e escolhida por entrega entre cinco materiais, peso total 275:

- plastico: peso 75, 225 a 275, cerca de 27,27%;
- aluminio: peso 25, 175 a 200, cerca de 9,09%;
- cobre: peso 25, 175 a 200, cerca de 9,09%;
- nivel, buff e plano podem aumentar a quantidade.

Uma unica entrega sorteada de cobre/aluminio cobre varias Gazuas. A duracao de
uma rota nao esta fixada no servidor, portanto nao existe valor confiavel por
hora sem cronometrar uma sessao real.

### Guincho (`towed`)

Tambem sorteia uma recompensa por veiculo, com peso total 275:

- plastico: peso 75, 25 a 45, cerca de 27,27%;
- aluminio: peso 25, 15 a 25, cerca de 9,09%;
- cobre: peso 25, 15 a 25, cerca de 9,09%;
- nivel, buff e plano aumentam a quantidade.

### Loja do desmanche legado

O modo `Dismantle` troca `ironfilings` por materiais:

- plastico: 30 limalhas por unidade;
- aluminio: 50 limalhas por unidade;
- cobre: 50 limalhas por unidade.

O desmanche legado gera limalhas, mas o desmanche novo do Pombal paga
`dirtydollar`. A troca continua sendo fonte indireta para jogadores que ainda
acessam o fluxo legado.

## Fontes de loot e atividades ilegais

### Suprimentos

`LootSupplies` exige `utilkey`, possui cooldown de 3600 segundos e sorteia um
item da lista. Entre os alvos auditados:

- plastico: peso 100, 6 a 10;
- aluminio: peso 75, 4 a 8;
- cobre: peso 75, 4 a 8;
- chapa: peso 25, 1 a 2.

### Porta-malas, pedestres e propriedades

A lista `IlegalItens` e sua equivalente de propriedades contem:

- plastico: peso 100, 6 a 10;
- aluminio: peso 75, 3 a 5;
- cobre: peso 75, 3 a 5;
- chapa: peso 50, 1 a 3;
- componentes: peso 30, 1;
- Gazua: peso 45, 1;
- dolar sujo: peso 100, 275 a 375.

O porta-malas usa ate duas rolagens e cooldown de 3600 segundos por placa. A
invasao de propriedade usa ate tres rolagens, alem de cofres e bonus de
blackout. Esses pesos sao relativos a uma lista grande e nao percentuais
diretos.

### Cemiterio e loot de armas

- cemiterio: Gazua com peso 35 e quantidade 1 em ciclo de 10 segundos, com
  minigame e possibilidade de alerta policial;
- `LootWeapons`: Gazua com peso 50 e quantidade 1, exige `weaponkey` e possui
  cooldown de 7200 segundos;
- rota `Lenhador`: Gazua configurada com `Chance = 25`, quantidade 1 a 3.

A Gazua em uma rota chamada Lenhador e uma fonte tematicamente incoerente e
deve ser revista quando a rota for validada em jogo.

### Dolar sujo

Fontes confirmadas incluem:

- aviaozinho de Sao Judas: 200 a 300 por entrega antes da divisao financeira;
- desmanche do Pombal: valor por modelo/experiencia, pago ao trabalhador apos
  a divisao com o cofre;
- trafico de drogas para NPCs;
- registradoras e containers: 325 a 375, com multiplicador 1 a 2;
- caixa eletronico: 325 a 375;
- carro-forte: 7.225 por interacao valida;
- propriedades e cofres: loot comum, bonus de blackout e cofres de 3.225 a
  3.775 quando sorteados;
- porta-malas roubados: bonus e possibilidade na lista `IlegalItens`.

Nao ha indicio de escassez estrutural de `dirtydollar`. Seu uso de 975 na
receita do Cartao Ilegivel e um sink pequeno diante das atividades maiores.

## Gargalos reais

### Mola de metal

Nao foi localizada nenhuma recompensa direta jogavel de `metalspring`. O item
aparece como ingrediente de Gazua ++, Pe de Cabra e varias armas. Sua tabela
`Recycle` e um sink reverso: reciclar uma mola devolve cobre e aluminio, nao
gera uma mola.

Conclusao: Gazua ++ e Pe de Cabra de Sao Judas dependem de estoque
administrativo, legado ou origem nao encontrada fora dos resources auditados.

### Componentes eletronicos

Existem apenas entradas raras no lixo e em loot ilegal. A Gazua ++ consome
quatro unidades, entao o item e um gargalo valido, mas hoje depende demais de
sorte e nao de uma atividade especializada.

### Chapa de metal

Existe em lixo, suprimentos e furtos, mas em quantidades de 1 a 3. Uma Gazua
normal consome 2; uma Gazua ++ efetiva consome 20; um Pe de Cabra consome 4.
O material esta disponivel, porem nao existe uma fonte previsivel de volume.

## Consumo atual em Sao Judas

| Receita | Consumo por unidade | Tempo |
|---|---|---:|
| Gazua | 30 cobre, 30 aluminio, 2 chapas | 10 s |
| Bloqueador | 80 plasticos | 12 s |
| Cartao Ilegivel | 25 plasticos, 975 dolares sujos | 12 s |
| Gazua ++ | 5 Gazuas, 100 cobre, 100 aluminio, 10 chapas, 2 molas, 4 componentes | 20 s |
| Pe de Cabra | 4 chapas, 20 aluminio, 1 mola | 15 s |

Com o custo das cinco Gazuas embutido, uma Gazua ++ representa:

- 250 cobres;
- 250 aluminios;
- 20 chapas;
- 2 molas;
- 4 componentes eletronicos.

Pelos valores `Economy`, o custo contavel da Gazua normal e 730 para um item
avaliado em 725. O custo efetivo da Gazua ++ e aproximadamente 8.625 para um
item avaliado em 50.000.

## Proposta para materiais do desmanche do Pombal

O desmanche possui nove etapas de 5,5 segundos: minimo tecnico de 49,5 segundos
somente em animacoes, sem contar furto, transporte, estacionamento e movimento
entre pecas. Nao foi possivel obter veiculos/hora confiavel sem teste real.

Por isso, os valores abaixo sao faixa de teste, nao configuracao aprovada:

| Material | Faixa por veiculo concluido | Regra sugerida |
|---|---:|---|
| aluminio | 10 a 20 | garantido |
| cobre | 8 a 16 | garantido |
| plastico | 10 a 20 | garantido |
| chapa | 2 a 4 | garantido |
| mola | 0 a 1 | chance de 25% a 40% |
| componentes | 0 a 2 | chance de 20% a 35% |

Com essa faixa, o Pe de Cabra exige normalmente 1 a 3 veiculos, enquanto a
Gazua ++ continua exigindo comercio e varios desmanches. Uma Gazua normal deve
continuar vindo principalmente dos trabalhos basicos ou da propria bancada.

Implementacao futura deve:

- acumular componentes virtualmente por etapa;
- entregar somente apos a ultima etapa;
- usar o `sessionId` como `operationId`;
- validar peso antes da entrega;
- nunca recompensar cancelamento parcial;
- manter valores em config;
- registrar quantidade final server-side.

Antes de aprovar a faixa, medir 10 desmanches completos e registrar tempo do
furto ate a conclusao. Metas iniciais: 4 a 8 veiculos/h em operacao normal e
nenhuma recompensa parcial.

## Painel ESC

### Estado atual

- caixas pagas de aluminio, cobre e plastico custam 500 gemas;
- cada caixa entrega de 500 a 2.250 unidades;
- pelos pesos atuais, o valor medio e aproximadamente 824 unidades por caixa;
- Battlepass Free entrega 100 de plastico, aluminio e cobre em niveis
  especificos;
- Battlepass Premium entrega 225 de cada material basico;
- recompensa diaria do sexto dia entrega 20 plasticos e 20 vidros;
- nao foram encontradas caixas de mola ou componentes.

As caixas pagas sao, em volume, muito maiores que uma atividade comum e podem
dominar a oferta dos tres materiais basicos. Isso contraria o objetivo de usar
gameplay como fonte principal.

### Proposta, sem implementacao

- Caixa pequena de sucata: 10 a 25 unidades de um material basico;
- Caixa de componentes: 1 componente garantido e 10% de chance de 1 mola;
- diaria: 5 a 10 materiais basicos em apenas um dos sete dias;
- Battlepass Free: 20 a 40 basicos por marco;
- Battlepass Premium: no maximo 50 a 75 basicos por marco, sem mola exclusiva;
- caixas pagas atuais: reduzir pelo menos uma ordem de grandeza antes de abrir
  venda regular, preservando cosmeticos e conveniencia como principal valor.

Esses premios devem ser complementares e limitados. Mola e componentes nao
podem depender de compra, passe ou login diario.

## Candidatos funcionais para futuras receitas

| Indice | Nome / imagem | Peso / durabilidade | Funcao real | Consumidor | Receita hoje |
|---|---|---|---|---|---|
| `lockpick` | Gazua / `lockpick` | 1,25 / 72 | arromba veiculos e algemas | inventory, propertys | Sao Judas |
| `lockpickplus` | Gazua ++ / `lockpickplus` | 1,25 / 720 | arrombo melhor e invasao de propriedade | inventory, propertys | Sao Judas |
| `blocksignal` | Bloqueador de Sinal / `blocksignal` | 0,75 / sem durabilidade | remove sinal/rastreamento do veiculo | inventory, garages | Sao Judas |
| `dismantle` | Cartao Ilegivel / `dismantle` | 0 / uso unico | inicia contrato de desmanche legado | inventory | Sao Judas |
| `WEAPON_CROWBAR` | Pe de Cabra / `crowbar` | 1,35 / 240 | arromba porta-malas e carro-forte | target, stockade | Sao Judas |
| `plate` | Placa Veicular / `plate` | 0,75 / uso unico | troca placa de veiculo NPC | inventory | crafting Mecanica |
| `circuit` | Circuito Eletronico / `circuit` | 0,75 / 24 | abre boosting e progride veiculo contratado | inventory, boosting | nao localizada |
| `toolbox` | Kit de Ferramentas / `toolbox` | 2,25 / uso unico | reparo veicular | inventory | crafting Mecanica |
| `advtoolbox` | Ferramentas Mestre / `advtoolbox` | 4,75 / 3 cargas | reparo veicular avancado | inventory | crafting Mecanica |
| `rope` | Cordas / `rope` | 1,75 / 240 | carrega pessoa proxima | inventory | nao localizada |
| `pager` | Pager / `pager` | 2,25 / sem durabilidade | remove comunicacoes/marcacao de algemado | inventory, markers | nao localizada |
| `markers` | Receptor de Sinal / `markers` | 0,75 / 120 | ativa rastreamento da organizacao | inventory, markers | nao localizada |

Os cinco primeiros ja ocupam a bancada de Sao Judas. Para chegar a 8 a 12
receitas uteis, os melhores candidatos tecnicos sao `circuit`, `rope`, `pager`
e `markers`. `plate`, `toolbox` e `advtoolbox` ja pertencem ao crafting de
mecanica e nao devem ser duplicados sem uma decisao de economia/faccao.

`safependrive` e `weaponparts` existem e possuem imagem/economia, mas o primeiro
nao apresentou um uso direto suficiente nesta auditoria e o segundo e insumo
do crafting de armas. Eles nao devem entrar apenas para preencher a interface.

## Revisao da Gazua ++

Fatos confirmados:

- custo efetivo: 250 cobre, 250 aluminio, 20 chapas, 2 molas e 4 componentes;
- custo contavel aproximado: 8.625;
- valor `Economy`: 50.000;
- durabilidade: 720 contra 72 da Gazua normal;
- o fluxo de veiculo da Gazua normal possui chance de quebra de 12,5% em
  determinadas tentativas externas;
- a Gazua ++ nao usa essa chance de quebra no mesmo fluxo e permanece por sua
  durabilidade, alem de servir em propriedades.

Recomendacao: manter a receita por enquanto. Reduzir agora seria incorreto,
pois `metalspring` nao possui fonte jogavel direta; aumentar tambem seria
prematuro. Depois de adicionar drops do Pombal e medir 10 desmanches:

- se uma Gazua ++ levar menos de 3 desmanches + materiais basicos, aumentar
  molas/componentes, nao cobre;
- se levar mais de 8 desmanches com comercio ativo, reduzir chapas de 20
  efetivas para algo proximo de 14 a 16;
- manter molas e componentes como gargalo de cooperacao;
- revisar separadamente a ausencia de desgaste/quebra no uso da Gazua ++.

## Riscos e proximos passos

1. Validar a Gazua corrigida dentro do FiveM.
2. Endurecer o evento server-side do eletricista antes de usa-lo como fonte
   economica confiavel.
3. Cronometrar 10 desmanches completos e 10 rotas de caminhoneiro/guincho.
4. Aprovar faixas de materiais do Pombal.
5. Implementar recompensa somente na conclusao e com idempotencia.
6. Revisar as caixas pagas de 500 a 2.250 materiais.
7. Escolher no maximo quatro candidatos funcionais para a proxima expansao da
   bancada.

## Arquivos principais auditados

- `resources/vrp/config/Item.lua`
- `resources/[scripts]/sao_judas_operations/config.lua`
- `resources/[scripts]/crafting/shared-side/shared.lua`
- `resources/[scripts]/inventory/server-side/core.lua`
- `resources/[scripts]/inventory/server-side/itens.lua`
- `resources/[scripts]/inventory/server-side/dismantle.lua`
- `resources/[scripts]/inventory/server-side/pombal_dismantle.lua`
- `resources/[scripts]/inventory/shared-side/pombal_dismantle.lua`
- `resources/[scripts]/inventory/shared-side/shared.lua`
- `resources/[scripts]/propertys/shared-side/robbery.lua`
- `resources/[scripts]/propertys/server-side/core.lua`
- `resources/[scripts]/trucker/server-side/core.lua`
- `resources/[scripts]/towed/server-side/core.lua`
- `resources/[scripts]/cfWorks/config.lua`
- `resources/[scripts]/cfWorks/jobs/eletricista/server.lua`
- `resources/[scripts]/pause/shared-side/shared.lua`
- `resources/[scripts]/pause/server-side/core.lua`
- `resources/[scripts]/routes/shared-side/shared.lua`
- `resources/[scripts]/shops/shared-side/shared.lua`
- `resources/[scripts]/of_aviao_sao_judas/config.lua`
