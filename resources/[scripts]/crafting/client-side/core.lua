-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECTION
-----------------------------------------------------------------------------------------------------------------------------------------
vSERVER = Tunnel.getInterface("crafting")
-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Opened = false
local SaoJudasCraft = {
	CraftId = nil,
	Context = nil,
	State = "idle",
	StartedAtMs = 0,
	DurationMs = 0,
	AnimationMissingSince = nil,
	ServerCancelled = false
}

local function saoJudasCraftSettings(Context)
	if Context == "laboratory" then return SaoJudasOperations.Laboratory end
	if Context == "workbench" then return SaoJudasOperations.Workbench end
end

local function saoJudasCraftDebug(Action)
	if not SaoJudasOperations.Debug then return end

	local Now = GetGameTimer()
	local Elapsed = SaoJudasCraft.StartedAtMs > 0 and math.max(0,Now - SaoJudasCraft.StartedAtMs) or 0
	local Remaining = SaoJudasCraft.DurationMs > 0 and math.max(0,SaoJudasCraft.DurationMs - Elapsed) or 0
	local Settings = saoJudasCraftSettings(SaoJudasCraft.Context)
	local Animation = Settings and Settings.Animation
	local Playing = false

	if Animation and SaoJudasCraft.State ~= "idle" then
		Playing = IsEntityPlayingAnim(PlayerPedId(),Animation.Dictionary,Animation.Name,3)
	end

	print(("[saojudas/crafting-client] craftId=%s state=%s elapsed=%s remaining=%s progressFinished=%s isPlayingAnimation=%s action=%s"):format(
		tostring(SaoJudasCraft.CraftId),SaoJudasCraft.State,Elapsed,Remaining,
		tostring(SaoJudasCraft.State == "completing" or SaoJudasCraft.State == "completed"),tostring(Playing),Action
	))
end

local function setSaoJudasCraftState(State,Action)
	SaoJudasCraft.State = State
	saoJudasCraftDebug(Action or "state_changed")
end

local function resetSaoJudasCraft(State)
	if State ~= "completed" then
		TriggerEvent("Progress","",300)
	end

	local Ped = PlayerPedId()
	local Settings = saoJudasCraftSettings(SaoJudasCraft.Context)
	local Animation = Settings and Settings.Animation

	saoJudasCraftDebug("animation_cleanup")
	if Animation then
		StopAnimTask(Ped,Animation.Dictionary,Animation.Name,1.0)
		RemoveAnimDict(Animation.Dictionary)
	end
	FreezeEntityPosition(Ped,false)
	ClearPedTasks(Ped)

	setSaoJudasCraftState(State or "cancelled","session_cleanup")
	SaoJudasCraft.CraftId = nil
	SaoJudasCraft.Context = nil
	SaoJudasCraft.StartedAtMs = 0
	SaoJudasCraft.DurationMs = 0
	SaoJudasCraft.AnimationMissingSince = nil
	SaoJudasCraft.ServerCancelled = false
	SaoJudasCraft.State = "idle"
end

local function completeSaoJudasCraft()
	if SaoJudasCraft.State ~= "processing" then return end

	setSaoJudasCraftState("completing","progress_success_callback")
	saoJudasCraftDebug("complete_request_started")
	local Result = vSERVER.CompleteSaoJudas(SaoJudasCraft.CraftId)

	if Result == true then
		Result = { Success = true, Status = "completed" }
	elseif type(Result) ~= "table" then
		Result = { Success = false, Status = "missing_response", Reason = "missing_response" }
	end

	saoJudasCraftDebug("complete_request_result:"..tostring(Result.Status or Result.Reason))

	if Result.Success or Result.Status == "completed" then
		resetSaoJudasCraft("completed")
		return
	end

	local Status = vSERVER.GetSaoJudasCraftStatus(SaoJudasCraft.CraftId)
	local Attempts = 0
	while type(Status) == "table" and (Status.Status == "processing" or Status.Status == "completing") and Attempts < 8 do
		Attempts = Attempts + 1
		Wait(250)
		Status = vSERVER.GetSaoJudasCraftStatus(SaoJudasCraft.CraftId)
	end

	if type(Status) == "table" and Status.Status == "completed" then
		resetSaoJudasCraft("completed")
		return
	end

	resetSaoJudasCraft("cancelled")
end

