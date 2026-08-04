local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")

vRP = Proxy.getInterface("vRP")
fclient = Tunnel.getInterface("nation_concessionaria")

func = {}
Tunnel.bindInterface("nation_concessionaria",func)

local conceVehicles = {}
local userVehicles = {}
local PurchasePassportLocks = {}
local PurchaseModelLocks = {}
local makeVec3 = vec3 or vector3

config = config or {}
config.imgDir = config.imgDir or "nui://nation_concessionaria/vrp_images/"
config.logo = config.logo or "nui://nation_concessionaria/vrp_images/panto.png"
config.defaultImg = config.defaultImg or "nui://nation_concessionaria/vrp_images/blank.gif"
config.topVehicles = config.topVehicles or { "panto" }
config.openconce_permission = config.openconce_permission or nil
config.updateconce_permission = config.updateconce_permission or "Admin"
config.porcentagem_venda = config.porcentagem_venda or 50
config.porcentagem_testdrive = config.porcentagem_testdrive or 0.1
config.tempo_testdrive = config.tempo_testdrive or 30
config.maxDistance = config.maxDistance or 300
config.porcentagem_aluguel = config.porcentagem_aluguel or 1
config.defaultVehiclePrice = config.defaultVehiclePrice or 100000
config.defaultVehicleWeight = config.defaultVehicleWeight or 40
config.vehList = config.vehList or {}
config.descontos = config.descontos or {}
config.conceClasses = config.conceClasses or {
	{ class = "compactos", img = "nui://nation_concessionaria/vrp_images/panto.png" },
	{ class = "sedans", img = "nui://nation_concessionaria/vrp_images/cog552.png" },
	{ class = "suvs", img = "nui://nation_concessionaria/vrp_images/dubsta.png" },
	{ class = "imports", img = "nui://nation_concessionaria/vrp_images/zentorno.png" },
	{ class = "trucks", img = "nui://nation_concessionaria/vrp_images/mule.png" },
	{ class = "motos", img = "nui://nation_concessionaria/vrp_images/bati.png" },
	{ class = "outros", img = "nui://nation_concessionaria/vrp_images/burrito.png" }
}
config.availableClasses = config.availableClasses or {
	compactos = { "compact", "Compactos" },
	sedans = { "sedan", "Sedans" },
	suvs = { "suv", "off-road", "SUVs", "Off-Road" },
	imports = { "coupe", "muscle", "classic", "sport", "super", "Premium", "Vip", "Standard", "Esportivos", "Classicos", "Clássicos", "Importados" },
	motos = { "moto", "cycle" },
	trucks = { "industrial", "utility", "commercial" },
	outros = { "van", "service", "emergency", "military", "boat", "helicopter", "plane", "none", "Desconhecido", "outros" }
}
config.miscIcons = config.miscIcons or {}
config.myVehicles_img = config.myVehicles_img or "nui://nation_concessionaria/vrp_images/d7club8.png"
config.vehicleClasses = config.vehicleClasses or {
	[0] = "compact",
	[1] = "sedan",
	[2] = "suv",
	[3] = "coupe",
	[4] = "muscle",
	[5] = "classic",
	[6] = "sport",
	[7] = "super",
	[8] = "moto",
	[9] = "off-road",
	[10] = "industrial",
	[11] = "utility",
	[12] = "van",
	[13] = "cycle",
	[14] = "boat",
	[15] = "helicopter",
	[16] = "plane",
	[17] = "service",
	[18] = "emergency",
	[19] = "military",
	[20] = "commercial",
	[21] = "train"
}

config.ofPlans = config.ofPlans or {
	premium = {
		label = "Premium",
		salary = 15000,
		weaponLicense = true,
		vehicles = { "prototipo", "zentorno", "elegy2", "bmws", "p1", "baller6", "patriot2", "1016urus", "z1000", "supervolito2", "amarok" }
	},
	vip = {
		label = "VIP",
		salary = 10000,
		weaponLicense = true,
		vehicles = { "1016urus", "bmws", "lp700r", "r6", "urus2018", "baller4", "patriot", "nero2", "supervolito2", "amarok" }
	},
	standard = {
		label = "Standard",
		salary = 5000,
		weaponLicense = false,
		vehicles = { "omnis", "seven70", "x6m", "baller2", "i8", "g65amg", "kuruma" }
	}
}

local function MakeSet(list)
	local set = {}

	for _,model in ipairs(list or {}) do
		set[tostring(model):lower()] = true
	end

	return set
end

local RemovedVehicleSet = MakeSet({
	"gtr", "150", "488", "r1", "2f2fgtr34", "skyliner34", "aperta", "vantage",
	"bmwg20", "c7", "cbtwister", "cooperworks", "cox2013", "cx75", "d99", "ds4", "ds7", "f812",
	"fpacehm", "fx4", "gcr2", "hayabusa", "hilux2019", "hyrod", "jeepreneg", "macanturbo", "macla", "mgt",
	"nh2r", "pajero4", "panamera17turbo", "polo2018", "prius", "punto", "q7w", "rabike", "raiden2", "ram2500",
	"rr12", "santafe", "sont18", "str20", "taipam", "tmax", "trhawk", "vwgolf", "wraith", "rc", "zx10", "zx10r"
})

