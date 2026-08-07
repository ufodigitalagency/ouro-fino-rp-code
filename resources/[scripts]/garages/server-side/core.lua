-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")
vRPC = Tunnel.getInterface("vRP")
vRP = Proxy.getInterface("vRP")
-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECTION
-----------------------------------------------------------------------------------------------------------------------------------------
Lil = {}
Tunnel.bindInterface("garages",Lil)
vCLIENT = Tunnel.getInterface("garages")
vKEYBOARD = Tunnel.getInterface("keyboard")
-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIAVEIS
-----------------------------------------------------------------------------------------------------------------------------------------
local Spawn = {}
local Active = {}
local Signal = {}
local Changed = {}
local Searched = {}
local Respawns = {}
local Propertys = {}
local SaleLocks = {}

local function UsefulCustomization(Customize)
	return type(Customize) == "table" and next(Customize) ~= nil
end

local function ReadCustomization(Key)
	local Success,Customize = pcall(vRP.GetSrvData,Key,true)
	if not Success or type(Customize) ~= "table" then
		return {},false
	end

	return Customize,UsefulCustomization(Customize)
end

local function VehicleCustomization(Passport,PropertyKey)
	local Canonical = "LsCustoms:"..Passport..":"..PropertyKey
	local Customize,Useful = ReadCustomization(Canonical)
	if Useful then
		return Customize
	end

	local NativeModel = exports.vrp:VehicleModel(PropertyKey)
	if type(NativeModel) == "string" and NativeModel ~= "" and NativeModel ~= PropertyKey then
		local Legacy,LegacyUseful = ReadCustomization("LsCustoms:"..Passport..":"..NativeModel)
		if LegacyUseful then
			return Legacy
		end
	end

	return Customize
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- GARAGES
-----------------------------------------------------------------------------------------------------------------------------------------
local Garages = {
	["1"] = { ["Name"] = "Garage" },
	["2"] = { ["Name"] = "Garage" },
	["3"] = { ["Name"] = "Garage" },
	["4"] = { ["Name"] = "Garage" },
	["5"] = { ["Name"] = "Garage" },
	["6"] = { ["Name"] = "Garage" },
	["7"] = { ["Name"] = "Garage" },
	["8"] = { ["Name"] = "Garage" },
	["9"] = { ["Name"] = "Garage" },
	["10"] = { ["Name"] = "Garage" },
	["11"] = { ["Name"] = "Garage" },
	["12"] = { ["Name"] = "Garage" },
	["13"] = { ["Name"] = "Garage" },
	["14"] = { ["Name"] = "Garage" },
	["15"] = { ["Name"] = "Garage" },
	["16"] = { ["Name"] = "Garage" },
	["17"] = { ["Name"] = "Garage" },
	["18"] = { ["Name"] = "Garage" },
	["19"] = { ["Name"] = "Garage" },
	["20"] = { ["Name"] = "Garage" },
	["21"] = { ["Name"] = "Garage" },
	["22"] = { ["Name"] = "Garage" },
	["23"] = { ["Name"] = "Garage" },
	["24"] = { ["Name"] = "Garage" },
	["25"] = { ["Name"] = "Garage" },
	["26"] = { ["Name"] = "Garage" },
	["27"] = { ["Name"] = "Garage" },

	-- Paramedic
	["41"] = { ["Name"] = "Paramedico", ["Permission"] = "Paramedico" },
	["42"] = { ["Name"] = "Paramedico2", ["Permission"] = "Paramedico" },

	-- Boats
	["121"] = { ["Name"] = "Boats" },
	["122"] = { ["Name"] = "Boats" },
	["123"] = { ["Name"] = "Boats" },
	["124"] = { ["Name"] = "Boats" },

	["131"] = { ["Name"] = "Helicopters" },

	-- Works
	["140"] = { ["Name"] = "Bikes" },
	["141"] = { ["Name"] = "Lumberman" },
	["143"] = { ["Name"] = "Garbageman" },
	["144"] = { ["Name"] = "Transporter" },
	["145"] = { ["Name"] = "Garbageman" },
	["146"] = { ["Name"] = "Trucker" },
	["147"] = { ["Name"] = "Taxi" },
	["148"] = { ["Name"] = "Grime" },
	["149"] = { ["Name"] = "Towed" },
	["150"] = { ["Name"] = "Milkman" },
	-- FuelStations
    ["153"] = { ["Name"] = "FuelStation", ["Permission"] = "FuelStation01" },
    ["154"] = { ["Name"] = "FuelStation", ["Permission"] = "FuelStation02" },
    ["155"] = { ["Name"] = "FuelStation", ["Permission"] = "FuelStation03" },
    ["156"] = { ["Name"] = "FuelStation", ["Permission"] = "FuelStation04" },
    ["157"] = { ["Name"] = "FuelStation", ["Permission"] = "FuelStation05" },
    ["158"] = { ["Name"] = "FuelStation", ["Permission"] = "FuelStation06" },
    ["159"] = { ["Name"] = "FuelStation", ["Permission"] = "FuelStation07" },
    ["160"] = { ["Name"] = "FuelStation", ["Permission"] = "FuelStation08" },
    ["161"] = { ["Name"] = "FuelStation", ["Permission"] = "FuelStation09" },
    ["162"] = { ["Name"] = "FuelStation", ["Permission"] = "FuelStation10" },
    ["163"] = { ["Name"] = "FuelStation", ["Permission"] = "FuelStation11" },
    ["164"] = { ["Name"] = "FuelStation", ["Permission"] = "FuelStation12" },
    ["165"] = { ["Name"] = "FuelStation", ["Permission"] = "FuelStation13" },
    ["166"] = { ["Name"] = "FuelStation", ["Permission"] = "FuelStation14" },
    ["167"] = { ["Name"] = "FuelStation", ["Permission"] = "FuelStation15" },
    ["168"] = { ["Name"] = "FuelStation", ["Permission"] = "FuelStation16" },
    ["169"] = { ["Name"] = "FuelStation", ["Permission"] = "FuelStation17" },
    ["170"] = { ["Name"] = "FuelStation", ["Permission"] = "FuelStation18" },
    ["171"] = { ["Name"] = "FuelStation", ["Permission"] = "FuelStation19" },
    ["172"] = { ["Name"] = "FuelStation", ["Permission"] = "FuelStation20" },
    ["173"] = { ["Name"] = "FuelStation", ["Permission"] = "FuelStation21" },
    ["174"] = { ["Name"] = "FuelStation", ["Permission"] = "FuelStation22" },
    ["175"] = { ["Name"] = "FuelStation", ["Permission"] = "FuelStation23" },
    ["176"] = { ["Name"] = "FuelStation", ["Permission"] = "FuelStation24" },
    ["177"] = { ["Name"] = "FuelStation", ["Permission"] = "FuelStation25" },
    ["178"] = { ["Name"] = "FuelStation", ["Permission"] = "FuelStation26" },
    ["179"] = { ["Name"] = "FuelStation", ["Permission"] = "FuelStation27" },

	-- Hospital SAMU (Ouro Fino)
	["200"] = { ["Name"] = "Garage" },
	["201"] = { ["Name"] = "SamuOuroFino", ["Permission"] = "Paramedico" },
	["202"] = { ["Name"] = "Garage" },
	["203"] = { ["Name"] = "Garage" },

	-- Departamento de Policia mapPM
	["210"] = { ["Name"] = "Policia", ["Permission"] = "Policia" },
	["211"] = { ["Name"] = "Garage" },
	["212"] = { ["Name"] = "Policia2", ["Permission"] = "Policia" },

	-- Favela São Judas
	["213"] = { ["Name"] = "Garage" },
	["214"] = { ["Name"] = "Garage", ["FilterClass"] = "Helicópteros" },
	["215"] = { ["Name"] = "Garage" },

	-- Favela Pombal
	["216"] = { ["Name"] = "Garage" },

	-- Garagem publica - estacionamento -290/-985
	["217"] = { ["Name"] = "Garage" },
}
-----------------------------------------------------------------------------------------------------------------------------------------
-- WORKS
-----------------------------------------------------------------------------------------------------------------------------------------
local Works = {
	["Helicopters"] = {
		"maverick",
		"volatus",
		"supervolito",
		"havok"
	},
	["Paramedico"] = {
		"lguard",
		"blazer2",
		"firetruk",
		"ambulance2"
	},
	["Paramedico2"] = {
		"maverick2"
	},
	["SamuOuroFino"] = {
		"Wrasprinter",
		"Wrgle53"
	},
	["Policia"] = {
		"VRa3",
		"VRa4",
		"VRq8",
		"VRraptor",
		"VRrs5",
		"VRrs6",
		"VRrs6av",
		"VRtahoe"
	},
	["Policia2"] = {
		"valkyrie2"
	},
	["Policia3"] = {
		"pbus",
		"riot"
	},
	["Driver"] = {
		"bus"
	},
	["Boats"] = {
		"dinghy",
		"jetmax",
		"marquis",
		"seashark",
		"speeder",
		"squalo",
		"suntrap",
		"toro",
		"tropic"
	},
	["Transporter"] = {
		"stockade"
	},
	["Lumberman"] = {
		"ratloader"
	},
	["Garbageman"] = {
		"trash"
	},
	["Trucker"] = {
		"packer"
	},
	["Taxi"] = {
		"taxi"
	},
	["Grime"] = {
		"boxville2"
	},
	["Towed"] = {
		"flatbed"
	},
	["Milkman"] = {
		"youga2"
	},
    ["FuelStation"] = {
        "packer"
    },
	["Bikes"] = {
		"scorcher",
		"bmx"
	}
}
-----------------------------------------------------------------------------------------------------------------------------------------
-- WORK VEHICLES
-----------------------------------------------------------------------------------------------------------------------------------------
local function IsWorkRecord(Value)
	return Value == true or Value == 1 or Value == "1"
