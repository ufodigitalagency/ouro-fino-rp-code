# Dados de Receitas de Drogas — São Judas

**Data:** 2026-07-25
**Fonte:** `resources/[scripts]/crafting/shared-side/shared.lua` (linhas 812-890)

---

## Receitas Aprovadas (Fase 1)

### Processamento (Matéria-Prima → Unidade)

| Receita | Produto | Qtd | Ingrediente 1 | Qtd 1 | Ingrediente 2 | Qtd 2 | Tempo | Permissão | Local |
|---|---|---:|---|---:|---|---:|---|---|---|
| joint | joint | 1 | weed | 1 | — | — | Instantâneo | Nenhuma | drugs_bench |
| cocaine | cocaine | 1 | coke | 1 | — | — | Instantâneo | Nenhuma | drugs_bench |
| meth | meth | **5** | saline | 1 | sulfuric | 1 | Instantâneo | Nenhuma | drugs_bench |

### Embalagem (Unidade → Pacote)

| Receita | Produto | Qtd | Ingrediente | Qtd | Tempo | Permissão | Local |
|---|---|---:|---|---:|---|---|---|
| weedsack | weedsack | 1 | joint | 10 | Instantâneo | Nenhuma | drugs_bench |
| cokesack | cokesack | 1 | cocaine | 10 | Instantâneo | Nenhuma | drugs_bench |
| methsack | methsack | 1 | meth | 10 | Instantâneo | Nenhuma | drugs_bench |

---

## Receitas Não Aprovadas (Fase 1)

| Receita | Produto | Qtd | Ingredientes | Tempo | Permissão |
|---|---|---:|---|---|---|
| crack | crack | 1 | cocaine ×10, acetone ×2 | Instantâneo | Nenhuma |
| heroin | heroin | 1 | meth ×7, saline ×2, alcohol ×2, sulfuric ×2 | Instantâneo | Nenhuma |
| metadone | metadone | 1 | analgesic ×1, sulfuric ×2, alcohol ×2 | Instantâneo | Nenhuma |
| codeine | codeine | 1 | analgesic ×1, sulfuric ×2, alcohol ×2 | Instantâneo | Nenhuma |
| amphetamine | amphetamine | 1 | meth ×6, cocaine ×6 | Instantâneo | Nenhuma |

---

## Ingredientes de Drogas

| Índice | Nome | Fonte jogável | Chance | Qtd | Consumido por | Diagnóstico |
|---|---|---|---|---|---|---|
| weed | Maconha | Plantação (weedclone_0) | — | Variável | joint | GARGALO (clone 5% chance) |
| coke | Coca | Plantação (cokeclone_0) | — | Variável | cocaine | GARGALO (clone 5% chance) |
| saline | Solução Salina | IlegalItens | 50% | 1-3 | meth, heroin, medkit, analgesic | Equilibrado |
| sulfuric | Ácido Sulfúrico | IlegalItens | 50% | 1-3 | meth, heroin, metadone, codeine | Equilibrado |
| acetone | Acetona | IlegalItens | 50% | 1-3 | crack, medkit | Equilibrado |
| alcohol | Álcool | IlegalItens | 50% | 1-3 | heroin, metadone, codeine | Equilibrado |
| analgesic | Analgésico | IlegalItens | 100% | 2-3 | metadone, codeine | Abundante |
| weedclone_0 | Clone Maconha | IlegalItens | 5% | 1 | Plantação → weed | Raro |
| cokeclone_0 | Clone Coca | IlegalItens | 5% | 1 | Plantação → coke | Raro |

---

## Preços de Venda NPC (sao_judas_street_sales)

