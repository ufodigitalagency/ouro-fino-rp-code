# Auditoria Completa — Sistema de Produção de Drogas — São Judas

**Data:** 2026-07-25
**Branch:** audit/sao-judas-drug-lab
**Commit base:** d3aab43a66f571c347c290a1a8324c89265aa1ce
**Autor:** Auditoria automatizada

---

## 1. Resumo Executivo

O sistema antigo de fabricação de drogas existe dentro do resource **crafting** (shared-side/shared.lua) sob a categoria `drugs_bench`. É um item posicionável (bancada física `bkr_prop_weed_table_01b`) que qualquer jogador com o item `drugs_bench` no inventário pode colocar no mundo. **Não possui restrição de permissão por grupo ou facção** — qualquer jogador que possua o item pode fabricar drogas.

O sistema legado de **venda para NPCs** dentro do `inventory/server-side/drugs.lua` está **desabilitado** (`LegacyStreetSalesDisabled = true`), substituído pelo `sao_judas_street_sales`.

A bancada segura de São Judas (`SaoJudas` em crafting) já utiliza arquitetura transacional com persistência em banco, reserva de materiais, affected rows, e máquina de estados. **A recomendação é migrar as receitas de drogas para esta arquitetura.**

---

## 2. Sistema Antigo Encontrado

### Resource: `crafting`
- **Caminho:** `resources/[scripts]/crafting/`
- **Status no server.cfg:** Ativo (carregado via `[scripts]`)
- **Função:** Sistema unificado de crafting para todas as bancadas
- **Categoria relevante:** `drugs_bench` (linhas 812-890 do shared.lua)

### Resource: `inventory`
- **Caminho:** `resources/[scripts]/inventory/`
- **Arquivos relevantes:**
  - `server-side/drugs.lua` — venda legada para NPCs (DESABILITADA)
  - `server-side/itens.lua` — handler do item `drugs_bench` (posicionamento)
  - `client-side/drugs.lua` — efeitos visuais ao usar drogas
  - `shared-side/shared.lua` — tabela `IlegalItens` (loot de rotas)

### Resource: `plants`
- **Caminho:** `resources/[scripts]/plants/`
- **Função:** Sistema de plantação (weed/coke via clones)
- **Itens:** `weedclone_0`, `cokeclone_0` (disponíveis em IlegalItens)

### Resource: `sao_judas_operations`
- **Caminho:** `resources/[scripts]/sao_judas_operations/`
- **Função:** Cofre financeiro, bancada segura, permissões de São Judas

### Resource: `sao_judas_street_sales`
- **Caminho:** `resources/[scripts]/sao_judas_street_sales/`
- **Função:** Venda de drogas para NPCs (sistema ativo)

### Resource: `of_aviao_sao_judas`
- **Caminho:** `resources/[scripts]/of_aviao_sao_judas/`
- **Função:** Trabalho de entrega (aviãozinho) — paga dirtydollar

---

## 3. Resources Envolvidos

| Resource | Caminho | Ativo | Função | Legado |
|---|---|---|---|---|
| crafting | `[scripts]/crafting/` | Sim | Bancadas de crafting | Parcial (drugs_bench) |
| inventory | `[scripts]/inventory/` | Sim | Inventário, itens, efeitos | Venda legada desabilitada |
| plants | `[scripts]/plants/` | Sim | Plantação weed/coke | Não |
| sao_judas_operations | `[scripts]/sao_judas_operations/` | Sim | Bancada segura + cofre | Não |
| sao_judas_street_sales | `[scripts]/sao_judas_street_sales/` | Sim | Venda NPC | Não |
| of_aviao_sao_judas | `[scripts]/of_aviao_sao_judas/` | Sim | Entregas | Não |

---

## 4. Itens de Droga — Aprovados (Fase 1)

### Unidades

| Item | Receita drugs_bench | Ingredientes | Qtd produzida | Venda NPC (street_sales) | Preço NPC |
|---|---|---|---|---|---|
| joint | 1 weed → 1 joint | weed ×1 | 1 | Sim | 75–100 dd |
| cocaine | 1 coke → 1 cocaine | coke ×1 | 1 | Sim | 75–100 dd |
| meth | 1 saline + 1 sulfuric → 5 meth | saline ×1, sulfuric ×1 | 5 | Sim | 75–100 dd |

