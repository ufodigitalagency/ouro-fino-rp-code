# af_youtube_tv

Resource FiveM para exibir o player oficial do YouTube em um telao 3D usando DUI/NUI, com sincronizacao global e audio por proximidade.

## Arquitetura atual

- O DUI abre `https://cfx-nui-af_youtube_tv/html/index.html`.
- A pagina local controla o YouTube pela IFrame Player API.
- Volume, pausa, retomada e sincronizacao sao enviados ao player local.
- Cada jogador calcula o volume efetivo pela propria distancia do telao.
- Paredes e interiores diferentes podem abafar o som.
- O servidor valida URL, volume, alcance, geometria e permissao.
- Somente o passaporte configurado em `Config.Access.ownerPassport` controla o telao.
- O fluxo normal de controle fica em F9 > Central Administrativa > Telao.
- Os comandos continuam disponiveis somente para o dono como fallback de emergencia.

## Onde colocar

A pasta deve ficar dentro da pasta de resources do servidor:

```text
C:\meu-server-gta\Base\resources\af_youtube_tv
```

Neste servidor, o arquivo principal `C:\meu-server-gta\Base\config\config.cfg` executa `config/resources.cfg`. Portanto, adicione a linha abaixo em `C:\meu-server-gta\Base\config\resources.cfg` ou no cfg equivalente que carrega seus resources:

```cfg
ensure af_youtube_tv
```

Se o seu servidor tiver um `server.cfg` tradicional, a linha e a mesma:

```cfg
ensure af_youtube_tv
```

## Como configurar

Abra `config.lua` e ajuste:

- `Config.DefaultUrl`: ID ou URL padrao do video/live.
- `Config.Dui.width` e `Config.Dui.height`: resolucao interna do browser DUI.
- `Config.DisplayMode`: atualmente `crop`.
- `Config.Crop`: recorte da textura e posicao/tamanho da tela no jogo.
- `Config.Crop.drawMode`: use `uv` para desenhar apenas a area escolhida, sem bordas pretas. `mask` eh fallback, `poly` tenta triangulos UV.
- `Config.WorldScreen`: telao 3D global, com posicao, rotacao, tamanho e distancia de desenho.
- `Config.WorldScreen.flipX`: correcao horizontal do video no telao 3D. Deixe `true` se o video aparecer espelhado.
- `Config.WorldScreen.cropX/cropY/cropWidth/cropHeight`: corte proprio do telao 3D para esconder chat, header e bordas.
- `Config.WorldScreen.persist`: salva `/telaosalvar` em KVP para voltar no mesmo lugar apos restart.
- `Config.Audio`: alcance, queda por distancia, obstrucao e intervalo de atualizacao.
- `Config.Access.ownerPassport`: passaporte unico autorizado a controlar o telao.
- `Config.Autoplay`: tenta iniciar automaticamente.
- `Config.Muted`: recomendado `true`, porque autoplay com audio pode ser bloqueado.
- `Config.Loop`: repete videos normais quando possivel.

Formatos aceitos:

```text
M7lc1UVf-VE
https://www.youtube.com/watch?v=M7lc1UVf-VE
https://youtu.be/M7lc1UVf-VE
https://www.youtube.com/live/VIDEO_ID_AQUI
https://www.youtube.com/embed/M7lc1UVf-VE
```

## Modo de Corte Atual

O resource usa apenas URLs oficiais do YouTube. Nenhum metodo baixa video, extrai stream, remove anuncio ou burla DRM/restricao.

- O DUI carrega a pagina local do resource, que incorpora o player oficial do YouTube.
- O jogo usa UV crop por padrao para desenhar apenas a area escolhida da textura DUI.
- Isso remove a borda preta do modo antigo, porque as sobras da pagina nao sao desenhadas.
- Se o seu build nao renderizar UV, use `/tvrender mask` para voltar ao fallback por mascara.
- O ajuste por teclado usa NUMPAD e so funciona quando `/tveditar` esta ativo.

Se o YouTube mudar layout, ajuste o recorte com `/tveditar` ou manualmente com `/tvajuste`.

## Como iniciar pelo txAdmin