local function cancelSaoJudasCraft(Reason)
	if SaoJudasCraft.State ~= "starting" and SaoJudasCraft.State ~= "processing" then return end

	setSaoJudasCraftState("cancelling","cancel_request_started:"..Reason)
	local Result = vSERVER.CancelSaoJudas(SaoJudasCraft.CraftId,Reason)

	if type(Result) == "table" and Result.Status == "ready_to_complete" then
		SaoJudasCraft.State = "processing"
		completeSaoJudasCraft()
		return
	end

	setSaoJudasCraftState("cancelled","cancel_request_result:"..tostring(type(Result) == "table" and Result.Status or Result))
	resetSaoJudasCraft("cancelled")
end

local function performSaoJudasCraft(Data)
	local Ped = PlayerPedId()
	local Settings = saoJudasCraftSettings(Data.Context)
	local Position = Settings and Settings.PlayerCoords
	local TargetCoords = Data.Context == "laboratory" and Settings and Settings.Coords or Settings and Settings.TargetCoords
	local Animation = Settings and Settings.Animation
	local Monitor = Settings and Settings.AnimationMonitor or {}
	local Duration = tonumber(Data.Duration) or 0

	TriggerEvent("inventory:Close")
	Wait(250)

	if not Settings or not Position or not TargetCoords or not Animation or Duration <= 0 or
		#(GetEntityCoords(Ped) - TargetCoords) > Settings.ServerDistance then
		cancelSaoJudasCraft("client_cancelled")
		return
	end

	SetEntityCoordsNoOffset(Ped,Position.x,Position.y,Position.z,false,false,false)
	SetEntityHeading(Ped,Position.w)
	FreezeEntityPosition(Ped,true)
	RequestAnimDict(Animation.Dictionary)

	local Timeout = GetGameTimer() + 5000
	while not HasAnimDictLoaded(Animation.Dictionary) and GetGameTimer() < Timeout do
		Wait(50)
	end

	if not HasAnimDictLoaded(Animation.Dictionary) then
		cancelSaoJudasCraft("client_cancelled")
		return
	end

	TriggerEvent("Progress",tostring(Data.Action or "Fabricando").." "..tostring(Data.Label or "item"),Duration)
	TaskPlayAnim(Ped,Animation.Dictionary,Animation.Name,4.0,-4.0,-1,tonumber(Animation.Flag) or 49,0.0,false,false,false)
	SaoJudasCraft.StartedAtMs = GetGameTimer()
	setSaoJudasCraftState("processing","animation_started")

	local FinishedAt = SaoJudasCraft.StartedAtMs + Duration
	local CancelReason = false
	local CheckInterval = tonumber(Monitor.CheckIntervalMs) or 150
	local StartupGrace = tonumber(Monitor.StartupGraceMs) or 750
	local MissingGrace = tonumber(Monitor.MissingGraceMs) or 750
	local CompletionIgnoreWindow = tonumber(Monitor.CompletionIgnoreWindowMs) or 1000

	while SaoJudasCraft.State == "processing" do
		Wait(CheckInterval)
		if SaoJudasCraft.State ~= "processing" then break end

		local Now = GetGameTimer()
		local Elapsed = Now - SaoJudasCraft.StartedAtMs
		local Remaining = math.max(0,FinishedAt - Now)

		if Now >= FinishedAt then
			break
		end

		if GetEntityHealth(Ped) <= 100 then
			CancelReason = "client_cancelled"
			break
		end

		if IsPedInAnyVehicle(Ped,false) or IsPedRagdoll(Ped) then
			CancelReason = "client_cancelled"
			break
		end

		if LocalPlayer.state.Safezone or LocalPlayer.state.Handcuff then
			CancelReason = "client_cancelled"
			break
		end

		if #(GetEntityCoords(Ped) - vector3(Position.x,Position.y,Position.z)) > 1.5 then
			CancelReason = "client_cancelled"
			break
		end

		if Monitor.Enabled ~= false and Elapsed > StartupGrace and Remaining > CompletionIgnoreWindow then
			if IsEntityPlayingAnim(Ped,Animation.Dictionary,Animation.Name,3) then
				SaoJudasCraft.AnimationMissingSince = nil
			elseif not SaoJudasCraft.AnimationMissingSince then
				SaoJudasCraft.AnimationMissingSince = Now
				saoJudasCraftDebug("animation_missing")
			elseif Now - SaoJudasCraft.AnimationMissingSince >= MissingGrace then
				CancelReason = "animation_interrupted"
				break
			end
		end
	end

	if SaoJudasCraft.State == "cancelled" or SaoJudasCraft.ServerCancelled then
		resetSaoJudasCraft("cancelled")
		return
	end

	if CancelReason then
		cancelSaoJudasCraft(CancelReason)
	else
		completeSaoJudasCraft()
	end
