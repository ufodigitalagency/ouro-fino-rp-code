# Auditoria - Funcoes e cofre do Pombal

## Sistema existente

- Menu F9: `dynamic`, comando `PlayerFunctions`, key mapping `F9`.
- Computador de organizacao: `painel`.
- Grupo oficial: `Pombal`.
- Chefe real: nivel `1`, nome de hierarquia `Chefe do Pombal`.
- Saldo limpo oficial: coluna `Bank` da linha `Permission = 'Pombal'` na tabela `permissions`.
- Consulta do saldo: `vRP.Permissions("Pombal","Bank")`.
- Credito do saldo: `vRP.PermissionsUpdate("Pombal","Bank","+",valor)`.
- Historico: tabela `painel_creative_transactions`.

## Implementacao

- Resource autoritativo: `pombal_finance`.
- A hierarquia nativa do grupo `Pombal` foi adaptada aos cargos reais da faccao.
- O painel F9 continua usando sua aba `Permissoes` original, sem botoes, modais ou subcargos paralelos.
- O dropdown de cargos e alimentado por `vRP.Hierarchy("Pombal")` e mostra a hierarquia especifica do Pombal.
- `Chefe do Pombal` possui acesso automatico aos servicos especializados.
- `Operador de Lavagem` pode iniciar a lavagem da faccao.
- `Operador de Desmanche` pode iniciar o desmanche.
- Os demais cargos nao recebem esses acessos especializados.

## Hierarquia do Pombal

1. Chefe do Pombal
2. Braco-Direito
3. Gerente-Geral
4. Gerente de Operacoes
5. Gerente de Ponto
6. Operador de Lavagem
7. Operador de Desmanche
8. Soldado
9. Olheiro
10. Aviaozinho

## Cofre fisico

- Coordenada: `vec3(2538.5972,2522.2722,42.5448)`.
- Qualquer membro do Pombal pode depositar `dirtydollar` fisico do proprio inventario.
- O saldo sujo depositado nao pode ser sacado ou transferido para inventarios.
- Somente o chefe consulta os saldos e transfere valores limpos.
- Persistencia: ledger `pombal_vault_transactions` com referencias unicas.
- Saldos: soma de `DirtyDelta` e `CleanDelta`.
- O saldo limpo transferido vai para o banco oficial do F9 e gera historico no painel.

## Banco oficial no F9

- O deposito do grupo `Pombal` consome o item fisico `dollar` do inventario.
- A conta bancaria pessoal nao e debitada como alternativa quando falta dinheiro fisico.
- Policia, hospital, mecanica e os demais departamentos preservam o fluxo anterior de deposito bancario.
- Saques e transferencias do banco oficial continuam usando a implementacao original do painel.

## Divisao dos servicos

- Aviaozinho: 20% para o cofre e 80% para o trabalhador.
- Desmanche do Pombal: 20% para o cofre e 80% para o trabalhador.
- Percentuais ficam em `pombal_finance/config.lua` e podem ser ajustados sem alterar a logica.
- O desmanche generico da cidade continua pagando sua recompensa original.

## Lavagem da faccao

- Taxa preservada em 25%.
- O funcionario autorizado inicia a operacao diretamente com o saldo sujo do cofre.
- O resultado e creditado automaticamente em `clean_pending`.
- Nenhum item da faccao passa pelo inventario do funcionario.
- Somente o chefe transfere o saldo limpo pendente ao banco do F9.
- Operacoes pessoais continuam separadas das operacoes da faccao.
- A maquina identifica as opcoes como lavagem pessoal e lavagem do cofre da faccao.

## Reinicio e teste

Depois de reiniciar o servidor, testar:

1. A aba `Permissoes` lista somente os cargos especificos do Pombal.
2. Membro comum e bloqueado no desmanche e na lavagem.
3. Operador de Lavagem acessa somente a maquina de lavagem.
4. Operador de Desmanche acessa somente o desmanche.
5. Chefe do Pombal acessa ambos.
6. Aviaozinho e desmanche creditam a divisao no cofre.
7. Lavagem da faccao move saldo sujo para saldo limpo pendente.
8. Chefe transfere o saldo limpo para o banco do F9.
9. Dinheiro lavado pessoalmente entra no inventario como `dollar` e e consumido ao depositar no F9 do Pombal.
10. Membro deposita `dirtydollar` no cofre fisico e nao consegue saca-lo novamente.
11. Historico e logs possuem os prefixos `[pombal/finance]`, `[pombal/wash]` e `[pombal/chopshop]`.