local PlanVehicleSet = {}
for _,plan in pairs(config.ofPlans) do
	for _,model in ipairs(plan.vehicles or {}) do
		PlanVehicleSet[tostring(model):lower()] = true
	end
end

config.exclusivePlanVehicles = config.exclusivePlanVehicles or PlanVehicleSet
config.classOverrides = config.classOverrides or {
	moto = MakeSet({ "bmws", "r1", "20r1", "r6", "z1000", "s1000rr", "hcbr17", "akuma", "avarus", "bagger", "bati", "bati2", "bf400", "carbonrs", "chimera", "daemon", "daemon2", "defiler", "double", "faggio", "hakuchou", "hakuchou2", "manchez", "pcj", "sanchez", "sanchez2", "shotaro", "vader", "vortex" }),
	suv = MakeSet({ "1016urus", "urus2018", "amarok", "x6m", "g65", "g65amg", "baller", "baller2", "baller3", "baller4", "baller5", "baller6", "patriot", "patriot2", "bjxl", "cavalcade", "cavalcade2", "contender", "dubsta", "dubsta2", "dubsta3", "fq2", "granger", "gresley", "habanero", "mesa3", "seminole", "serrano", "xls", "xls2", "toros", "freecrawler", "kamacho" }),
	sport = MakeSet({ "prototipo", "zentorno", "elegy", "elegy2", "p1", "gp1", "lp700r", "nero", "nero2", "omnis", "seven70", "2f2fgtr34", "gtr", "kuruma", "i8", "bmwi8", "d7club8", "adder", "banshee", "banshee2", "carbonizzare", "cheetah", "comet2", "comet3", "comet5", "coquette", "cyclone", "entityxf", "italigtb", "italigtb2", "jester", "jester2", "le7b", "massacro", "massacro2", "nero", "neon", "osiris", "pariah", "reaper", "t20", "turismor", "vagner", "xa21" }),
	truck = MakeSet({ "mule", "mule2", "mule3", "mule4", "rallytruck", "flatbed", "flatbed3", "towtruck", "towtruck2", "phantom", "packer", "benson", "biff", "hauler", "pounder", "rubble", "tiptruck", "tiptruck2", "trash", "trash2" })
}
config.locais = config.locais or {
	{
		conce = makeVec3(-54.30,-1094.80,26.42),
		test_locais = {
			{ coords = makeVec3(-11.25,-1080.46,26.68), h = 129.4 },
			{ coords = makeVec3(-14.11,-1079.84,26.67), h = 122.02 },
			{ coords = makeVec3(-16.43,-1078.62,26.67), h = 126.74 },
			{ coords = makeVec3(-8.45,-1081.58,26.67), h = 117.45 }
		}
	}
}
config.getVehicleInfo = config.getVehicleInfo or function()
	return false
end

local function Notify(source,kind,message,time)
	local titles = {
		sucesso = "Sucesso",
		negado = "Aviso",
		aviso = "Aviso",
		importante = "Concessionaria"
	}

	local colors = {
		sucesso = "verde",
		negado = "vermelho",
		aviso = "amarelo",
		importante = "azul"
	}

	TriggerClientEvent("Notify",source,titles[kind] or "Concessionaria",message,colors[kind] or "amarelo",time or 5000)
end

local function Passport(source)
	return source and vRP.Passport(source)
end

local function ActiveCharacter(source,ExpectedPassport)
	source = tonumber(source)
	if not source or source <= 0 or GetPlayerName(source) == nil then
		return false
	end

	local CurrentPassport = Passport(source)
	if not CurrentPassport or (ExpectedPassport and CurrentPassport ~= ExpectedPassport) or vRP.Source(CurrentPassport) ~= source then
		return false
	end

	return CurrentPassport
end

local function NormalizeVehicleModel(model)
	if type(model) ~= "string" then
		return false
	end

	model = model:match("^%s*(.-)%s*$"):lower()
	if model == "" or #model > 80 or not model:match("^[%w_%-]+$") then
		return false
	end

	return model
end

local function PurchaseLog(status,stage,source,Passport,model,detail)
	detail = tostring(detail or "-"):gsub("[%c]"," "):sub(1,180)
	print(("[nation_concessionaria] action=purchase status=%s stage=%s source=%s passport=%s model=%s detail=%s"):format(
		tostring(status),
		tostring(stage),
		tostring(source),
		tostring(Passport),
		tostring(model),
		detail
	))
end

local function AcquirePurchaseLock(Passport,model)
	if PurchasePassportLocks[Passport] or PurchaseModelLocks[model] then
		return false
	end

	PurchasePassportLocks[Passport] = model
	PurchaseModelLocks[model] = Passport
	return true
end

local function ReleasePurchaseLock(Passport,model)
	if PurchasePassportLocks[Passport] == model then
		PurchasePassportLocks[Passport] = nil
	end

	if PurchaseModelLocks[model] == Passport then
		PurchaseModelLocks[model] = nil
	end
