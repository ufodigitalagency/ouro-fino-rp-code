-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")
vRP = Proxy.getInterface("vRP")
-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECTION
-----------------------------------------------------------------------------------------------------------------------------------------
vSERVER = Tunnel.getInterface("chest")
-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Opened = false
local Animation = false
local StoreBlock = false
local TakeBlock = false
-----------------------------------------------------------------------------------------------------------------------------------------
-- CHESTS
-----------------------------------------------------------------------------------------------------------------------------------------
local Chests = {
	{ Name = "Policia", Coords = vec3(-421.63,1088.31,327.68), Mode = "1" },
	{ Name = "Paramedico", Coords = vec3(-675.2672,316.5318,93.2960), Mode = "2" },
	{ Name = "Ballas", Coords = vec3(-626.63,180.34,66.69), Mode = "4" },
	{ Name = "Lester", Coords = vec3(1275.21,-1712.12,54.64), Mode = "2" },
	{ Name = "Pombal", Coords = vec3(2539.69,2524.95,46.24), Mode = "4", Marker = true, Radius = 0.5, Distance = 1.75 },
	{ Name = "SaoJudas", Coords = vec3(-482.34,1614.76,366.64), Mode = "4", Marker = true, Radius = 0.5, Distance = 1.75 },
	{ Name = "Policia", Coords = vec3(-412.3901,1102.7982,328.1586), Mode = "5", Radius = 0.35, Distance = 1.5 }
}
-----------------------------------------------------------------------------------------------------------------------------------------
-- LABELS
-----------------------------------------------------------------------------------------------------------------------------------------
local Labels = {
	["1"] = {
		{
			event = "chest:Open",
			label = "Compartimento Geral",
			tunnel = "client",
			service = "Normal"
		},{
			event = "chest:Open",
			label = "Compartimento Pessoal",
			tunnel = "client",
			service = "Personal"
		},{
			event = "chest:Armour",
			label = "Colete Balístico",
			tunnel = "server"
		}
	},
	["2"] = {
		{
			event = "chest:Open",
			label = "Abrir",
			tunnel = "client",
			service = "Normal"
		}
	},
	["3"] = {
		{
			event = "chest:Open",
			label = "Abrir",
			tunnel = "client",
			service = "Tray"
		}
	},
	["4"] = {
		{
			event = "chest:Open",
			label = "Abrir",
			tunnel = "client",
			service = "Normal"
		},{
			event = "chest:Open",
			label = "Metas",
			tunnel = "client",
			service = "Goals"
		}
	},
	["5"] = {
		{
			event = "chest:Open",
			label = "Baú da Polícia",
			tunnel = "client",
			service = "Normal"
		}
	}
}
-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADSERVERSTART
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	for Name,v in pairs(Chests) do
		exports.target:AddCircleZone("Chest:"..Name,v.Coords,v.Radius or 0.25,{
			name = "Chest:"..Name,
			heading = 0.0,
			useZ = true
		},{
			Distance = v.Distance or 1.25,
			shop = v.Name,
			options = Labels[v.Mode]
		})
	end
end)

CreateThread(function()
	while true do
		local TimeDistance = 1000
		local Ped = PlayerPedId()

		if LocalPlayer.state.Active and not IsPedInAnyVehicle(Ped,false) then
			local Coords = GetEntityCoords(Ped)

			for _,v in pairs(Chests) do
				if v.Marker then
					local Distance = #(Coords - v.Coords)
					if Distance <= 8.0 then
						TimeDistance = 1
						DrawMarker(2,v.Coords.x,v.Coords.y,v.Coords.z + 0.15,0.0,0.0,0.0,180.0,0.0,0.0,0.35,0.35,0.35,255,215,0,190,true,true,2,false)

						if Distance <= 1.5 then
							BeginTextCommandDisplayHelp("STRING")
							AddTextComponentSubstringPlayerName("Pressione ~INPUT_CONTEXT~ para acessar o ~y~bau da faccao")
							EndTextCommandDisplayHelp(0,false,true,-1)

							if IsControlJustPressed(0,38) then
								TriggerEvent("chest:Open",v.Name,"Normal")
							end
						end
					end
				end
			end
		end

		Wait(TimeDistance)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- CHEST:OPEN
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("chest:Open")
AddEventHandler("chest:Open",function(Name,Mode,Item,Blocked,Force)
	if not Name or not Mode then
		return false
	end

	if Mode == "Goals" then
		Name = "Painel:Goals:"..SplitOne(Name,":")
		TakeBlock = true
	end

	local Ped = PlayerPedId()
	if not vSERVER.Permissions(Name,Mode,Item) or GetEntityHealth(Ped) <= 100 then
		return false
	end

	if Blocked then
		StoreBlock = true
	else
		local BlockedTypes = { "Helicrash","Halloween","Christmas" }
		for Number = 1,#BlockedTypes do
			if SplitBoolean(Name,BlockedTypes[Number],":") then
				StoreBlock = true
				break
			end
		end
	end

	Opened = Name

	if Mode ~= "Item" then
		Animation = true
		vRP.playAnim(false,{"amb@prop_human_bum_bin@base","base"},true)
	end

	TriggerEvent("inventory:Open", {
		Type = "Chest",
		Resource = "chest",
		Force = Force,
		Right = "Baú"
	})
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- CHEST:ITEM
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("chest:Item",function(Name)
	local FullName = splitString(Name)
	if vSERVER.Permissions(FullName[1]..":"..FullName[3],"Item") and GetEntityHealth(PlayerPedId()) > 100 then
		Opened = true
		TriggerEvent("inventory:Open",{ Type = "Chest", Resource = "chest", Right = "Baú" })
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- CHEST:RECYCLE
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("chest:Recycle",function()
	if vSERVER.Permissions("Recycle","Tray") and GetEntityHealth(PlayerPedId()) > 100 then
		Opened = true
		TriggerEvent("inventory:Open",{ Type = "Chest", Resource = "chest", Right = "Baú" })
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- INVENTORY:CLOSE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("inventory:Close")
AddEventHandler("inventory:Close",function(Force)
	if (not Force and Opened) or (Force and Opened and Opened == Force) then
		if Animation then
			Animation = false
			vRP.Destroy()
		end

		Opened = false
		TakeBlock = false
		StoreBlock = false
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- INVENTORY:CLOSED
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("inventory:Closed",function(Name)
	if Opened and Opened == Name then
		if Animation then
			Animation = false
			vRP.Destroy()
		end

		Opened = false
		TakeBlock = false
		StoreBlock = false
		TriggerEvent("inventory:Close")
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- TAKE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("Take",function(Data,Callback)
	Callback(vSERVER.Take(Data.Item,Data.Slot,Data.Amount,Data.Target,TakeBlock))
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- STORE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("Store",function(Data,Callback)
	Callback(vSERVER.Store(Data.Item,Data.Slot,Data.Amount,Data.Target,StoreBlock))
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- UPDATE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("Update",function(Data,Callback)
	Callback(vSERVER.Update(Data.Slot,Data.Target,Data.Amount))
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- MOUNT
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("Mount",function(Data,Callback)
	local Primary,Secondary,PrimaryWeight,SecondaryWeight,PrimarySlots,SecondarySlots = vSERVER.Mount()
	if Primary then
		Callback({
			Primary = {
				Data = Primary,
				MaxWeight = PrimaryWeight,
				Slots = PrimarySlots or Theme.inventory.slots.default
			},
			Secondary = {
				Data = Secondary,
				MaxWeight = SecondaryWeight,
				Slots = SecondarySlots or Theme.inventory.slots.default
			}
		})
	end
end)
