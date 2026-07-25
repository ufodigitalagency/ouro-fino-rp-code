# Integracao de Hair e Roupas

Data: 2026-07-21

## Hair XS feminino

Origem analisada:

`D:\# Arquivos\# SERVIDOR FIVEM\#SCRIPTS\Pack Hair F&M\xs-female-hair-v1`

Integrado ao resource existente `resources/[scripts]/barbershop`:

- `mp_f_freemode_01_mp_f_femalehairv1_shop.meta`;
- 127 arquivos `.ydd`;
- 140 arquivos `.ytd`;
- 1 arquivo `.ymt`;
- 140 variacoes de cabelo para `mp_f_freemode_01`;
- collection `mp_f_femalehairv1`.

Backup anterior da barbearia:

`_codex_backups/barbershop_before_xs_female_hair_20260721`

O `barbershop` existente ja consulta dinamicamente a quantidade do componente
de cabelo, entao nenhuma NUI, comando ou sistema paralelo foi criado.

## Cabelo feminino em personagem masculino

O pack XS fornecido contem apenas assets e metadata para
`mp_f_freemode_01`. Permitir esses cabelos no ped masculino exige criar uma
versao masculina dos modelos, com nomes, metadata e pesos/esqueleto compativeis
com `mp_m_freemode_01`. Renomear arquivos ou liberar um indice no Lua nao faz
essa conversao e pode gerar cabelo invisivel, desalinhado ou deformado.

Essa conversao ficou pendente para uma etapa de asset authoring, usando uma
ferramenta apropriada e teste visual. Nenhum personagem masculino foi alterado
nesta instalacao.

## Roupas novas Doogie

Origem analisada:

`D:\# Arquivos\# SERVIDOR FIVEM\#SCRIPTS\roupas_novas`

Resultado:

- 5.670 arquivos;
- cerca de 18,26 GiB;
- duas partes (`wspdoogie-1` e `wspdoogie-2`);
- apenas a primeira parte possui `fxmanifest.lua`;
- 512 nomes de arquivo ja existem no `clothes_addon` atual;
- 73 colisoes de `.ydd` e 438 colisoes de `.ytd`;
- varios modelos individuais excedem 16 MiB.

O pack nao foi copiado ou iniciado. Mistura-lo diretamente ao
`clothes_addon` poderia sobrescrever assets ativos e aumentar drasticamente o
download/streaming dos jogadores.

## Proximo teste

1. Reiniciar somente `barbershop` em horario de teste.
2. Criar ou usar uma personagem feminina.
3. Abrir a barbearia e confirmar que o total de cabelos aumentou.
4. Salvar, relogar e confirmar persistencia.
5. So depois avaliar a conversao masculina com amostras pequenas e autorizadas.
