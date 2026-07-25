# Auditoria complementar do crafting de Sao Judas

## Resource e fluxo legado

- Resource: `resources/[scripts]/crafting`.
- Interface: inventario NUI existente, aberto como `Type = Shops` e
  `Mode = Buy`.
- Callback de producao: `Take` no client do crafting.
- Autoridade atual: `Lil.Take` no server do crafting.
- Ingredientes: consultados por `vRP.ConsultItem` e removidos por
  `vRP.RemoveItem`.
- Resultado: entregue por `vRP.GenerateItem`.
- Peso: validado por `vRP.CheckWeight`.
- Limite de item: validado por `vRP.MaxItens`.
- Quantidade: convertida com `parseInt`, sem limite por receita.
- Duracao, animacao, progressbar, sessao, log e rate limit: inexistentes no
  fluxo legado.

## Modo Lester

- Local: `vec3(1272.51,-1713.05,54.63)`.
- Permissao: `Lester` em servico.
- Categoria: uma lista unica com ferramentas, municoes e outros produtos.

Receitas ilegais originais:

| Produto | Saida | Ingredientes | Duracao | Lote |
|---|---:|---|---|---|
| `lockpick` | 1 | `copper` 30, `aluminum` 30, `sheetmetal` 2 | instantanea | sem limite proprio |
| `blocksignal` | 1 | `plastic` 80 | instantanea | sem limite proprio |
| `dismantle` | 1 | `plastic` 25, `dirtydollar` 975 | instantanea | sem limite proprio |

Nao ha dependencia direta conhecida desses tres indices com o nome do modo
`Lester`; o inventario recebe a lista do modo aberto. A migracao pode manter as
definicoes centralizadas e ocultar os tres produtos no Lester quando a
exclusividade estiver ativa.

## Finalidade de dismantle

`dismantle` e o item `Cartao Ilegivel`, peso zero. Ao ser usado, chama
`vCLIENT.Dismantle`; quando a rota e aceita, uma unidade e consumida. O item
nao possui limite maximo nativo. A bancada de Sao Judas deve limitar o lote e
registrar a producao.

A receita original usa `dirtydollar` 975. Este valor sera preservado como
ingrediente legado para cumprir a regra de nao alterar silenciosamente a
receita. Nenhuma taxa financeira adicional sera cobrada pelo crafting.

## Materiais reais para receitas novas

- `lockpick`: Gazua, peso 1.25, durabilidade 72, economia 725.
- `lockpickplus`: Gazua ++, peso 1.25, durabilidade 720, economia 50000.
- `WEAPON_CROWBAR`: Pe de Cabra, peso 1.35, durabilidade 240, economia 975.
- `copper`: Cobre, peso 0.045, economia 10.
- `aluminum`: Aluminio, peso 0.045, economia 10.
- `sheetmetal`: Chapa de Metal, peso 0.65, economia 65.
- `metalspring`: Mola de Metal, peso 0.35, economia 425.
- `electroniccomponents`: Componentes Eletronicos, peso 0.35, economia 375.

## Receitas propostas

Gazua ++, uma unidade, lote maximo 1:

- `lockpick` 5;
- `copper` 100;
- `aluminum` 100;
- `sheetmetal` 10;
- `metalspring` 2;
- `electroniccomponents` 4.

Pe de Cabra, uma unidade, lote maximo 1:

- `sheetmetal` 4;
- `aluminum` 20;
- `metalspring` 1.

As duas receitas usam somente indices confirmados no catalogo da base.
