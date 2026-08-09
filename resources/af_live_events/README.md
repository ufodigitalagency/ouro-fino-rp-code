# af_live_events

Resource FiveM que recebe eventos de lives (TikTok, StreamToEarn, etc.) via HTTP e spawna NPCs no jogo com o nome do usuario acima da cabeca.

## Onde colocar

A pasta deve ficar em:

```text
C:\meu-server-gta\Base\resources\af_live_events
```

Adicione no `resources.cfg` ou `server.cfg`:

```cfg
ensure af_live_events
```

## Configuracao

O endpoint inicia desativado. Configure o segredo fora do repositorio no
`server.cfg` e habilite somente depois:

```cfg
set af_live_events_secret "USE_UM_SEGREDO_ALEATORIO_COM_24_OU_MAIS_CARACTERES"
set af_live_events_enabled "1"
```

Edite `config.lua` apenas para limites e comportamento:

- `Config.LiveEvents`: limites, acoes e allowlist de enderecos.
- `Config.NpcModel`: modelo do NPC (padrao: `a_m_m_business_01`).
- `Config.MaximumActiveNpcs`: limite local de NPCs simultaneos.
- `Config.NpcLifetimeSeconds`: tempo em segundos que o NPC fica vivo (padrao: 60).
- `Config.SpawnDistance`: distancia em metros a frente do jogador (padrao: 3.0).
- `Config.DrawDistance`: distancia maxima para ver o texto 3D (padrao: 20.0).

## Endpoint HTTP

O resource cria automaticamente:

```text
POST http://127.0.0.1:30120/af_live_events/gift
Content-Type: application/json
```

Body JSON:

```json
{
  "secret": "O_MESMO_SEGREDO_CONFIGURADO_NO_SERVER_CFG",
  "action": "spawn_npc",
  "username": "Joao123",
  "giftName": "Rose",
  "giftId": "",
  "custom": "",
  "extra1": "",
  "extra2": ""
}
```

Campos obrigatorios: `secret` e `action`.
Se `username` vier vazio, usa `StreamToEarn` como fallback.

## Teste rapido com curl

Direto no FiveM (sem bridge):

```bash
curl -X POST http://127.0.0.1:30120/af_live_events/gift -H "Content-Type: application/json" -d "{\"secret\":\"O_MESMO_SEGREDO_CONFIGURADO_NO_SERVER_CFG\",\"action\":\"spawn_npc\",\"username\":\"teste123\",\"giftName\":\"Rose\"}"
```

Se tudo funcionar, um NPC aparece perto do jogador com "teste123" escrito acima da cabeca e "Rose" logo abaixo.

## Comportamento do NPC

- Aparece a `Config.SpawnDistance` metros a frente do jogador.
- Fica parado, invencivel, nao foge e nao reage.
- Texto 3D com o nome do usuario acima da cabeca.
- Se `giftName` vier preenchido, aparece abaixo do nome em amarelo.
- Deletado automaticamente apos `Config.NpcLifetimeSeconds`.
- Ao parar/reiniciar o resource, todos os NPCs sao removidos.

## Logs

No console do servidor:

```text
[af_live_events] Endpoint POST /af_live_events/gift habilitado com autenticacao.
[af_live_events] spawn_npc aceito: user=teste123 gift=Rose
```

No F8 do cliente:

```text
[af_live_events] NPC spawnado: user=teste123 gift=Rose
[af_live_events] NPC removido: user=teste123
```

## Bridge

Para conectar com o StreamToEarn, use a bridge Node.js em:

```text
C:\meu-server-gta\Base\tools\af_s2e_bridge
```

Veja o README dela para instrucoes.
