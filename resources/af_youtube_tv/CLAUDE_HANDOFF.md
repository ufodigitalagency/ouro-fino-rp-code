# Handoff para Claude / Antigravity - af_youtube_tv

Use este arquivo como prompt de continuidade. O objetivo e preservar tudo que ja esta funcionando e fazer o proximo ajuste sem quebrar o fluxo atual.

## Prompt pronto para colar no Claude

Voce e um desenvolvedor especialista em FiveM, Lua, NUI/DUI, HTML, CSS e JavaScript. Trabalhe no resource abaixo:

```text
C:\meu-server-gta\Base\resources\af_youtube_tv
```

Antes de editar, leia os arquivos principais:

```text
fxmanifest.lua
config.lua
client.lua
server.lua
README.md
html/*
```

Contexto do projeto:

- O resource `af_youtube_tv` exibe videos e lives do YouTube dentro do FiveM usando DUI/NUI.
- O modo principal carrega a pagina oficial `https://www.youtube.com/watch?v=VIDEO_ID`.
- O crop visual e feito no desenho do jogo, nao por download/extracao do video.
- O comando `/tvc URL_OU_ID` carrega a live/video atual e tambem serve como fonte para o telao quando nenhum link e passado diretamente.
- Existe um telao 3D global sincronizado pelo servidor. Cada cliente cria seu DUI local, mas todos recebem a mesma URL, posicao, rotacao, tamanho, flip e crop.
- O telao 3D ja esta funcionando muito bem: posicionamento, salvamento, flip horizontal, crop proprio e tela cheia sem chat/interface.
- Nao remova nem reescreva esse sistema. Faca apenas ajustes pequenos e seguros.

Arquivos importantes:

- `config.lua`: define `Config.WorldScreen`, incluindo posicao, tamanho, distancia, `flipX`, `flipY`, `persist` e crop do telao.
- `server.lua`: mantem o estado global do telao, sincroniza para todos os jogadores e salva/carrega KVP.
- `client.lua`: cria o DUI, desenha o telao com `DrawSpritePoly`, edita posicao/tamanho/rotacao/crop com NUMPAD e registra comandos.
- `README.md`: documentacao de uso.

Comandos que ja existem e devem continuar funcionando:

```text
/tvc URL_OU_ID
/tvurl URL_OU_ID
/tveditar
/tvrender uv
/tvsalvar
/tvdebug
/tvreset
/telao on [URL_OU_ID]
/telaoon [URL_OU_ID]
/telao off
/telaooff
/telao url URL_OU_ID
/telao aqui [distancia]
/telaoaqui [distancia]
/telaoedit
/telaoalvo pos|size|rot|crop
/telao crop
/telao crop X Y W H
/telao flipx
/telao flipy
/telao status
/telao reset
/telaosalvar
```

Tarefa principal agora:

Quero que o telao sempre inicie DESLIGADO quando o servidor/resource iniciar, mesmo se antes eu salvei o estado com o telao ligado.

Comportamento desejado:

1. Ao iniciar/reiniciar o servidor ou dar `restart af_youtube_tv`, o telao deve ficar invisivel/desativado.
2. O estado salvo em KVP deve continuar preservando URL, posicao, heading, tamanho, distancia, flip e crop.
3. Apenas o campo `enabled` nao deve religar automaticamente no boot.
4. O admin/dono deve ativar manualmente com:

```text
/telaoon
```

ou:

```text
/telao on
```

5. Quando o admin ativar, o telao deve aparecer na ultima posicao salva, com o ultimo crop/tamanho/rotacao salvos.
6. `/telaooff` deve desligar normalmente.
7. `/telaosalvar` deve continuar salvando posicao/crop/URL. Se ele salvar enquanto ligado, isso nao deve fazer o telao nascer ligado no proximo restart.

Implementacao recomendada:

1. Em `config.lua`, dentro de `Config.WorldScreen`, adicione uma opcao clara:

```lua
startDisabled = true,
```

Comentario sugerido:

```lua
-- Se true, o telao sempre inicia desligado no restart do servidor/resource.
-- O KVP ainda salva posicao, crop e URL, mas o admin precisa ligar com /telaoon.
startDisabled = true,
```

2. Em `server.lua`, depois de carregar o estado salvo e antes de sincronizar com clientes, force `worldState.enabled = false` quando `Config.WorldScreen.startDisabled ~= false`.

Procure a parte parecida com:

```lua
LoadSavedWorldState()
ClampWorldState()
```

E transforme em algo nesse estilo:

```lua
LoadSavedWorldState()

if worldDefaults.startDisabled ~= false then
    worldState.enabled = false
end

ClampWorldState()
```

Isso preserva o estado salvo, mas impede auto-ligar no boot.

3. Opcionalmente, ajuste a mensagem de `/telaosalvar` no `server.lua`, porque hoje ela pode dizer que ao reiniciar o telao volta no estado salvo. A mensagem deve deixar claro:

```text
Telao salvo. Posicao/crop/URL serao restaurados, mas ele inicia desligado; use /telaoon para ligar.
```

4. Atualize o `README.md` com uma pequena secao:

```md
## Inicializacao do telao

Por padrao, `Config.WorldScreen.startDisabled = true`.
Isso faz o telao iniciar desligado sempre que o servidor/resource reiniciar.
O KVP continua salvando posicao, tamanho, rotacao, crop e URL.
Para ligar no jogo, o admin usa `/telaoon` ou `/telao on`.
Para desligar, usa `/telaooff` ou `/telao off`.
```

Cuidados importantes:

- Nao mexa no sistema de crop do telao se nao for necessario.
- Nao volte o video espelhado. `Config.WorldScreen.flipX = true` foi usado para corrigir o espelhamento.
- Nao quebre o fluxo em que `/tvc LINK` salva o link atual e, se o telao estiver ligado, atualiza a URL do telao.
- Nao remova o KVP. A ideia e salvar configuracoes, apenas nao auto-ligar.
- Ignore erros externos de outros resources como `vrp_chest` integrity e mensagens `citizen-server-impl` de server list query. Eles nao sao desse resource.

Checklist de teste no FiveM:

1. Reinicie o resource:

```text
restart af_youtube_tv
```

2. Confirme que o telao nao aparece automaticamente.
3. Use:

```text
/telaoon
```

4. Confirme que o telao aparece na posicao salva, com video correto e sem chat/interface.
5. Use:

```text
/telaooff
```

6. Reinicie de novo o resource e confirme que o telao continua desligado ate usar `/telaoon`.
7. Teste:

```text
/tvc https://youtu.be/XL2jTQdj134
```

Se o telao estiver ligado, ele deve atualizar para esse link. Se estiver desligado, deve salvar o link para ligar depois com `/telaoon`.
8. Teste `/telaoedit`, `/telaoalvo crop` e `/telaosalvar` para garantir que a edicao ainda funciona.

Quando terminar esse ajuste, fique preparado para novos comandos do dono/admin. O projeto ainda vai receber melhorias de posicionamento, asset 3D de moldura/telao e refinamentos visuais.

## Documentacao rapida do projeto

### Objetivo

Criar uma TV/telao dentro do FiveM para reproduzir lives/videos do YouTube no jogo, com controle por comandos e opcao de um telao fixo global visivel para todos os jogadores.

### Arquitetura atual

- DUI: browser local criado no cliente com a pagina oficial do YouTube.
- Textura runtime: o handle do DUI vira uma textura que o GTA/FiveM consegue desenhar.
- Tela 2D/crop: modo usado para ajustes locais e teste rapido.
- Telao 3D: quadrilatero no mundo usando `DrawSpritePoly`, sincronizado pelo servidor.
- Servidor: guarda estado global e salva KVP.
- Cliente: desenha, cria/destroi DUI, edita valores e envia updates ao servidor.

### Fluxo operacional recomendado

1. Admin entra no servidor.
2. Carrega uma live com `/tvc LINK_DA_LIVE`.
3. Liga o telao com `/telaoon`.
4. Se precisar posicionar, usa `/telaoaqui 8` e depois `/telaoedit`.
5. Ajusta alvo com `/telaoalvo pos`, `/telaoalvo size`, `/telaoalvo rot` ou `/telaoalvo crop`.
6. Salva com `/telaosalvar`.
7. Desliga quando quiser com `/telaooff`.
8. No proximo restart, o telao deve ficar desligado ate o admin usar `/telaoon`, mas mantendo local e configuracoes salvas.

### Proxima etapa depois desse ajuste

Adicionar um asset 3D de moldura/telao no mapa:

- Pode ser feito via CodeWalker/YMAP colocando um objeto/moldura na praca.
- O video atual pode continuar sendo desenhado via script por cima/na frente da moldura.
- Alternativa mais simples: usar o telao scriptado atual como superficie visual e adicionar apenas uma moldura 3D decorativa.
- O importante e alinhar a posicao do `DrawSpritePoly` com a area interna do asset.