### Pacotes

| Item | Receita drugs_bench | Ingredientes | Qtd produzida | Venda NPC | Preço NPC |
|---|---|---|---|---|---|
| weedsack | 10 joint → 1 weedsack | joint ×10 | 1 | Sim | 500–625 dd |
| cokesack | 10 cocaine → 1 cokesack | cocaine ×10 | 1 | Sim | 500–625 dd |
| methsack | 10 meth → 1 methsack | meth ×10 | 1 | Sim | 500–625 dd |

**Confirmação:** A proporção de embalagem é **10:1** para todos os três tipos.

---

## 5. Drogas Não Aprovadas (Fase 1)

| Item | Existe | Ingredientes | Efeito | Risco |
|---|---|---|---|---|
| crack | Sim | cocaine ×10, acetone ×2 | Visual BW 5min, sacia fome/sede | Alto custo (10 cocaine) |
| heroin | Sim | meth ×7, saline ×2, alcohol ×2, sulfuric ×2 | +50 HP max por 15min | Muito caro |
| metadone | Sim | analgesic ×1, sulfuric ×2, alcohol ×2 | +10% dano arma/melee 10min | Moderado |
| codeine | Sim | analgesic ×1, sulfuric ×2, alcohol ×2 | Mesma receita da metadone | Duplicação |
| amphetamine | Sim | meth ×6, cocaine ×6 | Visual aliens 30s | Extremamente caro |

**Observação:** `codeine` e `metadone` possuem receitas idênticas — possível erro de design.

---

## 6. Processamento e Embalagem

### Cadeia confirmada pelo código:

```
PROCESSAMENTO (matéria-prima → unidade):
  weed ×1    → joint ×1
  coke ×1    → cocaine ×1
  saline ×1 + sulfuric ×1 → meth ×5

EMBALAGEM (unidade → pacote):
  joint ×10    → weedsack ×1
  cocaine ×10  → cokesack ×1
  meth ×10     → methsack ×1
```

**Desempacotamento:** NÃO EXISTE. Não há receita reversa (pacote → unidades).

---

## 7. Ingredientes

| Ingrediente | Fonte jogável | Abundância | Consumidores |
|---|---|---|---|
| **weed** | Plantação (plants + weedclone_0) | Depende de clone | joint |
| **coke** | Plantação (plants + cokeclone_0) | Depende de clone | cocaine |
| **saline** | IlegalItens 50% (1-3), rotas ilegais | Equilibrado | meth, heroin, medkit |
| **sulfuric** | IlegalItens 50% (1-3), rotas ilegais | Equilibrado | meth, heroin, metadone, codeine |
| **acetone** | IlegalItens 50% (1-3) | Equilibrado | crack, medkit |
| **alcohol** | IlegalItens 50% (1-3) | Equilibrado | heroin, metadone, codeine |
| **analgesic** | IlegalItens 100% (2-3), crafting (fabric ×5 + saline ×1) | Abundante | metadone, codeine |
| **weedclone_0** | IlegalItens 5% (1) | Raro | Plantação |
| **cokeclone_0** | IlegalItens 5% (1) | Raro | Plantação |

### Fontes de IlegalItens
A tabela `IlegalItens` é usada como loot de **rotas ilegais** (containers, assaltos, etc.). As drogas prontas (joint, cocaine, meth, crack, heroin, etc.) também aparecem diretamente como loot com 60-100% de chance.

---

## 8. Localizações Antigas

O `drugs_bench` é um **item posicionável** — não possui localização fixa. O jogador coloca a bancada onde quiser (exceto interiores). A bancada usa prop `bkr_prop_weed_table_01b` e o modo `Craftings`.

**Bancadas fixas de crafting:**

| Coordenada | Modo | Uso |
|---|---|---|
| vec3(1272.51,-1713.05,54.63) | Lester | Armas, munição, acessórios |
| vec3(-345.63,-124.74,38.95) | Mecanico | Peças mecânicas |
| vec3(1110.8,-2008.75,31.43) | Furnace | Materiais base |
| vec3(-480.57,1614.74,369.49) | **SaoJudas** | Ferramentas ilegais (bancada segura) |

