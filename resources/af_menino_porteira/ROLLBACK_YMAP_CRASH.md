# Rollback do crash de YMAP / YTYP

Data: 2026-07-02

## Diagnostico

O arquivo `stream/meninodaporteira.ytyp` ativo estava corrompido.

- Arquivo corrompido: `stream/meninodaporteira.ytyp`
- Tamanho do arquivo corrompido: `205 bytes`
- Erro observado no FiveM: `Failed to call inflate() for streaming file compcache:/af_menino_porteira/meninodaporteira.ytyp`
- Sintoma: crash ao entrar no servidor.

## Arquivos movidos para quarentena

Nada foi apagado definitivamente. Os arquivos suspeitos foram movidos para:

`C:\meu-server-gta\Base\resources\af_menino_porteira\_quarantine_corrompidos\20260702_101832`

Arquivos movidos:

- `meninodaporteira.ytyp` - `205 bytes`
- `af_menino_porteira_placements.ymap` - `1229 bytes`
- `af_menino_porteira.cwproj` - `540 bytes`

## Backup restaurado

Foi restaurado o backup funcional:

`C:\meu-server-gta\Base\resources\af_menino_porteira\tools\backups\20260701_010825\meninodaporteira.ytyp`

Destino:

`C:\meu-server-gta\Base\resources\af_menino_porteira\stream\meninodaporteira.ytyp`

Tamanho do `.ytyp` restaurado: `936 bytes`

O arquivo restaurado esta em XML e contem o archetype `meninodaporteira`.

## YMAP desativado

O `.ymap` foi removido temporariamente de `stream/` e movido para quarentena.

O resource voltou para o modo seguro por script. Nao recriar YMAP agora.

## Estado final

`config.lua`:

- `Config.UseScriptSpawn = true`
- Monumentos configurados:
  - `principal`
  - `praca_2`
  - `praca_3`

`fxmanifest.lua`:

- Carrega apenas `stream/meninodaporteira.ytyp` como `DLC_ITYP_REQUEST`
- Nao usa `this_is_a_map 'yes'`
- Nao carrega `.ymap`
- Carrega somente `config.lua` e `client.lua` no client

## Teste

No console do FXServer:

```text
restart af_menino_porteira
```

No jogo:

```text
/meninostatus
```

Resultado esperado:

- FiveM nao crasha ao entrar no servidor
- `Config.UseScriptSpawn = true`
- Os 3 monumentos aparecem por script
- `Exists = 1` para `principal`, `praca_2` e `praca_3`

## Observacao

O `.ydr` visual aprovado nao foi alterado.

O YMAP deve ser recriado depois, com cuidado para nao sobrescrever `meninodaporteira.ytyp`.

## Nova ocorrencia em 2026-07-02

Apos a troca para a base mais atualizada, o resource voltou a carregar como YMAP:

- `fxmanifest.lua` voltou a ter `this_is_a_map 'yes'`
- `Config.UseScriptSpawn` voltou para `false`
- surgiu `stream/af_menino_porteira.ymap`

Para manter o servidor estavel, foi aplicado novamente o modo seguro:

- `Config.UseScriptSpawn = true`
- `this_is_a_map 'yes'` removido do manifest
- `stream/af_menino_porteira.ymap` movido para:

`C:\meu-server-gta\Base\resources\af_menino_porteira\_quarantine_corrompidos\reverted_ymap_20260702_131352`

O resource deve continuar por script ate recriarmos o YMAP com seguranca.
