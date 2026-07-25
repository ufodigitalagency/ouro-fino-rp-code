# Auditoria da bancada e do cofre de Sao Judas

## Grupo e lideranca

- Grupo canonico: `SaoJudas`.
- Alias legado preservado: `Vagos`.
- Lideranca real: nivel 1 da hierarquia nativa do vRP/F9.
- Operacao da bancada: chefe ou cargo `Operador de Fabricacao`.

## Marcador anterior

O circulo antigo vinha de `resources/[scripts]/chest/client-side/core.lua`.
Ele era o primeiro de dois acessos ao mesmo bau persistente `SaoJudas`:

- removido: `vec3(-479.67,1610.02,369.58)`;
- preservado: `vec3(-482.34,1614.76,366.64)`.

O ponto removido registrava target, desenhava `DrawMarker` e permitia abrir o
bau pela tecla E. Nenhum registro de banco de dados ou conteudo do bau foi
apagado. O segundo acesso continua usando a mesma chave persistente.

## Bancada

- Target: `vec3(-480.5672,1614.7445,369.4934)`.
- Posicao de alinhamento futura: `vector4(-480.64,1613.86,369.58,0.0)`.
- O objeto existente do mapa foi mantido; nenhum prop foi criado.
- As receitas permanecem desativadas ate aprovacao da economia.

Itens reais encontrados no catalogo:

- `lockpick`: Gazua, peso 1.25, durabilidade 72;
- `lockpickplus`: Gazua ++, peso 1.25, durabilidade 720;
- `blocksignal`: Bloqueador de Sinal, peso 0.75;
- `WEAPON_CROWBAR`: Pe de Cabra, peso 1.35, durabilidade 240;
- `dismantle`: Cartao Ilegivel, peso 0.0;
- `cellphone`: Celular, peso 0.75, durabilidade 240.

Nao foram localizados itens com nomes de broca, ferramenta de corte ou celular
descartavel. Tambem nao foram encontrados arquivos locais de imagem com os
indices acima; a NUI pode resolver esses indices por outra fonte da base.

Receitas existentes encontradas no modo `Lester`:

- `lockpick`;
- `blocksignal`;
- `dismantle`.

Nao foram encontradas receitas aprovadas para `lockpickplus` ou
`WEAPON_CROWBAR`. Nenhuma receita ou item foi duplicado nesta entrega.

## Cofre financeiro

- Target: `vector4(-479.68,1609.96,369.58,184.26)`.
- Acesso completo: apenas nivel 1 de `SaoJudas`.
- Saldos persistentes: dinheiro sujo e dinheiro limpo pendente.
- Banco limpo oficial: conta da organizacao `SaoJudas` no F9.
- A transferencia para o F9 nao passa pela conta pessoal do chefe.
- A lavagem entre faccoes nao foi implementada nesta fase.

## Persistencia e integracao futura

O resource cria `sao_judas_vault_transactions` automaticamente e expoe apenas
APIs server-side para consultar saldos e creditar valores idempotentes. Essas
APIs preparam a futura integracao de atividades e da lavagem pelo Pombal sem
permitir que o client escolha valores.
