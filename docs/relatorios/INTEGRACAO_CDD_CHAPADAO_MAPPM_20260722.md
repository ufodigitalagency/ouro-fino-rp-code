# Integracao CDD, Chapadao e mapPM

Data: 2026-07-22

## Mapas

- `of_favela_deus` foi removida da carga e preservada em `_quarantine_disabled_resources/favelas_20260722/of_favela_deus_removed`.
- `[favelacdd]` foi extraida seletivamente para `resources/[maps]/of_favela_cdd`.
- Chapadao permanece em `resources/[maps]/of_chapadao`.
- Os assets usados pelas duas favelas ficam em `resources/[maps]/of_favelas_shared`.
- O pacote original usado na extracao nao foi alterado.

Validacao dos streams:

| Resource | Arquivos esperados | Arquivos instalados | Faltando | Extras |
|---|---:|---:|---:|---:|
| of_favela_cdd | 164 | 164 | 0 | 0 |
| of_chapadao | 227 | 227 | 0 | 0 |
| of_favelas_shared | 86 | 86 | 0 | 0 |

Nao existem nomes de arquivo duplicados entre esses tres streams.

## Departamento de policia

- O blip principal foi transferido para o `mapPM`.
- As garagens policiais antigas foram removidas.
- O vestiario, o arsenal, o ponto de servico e a zona segura policial foram transferidos.
- As portas 17 a 56 da delegacia antiga permanecem trancadas e sem interacao.
- A carga explicita do interior nativo de Mission Row foi removida do client do `mapPM`.

Garagens novas:

| ID | Tipo | Acesso |
|---|---|---|
| 210 | Viaturas mapPM | Policia em servico |
| 211 | Veiculos pessoais mapPM | Publico |
| 212 | Helicoptero policial | Policia em servico |
| 213 | Veiculos pessoais Chapadao | Publico |
| 214 | Helicopteros pessoais Chapadao | Publico, somente classe Helicopteros |

## Pontos funcionais

- mapPM: vestiario policial, arsenal gratuito, bau policial, servico, viaturas, garagem publica e helicoptero policial.
- Chapadao: garagem publica, heliponto pessoal, mercearia, barbearia e loja de roupas.
- O arsenal valida `Policia` no servidor e entrega itens sem cobranca.
- O botao de compra da loja comum nao aparece no arsenal gratuito; a retirada continua pelo fluxo de arrastar para o inventario.

## Validacoes executadas

- Parser Lua 5.3 em todos os arquivos Lua alterados: aprovado.
- `node --check` no JavaScript da compra da loja: aprovado.
- Comparacao SHA-256 dos assets de CDD, Chapadao e compartilhados: aprovada.
- Busca pelas coordenadas antigas nos resources funcionais: os pontos operacionais foram removidos ou substituidos.

## Teste no jogo

Fazer reinicio completo do servidor, pois houve troca de streams de mapa. Depois validar:

1. CDD carrega sem assets ausentes e sem conflito com Chapadao.
2. Favela Deus nao carrega.
3. Chapadao e mapPM permanecem visiveis simultaneamente.
4. A delegacia antiga nao possui blip, servico, garagem, roupas ou arsenal e suas portas nao abrem.
5. Policial fora de servico nao acessa viaturas, helicoptero ou arsenal.
6. Policial em servico acessa as tres funcoes.
7. Garagens publicas exibem apenas os veiculos esperados.
8. O heliponto do Chapadao lista somente helicopteros pessoais.
9. Mercearia, barbearia e roupas do Chapadao abrem corretamente.
10. Todos os pontos de garagem mostram o icone flutuante de carro.

## Ajustes adicionais

- O arsenal policial foi movido para `-421.88, 1088.37, 327.68` e agora possui marcador, interacao por `E`, target e blip de arma.
- O heliponto policial passou a oferecer somente `valkyrie2`.
- Sao Judas recebeu uma segunda garagem publica, ID 215.
- Pombal recebeu garagem publica, ID 216, mercearia, barbearia, roupas, arsenal e bau de faccao.
- O grupo persistente `Pombal` foi adicionado ao vRP e ao painel do dono.
- O arsenal do Pombal oferece pistola, Micro SMG, rifle, municoes e radio, sem cobranca e com validacao server-side do grupo.
- Pombal e Sao Judas receberam icones principais no mapa e aliases de GPS.
