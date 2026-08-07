-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")
vRP = Proxy.getInterface("vRP")
-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECTION
-----------------------------------------------------------------------------------------------------------------------------------------
Lil = {}
Tunnel.bindInterface("garages",Lil)
vSERVER = Tunnel.getInterface("garages")
-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIAVEIS
-----------------------------------------------------------------------------------------------------------------------------------------
local Respawns = {}
local Opened = false
local Searched = nil
local Hotwired = false
local Spam = GetGameTimer()
local Anim = "machinic_loop_mechandplayer"
local Dict = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@"

local function IsPhoneOpen()
	if GetResourceState("lb-phone") ~= "started" then
		return false
	end

	local Ok,Result = pcall(function()
		return exports["lb-phone"]:IsOpen()
	end)

	return Ok and Result == true
end

local function IsWanted()
	local Ok,Result = pcall(function()
		return exports.hud:Wanted()
	end)

	return Ok and Result == true
end

local function HelpText(Text)
	BeginTextCommandDisplayHelp("STRING")
	AddTextComponentSubstringPlayerName(Text)
	EndTextCommandDisplayHelp(0,false,true,-1)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIAVEIS
-----------------------------------------------------------------------------------------------------------------------------------------
local Garages = {
	["1"] = { x = 55.44, y = -876.17, z = 30.67,
		["1"] = { 60.44,-866.47,30.23,340.16 },
		["2"] = { 57.26,-865.35,30.25,340.16 },
		["3"] = { 54.03,-864.21,30.25,340.16 },
		["4"] = { 50.73,-863.01,30.26,340.16 },
		["5"] = { 60.52,-866.53,30.14,340.16 },
		["6"] = { 50.73,-873.28,30.11,158.75 },
		["7"] = { 47.36,-872.07,30.13,158.75 },
		["8"] = { 44.15,-870.9,30.13,158.75 }
	},
	["2"] = { x = 599.04, y = 2745.33, z = 42.04,
		["1"] = { 604.82,2738.27,41.64,187.09 },
		["2"] = { 601.75,2738.08,41.65,184.26 },
		["3"] = { 598.63,2737.85,41.69,184.26 },
		["4"] = { 595.59,2737.55,41.7,184.26 }
	},
	["3"] = { x = -136.8, y = 6356.84, z = 31.49,
		["1"] = { -133.72,6349.01,31.16,42.52 },
		["2"] = { -136.1,6346.53,31.16,42.52 }
	},
	["4"] = { x = 275.23, y = -345.56, z = 45.17,
		["1"] = { 266.06,-332.07,44.58,252.29 },
		["2"] = { 267.18,-328.9,44.58,252.29 },
		["3"] = { 268.32,-325.67,44.58,252.29 },
		["4"] = { 269.53,-322.4,44.58,252.29 },
		["5"] = { 270.77,-319.14,44.58,252.29 }
	},
	["5"] = { x = 596.43, y = 90.68, z = 93.13,
		["1"] = { 599.82,102.03,92.57,249.45 },
		["2"] = { 598.69,98.42,92.57,249.45 }
	},
	["6"] = { x = -340.57, y = 266.04, z = 85.68,
		["1"] = { -349.47,272.54,84.77,272.13 },
		["2"] = { -349.5,275.91,84.69,272.13 },
		["3"] = { -349.56,279.3,84.62,272.13 },
		["4"] = { -349.67,282.6,84.59,274.97 },
		["5"] = { -349.74,286.16,84.59,272.13 },
		["6"] = { -349.8,289.76,84.6,272.13 },
		["7"] = { -349.85,293.28,84.6,272.13 },
		["8"] = { -349.87,296.72,84.6,272.13 }
	},
	["7"] = { x = -2030.03, y = -465.99, z = 11.59,
		["1"] = { -2037.4,-461.02,11.07,138.9 },
		["2"] = { -2039.78,-459.07,11.07,138.9 },
		["3"] = { -2042.12,-457.1,11.07,138.9 },
		["4"] = { -2044.47,-455.11,11.07,138.9 },
		["5"] = { -2046.85,-453.09,11.07,138.9 },
		["6"] = { -2049.12,-451.17,11.07,138.9 },
		["7"] = { -2051.51,-449.23,11.07,138.9 }
	},
	["8"] = { x = -1184.94, y = -1509.99, z = 4.65,
		["1"] = { -1183.29,-1495.81,4.04,121.89 },
		["2"] = { -1185.23,-1493.28,4.04,121.89 },
		["3"] = { -1186.87,-1490.71,4.04,121.89 },
		["4"] = { -1188.69,-1488.27,4.04,121.89 }
	},
	["9"] = { x = 101.23, y = -1073.64, z = 29.37,
		["1"] = { 105.9,-1063.14,28.88,246.62 },
		["2"] = { 107.42,-1059.61,28.88,246.62 },
		["3"] = { 108.88,-1056.23,28.88,246.62 },
		["4"] = { 110.27,-1052.86,28.88,246.62 }
	},
	["10"] = { x = 213.97, y = -808.43, z = 31.0,
		["1"] = { 221.93,-804.11,30.35,249.45 },
		["2"] = { 222.9,-801.61,30.33,249.45 },
		["3"] = { 223.92,-799.2,30.33,249.45 },
		["4"] = { 224.85,-796.69,30.33,249.45 }
	},
	["11"] = { x = -348.89, y = -874.02, z = 31.31,
		["1"] = { -343.62,-875.51,30.75,167.25 },
		["2"] = { -339.98,-876.27,30.75,167.25 },
		["3"] = { -336.35,-876.98,30.75,167.25 },
		["4"] = { -332.72,-877.71,30.75,167.25 }
	},
	["12"] = { x = 67.72, y = 12.3, z = 69.22,
		["1"] = { 63.87,16.5,68.87,340.16 },
		["2"] = { 60.78,17.6,68.92,340.16 },
		["3"] = { 57.76,18.76,69.03,340.16 },
		["4"] = { 54.8,19.92,69.25,340.16 }
	},
	["13"] = { x = 361.96, y = 297.8, z = 103.88,
		["1"] = { 371.06,284.68,102.94,340.16 },
		["2"] = { 374.8,283.39,102.85,340.16 },
		["3"] = { 378.62,282.06,102.78,340.16 }
	},
	["14"] = { x = 1035.84, y = -763.87, z = 58.0,
		["1"] = { 1046.56,-774.55,57.69,90.71 },
		["2"] = { 1046.56,-778.24,57.68,90.71 },
		["3"] = { 1046.55,-782.0,57.68,90.71 },
		["4"] = { 1046.54,-785.65,57.66,90.71 }
	},
	["15"] = { x = -796.69, y = -2022.85, z = 9.17,
		["1"] = { -779.77,-2040.03,8.56,314.65 },
		["2"] = { -777.36,-2042.58,8.56,314.65 },
		["3"] = { -774.92,-2044.9,8.56,314.65 }
	},
	["16"] = { x = 453.28, y = -1146.77, z = 29.5,
		["1"] = { 467.33,-1151.89,28.96,85.04 },
		["2"] = { 467.16,-1154.75,28.96,85.04 },
		["3"] = { 467.1,-1157.73,28.96,87.88 }
	},
	["17"] = { x = 528.65, y = -146.25, z = 58.37,
		["1"] = { 540.99,-136.2,59.13,178.59 },
		["2"] = { 544.84,-136.25,59.01,178.59 },
		["3"] = { 548.83,-136.31,59.01,181.42 },
		["4"] = { 552.81,-136.41,58.99,178.59 }
	},
	["18"] = { x = -1159.56, y = -739.39, z = 19.88,
		["1"] = { -1144.95,-745.49,19.34,104.89 },
		["2"] = { -1142.76,-748.44,19.19,107.72 },
		["3"] = { -1140.18,-751.41,19.06,107.72 },
		["4"] = { -1137.99,-754.36,18.91,107.72 },
		["5"] = { -1135.43,-757.3,18.75,107.72 },
		["6"] = { -1133.12,-760.4,18.59,107.72 },
		["7"] = { -1130.59,-763.27,18.43,107.72 }
	},
	["19"] = { x = -791.48, y = 336.48, z = 85.7,
		["1"] = { -791.64,331.67,85.38,181.42 }
	},
	["20"] = { x = -800.45, y = 336.61, z = 85.7,
		["1"] = { -800.38,331.9,85.38,181.42 }
	},
	["21"] = { x = 935.95, y = 0.36, z = 78.76,
		["1"] = { 933.29,-3.74,78.44,147.41 }
	},
	["22"] = { x = 1725.21, y = 4711.77, z = 42.11,
		["1"] = { 1722.82,4700.38,42.28,87.88 }
	},
	["23"] = { x = 1624.05, y = 3566.14, z = 35.15,
		["1"] = { 1633.27,3563.91,34.91,303.31 }
	},
	["24"] = { x = 1143.8, y = 2667.46, z = 38.15,
		["1"] = { 1137.41,2674.26,37.83,0.0 }
	},
	["25"] = { x = -73.35, y = -2004.6, z = 18.27,
		["1"] = { -59.61,-1990.85,17.69,155.91 },
		["2"] = { -63.69,-1989.71,17.69,167.25 },
		["3"] = { -67.6,-1989.01,17.69,170.08 },
		["4"] = { -71.34,-1988.57,17.69,172.92 },
		["5"] = { -74.96,-1988.07,17.69,170.08 },
		["6"] = { -78.64,-1987.63,17.69,170.08 },
		["7"] = { -82.27,-1987.19,17.69,170.08 }
	},
	["26"] = { x = 1200.52, y = -1276.06, z = 35.22,
		["1"] = { 1206.23,-1270.21,35.03,175.75 }
	},
	["27"] = { x = -1032.69, y = -2731.05, z = 13.75,
		["1"] = { -1024.5928,-2728.4897,12.8659,238.69 },
		["2"] = { -1019.0021,-2731.7905,12.8631,238.82 },
		["3"] = { -1013.3653,-2734.7886,12.868,239.27 }
	},
	-- Garagem padrao do Hospital SAMU (Ouro Fino)
	["200"] = { x = -663.29, y = 334.73, z = 78.12,
		["1"] = { -658.1634,349.7439,77.316,175.91 },
		["2"] = { -661.4263,350.3895,77.3227,174.05 },
		["3"] = { -664.7061,350.4211,77.3165,176.42 },
		["4"] = { -668.1113,350.6783,77.3156,174.98 }
	},
	-- Garagem de viaturas do SAMU (Ouro Fino) - apenas veiculos de servico do hospital
	["201"] = { x = -687.33, y = 340.5, z = 78.12,
		["1"] = { -688.9399,352.0009,77.3155,176.11 },
		["2"] = { -685.3603,352.0512,77.3155,176.19 },
		["3"] = { -681.7809,351.797,77.3166,173.94 },
		["4"] = { -684.8823,359.0199,77.316,175.19 }
	},
	["41"] = { x = 294.77, y = -1447.93, z = 29.96,
		["1"] = { 298.09,-1442.67,29.57,232.45 }
	},
	["42"] = { x = 318.85, y = -1457.86, z = 46.51,
		["1"] = { 313.3,-1465.02,46.89,138.9 }
	},
	["121"] = { x = -1728.06, y = -1050.69, z = 1.7,
		["1"] = { -1734.05,-1057.01,0.94,133.23 }
	},
	["122"] = { x = -776.63, y = -1494.93, z = 2.29,
		["1"] = { -786.5,-1498.89,-0.57,110.56 }
	},
	["123"] = { x = -895.04, y = 5687.46, z = 3.03,
		["1"] = { -907.5,5684.52,0.76,102.05 }
	},
	["124"] = { x = 1509.64, y = 3788.7, z = 33.51,
		["1"] = { 1493.4,3797.23,29.89,50.19 }
	},
	["131"] = { x = -1896.42, y = -3032.01, z = 13.93,
		["1"] = { -1890.65,-3045.12,14.61,150.24 }
	},
	["140"] = { x = -615.63, y = -907.18, z = 24.15,
		["1"] = { -615.82,-911.88,23.44,104.89 },
		["2"] = { -615.73,-916.04,23.13,107.72 },
		["3"] = { -615.63,-920.3,22.83,110.56 }
	},
	["141"] = { x = 1961.97, y = 5181.03, z = 47.95,
		["1"] = { 1967.33,5179.34,47.06,158.75 }
	},
	["143"] = { x = -341.45, y = -1567.52, z = 25.22,
		["1"] = { -346.4,-1560.42,24.95,93.55 }
	},
	["144"] = { x = 355.15, y = 275.79, z = 103.15,
		["1"] = { 359.95,272.31,102.72,340.16 },
		["2"] = { 364.05,270.74,102.68,340.16 },
		["3"] = { 368.1,269.31,102.67,340.16 }
	},
	["145"] = { x = 19.43, y = 6510.93, z = 31.49,
		["1"] = { 28.38,6511.73,31.14,42.52 }
	},
	["146"] = { x = 1241.65, y = -3262.85, z = 5.53,
		["1"] = { 1271.56,-3287.96,6.10,91.00 },
		["2"] = { 1271.82,-3282.63,6.10,91.00 },
		["3"] = { 1271.95,-3271.04,6.10,91.00 },
		["4"] = { 1272.11,-3266.03,6.10,91.00 }
	},
	["147"] = { x = 905.6, y = -165.08, z = 74.11,
		["1"] = { 911.7178,-164.5945,73.9335,15.55 },
		["2"] = { 913.733,-160.427,74.3389,12.31 },
		["3"] = { 916.2238,-170.6808,74.0342,282.11 },
		["4"] = { 918.4755,-167.0511,74.2394,282.37 }
	},
	["148"] = { x = 68.21, y = 124.82, z = 79.18,
		["1"] = { 72.19,120.91,79.08,158.75 },
		["2"] = { 61.84,124.32,79.09,158.75 }
	},
	["149"] = { x = -223.09, y = -1370.69, z = 31.26,
		["1"] = { -220.45,-1361.2,31.34,209.77 }
	},
	["150"] = { x = 977.78, y = -2220.77, z = 31.54,
		["1"] = { 972.99,-2220.39,30.53,85.04 }
	},
    ["153"] = { x = 288.16, y = -1251.2, z = 29.44,
        ["1"] = { 289.67,-1244.94,29.34,87.88 }
    },
    ["154"] = { x = 2670.53, y = 3260.38, z = 55.23,
        ["1"] = { 2668.32,3255.17,55.32,243.78 }
    },
    ["155"] = { x = -2073.85, y = -322.89, z = 13.31,
        ["1"] = { -2078.5,-320.69,13.21,170.08 }
    },
    ["156"] = { x = -2535.48, y = 2317.42, z = 33.21,
        ["1"] = { -2536.97,2323.19,33.14,93.55 }
    },
    ["157"] = { x = 166.29, y = 6627.25, z = 31.76,
        ["1"] = { 161.45,6621.33,31.96,133.23 }
    },
    ["158"] = { x = 822.27, y = -1039.68, z = 26.74,
        ["1"] = { 827.25,-1041.63,27.06,0.0 }
    },
    ["159"] = { x = 1215.24, y = -1389.33, z = 35.37,
        ["1"] = { 1211.83,-1393.66,35.3,272.13 }
    },
    ["160"] = { x = 1168.42, y = -325.26, z = 69.29,
        ["1"] = { 1165.75,-330.85,69.03,99.22 }
    },
    ["161"] = { x = 647.78, y = 271.98, z = 103.29,
        ["1"] = { 645.97,278.46,103.24,150.24 }
    },
    ["162"] = { x = 2562.11, y = 376.05, z = 108.61,
        ["1"] = { 2564.97,373.38,108.55,357.17 }
    },
    ["163"] = { x = 161.56, y = -1560.11, z = 29.25,
        ["1"] = { 164.35,-1561.99,29.34,130.4 }
    },
    ["164"] = { x = -341.53, y = -1490.28, z = 30.75,
        ["1"] = { -336.75,-1492.78,30.7,0.0 }
    },
    ["165"] = { x = 1773.82, y = 3332.76, z = 41.35,
        ["1"] = { 1777.15,3334.74,41.27,25.52 }
    },
    ["166"] = { x = 42.33, y = 2791.06, z = 57.88,
        ["1"] = { 37.61,2788.99,57.96,138.9 }
    },
    ["167"] = { x = 252.55, y = 2596.21, z = 44.87,
        ["1"] = { 254.38,2600.91,44.97,99.22 }
    },
    ["168"] = { x = 1033.34, y = 2663.29, z = 39.55,
        ["1"] = { 1029.67,2660.04,39.63,0.0 }
    },
    ["169"] = { x = 1208.15, y = 2650.15, z = 37.84,
        ["1"] = { 1208.31,2646.66,37.93,317.49 }
    },
    ["170"] = { x = 2546.44, y = 2583.0, z = 37.95,
        ["1"] = { 2540.21,2586.02,38.03,87.88 }
    },
    ["171"] = { x = 1993.15, y = 3777.1, z = 32.18,
        ["1"] = { 1989.57,3775.34,32.27,212.6 }
    },
    ["172"] = { x = 1703.17, y = 4938.19, z = 42.07,
        ["1"] = { 1701.88,4947.45,42.66,51.03 }
    },
    ["173"] = { x = 1709.83, y = 6422.8, z = 32.64,
        ["1"] = { 1713.09,6417.86,33.04,153.08 }
    },
    ["174"] = { x = -99.04, y = 6405.97, z = 31.63,
        ["1"] = { -101.81,6408.04,31.56,317.49 }
    },
    ["175"] = { x = -1815.67, y = 793.96, z = 138.07,
        ["1"] = { -1814.22,787.13,137.83,221.11 }
    },
    ["176"] = { x = -1437.53, y = -259.35, z = 46.27,
        ["1"] = { -1438.85,-255.53,46.34,133.23 }
    },
    ["177"] = { x = -705.78, y = -917.48, z = 19.21,
        ["1"] = { -708.47,-922.69,19.09,181.42 }
    },
    ["178"] = { x = -539.24, y = -1216.2, z = 18.45,
        ["1"] = { -540.85,-1212.73,18.23,334.49 }
    },
    ["179"] = { x = -52.6, y = -1769.92, z = 29.18,
        ["1"] = { -52.85,-1761.05,29.15,48.19 }
    },
    ["202"] = { x = -57.01, y = -1104.06, z = 26.44,
        ["1"] = { -56.4074,-1116.52,26.0338,2.08 },
        ["2"] = { -53.6217,-1116.0533,26.0344,2.28 },
        ["3"] = { -50.6231,-1115.8016,26.0346,4.22 },
        ["4"] = { -47.7918,-1115.9752,26.0339,2.53 }
    },
	["203"] = { x = -552.42, y = -914.86, z = 23.86,
		["1"] = { -537.8771,-904.736,23.3956,59.1 },
		["2"] = { -540.155,-908.473,23.3938,59.18 },
		["3"] = { -542.4011,-911.8967,23.3939,59.57 },
		["4"] = { -543.3444,-915.8871,23.3944,60.29 }
	},
	-- Departamento de Policia mapPM
	["210"] = { x = -434.8, y = 1123.9, z = 325.86, Marker = 36,
		["1"] = { -449.3146,1133.5408,325.5169,344.18 },
		["2"] = { -452.3425,1133.3406,325.5176,344.18 },
		["3"] = { -455.2379,1134.4304,325.5174,344.43 },
		["4"] = { -458.2164,1135.0807,325.5175,345.27 },
		["5"] = { -461.0784,1135.7307,325.5172,344.37 },
		["6"] = { -463.8383,1136.7209,325.5174,343.97 }
	},
	["211"] = { x = -429.07, y = 1204.3, z = 325.76, Marker = 36,
		["1"] = { -421.4783,1197.9541,325.2562,50.14 },
		["2"] = { -419.9512,1201.9954,325.1751,47.47 },
		["3"] = { -419.1333,1206.1405,325.1745,53.99 }
	},
	["212"] = { x = -436.7, y = 1110.0, z = 335.11, Marker = 36,
		["1"] = { -431.8215,1102.8917,335.5166,280.55 }
	},
	-- Favela São Judas
	["213"] = { x = -441.61, y = 1606.91, z = 360.52, Marker = 36,
		["1"] = { -440.3703,1600.1744,359.8811,123.21 },
		["2"] = { -428.9143,1601.7655,359.8808,80.08 },
		["3"] = { -419.5441,1595.3765,359.8803,36.3 }
	},
	["214"] = { x = -526.7, y = 1450.74, z = 387.01, Marker = 36,
		["1"] = { -515.7281,1451.6301,387.6732,182.09 }
	},
	["215"] = { x = -334.2, y = 1536.48, z = 367.34, Marker = 36,
		["1"] = { -332.0385,1528.5059,366.5429,108.94 },
		["2"] = { -331.2238,1525.0847,366.5429,108.73 },
		["3"] = { -314.2583,1535.0936,366.5427,109.89 },
		["4"] = { -313.3527,1531.7058,366.5428,108.46 }
	},
	-- Favela Pombal
	["216"] = { x = 2492.22, y = 2463.06, z = 52.86, Marker = 36,
		["1"] = { 2484.2751,2459.8269,52.4515,111.05 },
		["2"] = { 2483.1787,2462.623,52.4527,111.97 },
		["3"] = { 2482.1919,2465.4226,52.4514,112.22 },
		["4"] = { 2480.905,2468.2837,52.4507,111.73 }
	},
	-- Garagem publica - estacionamento -290/-985
	["217"] = { x = -290.03, y = -985.74, z = 31.07, Marker = 36,
		["1"] = { -297.8485,-990.5114,30.3705,341.27 },
		["2"] = { -301.3759,-989.3566,30.3702,338.36 },
		["3"] = { -304.821,-988.0201,30.3701,341.0 }
	}
}

