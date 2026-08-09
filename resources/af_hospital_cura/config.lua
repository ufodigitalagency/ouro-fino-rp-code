Config = Config or {}

-----------------------------------------------------------------------------------------------------------------------------------------
-- GERAL
-----------------------------------------------------------------------------------------------------------------------------------------
Config.Debug = false

-- Distancia para mostrar o marker 3D no chao de cada maca
Config.MarkerDistance = 8.0

-- Distancia para liberar a interacao (deitar/levantar)
Config.InteractionDistance = 1.6

-----------------------------------------------------------------------------------------------------------------------------------------
-- CURA PASSIVA (sem medico em servico)
-----------------------------------------------------------------------------------------------------------------------------------------
-- A cada quantos segundos o jogador recupera vida deitado na maca
Config.PassiveHealInterval = 10000

-- Quantidade de vida recuperada a cada intervalo (bem lento, de proposito)
Config.PassiveHealAmount = 2

-- Ate qual valor de vida (vRP.GetHealth) a cura passiva funciona. Acima disso ela para
-- automaticamente. 100 = jogador critico/quase morrendo. Deixamos em 140 para nao
-- competir com o atendimento completo de um paramedico real (que pode curar mais).
Config.PassiveHealCap = 140

-----------------------------------------------------------------------------------------------------------------------------------------
-- ANIMACAO DE DEITAR NA MACA
-----------------------------------------------------------------------------------------------------------------------------------------
-- "dead"/"dead_a" e a animacao de "deitado de costas" usada na grande maioria das bases
-- FiveM de ambulancia/hospital (ESX, QBCore etc). Se preferir outra, so trocar aqui.
Config.LayAnim = {
	Dict = "dead",
	Clip = "dead_a",
	Flag = 1 -- 1 = loop
}

-- Tecla padrao para levantar da maca e cancelar a cura (o jogador pode rebindar em
-- Configuracoes > Teclas do FiveM, igual qualquer outro atalho do jogo)
Config.ExitKey = "F6"

-----------------------------------------------------------------------------------------------------------------------------------------
-- MACAS (Hospital SAMU - Ouro Fino)
-----------------------------------------------------------------------------------------------------------------------------------------
-- coords = posicao da maca/blip. heading = para onde o jogador fica olhando ao interagir.
-- lay = posicao exata em que o ped fica deitado (se nao informado, calculamos com base
-- em coords + uma pequena altura extra, usando o mesmo heading).
Config.Macas = {
	{ id = 1, coords = { x = -669.08, y = 343.42, z = 83.09 }, heading = 70.87 },
	{ id = 2, coords = { x = -664.33, y = 343.77, z = 83.09 }, heading = 113.39 },
	{ id = 3, coords = { x = -661.06, y = 343.35, z = 83.09 }, heading = 68.04 },
	{ id = 4, coords = { x = -658.83, y = 343.26, z = 83.09 }, heading = 283.47 },
	{ id = 5, coords = { x = -654.46, y = 337.88, z = 83.09 }, heading = 198.43 },
	{ id = 6, coords = { x = -654.25, y = 342.18, z = 83.09 }, heading = 204.1 },
	{ id = 7, coords = { x = -656.75, y = 334.17, z = 83.09 }, heading = 246.62 },
	{
		id = 8,
		coords = { x = -662.79, y = 335.0, z = 83.09 },
		heading = 110.56,
		-- Coordenada de deitado informada manualmente para esta maca especifica
		lay = { x = -663.68, y = 334.5543, z = 83.9912, heading = 167.72 }
	},
	{ id = 9, coords = { x = -658.76, y = 334.29, z = 83.09 }, heading = 96.38 }
}
