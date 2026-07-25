# Auditoria da lavagem de dinheiro - Pombal

## Sistemas encontrados

- `resources/[scripts]/inventory/*/moneywash.lua`: emprego legado por rotas. Recebe `wetdollar`, gera promissorias e troca as promissorias por `dollar` no ponto inicial.
- `resources/[scripts]/moneywash`: sistema de maquinas persistentes. Recebe `dirtydollar`, processa valores e entrega `dollar`.

O resource dedicado `moneywash` foi escolhido para a integracao da maquina fixa do Pombal. O emprego legado e as maquinas moveis existentes foram preservados.

## Falhas observadas no fluxo antigo

- Alguns eventos das maquinas moveis aceitam identificadores enviados pelo client sem validar permissao, distancia, instancia ou proprietario.
- O emprego legado nao representa uma maquina fixa e usa outro fluxo de itens.
- Nenhum dos fluxos existentes aplicava os limites economicos pedidos para a lavanderia do Pombal.

## Integracao criada

- Grupo oficial: `Pombal`.
- Local: `vector4(2540.83,2520.59,46.20,300.48)`.
- Entrada: `dirtydollar`.
- Saida: `dollar`.
- Taxa inicial: 25%.
- Duracao inicial: 120 segundos.
- Limite por operacao: 1.000 a 50.000.
- Limite diario: 150.000 por passaporte.
- Cooldown: 300 segundos depois da coleta.
- Capacidade: uma operacao por maquina.
- Chance policial inicial: 0%.
- Interacao: target local, sem blip publico.
- Persistencia: tabela `moneywash_operations`, criada automaticamente pelo resource e documentada em `database.sql`.

## Separacao de Sao Judas

Nao foi encontrado ponto de lavagem em `of_aviao_sao_judas` nem em `af_map_blips`. Nenhum arquivo de Sao Judas foi alterado.

## Testes recomendados

1. Reiniciar `moneywash` e confirmar a criacao da tabela no banco.
2. Testar o target com membro do Pombal e com jogador sem o grupo.
3. Inserir 1.000 `dirtydollar` e confirmar 250 de taxa e 750 de valor limpo.
4. Tentar zero, negativo, decimal, saldo insuficiente e valor acima de 50.000.
5. Tentar dois cliques e uma segunda operacao enquanto a maquina estiver ocupada.
6. Reiniciar o resource durante o processamento e coletar depois do prazo.
7. Reiniciar o servidor durante o processamento e coletar depois do prazo.
8. Tentar coletar duas vezes e confirmar um unico pagamento.
9. Confirmar os logs com prefixo `[pombal/wash]` no terminal.
10. Manter `PoliceAlertChance = 0` ate concluir os testes economicos.
