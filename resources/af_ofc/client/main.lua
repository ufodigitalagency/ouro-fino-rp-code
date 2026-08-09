local PublicZone = "AF_OFC:Public"
local OrganizerZone = "AF_OFC:Organizer"
local GongZone = "AF_OFC:Gong"

local Npc = nil
local SetupComplete = false
local NpcSpawnInProgress = false
local UiOpen = false
local UiMode = nil
local SessionToken = nil
local RequestSequence = 0
local PendingOpenRequest = 0
local PendingGongRequest = 0

local function nextRequestId()
	RequestSequence = RequestSequence + 1
	if RequestSequence > 2147483647 then
		RequestSequence = 1
	end

	return RequestSequence
end

local function notify(Message,Color)
	TriggerEvent("Notify",Config.Texts.Notifications.Title,Message,Color or "amarelo",5000)
end

local function closeUi(NotifyServer)
	local Token = SessionToken

	UiOpen = false
	UiMode = nil
	SessionToken = nil

	SendNUIMessage({ Action = "close" })
	SetNuiFocus(false,false)
	SetNuiFocusKeepInput(false)

	if NotifyServer and Token then
		TriggerServerEvent("af_ofc:closeSession",{ SessionToken = Token })
	end
end

local function removeTargets()
	pcall(function()
		exports.target:RemCircleZone(PublicZone)
	end)

	pcall(function()
		exports.target:RemCircleZone(OrganizerZone)
	end)

	pcall(function()
		exports.target:RemCircleZone(GongZone)
	end)
end

local function removeNpc()
	if Npc and DoesEntityExist(Npc) then
		FreezeEntityPosition(Npc,false)
		SetEntityAsMissionEntity(Npc,true,true)
		DeletePed(Npc)
	end

	Npc = nil
end

local function cleanup()
	removeTargets()
	removeNpc()
	closeUi(false)
	SetupComplete = false
end

local function loadModel(ModelName)
	local Model = GetHashKey(ModelName)
	if not IsModelInCdimage(Model) or not IsModelValid(Model) then
		return nil
	end

	RequestModel(Model)
	local Timeout = GetGameTimer() + Config.PublicNpc.SpawnTimeout
	while not HasModelLoaded(Model) and GetGameTimer() < Timeout do
		Wait(100)
	end

	return HasModelLoaded(Model) and Model or nil
end

local function createNpc()
	if Npc and DoesEntityExist(Npc) then
		return true
	end

	if NpcSpawnInProgress then
		return false
	end

	NpcSpawnInProgress = true
	Npc = nil

	local Model = loadModel(Config.PublicNpc.Model)
	if not Model then
		NpcSpawnInProgress = false
		print(Config.Texts.Console.NpcModelUnavailable:format(Config.PublicNpc.Model))
		return false
	end

	local Coords = Config.PublicNpc.Coords
	RequestCollisionAtCoord(Coords.x,Coords.y,Coords.z)
	Npc = CreatePed(4,Model,Coords.x,Coords.y,Coords.z,Coords.w,false,false)
	SetModelAsNoLongerNeeded(Model)

	if not Npc or Npc == 0 or not DoesEntityExist(Npc) then
		Npc = nil
		NpcSpawnInProgress = false
		return false
	end

	DecorSetBool(Npc,"CREATIVE_PED",true)
	SetEntityAsMissionEntity(Npc,true,true)
	SetEntityLoadCollisionFlag(Npc,true)
	FreezeEntityPosition(Npc,true)

	local CollisionTimeout = GetGameTimer() + Config.PublicNpc.SpawnTimeout
	while not HasCollisionLoadedAroundEntity(Npc) and GetGameTimer() < CollisionTimeout do
		RequestCollisionAtCoord(Coords.x,Coords.y,Coords.z)
		Wait(100)
	end

	SetEntityCoordsNoOffset(Npc,Coords.x,Coords.y,Coords.z,false,false,false)
	SetEntityHeading(Npc,Coords.w)
	SetEntityCollision(Npc,true,true)
	SetEntityVisible(Npc,true,false)
	ResetEntityAlpha(Npc)
	SetEntityInvincible(Npc,true)
	SetEntityCanBeDamaged(Npc,false)
	SetBlockingOfNonTemporaryEvents(Npc,true)
	TaskSetBlockingOfNonTemporaryEvents(Npc,true)
	SetPedCanRagdoll(Npc,false)
	SetPedDiesWhenInjured(Npc,false)
	SetPedFleeAttributes(Npc,0,false)

	if Config.PublicNpc.Scenario and Config.PublicNpc.Scenario ~= "" then
		TaskStartScenarioInPlace(Npc,Config.PublicNpc.Scenario,0,true)
	end
	SetPedKeepTask(Npc,true)

	NpcSpawnInProgress = false
	return true
