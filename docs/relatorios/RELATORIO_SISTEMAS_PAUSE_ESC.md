# Relatorio - Sistemas do painel ESC/Pause

Data: 2026-07-08

## Resources principais

- `C:\meu-server-gta\Base\resources\[scripts]\pause`: painel ESC/pause, loja premium, caixas, marketplace, ranking, battlepass, daily e estatisticas.
- `C:\meu-server-gta\Base\resources\vrp`: funcoes de identidade, banco, diamantes, inventario e battlepass.
- `C:\meu-server-gta\Base\resources\[scripts]\skinweapon`: tela de skins de armas aberta pelo painel.
- `C:\meu-server-gta\Base\resources\[scripts]\painel`: painel de grupos/atendimento/administracao da base.

## Arquivos relevantes

- `pause/client-side/core.lua`: registra callbacks NUI e abre/fecha o painel.
- `pause/server-side/core.lua`: executa compras, caixas, battlepass, marketplace, ranking, daily e estatisticas.
- `pause/shared-side/shared.lua`: configura caixas, planos premium, loja, battlepass, daily e lista de trabalhos para estatisticas.
- `vrp/modules/battlepass.lua`: guarda progresso do passe de batalha em `playerdata`.
- `vrp/modules/identity.lua`: le saldo de diamantes pelo campo `Gemstone` da conta.
- `vrp/modules/money.lua`: cobra diamantes via `vRP.PaymentGems`.

## Diamantes

Nome tecnico: `gemstone`.

Fluxo:

- O saldo aparece no painel por `vRP.UserGemstone(Identity.License)`.
- O valor fica ligado a conta/license do jogador, nao somente ao personagem.
- Compras da loja premium, caixas e passe usam `vRP.PaymentGems(Passport,Amount)`.
- Ao pagar, o sistema remove diamantes da conta e atualiza HUD com `hud:RemoveGemstone`.

Arquivos:

- `vrp/modules/identity.lua`
- `vrp/modules/money.lua`
- `pause/server-side/core.lua`

## Caixas

Configuracao:

- `pause/shared-side/shared.lua`
- tabela global `Boxes`.

Funcionamento:

- Cada caixa tem `Id`, `Name`, `Image`, `Price`, `Discount` e `Rewards`.
- O jogador paga diamantes.
- O servidor sorteia premio com `RandPercentage(Boxes[Number].Rewards)`.
- O premio e entregue com `vRP.GenerateItem`.
- Loga no Discord pelo canal `Boxes`.

Callback:

- NUI chama `OpenBox`.
- Client chama `vSERVER.OpenBox(Data.Index)`.
- Server executa `Lil.OpenBox(Number)`.

## Battlepass / Passe de batalha

Configuracao:

- `BattlepassPoints = 500`
- `BattlepassPrice = 10000`
- Recompensas em `Battlepass.Free` e `Battlepass.Premium`.

Persistencia:

- Progresso do jogador: tabela `playerdata`, chave `Battlepass`.
- Data/ciclo global: tabela `entitydata`, chave `Battlepass`.

Funcionamento:

- `vRP.Battlepass(Passport)` cria dados padrao `{ Free = 0, Premium = 0, Points = 0, Active = false }`.
- Varias atividades do servidor chamam `vRP.BattlepassPoints(Passport,Amount)`.
- Para resgatar, o jogador precisa ter pontos suficientes.
- Recompensas Free e Premium possuem contadores separados.
- Premium so resgata se `Active = true`.
- Comprar o passe custa `BattlepassPrice` em diamantes.

Callbacks:

- `Battlepass`
- `BattlepassBuy`
- `BattlepassRescue`

## Ranking

Arquivo principal:

- `pause/server-side/core.lua`, funcao `Lil.Ranking`.

Funcionamento:

- Monta ranking com base em colunas/estatisticas do banco.
- Tambem consulta dados agregados em `entitydata` quando aplicavel.
- O painel chama `Ranking` pelo NUI.

Observacao:

- O ranking depende da consistencia das tabelas da base atual. Se categorias aparecem vazias, e preciso conferir quais colunas estao sendo usadas pela tela web.

## Marketplace

Persistencia:

- tabela `entitydata`, chave `Marketplace`.

Funcionamento:

- Jogador anuncia item do inventario.
- Sistema cobra taxa `MarketplaceTax = 0.03`.
- Item fica guardado na estrutura Marketplace.
- Compra transfere dinheiro para vendedor via `vRP.GiveBank`.
- Cancelamento devolve item via `vRP.GiveItem`.

Callbacks:

- `Marketplace`
- `MarketplaceInventory`
- `MarketplaceAnnounce`
- `MarketplaceBuy`
- `MarketplaceCancel`

## Loja premium / Premium

Configuracao:

- `pause/shared-side/shared.lua`, tabela `Premium`.

Estado atual:

- Planos ja estao configurados como `Premium`, `VIP` e `Standard`.
- Os beneficios aparecem como informacoes no painel.
- A aplicacao real de plano pelo dono foi centralizada no painel administrativo via `af_owner_panel`.

Fluxo antigo do painel:

- O jogador podia comprar plano pagando diamantes.
- O servidor aplicava permissao temporaria e recompensas configuradas.

Ponto de atencao:

- Como agora o dono tambem aplica plano manualmente, manter uma regra unica de beneficios evita duplicidade.

## Skins de armas

Callback:

- `Skinweapon` no `pause/client-side/core.lua`.

Fluxo:

- O painel chama `TriggerEvent("skinweapon:Open")`.
- Resource responsavel: `skinweapon`.

## Daily / Recompensa diaria

Configuracao:

- `pause/shared-side/shared.lua`, tabela `Daily`.

Persistencia:

- Campo `Daily` em `characters`.

Funcionamento:

- O painel consulta dia atual e progresso.
- Ao resgatar, atualiza `characters.Daily` com data e dia resgatado.

Callbacks:

- `Daily`
- `DailyRescue`

## Codigos promocionais

Tabelas:

- `codes_creative`
- `codes_creative_redeemd`

Funcionamento:

- O jogador informa codigo no painel.
- O servidor valida limite, expiracao e se o passaporte ja resgatou.
- Recompensas podem dar itens, dinheiro, banco, diamantes, veiculos ou grupo.

Callback:

- `Code`

## Trabalhos/estatisticas exibidas no ESC

Configuracao:

- `pause/shared-side/shared.lua`, tabela `Works`.

Trabalhos listados para estatistica:

- Grime
- Taxista
- Impound
- Desmanche
- Entregador
- Transportador
- Lenhador
- Leiteiro
- Caminhoneiro
- Pescador
- Motorista
- Traficante
- Cacador
- Lixeiro
- Corredor
- Entregador de Jornal

Importante:

- Essa lista do painel ESC nao significa que todos esses empregos estejam ativos na central `cfWorks`.
- Muitos resources de trabalho existem separados (`farmer`, `taxi`, `trucker`, `towed`, `grime`, `routes`, `races`, `throwing`) e pontuam battlepass.
- A central visual `cfWorks` foi ampliada agora para 5 empregos, mas ainda nao e o agregador oficial de todos os trabalhos da base.

## Bugs ou riscos conhecidos

- A UI web do pause e grande/obfuscada em partes, entao mudancas visuais devem ser pequenas e testadas no jogo.
- Marketplace depende de `entitydata`; se o servidor fechar antes do save, pode perder alteracoes recentes.
- Battlepass depende de `playerdata`; sem tabela correta, pontos/resgates nao persistem.
- Troca de planos pelo painel do dono e compra premium pelo ESC precisam seguir a mesma lista de beneficios para nao duplicar carros/salarios.

## Comandos de teste

No console:

```txt
restart pause
```

No jogo:

```txt
ESC
/skinweapon
```

Testes esperados:

- Painel ESC abre.
- Aba Premium mostra planos.
- Caixas listam premios.
- Battlepass abre com recompensas Free/Premium.
- Ranking nao gera erro no F8.
