# Auditoria inicial - Ouro Fino Roleplay

Data: 2026-07-02
Escopo: auditoria antes de alteracoes criticas.

Nenhum sistema critico foi alterado nesta etapa. Foi feito somente inventario, leitura de arquivos, consulta ao banco e um startup controlado do FXServer para capturar erros reais.

## Resultado do startup controlado

- FXServer iniciado com `+exec server.cfg`.
- Endpoint `http://127.0.0.1:30120/info.json`: HTTP 200.
- `stderr`: 0 bytes.
- Log gerado: `C:\meu-server-gta\Base\_codex_fxserver_audit_stdout.log`.
- O servidor nao crashou durante o teste.

Problemas reais no console:

1. Resources duplicados:
   - `dynamic`: usado `[scripts]\dynamic`, duplicado em `[Core]\[Interfaces]\dynamic`
   - `hoverfy`: usado `[scripts]\hoverfy`, duplicado em `[Core]\[Interfaces]\hoverfy`
   - `shops`: usado `[scripts]\shops`, duplicado em `[Core]\[Interfaces]\shops`
   - `notify`: usado `[scripts]\notify`, duplicado em `[Core]\[Player]\notify`
   - `chat`: usado `[scripts]\chat`, duplicado em `[System]\[chat]\chat`
   - `pma-voice`: usado `[System]\pma-voice`, duplicado em `[System]\[voip]\pma-voice`
2. `fivem` usa manifesto antigo `__resource.lua`.
3. Assets pesados:
   - `WEAPON_SKINS/w_pi_pistol_fn.ytd` com 24.2 MiB.
   - `WEAPON_SKINS/w_pi_pistol_fn_mag1.ytd` com 18.5 MiB.
   - `PropertyShells/k4_starter_shared4.ytd` com 28.0 MiB.
4. `lb-phone`:
   - MariaDB atual: 10.4.32.
   - O script recomenda MariaDB 10.11+.
   - Versao atual `lb-phone 2.7.2`; ultima reportada no console: `2.8.2`.
5. `vrp/check_exports.lua` esta no `fxmanifest.lua` e imprime `mysql_fetch_all`, `mysql_execute`, `mysql_fetch_scalar`, `mysql_insert -> MISSING`.
   - Isso parece diagnostico deixado ativo, nao erro funcional da base.
   - A base usa principalmente `exports.oxmysql:query_async`, `single_async`, `execute_async`, `insert_async`.

## Server.cfg e identidade

Arquivo ativo: `C:\meu-server-gta\Base\server.cfg`

Ordem atual:

- `[System]`
- `vrp`
- `[weapons]`
- `[scripts]`
- `[smartphone]`
- `[maps]`
- `af_menino_porteira`
- `af_telao_asset`
- `af_youtube_tv`
- `af_live_events`

Rebrand ja aplicado parcialmente:

- `sv_hostname "Ouro Fino Roleplay"`
- `sets sv_projectName "Ouro Fino Roleplay"`
- `sets Grupo "Ouro Fino Roleplay"`
- `Global.lua`: `ServerName = "Ouro Fino Roleplay"`
- `lb-phone`: `Config.CityName = "Ouro Fino Roleplay"`
- Muitos `index.html` de NUI ja tem title `Ouro Fino Roleplay`.

Branding residual encontrado:

- `C:\meu-server-gta\Base\config\config.cfg`
  - `sets sv_projectName "UNITY BASE - VRPEX"`
  - `sv_hostname "UNITY BASE - VRPEX"`
- Discord ainda usa asset antigo:
  - `[scripts]\discord\client-side\core.lua`: asset `lil`
  - convite atual: `https://discord.gg/KumpTEx6vf`

Observacao: `config\config.cfg` nao parece ser o arquivo usado pelo startup atual, mas deve ser corrigido ou arquivado para evitar confusao futura.

## Banco de dados

Banco ativo: `vrp`

Tabelas importantes presentes:

- `accounts`
- `characters`
- `permissions`
- `playerdata`
- `vehicles`
- `propertys`
- `painel_creative_*`
- `mdt_creative_*`
- `ems_creative_*`
- `tickets_creative*`
- todas as tabelas `phone_*` importadas
- tabelas antigas `vrp_*` ainda existem

Estado observado:

- `accounts`: 1 registro.
- `accounts.id = 1`: `Whitelist = 1`, `Banned = 0`, `Token = 5085356`.
- `characters.id = 1`: `Miranha Parker`, license `1100001178625f2`.
- `permissions`: existe `Admin`.

