local Tunnel = module("vrp","lib/Tunnel")
local Taskbar = Tunnel.getInterface("taskbar")

local LockpickConfig = {
	Debug = false,
	AttemptTtlSeconds = 100,
	MaximumDistance = 6.0,
	Items = {
		lockpick = {
			InsideRounds = 10,
			OutsideRounds = 5,
			Speed = 5000,
			WearChance = 125
		},
		lockpickplus = {
			InsideRounds = 5,
			OutsideRounds = 5,
			Speed = 5000,
			WearChance = 0
		}
	}
}

local AttemptsByPassport = {}
local AttemptsById = {}
local AttemptRateLimit = {}

local function lockpickLog(Message)
	print("[lockpick] "..Message)
end

local function safeJson(Value)
	local Success,Encoded = pcall(json.encode,Value)
	return Success and Encoded or '"json_encode_failed"'
end

local function setAttemptStatus(Attempt,Status,Action)
	Attempt.Status = Status
	if LockpickConfig.Debug then
		lockpickLog(("attemptId=%s passport=%s vehicleNet=%s item=%s status=%s action=%s"):format(
			Attempt.AttemptId,Attempt.Passport,Attempt.VehicleNet,Attempt.Item,Status,tostring(Action or "state_changed")
		))
	end
end

local function attemptItemValid(Attempt)
	local Inventory = vRP.Inventory(Attempt.Passport)
	local Entry = Inventory and Inventory[tostring(Attempt.Slot)]
	return Entry and Entry.item == Attempt.FullItem and Entry.amount >= 1 and not vRP.CheckDamaged(Entry.item)
end

local function clearAttempt(Attempt,DestroyAnimation)
	if not Attempt or Attempt.Cleared then return end
	Attempt.Cleared = true

	if AttemptsByPassport[Attempt.Passport] == Attempt.AttemptId then
		AttemptsByPassport[Attempt.Passport] = nil
	end
	AttemptsById[Attempt.AttemptId] = nil
	Active[Attempt.Passport] = nil

	if GetPlayerName(Attempt.Source) then
		Player(Attempt.Source).state.Buttons = false
		if Attempt.Inside then vGARAGE.StopHotwired(Attempt.Source) end
		if DestroyAnimation ~= false then vRPC.Destroy(Attempt.Source) end
	end
end

local function applyCurrentWear(Attempt)
	if Attempt.WearApplied or Attempt.Inside then return end
	Attempt.WearApplied = true

	local Settings = LockpickConfig.Items[Attempt.Item]
	if Settings and Settings.WearChance > 0 and math.random(1000) >= (1000 - Settings.WearChance) then
		Attempt.Consumed = vRP.RemoveItem(Attempt.Passport,Attempt.FullItem,1,true,Attempt.Slot) == true
	end
end

local function vehicleLocked(Entity)
	local Status = GetVehicleDoorLockStatus(Entity)
	return Status and Status >= 2
end

local function validateAttemptContext(Attempt,RequireClientSelection)
	if not Attempt or Attempt.Cleared then return false,"attempt_missing" end
	if AttemptsByPassport[Attempt.Passport] ~= Attempt.AttemptId then return false,"attempt_replaced" end
	if AttemptsById[Attempt.AttemptId] ~= Attempt then return false,"attempt_missing" end
	if not GetPlayerName(Attempt.Source) or vRP.Passport(Attempt.Source) ~= Attempt.Passport then return false,"player_missing" end
	if os.time() > Attempt.ExpiresAt then return false,"attempt_expired" end
	if not attemptItemValid(Attempt) then return false,"item_missing" end

	local Entity = NetworkGetEntityFromNetworkId(Attempt.VehicleNet)
	if not Entity or Entity == 0 or not DoesEntityExist(Entity) then return false,"vehicle_missing" end
	if GetEntityRoutingBucket(Entity) ~= GetPlayerRoutingBucket(Attempt.Source) then return false,"routing_bucket_changed" end

	local Ped = GetPlayerPed(Attempt.Source)
	if not Ped or Ped == 0 or not DoesEntityExist(Ped) then return false,"ped_missing" end
	if #(GetEntityCoords(Ped) - GetEntityCoords(Entity)) > LockpickConfig.MaximumDistance then return false,"too_far" end
	if not vehicleLocked(Entity) then return false,"vehicle_already_unlocked" end

	if RequireClientSelection then
		local _,CurrentNetwork,CurrentPlate,CurrentModel = vRPC.VehicleList(Attempt.Source)
		if tonumber(CurrentNetwork) ~= Attempt.VehicleNet then return false,"vehicle_changed" end
		if tostring(CurrentPlate or "") ~= Attempt.Plate then return false,"plate_changed" end
		if tostring(CurrentModel or "") ~= Attempt.Model then return false,"model_changed" end
	end

	return true,nil,Entity