end

local function IsBlockedRecord(Value)
	return Value == true or (tonumber(Value) or 0) ~= 0
end

local function IsRentalRecord(Value)
	return (tonumber(Value) or 0) ~= 0
end

local function ActiveCharacter(source,ExpectedPassport)
	source = tonumber(source)
	if not source or source <= 0 or GetPlayerName(source) == nil then
		return false
	end

	local Passport = vRP.Passport(source)
	if not Passport or (ExpectedPassport and Passport ~= ExpectedPassport) or vRP.Source(Passport) ~= source then
		return false
	end

	return Passport
end

local function NormalizePropertyKey(Name)
	if type(Name) ~= "string" then
		return false
	end

	Name = Name:match("^%s*(.-)%s*$"):lower()
	if Name == "" or #Name > 80 or not Name:match("^[%w_%-]+$") then
		return false
	end

	return Name
end

local function SaleLog(Status,Stage,source,Passport,Name,Plate,Detail)
	Detail = tostring(Detail or "-"):gsub("[%c]"," "):sub(1,180)
	print(("[garages] action=sell status=%s stage=%s source=%s passport=%s vehicle=%s plate=%s detail=%s"):format(
		tostring(Status),
		tostring(Stage),
		tostring(source),
		tostring(Passport),
		tostring(Name),
		tostring(Plate),
		Detail
	))
end

local function CleanupSoldVehicleData(source,Passport,Name,Plate)
	local customOk,customError = pcall(vRP.RemSrvData,"LsCustoms:"..Passport..":"..Name)
	if not customOk then
		SaleLog("warning","customization_cleanup",source,Passport,Name,Plate,customError)
	end

	local nativeOk,NativeModel = pcall(function()
		return exports.vrp:VehicleModel(Name)
	end)

	if not nativeOk then
		SaleLog("warning","native_model_lookup",source,Passport,Name,Plate,NativeModel)
	else
		NativeModel = NormalizePropertyKey(NativeModel)
		if NativeModel and NativeModel ~= Name then
			local propertyOk,NativeProperty = pcall(vRP.SelectVehicle,Passport,NativeModel)
			if not propertyOk then
				SaleLog("warning","legacy_customization_lookup",source,Passport,Name,Plate,"native="..NativeModel.." lookup failed; preserved")
			elseif type(NativeProperty) == "table" then
				SaleLog("preserved","legacy_customization_cleanup",source,Passport,Name,Plate,"native="..NativeModel.." belongs to a distinct property")
			else
				local legacyOk,legacyError = pcall(vRP.RemSrvData,"LsCustoms:"..Passport..":"..NativeModel)
				if not legacyOk then
					SaleLog("warning","legacy_customization_cleanup",source,Passport,Name,Plate,"native="..NativeModel.." error="..tostring(legacyError))
				end
			end
		end
	end

	local trunkOk,trunkError = pcall(vRP.RemSrvData,"Trunkchest:"..Passport..":"..Name)
	if not trunkOk then
		SaleLog("warning","trunk_cleanup",source,Passport,Name,Plate,trunkError)
	end
end

local function IsWorkVehicle(Number,Model)
	local Garage = Garages[Number]
	if not Garage or not Garage.Name or not Works[Garage.Name] then
		return false
	end

	for _,WorkModel in pairs(Works[Garage.Name]) do
		if WorkModel == Model then
			return true
		end
	end

	return false