Risco:

- Existem tabelas novas e antigas ao mesmo tempo (`accounts/characters/permissions` e `vrp_users/vrp_user_*`). Isso pode ser normal pela migracao, mas sistemas legados de `[Core]` podem ler tabelas antigas se forem reativados.

## Framework e dependencias

Framework ativo:

- vRP moderno em `resources\vrp`.
- Config: `BaseMode = "steam"`, whitelist por `Token`.

Dependencias principais:

- `oxmysql`
- `ox_lib`
- `pma-voice`
- `PolyZone`
- `screenshot-basic`
- `discord-screenshot`
- `lb-phone`
- `loaf_lib`
- `target`

Ponto critico:

- `lb-phone/config/config.lua` esta com `Config.Framework = "standalone"`.
- A base e vRP. Isso pode explicar bugs de chamadas/apps/servicos/garagem/identidade no telefone.
- Voz do telefone esta em `Config.Voice.System = "pma"`, coerente com `pma-voice`.

## Grupos, cargos e permissoes

Arquivo: `resources\vrp\config\Global.lua`

Grupos principais encontrados:

- `Admin`
- `Ouro`
- `Prata`
- `Bronze`
- `LSPD`
- `BCSO`
- `SAPR`
- `Paramedico`
- `Ballas`
- `Vagos`
- `Families`
- `Marabunta`
- `Aztecas`
- `Bennys`
- `Bahamas`
- `Restaurante`
- `Booster`
- `Freecam`
- `Policia` agregado de `LSPD`, `BCSO`, `SAPR`
- `Emergencia` agregado de `LSPD`, `BCSO`, `SAPR`, `Paramedico`
- `Corredor`
- `Boosting`
- muitos grupos de postos, mansoes, fazendas e propriedades

Admin:

- `Admin` tem hierarquia:
  - Administrador
  - Diretor
  - Moderador
  - Suporte
  - Ajudante
- Comandos administrativos usam `vRP.HasGroup(Passport,"Admin")` e `vRP.HasPermission(Passport,"Admin",nivel)`.
- `server.cfg` tambem tem ACE para `group.admin`, mas os comandos principais da base usam vRP, nao ACE.

Policia:

- Cargos reais: `LSPD`, `BCSO`, `SAPR`.
- Grupo agregado: `Policia`.
- Arsenal/loja policial aparece em `shops/shared-side/shared.lua` com `Permission = "Policia"`.
- Garagens policiais aparecem em `garages/server-side/core.lua`.
- Prisao usa `prison/server-side/core.lua` com `vRP.HasService(Passport,"Policia")`.
- MDT usa `mdt` com grupo `Policia`.

Medico/enfermeiro:

- Grupo principal: `Paramedico`.
- Hierarquia ja inclui medico, residente, enfermeiro e tecnico.
- Sistema EMS: `ems`.
- Sistema de paramedico/revive/cura: `paramedic`.
- Garagem e loja de paramedico existem.

Mecanico:

- Grupo real encontrado: `Bennys`.
- Existem referencias a `Mecanico` em `crafting/shared-side/shared.lua`.
- `lscustoms/shared-side/shared.lua` tem `--Permission = "Mecanico"` comentado.
- Ha risco de inconsistencia: mecanica pode estar aberta sem permissao ou usando nome de grupo errado.

## Comandos principais

### Admin

Arquivo: `[scripts]\admin\server-side\core.lua`

- `/passaporte`
- `/passport`
- `/players`
- `/clone`
- `/print`
- `/pointbattlepass`
- `/pointexperience`
- `/codes`
- `/wipebattlepass`
- `/wipeonline`
- `/wipedaily`
- `/skinshop`
- `/barbershop`
- `/skinweapon`
- `/lscustoms`
- `/tattooshop`
- `/postit`
- `/usource`
- `/cam`
- `/id`
- `/wipepermissions`
- `/referral`
- `/clearpermission`
- `/status`
- `/skin`
- `/clearinv`
- `/dima`
- `/money`
- `/blips`
- `/god`
- `/item`
- `/skins`
- `/delete`
- `/nc`
- `/kick`
- `/ban`
- `/banr`
- `/unban`
- `/insertcron`
- `/removecron`
- `/tpcds`
- `/bucket`
- `/cds`
- `/group`
- `/ungroup`
- `/tptome`
- `/tpto`
- `/tpway`
- `/tuning`
- `/fix`
- `/announce`
- `/nameds`
- `/console`
- `/kickall`
- `/kickall2`
- `/save`
- `/spectate`
- `/quake`
- `/limparea`
- `/video`
- `/rename`
- `/addcar`
- `/remcar`
- `/nitro`
- `/fuel`
- `/kill`
- `/leaders`
- `/blackout`