end

local function notifyPolice(Attempt)
	exports.vrp:CallPolice({
		Code = 31,
		Color = 44,
		Wanted = 300,
		Source = Attempt.Source,
		Percentage = 250,
		Name = Attempt.NotifyTitle,
		Passport = Attempt.Passport,
		Permission = "Policia",
		Vehicle = exports.vrp:VehicleName(Attempt.Model).." - "..Attempt.Plate
	})
end

local function unlockAttemptVehicle(Attempt,VehicleEntity)
	if Attempt.UnlockApplied or Attempt.Status ~= "unlocking" then return false,false end
	Attempt.UnlockApplied = true

	local StolenRecord = false
	local VehicleUnlocked = false
	if not vRP.PassportPlate(Attempt.Plate) then
		if not Dismantle[Attempt.Plate] then
			Entity(VehicleEntity).state:set("Nitro",0,true)
			Entity(VehicleEntity).state:set("Fuel",100,true)
		end

		Entity(VehicleEntity).state:set("Lockpick",Attempt.Passport,true)
		SetVehicleDoorsLocked(VehicleEntity,1)
		VehicleUnlocked = true
		StolenRecord = true
	elseif math.random(100) >= 75 then
		SetVehicleDoorsLocked(VehicleEntity,1)
		VehicleUnlocked = true
	end

	return VehicleUnlocked,StolenRecord
end

local function logTaskResult(Attempt,Result)
	local Required = type(Result) == "table" and tonumber(Result.RequiredRounds) or Attempt.RequiredRounds
	local Successes = type(Result) == "table" and tonumber(Result.SuccessfulRounds) or 0
	local Failures = type(Result) == "table" and tonumber(Result.FailedRounds) or 1
	local FinalStatus = type(Result) == "table" and tostring(Result.Status or "invalid") or "invalid"

	if LockpickConfig.Debug and type(Result) == "table" and type(Result.Rounds) == "table" then
		for _,Round in ipairs(Result.Rounds) do
			lockpickLog(("attemptId=%s passport=%s vehicleNet=%s item=%s round=%s requiredRounds=%s rawResult=%s resultType=%s successCount=%s failureCount=%s terminal=%s action=round_result"):format(
				Attempt.AttemptId,Attempt.Passport,Attempt.VehicleNet,Attempt.Item,tostring(Round.Round),tostring(Required),
				safeJson(Round.RawResult),tostring(Round.ResultType),tostring(Successes),tostring(Failures),tostring(Result.Terminal == true)
			))
		end
	end

	lockpickLog(("attemptId=%s passport=%s vehicleNet=%s item=%s requiredRounds=%s successfulRounds=%s failedRounds=%s rawResult=%s resultType=%s finalStatus=%s terminal=%s"):format(
		Attempt.AttemptId,Attempt.Passport,Attempt.VehicleNet,Attempt.Item,tostring(Required),tostring(Successes),tostring(Failures),
		safeJson(Result),type(Result),FinalStatus,tostring(type(Result) == "table" and Result.Terminal == true)
	))
end

local function finishFailedAttempt(Attempt,Status,Reason)
	if Attempt.MinigameTerminal then return false end
	Attempt.MinigameTerminal = true
	setAttemptStatus(Attempt,Status,Reason)
	applyCurrentWear(Attempt)
	lockpickLog(("attemptId=%s passport=%s vehicleNet=%s successfulRounds=%s failedRounds=%s finalStatus=%s reason=%s vehicleUnlocked=false stolenRecord=false"):format(
		Attempt.AttemptId,Attempt.Passport,Attempt.VehicleNet,Attempt.SuccessfulRounds or 0,Attempt.FailedRounds or 0,Status,Reason
	))
	clearAttempt(Attempt,true)
	return false
