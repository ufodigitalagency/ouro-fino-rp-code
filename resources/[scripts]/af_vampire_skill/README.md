# af_vampire_skill

Habilidade isolada de Vampiro para o Ouro Fino Roleplay, integrada ao vRP/Creative e ao `af_owner_panel` existente.

## Administracao

No painel administrativo, informe o ID/passaporte do jogador e selecione `Habilidade: Vampiro` no campo **Cargo**. Os botoes **Aplicar Cargo** e **Remover Cargo** usam, respectivamente, as permissoes vRP `Vampire` e a sua remocao. A alteracao vale para jogadores conectados e desconectados.

## Comandos e atalhos

- `/vampiro`: ativa/desativa o modo Vampiro. A tecla `H` permanece livre para os farois dos veiculos.
- `/sugar` ou `E`: tenta sugar um jogador proximo; sem jogador valido, tenta um NPC humano proximo.
- `/vampnpc`: cria um NPC temporario a frente do vampiro para teste.
- `/removervampnpc`: remove o NPC temporario de teste.

O atalho de drenagem pode ser alterado em `config.lua` ou nas configuracoes de teclas do FiveM.

## Super pulo e velocidade

Ao ativar o modo, o jogador recebe `Config.SuperJumpCharges` cargas de super pulo. Cada salto usa uma carga. Quando chegar a zero, a recarga leva `Config.SuperJumpRechargeSeconds` segundos e uma notificacao avisa quando as quatro cargas voltarem.

- `Config.SpeedMultiplier`: velocidade de corrida. Use valores entre `1.0` e `1.49`; `1.35` e o valor seguro atual.
- `Config.SuperJumpVerticalVelocity`: altura do salto. Comece entre `9.0` e `16.0`.
- `Config.SuperJumpCharges`: quantidade de super pulos por ciclo.
- `Config.SuperJumpRechargeSeconds`: tempo de recarga em segundos.

## Regras

- Apenas jogadores com a permissao `Vampire` conseguem ativar ou usar a habilidade.
- A habilidade e bloqueada em veiculos, safe zones e nas zonas de hospital configuradas.
- Jogadores e NPCs precisam estar proximos, vivos e na mesma instancia.
- Ha cooldown global, cooldown por alvo e bloqueio durante a animacao.
- O dano e a cura de jogadores sao aplicados pelo servidor apos revalidacao no fim da animacao.
- Para NPCs, o servidor autoriza a acao e a cura somente apos validar a entidade e envia o dano visual ao cliente que a iniciou; isto evita depender de uma nativa de dano de ped nao usada pelo runtime server-side desta base.

## NPCs e seguranca

O cliente procura NPCs humanos em `Config.NpcSearchRange`. Motoristas sao retirados do veiculo antes da drenagem, e o veiculo recupera o estado original das travas. O resource tenta obter controle e registrar o ped na rede; quando consegue um `netId`, usa sempre `DrainNpc`, cuja entidade, distancia, instancia, permissao, cooldown e cura sao validados pelo servidor.

Alguns peds criados localmente pelo GTA nao podem ser comprovados pelo servidor. Nesses casos existe um fallback apenas para animacao e dano local, ainda protegido por permissao, cooldown e bloqueio de operacoes paralelas. Por seguranca, esse fallback nao cura o vampiro (`Config.LocalNpcFallbackHeal = 0`).

## Configuracao

Edite `config.lua` para ajustar dano, cura, alcance, cooldown, teclas, zonas bloqueadas e logs. `Config.Debug = true` habilita logs no console do FXServer.

## Inicializacao e teste

O `server.cfg` ja possui `start [scripts]`, portanto este resource e carregado automaticamente por estar em `resources/[scripts]`.

1. Reinicie `af_owner_panel` e `af_vampire_skill`.
2. No painel, aplique `Habilidade: Vampiro` ao seu ID.
3. Use `/vampiro`, confirme o sprint/super pulo e use `/sugar` perto de um NPC ou jogador.
4. Remova o cargo no painel e confirme que `/vampiro` passa a ser negado.
