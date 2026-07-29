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
vCLIENT = Tunnel.getInterface("skinshop")
Tunnel.bindInterface("skinshop",Lil)
-----------------------------------------------------------------------------------------------------------------------------------------
-- LOCATIONS
-----------------------------------------------------------------------------------------------------------------------------------------
local Locations = {
	{ Coords = vec3(71.29,-1398.68,29.37) },
	{ Coords = vec3(-708.56,-160.5,37.41) },
	{ Coords = vec3(-158.76,-296.94,39.73) },
	{ Coords = vec3(-829.08,-1073.27,11.32) },
	{ Coords = vec3(-1192.23,-771.74,17.32) },
	{ Coords = vec3(-1456.98,-241.17,49.81) },
	{ Coords = vec3(11.87,6513.59,31.88) },
	{ Coords = vec3(1696.92,4829.24,42.06) },
	{ Coords = vec3(122.93,-221.48,54.56) },
	{ Coords = vec3(617.77,2761.81,42.09) },
	{ Coords = vec3(1190.79,2714.29,38.22) },
	{ Coords = vec3(-3173.28,1046.04,20.86) },
	{ Coords = vec3(-1108.61,2709.59,19.11) },
	{ Coords = vec3(429.67,-800.14,29.49) },
	{ Coords = vec3(-448.11,1103.87,327.68), Name = "Vestiario Policial" },
	{ Coords = vec3(-298.76,1603.3,347.27), Name = "Loja de Roupas São Judas" },
	{ Coords = vec3(2551.73,2412.35,53.85), Name = "Loja de Roupas Pombal" }
}
-----------------------------------------------------------------------------------------------------------------------------------------
-- CLOTHING PAYLOAD
-----------------------------------------------------------------------------------------------------------------------------------------
-- The NUI is client-side, so keep persisted clothing data narrowly shaped. The
-- collection fields are optional and coexist with legacy global GTA indexes.
local Components = {
	"pants","arms","tshirt","torso","vest","shoes","mask","backpack","accessory","decals"
}

local Props = {
	"hat","glass","ear","watch","bracelet"
}

local function safeInteger(Value,Minimum,Maximum,Default)
	Value = tonumber(Value)
	if not Value then
		return Default
	end

	Value = math.floor(Value)
	if Value < Minimum or Value > Maximum then
		return Default
	end

	return Value
end

local function safeCollection(Value)
	if type(Value) ~= "string" or #Value == 0 or #Value > 64 or not Value:match("^[%w_%-]+$") then
		return nil
	end

	return Value
end

local function sanitizeSlot(Data,IsProp)
	Data = type(Data) == "table" and Data or {}

	local Result = {
		item = safeInteger(Data.item,IsProp and -1 or 0,10000,IsProp and -1 or 0),
		texture = safeInteger(Data.texture,0,1000,0)
	}

	local Collection = safeCollection(Data.collection)
	local Drawable = safeInteger(Data.drawable,0,10000,nil)
	if Collection and Drawable then
		Result.collection = Collection
		Result.drawable = Drawable
	end

	return Result
end

local function sanitizeClothes(Clothes)
	if type(Clothes) ~= "table" then
		return nil
	end

	local Result = {}
	for _,Slot in ipairs(Components) do
		Result[Slot] = sanitizeSlot(Clothes[Slot],false)
	end

	for _,Slot in ipairs(Props) do
		Result[Slot] = sanitizeSlot(Clothes[Slot],true)
	end

	return Result
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- CHECKPERMISSION
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.CheckPermission(Table)
	local source = source
	local Passport = vRP.Passport(source)

	return Passport and vRP.HasTable(Passport,Table) and true or false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- UPDATE
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Update(Clothes)
	local source = source
	local Passport = vRP.Passport(source)
	local Sanitized = sanitizeClothes(Clothes)
	if Passport and Sanitized then
		vRP.Query("playerdata/SetData",{ Passport = Passport, Name = "Clothings", Information = json.encode(Sanitized) })
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- SKINSHOP:SEND
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("skinshop:Send")
AddEventHandler("skinshop:Send",function()
	local source = source
	local Passport = vRP.Passport(source)

	if not Passport then
		return false
	end

	local OtherSource = vRPC.ClosestPed(source)
	if not OtherSource or vRP.GetHealth(OtherSource) <= 100 then
		return false
	end

	if vRP.ModelPlayer(source) ~= vRP.ModelPlayer(OtherSource) then
		TriggerClientEvent("Notify",source,"Aviso","Vestimentas recusada.","amarelo",5000)
		return false
	end

	if vRP.Request(OtherSource,false,"Aceitar vestimentas de <b>"..vRP.FullName(Passport).."</b>?") then
		TriggerClientEvent("Notify",source,"Sucesso","Vestimentas enviada.","verde",5000)
		TriggerClientEvent("skinshop:Apply",OtherSource,vCLIENT.CurrentClothes(source),true)
	else
		TriggerClientEvent("Notify",source,"Aviso","Vestimentas recusada.","amarelo",5000)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- SKINSHOP:REMOVE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("skinshop:Remove")
AddEventHandler("skinshop:Remove",function(Mode)
	local source = source
	local Passport = vRP.Passport(source)
	if Passport then
		local ClosestPed = vRPC.ClosestPed(source)
		if ClosestPed and vRP.HasService(Passport,"Emergencia") then
			TriggerClientEvent("skinshop:set"..Mode,ClosestPed)
		end
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADINITSYSTEM
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	local Consult = vRP.SingleQuery("entitydata/GetData",{ Name = "Skinshop" })
	local Result = Consult and json.decode(Consult.Information) or {}

	for _,v in pairs(Result) do
		table.insert(Locations,v)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- ADD
-----------------------------------------------------------------------------------------------------------------------------------------
exports("Add",function(Table)
	local Consult = vRP.SingleQuery("entitydata/GetData",{ Name = "Skinshop" })
	local Result = Consult and json.decode(Consult.Information) or {}

	table.insert(Result,Table)
	table.insert(Locations,Table)

	TriggerClientEvent("skinshop:Insert",-1,Table)
	vRP.Query("entitydata/SetData",{ Name = "Skinshop", Information = json.encode(Result) })
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECT
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("Connect",function(Passport,source)
	TriggerClientEvent("skinshop:Init",source,Locations)
end)