### Telas, live e telao

Arquivo: `af_youtube_tv\client.lua`

- `/tvligar`
- `/tvdesligar`
- `/tvreset`
- `/tvurl`
- `/tvc`
- `/telao`
- `/telaoedit`
- `/telaoalvo`
- `/telaosalvar`
- `/telaoaqui`
- `/telaoon`
- `/telaooff`
- `/tveditar`
- `/tvalvo`
- `/tvpasso`
- `/tvajuste`
- `/tvtamanho`
- `/tvpos`
- `/tvresetcrop`
- `/tvresetcorte`
- `/tvsalvar`
- `/tvrender`
- `/tvdebug`
- `/tvhelp`

Risco:

- Os comandos parecem client-side e precisam de auditoria de permissao. Para uso final, `telaoon/telaooff/link/volume` deve ir para controle server-side validando dono/Admin nivel 1.

### Menino da Porteira

Arquivo: `af_menino_porteira\client.lua`

- `/testmenino`
- `/delmenino`
- `/meninomodel`
- `/meninohash`
- `/meninostatus`
- `/meninoreload`
- `/meninolimpar`
- `/meninoadd`
- `/meninoz`
- `/meninorot`
- `/meninosalvar`
- `/meninoaqui`

### Outros comandos ativos relevantes

- `/procurado`
- `/andar`
- `/binds`
- `/ChatEvent`
- `/me`
- `/configrace`
- `/inv`
- `/helicrash`
- `/timeset`
- `/hud`
- `/car`
- `/dv`
- `/objects`
- `/christmas`
- `/pages`
- `/fps`
- `/e`, `/e2`, `/e3`
- `/toggleRadar`
- `/toggleFreeze`
- `/phone`
- `/togglePhoneFocus`
- `/answerCall`
- `/declineCall`
- `/phonedebug`
- `/svphonedebug`

## Atalhos de teclado atuais

Atalhos ativos encontrados em Lua:

- `T`: chat
- `K`: telefone
- `LMENU`: foco do telefone
- `LMENU`: target
- `LMENU`: nitro
- `F2`: notify call
- `F3`: taximetro
- `F4`: cruise control
- `F6`: cancelar acoes
- `F7`: passaporte/informacao
- `F9`: menu principal (`dynamic`)
- `F10`: menu emergencial (`dynamic`)
- `Escape`: pause custom
- `P`: mapa custom
- `OEM_3`: inventario
- `G`: cinto e party usam `G`, possivel conflito
- `N`: radar
- `M`: travar radar
- `Y`: aceitar requisicao
- `U`: recusar requisicao
- `X`: maos/camera/freeze camera em contextos diferentes
- `B`: apontar
- `Z`: motor/camera roll em contextos diferentes
- `L`: trancar/destrancar
- `HOME`: ciclo de proximidade da voz
- `CAPITAL`: radio PTT
- `NUMPAD0-9`: animacoes e ajuste de crop/telao do `af_youtube_tv`

Pedido do projeto:

- F1 -> menu player
- F10 -> scoreboard/painel
- F11 -> mapa custom/hud toggle

Conflitos atuais:

- F1 nao esta claramente mapeado em Lua ativa.
- F10 ja abre `EmergencyFunctions`.
- F11 aparece no resource legado `[Core]\[Player]\vrp_identity`, que hoje nao sobe pelo `server.cfg`, mas pode conflitar se `[Core]` for ativado.
- `LMENU` esta em telefone, target e nitro.
- `G` esta em cinto e party.

## HUD de localizacao

Arquivo: `[scripts]\hud\client-side\core.lua`

Estado atual:

- O HUD usa `GetStreetNameAtCoord`.
- O nome principal da rua foi substituido por uma lista de regioes brasileiras:
  - Ouro Fino
  - Ouro Verde
  - Crisolia
  - Centro
  - Sao Judas
  - Jardim Terezinha
  - Jardim Centenario
  - Palomos
  - Pombal
  - BNH
  - Monjolinho
  - Santa Izabel
  - Pouso Alegre
  - Itapira
  - Campinas
  - Pocos de Caldas
  - Belo Horizonte
  - Serra Negra