1. Abra o txAdmin do seu servidor.
2. Confirme que o servidor esta usando o cfg correto.
3. Reinicie o servidor ou rode no console:

```cfg
ensure af_youtube_tv
```

4. Verifique se aparece no console:

```text
[af_youtube_tv] server.lua carregado com controle exclusivo do dono.
```

## Como conectar no FiveM local

1. Abra o FiveM.
2. Pressione F8.
3. Conecte no seu servidor local, normalmente:

```text
connect 127.0.0.1:30120
```

## Como testar dentro do jogo

Use os comandos no chat ou no F8:

```text
/tvligar
/tvc URL_OU_ID
/tvurl URL_OU_ID
/tveditar
/tvalvo crop
/tvalvo tela
/tvajuste 0.02 0.06 0.85 0.75
/tvtamanho 0.75 0.421875
/tvpos 0.5 0.5
/tvrender uv
/tvresetcrop
/tvsalvar
/tvreset
/tvdebug
/tvdesligar
/tvc URL_OU_ID
/telao on
/telao aqui 8
/telaoedit
/telaosalvar
/telao off
```

## Corte visual por NUMPAD

O modo atual usa o player incorporado do YouTube na pagina local do DUI e corta a textura no desenho do jogo. O recorte nao usa WASD.

Ative a edicao:

```text
/tveditar
```

Controles padrao:

```text
NUM4 / NUM6  move esquerda/direita
NUM8 / NUM2  move cima/baixo
NUM7 / NUM9  diminui/aumenta largura
NUM1 / NUM3  diminui/aumenta altura
NUM5         alterna alvo: recorte da textura ou tela no jogo
NUM0         reseta recorte e tela
```

Se o teclado nao tiver NUMPAD, use comandos:

```text
/tvalvo crop
/tvajuste X Y W H
/tvalvo tela
/tvtamanho W H
/tvpos X Y
/tvpasso 0.002
/tvrender uv
/tvsalvar
```

`/tvsalvar` mostra os valores atuais para colocar em `Config.Crop`.
`/tvrender uv` e o modo recomendado para ficar so com a area escolhida, sem moldura preta. Se a imagem sumir no seu build, use `/tvrender mask` como fallback.

Fluxo recomendado:

1. Entre no servidor.
2. Use `/tvc LINK_DA_LIVE`.
3. Use `/tveditar`.
4. Ajuste com NUMPAD.
5. Use `NUM5` para alternar entre recorte da textura e tamanho/posicao da tela.
6. Confirme que o render esta em UV com `/tvrender uv`.
7. Use `/tvsalvar` para ver os valores finais.
8. Use `/tvdebug` para conferir estado atual.

Exemplos:

```text
# Carregar video/live e abrir ajuste
/tvc https://youtu.be/XL2jTQdj134
/tveditar

# Ajuste manual do recorte
/tvalvo crop
/tvajuste 0.02 0.06 0.85 0.75

# Ajuste manual da tela no jogo
/tvalvo tela
/tvtamanho 0.80 0.45
/tvpos 0.50 0.50

# Mostrar valores para salvar no config.lua
/tvsalvar

# Remover borda preta usando crop UV
/tvrender uv
```

## Telao 3D Global

O telao global e sincronizado pelo servidor. Cada jogador cria o proprio DUI localmente, mas todos recebem a mesma URL, posicao, rotacao, tamanho e crop.

O telao usa o link atual do `/tvc` quando voce nao passa URL diretamente no comando `/telao`. Fluxo simples: use `/tvc LINK_DA_LIVE`, ajuste/corte o video, depois use `/telao on` ou `/telao aqui`.

A pagina local cria somente o player incorporado, sem a pagina completa do YouTube. O crop UV continua disponivel para ajustar exatamente a area renderizada na textura do telao.

Comandos principais:

```text
/telao on [URL_OU_ID]     liga o telao para todos; sem URL usa o /tvc atual
/telao off                desliga o telao para todos
/telao url URL_OU_ID      troca a live e liga
/telao aqui 8             coloca o telao 8m a sua frente usando o /tvc atual
/telao pos X Y Z          define coordenadas manualmente
/telao tamanho W H        define largura e altura em metros
/telao rot HEADING        define a rotacao
/telao volume 0-100       define o volume maximo perto do telao
/telao alcance METROS     define o alcance do audio
/telao som on|off         liga/desliga o audio por proximidade
/telao oclusao on|off     liga/desliga o abafamento por paredes
/telao pause              pausa o video globalmente
/telao continuar          retoma o video globalmente
/telao sync               sincroniza tempo e estado
/telao audiostatus        mostra diagnostico local do audio
/telao crop               copia o crop atual do /tveditar para o telao
/telao crop X Y W H       define crop manual do telao
/telao status             mostra debug do telao
/telao reset              volta para Config.WorldScreen
/telao salvar             salva estado atual em KVP
/telaoedit                liga/desliga ajuste fino por NUMPAD
/telaoalvo pos|size|rot|crop escolhe o alvo do ajuste
/telaosalvar              salva em KVP e mostra valores para config.lua
```

Fluxo recomendado para colocar na praca:

1. Fique no lugar de onde voce quer mirar/posicionar o telao.
2. Olhe para onde a frente do telao deve ficar.
3. Use:

```text
/tvc https://youtu.be/XL2jTQdj134
/telao aqui 8
/telao on
/telaoedit
```

4. Ajuste com NUMPAD:

```text
NUM5         alterna alvo: pos, size, rot, crop
NUM4 / NUM6  move lateral ou gira
NUM8 / NUM2  sobe/desce
NUM7 / NUM9  aproxima/afasta quando alvo=pos, ou muda largura quando alvo=size
NUM1 / NUM3  muda altura quando alvo=size
NUM0         recoloca o telao a sua frente
```

Quando o alvo for `crop`, os controles mudam para cortar a imagem do YouTube:

```text
NUM4 / NUM6  move o corte esquerda/direita
NUM8 / NUM2  move o corte cima/baixo
NUM7 / NUM9  diminui/aumenta largura do corte
NUM1 / NUM3  diminui/aumenta altura do corte
```

5. Quando ficar bom:

```text
/telaosalvar
```

6. O estado fica salvo em KVP. Posicao, crop e URL serao restaurados, mas o telao inicia desligado; use `/telaoon` para ligar.
7. Opcional: copie os valores mostrados para `Config.WorldScreen` em `config.lua`.

O tamanho padrao e `9.6 x 5.4` metros, proporcao 16:9, com altura parecida com 3 personagens empilhados. A autoridade principal usa o passaporte definido em `Config.Access.ownerPassport`; a checagem acontece novamente no servidor para toda alteracao.

## Inicializacao do telao

Por padrao, `Config.WorldScreen.startDisabled = true`.
Isso faz o telao iniciar desligado sempre que o servidor ou o resource reiniciar.
O KVP continua salvando posicao, tamanho, rotacao, crop e URL normalmente.
Para ligar no jogo, o admin usa `/telaoon` ou `/telao on`.
Para desligar, usa `/telaooff` ou `/telao off`.

## Logs para observar

No F8/client:

```text
[af_youtube_tv] client.lua carregado. Use /tvhelp para comandos.
[af_youtube_tv] Criando DUI ... https://cfx-nui-af_youtube_tv/html/index.html?url=...
[af_youtube_tv] YouTube IFrame API pronta. video=... state=...
[af_youtube_tv] Crop UV ativo via native DRAW_SPRITE_UV.
[af_youtube_tv] DEBUG ligada=true dui=true render=uv uv=native poly=nil edit=true target=crop ...
[af_youtube_tv] Telao 3D ativo via native DRAW_SPRITE_POLY.
```

No console do servidor:

```text
[af_youtube_tv] server.lua carregado com controle exclusivo do dono.
```

No console NUI/CEF, se disponivel, o JS tambem registra mensagens com `[af_youtube_tv]`.

## Problemas comuns

### Tela preta

- Confirme que o resource iniciou com `ensure af_youtube_tv`.
- Use `/tvdebug` e veja se `dui=true`.
- Teste outro video com `/tvurl`.
- Algumas lives/videos nao permitem embed.
- Confirme que o PC tem internet e consegue acessar YouTube.
- Se a tela preta aparecer logo apos trocar para UV, teste `/tvrender mask`.