end

local function IsAdmin(Passport)
	return Passport == 1 or vRP.HasGroup(Passport,"Admin",1) or vRP.HasPermission(Passport,"Admin")
end

local function Money(value)
	return "$ "..tostring(parseInt(value or 0))
end

local function RegisteredVehicle(model)
	if not model then
		return false
	end

	local ok,result = pcall(function()
		return exports.vrp:VehicleExist(model)
	end)

	return ok and result ~= nil and result ~= false
end

local function NativeVehicleModel(model)
	if not RegisteredVehicle(model) then
		return false
	end

	local ok,result = pcall(function()
		return exports.vrp:VehicleModel(model)
	end)

	if not ok or type(result) ~= "string" or result == "" or #result > 80 or not result:match("^[%w_%-]+$") then
		return false
	end

	return result
end

local function VrpVehicleValue(exportName,model,fallback)
	if not model or not RegisteredVehicle(model) then
		return fallback
	end

	local ok,result = pcall(function()
		if exportName == "VehicleName" then
			return exports.vrp:VehicleName(model)
		elseif exportName == "VehiclePrice" then
			return exports.vrp:VehiclePrice(model)
		elseif exportName == "VehicleWeight" then
			return exports.vrp:VehicleWeight(model)
		elseif exportName == "VehicleClass" then
			return exports.vrp:VehicleClass(model)
		end
	end)

	if not ok or result == nil or result == false or result == "Desconhecido" then
		return fallback
	end

	return result
end

local function IsPlanVehicle(model)
	return model and config.exclusivePlanVehicles and config.exclusivePlanVehicles[tostring(model):lower()] or false
end

local function IsRemovedVehicle(model)
	return model and RemovedVehicleSet[tostring(model):lower()] or false
end

local function NormalizeVehicleClass(value)
	if not value or value == "" then
		return nil
	end

	local class = tostring(value):lower()

	if class == "moto" or class == "motos" or class == "cycle" or class:find("moto",1,true) then
		return "moto"
	elseif class == "suv" or class == "suvs" or class == "off-road" or class:find("suv",1,true) then
		return "suv"
	elseif class == "truck" or class == "trucks" or class == "industrial" or class == "utility" or class == "commercial" or class == "work" then
		return "commercial"
	elseif class == "compact" or class == "compacto" or class == "compactos" then
		return "compact"
	elseif class == "sedan" or class == "sedans" then
		return "sedan"
	elseif class == "sport" or class == "super" or class == "classic" or class == "premium" or class == "vip" or class == "standard" or class:find("esport",1,true) or class:find("import",1,true) or class:find("class",1,true) then
		return "sport"
	elseif class == "carros" or class == "cars" then
		return nil
	end

	return value
end

local function ClassByModel(model)
	local key = tostring(model or ""):lower()
	local overrides = config.classOverrides or {}

	if overrides.moto and overrides.moto[key] then
		return "moto"
	elseif overrides.suv and overrides.suv[key] then
		return "suv"
	elseif overrides.sport and overrides.sport[key] then
		return "sport"
	elseif overrides.truck and overrides.truck[key] then
		return "commercial"
	end

	return nil
end

local function ResolveVehicleClass(model,row,info)
	return ClassByModel(model)
		or NormalizeVehicleClass(row and row.class)
		or NormalizeVehicleClass(VrpVehicleValue("VehicleClass",model,nil))
		or NormalizeVehicleClass(info and info.tipo)
		or "outros"
end

local function PrettyVehicleName(model)
	model = tostring(model or "")
	model = model:gsub("[_%-%s]+"," ")
	model = model:gsub("(%l)(%d)","%1 %2")
	model = model:gsub("(%d)(%l)","%1 %2")

	local pretty = model:gsub("(%a)([%w']*)",function(first,rest)
		return first:upper()..rest
	end)

	return pretty ~= "" and pretty or model
end

local function NumberOrDefault(value,default)
	value = parseInt(value or 0)

	if value <= 0 then
		return parseInt(default or 0)
	end

	return value
end

local function PublicConfig()
	local public = {}

	for key,value in pairs(config) do
		if type(value) ~= "function" then
			public[key] = value
		end
	end

	return public
end