Problema:

- A regiao e sorteada com `math.random(#Regions)` quando existe rua.
- Isso nao fica estavel por posicao e pode trocar sem o jogador realmente mudar de bairro.

Recomendacao:

- Criar tabela de zonas por coordenadas com raio/poligono e fallback por hash estavel da posicao.
- Manter formato `bairro - rua`, mas substituir o bairro por zona calculada.

## NPCs e peds

`CreatePed` ativo encontrado em:

- `[scripts]\creative\client-side\peds.lua`: peds estaticos gerais.
- `[scripts]\fuelstations\client-side\core.lua`: peds de posto/trabalho.
- `[scripts]\cemitery\client-side\core.lua`: ped de cimiterio.
- `[scripts]\arena\client-side\core.lua`: guard.
- `[scripts]\taxi\client-side\core.lua`: passageiro NPC.
- `[scripts]\boosting\client-side\core.lua`: NPCs de boosting.
- `[scripts]\inventory\client-side\dismantle.lua`: NPCs de desmanche.
- `[scripts]\inventory\client-side\hunting.lua`: animais.
- `[scripts]\animals\client-side\core.lua`: animais.

Nao remover automaticamente:

- peds de job/trabalho.
- peds que fazem parte de mecanicas ativas.

Possivel limpeza futura:

- Auditar primeiro `[scripts]\creative\client-side\peds.lua`, porque tende a concentrar peds estaticos decorativos.

## Roda-roda / cassino na praca

Arquivos relacionados:

- `[scripts]\luckywheel\client-side\core.lua`
- `[scripts]\inventory\server-side\objects.lua`
- `[scripts]\target\client-side\core.lua`

Estado:

- `luckywheel/client-side/core.lua` tem `DisableWheel = true`, entao nao instancia `vw_prop_vw_luckywheel_02a`.
- Mesmo assim, `inventory/server-side/objects.lua` ainda registra:
  - `vw_prop_vw_luckywheel_01a` em `167.62,-980.22,29.1`
  - `vw_prop_vw_jackpot_on` em `167.66,-980.19,29.11`
- `target/client-side/core.lua` ainda tem zona `Luckywheel` perto de `167.47,-980.35,30.61`.

Conclusao:

- A roleta pode continuar aparecendo por causa dos objetos do inventory, mesmo com `DisableWheel = true`.
- Para remover corretamente, fazer backup de `objects.lua` e remover/comentar apenas esses dois objetos e a zona target `Luckywheel`.

## Celular

Resource: `[smartphone]\lb-phone`

Estado:

- Banco `phone_*` existe.
- `lb-phone` inicia no startup.
- `Config.Voice.System = "pma"` esta correto para `pma-voice`.
- `Config.Framework = "standalone"` esta suspeito para base vRP.
- Keybind:
  - abrir telefone: `K`
  - foco cursor: `LMENU`
  - atender: `RETURN`
  - recusar: `BACK`

Riscos:

- Chamadas podem falhar por conflito/duplicidade de `pma-voice`.
- Apps de servicos/garagem/contas podem falhar por framework standalone sem integracao vRP.
- MariaDB 10.4 pode impedir migracoes automaticas futuras do lb-phone.

Ordem recomendada:

1. Resolver duplicidade do `pma-voice`.
2. Definir se o lb-phone deve usar custom vRP/vrp2 ou standalone adaptado.
3. Testar chamada local entre dois clients.
4. So depois atualizar lb-phone ou MariaDB.

## Painel admin e telao

Painel existente:

- Resource: `[scripts]\painel`
- Abre por evento `painel:Open`.
- O acesso depende do grupo atual do jogador.
- NUI callbacks existentes:
  - membros
  - tags
  - anuncios
  - perks
  - banco
  - permissoes
  - metas

Telao existente:

- Resource: `af_youtube_tv`
- Comandos prontos para telao, link, crop, posicao, salvar e ligar/desligar.

Recomendacao:

- Criar modulo de admin/dono separado ou aba especial no painel visivel somente para `Admin` nivel 1.
- O server deve validar:
  - Passport do dono
  - grupo `Admin`
  - nivel 1
- Integrar com eventos server-side do `af_youtube_tv` para:
  - `telaoon`
  - `telaooff`
  - link
  - volume
  - area/preset

