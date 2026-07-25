-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
ScubaMask = nil
ScubaTank = nil
-----------------------------------------------------------------------------------------------------------------------------------------
-- INVENTORY:SCUBAREMOVE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("inventory:ScubaRemove")
AddEventHandler("inventory:ScubaRemove",function()
	if ScubaMask and DoesEntityExist(ScubaMask) then
		TriggerServerEvent("DeleteObject",NetworkGetNetworkIdFromEntity(ScubaMask))
		ScubaMask = nil
	end

	if ScubaTank and DoesEntityExist(ScubaTank) then
		TriggerServerEvent("DeleteObject",NetworkGetNetworkIdFromEntity(ScubaTank))
		ScubaTank = nil
	end

	SetEnableScuba(PlayerPedId(),false)
	SetPedMaxTimeUnderwater(PlayerPedId(),10.0)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- INVENTORY:SCUBA
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("inventory:Scuba")
AddEventHandler("inventory:Scuba",function()
	if ScubaMask or ScubaTank then
		TriggerEvent("inventory:ScubaRemove")
	else
		local Ped = PlayerPedId()
		local Coords = GetEntityCoords(Ped)

		local Networked = vRPS.CreateObject("p_s_scuba_tank_s",Coords["x"],Coords["y"],Coords["z"])
		if not Networked then return end

		ScubaTank = LoadNetwork(Networked)
		while not DoesEntityExist(ScubaTank) do
			Wait(100)
		end

		local Networked = vRPS.CreateObject("p_s_scuba_mask_s",Coords["x"],Coords["y"],Coords["z"])
		if not Networked then return end

		ScubaMask = LoadNetwork(Networked)
		while not DoesEntityExist(ScubaMask) do
			Wait(100)
		end

		AttachEntityToEntity(ScubaTank,Ped,GetPedBoneIndex(Ped,24818),-0.28,-0.24,0.0,180.0,90.0,0.0,true,true,false,true,2,true)
		AttachEntityToEntity(ScubaMask,Ped,GetPedBoneIndex(Ped,12844),0.0,0.0,0.0,180.0,90.0,0.0,true,true,false,true,2,true)
		SetPedMaxTimeUnderwater(Ped,10000.0)
		SetEntityLodDist(ScubaMask,0xFFFF)
		SetEntityLodDist(ScubaTank,0xFFFF)
		SetEnableScuba(Ped,true)
	end
end)