**Futura bancada do laboratório:** `vec3(-482.9467,1613.3351,369.3726)` — está dentro do mapa de São Judas, a ~2.7m da bancada de ferramentas atual.

---

## 9. Permissões

### drugs_bench (sistema antigo)
- **Permissão:** NENHUMA — qualquer jogador com o item pode usar
- **Restrição:** Apenas precisa possuir o item `drugs_bench` no inventário
- **Fabricação de unidades:** Sem restrição
- **Fabricação de pacotes:** Sem restrição
- **Drogas avançadas:** Sem restrição

### SaoJudas (bancada segura)
- **Permissão:** `SaoJudas` (grupo canônico)
- **Verificação:** `exports.sao_judas_operations:CanUseWorkbench(Passport)`
- **Roles:** Líder OU "Operador de Fabricação"
- **Verificação de distância:** server-side via `AtWorkbench()`

---

## 10. Interface e Experiência

### drugs_bench (sistema antigo)
- **Interface:** NUI do crafting padrão
- **Abertura:** Target no objeto posicionado → Mode "Craftings"
- **Seleção:** Lista de receitas na UI
- **Fabricação:** Clique → materiais removidos → produto entregue INSTANTANEAMENTE
- **Cancelamento:** Não possui tempo de fabricação
- **Animação:** Não possui para drugs_bench especificamente
- **Progressbar:** Não possui
- **Fila:** Não possui

### SaoJudas (bancada segura)
- **Interface:** NUI do crafting com extensões
- **Fabricação:** Timed (Duration por receita × quantidade)
- **Animação:** `anim@amb@clubhouse@tutorial@bkr_tut_ig3@` com monitor
- **Cancelamento:** Seguro, sem perda de materiais
- **Progressbar:** Sim, com validação client+server

---

## 11. Segurança Server-Side

### drugs_bench (sistema antigo) — RISCOS

| Risco | Severidade | Arquivo | Consequência |
|---|---|---|---|
| Client escolhe produto livremente | **CRÍTICO** | crafting/server-side/core.lua:319 | Fabricação de qualquer item |
| Sem verificação de distância | **CRÍTICO** | crafting/server-side/core.lua:319 | Crafting remoto |
| Entrega instantânea | **ALTO** | crafting/server-side/core.lua:371 | Sem tempo para interceptar |
| Sem rate limiting | **ALTO** | crafting/server-side/core.lua:319 | Spam de fabricação |
| Sem log de fabricação | **MÉDIO** | crafting/server-side/core.lua | Sem auditoria |
| Sem cooldown | **MÉDIO** | crafting/server-side/core.lua | Produção infinita |
| Sem persistência | **MÉDIO** | crafting/server-side/core.lua | Sem rastreio |
| Sem proteção contra desconexão | **BAIXO** | crafting/server-side/core.lua | Materiais já removidos |

### SaoJudas (bancada segura) — PONTOS REUTILIZÁVEIS

| Feature | Implementado | Arquivo |
|---|---|---|
| CraftId server-side | ✅ | crafting/server-side/core.lua:447 |
| Reserva de sessão | ✅ | crafting/server-side/core.lua:483-497 |
| Affected rows (INSERT) | ✅ | crafting/server-side/core.lua:456-461 |
| Máquina de estados | ✅ | processing→completed/cancelled |
| Validação de materiais | ✅ | reservedMaterials() |
| Validação de tempo | ✅ | CompletionToleranceMs |
| Limite de lote | ✅ | MaximumBatch |
| Cancelamento seguro | ✅ | releaseSaoJudasSession() |
| Peso projetado | ✅ | projectedWeightAllowed() |
| Slot livre | ✅ | resultSlot() |
| Logs | ✅ | craftingLog() |
| Persistência DB | ✅ | sao_judas_crafts |
| Rate limiting | ✅ | saoJudasRateAllowed() |
| Desconexão | ✅ | playerDropped handler |
| Resource stop | ✅ | onResourceStop handler |
| Idempotência | ✅ | Session.Busy flag |

