# Guia rapido - Menino da Porteira

O posicionamento atual esta por script, nao por YMAP ativo.

Arquivo principal:

`C:\meu-server-gta\Base\resources\af_menino_porteira\config.lua`

## Monumentos atuais

- `principal`: praca, perto de `241.975, -888.214, 29.492`
- `praca_2`: praca, perto de `189.369, -911.124, 30.693`
- `praca_3`: rodovia, perto de `-2132.704, -335.624, 13.012`

## Ver status no jogo

Use:

```text
/meninostatus
```

O F8 mostra id, posicao, heading, zOffset e handle.

## Mudar um monumento de lugar

1. Fique no local desejado.
2. Use um id novo ou o mesmo id temporariamente:

```text
/meninoadd nome_do_local
```

3. O F8 imprime uma entrada pronta para colar em `Config.Monuments`.
4. Cole no `config.lua`.
5. Reinicie:

```text
restart af_menino_porteira
```

## Ajustar rotacao

```text
/meninorot principal 195
/meninorot praca_2 324.11
/meninorot praca_3 313.97
```

Copie a entrada atualizada que aparecer no F8.

## Ajustar altura

```text
/meninoz principal -0.50
/meninoz praca_2 -1.20
/meninoz praca_3 -1.10
```

Use valores negativos para baixar e positivos para subir.

## Remover os dois da praca e manter so o da rodovia

No `config.lua`, deixe assim:

```lua
{
    id = "principal",
    enabled = false,
    position = vector3(241.975, -888.214, 29.492),
    heading = 195.00,
    zOffset = 0.000
},
{
    id = "praca_2",
    enabled = false,
    position = vector3(189.369, -911.124, 30.693),
    heading = 324.11,
    zOffset = -1.200
},
{
    id = "praca_3",
    enabled = true,
    position = vector3(-2132.704, -335.624, 13.012),
    heading = 313.97,
    zOffset = -1.100
},
```

Depois:

```text
restart af_menino_porteira
```

## Recriar sem reiniciar

```text
/meninoreload
```

## Limpar todos temporariamente

```text
/meninolimpar
```

Isso remove os props da sessao atual, mas eles voltam no restart se `enabled = true`.
