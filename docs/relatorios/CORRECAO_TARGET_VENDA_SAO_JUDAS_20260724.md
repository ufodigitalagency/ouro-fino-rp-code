# Correcao do target e modo de venda de Sao Judas

Data: 2026-07-24

## Escopo

Esta entrega executa somente a Fase A. O laboratorio de drogas e o comercio
entre jogadores nao foram iniciados porque dependem da aprovacao da venda NPC
dentro do jogo.

## Causa confirmada da opcao ausente

O target consultava apenas o state bag local
`SaoJudasStreetSalesEligible`. Quando o servidor retornava `false`, a opcao era
ocultada sem informar o motivo. A consulta era renovada a cada cinco segundos e
o target repetia filtros proprios, inclusive `IsEntityAMissionEntity`, antes de
chamar o resource de venda.

No banco usado no teste, o estado encontrado foi:

```text
Permissions:SaoJudas = { "1": 6 }
Operador de Distribuicao.Members = []
```

O passaporte 1 pertence a Sao Judas no nivel 6, mas nao e a lideranca nivel 1
e ainda nao recebeu a tag `Operador de Distribuicao`. Portanto o servidor
retornava corretamente `not_authorized`. Ter acesso administrativo nao concede
automaticamente acesso operacional a venda.

Para testar com o passaporte 1, o chefe deve atribuir pelo F9:

```text
Tags > Operador de Distribuicao > adicionar passaporte 1
```

Alternativamente, o personagem de teste precisa estar no nivel 1 real de Sao
Judas. Nenhum bypass de dono ou administrador foi criado.

## Correcao do target manual

O `target` agora verifica se `sao_judas_street_sales` esta iniciado e consulta
diretamente a export client-side `CanOffer(entity)`. A export utiliza a
elegibilidade detalhada recebida do servidor e uma unica funcao local para
classificar o NPC.

Isso elimina a duplicacao silenciosa entre o target e o resource. A opcao
`OFERECER PRODUTO` aparece quando autorizacao, produto, estado do jogador e NPC
forem validos. Peds nao networkados podem aparecer no target; a tentativa de
networkar ocorre apenas quando a negociacao for iniciada.

## Diagnostico

Com debug ativo, cada combinacao de ped e motivo e registrada no maximo uma vez
a cada dez segundos:

```text
[saojudas/street-sales-target]
```

O comando exclusivo do passaporte configurado como dono e:

```text
/saojudas_sales_target_debug
```

Ele analisa o ped mirado ou o mais proximo e informa no F8:

- handle, modelo, tipo, humanidade e estado de mission entity;
- network ID, vida, veiculo e distancia;
- safe zone e routing bucket;
- passaporte, membro, lideranca e tag operacional;
- drogas reconhecidas;
- elegibilidade e motivo de rejeicao;
- validacao server-side do NPC quando ele estiver networkado.

## Acao administrativa Deletar

A opcao continua visivel somente quando `LocalPlayer.state.Admin` estiver
ativo. O evento `DeletePed` agora tambem exige o grupo real `Admin` no servidor.
Uma chamada manual feita por jogador comum nao remove o ped.

## Modo de venda de rua

Ativacao:

```text
/venderdrogas
```

O comando e o key mapping opcional ficam configuraveis em `StreetMode`. Nenhum
item novo foi criado.

Ao ativar, o servidor valida novamente:

- Sao Judas e lideranca/tag operacional;
- existencia de uma das seis drogas autorizadas;
- vida, veiculo, safe zone e routing bucket;
- ausencia de venda ativa.

Com o modo ativo, uma unica thread procura civis a cada 1000 ms em um raio de
12 metros. A busca para quando ha candidato ou venda. O NPC precisa estar em
linha de visao, nao pode ser jogador, ped de missao, ped scripted, estar morto,
ferido, em veiculo ou combate.

O servidor reserva o NPC antes da aproximacao. O client solicita controle,
chama o civil para aproximadamente 1,6 metro, faz ambos se olharem e mostra:

```text
[E] Negociar
```

Se o NPC desaparecer, fugir, morrer, entrar em combate, perder controle ou se
afastar, a sessao e cancelada sem produto ou pagamento. O NPC e liberado e seus
eventos temporarios sao restaurados.

O target com Alt permanece como alternativa manual.

## Arquivos alterados

- `resources/[scripts]/target/client-side/core.lua`;
- `resources/[scripts]/sao_judas_street_sales/config.lua`;
- `resources/[scripts]/sao_judas_street_sales/client.lua`;
- `resources/[scripts]/sao_judas_street_sales/server.lua`;
- `resources/vrp/modules/player.lua`;
- `tools/test-sao-judas-street-sales.ps1`.

## Validacoes executadas

- cinco arquivos Lua analisados com `luaparser`;
- teste estrutural `test-sao-judas-street-sales.ps1` aprovado;
- FXServer iniciou o resource sem erro;
- restart isolado de `sao_judas_street_sales` aprovado;
- seis produtos e divisao 85/15 preservados;
- dispatch continua desabilitado;
- venda legada continua desabilitada.

## Teste obrigatorio no jogo

### Correcao apos o primeiro teste ao vivo

O log real do F8 confirmou que o passaporte 1 estava autorizado como lider e
possuia `cocaine`. Ele tambem revelou que o client consultava `os.time()` para
o cooldown do ped, mas a biblioteca `os` nao esta disponivel no runtime client
do FiveM. Civis elegiveis chegavam a esse trecho e a export do target falhava.

O client agora compara o timestamp replicado pelo servidor com
`GetCloudTimeAsInt()`. O ped observado no diagnostico especifico continuou
corretamente rejeitado como `npc_in_combat`; o bloqueio de NPC em combate foi
preservado.

Antes da Fase B:

1. atribuir a tag ao personagem de teste;
2. colocar `cocaine` no inventario;
3. aguardar ate 2,5 segundos;
4. testar `OFERECER PRODUTO` com Alt;
5. executar `/venderdrogas`;
6. aguardar um civil se aproximar;
7. pressionar E e concluir uma venda;
8. confirmar remocao da droga, pagamento e credito no cofre;
9. executar `/saojudas_sales_target_debug` diante de qualquer rejeicao;
10. repetir com dois jogadores antes de aprovar concorrencia.

## Reinicio

Como `target` possui varios dependentes, o caminho mais seguro e reiniciar o
servidor completo. Para manutencao isolada:

```text
restart target
start inventory
start sao_judas_operations
start sao_judas_street_sales
```

Tambem devem ser religados outros resources dependentes do target que o FXServer
tenha parado.

## Fases bloqueadas

- Fase B: nao iniciada;
- Fase C: nao iniciada.

Elas somente devem comecar depois de uma venda NPC completa ser confirmada no
jogo.
