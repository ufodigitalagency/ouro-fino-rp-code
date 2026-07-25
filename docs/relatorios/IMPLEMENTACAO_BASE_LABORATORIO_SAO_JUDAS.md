# Implementação Base — Laboratório de São Judas (Etapa 3A)

**Data:** 2026-07-25
**Branch:** feat/sao-judas-laboratory-foundation
**Base:** audit/sao-judas-drug-lab (commit c36b641)

---

## 1. Resumo

Esta etapa implementa a **fundação** do laboratório de São Judas:
- Função operacional "Operador de Laboratório"
- Integração com tags do F9
- Exports de autorização server-side
- Configuração do laboratório
- Target físico na coordenada definida
- Diagnóstico e logs

**NÃO inclui:** receitas, crafting, ingredientes, progressbar, animação, banco de crafts, economia.

---

## 2. Função Operacional

| Campo | Valor |
|---|---|
| ID interno | `SaoJudasLaboratorio` |
| Label | `Operador de Laboratório` |
| TagName (DB) | `Operador de Laboratório` |
| Padrão seguido | `DistributionRole` (tag via `painel_creative_tags`) |
| Persistência | `painel_creative_tags` (tabela SQL existente) |
| Auto-criação | `ensureLaboratoryRole()` no startup do resource |

### Padrão reutilizado

A função segue **exatamente** o padrão do `DistributionRole`:
- Registro no banco via `INSERT ... WHERE NOT EXISTS`
- Cache de 5 segundos por Passport
- Consulta direta ao banco com `skipCache` opcional
- Proteção via `ReservedOperationalTags` no painel
- Limpeza de cache no `playerDropped`

### Diferença do WorkbenchRole

O `WorkbenchRole` usa um padrão diferente — verifica a posição na hierarquia (`currentRole()`) ao invés de tag no DB. O `LaboratoryRole` **não** usa esse padrão; ele é independente de patente, assim como o `DistributionRole`.

---

## 3. Regra de Autorização

```
CanUseLaboratory(Passport) =
    IsMember(Passport, "SaoJudas")
    AND (
        IsLeader(Passport)       -- nível 1
        OR HasLaboratoryRole(Passport)  -- tag no DB
    )
```

### Cenários

| Cenário | Resultado |
|---|---|
| Chefe nível 1 | ✅ Acesso sem tag |
| Membro com tag "Operador de Laboratório" | ✅ Acesso |
| Membro sem tag | ❌ Bloqueado |
| Externo com tag órfã | ❌ Bloqueado (isMember falha) |
| Admin sem grupo SaoJudas | ❌ Bloqueado |
| Alias Vagos sem grupo real | ❌ Bloqueado (isMember verifica HasGroup) |

---

## 4. Exports

| Export | Tipo | Descrição |
|---|---|---|
| `HasLaboratoryRole(Passport,skipCache)` | server | Verifica tag no DB com cache 5s |
| `CanUseLaboratory(Passport,skipCache)` | server | isMember AND (isLeader OR hasLaboratoryRole) |
| `AtLaboratory(source)` | server | Distância server-side ≤ 2.5m |

---

## 5. Configuração

Adicionado em `sao_judas_operations/config.lua`:

```lua
LaboratoryRole = {
    Id = "SaoJudasLaboratorio",
    Label = "Operador de Laboratório",
    TagName = "Operador de Laboratório"
},

Laboratory = {
    Enabled = true,
    Coords = vector3(-482.9467,1613.3351,369.3726),
    TargetRadius = 0.65,
    InteractionDistance = 1.5,
    ServerDistance = 2.5,
    ExclusiveSaoJudasLaboratory = false
}
```

### Flags

- `Enabled`: ativa/desativa todo o laboratório
- `ExclusiveSaoJudasLaboratory`: preparação para futura desativação do drugs_bench (mantido `false`)

---

## 6. Target

| Campo | Valor |
|---|---|
| Zone ID | `SaoJudas:Laboratory` |
| Coordenada | `vec3(-482.9467,1613.3351,369.3726)` |
| Raio | 0.65 |
| Distância de interação | 1.5 |
| Label | "Acessar laboratorio" |
| Evento | `saoJudas:UseLaboratory` (server) |
| Heading | Não definido (sem animação nesta etapa) |

### Conflito com bancada de ferramentas