end

local function registerTargets()
	removeTargets()

	exports.target:AddCircleZone(PublicZone,Config.PublicNpc.Coords.xyz,Config.PublicNpc.TargetRadius,{
		name = PublicZone,
		heading = Config.PublicNpc.Coords.w,
		useZ = false
	},{
		Distance = Config.PublicNpc.TargetDistance,
		options = {
			{
				event = "af_ofc:targetViewEvent",
				label = Config.Texts.Target.ViewEvent,
				tunnel = "client"
			},{
				event = "af_ofc:targetOpenBetting",
				label = Config.Texts.Target.OpenBetting,
				tunnel = "client"
			},{
				event = "af_ofc:targetCheckIn",
				label = Config.Texts.Target.CheckIn,
				tunnel = "client"
			}
		}
	})

	if Config.OrganizerDesk.Enabled then
		exports.target:AddCircleZone(OrganizerZone,Config.OrganizerDesk.Coords.xyz,Config.OrganizerDesk.TargetRadius,{
			name = OrganizerZone,
			heading = Config.OrganizerDesk.Coords.w,
			useZ = false
		},{
			Distance = Config.OrganizerDesk.TargetDistance,
			options = {
				{
					event = "af_ofc:targetOrganizerPanel",
					label = Config.Texts.Target.OrganizerPanel,
					tunnel = "client"
				}
			}
		})
	end

	if Config.Gong.Enabled then
		exports.target:AddCircleZone(GongZone,Config.Gong.Coords,Config.Gong.TargetRadius,{
			name = GongZone,
			useZ = false
		},{
			Distance = Config.Gong.TargetDistance,
			options = {
				{
					event = "af_ofc:targetRingGong",
					label = Config.OperationalTexts.Target.RingGong,
					tunnel = "client"
				}
			}
		})
	end
end

local function setup()
	if SetupComplete then
		return
	end

	SetupComplete = true
	registerTargets()
end

local function startPublicMonitor()
	CreateThread(function()
		while UiOpen and UiMode == "public" do
			Wait(Config.Interaction.ClientValidationInterval)

			local Ped = PlayerPedId()
			local Invalid = not LocalPlayer.state.Active or not DoesEntityExist(Ped) or GetEntityHealth(Ped) <= 100
			if not Invalid then
				Invalid = #(GetEntityCoords(Ped) - Config.PublicNpc.Coords.xyz) > Config.Interaction.ClientCloseDistance
			end

			if Invalid then
				closeUi(true)
				notify(Config.Texts.Notifications.InvalidSession,"vermelho")
				break
			end
		end
	end)
end

RegisterNetEvent("af_ofc:targetViewEvent",function()
	PendingOpenRequest = nextRequestId()
	TriggerServerEvent("af_ofc:requestEvent",PendingOpenRequest)
end)

RegisterNetEvent("af_ofc:targetOpenBetting",function()
	PendingOpenRequest = nextRequestId()
	TriggerServerEvent("af_ofc:requestBettingPanel",PendingOpenRequest)
end)

RegisterNetEvent("af_ofc:targetCheckIn",function()
	TriggerServerEvent("af_ofc:requestCheckIn",nextRequestId())
end)

RegisterNetEvent("af_ofc:targetOrganizerPanel",function()
	PendingOpenRequest = nextRequestId()
	TriggerServerEvent("af_ofc:requestOrganizerDesk",PendingOpenRequest)
end)

RegisterNetEvent("af_ofc:targetRingGong",function()
	PendingGongRequest = nextRequestId()
	TriggerServerEvent("af_ofc:requestRingGong",PendingGongRequest)
end)

RegisterNetEvent("af_ofc:ringGongAuthorized",function(Data)
	if type(Data) ~= "table" or tonumber(Data.RequestId) ~= PendingGongRequest or type(Data.SessionToken) ~= "string" then
		return
	end

	PendingGongRequest = 0
	TriggerServerEvent("af_ofc:ringGong",{
		RequestId = Data.RequestId,
		SessionToken = Data.SessionToken
	})
end)