| Item | Preço Mín | Preço Máx | Qtd Mín | Qtd Máx | Moeda |
|---|---:|---:|---:|---:|---|
| joint | 75 | 100 | 1 | 3 | dirtydollar |
| cocaine | 75 | 100 | 1 | 3 | dirtydollar |
| meth | 75 | 100 | 1 | 3 | dirtydollar |
| weedsack | 500 | 625 | 1 | 1 | dirtydollar |
| cokesack | 500 | 625 | 1 | 1 | dirtydollar |
| methsack | 500 | 625 | 1 | 1 | dirtydollar |

### Divisão de Receita
- Trabalhador: 85%
- Cofre de São Judas: 15%

---

## Economia — Custo vs Receita

### Cadeia completa: matéria-prima → unidade → venda NPC

| Cadeia | Custo | Produz | Receita bruta | Trabalhador (85%) | Cofre (15%) |
|---|---|---:|---|---|---|
| 1 weed → 1 joint → venda | 1 weed | 1 | 75-100 dd | 64-85 dd | 11-15 dd |
| 1 coke → 1 cocaine → venda | 1 coke | 1 | 75-100 dd | 64-85 dd | 11-15 dd |
| 1 saline + 1 sulfuric → 5 meth → venda (×5) | 2 itens | 5 | 375-500 dd | 319-425 dd | 56-75 dd |

### Cadeia completa: matéria-prima → unidade → pacote → venda NPC

| Cadeia | Custo | Produz | Receita bruta | vs unidades separadas |
|---|---|---:|---|---|
| 10 weed → 10 joint → 1 weedsack → venda | 10 weed | 1 | 500-625 dd | PIOR (750-1000 dd separadas) |
| 10 coke → 10 cocaine → 1 cokesack → venda | 10 coke | 1 | 500-625 dd | PIOR (750-1000 dd separadas) |
| 2 saline + 2 sulfuric → 10 meth → 1 methsack → venda | 4 itens | 1 | 500-625 dd | PIOR (750-1000 dd separadas) |

### ⚠️ Alerta
Pacotes são **economicamente inferiores** às unidades vendidas individualmente. A diferença é que pacotes são vendidos em 1 transação vs múltiplas.

---

## Efeitos ao Usar Drogas

| Droga | Efeito visual | Duração | Efeito mecânico |
|---|---|---|---|
| joint | DeathFailMPIn | 30s (acumula) | Nenhum |
| cocaine | MinigameTransitionIn | 30s (acumula) | Nenhum |
| meth | Dont_tazeme_bro | 30s (acumula) | Nenhum |
| crack | HeistCelebPassBW | 600s fixo | Sacia fome+sede 90s → penaliza 180s |
| heroin | DrugsMichaelAliensFight | 900s fixo | +50 HP máximo (250 total) |
| metadone | DeathFailMPDark | 600s | +10% dano arma/melee |
| codeine | — | — | Sem handler no client (possível bug) |
| amphetamine | — | — | Sem handler no client (possível bug) |

---

## Futura Permissão — Conceitual

```
ID: SaoJudasLaboratorio
Label: Operador de Laboratório
TagName: Operador de Laboratório

Regra:
  IsMember(Passport, "SaoJudas")
  AND (IsLeader(Passport) OR currentRole(Passport) == "Operador de Laboratório")

Arquivos necessários:
  - sao_judas_operations/config.lua → adicionar LaboratoryRole
  - sao_judas_operations/server.lua → adicionar CanUseLaboratory()
  - Painel F9 → adicionar tag (painel/shared-side/shared.lua)
  - Tabela DB → painel_creative_tags (já existente)
```

---

## Futura Desativação Seletiva

Para `ExclusiveSaoJudasLaboratory = true`, seria necessário:

1. Remover receitas de drogas da tabela `List.drugs_bench.List` no crafting/shared-side/shared.lua
2. **NÃO** remover o item `drugs_bench` do inventário (quebraria inventários existentes)
3. **NÃO** remover efeitos das drogas (client-side/drugs.lua)
4. **NÃO** alterar imagens, nomes ou Economy dos itens
5. Manter o sistema de venda NPC intacto
6. Manter as rotas que dão drogas prontas como loot
