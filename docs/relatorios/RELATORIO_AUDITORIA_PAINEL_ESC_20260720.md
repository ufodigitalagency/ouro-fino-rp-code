# Auditoria e reforma do painel ESC - Ouro Fino RP

Data: 20/07/2026

## Resumo executivo

O painel principal é o resource `resources/[scripts]/pause`. A interface compilada existente foi preservada. As alterações foram feitas por configuração Lua e pela camada complementar `panel-customizations`, sem editar o bundle ofuscado `web-side/script.js`.

Decisão adotada: reformar o painel atual por módulos. Não há justificativa técnica para reconstruí-lo do zero agora.

Situação de lançamento:

- manter: Início, Loja, Cofres e Armazenamento, Caixas, Marketplace, Recompensa Diária, Resgatar Código, Premium e Ranking Underground;
- ocultar temporariamente: Propriedades especiais, Passe de Batalha e Estatísticas antigas;
- manter oculto conforme configuração atual: Skins e Personalizar HUD;
- preservar todos os backends e dados das páginas ocultas.

## Mapa das páginas

| Página | Rota | Backend/callback | Situação | Decisão |
|---|---|---|---|---|
| Início | `#/` | `Home` | funcional | manter |
| Premium | `#/Premium` | checkout novo + planos do F9 | reformada | manter |
| Propriedades | `#/Propertys` | `Propertys`, `PropertyBuy` | catálogo fictício/incompleto | ocultar |
| Loja | `#/Store` | `StoreBuy` | funcional, usa diamantes | manter e revisar catálogo |
| Móveis | `#/Furnitures` | `FurnituresBuy` | contém apenas cofres | renomear para Cofres e Armazenamento |
| Passe de Batalha | `#/Battlepass` | módulo `vrp/modules/battlepass.lua` | backend funcional, temporada não curada | ocultar |
| Caixas | `#/Boxes` | `OpenBox` | funcional e ligada ao crafting | manter |
| Marketplace | `#/Marketplace` | callbacks Marketplace | funcional | manter |
| Estatísticas | `#/Ranking` | `Statistics`/`Ranking` | página antiga sem utilidade aprovada | ocultar |
| Ranking Underground | botão complementar | `UndergroundRanking` | funcional | manter |
| Recompensa Diária | `#/Daily` | `Daily`, `DailyRescue` | corrigida | manter |
| Resgatar Código | `#/Code` | `Code` | ampliada e protegida | manter |

A visibilidade é controlada por `MenuPages` em `pause/shared-side/shared.lua`. Além de esconder o botão, a camada complementar bloqueia navegação direta para rotas desativadas.

## Catálogo de itens

O inventário foi extraído de `resources/vrp/config/Item.lua` e cruzado com imagens e referências Lua.

- 392 itens no catálogo consolidado;
- 24 objetos de mobília gerados a partir da tabela `Furniture`;
- 243 itens sem descrição preenchida;
- 7 itens sem imagem correspondente;
- 30 itens sem referência Lua encontrada fora da definição;
- 11 modos/bancadas de crafting;
- 103 receitas.

Itens sem imagem:

- `dompeidon`;
- `furniture_halloween_ghost`;
- `furniture_halloween_pumpkin`;
- `halloween_ghost`;
- `halloween_pumpkin`;
- `mapgps`;
- `mechanicbag`.

Arquivos entregues:

- `CATALOGO_ITENS_20260720.csv`: código, nome, tipo, descrição, peso, economia, limite, raridade, imagem e referências;
- `CATALOGO_CRAFTING_20260720.csv`: bancada, permissão, produto, quantidade e materiais;
- `RESUMO_CATALOGO_20260720.json`: totais auditáveis e categorias.

“Sem referência” é um indicador heurístico, não autorização para apagar o item. Pode existir uso dinâmico vindo do banco, JSON ou bundle NUI.

## Economia

### Carteira

O dinheiro em espécie é o item `dollar` no inventário. Ele possui peso/quantidade e é manipulado pelas funções de inventário.

### Banco

O saldo bancário fica no personagem (`characters.Bank`). `vRP.GiveBank` e `vRP.RemoveBank` também registram transações pelo resource `bank`.

### Diamantes

Diamantes são saldo por conta/licença em `accounts.Gemstone`, não por personagem. As funções centrais são:

- `vRP.UserGemstone` para consulta;
- `vRP.UpgradeGemstone` para crédito;
- `vRP.PaymentGems` para débito.