| Ponto | Coordenada | Raio | Dist. interação |
|---|---|---|---|
| Bancada ferramentas | `vec3(-480.5672,1614.7445,369.4934)` | 0.75 | 1.5 |
| Laboratório | `vec3(-482.9467,1613.3351,369.3726)` | 0.65 | 1.5 |

**Distância entre os dois pontos:** ~2.7m

**Análise:** Com raios de 0.65 e 0.75, os círculos de target NÃO se sobrepõem (soma dos raios = 1.40, distância = 2.7). O raio de interação (1.5) cobre até 2.15m e 2.25m do centro respectivamente — ainda sem sobreposição significativa (2.7 > 2.15). **Conflito minimizado.**

**Recomendação:** Confirmar em jogo que cada target ativa apenas sua opção correta.

---

## 7. Interação Temporária

Ao acessar o laboratório:
- **Autorizado:** "O laboratório está sendo preparado." (amarelo)
- **Não autorizado:** Mensagem específica por razão (vermelho)

### Mensagens por estado

| Razão | Mensagem |
|---|---|
| `laboratory_disabled` | O laboratório está temporariamente desabilitado. |
| `player_not_found` | Você não pode acessar o laboratório neste momento. |
| `player_dead` | Você não pode utilizar o laboratório neste estado. |
| `player_in_vehicle` | Saia do veículo para utilizar o laboratório. |
| `safezone` | Não é possível utilizar o laboratório nesta área. |
| `player_handcuffed` | Você não pode utilizar o laboratório algemado. |
| `player_busy` | Você já está realizando outra ação. |
| `routing_bucket_blocked` | O laboratório não está disponível nesta dimensão. |
| `not_member` | Você não está autorizado a utilizar o laboratório de São Judas. |
| `role_missing` | Você não está autorizado a utilizar o laboratório de São Judas. |
| `too_far` | Aproxime-se do laboratório. |

### Validações server-side (ordem)

1. Rate limiting (1s)
2. Passport válido
3. `validateLaboratoryPlayerState(source)` — ped, vida, veículo, safezone, algema, buttons, bucket, enabled
4. isMember(SaoJudas)
5. canUseLaboratory (líder ou tag)
6. atLaboratory (distância ≤ 2.5m)
7. Conceder interação temporária

### validateLaboratoryPlayerState(source)

Função centralizada, reutilizável. Segue o padrão do `validPlayerState()` do `sao_judas_street_sales`.

```lua
-- Ordem interna:
1. Laboratory.Enabled
2. GetPlayerPed(source) ~= 0
3. GetEntityHealth(ped) > 100
4. vRP.InsideVehicle(source) == false
5. Player(source).state.Safezone == false
6. Player(source).state.Handcuff == false
7. Player(source).state.Buttons == false
8. GetPlayerRoutingBucket(source) == 0
```

---

## 8. F9

A tag "Operador de Laboratório" é:
- Auto-criada na tabela `painel_creative_tags` com Permission = "SaoJudas"
- Visível na tela de Tags do painel F9
- Protegida contra edição/exclusão por `ReservedOperationalTags`
- Atribuível pelo chefe (nível 1) a qualquer membro de SaoJudas
- Removível pelo chefe
- Atualização imediata (cache expira em 5s, sem necessidade de restart)

---

## 9. Logs

Prefixo: `[saojudas/laboratory]`

Eventos registrados:
- `access_granted` (passport, source)
- `access_denied` com razão: `laboratory_disabled`, `invalid_passport`, `player_not_found`, `player_dead`, `player_in_vehicle`, `safezone`, `player_handcuffed`, `player_busy`, `routing_bucket_blocked`, `not_member`, `role_missing`, `too_far` (com distância)

---

## 10. Debug

Comando: `/saojudas_lab_debug`

Restrições: `Debug = true` na config + Passport = 1

Informações exibidas:
- passport, member, leader
- has_lab_role, can_use_lab
- distance, at_lab
- bucket, enabled, exclusive
- **in_vehicle**, **safezone**, **handcuff**, **buttons** — state bags
- **alive** — saúde > 100
- **player_state_valid**, **player_state_reason** — resultado de `validateLaboratoryPlayerState()`

---

## 11. Arquivos Alterados

