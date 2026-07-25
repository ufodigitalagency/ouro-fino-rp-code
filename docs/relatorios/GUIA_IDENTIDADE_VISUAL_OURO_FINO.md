# Guia de identidade visual - Ouro Fino Roleplay

Este guia lista onde trocar as logos e o video de entrada da base.

## Logo central no topo do jogo

Arquivo atual:

`C:\meu-server-gta\Base\resources\[scripts]\hud\web-side\images\logo.png`

Uso:

- E a logo que aparece centralizada no HUD/topo da tela.
- Substitua mantendo o mesmo nome `logo.png`.
- Formato recomendado: PNG com fundo transparente.
- Resolucao recomendada: entre 512x512 e 1024x1024, ou uma logo horizontal com largura ate 1024px.
- Evite arquivo muito pesado. Tente manter abaixo de 1 MB.

Depois de trocar:

```txt
restart hud
```

Se o FiveM ainda mostrar a antiga, limpe cache do cliente ou reinicie o jogo.

## Video de loading/entrada

Arquivo atual:

`C:\meu-server-gta\Base\resources\[system]\loading\web-side\video\video.webm`

Config que aponta para ele:

`C:\meu-server-gta\Base\resources\[system]\loading\shared-side\shared.lua`

Linha principal:

```lua
Video = "video.webm"
```

Uso:

- Para trocar sem mexer no codigo, substitua o arquivo mantendo o nome `video.webm`.
- Formato recomendado: WEBM, codec VP9 ou VP8.
- Resolucao recomendada: 1920x1080.
- Duracao recomendada: 10 a 30 segundos em loop.
- Peso recomendado: abaixo de 50 MB, ideal abaixo de 25 MB.
- Se quiser usar outro nome, coloque o arquivo em `web-side/video/` e altere a linha `Video = "novo_nome.webm"`.

Depois de trocar:

```txt
restart loading
```

## Icone do servidor na lista do FiveM

Arquivo atual configurado:

`C:\meu-server-gta\Base\server.png`

Config:

`C:\meu-server-gta\Base\server.cfg`

Linha atual:

```cfg
load_server_icon server.png
```

Uso:

- Substitua `server.png` mantendo o mesmo nome.
- Formato obrigatorio/recomendado: PNG.
- Resolucao recomendada pelo FiveM: 96x96.
- Fundo transparente funciona bem, mas precisa ser legivel pequeno.

Depois de trocar:

```txt
restart do servidor completo
```

O icone pode demorar alguns minutos para atualizar na lista publica por cache.

## Logo solta na raiz da base

Existe tambem:

`C:\meu-server-gta\Base\logo.png`

Ela aparece referenciada em `C:\meu-server-gta\Base\config\config.cfg`, mas o `server.cfg` principal usa `server.png`. Se quiser padronizar tudo, mantenha `server.png` como icone oficial e use `logo.png` apenas como backup/arte fonte.

## Checklist rapido

1. Trocar HUD: substituir `resources/[scripts]/hud/web-side/images/logo.png`.
2. Trocar loading: substituir `resources/[system]/loading/web-side/video/video.webm`.
3. Trocar icone FiveM: substituir `Base/server.png`.
4. Reiniciar resources ou servidor.
5. Se nao atualizar no cliente, limpar cache do FiveM.
