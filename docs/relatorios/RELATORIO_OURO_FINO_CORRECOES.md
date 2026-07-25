# Relatorio de Correcoes - Ouro Fino Roleplay

Data: 2026-07-02

## Objetivo

Restaurar estabilidade da base depois do backup, corrigir o problema de conexao do vRP, manter os recursos customizados do Menino da Porteira, telão/YouTube, limpar NPCs e entregar um painel admin separado para o dono.

## Correcoes criticas aplicadas

- `server.cfg` corrigido de `start [System]` para `start [system]`. O boot real mostrava `Couldn't find resource category [System]`, fazendo `oxmysql/ox_lib` iniciarem fora da ordem correta.
- `oxmysql` foi convertido para sintaxe compativel com o runtime atual do FXServer. O arquivo ativo nao possui mais blocos `static {}`.
- `vrp/modules/base.lua` recebeu um `playerConnecting` seguro:
  - sempre chama `deferrals.done()`;
  - cria conta se necessario;
  - nega com mensagem clara quando faltar whitelist;
  - evita o travamento em `vrp: deferring connection`.
- Whitelist do dono ajustada para a base nova:
  - a base atual usa `accounts.Whitelist`, nao `vrp_users.whitelisted`;
  - se a conta for `accounts.id = 1` ou possuir o personagem/passaporte `1`, ela e liberada automaticamente em `accounts.Whitelist`.
- `vrp/modules/vrp.lua` voltou a buscar telefone real no `phone_phones`, corrigindo identidade/passaporte com telefone `Inativo` quando ja existe numero do lb-phone.
- Adapter standalone do `lb-phone` foi ajustado para resolver jogador por passaporte vRP, respeitar item `cellphone` e achar contatos online corretamente.
- `Config.DatabaseChecker.Enabled` do `lb-phone` foi desligado porque o servidor usa MariaDB 10.4; o checker gerava erro de console mesmo com as tabelas existentes.

## Recursos novos/ajustados

- `af_owner_panel`
  - Comando: `/ofadmin`
  - Acesso: somente passaporte/ID `1`
  - Funcoes: god, noclip, tpway, puxar jogador, banir, dar/remover Admin, aplicar cargos, controlar telão.
- `af_clean_world`
  - Remove densidade de NPCs/peds ambiente.
  - Nao remove veiculos vazios por script para evitar quebrar garagens ou sistemas.
- `af_map_blips`
  - Recria blips principais de bancos, garagens, lojas, policia, hospital, mecanica e concessionaria.
- HUD
  - Localizacao inferior trocada para nomes estilo Minas/Ouro Fino.
  - F1 abre menu principal.
  - F10 manteve menu emergencial existente.
  - F11 alterna HUD.
- Telão/YouTube
  - `af_youtube_tv` mantido com `WorldScreen.startDisabled = true`.
  - Telão inicia desligado; dono liga com `/telaoon` ou pelo `/ofadmin`.
- Menino da Porteira
  - `af_menino_porteira` conferido em modo seguro por script.
  - `stream/meninodaporteira.ydr` e `stream/meninodaporteira.ytyp` presentes.
- Telão asset
  - `af_telao_asset/stream/map1.ymap` presente.

## Remocoes/desativacoes

- Roda do cassino removida dos objetos spawnados pelo inventory.
- Target da roda do cassino removido.
- Resource `luckywheel` impedido de criar a roda automaticamente.
- NPCs ambiente reduzidos/removidos pelo `af_clean_world`, preservando NPCs de jobs/scripts.

## Rebranding

- Nome do servidor: `Ouro Fino Roleplay`.
- `server.cfg`, `vrp/config/Global.lua`, lb-phone e Discord Rich Presence atualizados.
- Varredura ativa em `Base/resources` nao encontrou `Little Community` ou `Lil Community` fora de backups/arquivos ignorados.

## Arquivos principais alterados