---

## 12. Economia

### Custo de produção vs venda NPC

| Produto | Custo ingredientes | Qtd produzida | Custo/unidade | Venda NPC | Margem |
|---|---|---|---|---|---|
| joint | 1 weed | 1 | 1 weed | 75-100 dd | Depende do weed |
| cocaine | 1 coke | 1 | 1 coke | 75-100 dd | Depende do coke |
| meth | 1 saline + 1 sulfuric | **5** | 0.4 (saline+sulfuric) | 75-100 dd × 5 = 375-500 dd | **ALTO** |
| weedsack | 10 joint | 1 | 10 weed | 500-625 dd | = 10 joints vendidos separados |
| cokesack | 10 cocaine | 1 | 10 coke | 500-625 dd | = 10 cocaines |
| methsack | 10 meth | 1 | 2 saline + 2 sulfuric | 500-625 dd | **MUITO ALTO** |

### ⚠️ Alertas Econômicos

1. **Meth produz 5 unidades** — é significativamente mais eficiente que joint/cocaine
2. **Pacotes vs unidades:** vender 10 joints individualmente (750-1000 dd) > 1 weedsack (500-625 dd). **Pacotes são economicamente piores que unidades vendidas separadas.**
3. **saline e sulfuric** estão disponíveis gratuitamente em rotas ilegais (50% chance, 1-3 unidades) — custo real de meth é praticamente zero
4. **weed e coke** dependem de plantação com clones raros (5% chance) — gargalo real

---

## 13. Aviãozinho

| Aspecto | Valor |
|---|---|
| Resource | `of_aviao_sao_judas` |
| Permissão | `SaoJudas` |
| Entregas por rota | 5 |
| Cooldown | 30 minutos |
| Pagamento | 200-300 dirtydollar por entrega |
| Entrega droga pronta? | **NÃO** — paga apenas dirtydollar |
| Entrega matéria-prima? | **NÃO** |
| Contribuição ao cofre? | Não diretamente |

**Recomendação futura:** O aviãozinho pode ser adaptado para entregar matéria-prima (weed, coke, saline, sulfuric) ao invés de apenas pagar dirtydollar, criando uma cadeia de suprimentos para o laboratório. Porém, manter pagamento em dirtydollar como trabalho separado é válido para não sobrecarregar a economia de uma única atividade.

---

## 14. Compatibilidade com Venda NPC

A allowlist do `sao_judas_street_sales` já inclui todos os 6 produtos aprovados:

- ✅ joint (75-100 dd, qty 1-3)
- ✅ cocaine (75-100 dd, qty 1-3)
- ✅ meth (75-100 dd, qty 1-3)
- ✅ weedsack (500-625 dd, qty 1)
- ✅ cokesack (500-625 dd, qty 1)
- ✅ methsack (500-625 dd, qty 1)

**O laboratório futuro produzirá itens diretamente vendáveis pelo sistema de venda NPC sem alterações.**

---

## 15. Compatibilidade com Crafting Seguro

A bancada segura de São Judas (`SaoJudas` no crafting) já implementa **todas as proteções necessárias**. A comparação:

| Feature | drugs_bench | SaoJudas crafting |
|---|---|---|
| Persistência DB | ❌ | ✅ sao_judas_crafts |
| Validação server | Parcial | ✅ Completa |
| Rate limiting | ❌ | ✅ |
| Verificação distância | ❌ | ✅ AtWorkbench() |
| Permissão por grupo | ❌ | ✅ SaoJudas |
| Tempo de fabricação | ❌ | ✅ Duration |
| Cancelamento seguro | N/A | ✅ |
| Logs | ❌ | ✅ |
| Monitor de animação | ❌ | ✅ |
| Proteção desconexão | ❌ | ✅ |

---

## 16. Recomendação de Arquitetura

### Opção A: Migrar receitas para o resource `crafting` (bancada SaoJudas)
- ✅ Reutiliza toda a infraestrutura segura existente
- ✅ Menor esforço de implementação
- ✅ Mesma tabela `sao_judas_crafts` para auditoria
- ❌ Mistura ferramentas ilegais com drogas na mesma bancada