end

local function runLockpick(source,Passport,Slot,Full,Item)
	local PlayerState = Player(source).state
	if PlayerState.Handcuff then
		TriggerClientEvent("sounds:Private",source,"uncuff",0.5)
		vRP.RemoveItem(Passport,Full,1,true)
		PlayerState.Handcuff = false
		PlayerState.Commands = false
		vRPC.Destroy(source)
		return false
	end

	local Settings = LockpickConfig.Items[Item]
	if not Settings or AttemptsByPassport[Passport] then return false end
	if AttemptRateLimit[Passport] and AttemptRateLimit[Passport] > os.time() then return false end
	AttemptRateLimit[Passport] = os.time() + 2

	local Vehicle,Network,Plate,Model,Class = vRPC.VehicleList(source)
	if not Vehicle or not Network or Model == "stockade" or Class == 15 or Class == 16 or Class == 19 then return false end

	local Networked = NetworkGetEntityFromNetworkId(Network)
	if not Networked or Networked == 0 or not DoesEntityExist(Networked) or not vehicleLocked(Networked) then return false end
	if not attemptItemValid({ Passport = Passport, Slot = Slot, FullItem = Full }) then return false end

	local Inside = vRP.InsideVehicle(source) == true
	local RequiredRounds = Inside and Settings.InsideRounds or Settings.OutsideRounds
	local AttemptId = ("LP-%s-%s-%04d"):format(Passport,os.time(),math.random(0,9999))
	local Attempt = {
		AttemptId = AttemptId,
		Passport = Passport,
		Source = source,
		Vehicle = Vehicle,
		VehicleNet = tonumber(Network),
		Plate = tostring(Plate or ""),
		Model = tostring(Model or ""),
		Class = Class,
		Item = Item,
		FullItem = Full,
		Slot = tostring(Slot),
		Inside = Inside,
		RequiredRounds = RequiredRounds,
		StartedAt = os.time(),
		ExpiresAt = os.time() + LockpickConfig.AttemptTtlSeconds,
		Status = "starting",
		NotifyTitle = "Roubo de Veículo",
		Consumed = false,
		UnlockApplied = false,
		MinigameTerminal = false
	}

	AttemptsByPassport[Passport] = AttemptId
	AttemptsById[AttemptId] = Attempt
	vRPC.AnimActive(source)
	PlayerState.Buttons = true
	Active[Passport] = Attempt.ExpiresAt
	TriggerClientEvent("inventory:Close",source)
	if Inside then vGARAGE.StartHotwired(source) end
	setAttemptStatus(Attempt,"minigame","minigame_started")

	local Result = Taskbar.TaskDetailed(source,RequiredRounds,Settings.Speed,AttemptId)
	logTaskResult(Attempt,Result)
	Attempt.SuccessfulRounds = type(Result) == "table" and tonumber(Result.SuccessfulRounds) or 0
	Attempt.FailedRounds = type(Result) == "table" and tonumber(Result.FailedRounds) or 1

	local FullSuccess = type(Result) == "table"
		and Result.Success == true
		and Result.Status == "success"
		and Result.Terminal == true
		and Attempt.SuccessfulRounds == RequiredRounds
		and Attempt.FailedRounds == 0

	if not FullSuccess then
		local Status = type(Result) == "table" and Result.Status == "cancelled" and "cancelled" or "failed"
		return finishFailedAttempt(Attempt,Status,"minigame_not_fully_completed")
	end

	Attempt.MinigameTerminal = true
	setAttemptStatus(Attempt,"succeeded","full_minigame_success")
	local Valid,Reason,Entity = validateAttemptContext(Attempt,true)
	if not Valid then
		Attempt.MinigameTerminal = false
		return finishFailedAttempt(Attempt,"cancelled",Reason)
	end

	if Inside then
		setAttemptStatus(Attempt,"unlocking","inside_unlock")
		vGARAGE.RegisterDecors(source,Vehicle)
		TriggerClientEvent("player:Residual",source,"Resíduo de Alumínio")
		local VehicleUnlocked,StolenRecord = unlockAttemptVehicle(Attempt,Entity)
		notifyPolice(Attempt)
		setAttemptStatus(Attempt,"completed","inside_completed")
		lockpickLog(("attemptId=%s passport=%s vehicleNet=%s successfulRounds=%s failedRounds=0 finalStatus=success vehicleUnlocked=%s stolenRecord=%s"):format(
			AttemptId,Passport,Attempt.VehicleNet,Attempt.SuccessfulRounds,tostring(VehicleUnlocked),tostring(StolenRecord)
		))
		clearAttempt(Attempt,true)
		return true
	end

	setAttemptStatus(Attempt,"unlocking","unlock_progress_started")
	vRPC.playAnim(source,false,{ "missfbi_s4mop","clean_mop_back_player" },true)
	Active[Passport] = os.time() + 15
	vGARAGE.RegisterDecors(source,Vehicle)
	TriggerClientEvent("Progress",source,"Destravando",15000)
	TriggerClientEvent("player:Residual",source,"Resíduo de Alumínio")

	if Dismantle[Plate] then
		Attempt.NotifyTitle = "Desmanche"
		TriggerClientEvent("dismantle:Dispatch",source)
	elseif Boosting[Plate] then
		Attempt.NotifyTitle = "Boosting"
		TriggerClientEvent("boosting:Dispatch",source)
	end
	notifyPolice(Attempt)

	CreateThread(function()
		while Active[Passport] and os.time() < Active[Passport] do Wait(100) end

		local VehicleUnlocked = false
		local StolenRecord = false
		if Active[Passport] and AttemptsById[AttemptId] == Attempt and Attempt.Status == "unlocking" then
			local FinishValid,FinishReason,FinishEntity = validateAttemptContext(Attempt,true)
			if FinishValid then
				VehicleUnlocked,StolenRecord = unlockAttemptVehicle(Attempt,FinishEntity)
				setAttemptStatus(Attempt,"completed","unlock_completed")
			else
				setAttemptStatus(Attempt,"cancelled",FinishReason)
			end
		else
			setAttemptStatus(Attempt,"cancelled","progress_cancelled")
		end

		applyCurrentWear(Attempt)
		lockpickLog(("attemptId=%s passport=%s vehicleNet=%s successfulRounds=%s failedRounds=0 finalStatus=%s vehicleUnlocked=%s stolenRecord=%s"):format(
			AttemptId,Passport,Attempt.VehicleNet,Attempt.SuccessfulRounds,Attempt.Status,tostring(VehicleUnlocked),tostring(StolenRecord)
		))
		clearAttempt(Attempt,true)
	end)

	return true
