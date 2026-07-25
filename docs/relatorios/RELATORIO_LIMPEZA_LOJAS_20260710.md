# Relatorio - duplicacao da mercearia e botao Comprar

## Causa encontrada

Os manifests de `shops` e de outros resources usam curingas como
`client-side/*`, `server-side/*` e `shared-side/*`. Havia oito arquivos
`.bak_codex` dentro dessas pastas. O FiveM carregava os backups junto com os
scripts reais. Em `shops/shared-side`, isso executava a montagem de
`ItemList` duas vezes e fazia os produtos aparecerem duplicados.

## Correcao

- Os oito backups foram preservados em `Base/_codex_backups/resource_files/`.
- Nenhum `.bak_codex` permanece dentro de `Base/resources`.
- `of-shop-buy.js` continua sendo o unico controlador ativo do botao.
- O botao agora fica no `body`, alinhado ao campo de quantidade visivel.
- O estilo forca opacidade, visibilidade, foco e fundo para evitar o botao
  transparente herdado da NUI.
- O fluxo continua usando `shops/DirectBuy`; a confirmacao de compra fica no
  servidor e usa a confirmacao existente Y/U.

## Teste

```text
restart shops
restart inventory
```

Dentro do jogo, abra uma mercearia, confira se cada item aparece uma vez,
selecione um produto, informe a quantidade e clique em `Comprar`. A compra
deve pedir confirmacao por Y/U antes de gerar o item.

## Validacao tecnica

- `node --check resources/[scripts]/inventory/web-side/of-shop-buy.js`: OK
- `node --check resources/[scripts]/inventory/web-side/of-destroy.js`: OK