end

local function IsTaxiShiftActive(source)
	if GetResourceState("cfWorks") ~= "started" then
		return false
	end

	local ok,active = pcall(function()
		return exports["cfWorks"]:IsJobActive(source,"taxista")
	end)

	return ok and active == true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- ENTITYREMOVED
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("entityRemoved",function(Entitys)
	if IsPedAPlayer(Entitys) or GetEntityType(Entitys) ~= 2 then
		return false
	end

	local Plate = GetVehicleNumberPlateText(Entitys)
	Plate = Changed[Plate] or Plate

	local Data = Spawn[Plate]
	if not Data then
		return false
	end

	local State = Entity(Entitys).state
	local Health = GetEntityHealth(Entitys)
	local Coords = GetEntityCoords(Entitys)
	local Heading = GetEntityHeading(Entitys)
	local Body = GetVehicleBodyHealth(Entitys)
	local Engine = GetVehicleEngineHealth(Entitys)

	local Windows = {}
	for Number = 0,5 do
		Windows[Number] = IsVehicleWindowIntact(Entitys,Number)
	end

	local VehicleCoords = vec4(Coords.x,Coords.y,Coords.z,Heading)
	Respawns[Plate] = VehicleCoords

	TriggerClientEvent("garages:Respawn",-1,"Add",Plate,VehicleCoords)

	vRP.Update("vehicles/updateVehiclesRespawns",{ Passport = Data[1], Vehicle = Data[2], Nitro = parseInt(State.Nitro) or 0, Engine = parseInt(Engine), Body = parseInt(Body), Health = parseInt(Health), Fuel = parseInt(State.Fuel) or 0, Windows = json.encode(Windows) })
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- SERVERVEHICLE
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.ServerVehicle(Model,Coords,Plate,Nitro,Doors,Body,Fuel,Seatbelt,Drift)
	if not Model or not Coords then
		return false
	end

	local SpawnModel = exports.vrp:VehicleModel(Model) or Model
	Model = SpawnModel

	if type(Model) == "string" then
		Model = GetHashKey(Model)
	end

	local Vehicle = CreateVehicle(Model,Coords.x,Coords.y,Coords.z,Coords.w or 0.0,true,true)
	if not Vehicle or Vehicle == 0 then
		return false
	end

	local Timeout = GetGameTimer() + 5000
	while not DoesEntityExist(Vehicle) do
		if GetGameTimer() > Timeout then
			return false
		end

		Wait(0)
	end

	local Network = NetworkGetNetworkIdFromEntity(Vehicle)
	if not Network or Network == 0 then
		DeleteEntity(Vehicle)
		return false
	end

	Plate = Plate or vRP.GeneratePlate()
	SetVehicleNumberPlateText(Vehicle,Plate)
	SetVehicleBodyHealth(Vehicle,(Body or 1000) + 0.0)
	SetEntityRoutingBucket(Vehicle,0)

	if Doors then
		local Success,Decoded = pcall(json.decode,Doors)
		if Success and type(Decoded) == "table" then
			for Number,Broken in pairs(Decoded) do
				if Broken then
					SetVehicleDoorBroken(Vehicle,parseInt(Number),true)
				end
			end
		end
	end

	Entity(Vehicle).state.Nitro = Nitro or 0
	Entity(Vehicle).state.Fuel = Fuel or 100.0
	Entity(Vehicle).state.Drift = Drift or false
	Entity(Vehicle).state.Seatbelt = Seatbelt or false

	return true,Network,Vehicle,Plate,SpawnModel
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- GARAGES:RESPAWNS
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("garages:Respawns")
AddEventHandler("garages:Respawns",function(Plate)
	local source = source
	local Passport = vRP.Passport(source)
	if not Passport or not Plate or Active[Passport] then
		return false
	end

	local Respawn = Respawns[Plate]
	local VehicleSpawn = Spawn[Plate]
	if not Respawn or not VehicleSpawn then
		return false
	end

	local OtherPassport,Model = VehicleSpawn[1],VehicleSpawn[2]
	if not OtherPassport or not Model then
		return false
	end

	if OtherPassport ~= Passport and not vRP.HasService(Passport,"Admin") then
		return false
	end

	local VehicleData = vRP.SelectVehicle(OtherPassport,Model)
	if not VehicleData then
		return false
	end

	Active[Passport] = true

	local Mods = VehicleCustomization(OtherPassport,Model)
	local Exist,Network,Entitys,_,SpawnModel = Lil.ServerVehicle(Model,Respawn,Plate,VehicleData.Nitro,VehicleData.Doors,VehicleData.Body,VehicleData.Fuel,VehicleData.Seatbelt,VehicleData.Drift)
	if not Exist then
		print(("[garages] Falha ao criar veiculo: Passport=%s Vehicle=%s Model=%s"):format(OtherPassport,Model,exports.vrp:VehicleModel(Model) or Model))
		TriggerClientEvent("Notify",source,"Aviso","Nao foi possivel retirar o veiculo.","amarelo",5000)
		Active[Passport] = nil
		return false
	end

	local Players = vRPC.Players(source)
	for _,OtherSource in pairs(Players) do
		async(function()
			vCLIENT.CreateVehicle(OtherSource,SpawnModel,Network,VehicleData.Engine,VehicleData.Health,Mods,VehicleData.Windows,VehicleData.Tyres)
		end)
	end

	if DoesEntityExist(Entitys) then
		Entity(Entitys).state.Lockpick = OtherPassport
		SetPedIntoVehicle(GetPlayerPed(source),Entitys,-1)
	end

	TriggerClientEvent("garages:Respawn",-1,"Remove",Plate)
	Spawn[Plate] = { OtherPassport,Model,Entitys }
	Active[Passport] = nil
	Respawns[Plate] = nil
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- GARAGES:CHANGEPLATE
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("garages:ChangePlate",function(Plate,NewPlate)
	Changed[NewPlate] = Plate
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- SIGNALREMOVE
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("SignalRemove",function(Plate)
	if not Signal[Plate] then
		Signal[Plate] = true
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- VEHICLES
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Vehicles(Number)
	local source = source
	local Passport = vRP.Passport(source)
	if not Passport then
		return false
	end

	local Garage = Garages[Number]
	if not Garage then
		return false
	end

	if exports.bank:CheckTaxes(Passport) or exports.bank:CheckFines(Passport) then
		return false
	end

	if Garage.Permission and not vRP.HasService(Passport,Garage.Permission) then
		return false
	end

	if Garage.Name == "Taxi" and not IsTaxiShiftActive(source) then
		TriggerClientEvent("Notify",source,"Taxi","Entre em servico como taxista antes de usar esta garagem.","amarelo",5000)
		return false
	end

	local Vehicles = {}
	local Selected = Garage.Name

	if Works[Selected] then
		for _,Model in pairs(Works[Selected]) do
			if exports.vrp:VehicleExist(Model) then
				local TaxTimer,RentalTimer = false,false
				local Consult = vRP.SelectVehicle(Passport,Model)

				if Consult then
					if Consult.Tax > os.time() then
						TaxTimer = CompleteTimers(Consult.Tax - os.time())
					end

					if Consult.Rental ~= 0 then
						if Consult.Rental > os.time() then
							RentalTimer = CompleteTimers(Consult.Rental - os.time())
						else
							RentalTimer = "Vencido"
						end
					end

					table.insert(Vehicles,{
						Model = Model,
						Name = exports.vrp:VehicleName(Model),
						Tax = 0,
						Mode = "Work",
						Weight = Consult.Weight,
						Engine = Consult.Engine / 10,
						Body = Consult.Body / 10,
						Fuel = Consult.Fuel,
						TaxTime = "Servico",
						RentalTime = RentalTimer
					})
				else
					table.insert(Vehicles,{
						Model = Model,
						Name = exports.vrp:VehicleName(Model),
						Tax = 0,
						Mode = "Work",
						Weight = exports.vrp:VehicleWeight(Model),
						Engine = 100,
						Body = 100,
						Fuel = 100,
						TaxTime = "Servico",
						RentalTime = false
					})
				end
			end
		end
	else
		if string.sub(Number,1,9) == "Propertys" then
			local Consult = vRP.Query("propertys/Exist",{ Name = Number })
			local Property = Consult[1]
			if not Property then
				return false
			end

			local OwnerProperty = vRP.InventoryFull(Passport,"propertys-"..Property.Serial) or Property.Passport == Passport
			if not OwnerProperty or os.time() > Property.Tax then
				return false
			end
		end

		local Consult = vRP.Query("vehicles/UserVehicles",{ Passport = Passport })
		for _,v in pairs(Consult) do
			local VehicleClass = exports.vrp:VehicleClass(v.Vehicle)
			local ClassAllowed = not Garage.FilterClass or VehicleClass == Garage.FilterClass
			if exports.vrp:VehicleExist(v.Vehicle) and not v.Work and ClassAllowed then
				local TaxTimer,RentalTimer = false,false

				if v.Tax > os.time() then
					TaxTimer = CompleteTimers(v.Tax - os.time())
				end

				if v.Rental ~= 0 then
					if v.Rental > os.time() then
						RentalTimer = CompleteTimers(v.Rental - os.time())
					else
						RentalTimer = "Vencido"
					end
				end

				table.insert(Vehicles,{
					Model = v.Vehicle,
					Name = exports.vrp:VehicleName(v.Vehicle),
					Tax = exports.vrp:VehiclePrice(v.Vehicle) * 0.15,
					Mode = exports.vrp:VehicleMode(v.Vehicle),
					Weight = v.Weight,
					Engine = v.Engine / 10,
					Body = v.Body / 10,
					Fuel = v.Fuel,
					TaxTime = TaxTimer,
					RentalTime = RentalTimer
				})
			end
		end
	end

	return Vehicles
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- GARAGES:SELL
-----------------------------------------------------------------------------------------------------------------------------------------
local function ProcessVehicleSale(source,Passport,Name)
	local Vehicle = vRP.SelectVehicle(Passport,Name)
	if not Vehicle then
		return false,"propriedade nao encontrada"
	elseif IsBlockedRecord(Vehicle.Block) then
		return false,"veiculo bloqueado para venda"
	elseif IsWorkRecord(Vehicle.Work) then
		return false,"veiculo de trabalho nao pode ser vendido"
	elseif IsRentalRecord(Vehicle.Rental) then
		return false,"veiculo alugado nao pode ser vendido"
	end

	local Plate = type(Vehicle.Plate) == "string" and Vehicle.Plate or ""
	if Plate == "" then
		return false,"placa da propriedade invalida"
	end

	local Mode = exports.vrp:VehicleMode(Name)
	local Class = exports.vrp:VehicleClass(Name)
	if Mode == "Work" or Mode == "Rental" or Class == "Races" then
		return false,"categoria de veiculo nao permite venda"
	end

	local Price = parseInt(exports.vrp:VehiclePrice(Name) * 0.5)
	local VehicleName = exports.vrp:VehicleName(Name)
	if Price <= 0 then
		return false,"valor de venda invalido"
	end

	TriggerClientEvent("garages:Close",source)
	if not vRP.Request(source,"Garagem","Vender o veículo <b>"..VehicleName.."</b> por <b>$"..Dotted(Price).."</b>?") then
		return false,"venda cancelada"
	end

	if ActiveCharacter(source,Passport) ~= Passport then
		return false,"personagem desconectado"
	end

	local readOk,Current = pcall(vRP.SelectVehicle,Passport,Name)
	if not readOk or type(Current) ~= "table" then
		SaleLog("denied","property_revalidation",source,Passport,Name,Plate,readOk and "missing" or Current)
		return false,"propriedade nao encontrada"
	elseif Current.Plate ~= Plate or tonumber(Current.Passport) ~= Passport then
		SaleLog("denied","property_changed",source,Passport,Name,Plate,"owner or plate changed")
		return false,"a propriedade mudou durante a venda"
	elseif IsBlockedRecord(Current.Block) or IsWorkRecord(Current.Work) or IsRentalRecord(Current.Rental) then
		return false,"veiculo nao pode mais ser vendido"
	end

	Mode = exports.vrp:VehicleMode(Name)
	Class = exports.vrp:VehicleClass(Name)
	if Mode == "Work" or Mode == "Rental" or Class == "Races" then
		return false,"categoria de veiculo nao permite venda"
	end

	Price = parseInt(exports.vrp:VehiclePrice(Name) * 0.5)
	if Price <= 0 then
		return false,"valor de venda invalido"
	end

	local deleteOk,affected = pcall(vRP.Update,"vehicles/removeVehicleExact",{
		Passport = Passport,
		Vehicle = Name,
		Plate = Plate
	})

	if not deleteOk or tonumber(affected) ~= 1 then
		SaleLog("denied","delete",source,Passport,Name,Plate,deleteOk and affected or affected)
		TriggerClientEvent("Notify",source,"Garagem","Nao foi possivel confirmar a exclusao da propriedade.","vermelho",5000)
		return false,"propriedade nao removida"
	end

	local creditOk,creditError = pcall(vRP.GiveBank,Passport,Price)
	if not creditOk then
		SaleLog("critical","credit",source,Passport,Name,Plate,creditError)
		TriggerClientEvent("Notify",source,"Garagem","Propriedade removida, mas o credito falhou. Procure a administracao.","vermelho",8000)
		return false,"falha critica no credito"
	end

	CleanupSoldVehicleData(source,Passport,Name,Plate)

	SaleLog("success","complete",source,Passport,Name,Plate,"affectedRows=1 credit="..Price)
	TriggerClientEvent("Notify",source,VehicleName,"Veículo vendido com sucesso.","verde",5000)
	return true,"veiculo vendido com sucesso"
end

local function ExecuteVehicleSale(requestSource,Name)
	local source = tonumber(requestSource)
	local Passport = ActiveCharacter(source)
	Name = NormalizePropertyKey(Name)

	if not Passport then
		return false,"personagem indisponivel"
	elseif not Name or not exports.vrp:VehicleExist(Name) then
		return false,"veiculo invalido"
	elseif Active[Passport] or SaleLocks[Passport] then
		return false,"operacao ja esta em processamento"
	end

	Active[Passport] = true
	SaleLocks[Passport] = Name
	local ok,state,message = pcall(ProcessVehicleSale,source,Passport,Name)
	SaleLocks[Passport] = nil
	Active[Passport] = nil

	if not ok then
		SaleLog("error","unhandled",source,Passport,Name,"-",state)
		TriggerClientEvent("Notify",source,"Garagem","Erro interno ao processar a venda.","vermelho",5000)
		return false,"erro interno ao processar a venda"
	end

	return state == true,message
end

function Lil.Sell(Name)
	return ExecuteVehicleSale(source,Name)
end

RegisterServerEvent("garages:Sell")
AddEventHandler("garages:Sell",function(Name)
	ExecuteVehicleSale(source,Name)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- GARAGES:TRANSFER
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("garages:Transfer")
AddEventHandler("garages:Transfer",function(Name)
	local source = source
	local Passport = vRP.Passport(source)
	if not Passport then
		return false
	end

	local Vehicle = vRP.SelectVehicle(Passport,Name)
	if not Vehicle or IsBlockedRecord(Vehicle.Block) or IsWorkRecord(Vehicle.Work) then
		return false
	end

	TriggerClientEvent("garages:Close",source)

	local Keyboard = vKEYBOARD.Primary(source,"Passaporte")
	if not Keyboard then
		return false
	end

	local OtherPassport = parseInt(Keyboard[1])
	if OtherPassport <= 0 or OtherPassport == Passport then
		TriggerClientEvent("Notify",source,"Negado","Passaporte inválido.","vermelho",5000)
		return false
	end

	local OtherName = vRP.FullName(OtherPassport) or "Desconhecido"
	if not vRP.Request(source,"Garagem","Transferir o veículo <b>"..exports.vrp:VehicleName(Name).."</b> para <b>"..OtherName.."</b>?") then
		return false
	end

	if vRP.SelectVehicle(OtherPassport,Name) then
		TriggerClientEvent("Notify",source,"Atenção","<b>"..OtherName.."</b> já possui este modelo de veículo.","amarelo",5000)
		return false
	end

	vRP.Update("vehicles/moveVehicles",{ Passport = Passport, OtherPassport = OtherPassport, Vehicle = Name })

	local LsData = vRP.GetSrvData("LsCustoms:"..Passport..":"..Name,true)
	vRP.SetSrvData("LsCustoms:"..OtherPassport..":"..Name,LsData,true)
	vRP.RemSrvData("LsCustoms:"..Passport..":"..Name)

	local TrunkData = vRP.GetSrvData("Trunkchest:"..Passport..":"..Name,true)
	vRP.SetSrvData("Trunkchest:"..OtherPassport..":"..Name,TrunkData,true)
	vRP.RemSrvData("Trunkchest:"..Passport..":"..Name)

	TriggerClientEvent("Notify",source,"Sucesso","Transferência concluída para <b>"..OtherName.."</b>.","verde",5000)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- GARAGES:TAX
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("garages:Tax")
AddEventHandler("garages:Tax",function(Name)
	local source = source
	local Passport = vRP.Passport(source)
	if not Passport then
		return false
	end

	local Vehicle = vRP.SelectVehicle(Passport,Name)
	if not Vehicle or IsWorkRecord(Vehicle.Work) or Vehicle.Tax > os.time() then
		return false
	end

	TriggerClientEvent("garages:Close",source)

	local Price = exports.vrp:VehiclePrice(Name) * 0.15
	local VehicleName = exports.vrp:VehicleName(Name)
	local FormattedPrice = Dotted(Price)

	if not vRP.Request(source,"Garagem","Pagar o <b>IPVA</b> do veículo <b>"..VehicleName.."</b> por <b>$"..FormattedPrice.."</b>?") then
		return false
	end

	if vRP.PaymentFull(Passport,Price) then
		vRP.Update("vehicles/updateVehiclesTax",{ Passport = Passport, Vehicle = Name })
		TriggerClientEvent("Notify",source,"Sucesso","Pagamento concluído.","verde",5000)
	else
		TriggerClientEvent("Notify",source,"Aviso","Dinheiro insuficiente.","amarelo",5000)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- RESET
-----------------------------------------------------------------------------------------------------------------------------------------
function Reset(Plate)
	Signal[Plate] = nil
	Respawns[Plate] = nil

	local Backup = Changed[Plate]
	if Backup then
		Spawn[Backup] = nil
		Changed[Plate] = nil
	end

	Spawn[Plate] = nil
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- GARAGES:SPAWN
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("garages:Spawn")
AddEventHandler("garages:Spawn",function(Name,Number)
	local source = source
	local Passport = vRP.Passport(source)
	if not Passport or Active[Passport] or not exports.vrp:VehicleExist(Name) then
		return false
	end

	Active[Passport] = true
	local Garage = Garages[Number]

	local function CancelProcess(Message)
		TriggerClientEvent("Notify",source,"Aviso",Message,"amarelo",5000)
		Active[Passport] = nil
		return false
	end

	if not Garage then
		return CancelProcess("Garagem invalida.")
	end

	if Garage.Permission and not vRP.HasService(Passport,Garage.Permission) then
		return CancelProcess("Voce nao tem permissao para esta garagem.")
	end

	if Garage.Name == "Taxi" and not IsTaxiShiftActive(source) then
		return CancelProcess("Entre em servico como taxista antes de puxar um taxi.")
	end

	local function GetDiscountCoin()
		local Coin = "Diamantes"
		if Garage.Platinum then
			Coin = "Platinas"
		end

		return Coin
	end

	local function GetDiscount(Coin,Gemstone)
		if Coin == "Platinas" then
			return Gemstone
		end

		local Discount = 1.0
		local Tiers = { Ouro = 0.70, Prata = 0.80, Bronze = 0.90 }

		for Rank,Multiplier in pairs(Tiers) do
			if vRP.HasService(Passport,Rank) then
				Discount = math.min(Discount,Multiplier)
			end
		end

		return Gemstone * Discount
	end

	local function HandleRentalPayment(Gemstone,textName)
		TriggerClientEvent("garages:Close",source)

		local Coin = GetDiscountCoin()
		local Value = GetDiscount(Coin,Gemstone)
		local Message = ("Pagar o aluguel do veículo <b>%s</b> por <b>%s %s</b>?"):format(textName,Dotted(Value),Coin)

		if not vRP.Request(source,"Garagem",Message) then
			return CancelProcess("Processo cancelado.")
		end

		local Paid = (Coin == "Diamantes" and vRP.PaymentGems(Passport,Value)) or (Coin == "Platinas" and vRP.TakeItem(Passport,"platinum",Value))
		if not Paid then
			return CancelProcess(Coin.." insuficiente.")
		end

		return Value,Coin
	end

	local Class = exports.vrp:VehicleClass(Name)
	local Price = exports.vrp:VehiclePrice(Name)
	local Gemstone = exports.vrp:VehicleGemstone(Name)
	local Vehicle = vRP.SelectVehicle(Passport,Name)
	local ServiceVehicle = IsWorkVehicle(Number,Name)

	if not Vehicle and Class ~= "Races" then
		TriggerClientEvent("garages:Close",source)

		if ServiceVehicle then
			vRP.Query("vehicles/addVehicles",{ Passport = Passport, Vehicle = Name, Plate = vRP.GeneratePlate(), Weight = exports.vrp:VehicleWeight(Name), Work = 1 })
			TriggerClientEvent("Notify",source,"Garagem","Viatura liberada para uso de servico.","verde",3000)
			Vehicle = vRP.SelectVehicle(Passport,Name)
		elseif Gemstone > 0 then
			local Value,Coin = HandleRentalPayment(Gemstone,exports.vrp:VehicleName(Name))
			if not Value then
				return false
			end

			vRP.Query("vehicles/rentalVehicles",{ Passport = Passport, Vehicle = Name, Plate = vRP.GeneratePlate(), Days = 30, Weight = exports.vrp:VehicleWeight(Name), Work = 1 })
			exports.discord:Embed("Vehicles",("**[PASSAPORTE]:** %s\n**[RENOVOU]:** %s\n**[VALOR]:** %s %s"):format(Passport,Name,Dotted(Value),Coin))
			TriggerClientEvent("Notify",source,"Sucesso","Aluguel do veículo <b>"..exports.vrp:VehicleName(Name).."</b> concluído.","verde",5000)
			Vehicle = vRP.SelectVehicle(Passport,Name)
		else
			if Price > 0 then
				if not vRP.Request(source,"Garagem",("Comprar o veículo <b>%s</b> por <b>%s%s</b>?"):format(exports.vrp:VehicleName(Name),Currency,Dotted(Price))) then
					return CancelProcess("Processo cancelado.")
				end

				if not vRP.PaymentFull(Passport,Price) then
					return CancelProcess("Dinheiro insuficiente.")
				end

				vRP.Query("vehicles/addVehicles",{ Passport = Passport, Vehicle = Name, Plate = vRP.GeneratePlate(), Weight = exports.vrp:VehicleWeight(Name), Work = 1 })
				exports.discord:Embed("Vehicles",("**[PASSAPORTE]:** %s\n**[COMPROU]:** %s\n**[VALOR]:** %s%s"):format(Passport,Name,Currency,Dotted(Price)))
				exports.bank:AddTaxes(Passport,"Concessionária",Price,"Compra do veículo "..exports.vrp:VehicleName(Name)..".")
				Vehicle = vRP.SelectVehicle(Passport,Name)
			else
				vRP.Query("vehicles/addVehicles",{ Passport = Passport, Vehicle = Name, Plate = vRP.GeneratePlate(), Weight = exports.vrp:VehicleWeight(Name), Work = 1 })
				Vehicle = vRP.SelectVehicle(Passport,Name)
			end
		end
	end

	if not Vehicle then
		Active[Passport] = nil
		return false
	end

	local WorkVehicle = ServiceVehicle or IsWorkRecord(Vehicle.Work)
	local Plate = Vehicle.Plate
	if Spawn[Plate] then
		if Garage.Name == "Taxi" then
			return CancelProcess("Seu taxi ja esta em uso. Guarde o veiculo antes de puxar outro.")
		end

		if Signal[Plate] then
			TriggerClientEvent("Notify",source,"Aviso","Rastreador está desativado.","policia",5000)
			Active[Passport] = nil
			return false
		end

		local CurrentTimer = os.time()
		if CurrentTimer < (Searched[Passport] or 0) then
			TriggerClientEvent("Notify",source,"Aviso","Rastreador pode ser ativado a cada <b>60</b> segundos.","policia",5000)
			Active[Passport] = nil
			return false
		end

		local Entitys = Spawn[Plate][3]
		if not Respawns[Plate] then
			if Entitys and DoesEntityExist(Entitys) and GetEntityType(Entitys) == 2 then
				if GetEntityCoords(Entitys).z > -20 then
					Searched[Passport] = CurrentTimer + 60
					vCLIENT.SearchBlip(source,GetEntityCoords(Entitys))
					TriggerClientEvent("Notify",source,"Atenção","Rastreador ativado por <b>30</b> segundos.","policia",10000)
				else
					Reset(Plate)
					DeleteEntity(Entitys)
					TriggerClientEvent("Notify",source,"Sucesso","Seguradora resgatou seu veículo.","policia",5000)
				end
			else
				Reset(Plate)
				TriggerClientEvent("Notify",source,"Sucesso","Seguradora resgatou seu veículo.","policia",5000)
			end
		else
			Searched[Passport] = CurrentTimer + 60
			vCLIENT.SearchBlip(source,Respawns[Plate].xyz)
			TriggerClientEvent("Notify",source,"Atenção","Rastreador ativado por <b>30</b> segundos.","policia",10000)
		end

		Active[Passport] = nil

		return false
	end

	if Vehicle.Arrest and not WorkVehicle then
		TriggerClientEvent("garages:Close",source)

		local Valuation = Price * 0.1
		if not vRP.Request(source,"Garagem",("Liberar veículo custa <b>%s%s</b>, deseja prosseguir?"):format(Currency,Dotted(Valuation))) then
			return CancelProcess("Processo cancelado.")
		end

		if not vRP.PaymentFull(Passport,Valuation) then
			return CancelProcess("Dinheiro insuficiente.")
		end

		exports.bank:AddTaxes(Passport,"Garagem",Price,"Liberação do veículo.")
		vRP.Update("vehicles/PaymentArrest",{ Passport = Passport, Vehicle = Name })
		TriggerClientEvent("Notify",source,"Sucesso","Veículo liberado.","policia",10000)
	end

	if Vehicle.Tax <= os.time() and not WorkVehicle then
		TriggerClientEvent("garages:Close",source)

		local Valuation = Price * 0.15
		if not vRP.Request(source,"Garagem",("Pagar a taxa do veículo <b>%s</b> por <b>%s%s</b>?"):format(exports.vrp:VehicleName(Name),Currency,Dotted(Valuation))) then
			return CancelProcess("Processo cancelado.")
		end

		if not vRP.PaymentFull(Passport,Valuation) then
			return CancelProcess("Dinheiro insuficiente.")
		end

		vRP.Update("vehicles/updateVehiclesTax",{ Passport = Passport, Vehicle = Name })
		TriggerClientEvent("Notify",source,"Sucesso","Pagamento concluído.","verde",5000)
	end

	if Gemstone > 0 and Vehicle.Rental ~= 0 and Vehicle.Rental <= os.time() and not WorkVehicle then
		local Value,Coin = HandleRentalPayment(Gemstone,exports.vrp:VehicleName(Name))
		if not Value then
			return false
		end

		vRP.Update("vehicles/rentalVehiclesUpdate",{ Passport = Passport, Vehicle = Name, Days = 30 })
		TriggerClientEvent("Notify",source,"Sucesso","Aluguel do veículo <b>"..exports.vrp:VehicleName(Name).."</b> atualizado.","verde",5000)
		exports.discord:Embed("Vehicles",("**[PASSAPORTE]:** %s\n**[RENOVOU]:** %s\n**[VALOR]:** %s %s"):format(Passport,Name,Dotted(Value),Coin))
	end

	local Coords = vCLIENT.SpawnPosition(source,Number)
	if Coords then
		local Mods = VehicleCustomization(Passport,Name)
		local Exist,Network,Entitys,_,SpawnModel = Lil.ServerVehicle(Name,Coords,Plate,Vehicle.Nitro,Vehicle.Doors,Vehicle.Body,Vehicle.Fuel,Vehicle.Seatbelt,Vehicle.Drift)
		if Exist then
			local Players = vRPC.Players(source)
			for _,OtherSource in pairs(Players) do
				async(function()
					vCLIENT.CreateVehicle(OtherSource,SpawnModel,Network,Vehicle.Engine,Vehicle.Health,Mods,Vehicle.Windows,Vehicle.Tyres)
				end)
			end

			Entity(Entitys).state.Lockpick = Passport
			Spawn[Plate] = { Passport,Name,Entitys,Network }
		else
			print(("[garages] Falha ao criar veiculo: Passport=%s Vehicle=%s Model=%s"):format(Passport,Name,exports.vrp:VehicleModel(Name) or Name))
			return CancelProcess("Nao foi possivel retirar o veiculo.")
		end
	end

	Active[Passport] = nil
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- CAR
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("car",function(source,Message)
	local Model = Message[1]
	local Passport = vRP.Passport(source)
	if not Passport or not Model or not vRP.HasGroup(Passport,"Admin") then
		return
	end

	local Ped = GetPlayerPed(source)
	local Coords = GetEntityCoords(Ped)
	local Heading = GetEntityHeading(Ped)
	local Plate = ("VEH%s"):format(10000 + Passport)
	local Spawned,Network,Entitys = Lil.ServerVehicle(Model,vec4(Coords.x,Coords.y,Coords.z,Heading),Plate,2000,nil,1000,100,true,false)
	if not Spawned then
		return false
	end

	local Players = vRPC.Players(source)
	for _,OtherSource in pairs(Players) do
		async(function()
			vCLIENT.CreateVehicle(OtherSource,Model,Network,1000,1000,nil,false,false,false)
		end)
	end

	Entity(Entitys).state.Lockpick = Passport
	Spawn[Plate] = { Passport,Model,Entitys }
	SetPedIntoVehicle(GetPlayerPed(source),Entitys,-1)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- DV
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("dv",function(source)
	local Passport = vRP.Passport(source)
	if not Passport or not vRP.HasGroup(Passport,"Admin") then
		return false
	end

	TriggerClientEvent("garages:Delete",source)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- GARAGES:KEY
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("garages:Key")
AddEventHandler("garages:Key",function(entityData)
	local source = source
	local Passport = vRP.Passport(source)
	if not Passport then
		return false
	end

	local Plate = entityData[1]
	local Network = entityData[4]
	local Entitys = NetworkGetEntityFromNetworkId(Network)
	if not DoesEntityExist(Entitys) then
		return false
	end

	local State = Entity(Entitys).state
	if State and State.Lockpick == Passport then
		vRP.GiveItem(Passport,"vehiclekey-"..os.time().."-"..Plate,1,true)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- GARAGES:LOCK
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("garages:Lock")
AddEventHandler("garages:Lock",function(Network)
	local source = source
	local Passport = vRP.Passport(source)
	if not Passport then
		return false
	end

	local Entitys = NetworkGetEntityFromNetworkId(Network)
	if not DoesEntityExist(Entitys) then
		return false
	end

	local State = Entity(Entitys).state
	if State and State.Lockpick == Passport then
		TriggerEvent("garages:LockVehicle",source,Network)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- GARAGES:LOCKVEHICLE
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("garages:LockVehicle",function(source,Network)
	local Vehicle = NetworkGetEntityFromNetworkId(Network)
	if not DoesEntityExist(Vehicle) then
		return false
	end

	local DoorStatus = tonumber(GetVehicleDoorLockStatus(Vehicle)) or 0

	if DoorStatus <= 1 then
		TriggerClientEvent("Notify",source,"Aviso","Veículo trancado.","default",5000)
		TriggerClientEvent("sounds:Private",source,"locked",0.5)
		SetVehicleDoorsLocked(Vehicle,2)
	else
		TriggerClientEvent("Notify",source,"Aviso","Veículo destrancado.","default",5000)
		TriggerClientEvent("sounds:Private",source,"unlocked",0.5)
		SetVehicleDoorsLocked(Vehicle,1)
	end

	if not vRP.InsideVehicle(source) then
		vRPC.playAnim(source,true,{"anim@mp_player_intmenu@key_fob@","fob_click_fp"},false)
		Wait(350)
		vRPC.stopAnim(source)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- DELETE
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Delete(Network,Doors,Tyres,Plate)
	local Networked = NetworkGetEntityFromNetworkId(Network)
	if not DoesEntityExist(Networked) or IsPedAPlayer(Networked) or GetEntityType(Networked) ~= 2 then
		return false
	end

	local Primary = Changed[Plate] and Plate or false
	if Primary then
		Plate = Changed[Plate]
		Changed[Primary] = nil
	end

	if Spawn[Plate] then
		local Name = Spawn[Plate][2]
		local Passport = Spawn[Plate][1]
		if vRP.SelectVehicle(Passport,Name) then
			local Health = GetEntityHealth(Networked)
			local Body = GetVehicleBodyHealth(Networked)
			local Engine = GetVehicleEngineHealth(Networked)

			local Windows = {}
			for Number = 0,5 do
				Windows[Number] = IsVehicleWindowIntact(Networked,Number)
			end

			local State = Entity(Networked).state
			local Nitro = State.Nitro or 0
			local Fuel = State.Fuel or 0

			local DoorsJson = json.encode(Doors)
			local WindowsJson = json.encode(Windows)
			local TyresJson = json.encode(Tyres)

			vRP.Update("vehicles/updateVehicles",{ Passport = Passport, Vehicle = Name, Nitro = Nitro, Engine = math.floor(Engine), Body = math.floor(Body), Health = math.floor(Health), Fuel = Fuel, Doors = DoorsJson, Windows = WindowsJson, Tyres = TyresJson })
		end
	end

	TriggerEvent("garages:Delete",Network,Plate)

	if Primary then
		TriggerEvent("garages:Delete",Network,Primary)
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- GARAGES:DELETED
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("garages:Deleted")
AddEventHandler("garages:Deleted",function(Network,Plate)
	Lil.Delete(Network,{},{},Plate)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- GARAGES:DELETE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("garages:Delete")
AddEventHandler("garages:Delete",function(Network,Plate)
	if not Network or not Plate then
		return false
	end

	Signal[Plate] = nil

	if Changed[Plate] then
		local Backup = Changed[Plate]
		Spawn[Backup] = nil
		Changed[Plate] = nil
	end

	Spawn[Plate] = nil

	local Entity = NetworkGetEntityFromNetworkId(Network)
	if Entity and DoesEntityExist(Entity) and GetEntityType(Entity) == 2 and not IsPedAPlayer(Entity) then
		DeleteEntity(Entity)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- GARAGES:PROPERTYS
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("garages:Propertys")
AddEventHandler("garages:Propertys",function(Name)
	local source = source
	local Passport = vRP.Passport(source)
	if not Passport or Active[Passport] then
		return false
	end

	local Consult = vRP.SingleQuery("propertys/Exist",{ Name = Name })
	if not Consult or Consult.Passport ~= Passport then
		return false
	end

	Active[Passport] = true

	TriggerClientEvent("dynamic:Close",source)
	TriggerClientEvent("Notify",source,"Aviso","Selecione o local da garagem.","amarelo",5000)

	local Hash = "prop_offroad_tyres02"
	local Sucess,GarageCoords = vRPC.ObjectControlling(source,Hash)
	if not Sucess then
		Active[Passport] = nil
		return false
	end

	local PropertyCoords = exports.propertys:Coords(Name)
	if PropertyCoords and #(vec3(GarageCoords[1],GarageCoords[2],GarageCoords[3]) - PropertyCoords) > 25 then
		TriggerClientEvent("Notify",source,"Aviso","A garagem precisa ser próximo da entrada.","amarelo",5000)
		Active[Passport] = nil
		return false
	end

	TriggerClientEvent("Notify",source,"Aviso","Selecione o local do veículo.","amarelo",5000)

	local VehicleHash = "sultanrs"
	local Sucess,VehicleCoords = vRPC.ObjectControlling(source,VehicleHash)
	if not Sucess then
		Active[Passport] = nil
		return false
	end

	if PropertyCoords and #(vec3(VehicleCoords[1],VehicleCoords[2],VehicleCoords[3]) - PropertyCoords) > 25 then
		TriggerClientEvent("Notify",source,"Aviso","A garagem precisa ser próximo da entrada.","amarelo",5000)
		Active[Passport] = nil
		return false
	end

	local NewGarage = {
		["1"] = { GarageCoords[1],GarageCoords[2],GarageCoords[3] + 1 },
		["2"] = { VehicleCoords[1],VehicleCoords[2],VehicleCoords[3] + 1,VehicleCoords[4] }
	}

	Garages[Name] = { Name = "Garage" }
	Propertys[Name] = { x = NewGarage["1"][1], y = NewGarage["1"][2], z = NewGarage["1"][3], ["1"] = NewGarage["2"] }

	vRP.Update("propertys/Garage",{ Name = Name, Garage = json.encode(NewGarage) })
	TriggerClientEvent("garages:Propertys",-1,Propertys)

	Active[Passport] = nil
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADSERVERSTART
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	local Consult = vRP.Query("propertys/Garages")
	for _,v in ipairs(Consult) do
		local Name = v.Name
		local GarageJson = v.Garage
		if not Propertys[Name] and GarageJson then
			local GarageTable = json.decode(GarageJson)
			if GarageTable and GarageTable["1"] and GarageTable["2"] then
				Garages[Name] = { Name = "Garage" }
				Propertys[Name] = { x = GarageTable["1"][1], y = GarageTable["1"][2], z = GarageTable["1"][3], ["1"] = GarageTable["2"] }
			end
		end
	end

	local Vehicles = exports.oxmysql:query_async("SELECT Passport,Vehicle FROM vehicles WHERE Tax + 1296000 < UNIX_TIMESTAMP()")
	for _,v in ipairs(Vehicles or {}) do
		local Key = v.Passport..":"..v.Vehicle
		vRP.Query("entitydata/RemoveData",{ Name = "Mods:"..Key })
		vRP.Query("entitydata/RemoveData",{ Name = "Trunkchest:"..Key })
		vRP.Query("vehicles/removeVehicles",{ Passport = v.Passport, Vehicle = v.Vehicle })

		Wait(100)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- SIGNAL
-----------------------------------------------------------------------------------------------------------------------------------------
exports("Signal",function(Plate)
	return Signal[Plate]
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- SPAWN
-----------------------------------------------------------------------------------------------------------------------------------------
exports("Spawn",function(Plate)
	return Spawn[Plate]
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECT
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("Connect",function(Passport,source)
	TriggerClientEvent("garages:Propertys",source,Propertys,Respawns)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- DISCONNECT
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("Disconnect",function(Passport,source)
	if Active[Passport] then
		Active[Passport] = nil
	end
end)