Há consumo de diamantes em loja do painel, caixas, barbearia, skins, veículos/aluguel, propriedades e outros resources. Por isso não foram removidos nem renomeados nesta etapa. A compra dos três planos Premium por diamantes foi bloqueada; os demais usos continuam intactos.

### Platina

`platinum` é um item, usado em caixas e em alguns fluxos de veículos. Não é a mesma moeda que `Gemstone`.

### Outras progressões

- Battle Pass: JSON em `playerdata`, com Free, Premium, Points e Active;
- Street Rating: sistema próprio do `af_illegal_races`, exibido no Ranking Underground;
- planos Premium/VIP/Standard: `ouro_fino_plans`, agora com validade opcional;
- medalhas encontradas: `mdt_creative_medals`, ligadas ao MDT/polícia, não um sistema geral de insígnias do jogador.

Não foi encontrado um sistema completo e integrado de insígnias gerais no painel ESC.

## Loja

A loja possui 38 produtos:

| Categoria | Produtos |
|---|---:|
| Armamentos | 3 |
| Diamantes | 1 |
| Domésticos | 8 |
| Ferramentas de Trabalho | 3 |
| Grupos | 6 |
| Lavagem | 6 |
| Medicamentos | 1 |
| Utilidades | 4 |
| Veículos | 2 |
| Vestimentas | 4 |

A antiga categoria “Empregos” continha machadinha, picareta e vara de pesca melhoradas. Ela foi renomeada para “Ferramentas de Trabalho”, sem mudar IDs internos.

Armamentos, Grupos e Lavagem merecem uma decisão econômica antes do lançamento. O código realiza validação server-side e cobra diamantes, mas o catálogo pode criar vantagem excessiva dependendo da proposta do servidor.

## Propriedades especiais

O catálogo do painel não é o sistema normal de casas.

Foram encontrados apenas dois registros:

- `Fazenda 01`;
- `Fazenda 02`, classificada visualmente como mansão.

Ambos usam a mesma permissão `Fazenda`, coordenadas `0,0,0`, descrições de placeholder e compra temporária por diamantes. Não entregam uma propriedade mapeada identificável. A página foi ocultada. O resource normal `propertys`, seus interiores e dados foram preservados.

## Cofres e mobília

A loja “Móveis” contém seis produtos e todos são cofres, de capacidades/preços diferentes. Ela foi renomeada visualmente para “Cofres e Armazenamento”.

A tabela geral da base contém 24 objetos de mobília posicionáveis. Eles não foram adicionados automaticamente à loja, pois isso exigiria validar entrega, posicionamento, armazenamento e persistência de cada objeto.

## Crafting e caixas

Modos/bancadas encontrados:

- Essence;
- FoodRestaurante;
- DrinkRestaurante;
- Furnace;
- Mecanico;
- pistol_bench;
- smg_bench;
- rifle_bench;
- blueprint_bench;
- drugs_bench;
- Lester.

As sete caixas são:

- Caixa de Diamantes;
- Caixa de Platinas;
- Caixa de Alumínio;
- Caixa de Vidro;
- Caixa de Cobre;
- Caixa de Borracha;
- Caixa de Plástico.

Os materiais não são órfãos. Furnace, mecânica, armas, blueprints e Lester consomem materiais auditados. As caixas foram mantidas, mas os valores e probabilidades devem entrar na futura revisão econômica.

## Passe de Batalha

O backend funciona e possui 30 recompensas gratuitas e 30 Premium. Cada resgate consome 500 pontos; a trilha Premium custava 10.000 diamantes.

Há concessão de pontos em ônibus, farmer, grime, caminhoneiro, táxi, guincho, corridas, entregas e atividades do inventário. O problema é de curadoria: não existe temporada de Ouro Fino com início/fim, narrativa e recompensas economicamente aprovadas. A página foi ocultada sem apagar progresso.

## Recompensa diária

Foi criado um ciclo conservador de sete dias:

1. água e sanduíches;
2. R$ 500 em espécie;
3. bandagens;
4. caixa de ferramentas;
5. essência azul;
6. plástico e vidro;
7. kit de reparo básico e R$ 1.000.

Correções server-side:

- o client não escolhe mais o dia a receber;
- bloqueio de resgate duplicado no mesmo dia;
- sequência calculada pelo servidor;
- validação de itens e peso antes da entrega;
- trava por jogador durante o processamento.

## Códigos de planos

Configuração server-only em `pause/server-side/00-config.lua`:

- `BOI SEM CORAÇÃO` ativa Premium;
- `MIRANHA` ativa VIP;
- `OURO FINO 26` ativa Standard.

Os três estão configurados para 30 dias. Os nomes, duração, validade, limite global e estado podem ser alterados em um único arquivo.

Proteções:

- normalização de caixa, espaços e acentos;
- código não é enviado à NUI;
- uso único por conta/personagem para cada código;
- reserva no banco antes da concessão;
- rollback da reserva se a ativação falhar;
- prioridade Premium > VIP > Standard;
- plano inferior não substitui superior;
- plano igual temporário estende a validade;
- plano permanente não é substituído por temporário.

## Premium via Pix

O checkout foi implementado, mas permanece desativado até receber valores reais.

Fluxo:

1. jogador escolhe um plano;
2. servidor cria protocolo com valor, plano, duração e expiração;
3. NUI mostra QR configurado, chave/Pix Copia e Cola e Discord;
4. “Já realizei o pagamento” muda apenas para `awaiting_review`;
5. o dono confere o crédito no banco;
6. o dono aprova em F9 > Pagamentos;
7. o servidor ativa o plano uma vez e registra a aprovação.

O comprovante nunca ativa o plano automaticamente. O estado `processing` e updates condicionais impedem aprovação dupla.

Para ativar, preencher os preços em centavos e `Enabled = true` em `00-config.lua`, depois definir no `server.cfg`:

```cfg
set of_premium_pix_key "SUA_CHAVE_PUBLICA"
set of_premium_pix_copy_paste "SEU_PIX_COPIA_E_COLA"
set of_premium_qr_image "images/pix.png"
set of_premium_discord_url "https://discord.com/channels/..."
```

Não colocar senha bancária, token de bot ou segredo no GitHub. A imagem `images/pix.png` deve ficar na pasta web do `pause`, ou o convar pode usar uma URL HTTPS pública.

## Planos e expiração

Registros antigos em `ouro_fino_plans` recebem `ExpiresAt = 0` e continuam permanentes. Códigos e Pix criam validade. Uma thread do `af_owner_panel` remove benefícios expirados, e o evento de conexão revalida o plano.

O painel do dono continua podendo aplicar e remover planos permanentes. Para reduzir erros, downgrade precisa ser feito removendo o plano atual antes de aplicar outro inferior.

## Marketplace

O Marketplace foi preservado. Ele possui taxa de 3% configurada no painel. A auditoria não encontrou motivo para removê-lo nesta etapa. Antes do lançamento público, ainda é recomendável testar anúncio, compra, cancelamento, expiração, item bloqueado e jogador offline com dois clientes.

## Banco e migração

Migration: `docs/migrations/20260720_player_panel.sql`.

Tabelas:

- `ouro_fino_redeem_codes`;
- `ouro_fino_premium_orders`;
- coluna `ouro_fino_plans.ExpiresAt`.

Os resources também criam/atualizam as estruturas no startup. A migration existe para auditoria e implantação controlada.

## Testes executados

- análise sintática dos Lua alterados com `luaparse`;
- `node --check` nos JavaScripts;
- gerador de catálogo executado sobre a base real;
- render 1920x1080 da página Premium;
- render do checkout Pix;
- render da aba Pagamentos do F9;
- teste DOM confirmou que Propriedades, Passe e Estatísticas antigas ficam ocultos;
- `git diff --check` sem erro de whitespace.

O render local usa respostas NUI simuladas. A compra real, MySQL e concessão do plano ainda precisam de teste dentro do FiveM depois que preços/Pix/Discord forem configurados. Também falta teste multiplayer real de Marketplace e persistência entre duas contas.

## Decisões pendentes do proprietário

1. Definir preço em reais de Premium, VIP e Standard.
2. Informar chave Pix pública, Pix Copia e Cola, imagem QR e canal Discord.
3. Decidir se Armamentos, Grupos e Lavagem permanecem na loja pública.
4. Decidir se caixas continuam vendidas por diamantes no lançamento.
5. Criar uma temporada antes de reativar o Passe de Batalha.
6. Escolher imóveis reais antes de reativar Propriedades especiais.
7. Criar imagens para os sete itens ausentes.
8. Revisar descrições dos itens exibidos ao jogador; itens técnicos podem continuar sem descrição.

## Restart

Depois de aplicar os arquivos:

```text
restart af_owner_panel
restart pause
```

Como houve alteração de schema e de manifesto do `pause`, um reinício completo do servidor é preferível no primeiro teste.