local StaticGarages = {}
local InvalidGarageWarnings = {}
local InvalidRespawnWarnings = {}

for Number,Data in pairs(Garages) do
	StaticGarages[Number] = Data
end

local function ReadCoords(Data)
	if not Data then
		return nil
	end

	local DataType = type(Data)
	if DataType ~= "table" and DataType ~= "vector3" and DataType ~= "vector4" then
		return nil
	end

	local X = tonumber(Data.x or Data[1])
	local Y = tonumber(Data.y or Data[2])
	local Z = tonumber(Data.z or Data[3])
	if not X or not Y or not Z then
		return nil
	end

	return vec3(X,Y,Z)
end

local function WarnInvalid(Storage,Kind,Identifier)
	Identifier = tostring(Identifier or "desconhecido")
	if Storage[Identifier] then
		return
	end

	Storage[Identifier] = true
	print(("[garages] %s invalido ignorado: %s"):format(Kind,Identifier))
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- SPAWNPOSITION
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.SpawnPosition(Select)
	Select = tostring(Select or "")
	if not Garages[Select] then
		TriggerEvent("Notify","Atencao","Garagem indisponivel no momento.","default",5000)
		print(("[garages] Spawn negado: garagem %s nao encontrada."):format(Select))
		return false
	end

	if not ReadCoords(Garages[Select]["1"]) then
		TriggerEvent("Notify","Atencao","As vagas desta garagem estao invalidas.","default",5000)
		WarnInvalid(InvalidGarageWarnings,"vagas da garagem",Select)
		return false
	end

	local Checks = 0
	local Selected,Position

	repeat
		Checks = Checks + 1
		local Slot = tostring(Checks)

		if Garages[Select] and Garages[Select][Slot] then
			local SlotData = Garages[Select][Slot]
			local Coords = ReadCoords(SlotData)
			local Heading = tonumber(SlotData.w or SlotData[4])
			if not Coords or not Heading then
				WarnInvalid(InvalidGarageWarnings,"vaga da garagem",Select..":"..Slot)
				return false
			end

			Selected = vec4(Coords.x,Coords.y,Coords.z,Heading)
			Position = GetClosestVehicle(Coords.x,Coords.y,Coords.z,2.75,0,127)
		end
	until not DoesEntityExist(Position) or not Garages[Select][tostring(Checks)]

	if not Garages[Select][tostring(Checks)] then
		TriggerEvent("Notify","Atenção","Todas as vagas estão ocupadas.","default",5000)

		return false
	end

	SendNUIMessage({ Action = "Close" })
	SetNuiFocus(false,false)
	Opened = false

	return Selected
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- CREATEVEHICLE
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.CreateVehicle(Model,Network,Engine,Health,Customize,Windows,Tyres)
	if not NetworkDoesNetworkIdExist(Network) then
		return false
	end

	local Vehicle = NetToEnt(Network)
	if not DoesEntityExist(Vehicle) then
		return false
	end

	Wait(500)

	SetVehicleOnGroundProperly(Vehicle)
	SetEntityAsMissionEntity(Vehicle,true,true)
	SetNetworkIdExistsOnAllMachines(Network,true)
	SetVehicleEngineOn(Vehicle,true,true,true)
	SetVehicleEngineHealth(Vehicle,Engine + 0.0)
	SetVehicleHasBeenOwnedByPlayer(Vehicle,true)
	SetVehicleNeedsToBeHotwired(Vehicle,false)
	SetEntityCleanupByEngine(Vehicle,true)
	SetNetworkIdCanMigrate(Network,true)
	SetVehRadioStation(Vehicle,"OFF")
	SetEntityHealth(Vehicle,Health)

	TriggerEvent("lscustoms:Apply",Vehicle,Customize)

	Wait(500)

	if Windows then
		local DecodedWindows = json.decode(Windows)
		if DecodedWindows then
			for Index,v in pairs(DecodedWindows) do
				if not v then
					RemoveVehicleWindow(Vehicle,tonumber(Index))
				end
			end
		end
	end

	if Tyres then
		local DecodedTyres = json.decode(Tyres)
		if DecodedTyres then
			for Index,Burst in pairs(DecodedTyres) do
				if Burst then
					SetVehicleTyreBurst(Vehicle,tonumber(Index),true,1000.0)
				end
			end
		end
	end

	SetModelAsNoLongerNeeded(Model)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- GARAGES:DELETE
