# of_busjob

Emprego de motorista de onibus para o vRP Creative do Ouro Fino RP.

## Dependencias

- `vrp`
- `target`

Nao usa QBCore, qb-menu, PolyZone, LegacyFuel ou garages. O pagamento usa o item
`dollar`, o combustivel usa `Entity(vehicle).state.Fuel` e a chave usa
`Entity(vehicle).state.Lockpick`, seguindo os resources atuais da base.

## Uso

1. Adicione `ensure of_busjob` ao `server.cfg` depois de `start [scripts]`.
2. Reinicie o servidor ou use `ensure of_busjob` no console.
3. Abra a Central de Empregos e selecione `Motorista de Onibus`.
4. Va ate a garagem marcada no mapa, retire o onibus e siga as rotas.
5. Use `E` no ponto para embarcar e novamente no destino para desembarcar.
6. Use `/sairtrabalho` para encerrar o emprego e remover o onibus.
