-----------------------------------------------------------------------------------------------------------------------------------------
-- BLIPS DE LOJAS DE ROUPA
-----------------------------------------------------------------------------------------------------------------------------------------
local SkinshopBlips = {}

local function clearSkinshopBlips()
	for _,Blip in pairs(SkinshopBlips) do
		if DoesBlipExist(Blip) then
			RemoveBlip(Blip)
		end
	end

	SkinshopBlips = {}
end

local function addSkinshopBlip(Data)
	if not Data or not Data.Coords then
		return
	end

	local Coords = Data.Coords
	local Blip = AddBlipForCoord(Coords.x,Coords.y,Coords.z)
	SetBlipSprite(Blip,73)
	SetBlipColour(Blip,47)
	SetBlipScale(Blip,0.52)
	SetBlipAsShortRange(Blip,true)

	BeginTextCommandSetBlipName("STRING")
	AddTextComponentString(Data.Name or "Loja de Roupas")
	EndTextCommandSetBlipName(Blip)

	SkinshopBlips[#SkinshopBlips + 1] = Blip
end

RegisterNetEvent("skinshop:Init")
AddEventHandler("skinshop:Init",function(Data)
	clearSkinshopBlips()

	for _,v in pairs(Data or {}) do
		addSkinshopBlip(v)
	end

	print(("[skinshop] %s blips de loja de roupas criados no mapa."):format(#SkinshopBlips))
end)

RegisterNetEvent("skinshop:Insert")
AddEventHandler("skinshop:Insert",function(Data)
	addSkinshopBlip(Data)
end)

AddEventHandler("onResourceStop",function(Resource)
	if Resource ~= GetCurrentResourceName() then
		return
	end

	clearSkinshopBlips()
end)
