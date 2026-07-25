# Relatorio - Concessionaria e Smartphone

## Concessionaria

Instalada em:

```text
Base/resources/[scripts]/nation_concessionaria
```

Foi adaptada para a base Creative/vRP atual:

- imagens carregam por `nui://nation_concessionaria/vrp_images/`;
- `/conce` abre o painel para Passaporte `1` ou grupo `Admin`;
- compra grava na tabela `vehicles`;
- venda remove da tabela `vehicles`;
- aluguel usa `vehicles/rentalVehicles`;
- tabela `nation_concessionaria` e criada automaticamente;
- estoque inicial e montado com veiculos que existem no `Vehicle.lua`;
- modelos `d7club8`, `1016urus` e `2f2fgtr34` entram no estoque se estiverem registrados.

## Veiculos

Atualizado:

```text
Base/resources/vrp/config/Vehicle.lua
```

Entradas adicionadas:

- `1016urus`
- `2f2fgtr34`

O importador tambem foi melhorado:

```text
C:/meu-server-gta/tools/importar_veiculo.ps1
```

Agora ele tenta cadastrar automaticamente o modelo importado no `Vehicle.lua`.

## Smartphone novo

Referencia analisada:

```text
C:/meu-server-gta/#referencias#/novo smartphone
```

Nao substitui o `lb-phone` atual ainda.

Motivos:

- o resource novo usa `server.js` grande/minificado;
- possui SQL proprio com muitas tabelas `smartphone_*`;
- depende de configuracao de upload local e webhook;
- precisa validar item do inventario, chamadas, fotos, contatos e banco antes de trocar o telefone atual.

Recomendacao segura:

1. Criar copia de teste em `[smartphone]/smartphone_novo_teste`.
2. Importar `smartphone.sql` em banco separado ou backupado.
3. Subir em servidor local isolado.
4. Testar abrir telefone, contatos, fotos, chamadas, Nubank, Blaze, Instagram e WhatsApp.
5. So depois desligar `lb-phone`.

## Teste rapido

No console do FXServer:

```text
refresh
ensure nation_concessionaria
restart vrp
```

No jogo:

```text
/conce
/vehpreview d7club8
/vehpreview 1016urus
/vehpreview 2f2fgtr34
```

Comprar um carro pela concessionaria e depois verificar na garagem.
