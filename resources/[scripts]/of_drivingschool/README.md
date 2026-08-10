# of_drivingschool

Fundacao do sistema de CNH e autoescola do Ouro Fino RP.

## Estado atual — Phase 1A

Esta fase adiciona somente persistencia e API server-side.

Ainda NAO:

- bloqueia jogadores sem CNH;
- altera o `af_starter_vehicle`;
- entrega Panto apos aprovacao;
- cria prova pratica;
- cria NPC ou UI da autoescola;
- consulta o estado real do cinto;
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
