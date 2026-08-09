# OF Broom Proxy

Proxy privado de diagnostico para a Nimbus. Ele usa a malha da vassoura com:

- handling privado `OF_BROOM_PROXY`, copiado da Oppressor2 para voo e impulso;
- `LAYOUT_BIKE_SPORT` da Akuma/Nimbus para a postura do piloto.

Nao deve ser adicionado a garagem, concessionaria, catalogos ou comandos publicos.
O unico ponto de entrada e o comando de debug do `af_witch_broom`:
`/vassoura_proxy_localtest` ou `/vassoura_proxy_networktest`.

O resource referencia somente `LAYOUT_BIKE_SPORT`, que ja existe no jogo. Ele
nao declara `vehiclelayouts.meta` e nao redefine nenhum layout nativo.
