# Diagnostico do Asset - Menino da Porteira

## Problema encontrado

O prop `meninodaporteira` carregava e spawnava corretamente, mas o material estava
com aparencia simples demais para o ambiente do GTA/FiveM.

Pontos encontrados:

- O `.ydr` atual estava em escala 3x e foi preservado.
- O material importado do `.ydr` usava `gta_default.sps`, apenas com diffuse.
- Nao havia `.ytd` no resource.
- O `.ytyp` ja apontava `textureDictionary` e `physicsDictionary` para
  `meninodaporteira`.
- O `.blend` fonte tinha material cinza generico e escala 1x, entao nao foi usado
  diretamente para o drawable final.

## Correcao aplicada

- O `.ydr` atual foi importado no Blender/Sollumz para preservar escala 3x.
- O material foi convertido para `normal_spec.sps`.
- Foram criadas e embutidas no `.ydr` tres texturas DDS:
  - `meninodaporteira_bronze_d`: diffuse bronze/dourado.
  - `meninodaporteira_bronze_n`: normal flat.
  - `meninodaporteira_bronze_s`: specular bronze.
- Foram garantidos `UVMap 0` e `Color 1`.
- Normals foram recalculadas para fora e foi aplicado weighted normals.
- Foi criado `meninodaporteira.ybn` com colisao box em escala 3x.

## Arquivos alterados

```text
stream/meninodaporteira.ydr
stream/meninodaporteira.ybn
```

O arquivo abaixo nao foi alterado:

```text
stream/meninodaporteira.ytyp
```

## Backups

Os arquivos antigos foram copiados para:

```text
tools/backups/
```

## Validacao feita

O `.ydr` final foi importado de volta no Blender/Sollumz e confirmou:

```text
dims = 12.0006, 2.823, 6.9641
shader = normal_spec.sps
uv = UVMap 0
color = Color 1
DiffuseSampler embedded = true
BumpSampler embedded = true
SpecSampler embedded = true
```

O `.ybn` final foi importado de volta e confirmou:

```text
collision dims = 12.0006, 2.823, 6.9641
physicsDictionary esperado = meninodaporteira
```

## Teste no FiveM

```text
restart af_menino_porteira
/meninostatus
```

Depois olhe o monumento em horarios diferentes do jogo, especialmente de dia e
com luz lateral. O material deve responder melhor a luz e especular do ambiente.

## CodeWalker/YMAP

Ainda nao foi criado YMAP. O script atual basta para posicionamento e teste visual.
Depois que o material for aprovado no FiveM, o monumento pode ser colocado via
CodeWalker/YMAP na posicao:

```text
x = 241.975
y = -888.214
z = 29.492
heading = 195.00
```