RegisterNetEvent("af_ofc:openAuthorized",function(Data)
	if type(Data) ~= "table" or type(Data.Snapshot) ~= "table" then
		return
	end

	local RequestId = tonumber(Data.RequestId)
	local CommandOrigin = Data.Origin == "command"
	if not RequestId or type(Data.SessionToken) ~= "string" or (not CommandOrigin and RequestId ~= PendingOpenRequest) then
		return
	end

	PendingOpenRequest = 0
	UiOpen = true
	UiMode = Data.Snapshot.Mode
	SessionToken = Data.SessionToken

	SendNUIMessage({
		Action = "open",
		Payload = {
			RequestId = RequestId,
			View = Data.View,
			Snapshot = Data.Snapshot
		}
	})
	SetNuiFocus(true,true)
	SetNuiFocusKeepInput(false)

	if UiMode == "public" then
		startPublicMonitor()
	end
end)

RegisterNetEvent("af_ofc:actionResult",function(Data)
	if type(Data) ~= "table" then
		return
	end

	if Data.Kind == "checkIn" then
		notify(Data.Message or Config.Texts.Notifications.InvalidRequest,Data.Success and "verde" or "amarelo")
		return
	end

	if not UiOpen then
		return
	end

	SendNUIMessage({ Action = "actionResult", Payload = Data })
end)

RegisterNetEvent("af_ofc:snapshot",function(Snapshot)
	if not UiOpen or type(Snapshot) ~= "table" or Snapshot.Mode ~= UiMode then
		return
	end

	SendNUIMessage({ Action = "snapshot", Payload = Snapshot })
end)

RegisterNetEvent("af_ofc:forceClose",function()
	closeUi(false)
end)

RegisterNUICallback("close",function(_,Callback)
	closeUi(true)
	Callback({ Accepted = true })
end)

RegisterNUICallback("attemptBet",function(Data,Callback)
	if not UiOpen or UiMode ~= "public" or not SessionToken or type(Data) ~= "table" then
		Callback({ Accepted = false })
		return
	end

	local RequestId = tonumber(Data.RequestId) or nextRequestId()
	TriggerServerEvent("af_ofc:attemptBet",{
		RequestId = RequestId,
		SessionToken = SessionToken,
		Side = Data.Side,
		Amount = Data.Amount
	})
	Callback({ Accepted = true })
end)

local function organizerCallback(EventName,Data,Callback,Fields)
	if not UiOpen or UiMode ~= "organizer" or not SessionToken or type(Data) ~= "table" then
		Callback({ Accepted = false })
		return
	end

	local RequestId = tonumber(Data.RequestId) or nextRequestId()
	local Payload = {
		RequestId = RequestId,
		SessionToken = SessionToken
	}

	for _,Field in ipairs(Fields or {}) do
		Payload[Field] = Data[Field]
	end

	TriggerServerEvent(EventName,Payload)
	Callback({ Accepted = true })
end

RegisterNUICallback("createEvent",function(Data,Callback)
	organizerCallback("af_ofc:createEvent",Data,Callback,{ "Title","FighterA","FighterB" })
end)

RegisterNUICallback("announceEvent",function(Data,Callback)
	organizerCallback("af_ofc:announceEvent",Data,Callback)
end)

RegisterNUICallback("openBets",function(Data,Callback)
	organizerCallback("af_ofc:openBets",Data,Callback)
end)

RegisterNUICallback("closeBets",function(Data,Callback)
	organizerCallback("af_ofc:closeBets",Data,Callback)
end)

RegisterNUICallback("cancelEvent",function(Data,Callback)
	organizerCallback("af_ofc:cancelEvent",Data,Callback)
end)

RegisterNUICallback("startFight",function(Data,Callback)
	organizerCallback("af_ofc:startFight",Data,Callback)
end)

AddEventHandler("onResourceStop",function(Resource)
	if Resource == GetCurrentResourceName() then
		cleanup()
	end
end)

CreateThread(function()
	Wait(500)
	setup()

	while SetupComplete do
		local Ped = PlayerPedId()
		local NearNpc = LocalPlayer.state.Active and DoesEntityExist(Ped) and
			#(GetEntityCoords(Ped) - Config.PublicNpc.Coords.xyz) <= Config.PublicNpc.SpawnDistance

		if NearNpc and (not Npc or not DoesEntityExist(Npc)) then
			createNpc()
		end

		Wait(Config.PublicNpc.SpawnCheckInterval)
	end
end)