end

local function startSaoJudasCraft(Result)
	SaoJudasCraft.CraftId = Result.CraftId
	SaoJudasCraft.Context = Result.Context
	SaoJudasCraft.StartedAtMs = GetGameTimer()
	SaoJudasCraft.DurationMs = tonumber(Result.Duration) or 0
	SaoJudasCraft.AnimationMissingSince = nil
	SaoJudasCraft.ServerCancelled = false
	setSaoJudasCraftState("starting","craft_started")

	CreateThread(function()
		performSaoJudasCraft(Result)
	end)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- INVENTORY:CLOSE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("inventory:Close")
AddEventHandler("inventory:Close",function()
	Opened = false
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- OPENCRAFTING
-----------------------------------------------------------------------------------------------------------------------------------------
function OpenCrafting(Mode)
	Opened = Mode
	local Settings = List[Mode]

	TriggerEvent("inventory:Open",{
		Mode = "Buy",
		Type = "Shops",
		Right = Settings and Settings.Title or "Produção",
		Resource = "crafting"
	})
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- MOUNT
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("Mount",function(Data,Callback)
	local Primary,PrimaryWeight,PrimarySlots = vSERVER.Mount(Opened)
	if Primary then
		Callback({
			Primary = {
				Data = Primary,
				MaxWeight = PrimaryWeight,
				Slots = PrimarySlots or Theme.inventory.slots.default
			},
			Secondary = {
				Data = ItemList[Opened],
				Slots = math.max(CountTable(ItemList[Opened]),25)
			}
		})
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- TAKE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("Take",function(Data,Callback)
	if Opened == "SaoJudas" or Opened == "SaoJudasLaboratory" then
		if SaoJudasCraft.State ~= "idle" then
			Callback("Ok")
			return
		end

		local Result = vSERVER.StartSaoJudas(Data.Item,Data.Amount,Data.Target,Opened)
		Callback("Ok")

		if Result and Result.Success then
			startSaoJudasCraft(Result)
		end

		return
	end

	if MumbleIsConnected() then
		vSERVER.Take(Data.Item,Data.Amount,Data.Target,Opened)
	end

	Callback("Ok")
end)

RegisterNetEvent("crafting:OpenSaoJudas",function()
	if SaoJudasCraft.State == "idle" and not exports.hud:Wanted() then
		OpenCrafting("SaoJudas")
	end
end)

RegisterNetEvent("crafting:OpenSaoJudasLaboratory",function()
	if SaoJudasCraft.State == "idle" and not exports.hud:Wanted() then
		OpenCrafting("SaoJudasLaboratory")
	end
end)

RegisterNetEvent("crafting:SaoJudasCancelled",function(CraftId)
	if SaoJudasCraft.CraftId == CraftId and SaoJudasCraft.State ~= "idle" then
		SaoJudasCraft.ServerCancelled = true
		setSaoJudasCraftState("cancelled","server_cancelled")
	end
end)

RegisterNetEvent("crafting:CancelSaoJudas",function()
	if SaoJudasCraft.State == "processing" then
		CreateThread(function()
			cancelSaoJudasCraft("progress_cancelled")
		end)
	end
end)

AddEventHandler("onResourceStop",function(Resource)
	if Resource == GetCurrentResourceName() and SaoJudasCraft.State ~= "idle" then
		resetSaoJudasCraft("cancelled")
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- CRAFTING:OPEN
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("crafting:Open",function(Number)
	if exports.hud:Wanted() then
		return false
	end

	local Data = Location[Number]
	if Data then
		if vSERVER.Permission(Data.Mode) then
			OpenCrafting(Data.Mode)
		end
	else
		if vSERVER.Permission(Number) then
			OpenCrafting(Number)
		end
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADSERVERSTART
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	for Number,v in pairs(Location) do
		exports.target:AddCircleZone("Crafting:"..Number,v.Coords,v.Circle,{
			name = "Crafting:"..Number,
			heading = 0.0,
			useZ = true
		},{
			shop = Number,
			Distance = 2.0,
			options = {
				{
					event = "crafting:Open",
					label = "Abrir",
					tunnel = "client"
				}
			}
		})
	end
end)
