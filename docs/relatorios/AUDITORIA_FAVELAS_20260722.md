# Auditoria seletiva - Favela Deus e Chapadao

Data: 2026-07-22

## Decisao

O pacote original `favelas_quebradashop` nao foi alterado e nao deve ser
iniciado. Somente Favela Deus e Chapadao foram extraidos para resources
privados e independentes.

O Chapadao nao foi ativado no `server.cfg` porque ocupa a mesma area do mapa
existente `resources/[maps]/mapPM/stream/dppolicia/apa_ch2_02.ymap`.

## Metodo

- Leitura binaria feita com `CodeWalker.Core.dll` da instalacao local.
- Todos os YMAPs dos dois mapas foram exportados para XML de auditoria.
- Archetypes foram comparados pelos hashes Jenkins dos nomes dos assets.
- YTYPs foram lidos para localizar modelo, textura e colisao associados.
- Os binarios copiados foram verificados por SHA-256 contra o pacote original.
- A interface do CodeWalker nao foi usada para edicao; a captura da janela
  falhou com `SetIsBorderRequired ... 0x80004002`.

## Pacote original

- Autor informado no manifest: Quebrada SHOP.
- Discord informado no manifest: `discord.gg/eVCFYSgJxy`.
- Licenca explicita de redistribuicao: nao encontrada.
- Arquivos: 4.929.
- Tamanho: 1.035.114.519 bytes (987,16 MiB).
- Resource original: nao ativar.

## Resultado seletivo

- Arquivos unicos: 450.
- Tamanho final unico: 142.397.471 bytes (135,80 MiB).
- Economia: 892.717.048 bytes (851,36 MiB).
- Reducao: 86,24%.
- Assets compartilhados: 66 arquivos, 43.074.057 bytes (41,08 MiB).
- Favela Deus exclusiva: 137 arquivos, 21.141.605 bytes (20,16 MiB).
- Chapadao exclusivo: 247 arquivos, 78.181.809 bytes (74,56 MiB).

## Favela Deus

- Resource: `resources/[maps]/of_favela_deus`.
- YMAP principal: `morrodoadeus.ymap`.
- YMAPs: 9.
- Entidades no mapa principal: 735.
- Referencias unicas: 435.
- Assets locais do pacote encontrados: 178 archetypes por modelo e 184 por
  definicao YTYP. As contagens se sobrepoem.
- Referencias sem asset local: 257, classificadas como nativas do GTA ou
  pendentes de confirmacao visual no jogo.
- Extents principais: X -3017,82 a -2834,10; Y 1321,81 a 1503,08.
- Centro medio das entidades: `-2921.48, 1419.13, 68.73`.
- Entrada sugerida da lista: `-2982.58, 1331.08, 38.03`.
- Confianca da coordenada: alta; o ponto esta dentro dos extents do mapa.
- MLOs detectados: nenhum `CMloInstanceDef`.
- Barbearia, bar, igreja, loja, mercadinho e padaria sao placements externos
  neste pacote, nao interiores MLO independentes.
- Maior asset exclusivo: `quebradafvqs.ytd`, 5.368.501 bytes.

## Chapadao

- Resource: `resources/[maps]/of_chapadao`.
- YMAP principal: `complexodochapadao.ymap`.
- YMAPs: 23.
- Entidades no mapa principal: 1.683.
- Referencias unicas: 707.
- Assets locais do pacote encontrados: 245 archetypes por modelo e 243 por
  definicao YTYP. As contagens se sobrepoem.
- Referencias sem asset local: 469, classificadas como nativas do GTA ou
  pendentes de confirmacao visual no jogo.
- Extents principais: X -565,70 a -195,89; Y 1438,23 a 1641,17.
- Centro medio das entidades: `-399.28, 1547.52, 367.45`.
- Entrada sugerida da lista: `-301.35, 1426.88, 339.49`.
- Confianca da coordenada: alta; o ponto fica junto ao limite de entrada.
- MLOs detectados: casa do Chapadao, espetinho e farm.
- Colisoes exclusivas selecionadas: 4 YBNs.
- Maior asset exclusivo: `favela_02_qs.ytd`, 10.773.034 bytes.
- Duplicidade resolvida: a versao local mais nova de
  `quebradashop_espetinho_ext.ydr` prevalece sobre a copia global.

## Shared

- Resource: `resources/[maps]/of_favelas_shared`.
- 52 YDRs.
- 7 YTDs.
- 7 YTYPs.
- Maior arquivo: `cs_8646_lod.ytd`, 9.479.761 bytes.
- O resource registra somente os YTYPs realmente selecionados.

## Conflitos

### Chapadao x mapa policial

O mapa existente abaixo possui 47 entidades dentro dos extents do Chapadao:

`resources/[maps]/mapPM/stream/dppolicia/apa_ch2_02.ymap`

O arquivo `apa_ch2_02_strm_3.ymap` do mesmo resource tambem possui entidades a
menos de 300 metros do centro. O proprio Chapadao inclui substituicoes
`apa_ch2_02_*`, portanto os dois conjuntos nao devem ser validados como se
fossem independentes.

Decisao necessaria: manter a delegacia nessa area ou usar o Chapadao. Nenhum
arquivo do mapa policial foi removido.

### Favela Deus

Nenhuma entidade de outro mapa foi encontrada dentro dos extents. Uma estrada
da Fazenda fica aproximadamente 282 metros do centro e deve ser observada no
teste visual, mas nao foi classificada como sobreposicao direta.

## Instalacao e teste

Os resources foram preparados, mas nao adicionados ao `server.cfg`.

Ordem futura, depois da decisao sobre o conflito:

```cfg
ensure of_favelas_shared
ensure of_favela_deus
ensure of_chapadao
```

Para usar os teleportes temporarios:

1. Alterar `Config.Debug = true` em `of_favelas_shared/config.lua`.
2. Reiniciar os resources.
3. Usar `/favela_test deus`, `/favela_test chapadao` ou
   `/favela_test coords` com o passaporte 1.
4. Voltar `Config.Debug = false` antes da producao.

## Validacoes pendentes no FiveM

- Texturas e archetypes sem asset local.
- Colisao de ruas, escadas, telhados e interiores.
- Rooms, portals, iluminacao e chuva nos tres MLOs do Chapadao.
- Warnings de streaming e archetypes duplicados no F8/console.
- Teste com dois jogadores e entrada tardia.
- Decisao visual sobre `mapPM/dppolicia`.

## Arquivos de auditoria

- `dependencies-deus.csv`
- `dependencies-chapadao.csv`
- `selected-files-deus.csv`
- `selected-files-chapadao.csv`
- `maps-deus.csv`
- `maps-chapadao.csv`
- XMLs temporarios dos YMAPs em `AUDITORIA_FAVELAS_20260722/xml`.

Os assets binarios estao ignorados no Git. Nao publicar sem confirmar os
termos do autor.