end

Use.lockpick = function(source,Passport,Amount,Slot,Full,Item,Split)
	return runLockpick(source,Passport,Slot,Full,"lockpick")
end

Use.lockpickplus = function(source,Passport,Amount,Slot,Full,Item,Split)
	return runLockpick(source,Passport,Slot,Full,"lockpickplus")
end

AddEventHandler("playerDropped",function()
	local DroppedSource = source
	for _,Attempt in pairs(AttemptsById) do
		if Attempt.Source == DroppedSource then
			setAttemptStatus(Attempt,"cancelled","player_dropped")
			clearAttempt(Attempt,false)
			break
		end
	end
end)

AddEventHandler("onResourceStop",function(Resource)
	if Resource ~= GetCurrentResourceName() then return end
	local Pending = {}
	for _,Attempt in pairs(AttemptsById) do Pending[#Pending + 1] = Attempt end
	for _,Attempt in ipairs(Pending) do
		setAttemptStatus(Attempt,"cancelled","resource_stop")
		clearAttempt(Attempt,true)
	end
end)

RegisterCommand("lockpick_debug",function(source)
	local Passport = source > 0 and vRP.Passport(source) or 0
	if source > 0 and Passport ~= 1 then return end
	LockpickConfig.Debug = not LockpickConfig.Debug
	lockpickLog("debug="..tostring(LockpickConfig.Debug).." changedBy="..tostring(Passport))
end,false)
