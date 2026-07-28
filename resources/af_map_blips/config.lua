Config = Config or {}

Config.Debug = false
Config.DefaultDisplay = 4
Config.DefaultShortRange = true
Config.ReconcileInterval = 15000
Config.WorldMarkers = true
Config.WorldMarkerDistance = 35.0
Config.InteractionDistance = 1.6

Config.NavAliases = {
    banco = "banco_principal",
    caixa = "atm_principal",
    atm = "atm_principal",
    mercearia = "mercearia_1",
    loja = "mercearia_1",
    concessionaria = "concessionaria",
    policia = "policia",
    vestiario = "policia_vestiario",
    arsenal = "policia_arsenal",
    hospital = "hospital",
    farmacia = "hospital_farmacia",
    lanchonete = "hospital_lanchonete",
    garagem = "garagem_praca",
    garagemhospital = "garagem_hospital",
	garagemsamu = "garagem_hospital_viaturas",
	aeroporto = "garagem_aeroporto",
	taxi = "taxista",
	pombal = "favela_pombal",
	cdd = "favela_pombal",
	saojudas = "favela_sao_judas",
	chapadao = "favela_sao_judas",
	arsenalpombal = "pombal_arsenal",
	arsenalsaojudas = "sao_judas_arsenal"
}

-- Este resource assume os blips principais da cidade para evitar duplicidade
-- com os blips curtos do creative. Use coords como tabela simples para nao
-- depender de vector3/vector4 no carregamento compartilhado.
Config.Blips = {
    { id = "banco_principal", enabled = true, marker = true, name = "Banco Principal", sprite = 108, color = 25, scale = 0.72, coords = { x = 149.99, y = -1039.58, z = 29.37 } },
    { id = "banco_2", enabled = true, marker = true, name = "Banco 2", sprite = 108, color = 25, scale = 0.72, coords = { x = 235.18, y = 217.38, z = 106.29 } },
    { id = "banco_hawick", enabled = true, name = "Banco", sprite = 108, color = 25, scale = 0.62, coords = { x = 313.95, y = -279.74, z = 54.39 } },
    { id = "banco_del_perro", enabled = true, name = "Banco", sprite = 108, color = 25, scale = 0.62, coords = { x = -1212.37, y = -331.37, z = 38.0 } },
    { id = "banco_burton", enabled = true, name = "Banco", sprite = 108, color = 25, scale = 0.62, coords = { x = -351.2, y = -50.57, z = 49.26 } },
    { id = "banco_rota_68", enabled = true, name = "Banco", sprite = 108, color = 25, scale = 0.62, coords = { x = 1175.09, y = 2707.53, z = 38.31 } },
    { id = "banco_pacific", enabled = true, name = "Banco", sprite = 108, color = 25, scale = 0.62, coords = { x = -2961.85, y = 482.87, z = 15.92 } },
    { id = "banco_paleto", enabled = true, name = "Banco", sprite = 108, color = 25, scale = 0.62, coords = { x = -112.86, y = 6470.46, z = 31.85 } },
    { id = "atm_principal", enabled = true, marker = true, name = "Caixa Eletronico", sprite = 108, color = 2, scale = 0.55, coords = { x = 146.21, y = -1035.25, z = 29.34 } },

    { id = "mercearia_1", enabled = true, marker = true, name = "Mercearia", sprite = 52, color = 36, scale = 0.58, coords = { x = 25.75, y = -1346.69, z = 29.49 } },
    { id = "mercearia_2", enabled = true, name = "Mercearia", sprite = 52, color = 36, scale = 0.52, coords = { x = 2556.77, y = 380.87, z = 108.61 } },
    { id = "mercearia_3", enabled = true, name = "Mercearia", sprite = 52, color = 36, scale = 0.52, coords = { x = 1164.81, y = -323.61, z = 69.2 } },
    { id = "mercearia_4", enabled = true, name = "Mercearia", sprite = 52, color = 36, scale = 0.52, coords = { x = -706.16, y = -914.55, z = 19.21 } },
    { id = "mercearia_5", enabled = true, name = "Mercearia", sprite = 52, color = 36, scale = 0.52, coords = { x = -47.35, y = -1758.59, z = 29.42 } },
    { id = "mercearia_6", enabled = true, name = "Mercearia", sprite = 52, color = 36, scale = 0.52, coords = { x = 372.7, y = 326.89, z = 103.56 } },
    { id = "mercearia_7", enabled = true, name = "Mercearia", sprite = 52, color = 36, scale = 0.52, coords = { x = -3242.7, y = 1000.05, z = 12.82 } },
    { id = "mercearia_8", enabled = true, name = "Mercearia", sprite = 52, color = 36, scale = 0.52, coords = { x = 1728.08, y = 6415.6, z = 35.03 } },
    { id = "mercearia_9", enabled = true, name = "Mercearia", sprite = 52, color = 36, scale = 0.52, coords = { x = 549.09, y = 2670.89, z = 42.16 } },
    { id = "mercearia_10", enabled = true, name = "Mercearia", sprite = 52, color = 36, scale = 0.52, coords = { x = 1959.87, y = 3740.44, z = 32.33 } },
    { id = "mercearia_11", enabled = true, name = "Mercearia", sprite = 52, color = 36, scale = 0.52, coords = { x = 2677.65, y = 3279.66, z = 55.23 } },
    { id = "mercearia_12", enabled = true, name = "Mercearia", sprite = 52, color = 36, scale = 0.52, coords = { x = 1697.32, y = 4923.46, z = 42.06 } },
    { id = "mercearia_13", enabled = true, name = "Mercearia", sprite = 52, color = 36, scale = 0.52, coords = { x = -1819.52, y = 793.48, z = 138.08 } },
    { id = "mercearia_14", enabled = true, name = "Mercearia", sprite = 52, color = 36, scale = 0.52, coords = { x = 1391.62, y = 3605.95, z = 34.98 } },
    { id = "mercearia_15", enabled = true, name = "Mercearia", sprite = 52, color = 36, scale = 0.52, coords = { x = -2966.41, y = 391.52, z = 15.05 } },
    { id = "mercearia_16", enabled = true, name = "Mercearia", sprite = 52, color = 36, scale = 0.52, coords = { x = -3039.42, y = 584.42, z = 7.9 } },
    { id = "mercearia_17", enabled = true, name = "Mercearia", sprite = 52, color = 36, scale = 0.52, coords = { x = 1134.32, y = -983.09, z = 46.4 } },
    { id = "mercearia_18", enabled = true, name = "Mercearia", sprite = 52, color = 36, scale = 0.52, coords = { x = 1165.32, y = 2710.79, z = 38.15 } },
    { id = "mercearia_19", enabled = true, name = "Mercearia", sprite = 52, color = 36, scale = 0.52, coords = { x = -1486.72, y = -377.61, z = 40.15 } },
    { id = "mercearia_20", enabled = true, name = "Mercearia", sprite = 52, color = 36, scale = 0.52, coords = { x = -1221.48, y = -907.93, z = 12.32 } },

    { id = "concessionaria", enabled = true, name = "Concessionaria", sprite = 225, color = 62, scale = 0.66, coords = { x = -54.3, y = -1094.8, z = 26.42 } },
    { id = "hospital", enabled = true, marker = false, shortRange = true, name = "Hospital SAMU", sprite = 80, color = 38, scale = 0.62, coords = { x = -676.9, y = 312.16, z = 83.09 } },
    { id = "hospital_farmacia", enabled = true, marker = true, name = "Farmacia do Hospital", sprite = 52, color = 2, scale = 0.6, coords = { x = -664.49, y = 321.26, z = 83.09 } },
    { id = "hospital_lanchonete", enabled = true, marker = true, name = "Lanchonete do Hospital", sprite = 78, color = 62, scale = 0.6, coords = { x = -691.5, y = 322.46, z = 83.09 } },
    { id = "garagem_hospital", enabled = true, name = "Garagem Hospital", sprite = 357, color = 62, scale = 0.58, coords = { x = -663.29, y = 334.73, z = 78.12 } },
    { id = "garagem_hospital_viaturas", enabled = true, name = "Garagem Viaturas SAMU", sprite = 357, color = 38, scale = 0.58, coords = { x = -687.33, y = 340.5, z = 78.12 } },
    { id = "policia", enabled = true, marker = false, name = "Departamento de Policia Ouro Fino", sprite = 60, color = 29, scale = 0.72, coords = { x = -434.8, y = 1123.9, z = 325.86 } },
    { id = "policia_vestiario", enabled = true, map = false, marker = false, name = "Vestiario Policial", sprite = 366, color = 29, scale = 0.58, coords = { x = -448.11, y = 1103.87, z = 327.68 } },
	{ id = "policia_arsenal", enabled = true, map = true, marker = true, name = "Armamento Policial", sprite = 76, color = 29, scale = 0.58, coords = { x = -422.59, y = 1089.13, z = 327.68 } },
    { id = "garagem_policia_map_pm", enabled = true, name = "Garagem de Viaturas", sprite = 357, color = 29, scale = 0.58, coords = { x = -434.8, y = 1123.9, z = 325.86 } },
    { id = "garagem_map_pm", enabled = true, name = "Garagem", sprite = 357, color = 62, scale = 0.58, coords = { x = -429.07, y = 1204.3, z = 325.76 } },
    { id = "heliporto_policia_map_pm", enabled = true, name = "Helicoptero Policial", sprite = 64, color = 29, scale = 0.58, coords = { x = -436.7, y = 1110.0, z = 335.11 } },
	{ id = "garagem_chapadao", enabled = true, name = "Garagem São Judas", sprite = 357, color = 62, scale = 0.58, coords = { x = -441.61, y = 1606.91, z = 360.52 } },
	{ id = "heliporto_chapadao", enabled = true, name = "Heliponto São Judas", sprite = 64, color = 62, scale = 0.58, coords = { x = -526.7, y = 1450.74, z = 387.01 } },
	{ id = "garagem_chapadao_2", enabled = true, name = "Garagem São Judas", sprite = 357, color = 62, scale = 0.58, coords = { x = -334.2, y = 1536.48, z = 367.34 } },
	{ id = "favela_sao_judas", enabled = true, name = "São Judas", sprite = 84, display = 2, color = 2, scale = 0.68, shortRange = true, priority = 5, coords = { x = -396.0, y = 1553.0, z = 370.0 } },
	{ id = "favela_pombal", enabled = true, name = "Pombal", sprite = 84, display = 2, color = 1, scale = 0.68, shortRange = true, priority = 5, coords = { x = 2526.0, y = 2501.0, z = 50.0 } },
	{ id = "garagem_pombal", enabled = true, name = "Garagem Pombal", sprite = 357, color = 1, scale = 0.58, coords = { x = 2492.22, y = 2463.06, z = 52.86 } },
	{ id = "pombal_arsenal", enabled = true, map = true, marker = true, interactionDistance = 2.75, name = "Arsenal do Pombal", sprite = 76, color = 1, scale = 0.58, coords = { x = 2538.11, y = 2521.55, z = 46.20 } },
	{ id = "sao_judas_arsenal", enabled = true, map = true, marker = true, interactionDistance = 2.75, name = "Arsenal de São Judas", sprite = 76, color = 2, scale = 0.58, coords = { x = -484.78, y = 1606.37, z = 369.58 } },
	{ id = "taxista", enabled = true, map = false, marker = false, name = "Central de Taxi", sprite = 198, color = 62, scale = 0.55, coords = { x = 895.17, y = -179.31, z = 74.70 } },

    { id = "roupas_1", enabled = true, name = "Loja de Roupas", sprite = 366, color = 62, scale = 0.52, coords = { x = 414.86, y = -807.57, z = 29.34 } },
    { id = "barbearia_1", enabled = true, name = "Barbearia", sprite = 71, color = 62, scale = 0.5, coords = { x = -815.12, y = -184.15, z = 37.57 } },
    { id = "mecanica_1", enabled = true, name = "Bennys - Oficina Mecanica", sprite = 72, color = 46, scale = 0.72, shortRange = true, coords = { x = -553.92, y = -929.12, z = 23.86 } },
    { id = "garagem_praca", enabled = true, name = "Garagem", sprite = 357, color = 62, scale = 0.58, coords = { x = 214.02, y = -808.44, z = 31.01 } },
    { id = "garagem_centro", enabled = true, name = "Garagem", sprite = 357, color = 62, scale = 0.58, coords = { x = 55.43, y = -876.19, z = 30.66 } },
    { id = "garagem_sandy", enabled = true, name = "Garagem", sprite = 357, color = 62, scale = 0.58, coords = { x = 598.04, y = 2741.27, z = 42.07 } },
    { id = "garagem_paleto", enabled = true, name = "Garagem", sprite = 357, color = 62, scale = 0.58, coords = { x = -136.36, y = 6357.03, z = 31.49 } },
    { id = "garagem_pillbox", enabled = true, name = "Garagem", sprite = 357, color = 62, scale = 0.58, coords = { x = 275.23, y = -345.54, z = 45.17 } },
    { id = "garagem_vinewood", enabled = true, name = "Garagem", sprite = 357, color = 62, scale = 0.58, coords = { x = 596.4, y = 90.65, z = 93.12 } },
    { id = "garagem_eclipse", enabled = true, name = "Garagem", sprite = 357, color = 62, scale = 0.58, coords = { x = -340.76, y = 265.97, z = 85.67 } },
    { id = "garagem_chumash", enabled = true, name = "Garagem", sprite = 357, color = 62, scale = 0.58, coords = { x = -2030.01, y = -465.97, z = 11.6 } },
    { id = "garagem_vespucci", enabled = true, name = "Garagem", sprite = 357, color = 62, scale = 0.58, coords = { x = -1184.92, y = -1510.0, z = 4.64 } },
    { id = "garagem_morningwood", enabled = true, name = "Garagem", sprite = 357, color = 62, scale = 0.58, coords = { x = -348.88, y = -874.02, z = 31.31 } },
    { id = "garagem_innocence", enabled = true, name = "Garagem", sprite = 357, color = 62, scale = 0.58, coords = { x = 67.74, y = 12.27, z = 69.21 } },
    { id = "garagem_alta", enabled = true, name = "Garagem", sprite = 357, color = 62, scale = 0.58, coords = { x = 361.9, y = 297.81, z = 103.88 } },
    { id = "garagem_mirror", enabled = true, name = "Garagem", sprite = 357, color = 62, scale = 0.58, coords = { x = 1035.89, y = -763.89, z = 57.99 } },
    { id = "garagem_delperro", enabled = true, name = "Garagem", sprite = 357, color = 62, scale = 0.58, coords = { x = -796.63, y = -2022.77, z = 9.16 } },
    { id = "garagem_missionrow", enabled = true, name = "Garagem", sprite = 357, color = 62, scale = 0.58, coords = { x = 453.27, y = -1146.76, z = 29.52 } },
    { id = "garagem_hawick", enabled = true, name = "Garagem", sprite = 357, color = 62, scale = 0.58, coords = { x = 528.66, y = -146.3, z = 58.38 } },
    { id = "garagem_little_seoul", enabled = true, name = "Garagem", sprite = 357, color = 62, scale = 0.58, coords = { x = -1159.48, y = -739.32, z = 19.89 } },
    { id = "garagem_legion", enabled = true, name = "Garagem", sprite = 357, color = 62, scale = 0.58, coords = { x = 101.22, y = -1073.68, z = 29.38 } },
    { id = "garagem_grapeseed", enabled = true, name = "Garagem", sprite = 357, color = 62, scale = 0.58, coords = { x = 1725.21, y = 4711.77, z = 42.11 } },
    { id = "garagem_sandy_2", enabled = true, name = "Garagem", sprite = 357, color = 62, scale = 0.58, coords = { x = 1624.05, y = 3566.14, z = 35.15 } },
    { id = "garagem_warehouse", enabled = true, name = "Garagem", sprite = 357, color = 62, scale = 0.58, coords = { x = -73.35, y = -2004.6, z = 18.27 } },
    { id = "garagem_mirror_park", enabled = true, name = "Garagem", sprite = 357, color = 62, scale = 0.58, coords = { x = 1200.52, y = -1276.06, z = 35.22 } },
    { id = "garagem_aeroporto", enabled = true, name = "Garagem Aeroporto", sprite = 357, color = 62, scale = 0.58, coords = { x = -1032.69, y = -2731.05, z = 13.75 } },
    { id = "garagem_concessionaria", enabled = true, name = "Garagem", sprite = 357, color = 62, scale = 0.58, coords = { x = -57.01, y = -1104.06, z = 26.44 } },
    { id = "garagem_bennys", enabled = true, name = "Garagem Bennys", sprite = 357, color = 62, scale = 0.58, shortRange = true, coords = { x = -552.42, y = -914.86, z = 23.86 } },
    { id = "eletronicos", enabled = true, name = "Loja de Eletronicos", sprite = 515, color = 62, scale = 0.62, coords = { x = 224.59, y = -1511.14, z = 29.28 } },
    { id = "mercado_central", enabled = true, name = "Mercado Central", sprite = 78, color = 62, scale = 0.55, coords = { x = 46.7, y = -1749.71, z = 29.62 } }
}

Config.ReferenceCoords = {
    concessionaria = { x = -54.30, y = -1094.80, z = 26.42, h = 277.80 },
    mercearia_1 = { x = 25.75, y = -1346.69, z = 29.49, h = 85.04 },
    banco_principal = { x = 149.99, y = -1039.58, z = 29.37, h = 192.76 },
    caixa_eletronico_1 = { x = 146.21, y = -1035.25, z = 29.34, h = 68.04 },
    banco_2 = { x = 235.18, y = 217.38, z = 106.29, h = 294.81 },
    vestiario_policia = { x = -448.11, y = 1103.87, z = 327.68, h = 62.37 },
	arsenal_policia = { x = -422.59, y = 1089.13, z = 327.68, h = 201.26 },
	arsenal_pombal = { x = 2538.11, y = 2521.55, z = 46.20, h = 113.39 }
}
