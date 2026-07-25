# Auditoria Inicial - Roupas e Character Creator

Data: 2026-07-21

## Escopo desta fase

Esta fase mapeou o sistema atual e preparou compatibilidade por collections no
`skinshop` existente. Nenhuma interface paralela, command, creator alternativo
ou loja alternativa foi criada. Nenhum personagem, roupa salva, outfit,
inventario ou permissao foi migrado em massa.

## Resources encontrados

| Responsabilidade | Resource | Arquivos principais |
| --- | --- | --- |
| Selecao e spawn do personagem | `spawn` | `client-side/core.lua`, `server-side/core.lua` |
| Criador inicial e rosto/cabelo | `barbershop` | `client-side/core.lua`, `server-side/core.lua`, `shared-side/shared.lua` |
| Loja e componentes de roupa | `skinshop` | `client-side/core.lua`, `server-side/core.lua` |
| Outfits de armario | `propertys` | `client-side/core.lua`, `server-side/core.lua` |
| Aplicacao da aparencia no ped | `vrp` | `modules/player.lua` |
| Assets adicionais atuais | `clothes_addon` | `fxmanifest.lua`, `stream/` |

## Persistencia atual

- `playerdata/Clothings`: JSON por categoria, por exemplo
  `torso = { item = 273, texture = 0 }`.
- `playerdata/Barbershop`: vetor posicional de 56 valores para blend facial,
  olhos, cabelo, overlays e features do rosto.
- `playerdata/Tattooshop`: tatuagens.
- Armarios: snapshots de `Clothings` em `srv_data`, sob
  `Wardrobe:<propriedade>:<serial>`.

O spawn reaplica roupas, barbearia e tatuagens. O reload de personagem tambem
chama `skinshop:Apply`, `barbershop:Apply` e `tattooshop:Apply`.

## Limites encontrados

O `skinshop` ja consulta a quantidade real de drawables, texturas e props do
ped com as natives globais do GTA. Nao existe um maximo Lua fixo para as
categorias de roupa. O `barbershop` tambem consulta o total de cabelos do
componente 2 ao abrir a interface.

As interfaces NUI de `skinshop` e `barbershop` estao compiladas. O `skinshop`
ja recebe os limites reais do ped ao abrir, portanto nao recebeu uma segunda
interface nem valores artificiais. A validacao visual final precisa ser feita
no jogo com personagem masculino e feminino.

## Causa mais provavel da pouca variedade

O resource `clothes_addon` possui 1.443 arquivos `.ydd` e 11.291 `.ytd`, com
assets masculinos e femininos de diversas colecoes. Ele, entretanto, possui
somente um `.ymt`, da collection feminina `mp_f_roupasf`, e declara somente um
`SHOP_PED_APPAREL_META_FILE` feminino. O manifesto tambem declarava
`data/skins/*.meta`, mas essa pasta nao existe no resource.

Um `ShopPedApparel` com listas vazias pode ser valido para um add-on: o arquivo
registra a collection, enquanto os slots de roupa sao definidos pelo `.ymt`.
O problema real e que faltam os `.ymt` e metadatas correspondentes para as
demais collections representadas pelos assets. Aumentar numeros no menu seria
incorreto: poderia expor indices sem asset valido, roupa invisivel ou
combinacoes incompativeis.

O log de boot tambem registra 91 avisos no `clothes_addon`, incluindo texturas
de 64 MiB que podem causar problemas de streaming.

## Inventario de assets observado

Contagem de `.ydd` no pacote, antes de validar disponibilidade real no ped:

| Categoria | Masculino | Feminino |
| --- | ---: | ---: |
| Cabelo | 66 | 100 |
| Barba | 9 | 6 |
| Parte superior | 144 | 285 |
| Camiseta | 17 | 52 |
| Calca | 59 | 67 |
| Sapato | 46 | 59 |
| Acessorio | 34 | 142 |
| Bracos | 21 | 52 |
| Mascara | 19 | 21 |
| Chapeu | 23 | 10 |
| Oculos | 12 | 21 |

Esses numeros representam arquivos presentes, nao itens ja aprovados para
uso. A proxima medicao deve usar as collections e variacoes que o ped de fato
enxerga em jogo.

## Seguranca e compatibilidade

O `skinshop` passou a aceitar e salvar, de forma aditiva, o par opcional
`collection` e `drawable`. Ao carregar, tenta primeiro a collection/local
drawable e recua para os indices globais antigos quando a collection nao esta
disponivel. O servidor limita o payload aos slots conhecidos e tipos esperados
antes de gravar no banco. `Barbershop` nao foi alterado nesta etapa porque ja
consulta os cabelos dinamicamente e sua NUI compilada nao deve ser substituida
sem necessidade.

Isso mantem `Clothings` e os snapshots de armario existentes validos:

A migracao recomendada e aditiva:

```lua
torso = {
  item = 273,       -- fallback global legado
  texture = 0,
  collection = "of_city_male",
  drawable = 4
}
```

O carregador primeiro tenta a collection; se ela nao existir ou o pack estiver
desligado, usa o `item` global legado. A informacao de collection e preservada
quando o jogador muda outra peca pela NUI antiga. Nenhum dado existente precisa
ser reescrito em massa.

## Alteracoes concluidas

- Backup completo criado em
  `_codex_backups/clothes_addon_backup_20260721` (12.739 arquivos, cerca de
  3,13 GiB).
- Removida do manifesto de `clothes_addon` a referencia para
  `data/skins/*.meta`, que nao existia.
- `skinshop` existente preparado para aplicar e persistir collections de forma
  retrocompativel.
- Nenhum resource de auditoria continua carregavel; a pasta remanescente esta
  vazia e nao possui `fxmanifest.lua`.

## Collections e proxima fase

FiveM oferece natives client-side para enumerar collections, converter indice
global/local e aplicar componentes ou props por collection. Essa e a estrategia
correta para packs futuros, porque indices locais de uma collection permanecem
estaveis quando o GTA recebe novas DLCs.

O pack futuro deve ficar separado em:

```text
resources/[clothes]/of_clothing_pack
```

Com collections exclusivas, por exemplo `of_city_male`, `of_city_female`,
`of_witch_male` e `of_witch_female`. A Colecao Arcana deve ser validada no
servidor pela permissao `Bruxo` ao equipar, salvar e carregar.

## Arquivos previstos para uma migracao posterior

- `resources/[scripts]/skinshop/client-side/core.lua`
- `resources/[scripts]/skinshop/server-side/core.lua`
- `resources/[scripts]/barbershop/client-side/core.lua`
- `resources/[scripts]/barbershop/server-side/core.lua`
- novo resource `resources/[clothes]/of_clothing_pack`

As NUIs compiladas nao serao alteradas ate que a auditoria em jogo confirme as
categorias que elas ja suportam e se o fonte original esta disponivel.

## Proximos testes

1. Executar os comandos de auditoria com ped masculino e feminino.
2. Registrar collections reais, contagens por categoria e look atual.
3. Confirmar o que a NUI esconde apesar das variacoes disponiveis.
4. Validar um pack pequeno e autorizado em collection propria.
5. So entao adicionar persistencia por collection com fallback legado.
