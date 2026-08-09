# af_menino_porteira

Resource que posiciona o monumento `meninodaporteira` no mapa GTA V usando
**spawn por script**.

> Estado seguro atual: YMAP esta desativado. Nao reative `this_is_a_map 'yes'`
> nem coloque `.ymap` em `stream/` ate recriarmos o mapa com seguranca.

## Status atual

| Item | Valor |
|---|---|
| Modo | **Script spawn** |
| `Config.UseScriptSpawn` | `true` |
| `this_is_a_map` | desativado |
| Monumentos | 3 (principal, praca_2, praca_3) |
| Script spawn | Ligado |

## Instalar

No cfg que carrega seus resources:

```cfg
ensure af_menino_porteira
```

Reinicie:

```text
restart af_menino_porteira
```

Os 3 monumentos aparecem automaticamente no mapa via script.

## Estrutura

```text
af_menino_porteira/
|-- fxmanifest.lua
|-- config.lua
|-- client.lua              (comandos de debug)
|-- server.lua
|-- README.md
`-- stream/
    |-- meninodaporteira.ydr      (modelo 3D - NAO ALTERAR)
    `-- meninodaporteira.ytyp     (archetype - NAO ALTERAR)
```

## Posicoes dos monumentos

| ID | X | Y | Z | Heading |
|---|---|---|---|---|
| principal | 241.975 | -888.214 | 29.492 | 195.00 |
| praca_2 | 189.369 | -911.124 | 29.493 | 324.11 |
| praca_3 | -2132.704 | -335.624 | 11.912 | 313.97 |

> **Nota:** No modo script, o Z final usa `position.z + zOffset`.

## Configuracao

### Modo Script (atual)

Estado seguro:

1. Em `config.lua`:
   ```lua
   Config.UseScriptSpawn = true
   ```

2. Em `fxmanifest.lua`, mantenha sem:
   ```lua
   -- this_is_a_map 'yes'
   ```

3. Mantenha qualquer `.ymap` fora de `stream/`.

4. Reinicie:
   ```text
   restart af_menino_porteira
   ```

> **IMPORTANTE:** Nao deixe YMAP e script spawn ativos ao mesmo tempo.
> Isso duplica os objetos no mapa.

## Comandos de debug

Todos os comandos continuam funcionando para inspecao e testes:

| Comando | Descricao |
|---|---|
| `/meninostatus` | Mostra UseScriptSpawn, modelo, ids e handles |
| `/meninosalvar` | Imprime Config.Monuments no F8 |
| `/meninolimpar` | Remove monumentos spawnados por script |
| `/meninoadd id` | Cria monumento temporario via script |
| `/meninoreload` | Recria monumentos via script |
| `/meninoz id val` | Ajusta zOffset |
| `/meninorot id graus` | Ajusta heading |
| `/meninomodel` | Diagnostica modelo |
| `/testmenino` | Spawna via script (compatibilidade) |
| `/delmenino` | Remove via script (compatibilidade) |

## Como editar posicoes no YMAP

O YMAP esta temporariamente desativado por seguranca. Para editar posicoes agora,
use os comandos de script e salve os valores em `Config.Monuments`.

Quando recriarmos o YMAP:

1. Abra o `.ymap` novo em um editor de texto.
2. Altere os valores de `<position>` e `<rotation>` do `<Item>` desejado.
3. Recalcule os extents se as posicoes mudaram significativamente.
4. Reinicie o resource.

Para converter heading em quaternion (rotacao Z):
```
w = cos(heading * pi / 360)
z = -sin(heading * pi / 360)
x = 0, y = 0
```

## Notas tecnicas

- O `.ytyp` define o archetype e deve estar sempre carregado via `DLC_ITYP_REQUEST`.
- O `.ymap` so deve voltar para `stream/` quando estiver validado no CodeWalker.
- Flags `32` = entidade estatica (sem fisica dinamica).
- `LODTYPES_DEPTH_ORPHANHD` = sem hierarquia LOD, renderiza sempre em HD.
- `PRI_REQUIRED` = prioridade maxima de streaming.
- `lodDist 500` = distancia de renderizacao (herdada do archetype).
- Sem vRP, banco de dados ou dependencias externas.