## Blips, bancos, lojas, garagem e mecanica

Estado geral:

- Banco: usa `target:AddCircleZone` em `[scripts]\bank`.
- Lojas: usam `target:AddCircleZone` / `AddBoxZone` em `[scripts]\shops`.
- Garagens: configuradas em `[scripts]\garages`.
- Policia/Paramedico: garagens e lojas especificas existem.
- Mecanica:
  - `Bennys` existe como grupo.
  - `Mecanico` aparece em crafting.
  - `lscustoms` tem permissao comentada.

Prioridade:

- Corrigir naming/permission da mecanica antes de adicionar features novas.

## Plano seguro de correcao

Fase 1 - estabilidade e barulho de console:

1. Fazer backup de `vrp\fxmanifest.lua`.
2. Remover `check_exports.lua` dos `server_scripts` ou mover diagnosticos para pasta desativada.
3. Desativar duplicatas por backup/renome seguro, uma por vez:
   - priorizar `pma-voice` duplicado.
   - depois `chat`, `dynamic`, `hoverfy`, `shops`, `notify`.
4. Rodar startup controlado novamente.

Fase 2 - rebrand final:

1. Corrigir `config\config.cfg` ou marcar como arquivo legado.
2. Trocar asset/texto Discord `lil` se houver asset novo.
3. Padronizar Discord invite se necessario.
4. Rodar `rg` final para `UNITY`, `Little Community`, `Lil Community`.

Fase 3 - gameplay visivel:

1. HUD de localizacao por zonas estaveis.
2. Remover roda-roda da praca via `inventory/server-side/objects.lua` e target zone.
3. Corrigir F1/F10/F11:
   - F1: menu player.
   - F10: scoreboard/painel.
   - F11: mapa custom ou hud toggle.

Fase 4 - telefone:

1. Resolver `pma-voice` duplicado.
2. Ajustar framework do lb-phone para integracao com vRP ou adaptar standalone.
3. Testar chamadas e apps.
4. Avaliar upgrade MariaDB 10.11 ou manter 10.4 com checker consciente.

Fase 5 - admin/telao/cargos:

1. Adicionar aba/controle de dono no painel.
2. Mover controle do telao para server-side com permissao Admin nivel 1.
3. Criar comando/funcao segura para dar Admin por ID.
4. Padronizar grupos:
   - Policia via `LSPD/BCSO/SAPR` + agregado `Policia`.
   - Medico/Enfermeiro via `Paramedico`.
   - Mecanico decidir entre `Bennys` ou novo `Mecanico` e alinhar todos scripts.

## Arquivos que provavelmente serao tocados depois da aprovacao

- `C:\meu-server-gta\Base\resources\vrp\fxmanifest.lua`
- `C:\meu-server-gta\Base\resources\[scripts]\inventory\server-side\objects.lua`
- `C:\meu-server-gta\Base\resources\[scripts]\target\client-side\core.lua`
- `C:\meu-server-gta\Base\resources\[scripts]\hud\client-side\core.lua`
- `C:\meu-server-gta\Base\resources\[scripts]\dynamic\client-side\core.lua`
- `C:\meu-server-gta\Base\resources\[scripts]\pause\client-side\core.lua`
- `C:\meu-server-gta\Base\resources\[smartphone]\lb-phone\config\config.lua`
- `C:\meu-server-gta\Base\resources\[smartphone]\lb-phone\client\custom\*`
- `C:\meu-server-gta\Base\resources\[smartphone]\lb-phone\server\custom\*`
- `C:\meu-server-gta\Base\resources\[scripts]\painel\client-side\core.lua`
- `C:\meu-server-gta\Base\resources\[scripts]\painel\server-side\core.lua`
- `C:\meu-server-gta\Base\resources\[scripts]\painel\web-side\script.js`
- `C:\meu-server-gta\Base\resources\af_youtube_tv\server.lua`
- `C:\meu-server-gta\Base\resources\af_youtube_tv\client.lua`
- `C:\meu-server-gta\Base\resources\vrp\config\Global.lua`

## Conclusao

A base esta subindo agora. O trabalho nao deve comecar por remocao agressiva. A ordem mais segura e:

1. Limpar diagnostico falso do oxmysql e duplicatas.
2. Resolver telefone/framework/voice.
3. Ajustar HUD, teclas e objeto da roleta.
4. So entao implementar painel admin/telao e reorganizacao de cargos.