| Arquivo | Tipo | Alteração |
|---|---|---|
| `resources/[scripts]/sao_judas_operations/config.lua` | MODIFY | LaboratoryRole + Laboratory section |
| `resources/[scripts]/sao_judas_operations/server.lua` | MODIFY | Lab functions, event, exports, debug, cache cleanup |
| `resources/[scripts]/sao_judas_operations/client.lua` | MODIFY | Laboratory target zone + debug |
| `resources/[scripts]/painel/server-side/core.lua` | MODIFY | ReservedOperationalTags + "Operador de Laboratório" |

### Arquivos NÃO alterados (confirmado)
- crafting/*
- inventory/*
- sao_judas_street_sales/*
- plants/*
- of_aviao_sao_judas/*
- drugs_bench

---

## 12. Testes Estáticos

- [x] `git diff --check` — sem erros de whitespace
- [x] Nenhuma referência a receitas de drogas no diff
- [x] Nenhuma alteração em crafting/inventory
- [x] Exports registrados corretamente
- [x] Target zone registrado com ID único
- [x] ReservedOperationalTags atualizado
- [x] Cache cleanup no playerDropped

---

## 13. Roteiro de Testes em Jogo

### TESTE A — CHEFE
1. Entrar como líder de SaoJudas
2. Aproximar-se de `vec3(-482.9467,1613.3351,369.3726)`
3. Abrir target
4. Clicar em "Acessar laboratorio"
5. **Esperado:** "O laboratório está sendo preparado." (amarelo)

### TESTE B — MEMBRO SEM FUNÇÃO
1. Pertencer a SaoJudas sem tag "Operador de Laboratório"
2. Tentar acessar o target do laboratório
3. **Esperado:** "Você não está autorizado..." (vermelho)

### TESTE C — MEMBRO COM FUNÇÃO
1. Abrir F9 como chefe
2. Ir em Tags → localizar "Operador de Laboratório"
3. Atribuir a um membro
4. Membro tenta acessar laboratório (sem restart)
5. **Esperado:** "O laboratório está sendo preparado." (amarelo)

### TESTE D — REMOÇÃO
1. Remover tag do membro pelo F9
2. Membro tenta novamente (sem restart)
3. **Esperado:** "Você não está autorizado..." (vermelho)

### TESTE E — EXTERNO
1. Jogador sem grupo SaoJudas
2. **Esperado:** Acesso negado

### TESTE F — DISTÂNCIA
1. Chamar `saoJudas:UseLaboratory` longe da bancada
2. **Esperado:** "Aproxime-se do laboratório." (vermelho)

### TESTE G — CONFLITO DE TARGETS
1. Posicionar-se na bancada de ferramentas
2. Verificar que aparece "Usar bancada de fabricação"
3. Caminhar até o laboratório
4. Verificar que aparece "Acessar laboratorio"
5. **Esperado:** Cada target mostra apenas sua opção

### TESTE H — DEBUG
1. `/saojudas_lab_debug` (como Passport 1 com Debug = true)
2. Verificar output no F8
3. **Esperado:** Todos os campos listados na seção 10, incluindo estados

### TESTE I — VEÍCULO
1. Entrar em um veículo próximo ao laboratório
2. Tentar acessar
3. **Esperado:** "Saia do veículo para utilizar o laboratório." (vermelho)

### TESTE J — ALGEMA
1. Estar algemado
2. Tentar acessar
3. **Esperado:** "Você não pode utilizar o laboratório algemado." (vermelho)

---

## 14. Cache

- Não existe invalidação imediata no painel F9 para tags (nem para DistributionRole, nem para LaboratoryRole)
- Ambos usam cache de 5 segundos com `skipCache` opcional
- Após atribuir/remover tag, aguardar até **5 segundos** para o efeito refletir
- Não foi adicionada comunicação inter-resource para invalidação (preservando o padrão existente)

---

## 15. Limitações

- Heading não definido — será confirmado no teste em jogo
- Sem animação — será adicionada na etapa de crafting
- Sem NUI — nesta etapa não há interface visual
- `ExclusiveSaoJudasLaboratory = false` — não desativa o drugs_bench antigo

### Nota sobre Buttons na Etapa 3B

A verificação de `Player(source).state.Buttons` impede acesso quando o jogador já está em outra interação. Na futura Etapa 3B, quando o laboratório definir `Buttons = true` durante o crafting, a validação de **conclusão** do craft não deve cancelar por causa do estado que a própria interação criou. Padrão a seguir: validar Buttons apenas no **início** da interação, não durante o progresso.
