# Mecanica Bennys - Ouro Fino RP

## Diagnostico

1. A base ja possuia o grupo de trabalho `Bennys`, com hierarquia, salario, servico e bau.
2. O sistema canonico de tunagem e o resource `lscustoms`.
3. A tunagem permanente e salva em `entitydata` na chave `LsCustoms:<passaporte>:<modelo>`.
4. Os veiculos pertencem a tabela SQL `vehicles`.
5. A garagem le a chave `LsCustoms` e reaplica as modificacoes ao retirar o veiculo.
6. O `lscustoms` ja captura e aplica cores, rodas, extras, neon, turbo e upgrades de desempenho.
7. O painel `af_owner_panel` ja concede e remove o cargo `Mecanico`, mapeado para `Bennys`.
8. O sistema de servico da base e o `vRP.ServiceToggle`/`vRP.HasService`.
9. O antigo `nation_bennys` usava uma chave de persistencia diferente e foi desativado para evitar dois tunings concorrentes.
10. A decisao adotada foi expandir o `lscustoms`, sem criar um resource mecanico paralelo.

## Arquivos principais

- `resources/[scripts]/lscustoms/shared-side/shared.lua`: configuracao da mecanica e precos.
- `resources/[scripts]/lscustoms/client-side/core.lua`: painel, diagnostico, animacao e reparo.
- `resources/[scripts]/lscustoms/server-side/core.lua`: permissoes, servico, validacoes, cobranca e persistencia.
- `resources/[maps]/ed_carzone`: mapa da oficina Car Zone/Bennys.

## Comandos

- `/mecservico`: entra ou sai do servico de mecanico.
- `/mecanico`: abre o painel de tunagem no veiculo parado mais proximo.
- `/mecdiagnostico`: mostra motor, lataria, tanque, combustivel e pneus.
- `/mecreparar`: executa o reparo com animacao e tempo configurado.

## Fluxo de tunagem

1. O dono concede o cargo `Mecanico` pelo painel administrativo.
2. O mecanico usa `/mecservico`.
3. Com o veiculo parado e a uma distancia maxima de 4 metros, usa `/mecanico`.
4. O painel existente permite cores, rodas, estetica e desempenho.
5. Ao salvar, o proprietario identificado pela placa recebe a confirmacao do valor.
6. O servidor cobra o proprietario e grava a tunagem na mesma chave usada pela garagem.
7. Se o cliente recusar ou nao possuir saldo, o preview e revertido.

## Configuracao

O bloco `MechanicConfig` fica no inicio de `shared-side/shared.lua`:

- `Permission`: grupo necessario (`Bennys`).
- `VehicleDistance`: distancia maxima do veiculo.
- `MaximumVehicleSpeed`: velocidade maxima permitida para atendimento.
- `RequireDuty`: exige servico ativo.
- `RequireWorkshop`: reservado para limitar por oficina; atualmente `false`.
- `RepairDuration`: duracao do reparo em milissegundos.
- `Debug`: logs de diagnostico no console.

## Mapa

O mapa `ed_carzone` e carregado pelo grupo `start [maps]` do `server.cfg`.
O manifesto registra `ed_westcarzone.ytyp` como `DLC_ITYP_REQUEST`.
Nao foram encontrados nomes de assets duplicados em outros resources.

## Teste

No console do servidor:

```text
restart ed_carzone
restart lscustoms
```

No jogo:

1. Conceder `Mecanico` ao passaporte de teste no painel do dono.
2. Usar `/mecservico` e confirmar a entrada em servico.
3. Aproximar-se de um veiculo parado e testar `/mecdiagnostico`.
4. Danificar levemente o veiculo e testar `/mecreparar`.
5. Abrir `/mecanico`, alterar uma opcao e confirmar a compra pelo proprietario.
6. Guardar e retirar o veiculo na garagem para confirmar a persistencia.
7. Sair do servico e confirmar que o painel nao abre.

Logs esperados usam o prefixo `[lscustoms/mechanic]`.