### Borda preta no crop

- Use `/tvrender uv`. Esse modo desenha somente a area escolhida da textura.
- Se ainda aparecer preto, o preto provavelmente esta dentro do proprio recorte. Use `/tveditar` e ajuste o crop ate pegar apenas o video.
- Use `/tvrender mask` somente como fallback, porque ele precisa mascarar as sobras e pode criar moldura preta.

### Autoplay bloqueado

O YouTube/CEF pode bloquear autoplay com audio. Deixe:

```lua
Config.Autoplay = true
Config.Muted = true
```

Depois ajuste o audio conforme o comportamento no seu FiveM.

### Live com restricao

Algumas lives tem restricao de idade, regiao, login, direitos autorais ou embed. Nesses casos o player oficial pode recusar carregar dentro do iframe.

Se aparecer a mensagem do YouTube `Video unavailable` dizendo que o dono bloqueou exibicao neste site ou aplicativo, o resource esta funcionando, mas aquele video/live nao permite embed externo. Teste com:

```text
/tvc M7lc1UVf-VE
```

Se o video de teste aparecer, escolha uma live com incorporacao permitida ou habilite a opcao de incorporacao na sua propria live/canal do YouTube.

### Anuncio do YouTube

Este resource usa o embed oficial. Ele nao bloqueia anuncios, nao remove DRM e nao extrai video por meios nao oficiais.

### Audio nao tocando

- Teste `Config.Muted = false`, mas autoplay pode parar de funcionar.
- Clique/interaja no jogo se o CEF exigir gesto de usuario.
- Verifique mixer de volume do Windows/FiveM.

### DUI nao carregando

- Confirme que a URL local esta no formato `https://cfx-nui-af_youtube_tv/html/index.html`.
- Reinicie com `/tvreset`.
- Veja erros no F8.

### Resource nao iniciou

- Confirme que a pasta esta em `resources\af_youtube_tv`.
- Confirme `ensure af_youtube_tv` no cfg.
- Veja se `fxmanifest.lua` esta na raiz do resource.

### Telao nao aparece no mundo

- Use `/telao status` e confira se `ligado=true`.
- Use `/telao aqui 8` para colocar o telao diretamente a sua frente.
- Use `/telaoedit`; a borda verde deve aparecer no painel.
- Se aparecer so um painel preto, veja o F8: o DUI pode ainda estar carregando ou o YouTube pode ter bloqueado a live.
- Se o F8 mostrar que `DrawSpritePoly` esta indisponivel, esse build do FiveM nao consegue desenhar o telao 3D por este metodo.

### Video errado ou espelhado no telao

- Use `/tvc LINK_DA_LIVE` antes de `/telao on` ou `/telao aqui`.
- Se quiser forcar diretamente, use `/telao url LINK_DA_LIVE`.
- Se o video aparecer espelhado, deixe `Config.WorldScreen.flipX = true`.
- Se aparecer invertido de cima para baixo, teste `Config.WorldScreen.flipY = true`.

## Asset real / CodeWalker

O telao atual e um painel 3D desenhado por script, sem precisar editar mapa. Para colocar em um asset real de TV/telao no mapa, o caminho futuro e usar CodeWalker ou ferramenta equivalente:

1. No jogo, posicione o painel por script primeiro com `/telao aqui`, `/telaoedit` e `/telaosalvar`.
2. Anote `x`, `y`, `z`, `heading`, `width` e `height`.
3. No CodeWalker, crie um YMAP pequeno na regiao da praca.
4. Adicione um prop/modelo de telao ou crie um modelo simples: moldura + plano retangular 16:9.
5. Use as coordenadas salvas do script para colocar o prop no mesmo lugar.
6. Caminho mais seguro: use o asset real como moldura fisica e mantenha o painel DUI por script um pouquinho na frente da tela.
7. Caminho avancado: se o modelo tiver material proprio de tela, tentar substituir esse material por runtime texture. Nem todo modelo aceita isso facilmente.

O caminho mais seguro agora e posicionar e validar o painel 3D primeiro. Depois que a posicao estiver perfeita na praca, fica mais facil criar ou escolher um asset real no CodeWalker.
