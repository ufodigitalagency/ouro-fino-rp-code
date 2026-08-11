# of_drivingschool

Fundacao persistente e operacional do sistema de CNH e Autoescola do Ouro Fino RP.

## Estado atual — Phase 3A

Esta fase oferece:

- persistencia das categorias A, B, C e D;
- NPC fixo e target da Autoescola;
- sessoes server-side de prova Categoria B;
- tres vagas reservadas atomicamente;
- veiculo temporario configuravel;
- limitador exclusivo de 50 km/h;
- checklist ordenado de motorista, cinto, motor e farois;
- estrutura de rotas futuras e coordenadas da futura baliza;
- NUI de resultado somente para apresentacao;
- comandos administrativos e de emergencia pelo console;
- auditoria persistente das concessoes e revogacoes;
- limpeza por cancelamento, desconexao, morte, timeout, desaparecimento do veiculo e stop do resource.

Ainda NAO:

- bloqueia jogadores sem CNH;
- altera o `af_starter_vehicle`;
- remove ou condiciona o Panto automatico;
- concede CNH ao concluir o checklist;
- executa ou pontua uma rota pratica;
- fiscaliza semaforos ou placas;
- cria ou avalia a prova de baliza;
- altera controles, garagens ou persistencia de veiculos pessoais.

## Persistencia

Licencas:

`ouro_fino_driver_licenses`

Auditoria administrativa:

`ouro_fino_driver_license_audit`

A chave da licenca e `Passport + Category`. Os status continuam sendo `active`, `suspended` e `revoked`.

## Exports server-side

- `GetLicense(Passport,Category)`
- `ListLicenses(Passport)`
- `HasLicense(Passport,Category)`
- `GrantLicense(Passport,Category)`
- `SuspendLicense(Passport,Category,ResponsiblePassport,Reason)`
- `RevokeLicense(Passport,Category,ResponsiblePassport,Reason)`
- `ActivateLicense(Passport,Category)`

Nenhum export e exposto diretamente ao cliente.

## Comandos

Admin dentro do jogo:

- `/cnhdar <passaporte> [categoria] [motivo]`
- `/cnhremover <passaporte> [categoria] [motivo]`
- `/cnhconsultar <passaporte> [categoria]`
- `/ofcnhcds`
- `/ofcnhuitest <aprovado|reprovado> [motivo]` (somente apresentacao)

Jogador com prova ativa:

- `/ofcnhcancelar`

Console do FXServer:

- `ofcnhstatus <passaporte> [categoria]`
- `ofcnhgrant <passaporte> [categoria] [motivo]`
- `ofcnhrevoke <passaporte> [categoria] [motivo]`

Os comandos de concessao e revogacao do console aceitam exclusivamente `source == 0`.

## Diagnostico

No F8 do jogo:

`ofcnhdiag`

O diagnostico informa banco do motorista, cinto via `exports["hud"]:IsSeatbeltOn()`, motor, farois, farol alto e velocidade.

## Limite de seguranca da Phase 3A

As observacoes de cinto, motor e farois do checklist se originam no cliente. O servidor aceita somente a ordem esperada para a sessao e o veiculo registrados.

`READY_FOR_ROUTE` representa apenas preparacao para a rota, nunca autorizacao. Qualquer resultado ou concessao futura deve ser decidida pelo servidor, e nenhuma transicao do checklist chama `GrantLicense`.

Os eventos `of_drivingschool:ShowApproved` e `of_drivingschool:ShowFailed` controlam somente a NUI local. Exibir `APROVADO` nao concede licenca.