- `Base/server.cfg`
- `Base/resources/[System]/oxmysql/server-side/server.js`
- `Base/resources/vrp/modules/base.lua`
- `Base/resources/vrp/modules/prepare.lua`
- `Base/resources/vrp/modules/vrp.lua`
- `Base/resources/vrp/config/Global.lua`
- `Base/resources/[smartphone]/lb-phone/config/config.lua`
- `Base/resources/[smartphone]/lb-phone/server/custom/frameworks/standalone/standalone.lua`
- `Base/resources/[scripts]/discord/client-side/core.lua`
- `Base/resources/[scripts]/dynamic/client-side/core.lua`
- `Base/resources/[scripts]/hud/client-side/core.lua`
- `Base/resources/[scripts]/hud/client-side/vehicle.lua` nao foi alterado nesta rodada.
- `Base/resources/[scripts]/inventory/server-side/objects.lua`
- `Base/resources/[scripts]/target/client-side/core.lua`
- `Base/resources/[scripts]/luckywheel/client-side/core.lua`
- `Base/resources/af_clean_world/*`
- `Base/resources/af_owner_panel/*`
- `Base/resources/af_map_blips/*`

## Backups

Backups foram criados em:

- `Base/_codex_backups/20260702_173702`
- `Base/_codex_backups/20260702_174340`
- `Base/_codex_backups/20260702_174505`
- `Base/_codex_backups/20260702_174712`
- `Base/_codex_backups/20260702_175336`
- `Base/_codex_backups/20260702_175802`
- `Base/_codex_backups/20260702_180330`
- `Base/_codex_backups/20260702_180528`
- `Base/_codex_backups/20260702_180926`

## Verificacoes feitas

- FXServer estava rodando nos PIDs `13788` e `18552`; as mudancas precisam de restart para entrarem em vigor.
- Boot real validado depois das correcoes no log `_codex_fxserver_boot_20260702_184617.log`.
- Ordem confirmada no boot: `ox_lib` linha 11, `oxmysql` linha 13, `vrp` linha 22.
- `info.json` respondeu `200` apos o boot.
- `node --check` passou em `af_owner_panel/html/script.js`.
- `oxmysql/server-side/server.js` nao contem mais `static {}`.
- `Base/resources` nao possui mais ocorrencias ativas de `Little Community` ou `Lil Community`.
- Recursos `af_menino_porteira`, `af_telao_asset`, `af_youtube_tv`, `af_clean_world`, `af_owner_panel` e `af_map_blips` estao presentes.
- Sem `SCRIPT ERROR` no boot validado. Restam apenas avisos nao criticos: update disponivel do `lb-phone`, update disponivel do `ox_lib` e memoria alta em alguns assets.

## Como testar

Preferencialmente reinicie o FXServer inteiro, porque `oxmysql`, `vrp`, HUD e recursos novos foram alterados.

Se nao puder reiniciar tudo, rode no console do FXServer:

```text
restart oxmysql
restart vrp
restart lb-phone
restart discord
restart dynamic
restart hud
restart inventory
restart target
restart luckywheel
ensure af_clean_world
ensure af_owner_panel
ensure af_map_blips
restart af_menino_porteira
restart af_telao_asset
restart af_youtube_tv
```

No jogo:

```text
/ofadmin
/meninostatus
/telaoon https://youtu.be/XL2jTQdj134
/telaooff
```

Teste tambem:

- Entrar no servidor com o dono/passaporte 1.
- Abrir celular com `K`.
- Abrir menu principal com `F1`.
- Abrir menu emergencial com `F10`.
- Alternar HUD com `F11`.
- Ver se garagens, bancos, lojas e mecanica aparecem no mapa.
- Conferir se a roda do cassino nao aparece mais na praca.

## Observacoes

- O telão foi mantido desligado por padrao para o dono ativar quando quiser.
- Nao removi sistemas essenciais de jobs.
- Nao mexi em banco de dados diretamente porque nao havia cliente `mysql.exe/mariadb.exe` disponivel no PATH; a auto-liberacao do dono ocorre pelo proprio vRP ao conectar.