-----------------------------------------------------------------------------------------------------------------------------------------
local StorageSlotRadius = 2.75

local function StorageVehicleValid(Vehicle)
	if not Vehicle or Vehicle == 0 or not DoesEntityExist(Vehicle) or GetEntityType(Vehicle) ~= 2 or not IsEntityAVehicle(Vehicle) then
		return false
	end

	return not Entity(Vehicle).state.Tow or LocalPlayer.state.Admin
end

local function StorageSlotVehicles()
	local Garage = Opened and Garages[tostring(Opened)]
	if not Garage then
		return {}
	end

	local Slots = {}
	for Slot,Data in pairs(Garage) do
		local Coords = tonumber(Slot) and ReadCoords(Data)
		if Coords then
			Slots[#Slots + 1] = Coords
		end
	end

	local Candidates = {}
	local Added = {}

	for _,Vehicle in ipairs(GetGamePool("CVehicle")) do
		if StorageVehicleValid(Vehicle) then
			local VehicleCoords = GetEntityCoords(Vehicle)
			for _,SlotCoords in ipairs(Slots) do
				if #(VehicleCoords - SlotCoords) <= StorageSlotRadius then
					if not Added[Vehicle] then
						Added[Vehicle] = true
						Candidates[#Candidates + 1] = Vehicle
					end

					break
				end
			end
		end
	end

	return Candidates
end

local function StorageNetwork(Vehicle)
	local Timeout = GetGameTimer() + 750

	repeat
		if not DoesEntityExist(Vehicle) then
			return nil
		end

		local Network = NetworkGetNetworkIdFromEntity(Vehicle)
		if Network and Network > 0 and NetworkDoesNetworkIdExist(Network) and NetworkGetEntityFromNetworkId(Network) == Vehicle then
			return Network
		end

		Wait(50)
	until GetGameTimer() >= Timeout

	return nil
end

RegisterNetEvent("garages:Delete")
AddEventHandler("garages:Delete",function(Data,FromGarage)
	if not FromGarage then
		local Vehicle = Data
		if not Vehicle or Vehicle == "" then
			Vehicle = vRP.ClosestVehicle(15)
		end

		if IsEntityAVehicle(Vehicle) and (not Entity(Vehicle).state.Tow or LocalPlayer.state.Admin) then
			local Doors = {}
			for Number = 0,5 do
				Doors[Number] = IsVehicleDoorDamaged(Vehicle,Number)
			end

			local Tyres = {}
			for Number = 0,7 do
				Tyres[Number] = (GetTyreHealth(Vehicle,Number) ~= 1000.0 and true or false)
			end

			vSERVER.Delete(NetworkGetNetworkIdFromEntity(Vehicle),Doors,Tyres,GetVehicleNumberPlateText(Vehicle))
		end

		return
	end

	local Vehicle
	local Ped = PlayerPedId()
	local CurrentVehicle = GetVehiclePedIsIn(Ped,false)

	if CurrentVehicle ~= 0 then
		if not StorageVehicleValid(CurrentVehicle) then
			TriggerEvent("Notify","Atenção","Este veículo não pode ser guardado.","default",5000)
			return
		end

		Vehicle = CurrentVehicle
	elseif Opened then
		local Candidates = StorageSlotVehicles()
		if #Candidates == 1 then
			Vehicle = Candidates[1]
		elseif #Candidates > 1 then
			TriggerEvent("Notify","Atenção","Entre no veículo que deseja guardar e tente novamente.","default",5000)
			return
		else
			TriggerEvent("Notify","Atenção","Posicione o veículo em uma das vagas da garagem e tente novamente.","default",5000)
			return
		end
	end

	if not StorageVehicleValid(Vehicle) then
		TriggerEvent("Notify","Atenção","Não foi possível identificar um veículo válido.","default",5000)
		return
	end

	local Network = StorageNetwork(Vehicle)
	if not Network then
		TriggerEvent("Notify","Atenção","Não foi possível sincronizar o veículo. Tente novamente.","default",5000)
		return
	end

	local Doors = {}
	for Number = 0,5 do
		Doors[Number] = IsVehicleDoorDamaged(Vehicle,Number)
	end

	local Tyres = {}
	for Number = 0,7 do
		Tyres[Number] = (GetTyreHealth(Vehicle,Number) ~= 1000.0 and true or false)
	end

	vSERVER.Delete(Network,Doors,Tyres,GetVehicleNumberPlateText(Vehicle))
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- SEARCHBLIP
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.SearchBlip(Coords)
	if DoesBlipExist(Searched) then
		RemoveBlip(Searched)
		Searched = nil
	end

	if type(Coords) == "string" then
		if not Garages[Coords] then
			return false
		end

		Coords = vec3(Garages[Coords].x,Garages[Coords].y,Garages[Coords].z)
	end

	if not Coords then
		return false
	end

	Searched = AddBlipForCoord(Coords.x,Coords.y,Coords.z)
	SetBlipSprite(Searched,225)
	SetBlipColour(Searched,77)
	SetBlipScale(Searched,0.6)
	SetBlipAsShortRange(Searched,true)
	BeginTextCommandSetBlipName("STRING")
	AddTextComponentString("Veículo")
	EndTextCommandSetBlipName(Searched)

	SetTimeout(30000,function()
		if DoesBlipExist(Searched) then
			RemoveBlip(Searched)
		end

		Searched = nil
	end)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- STARTHOTWIRED
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.StartHotwired()
	local Ped = PlayerPedId()
	if not Hotwired and LoadAnim(Dict) then
		TaskPlayAnim(Ped,Dict,Anim,8.0,8.0,-1,49,1,0,0,0)
		Hotwired = true
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- STOPHOTWIRED
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.StopHotwired()
	local Ped = PlayerPedId()
	if Hotwired and LoadAnim(Dict) then
		StopAnimTask(Ped,Dict,Anim,8.0)
		Hotwired = false
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- UPDATEHOTWIRED
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.UpdateHotwired(Status)
	Hotwired = Status
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- REGISTERDECORS
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.RegisterDecors(Vehicle)
	SetVehicleHasBeenOwnedByPlayer(Vehicle,true)
	SetVehicleNeedsToBeHotwired(Vehicle,false)
	SetVehRadioStation(Vehicle,"OFF")
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- LOOPHOTWIRED
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	while true do
		local TimeDistance = 999
		local Ped = PlayerPedId()
		if LocalPlayer.state.Active and IsPedInAnyVehicle(Ped) then
			local Vehicle = GetVehiclePedIsUsing(Ped)
			if Vehicle then
				local Plate = GetVehicleNumberPlateText(Vehicle)
				if GetPedInVehicleSeat(Vehicle,-1) == Ped and Plate ~= "PDMSPORT" and not Entity(Vehicle).state.Lockpick then
					SetVehicleEngineOn(Vehicle,false,true,true)
					DisablePlayerFiring(Ped,true)
					TimeDistance = 1
				end

				if Hotwired and Vehicle then
					DisableControlAction(0,75,true)
					DisableControlAction(0,20,true)
					TimeDistance = 1
				end
			end
		end

		Wait(TimeDistance)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADOPEN
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	while true do
		local TimeDistance = 999
		local Ped = PlayerPedId()
		if LocalPlayer.state.Active and not IsPedInAnyVehicle(Ped) then
			local Coords = GetEntityCoords(Ped)

			for Number,v in pairs(Garages) do
				local GarageCoords = ReadCoords(v)
				if GarageCoords then
					local Distance = #(Coords - GarageCoords)
					if Distance <= 5.0 then
						TimeDistance = 1
						local Marker = tonumber(v.Marker) or 23
						if Marker == 36 then
							DrawMarker(36,GarageCoords.x,GarageCoords.y,GarageCoords.z + 0.35,0.0,0.0,0.0,0.0,0.0,0.0,1.1,1.1,1.1,88,101,242,210,false,true,2,true)
						else
							DrawMarker(Marker,GarageCoords.x,GarageCoords.y,GarageCoords.z - 0.95,0.0,0.0,0.0,0.0,0.0,0.0,1.75,1.75,0.0,88,101,242,175,false,false,2,false)
						end

						if Distance <= 2.0 then
							HelpText("Pressione ~INPUT_CONTEXT~ para acessar a ~b~garagem")
						end

						if Distance <= 1.25 and IsControlJustPressed(1,38) and not IsWanted() and not IsPhoneOpen() then
							local Vehicles = vSERVER.Vehicles(Number)
							if Vehicles then
								Opened = Number
								SetNuiFocus(true,true)
								TriggerEvent("target:Debug")
								SendNUIMessage({ Action = "Open", Payload = Vehicles })
							end
						end
					elseif Opened and Opened == Number then
						TriggerEvent("garages:Close")
					end
				else
					WarnInvalid(InvalidGarageWarnings,"garagem",Number)
				end
			end

			if Opened and not Garages[Opened] then
				TriggerEvent("garages:Close")
			end
		end

		Wait(TimeDistance)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADRESPAWNS
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	while true do
		local TimeDistance = 999
		local Ped = PlayerPedId()
		if LocalPlayer.state.Active and not IsPedInAnyVehicle(Ped) then
			local Coords = GetEntityCoords(Ped)

			for Plate,v in pairs(Respawns) do
				local RespawnCoords = ReadCoords(v)
				if RespawnCoords then
					local Distance = #(Coords - RespawnCoords)
					if Distance <= 25.0 then
						TimeDistance = 1
						DrawMarker(36,RespawnCoords.x,RespawnCoords.y,RespawnCoords.z,0.0,0.0,0.0,0.0,0.0,0.0,1.75,1.75,1.75,88,101,242,175,0,0,0,1)

						if Distance <= 1.25 and IsControlJustPressed(1,38) and Spam <= GetGameTimer() then
							Spam = GetGameTimer() + 5000
							TriggerServerEvent("garages:Respawns",Plate)
						end
					end
				else
					WarnInvalid(InvalidRespawnWarnings,"respawn",Plate)
					Respawns[Plate] = nil
				end
			end
		end

		Wait(TimeDistance)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADSTATICWATCHDOG
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	while true do
		Wait(10000)

		local Restored = 0
		for Number,Data in pairs(StaticGarages) do
			if not Garages[Number] then
				Garages[Number] = Data
				Restored = Restored + 1
			end
		end

		if Restored > 0 then
			print(("[garages] Watchdog restaurou %s garagem(ns) estatica(s)."):format(Restored))
		end
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- SPAWN
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("Spawn",function(Data,Callback)
	TriggerServerEvent("garages:Spawn",Data.Model,Opened)

	Callback("Ok")
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- DELETE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("Delete",function(Data,Callback)
	TriggerEvent("garages:Delete",nil,true)

	Callback("Ok")
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- TAX
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("Tax",function(Data,Callback)
	TriggerServerEvent("garages:Tax",Data.Model)

	Callback("Ok")
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- SELL
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("Sell",function(Data,Callback)
	if type(Data) ~= "table" or type(Data.Model) ~= "string" or Data.Model == "" then
		Callback({ Ack = true, Success = false, Message = "Veiculo invalido." })
		return
	end

	local Ok,Success,Message = pcall(vSERVER.Sell,Data.Model)
	Callback({
		Ack = Ok,
		Success = Ok and Success == true,
		Message = Ok and (Message or "Venda processada.") or "Erro de transporte ao processar a venda."
	})
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- TRANSFER
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("Transfer",function(Data,Callback)
	TriggerServerEvent("garages:Transfer",Data.Model)

	Callback("Ok")
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- CLOSE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("Close",function(Data,Callback)
	SetNuiFocus(false,false)
	Opened = false

	Callback("Ok")
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- GARAGES:CLOSE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("garages:Close")
AddEventHandler("garages:Close",function()
	SendNUIMessage({ Action = "Close" })
	SetNuiFocus(false,false)
	Opened = false
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- GARAGES:PROPERTYS
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("garages:Propertys")
AddEventHandler("garages:Propertys",function(GaragesTable,RespawnsTable)
	if type(GaragesTable) == "table" then
		for Name,v in pairs(GaragesTable) do
			local GarageCoords = ReadCoords(v)
			if GarageCoords and not StaticGarages[Name] then
				Garages[Name] = {
					x = GarageCoords.x,
					y = GarageCoords.y,
					z = GarageCoords.z,
					["1"] = v["1"]
				}
			elseif not GarageCoords then
				WarnInvalid(InvalidGarageWarnings,"garagem de propriedade",Name)
			end
		end
	end

	if type(RespawnsTable) == "table" then
		Respawns = RespawnsTable
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- GARAGES:CLEAN
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("garages:Clean")
AddEventHandler("garages:Clean",function(Name)
	if StaticGarages[Name] then
		print(("[garages] Remocao ignorada para garagem estatica %s."):format(tostring(Name)))
		return
	end

	if Garages[Name] then
		Garages[Name] = nil
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- GARAGES:CLOSE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("garages:Respawn")
AddEventHandler("garages:Respawn",function(Mode,Plate,Coords)
	if Mode == "Add" then
		if ReadCoords(Coords) then
			Respawns[Plate] = Coords
		else
			WarnInvalid(InvalidRespawnWarnings,"respawn recebido",Plate)
		end
	elseif Mode == "Remove" then
		Respawns[Plate] = nil
	end
end)

RegisterCommand("garagesstatus",function()
	local StaticCount = 0
	local ActiveStaticCount = 0
	local DynamicCount = 0
	local RespawnCount = 0

	for Number in pairs(StaticGarages) do
		StaticCount = StaticCount + 1
		if Garages[Number] then
			ActiveStaticCount = ActiveStaticCount + 1
		end
	end

	for Number in pairs(Garages) do
		if not StaticGarages[Number] then
			DynamicCount = DynamicCount + 1
		end
	end

	for _ in pairs(Respawns) do
		RespawnCount = RespawnCount + 1
	end

	print(("[garages] status: static=%s/%s dynamic=%s respawns=%s opened=%s active=%s"):format(
		ActiveStaticCount,
		StaticCount,
		DynamicCount,
		RespawnCount,
		tostring(Opened),
		tostring(LocalPlayer.state.Active)
	))
end,false)
