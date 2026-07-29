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
vCLIENT = Tunnel.getInterface("player")
vSKINSHOP = Tunnel.getInterface("skinshop")
vKEYBOARD = Tunnel.getInterface("keyboard")
-----------------------------------------------------------------------------------------------------------------------------------------
-- PLAYER:SURVIVAL
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("player:Survival")
AddEventHandler("player:Survival",function()
	local source = source
	local Passport = vRP.Passport(source)
	if Passport then
		vRP.ClearInventory(Passport)
		vRP.UpgradeThirst(Passport,100)
		vRP.UpgradeHunger(Passport,100)
		vRP.DowngradeStress(Passport,100)
		exports.propertys:Survival(Passport,source)
		TriggerEvent("inventory:CarryDetach",source,Passport)
		exports.discord:Embed("Airport","**[SOURCE]:** "..source.."\n**[PASSAPORTE]:** "..Passport.."\n**[COORDS]:** "..vRP.GetEntityCoords(source))
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PLAYER:DEMAND
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("player:Demand")
AddEventHandler("player:Demand",function(OtherSource)
	local source = source
	local Passport = vRP.Passport(source)
	local OtherPassport = vRP.Passport(OtherSource)
	if Passport and OtherPassport and not exports.bank:CheckTaxes(OtherPassport) and not exports.bank:CheckFines(OtherPassport) then
		local Keyboard = vKEYBOARD.Primary(source,"Valor")
		if Keyboard and vRP.Passport(OtherSource) then
			local Price = parseInt(Keyboard[1],true)
			if vRP.Request(OtherSource,"Cobrança","Aceitar a cobrança de <b>$"..Dotted(Price).."</b> feita por <b>"..Passport.."</b>.") then
				if vRP.PaymentBank(OtherPassport,Price,true) then
					vRP.GiveBank(Passport,Price,true)
				end
			else
				TriggerClientEvent("Notify",source,"Cobrança","Pedido recusado.","vermelho",5000)
			end
		end
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PLAYER:DEBUG
-----------------------------------------------------------------------------------------------------------------------------------------
local Debug = {}
RegisterServerEvent("player:Debug")
AddEventHandler("player:Debug",function()
	local source = source
	local Passport = vRP.Passport(source)
	if Passport and not Debug[Passport] or os.time() > Debug[Passport] then
		TriggerClientEvent("target:Debug",source)
		TriggerEvent("DebugObjects",Passport)
		Debug[Passport] = os.time() + 300
		vRPC.ReloadCharacter(source)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PLAYER:STRESS
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("player:Stress")
AddEventHandler("player:Stress",function(Number)
	local source = source
	local Number = parseInt(Number)
	local Passport = vRP.Passport(source)
	if Passport then
		vRP.DowngradeStress(Passport,Number)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- E
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("e",function(source,Message)
	local Passport = vRP.Passport(source)
	if Passport and vRP.GetHealth(source) > 100 then
		if Message[2] and Message[2] == "friend" then
			local ClosestPed = vRPC.ClosestPed(source)
			if ClosestPed and vRP.GetHealth(ClosestPed) > 100 and not Player(ClosestPed)["state"]["Handcuff"] then
				if vRP.Request(ClosestPed,"Animação","Pedido de <b>"..vRP.FullName(Passport).."</b> da animação <b>"..Message[1].."</b>?") then
					TriggerClientEvent("emotes",ClosestPed,Message[1])
					TriggerClientEvent("emotes",source,Message[1])
				end
			end
		else
			TriggerClientEvent("emotes",source,Message[1])
		end
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- E2
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("e2",function(source,Message)
	local Passport = vRP.Passport(source)
	if Passport and (vRP.HasService(Passport,"Admin") or vRP.HasService(Passport,"Paramedico")) then
		local ClosestPed = vRPC.ClosestPed(source)
		if ClosestPed then
			TriggerClientEvent("emotes",ClosestPed,Message[1])
		end
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- E3
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("e3",function(source,Message)
	local Passport = vRP.Passport(source)
	if Passport and vRP.HasGroup(Passport,"Admin",2) then
		local Players = vRPC.ClosestPeds(source,50)
		for _,v in pairs(Players) do
			async(function()
				TriggerClientEvent("emotes",v,Message[1])
			end)
		end
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PLAYER:DOORS
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("player:Doors")
AddEventHandler("player:Doors",function(Number)
	local source = source
	local Passport = vRP.Passport(source)
	if Passport then
		local Vehicle,Network = vRPC.VehicleList(source)
		if Vehicle then
			local Players = vRPC.Players(source)
			for _,v in pairs(Players) do
				async(function()
					TriggerClientEvent("player:syncDoors",v,Network,Number)
				end)
			end
		end
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PLAYER:CVFUNCTIONS
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("player:cvFunctions")
AddEventHandler("player:cvFunctions",function(Mode)
	local Distance = 1
	if Mode == "rv" then
		Distance = 10
	end

	local source = source
	local Passport = vRP.Passport(source)
	local OtherSource = vRPC.ClosestPed(source,Distance)
	if Passport and OtherSource then
		if vRP.HasService(Passport,"Emergencia") or vRP.ConsultItem(Passport,"rope",1) then
			local Vehicle,Network = vRPC.VehicleList(source)
			if Vehicle then
				local Networked = NetworkGetEntityFromNetworkId(Network)
				if DoesEntityExist(Networked) and GetVehicleDoorLockStatus(Networked) <= 1 then
					if Mode == "rv" then
						vCLIENT.RemoveVehicle(OtherSource)
					elseif Mode == "cv" then
						vCLIENT.PlaceVehicle(OtherSource,Network)
						TriggerEvent("inventory:CarryDetach",source,Passport)
					end
				end
			end
		end
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PRESET
-----------------------------------------------------------------------------------------------------------------------------------------
local Preset = {
	["1"] = {
        ["mp_m_freemode_01"] = {
            ["hat"] = { item = -1, texture = 0 },
            ["pants"] = { item = 195, texture = 0 },
            ["vest"] = { item = 65, texture = 0 },
            ["bracelet"] = { item = -1, texture = 0 },
            ["backpack"] = { item = 0, texture = 0 },
            ["decals"] = { item = 197, texture = 12 },
            ["mask"] = { item = 0, texture = 0 },
            ["shoes"] = { item = 25, texture = 0 },
            ["tshirt"] = { item = 15, texture = 0 },
            ["torso"] = { item = 548, texture = 0 },
            ["accessory"] = { item = 183, texture = 0 },
            ["watch"] = { item = -1, texture = 0 },
            ["arms"] = { item = 22, texture = 0 },
            ["glass"] = { item = 0, texture = 0 },
            ["ear"] = { item = -1, texture = 0 }
        },
        ["mp_f_freemode_01"] = {
            ["hat"] = { item = -1, texture = 0 },
            ["pants"] = { item = 209, texture = 0 },
            ["vest"] = { item = 63, texture = 0 },
            ["bracelet"] = { item = -1, texture = 0 },
            ["backpack"] = { item = 0, texture = 0 },
            ["decals"] = { item = 209, texture = 12 },
            ["mask"] = { item = 0, texture = 0 },
            ["shoes"] = { item = 25, texture = 0 },
            ["tshirt"] = { item = 254, texture = 0 },
            ["torso"] = { item = 584, texture = 0 },
            ["accessory"] = { item = 148, texture = 0 },
            ["watch"] = { item = -1, texture = 0 },
            ["arms"] = { item = 21, texture = 0 },
            ["glass"] = { item = 0, texture = 0 },
            ["ear"] = { item = -1, texture = 0 }
        }
	},
	["2"] = {
        ["mp_m_freemode_01"] = {
            ["hat"] = { item = -1, texture = 0 },
            ["pants"] = { item = 31, texture = 0 },
            ["vest"] = { item = 0, texture = 0 },
            ["bracelet"] = { item = -1, texture = 0 },
            ["backpack"] = { item = 0, texture = 0 },
            ["decals"] = { item = 58, texture = 1 },
            ["mask"] = { item = 0, texture = 0 },
            ["shoes"] = { item = 25, texture = 0 },
            ["tshirt"] = { item = 154, texture = 0 },
            ["torso"] = { item = 250, texture = 0 },
            ["accessory"] = { item = 171, texture = 0 },
            ["watch"] = { item = -1, texture = 0 },
            ["arms"] = { item = 85, texture = 0 },
            ["glass"] = { item = 0, texture = 0 },
            ["ear"] = { item = -1, texture = 0 }
        },
        ["mp_f_freemode_01"] = {
            ["hat"] = { item = -1, texture = 0 },
            ["pants"] = { item = 30, texture = 0 },
            ["vest"] = { item = 0, texture = 0 },
            ["bracelet"] = { item = -1, texture = 0 },
            ["backpack"] = { item = 0, texture = 0 },
            ["decals"] = { item = 66, texture = 1 },
            ["mask"] = { item = 0, texture = 0 },
            ["shoes"] = { item = 25, texture = 0 },
            ["tshirt"] = { item = 190, texture = 0 },
            ["torso"] = { item = 258, texture = 0 },
            ["accessory"] = { item = 96, texture = 0 },
            ["watch"] = { item = -1, texture = 0 },
            ["arms"] = { item = 109, texture = 0 },
            ["glass"] = { item = 0, texture = 0 },
            ["ear"] = { item = -1, texture = 0 }
        }
	}
}
local PoliceServices = { "LSPD","BCSO","SAPR" }
local PoliceServiceLookup = { LSPD = true, BCSO = true, SAPR = true }
local LegacyServiceDecals = {
	["mp_m_freemode_01"] = {
		[197] = { [12] = true },
		[58] = { [1] = true }
	},
	["mp_f_freemode_01"] = {
		[209] = { [12] = true },
		[66] = { [1] = true }
	}
}
local UniformSnapshots = {}
local UniformCaptureBusy = {}
local UniformPassportBySource = {}

local function copyTable(Value,Seen)
	if type(Value) ~= "table" then
		return Value
	end

	Seen = Seen or {}
	if Seen[Value] then
		return Seen[Value]
	end

	local Copy = {}
	Seen[Value] = Copy
	for Key,Data in pairs(Value) do
		Copy[copyTable(Key,Seen)] = copyTable(Data,Seen)
	end

	return Copy
end

local function copyCustomization(Customization)
	if type(Customization) ~= "table" then
		return nil
	end

	local Slots = 0
	for Slot,Data in pairs(Customization) do
		if type(Slot) ~= "string" or type(Data) ~= "table" or tonumber(Data.item) == nil or tonumber(Data.texture) == nil then
			return nil
		end
		Slots = Slots + 1
	end

	return Slots >= 15 and copyTable(Customization) or nil
end

local function sanitizeLegacyServiceDecal(Clothes,Model)
	local ModelDecals = LegacyServiceDecals[Model]
	local Decals = type(Clothes) == "table" and Clothes.decals or nil
	if not ModelDecals or type(Decals) ~= "table" then
		return false
	end

	local Item = tonumber(Decals.item)
	local Texture = tonumber(Decals.texture)
	if not Item or not Texture or not ModelDecals[Item] or not ModelDecals[Item][Texture] then
		return false
	end

	Clothes.decals = { item = 0, texture = 0 }
	return true
end

local function hasPoliceService(Passport)
	for _,Permission in ipairs(PoliceServices) do
		if vRP.HasService(Passport,Permission) then
			return true
		end
	end

	return false
end

local function uniformClass(Passport,Number)
	if Number == "1" and hasPoliceService(Passport) then
		return "Police"
	elseif Number == "2" and vRP.HasService(Passport,"Paramedico") then
		return "Paramedico"
	end

	return nil
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PLAYER:PRESET
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("player:Preset")
AddEventHandler("player:Preset",function(Number)
	local source = tonumber(source)
	if not source or source <= 0 or (Number ~= "1" and Number ~= "2") or not Preset[Number] then
		return
	end

	local Passport = vRP.Passport(source)
	local Class = Passport and uniformClass(Passport,Number) or nil
	local Model = Class and vRP.ModelPlayer(source) or nil
	if not Passport or not Class or not Model or not Preset[Number][Model] then
		return
	end

	Passport = tostring(Passport)
	local Snapshot = UniformSnapshots[Passport]
	if not Snapshot then
		if UniformCaptureBusy[Passport] then
			return
		end

		UniformCaptureBusy[Passport] = true
		local Success,Customization = pcall(function()
			return vSKINSHOP.Customization(source)
		end)
		UniformCaptureBusy[Passport] = nil

		local CurrentPassport = vRP.Passport(source)
		if not CurrentPassport or tostring(CurrentPassport) ~= Passport or uniformClass(Passport,Number) ~= Class or vRP.ModelPlayer(source) ~= Model then
			return
		end

		local Clothes = Success and copyCustomization(Customization) or nil
		if not Clothes then
			TriggerClientEvent("Notify",source,"Fardamento","Não foi possível preservar sua roupa civil. Tente novamente.","vermelho",5000)
			return
		end

		Snapshot = { Class = Class, Clothes = Clothes, LegacyResidue = sanitizeLegacyServiceDecal(Clothes,Model) }
		UniformSnapshots[Passport] = Snapshot
	else
		Snapshot.Class = Class
	end

	UniformPassportBySource[source] = Passport
	TriggerClientEvent("skinshop:Apply",source,Preset[Number][Model],false)
end)

AddEventHandler("player:ServiceLeave",function(_,Passport,Permission)
	Passport = tostring(Passport or "")
	local Snapshot = UniformSnapshots[Passport]
	if not Snapshot then
		return
	end

	if Snapshot.Class == "Police" then
		if not PoliceServiceLookup[Permission] or hasPoliceService(Passport) then
			return
		end
	elseif Snapshot.Class == "Paramedico" then
		if Permission ~= "Paramedico" or vRP.HasService(Passport,"Paramedico") then
			return
		end
	else
		return
	end

	local CurrentSource = tonumber(vRP.Source(Passport))
	local CurrentPassport = CurrentSource and vRP.Passport(CurrentSource) or nil
	if not CurrentSource or CurrentSource <= 0 or not CurrentPassport or tostring(CurrentPassport) ~= Passport then
		return
	end

	TriggerClientEvent("skinshop:Apply",CurrentSource,copyTable(Snapshot.Clothes),Snapshot.LegacyResidue == true)
	UniformSnapshots[Passport] = nil
	UniformCaptureBusy[Passport] = nil
	if UniformPassportBySource[CurrentSource] == Passport then
		UniformPassportBySource[CurrentSource] = nil
	end
end)

AddEventHandler("playerDropped",function()
	local PlayerSource = tonumber(source)
	local Passport = PlayerSource and vRP.Passport(PlayerSource) or nil
	Passport = Passport and tostring(Passport) or (PlayerSource and UniformPassportBySource[PlayerSource] or nil)
	if Passport then
		UniformSnapshots[Passport] = nil
		UniformCaptureBusy[Passport] = nil
	end
	if PlayerSource then
		UniformPassportBySource[PlayerSource] = nil
	end
end)

AddEventHandler("onResourceStop",function(Resource)
	if Resource == GetCurrentResourceName() then
		UniformSnapshots = {}
		UniformCaptureBusy = {}
		UniformPassportBySource = {}
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PLAYER:CHECKTRUNK
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("player:checkTrunk")
AddEventHandler("player:checkTrunk",function()
	local source = source
	local ClosestPed = vRPC.ClosestPed(source)
	if ClosestPed then
		TriggerClientEvent("player:checkTrunk",ClosestPed)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PLAYER:CHECKTRASH
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("player:checkTrash")
AddEventHandler("player:checkTrash",function()
	local source = source
	local ClosestPed = vRPC.ClosestPed(source)
	if ClosestPed then
		TriggerClientEvent("player:checkTrash",ClosestPed)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PLAYER:CHECKSHOES
-----------------------------------------------------------------------------------------------------------------------------------------
local UniqueShoes = {}
RegisterServerEvent("player:checkShoes")
AddEventHandler("player:checkShoes",function(Entity)
	local source = source
	local Passport = vRP.Passport(source)
	if Passport then
		if not UniqueShoes[Entity] then
			UniqueShoes[Entity] = os.time()
		end

		if os.time() >= UniqueShoes[Entity] and vSKINSHOP.checkShoes(Entity) then
			vRP.GenerateItem(Passport,"WEAPON_SHOES",2,true)
			UniqueShoes[Entity] = os.time() + 300
		end
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PLAYER:OUTFIT
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("player:Outfit")
AddEventHandler("player:Outfit",function(Mode)
	local source = source
	local Passport = vRP.Passport(source)
	if Passport and not exports.hud:Repose(Passport) and not exports.hud:Wanted(Passport) then
		TriggerClientEvent("skinshop:set"..Mode,source)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PLAYER:DEATH
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("player:Death")
AddEventHandler("player:Death",function(OtherSource,Weapon)
	local source = source
	local Passport = vRP.Passport(source)
	if not Passport or not OtherSource then
		return false
	end

	local OtherPassport = vRP.Passport(OtherSource)
	if not OtherPassport then
		return false
	end

	local Entity = vRP.DoesEntityExist(source)
	local OtherEntity = vRP.DoesEntityExist(OtherSource)
	if not Entity or not OtherEntity then
		return false
	end

	local Coords = vRP.GetEntityCoords(source)
	local OtherCoords = vRP.GetEntityCoords(OtherSource)

	exports.oxmysql:insert_async("INSERT INTO deaths_creative (Attacker,Victim,Weapon,Timestamp) VALUES (?,?,?,?)",{ OtherPassport,Passport,Weapon,os.time() })
	exports.discord:Embed("Deaths","**[ASSASSINO]:** "..OtherPassport.."\n**[LOCALIZAÇÃO]:** "..OtherCoords.."\n\n**[VÍTIMA]:** "..Passport.."\n**[LOCALIZAÇÃO]:** "..Coords)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECT
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("Connect",function(Passport,source)
	TriggerClientEvent("player:DuiTable",source,DuiTextures)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- DISCONNECT
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("Disconnect",function(Passport)
	if Debug[Passport] then
		Debug[Passport] = nil
	end
end)