local function VehicleInfo(model,row)
	if not model then
		return false
	end

	model = tostring(model)
	row = row or {}

	local info = config.getVehicleInfo(model)
	if info then
		local price = row.price or info.price or VrpVehicleValue("VehiclePrice",model,config.defaultVehiclePrice)
		local weight = row.weight or info.capacidade or VrpVehicleValue("VehicleWeight",model,config.defaultVehicleWeight)

		return {
			vehicle = model,
			name = info.name or model,
			modelo = row.name or info.modelo or VrpVehicleValue("VehicleName",model,PrettyVehicleName(model)),
			price = NumberOrDefault(price,config.defaultVehiclePrice),
			capacidade = NumberOrDefault(weight,config.defaultVehicleWeight),
			class = ResolveVehicleClass(model,row,info),
			registered = RegisteredVehicle(model)
		}
	end

	if RegisteredVehicle(model) then
		return {
			vehicle = model,
			name = model,
			modelo = row.name or VrpVehicleValue("VehicleName",model,PrettyVehicleName(model)),
			price = NumberOrDefault(row.price or VrpVehicleValue("VehiclePrice",model,config.defaultVehiclePrice),config.defaultVehiclePrice),
			capacidade = NumberOrDefault(row.weight or VrpVehicleValue("VehicleWeight",model,config.defaultVehicleWeight),config.defaultVehicleWeight),
			class = ResolveVehicleClass(model,row,nil),
			registered = true
		}
	end

	return {
		vehicle = model,
		name = model,
		modelo = row.name or PrettyVehicleName(model),
		price = NumberOrDefault(row.price,config.defaultVehiclePrice),
		capacidade = NumberOrDefault(row.weight,config.defaultVehicleWeight),
		class = ResolveVehicleClass(model,row,nil),
		registered = false
	}
end

