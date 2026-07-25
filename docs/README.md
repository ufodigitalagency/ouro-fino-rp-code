# Ouro Fino RP - Organizacao da base

## Pastas principais

- `resources/`: resources carregados pelo FXServer.
- `db/`: dados internos do FXServer; nao editar manualmente.
- `assets/`: modelos e materiais de apoio do projeto.
- `docs/relatorios/`: auditorias, guias e relatorios de alteracoes.
- `logs/fxserver/`: logs e capturas antigas das sessoes de teste.
- `_codex_backups/`: backups preservados fora dos resources ativos.
- `_quarantine_disabled_resources/`: resources desativados temporariamente.

## Ferramentas na raiz do projeto

Os arquivos de inicializacao continuam na raiz de `Base` para preservar os
caminhos atuais:

- `server.bat`: inicia o FXServer com `server.cfg`.
- `STOP_FXSERVER_OCULTO.bat`: encerra um FXServer oculto.
- `server.cfg`: configuracao principal do servidor.
- `server.png` e `logo.png`: imagens usadas pelo servidor e interfaces.
- `database.sql` e `phone.sql`: arquivos SQL de referencia/importacao.

## Backups de resources

Backups com sufixo `.bak_codex` foram movidos para
`_codex_backups/resource_files/`, mantendo a mesma estrutura relativa de
`resources/`. Eles ficam fora do caminho de carregamento do FiveM. Isso e
importante porque varios manifests usam curingas como `client-side/*` e
`shared-side/*`; deixar um backup Lua dentro dessas pastas faz o FXServer
carrega-lo como script ativo e pode duplicar eventos, blips e listas.

## Regra para novos backups

Nao criar `.bak_codex` dentro de `resources`. Use uma pasta dentro de
`_codex_backups/` com a data e o resource afetado.
