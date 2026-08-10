# of_drivingschool

Fundacao do sistema de CNH e autoescola do Ouro Fino RP.

## Estado atual — Phase 2C

A fundacao persistente server-side esta ativa e o cliente possui diagnostico read-only de cinto, motor e farois.

Ainda NAO:

- bloqueia jogadores sem CNH;
- altera o `af_starter_vehicle`;
- entrega Panto apos aprovacao;
- cria prova pratica;
- cria NPC ou UI da autoescola;
- altera controles do veiculo.

## Persistencia

Tabela:

`ouro_fino_driver_licenses`

Chave:

`Passport + Category`

Categorias previstas:

- A
- B
- C
- D

Status previstos:

- `active`
- `suspended`
- `revoked`

## Exports server-side

- `GetLicense(Passport,Category)`
- `ListLicenses(Passport)`
- `HasLicense(Passport,Category)`
- `GrantLicense(Passport,Category)`
- `SuspendLicense(Passport,Category,ResponsiblePassport,Reason)`
- `RevokeLicense(Passport,Category,ResponsiblePassport,Reason)`
- `ActivateLicense(Passport,Category)`

Nenhum desses exports e exposto diretamente ao cliente.

## Diagnostico

No console do FXServer:

`ofcnhstatus <passaporte>`

ou:

`ofcnhstatus <passaporte> B`

O comando e somente leitura.

### Cliente

No console F8 do jogo:

`ofcnhdiag`

O diagnostico e somente leitura. Ele informa se o jogador esta em veiculo, se esta no banco do motorista, estado real do cinto via export do `hud`, motor, farois, farol alto e velocidade aproximada em km/h.