### Opção B: Criar módulo próprio de laboratório ★ RECOMENDADO
- ✅ Separação clara (bancada de ferramentas ≠ laboratório de drogas)
- ✅ Reutiliza a arquitetura segura como template
- ✅ Permite permissão própria (`SaoJudasLaboratorio`)
- ✅ Permite coordenada separada (`vec3(-482.9467,1613.3351,369.3726)`)
- ✅ Permite configuração e economia independentes
- ❌ Mais código para manter

### Opção C: Corrigir o drugs_bench existente
- ❌ Sem permissão por grupo (qualquer jogador usa)
- ❌ Sem persistência, sem logs, sem rate limiting
- ❌ Requer reescrita quase completa
- ❌ Não se integra com o modelo de São Judas

**Recomendação: Opção B** — Criar módulo de laboratório em `sao_judas_operations/config.lua` usando a mesma arquitetura transacional do crafting seguro, com coordenada e permissão próprias.

---

## 17. Riscos

1. O `drugs_bench` antigo permanece acessível a qualquer jogador — não causa conflito imediato, mas permite fabricação fora de São Judas
2. O meth produz 5 unidades com ingredientes gratuitos de rotas — economia desequilibrada
3. Pacotes valem menos que unidades vendidas separadas — incentivo incorreto
4. `codeine` e `metadone` possuem receitas idênticas
5. Clones de weed/coke são muito raros (5%) — pode frustrar cadeia produtiva

---

## 18. Plano Sugerido para Implementação

1. Adicionar receitas de drogas ao `SaoJudasOperations.Workbench.Recipes` ou criar seção `Laboratory` separada
2. Criar coordenada e target para bancada do laboratório em `vec3(-482.9467,1613.3351,369.3726)`
3. Criar tag operacional `Operador de Laboratório` no F9
4. Configurar permissão `SaoJudasLaboratorio` ou reutilizar `WorkbenchRole`
5. Implementar tempo de fabricação (Duration) para cada receita
6. Testar em jogo
7. Opcionalmente desativar `drugs_bench` via flag `ExclusiveSaoJudasLaboratory`

---

## 19. Arquivos Relevantes

### CATÁLOGO
- `resources/[scripts]/inventory/shared-side/shared.lua` — IlegalItens, Sprays, Crafting básico

### CRAFTING
- `resources/[scripts]/crafting/shared-side/shared.lua` — Todas as receitas incluindo drugs_bench
- `resources/[scripts]/crafting/server-side/core.lua` — Lógica de fabricação (legada + SaoJudas segura)
- `resources/[scripts]/crafting/client-side/core.lua` — UI e animação do crafting

### INVENTÁRIO
- `resources/[scripts]/inventory/server-side/itens.lua` — Handler do item drugs_bench (posicionamento)
- `resources/[scripts]/inventory/server-side/drugs.lua` — Venda legada (desabilitada)
- `resources/[scripts]/inventory/client-side/drugs.lua` — Efeitos visuais das drogas

### PLANTAÇÃO
- `resources/[scripts]/plants/server-side/core.lua` — Sistema de plantação

### SÃO JUDAS
- `resources/[scripts]/sao_judas_operations/config.lua` — Config bancada segura + cofre
- `resources/[scripts]/sao_judas_operations/server.lua` — Permissões e exports
- `resources/[scripts]/sao_judas_operations/client.lua` — Targets e UI

### VENDA NPC
- `resources/[scripts]/sao_judas_street_sales/config.lua` — Allowlist de drogas vendáveis

### AVIÃOZINHO
- `resources/[scripts]/of_aviao_sao_judas/config.lua` — Configuração de entregas

---

## 20. Pendências para Teste em Jogo

- [ ] Verificar objeto físico existente em vec3(-482.9467,1613.3351,369.3726)
- [ ] Confirmar heading ideal para a bancada do laboratório
- [ ] Testar proximidade com bancada de ferramentas (possível conflito de target)
- [ ] Verificar se Economy dos itens de droga possui valores definidos no catálogo
- [ ] Confirmar disponibilidade real de weedclone_0 e cokeclone_0 nas rotas
- [ ] Verificar peso dos itens de droga no catálogo