local function PrepareDatabase()
	vRP.Prepare("nation_conce/createDB",[[
		CREATE TABLE IF NOT EXISTS nation_concessionaria (
			vehicle VARCHAR(80) NOT NULL,
			estoque INT NOT NULL DEFAULT 0,
			price INT NULL DEFAULT NULL,
			name VARCHAR(120) NULL DEFAULT NULL,
			class VARCHAR(40) NULL DEFAULT NULL,
			weight INT NULL DEFAULT NULL,
			PRIMARY KEY (vehicle)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
	]])

	vRP.Prepare("nation_conce/addPriceColumn","ALTER TABLE nation_concessionaria ADD COLUMN IF NOT EXISTS price INT NULL DEFAULT NULL AFTER estoque")
	vRP.Prepare("nation_conce/addNameColumn","ALTER TABLE nation_concessionaria ADD COLUMN IF NOT EXISTS name VARCHAR(120) NULL DEFAULT NULL AFTER price")
	vRP.Prepare("nation_conce/addClassColumn","ALTER TABLE nation_concessionaria ADD COLUMN IF NOT EXISTS class VARCHAR(40) NULL DEFAULT NULL AFTER name")
	vRP.Prepare("nation_conce/addWeightColumn","ALTER TABLE nation_concessionaria ADD COLUMN IF NOT EXISTS weight INT NULL DEFAULT NULL AFTER class")
	vRP.Prepare("nation_conce/getConceVehicles","SELECT vehicle, estoque, price, name, class, weight FROM nation_concessionaria WHERE estoque > 0 ORDER BY vehicle ASC")
	vRP.Prepare("nation_conce/countVehicles","SELECT COUNT(*) FROM nation_concessionaria")
	vRP.Prepare("nation_conce/isVehicleInConce","SELECT vehicle, estoque FROM nation_concessionaria WHERE vehicle = @vehicle")
	vRP.Prepare("nation_conce/addVehicle","INSERT INTO nation_concessionaria(vehicle,estoque) VALUES(@vehicle,@estoque) ON DUPLICATE KEY UPDATE estoque = @estoque")
	vRP.Prepare("nation_conce/removeVehicle","DELETE FROM nation_concessionaria WHERE vehicle = @vehicle")
	vRP.Prepare("nation_conce/setEstoque","UPDATE nation_concessionaria SET estoque = @estoque WHERE vehicle = @vehicle")
	vRP.Prepare("nation_conce/removeOneEstoque","UPDATE nation_concessionaria SET estoque = GREATEST(estoque - 1,0) WHERE vehicle = @vehicle")
	vRP.Prepare("nation_conce/takeOneStock","UPDATE nation_concessionaria SET estoque = estoque - 1 WHERE vehicle = @vehicle AND estoque > 0")

	vRP.Execute("nation_conce/createDB")
	pcall(function() vRP.Execute("nation_conce/addPriceColumn") end)
	pcall(function() vRP.Execute("nation_conce/addNameColumn") end)
	pcall(function() vRP.Execute("nation_conce/addClassColumn") end)
	pcall(function() vRP.Execute("nation_conce/addWeightColumn") end)
end

local function SeedInitialVehicles()
	local total = parseInt(vRP.Scalar("nation_conce/countVehicles") or 0)
	if total > 0 then
		return
	end

	local inserted = 0
	local seen = {}

	for _,entry in ipairs(config.vehList or {}) do
		local model = entry.name
		if model and not seen[model] and not IsRemovedVehicle(model) and RegisteredVehicle(model) then
			seen[model] = true
			vRP.Execute("nation_conce/addVehicle",{ vehicle = model, estoque = 10 })
			inserted = inserted + 1
		end
	end

	for _,model in ipairs({ "panto", "d7club8", "1016urus" }) do
		if not seen[model] and not IsRemovedVehicle(model) and RegisteredVehicle(model) and not IsPlanVehicle(model) then
			seen[model] = true
			vRP.Execute("nation_conce/addVehicle",{ vehicle = model, estoque = 10 })
			inserted = inserted + 1
		end
	end

	print(("[nation_concessionaria] Banco iniciado com %s veiculos em estoque."):format(inserted))
end

local function AddConceVehicle(model,stock)
	local info = VehicleInfo(model)
	local stock = parseInt(stock or 1)

	if not info or stock <= 0 or IsPlanVehicle(model) or IsRemovedVehicle(model) then
		return false
	end

	vRP.Execute("nation_conce/addVehicle",{ vehicle = info.vehicle, estoque = stock })
	return true
end

function getDbVehicles()
	conceVehicles = {}

	local vehicles = vRP.Query("nation_conce/getConceVehicles") or {}
	for _,row in ipairs(vehicles) do
		local info = not IsPlanVehicle(row.vehicle) and not IsRemovedVehicle(row.vehicle) and VehicleInfo(row.vehicle,row)
		if info then
			conceVehicles[#conceVehicles + 1] = {
				vehicle = info.vehicle,
				price = info.price,
				modelo = info.modelo,
				capacidade = info.capacidade,
				name = info.name,
				estoque = parseInt(row.estoque or 0),
				class = info.class,
				registered = info.registered
			}
		end
	end

	print(("[nation_concessionaria] %s veiculos carregados do banco nation_concessionaria."):format(#conceVehicles))
end

local function getVehicleFromCache(model)
	for _,veh in ipairs(conceVehicles) do
		if veh.vehicle == model then
			return veh
		end
	end

	return false
end

local function getVehicleEstoque(model)
	local info = getVehicleFromCache(model)
	return info and parseInt(info.estoque or 0) or 0
end

local function getVehiclePrice(model)
	local info = getVehicleFromCache(model)
	return info and parseInt(info.price or 0) or 0
end

local function hasVehicle(Passport,model)
	return Passport and model and vRP.SelectVehicle(Passport,model) ~= nil
end

local function addUserVehicle(Passport,vehInfo)
	if Passport and userVehicles[Passport] and vehInfo then
		userVehicles[Passport][#userVehicles[Passport] + 1] = {
			vehicle = vehInfo.vehicle,
			price = parseInt(vehInfo.price * (config.porcentagem_venda / 100)),
			modelo = vehInfo.modelo,
			capacidade = vehInfo.capacidade,
			class = vehInfo.class
		}
	end
end

local function removeUserVehicle(Passport,model)
	if Passport and model and userVehicles[Passport] then
		for i,veh in ipairs(userVehicles[Passport]) do
			if veh.vehicle == model then
				table.remove(userVehicles[Passport],i)
				return
			end
		end
	end
end

local function setEstoque(model,stock)
	stock = math.max(parseInt(stock or 0),0)
	if IsPlanVehicle(model) then
		stock = 0
	end

	vRP.Execute("nation_conce/setEstoque",{ vehicle = model, estoque = stock })

	for i,veh in ipairs(conceVehicles) do
		if veh.vehicle == model then
			if stock <= 0 then
				table.remove(conceVehicles,i)
			else
				veh.estoque = stock
			end

			return true
		end
	end

	if stock > 0 then
		local info = VehicleInfo(model)
		if info then
			conceVehicles[#conceVehicles + 1] = {
				vehicle = info.vehicle,
				price = info.price,
				modelo = info.modelo,
				capacidade = info.capacidade,
				name = info.name,
				estoque = stock,
				class = info.class,
				registered = info.registered
			}
			return true
		end
	end

	return false
end

local function addEstoque(model,amount)
	amount = parseInt(amount or 1)
	if amount <= 0 then
		return false
	end

	local current = getVehicleEstoque(model)
	if current <= 0 then
		return AddConceVehicle(model,amount) and (getDbVehicles() or true)
	end

	return setEstoque(model,current + amount)
end

local function removeEstoque(model,amount)
	amount = parseInt(amount or 1)
	if amount <= 0 then
		return false
	end

	local current = getVehicleEstoque(model)
	if current <= 0 then
		return false
	end

	return setEstoque(model,current - amount)
end

local function registerPurchaseTax(Passport,model,price)
	if GetResourceState("bank") == "started" then
		return exports.bank:AddTaxes(Passport,"Concessionaria",price,"Compra do veiculo "..(exports.vrp:VehicleName(model) or model)..".")
	end

	return true
end

local function UpdatePurchasedStockCache(model)
	for index,vehicle in ipairs(conceVehicles) do
		if vehicle.vehicle == model then
			local stock = math.max(parseInt(vehicle.estoque or 0) - 1,0)
			if stock <= 0 then
				table.remove(conceVehicles,index)
			else
				vehicle.estoque = stock
			end

			return stock
		end
	end

	return 0
end

local function RefundPurchase(source,Passport,model,price,stage)
	local ok,result = pcall(vRP.GiveBank,Passport,price,true)
	if not ok then
		PurchaseLog("critical","payment_refund",source,Passport,model,result)
		return false
	end

	PurchaseLog("refunded",stage,source,Passport,model,price)
	return true
end

local function RemoveInsertedProperty(source,Passport,model,plate)
	local ok,affected = pcall(vRP.Update,"vehicles/removeVehicleExact",{
		Passport = Passport,
		Vehicle = model,
		Plate = plate
	})

	if not ok or tonumber(affected) ~= 1 then
		PurchaseLog("critical","property_rollback",source,Passport,model,ok and affected or affected)
		return false
	end

	return true
end

function func.getConfig()
	return PublicConfig()
end

RegisterServerEvent("nationConce:getConfig")
AddEventHandler("nationConce:getConfig",function()
	TriggerClientEvent("nationConce:setConfig",source,PublicConfig())
end)

function func.getVehInfo(model)
	return VehicleInfo(model)
end

function func.getConceVehicles()
	return conceVehicles
end

function func.getTopVehicles()
	local list = {}
	for _,veh in ipairs(conceVehicles) do
		list[#list + 1] = veh
	end

	table.sort(list,function(a,b)
		return parseInt(a.price or 0) > parseInt(b.price or 0)
	end)

	local top = {}
	for i = 1,math.min(5,#list) do
		top[#top + 1] = list[i]
	end

	return top
end

function func.getDiscount(id)
	local source = source
	local Passport = id or Passport(source)
	if not Passport then
		return 0
	end

	for _,entry in pairs(config.descontos or {}) do
		if entry.perm and vRP.HasPermission(Passport,entry.perm) then
			return math.max(0,math.min(100,parseInt(entry.porcentagem or 0)))
		end
	end

	return 0
end

local function processVehiclePurchase(requestSource,passport,model,color)
	if ActiveCharacter(requestSource,passport) ~= passport then
		return false,"personagem indisponivel"
	elseif IsRemovedVehicle(model) then
		return false,"veiculo removido da concessionaria"
	end

	local info = getVehicleFromCache(model)
	local NativeModel = NativeVehicleModel(model)
	local ownershipOk,owned = pcall(hasVehicle,passport,model)
	if not info then
		return false,"veiculo fora do catalogo"
	elseif info.registered ~= true or not NativeModel then
		return false,"veiculo sem registro valido"
	elseif getVehicleEstoque(model) <= 0 then
		return false,"veiculo fora de estoque"
	elseif not ownershipOk then
		return false,"nao foi possivel validar a propriedade"
	elseif owned then
		return false,"veiculo ja possuido"
	end

	local discount = func.getDiscount(passport) / 100
	local catalogPrice = parseInt(info.price or 0)
	local price = parseInt(catalogPrice - (catalogPrice * discount))
	if price <= 0 then
		return false,"preco invalido"
	end

	local paymentOk,paid = pcall(vRP.PaymentFull,passport,price,true)
	if not paymentOk then
		PurchaseLog("error","payment",requestSource,passport,model,paid)
		return false,"falha ao processar pagamento"
	elseif paid ~= true then
		return false,"dinheiro insuficiente"
	end

	local function CancelPaidPurchase(stage,message,inserted,plate,detail)
		if inserted and not RemoveInsertedProperty(requestSource,passport,model,plate) then
			PurchaseLog("critical",stage,requestSource,passport,model,"property retained; refund blocked: "..tostring(detail))
			return false,"falha critica; procure a administracao"
		end

		if not RefundPurchase(requestSource,passport,model,price,stage) then
			return false,"falha critica no estorno; procure a administracao"
		end

		PurchaseLog("denied",stage,requestSource,passport,model,detail)
		return false,message
	end

	local currentInfo = getVehicleFromCache(model)
	local recheckOk,recheckOwned = pcall(hasVehicle,passport,model)
	if ActiveCharacter(requestSource,passport) ~= passport then
		return CancelPaidPurchase("character_revalidation","personagem desconectado; valor estornado",false,nil,"inactive character")
	elseif not currentInfo or currentInfo.registered ~= true or NativeVehicleModel(model) ~= NativeModel or IsRemovedVehicle(model) then
		return CancelPaidPurchase("catalog_revalidation","veiculo indisponivel; valor estornado",false,nil,"catalog changed")
	elseif not recheckOk then
		return CancelPaidPurchase("ownership_revalidation","propriedade nao validada; valor estornado",false,nil,recheckOwned)
	elseif getVehicleEstoque(model) <= 0 or recheckOwned then
		return CancelPaidPurchase("ownership_revalidation","compra concorrente recusada; valor estornado",false,nil,"stock or ownership changed")
	end

	local plateOk,plate = pcall(vRP.GeneratePlate)
	if not plateOk or type(plate) ~= "string" or plate == "" then
		return CancelPaidPurchase("plate_generation","nao foi possivel gerar a placa; valor estornado",false,nil,plate)
	end

	local insertOk,insertAffected = pcall(vRP.Update,"vehicles/addVehicles",{
		Passport = passport,
		Vehicle = model,
		Plate = plate,
		Weight = info.capacidade,
		Work = 0
	})

	if not insertOk or tonumber(insertAffected) ~= 1 then
		local confirmOk,insertedProperty = pcall(vRP.SingleQuery,"vehicles/PlateOwner",{
			Passport = passport,
			Vehicle = model,
			Plate = plate
		})
		local propertyCreated = confirmOk and type(insertedProperty) == "table" and tonumber(insertedProperty.Passport) == passport and insertedProperty.Vehicle == model and insertedProperty.Plate == plate
		return CancelPaidPurchase("vehicle_insert","propriedade nao criada; valor estornado",propertyCreated,plate,insertOk and insertAffected or insertAffected)
	end

	local readOk,property = pcall(vRP.SingleQuery,"vehicles/PlateOwner",{
		Passport = passport,
		Vehicle = model,
		Plate = plate
	})

	if not readOk or type(property) ~= "table" or tonumber(property.Passport) ~= passport or property.Vehicle ~= model or property.Plate ~= plate then
		return CancelPaidPurchase("property_confirmation","propriedade nao confirmada; valor estornado",true,plate,readOk and "invalid property" or property)
	end

	local stockOk,stockAffected = pcall(vRP.Update,"nation_conce/takeOneStock",{ vehicle = model })
	if not stockOk or tonumber(stockAffected) ~= 1 then
		return CancelPaidPurchase("stock_update","estoque indisponivel; valor estornado",true,plate,stockOk and stockAffected or stockAffected)
	end

	-- A propriedade confirmada e a baixa de estoque formam o ponto de commit da compra.
	-- Falhas auxiliares depois daqui nunca desfazem nem recusam uma compra concluida.
	local stock = math.max(parseInt(currentInfo.estoque or info.estoque or 0) - 1,0)
	local stockCacheOk,stockCacheResult = pcall(UpdatePurchasedStockCache,model)
	if stockCacheOk and type(stockCacheResult) == "number" then
		stock = math.max(parseInt(stockCacheResult),0)
	else
		PurchaseLog("warning","stock_cache",requestSource,passport,model,"committed=true stock="..stock.." error="..tostring(stockCacheResult))
	end

	local cacheOk,cacheError = pcall(addUserVehicle,passport,info)
	if not cacheOk then
		PurchaseLog("warning","user_cache",requestSource,passport,model,"committed=true error="..tostring(cacheError))
	end

	local taxOk,taxResult = pcall(registerPurchaseTax,passport,model,price)
	if not taxOk or taxResult == false then
		PurchaseLog("critical","purchase_tax",requestSource,passport,model,"committed=true price="..price.." error="..tostring(taxResult))
	end

	PurchaseLog("success","complete",requestSource,passport,model,"affectedRows=1 native="..NativeModel)
	return true,"compra concluida",stock
end

function func.buyVehicle(model,color)
	local requestSource = tonumber(source)
	model = NormalizeVehicleModel(model)
	local passport = ActiveCharacter(requestSource)

	print(("[nation_concessionaria] Compra solicitada: source=%s model=%s"):format(
		tostring(requestSource),
		tostring(model)
	))

	if not passport then
		return false,"personagem indisponivel"
	elseif not model then
		print(("[nation_concessionaria] Resultado da compra: state=false message=veiculo invalido"))
		return false,"veiculo invalido"
	elseif not AcquirePurchaseLock(passport,model) then
		PurchaseLog("denied","lock",requestSource,passport,model,"operation already active")
		return false,"compra ja esta em processamento"
	end

	local ok,state,message,extra = pcall(processVehiclePurchase,requestSource,passport,model,color)
	ReleasePurchaseLock(passport,model)
	if not ok then
		PurchaseLog("error","unhandled",requestSource,passport,model,state)
		state = false
		message = "erro interno ao processar a compra"
		extra = nil
	end

	state = state == true
	message = message or (state and "compra concluida" or "compra recusada")

	print(("[nation_concessionaria] Resultado da compra: state=%s message=%s"):format(
		tostring(state),
		tostring(message)
	))

	return state,message,extra
end

function func.sellVehicle(model)
	local source = source
	local Passport = Passport(source)
	local info = VehicleInfo(model)

	if not Passport then
		return false,"passaporte invalido"
	elseif not info then
		return false,"veiculo nao registrado"
	elseif not hasVehicle(Passport,model) then
		return false,"voce nao possui este veiculo"
	end

	local price = parseInt(info.price * (config.porcentagem_venda / 100))
	vRP.Query("vehicles/removeVehicles",{ Passport = Passport, Vehicle = model })
	vRP.GiveBank(Passport,price,true)
	removeUserVehicle(Passport,model)
	addEstoque(model,1)

	return true,"venda concluida"
end

function func.getMyVehicles(force)
	local source = source
	local Passport = Passport(source)
	if not Passport then
		return {}
	end

	if force or not userVehicles[Passport] then
		local myVehicles = {}
		local rows = vRP.Query("vehicles/UserVehicles",{ Passport = Passport }) or {}

		for _,row in ipairs(rows) do
			local info = VehicleInfo(row.Vehicle)
			if info then
				myVehicles[#myVehicles + 1] = {
					vehicle = info.vehicle,
					price = parseInt(info.price * (config.porcentagem_venda / 100)),
					modelo = info.modelo,
					capacidade = info.capacidade,
					class = info.class
				}
			end
		end

		userVehicles[Passport] = myVehicles
	end

	return userVehicles[Passport]
end

function func.testDrive(model)
	local source = source
	local Passport = Passport(source)
	local info = VehicleInfo(model)

	if not Passport or not info then
		return false,"veiculo indisponivel"
	end

	local price = parseInt(info.price * (config.porcentagem_testdrive / 100))
	return true,"deseja pagar <b>"..Money(price).."</b> para realizar o test drive em um(a) <b>"..info.modelo.."</b> ?"
end

function func.payTest(model)
	local source = source
	local Passport = Passport(source)
	local info = VehicleInfo(model)

	if not Passport or not info then
		return false,"veiculo indisponivel",0
	end

	local price = parseInt(info.price * (config.porcentagem_testdrive / 100))
	if price <= 0 or vRP.PaymentFull(Passport,price,true) then
		return true,"sucesso",price
	end

	return false,"dinheiro insuficiente",price
end

function func.chargeBack(price)
	local source = source
	local Passport = Passport(source)
	price = parseInt(price or 0)

	if Passport and price > 0 then
		vRP.GiveBank(Passport,price,true)
		Notify(source,"aviso","Voce recebeu seus <b>"..Money(price).."</b> de volta.",3000)
	end
end

function func.rentVehicle(model)
	local source = source
	local Passport = Passport(source)
	local info = VehicleInfo(model)

	if not Passport or not info then
		return false,"veiculo indisponivel"
	elseif getVehicleEstoque(model) <= 0 then
		return false,"veiculo fora de estoque"
	elseif hasVehicle(Passport,model) then
		return false,"veiculo ja possuido"
	end

	local price = parseInt(info.price * (config.porcentagem_aluguel / 100))
	return true,"deseja pagar <b>"..Money(price).."</b> para alugar um(a) <b>"..info.modelo.."</b> por 1 dia?"
end

function func.payRent(model)
	local source = source
	local Passport = Passport(source)
	local info = VehicleInfo(model)

	if not Passport or not info then
		return false,"veiculo indisponivel"
	end

	local price = parseInt(info.price * (config.porcentagem_aluguel / 100))
	if not vRP.PaymentFull(Passport,price,true) then
		return false,"dinheiro insuficiente"
	end

	vRP.Query("vehicles/rentalVehicles",{
		Passport = Passport,
		Vehicle = model,
		Plate = vRP.GeneratePlate(),
		Days = 1,
		Weight = info.capacidade,
		Work = 0
	})

	removeEstoque(model,1)
	return true,"aluguel concluido"
end

function func.hasPermission()
	local source = source
	local Passport = Passport(source)
	if not Passport then
		return false
	end

	if config.openconce_permission then
		return vRP.HasPermission(Passport,config.openconce_permission) ~= false
	end

	return true
end

local manages = {
	update = function(source)
		getDbVehicles()
		Notify(source,"sucesso","Concessionaria atualizada com sucesso.")
	end,
	add = function(source,model,stock)
		local info = VehicleInfo(model)
		local stock = parseInt(stock or 0)

		if not info then
			Notify(source,"negado","Modelo invalido.")
			return
		end

		if stock <= 0 then
			Notify(source,"negado","Quantidade invalida.")
			return
		end

		addEstoque(info.vehicle,stock)
		getDbVehicles()
		Notify(source,"sucesso","Adicionado(s) <b>"..stock.." "..info.modelo.."</b> a concessionaria.")
	end,
	remove = function(source,model,stock)
		local stock = parseInt(stock or 0)
		local current = getVehicleEstoque(model)

		if stock <= 0 then
			Notify(source,"negado","Quantidade invalida.")
			return
		end

		if current <= 0 then
			Notify(source,"negado","Veiculo nao esta em estoque.")
			return
		end

		removeEstoque(model,stock)
		getDbVehicles()
		Notify(source,"sucesso","Estoque atualizado.")
	end
}

function func.manageConce(mode,model,stock)
	local source = source
	local Passport = Passport(source)

	if not Passport or not IsAdmin(Passport) then
		return
	end

	if mode and manages[mode] then
		manages[mode](source,model,stock)
	end
end

RegisterCommand("conce",function(source)
	local Passport = Passport(source)

	if Passport and IsAdmin(Passport) then
		fclient.showAdminMenu(source)
	else
		Notify(source,"negado","Apenas o dono/admin pode abrir o painel da concessionaria.")
	end
end)

RegisterCommand("concereload",function(source)
	if source ~= 0 then
		local Passport = Passport(source)
		if not Passport or not IsAdmin(Passport) then
			Notify(source,"negado","Apenas o dono/admin pode recarregar a concessionaria.")
			return
		end
	end

	getDbVehicles()

	if source == 0 then
		print(("[nation_concessionaria] Recarregada via console: %s veiculos em estoque."):format(#conceVehicles))
	else
		Notify(source,"sucesso",("Concessionaria recarregada: <b>%s</b> veiculos em estoque."):format(#conceVehicles))
	end
end)

function func.checkAuth()
	return true
end

CreateThread(function()
	PrepareDatabase()
	SeedInitialVehicles()
	getDbVehicles()
end)
