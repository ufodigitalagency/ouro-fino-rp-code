# AF Witch Broom

Habilidade exclusiva de vassoura voadora para o grupo `Bruxo` no Ouro Fino Roleplay.

## Modelo de producao

O resource usa a Nimbus 2016 como veiculo add-on independente:

- resource do modelo: `resources/[vehicles]/of_magic_broom`;
- spawn configurado: `of_magic_broom`;
- tema utilizado: `Authentic theme`;
- modelo, textura e metadata proprios;
- nenhuma substituicao global da Akuma.

O `fxmanifest.lua` declara `of_magic_broom` como dependencia. No `server.cfg`, a categoria `[vehicles]` ja inicia antes de `[scripts]`.

O voo usa duas entidades networkadas:

- `of_broom_proxy` invisivel como chassi fisico e assento do piloto;
- `of_magic_broom` como Nimbus visual, sem colisao e anexada ao chassi.

Todos os clients reconciliam a invisibilidade do proxy e o anexo da Nimbus pelas state bags. Assim, inclusive jogadores que entram depois veem somente a vassoura e o piloto.

## Diagnostico de postura

A Nimbus original usa o layout `LAYOUT_BIKE_SPORT` da Akuma; a Oppressor Mk II
usa `LAYOUT_BIKE_SPORT_OPPRESSOR2`. Como o piloto ocupa o proxy invisivel, e
nao a Nimbus visual, o layout do proxy e que define a postura dos bracos e
maos. Offset da malha nao corrige essa animacao.

O resource privado `resources/[vehicles]/of_broom_proxy` foi validado nos
testes local e networkado e agora e o chassi de producao. Ele preserva o
handling especial da Oppressor2, mas usa o layout de motocicleta que alinhou
as maos do piloto sobre o cabo da Nimbus:

| Campo | Oppressor2 | Nimbus/Akuma | Proxy de teste |
| --- | --- | --- | --- |
| Handling | `OPPRESSOR2` | `AKUMA` | `OF_BROOM_PROXY` (copia privada da Oppressor2) |
| Layout | `LAYOUT_BIKE_SPORT_OPPRESSOR2` | `LAYOUT_BIKE_SPORT` | `LAYOUT_BIKE_SPORT` |
| Tipo | motocicleta | motocicleta | motocicleta |
| Rocket boost | sim | nao | sim |
| Voo/hover | handling especial | nao | handling especial |

Caso o layout Akuma nao mantenha o voo nativo na validacao de producao, a
proxima etapa sera um `vehiclelayouts.meta` proprio; nao sera usada animacao
Lua forcada sobre o piloto.

Os binarios do modelo ficam locais e ignorados pelo Git. Consulte o README do resource `of_magic_broom` antes de redistribui-los.

## Invocacao segura

A invocacao usa um handshake visual em quatro etapas:

1. o client carrega e valida `oppressor2` e `of_magic_broom`;
2. o servidor cria as duas entidades congeladas 60 metros abaixo do ponto final;
3. o client esconde o proxy, anexa a Nimbus e confirma `visualReady`;
4. o conjunto sobe para o ponto final, monta no proxy e o servidor confirma o motorista real.

Falha de modelo, streaming, controle de rede ou montagem cancela a sessao e remove a entidade.

## Uso

- O dono concede o cargo `Bruxo` pelo F9, em Central Administrativa > Permissoes.
- O jogador usa `/vassoura` para invocar ou iniciar o pouso.
- `W/A/S/D`: controles nativos da Oppressor Mk II.
- `NumPad 8/5`: inclinacao nativa de voo.
- `X`: impulso magico configuravel, com reforco curto e intervalo total padrao de 3,2 segundos entre ativacoes.
- `F`: pousar e guardar.

O voo nao usa bateria, energia ou recarga Lua. A vassoura pode ser usada em safe zones, preservando as protecoes globais de dano e armas. O boost nao exibe notificacoes invasivas.

O resource e iniciado automaticamente por `start [scripts]` no `server.cfg`.

Para recarregar durante o desenvolvimento:

```text
refresh
ensure of_magic_broom
restart af_witch_broom
```

## Diagnostico do dono

Os comandos abaixo so existem quando `Config.Debug = true` e aceitam apenas `Config.OwnerPassport`:

- `/vassoura_debug`: estado do modelo, entidade, rede, banco e visibilidade no F8;
- `/vassoura_spawnmodel`: cria uma copia local temporaria do modelo;
- `/vassoura_mounttest`: testa o banco de motorista;
- `/vassoura_remontar`: repete a montagem na Nimbus ativa;
- `/vassoura_cleanup`: remove sessoes e entidades temporarias.
- `/vassoura_proxydebug`: imprime proxy, visual, redes, attachment e state bags;
- `/vassoura_visualdebug`: repete o diagnostico visual;
- `/vassoura_offset x y z`: calibra o offset visual na sessao;
- `/vassoura_rotacao x y z`: calibra a rotacao visual na sessao;
- `/vassoura_salvaroffset`: imprime os valores calibrados para copiar na config.
- `/vassoura_offsetdebug`: imprime alinhamento, pose e estado do HUD.
- `/vassoura_hudpos x y`: ajusta temporariamente a posicao superior do HUD e imprime os valores para a config.
- `/vassoura_proxy_pose_test`: alias temporario do teste local.
- `/vassoura_proxy_localtest`: cria `of_broom_proxy` somente no client, visivel e sem sessao real.
- `/vassoura_proxy_networktest`: cria o proxy pelo servidor, recebe o network ID e testa a montagem apos obter controle.
- `/vassoura_proxy_diag`: imprime validade do modelo, quantidade de assentos, bones, colisao, trava e motorista no F8.

Os testes de proxy nao exigem o cargo Bruxo, mas continuam exclusivos do dono e
somem com `/vassoura_cleanup` ou ao reiniciar o resource. O teste local precisa
passar antes do networkado; nenhum deles cria Nimbus anexada ou altera a sessao
real da vassoura.

## Persistencia do cargo

`Bruxo` e um grupo real da base em `vrp/config/Global.lua`. A Central
Administrativa usa `vRP.SetPermission` e `vRP.RemovePermission`, gravando em
`entitydata` na chave `Permissions:Bruxo`. Para os cargos especiais Vampire e
Bruxo, o owner panel agora chama `SaveServer` imediatamente apos a mudanca.
Assim a permissao nao depende do source, state bag ou de um cache do resource
e permanece apos restart, reconexao e restart completo do servidor.

## Captura de teste

O Windows 10 build 19045 desta maquina nao expoe a interface exigida pela
captura sem borda (`IsBorderRequired`), que retorna `0x80004002`. A borda e
opcional, portanto o fallback independente da API Windows.Graphics.Capture e:

```powershell
powershell -ExecutionPolicy Bypass -File ".\resources\[scripts]\af_witch_broom\tools\capture-desktop.ps1"
```

Ele usa `CopyFromScreen`, salva uma PNG em `%TEMP%` e libera todos os handles.

Mantenha `Config.Debug = false` em producao.

## Ajustes de estabilidade desta versao

- O tempo de recarga do impulso agora e contado desde o inicio do turbo, evitando a soma acidental de duracao + cooldown.
- A Nimbus visual tem sua dinamica desativada enquanto anexada ao proxy e recebe uma protecao extra contra colisao com o chassi.
- Uma recuperacao conservadora atua apenas quando o proxy esta quase parado, junto ao solo e excessivamente inclinado; as curvas normais e o voo nativo nao sao sobrescritos.

Os valores podem ser ajustados em `Config.Boost.CooldownMs` e `Config.GroundStability`.
