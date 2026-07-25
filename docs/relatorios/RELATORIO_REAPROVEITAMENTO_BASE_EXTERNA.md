# Relatorio - Reaproveitamento da base externa

Data: 2026-07-08

## Caminho analisado

- Atalho local: `C:\meu-server-gta\Base\# externo\resources - Atalho.lnk`
- Destino resolvido: `D:\# Arquivos\# SERVIDOR FIVEM\# BASES\BaseGratuita2.0 - Fluxo Shop!\BaseFluxoGratuita\resources`

## Estrutura encontrada

- `[FLUXO-EMPREGOS]`: empregos antigos vRP, incluindo `fluxo_ifood`, `fluxo_desmanche`, `fluxo_vendinha`, pacote `[fluxo_empregos]` e `[fluxo_pescador]`.
- `[FLUXO-NATIONS]`: `bennys`, `nation_barbershop`, `nation_concessionaria`, `nation_creator`, `nation_fuel`, `nation_garages`, `nation_gm`, `nation_race`, `nation_skinshop`, `nation_tattoos`.
- `[FLUXO-ROUBOS]`: `vrp_roubos`.
- `[FLUXO-SCRIPTS]`: `ws-bank`, `five_setgroup`, `dm_time`, `Luzes-ELS`, `suricato_servico`, `[cam]`.
- `[FLUXO-SYSTEM]`: resources padrao (`chat`, `mapmanager`, `spawnmanager`, etc.).
- `[FLUXO-VEICULOS]`: pack de veiculos.
- `[FLUXO-VRP]`: framework vRP da base externa.

## O que foi aproveitado agora

Nao copiei resources externos crus para a base atual, porque varios scripts usam API antiga ou tabelas diferentes. Em vez disso, foi criado suporte simples dentro do `cfWorks` atual para mais dois empregos:

- `Entregador iFood`: emprego de rotas simples com GPS, marcador, tecla E, pagamento e XP.
- `Taxista`: emprego de rotas simples com GPS, marcador, tecla E, pagamento e XP.

Arquivos alterados:

- `C:\meu-server-gta\Base\resources\[scripts]\cfWorks\config.lua`
- `C:\meu-server-gta\Base\resources\[scripts]\cfWorks\eleven.lua`
- `C:\meu-server-gta\Base\resources\[scripts]\cfWorks\fxmanifest.lua`
- `C:\meu-server-gta\Base\resources\[scripts]\cfWorks\jobs\rotas\client.lua`
- `C:\meu-server-gta\Base\resources\[scripts]\cfWorks\jobs\rotas\server.lua`

## Avaliacao por item pedido

### Empregos

Encontrados na base externa:

- `fluxo_ifood`: bom candidato, mas usa funcoes antigas como `vRP.getUserId`, `vRP.giveMoney`, `vRP.getRegistrationNumber`, objetos via `vRP._CarregarObjeto` e exige fluxo de moto/placa antigo.
- `fluxo_desmanche`: funcional como ideia, mas contem webhook antigo, permissao propria, item `chave`, tabelas/listas antigas e precisa revisao de seguranca.
- `fluxo_vendinha`: parece job/farm de venda/produção, mas depende de itens antigos.
- `[fluxo_empregos]\jobsafter`: contem `emp_driver`, `emp_farmer`, `emp_garbageman`, `emp_miner`, `emp_postman`, `emp_taxista`.
- `[fluxo_pescador]`: contem pesca e venda de pescados, mas depende de itens como isca e peixes da base antiga.

Status recomendado: portar por partes, criando scripts novos ou adaptando para a API atual. Nao iniciar todos direto.

### Smartphone

Nao foi identificado um smartphone moderno completo nessa base externa. O que existe e mais ligado ao vRP antigo, identidade/telefone e voip. A base atual ja possui `lb-phone`/smartphone adaptado e o historico mostrou que trocar telefone sem migracao de banco/API causa erros em loop.

Status recomendado: manter o telefone atual por enquanto e trocar somente com teste isolado.

### Nation Bennys

A base externa possui `bennys` e outros Nation. A base atual ja possui `nation_bennys` em `C:\meu-server-gta\Base\resources\[scripts]\nation_bennys`.

Status recomendado: comparar configuracoes e UI, mas nao substituir direto. Scripts Nation externos ja causaram loop de autenticacao/DRM em tentativas anteriores.

### Roubos

`vrp_roubos` existe e e candidato para portar. Antes de ativar precisa revisar:

- permissao/quantidade minima de policia;
- cooldown global e por local;
- itens exigidos;
- pagamento em dinheiro limpo/sujo;
- compatibilidade com notificacoes e dispatch atual.

Status recomendado: fase 2, depois de estabilizar empregos e admin.

### Banco/Pix

`ws-bank` existe na base externa, mas usa tabela antiga `vrp_user_moneys`. A base atual usa sistema diferente com `characters`, `bank` e funcoes `vRP.PaymentFull`, `vRP.GiveBank`, `exports.bank`.

Status recomendado: nao portar cru.

## Risco tecnico

O maior risco e misturar framework vRP antigo da Fluxo com a base atual Creative/custom vRP. Muitos scripts antigos podem iniciar, mas quebrar em runtime por:

- nomes de itens diferentes;
- tabelas SQL antigas;
- permissoes antigas;
- callbacks/eventos inexistentes;
- autenticacao/DRM dos Nation.

## Proxima ordem recomendada

1. Testar os 5 empregos no `cfWorks`: `Lixeiro`, `Minerador`, `Eletricista`, `Entregador iFood`, `Taxista`.
2. Se estiver estavel, portar `Pescador` como script novo dentro do padrao atual.
3. Depois portar `Desmanche` com permissao, webhook novo e dinheiro sujo compativel.
4. Revisar `nation_bennys` atual antes de qualquer substituicao.
5. Avaliar `vrp_roubos` com checklist de policia/cooldown/item.

## Comandos de teste

No console do FXServer:

```txt
restart cfWorks
```

No jogo:

```txt
/cfworks
```

Resultado esperado:

- Central abre com 5 vagas.
- `Entregador iFood` e `Taxista` criam rota no GPS.
- Ao chegar no ponto, pressionar `E` paga dinheiro e XP.
- F10 nao abre mais `cfWorks`.
