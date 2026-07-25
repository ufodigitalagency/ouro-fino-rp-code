# Ajustes Ouro Fino - teclas, blips, hospital, veiculo e celular

Data: 2026-07-02

## O que foi ajustado

- F1 agora executa `GuiCrossArms` para cruzar os bracos.
- F10 agora executa `GuiHandsHead` para colocar as maos na cabeca.
- F9 continua abrindo o menu principal e, para o passaporte/ID 1, mostra o menu `Administrativo > Painel Ouro Fino`.
- O painel tambem pode ser aberto por `/ofadmin`.
- Blips de bancos foram mantidos nos pontos do resource `bank`.
- Blips de mercearia foram expandidos para todos os pontos usados pelo resource `shops`.
- O blip do hospital foi apontado para o SAMU/HPSAMU.
- O mapa HPSAMU foi instalado como resource `af_hpsamu`.
- O veiculo addon `d7club8` foi instalado como resource `d7club8`.
- O modelo `d7club8` foi cadastrado no `vrp/config/Vehicle.lua` como `D7 Club 8S`.

## Arquivos principais alterados

- `server.cfg`
- `resources/vrp/client/gui.lua`
- `resources/vrp/config/Vehicle.lua`
- `resources/[scripts]/dynamic/client-side/core.lua`
- `resources/af_owner_panel/server.lua`
- `resources/af_map_blips/client.lua`
- `resources/af_hpsamu/fxmanifest.lua`
- `resources/d7club8/fxmanifest.lua`
- `resources/d7club8/vehicle_names.lua`

## Backups

Backups pontuais foram salvos em:

`Base/_codex_backups/20260702_203110`

## Como testar no jogo

1. Entrar no servidor.
2. Pressionar `F1`: o personagem deve cruzar os bracos.
3. Pressionar `F10`: o personagem deve colocar as maos na cabeca.
4. Pressionar `F9`: abrir menu principal.
5. No F9, se estiver no ID/passaporte 1, abrir `Administrativo > Painel Ouro Fino`.
6. No mapa, conferir blips de `Banco`, `Mercearia` e `Hospital SAMU`.
7. Como admin, testar o carro com:

```text
/car d7club8
```

Observacao: se F1/F10 nao reagirem de primeira, abra as configuracoes de teclas do FiveM/GTA e restaure/remova binds antigos. O FiveM pode manter keybinds antigos no perfil local mesmo depois do resource mudar o default.

## Hospital HPSAMU

O hospital foi copiado de:

`C:/meu-server-gta/#referencias#/HPSAMU/HPSAMU`

Para:

`Base/resources/af_hpsamu`

O `fxmanifest.lua` do resource carrega:

- `interiorproxies.meta`
- `stream/logohp_high.ytyp`
- `stream/logosamu.ytyp`
- `stream/shmann_ehos_props.ytyp`
- `stream/shmann_ehos_props2.ytyp`

O resource esta ligado no `server.cfg` com:

```text
ensure af_hpsamu
```

## Veiculo d7club8

O veiculo foi copiado de:

`C:/meu-server-gta/#referencias#/d7club8`

Para:

`Base/resources/d7club8`

Spawn/modelo:

```text
d7club8
```

Teste admin:

```text
/car d7club8
```

## Celular: decisao tecnica

Foi avaliado o `qb-phone` em `#referencias#/[qb]/qb-phone`, mas ele depende de `qb-core`, `qb-banking`, `qb-crypto`, `qb-garages`, `qb-policejob`, `screenshot-basic` e outros resources QB. Como esta base esta rodando em vRP, trocar direto para `qb-phone` agora teria alto risco de quebrar banco, inventario, jobs e permissao.

O caminho seguro neste momento e manter o `lb-phone`, que ja esta adaptado ao vRP/standalone nesta base.

Foi confirmado no banco `vrp` que as tabelas `phone_*` existem, incluindo:

- `phone_phones`
- `phone_phone_contacts`
- `phone_photos`
- `phone_photo_albums`
- `phone_instagram_*`
- `phone_twitter_*`
- `phone_wallet_transactions`
- `phone_crypto`

Se contatos ou fotos nao salvarem, o problema mais provavel nao e falta de tabela. Priorizar:

1. Verificar se o jogador tem item `cellphone`.
2. Verificar se o telefone recebeu numero em `phone_phones`.
3. Verificar erro no F8/console ao salvar contato/foto.
4. Verificar se a API de upload esta valida.

## Passo a passo: fotos do celular e Discord

O `lb-phone` usa upload por API para armazenar a imagem/video e pode registrar logs em Discord. O local correto para configurar chaves e webhooks e:

`Base/resources/[smartphone]/lb-phone/server/apiKeys.lua`

Nao compartilhe esse arquivo publicamente.

### Opcao recomendada: Fivemanage

1. Criar conta no Fivemanage.
2. Criar API key para upload de imagem/video/audio.
3. Abrir:

```text
Base/resources/[smartphone]/lb-phone/server/apiKeys.lua
```

4. Preencher:

```lua
API_KEYS = {
    Video = "SUA_API_KEY",
    Image = "SUA_API_KEY",
    Audio = "SUA_API_KEY",
}
```

5. Confirmar em:

```text
Base/resources/[smartphone]/lb-phone/config/config.lua
```

Que esteja assim:

```lua
Config.UploadMethod.Video = "Fivemanage"
Config.UploadMethod.Image = "Fivemanage"
Config.UploadMethod.Audio = "Fivemanage"
```

6. Reiniciar:

```text
restart lb-phone
```

7. Tirar uma foto pelo celular.
8. Conferir se entrou registro em `phone_photos`.

### Opcao Discord como log das fotos

1. Criar um canal no Discord para uploads.
2. Ir em `Editar canal > Integracoes > Webhooks > Novo webhook`.
3. Copiar a URL.
4. Em `server/apiKeys.lua`, preencher somente com a URL do seu canal:

```lua
LOGS = {
    Default = false,
    Uploads = "SUA_URL_WEBHOOK_DISCORD"
}
```

5. Em `config/config.lua`, ativar logs se quiser que uploads gerem mensagem no Discord:

```lua
Config.Logs.Enabled = true
Config.Logs.Service = "discord"
Config.Logs.Actions.Uploads = true
```

Importante: o webhook do Discord e bom para auditoria/log. Para armazenamento estavel da imagem dentro do celular, mantenha Fivemanage ou LBUpload como upload principal.

## Validacao feita

- FXServer reiniciado.
- Endpoint `http://127.0.0.1:30120/info.json` respondeu HTTP 200.
- Resources `af_hpsamu`, `d7club8`, `af_owner_panel`, `af_map_blips`, `lb-phone` e resources customizados iniciaram.
- O warning antigo de `vehiclelayouts.meta` do `d7club8` foi removido do manifest.

## Pendencias recomendadas

- Testar F1/F10 dentro do jogo depois de limpar keybind antigo se necessario.
- Testar `/car d7club8`.
- Entrar no hospital e verificar colisao/interior.
- Tirar foto pelo celular e verificar console/F8 se a API de upload retornar erro.
- Se quiser visual "Nubank" e "Blaze", criar apps customizados no `lb-phone` ou atalhos NUI; nao misturar QB dentro da base vRP sem uma migracao planejada.
