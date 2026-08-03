-----------------------------------------------------------------------------------------------------------------------------------------
-- STATE
-----------------------------------------------------------------------------------------------------------------------------------------
local CurrentLobby = nil
local CurrentRace = nil
local PendingNpc = nil
local RouteBlip = nil
local OpponentBlip = nil
local OpponentBlipRaceId = nil
local OpponentBlipUpdatedAt = 0
local OpponentBlipTest = false
local CheckpointPending = false
local NpcCheckpointPending = false
local LastHudUpdate = 0
local LastNpcTask = 0
local NpcDriveMonitor = {
	NextCheck = 0,
	LastDistance = nil,
	StuckSince = 0,
	RecoveryAttempts = 0
}
local PendingTerms = nil
local NextTermsRequest = 0
local RouteAudit = nil
local RouteAuditBlips = {}
local CountdownLocks = {}
local NextCheckpointDetection = 0
local CheckpointDebugEnabled = false
-----------------------------------------------------------------------------------------------------------------------------------------
-- HELPERS
-----------------------------------------------------------------------------------------------------------------------------------------
local function Notify(Message,Color,Duration)
	TriggerEvent("Notify","Racha",Message,Color or "amarelo",Duration or 5000)
end

local function VehicleLabel(Vehicle)
	if Vehicle == 0 or not DoesEntityExist(Vehicle) then
		return "Veiculo"
	end

	local Display = GetDisplayNameFromVehicleModel(GetEntityModel(Vehicle))
	local Label = GetLabelText(Display)
	if not Label or Label == "NULL" then
		Label = Display
	end

	return Label or "Veiculo"
end

local function PointDistance(First,Second)
	if not First or not Second then
		return 0.0
	end

	local X = (First.x or First[1] or 0.0) - (Second.x or Second[1] or 0.0)
	local Y = (First.y or First[2] or 0.0) - (Second.y or Second[2] or 0.0)
	local Z = (First.z or First[3] or 0.0) - (Second.z or Second[3] or 0.0)
	return math.sqrt((X * X) + (Y * Y) + (Z * Z))
end

local function HorizontalDistance(First,Second)
	if not First or not Second then
		return math.huge
	end

	local X = (First.x or First[1] or 0.0) - (Second.x or Second[1] or 0.0)
	local Y = (First.y or First[2] or 0.0) - (Second.y or Second[2] or 0.0)
	return math.sqrt((X * X) + (Y * Y))
end

local function PointRadius(Point)
	if Point and Point.finish then
		return tonumber(Point.radius) or Config.FinishRadius
	end

	return tonumber(Point and Point.radius) or Config.CheckpointRadius
end

local function CheckpointPassed(Previous,Current,Point,Radius)
	local Validation = Config.CheckpointValidation or {}
	local MaximumVertical = math.max(0.0,tonumber(Validation.MaximumVerticalDifference) or 10.0)
	if not Previous then
		return HorizontalDistance(Current,Point) <= Radius and math.abs(Current.z - Point.z) <= MaximumVertical
	end

	local AX,AY = Previous.x,Previous.y
	local BX,BY = Current.x,Current.y
	local PX,PY = Point.x,Point.y
	local DX,DY = BX - AX,BY - AY
	local SegmentLength = (DX * DX) + (DY * DY)
	local T = 0.0
	if SegmentLength > 0.0001 then
		T = math.max(0.0,math.min(1.0,(((PX - AX) * DX) + ((PY - AY) * DY)) / SegmentLength))
	end

	local Closest = {
		x = AX + (DX * T),
		y = AY + (DY * T),
		z = Previous.z + ((Current.z - Previous.z) * T)
	}
	return HorizontalDistance(Closest,Point) <= Radius and math.abs(Closest.z - Point.z) <= MaximumVertical
end

local function BuildRouteMetrics(Start,Route)
	local Metrics = { Lengths = {}, Completed = {}, Total = 0.0, Start = Start }
	local Previous = Start
	for Index,Point in ipairs(Route or {}) do
		local Length = math.max(1.0,PointDistance(Previous,Point))
		Metrics.Lengths[Index] = Length
		Metrics.Completed[Index - 1] = Metrics.Total
		Metrics.Total = Metrics.Total + Length
		Previous = Point
	end
	Metrics.Completed[#(Route or {})] = Metrics.Total
	return Metrics
end

local function ContinuousProgress(Entity,Completed,Metrics,Route)
	local Total = #(Route or {})
	Completed = math.max(0,math.min(Total,math.floor(tonumber(Completed) or 0)))
	if Total <= 0 or not Metrics or Metrics.Total <= 0.0 then
		return 0.0
	end

	if Completed >= Total then
		return 100.0
	end

	local Base = Metrics.Completed[Completed] or 0.0
	local Segment = Metrics.Lengths[Completed + 1] or 1.0
	local Fraction = 0.0
	local NextPoint = Route[Completed + 1]
	if Entity and Entity ~= 0 and DoesEntityExist(Entity) and NextPoint then
		local Remaining = PointDistance(GetEntityCoords(Entity),NextPoint)
		Fraction = 1.0 - math.min(1.0,math.max(0.0,Remaining / Segment))
	end

	return math.min(100.0,math.max(0.0,((Base + (Segment * Fraction)) / Metrics.Total) * 100.0))
end

local function ResolvePendingTerms(Success,Message,Revision)
	local Pending = PendingTerms
	if not Pending then
		return
	end

	PendingTerms = nil
	Pending.Callback({
		success = Success == true,
		message = Message,
		revision = Revision
	})
end

local function RequestControl(Entity,Timeout)
	if Entity == 0 or not DoesEntityExist(Entity) then
		return false
	end

	if not NetworkGetEntityIsNetworked(Entity) or NetworkHasControlOfEntity(Entity) then
		return true
	end

	local Deadline = GetGameTimer() + (Timeout or Config.NpcRace.ControlTimeout)
	repeat
		NetworkRequestControlOfEntity(Entity)
		Wait(25)
	until NetworkHasControlOfEntity(Entity) or not DoesEntityExist(Entity) or GetGameTimer() >= Deadline

	return DoesEntityExist(Entity) and NetworkHasControlOfEntity(Entity)
end

local function EnsureNetworked(Entity)
	if Entity == 0 or not DoesEntityExist(Entity) then
		return 0
	end

	if not NetworkGetEntityIsNetworked(Entity) then
		NetworkRegisterEntityAsNetworked(Entity)
		local Deadline = GetGameTimer() + Config.NpcRace.ControlTimeout
		while DoesEntityExist(Entity) and not NetworkGetEntityIsNetworked(Entity) and GetGameTimer() < Deadline do
			Wait(25)
		end
	end

	if not NetworkGetEntityIsNetworked(Entity) then
		return 0
	end

	local Network = NetworkGetNetworkIdFromEntity(Entity)
	if Network > 0 then
		SetNetworkIdCanMigrate(Network,true)
	end

	return Network
end

local function ReleasePendingNpc()
	if not PendingNpc then
		return
	end

	if PendingNpc.Ped ~= 0 and DoesEntityExist(PendingNpc.Ped) then
		SetBlockingOfNonTemporaryEvents(PendingNpc.Ped,false)
		if PendingNpc.MadePedMission then
			SetEntityAsNoLongerNeeded(PendingNpc.Ped)
		end
	end

	if PendingNpc.Vehicle ~= 0 and DoesEntityExist(PendingNpc.Vehicle) and PendingNpc.MadeVehicleMission then
		SetEntityAsNoLongerNeeded(PendingNpc.Vehicle)
	end

	PendingNpc = nil
end

local function RemoveRouteBlip()
	if RouteBlip and DoesBlipExist(RouteBlip) then
		RemoveBlip(RouteBlip)
	end

	RouteBlip = nil
end

local function RemoveOpponentBlip()
	if OpponentBlip and DoesBlipExist(OpponentBlip) then
		RemoveBlip(OpponentBlip)
	end

	OpponentBlip = nil
	OpponentBlipRaceId = nil
	OpponentBlipUpdatedAt = 0
	OpponentBlipTest = false
end

local function UpdateOpponentBlip(Data,IsTest)
	if not Config.OpponentBlip or Config.OpponentBlip.Enabled == false or type(Data) ~= "table" then
		return
	end

	local X = tonumber(Data.x)
	local Y = tonumber(Data.y)
	local Z = tonumber(Data.z)
	if not X or not Y or not Z then
		return
	end

	if not OpponentBlip or not DoesBlipExist(OpponentBlip) then
		OpponentBlip = AddBlipForCoord(X,Y,Z)
		SetBlipSprite(OpponentBlip,tonumber(Config.OpponentBlip.Sprite) or 225)
		SetBlipColour(OpponentBlip,tonumber(Config.OpponentBlip.Color) or 5)
		SetBlipScale(OpponentBlip,tonumber(Config.OpponentBlip.Scale) or 0.85)
		SetBlipAsShortRange(OpponentBlip,Config.OpponentBlip.ShortRange == true)
		if Config.OpponentBlip.ShowHeading ~= false then
			ShowHeadingIndicatorOnBlip(OpponentBlip,true)
		end
		BeginTextCommandSetBlipName("STRING")
		AddTextComponentString(Config.OpponentBlip.Name or "Adversario do racha")
		EndTextCommandSetBlipName(OpponentBlip)
	else
		SetBlipCoords(OpponentBlip,X,Y,Z)
	end

	if Config.OpponentBlip.ShowHeading ~= false then
		SetBlipRotation(OpponentBlip,math.floor((tonumber(Data.heading) or 0.0) + 0.5))
	end
	OpponentBlipRaceId = tonumber(Data.raceId)
	OpponentBlipUpdatedAt = GetGameTimer()
	OpponentBlipTest = IsTest == true
end

local function ClearRouteAudit()
	for _,Blip in ipairs(RouteAuditBlips) do
		if DoesBlipExist(Blip) then
			RemoveBlip(Blip)
		end
	end
	RouteAuditBlips = {}
	RouteAudit = nil
end

local function SetRouteAuditPoint(Index)
	if not RouteAudit or not RouteAudit.Route then
		return
	end

	RouteAudit.Index = math.max(1,math.min(#RouteAudit.Route,tonumber(Index) or 1))
	for BlipIndex,Blip in ipairs(RouteAuditBlips) do
		if DoesBlipExist(Blip) then
			SetBlipRoute(Blip,BlipIndex == RouteAudit.Index)
			if BlipIndex == RouteAudit.Index then
				SetBlipRouteColour(Blip,1)
			end
		end
	end
end

local function SetRoutePoint(Index)
	RemoveRouteBlip()
	if not CurrentRace or not CurrentRace.Route then
		return
	end

	local Point = CurrentRace.Route[Index]
	if not Point then
		return
	end

	RouteBlip = AddBlipForCoord(Point.x,Point.y,Point.z)
	SetBlipSprite(RouteBlip,Point.finish and 38 or 1)
	SetBlipColour(RouteBlip,1)
	SetBlipScale(RouteBlip,Point.finish and 0.9 or 0.75)
	SetBlipAsShortRange(RouteBlip,false)
	SetBlipRoute(RouteBlip,true)
	SetBlipRouteColour(RouteBlip,1)
	BeginTextCommandSetBlipName("STRING")
	AddTextComponentString(Point.finish and "Chegada do racha" or ("Checkpoint "..Index))
	EndTextCommandSetBlipName(RouteBlip)
end

local function SetVehicleHeld(Vehicle,Held)
	if Vehicle == 0 or not DoesEntityExist(Vehicle) then
		return
	end

	RequestControl(Vehicle,800)
	if Held then
		CountdownLocks[Vehicle] = CountdownLocks[Vehicle] or {
			Coords = GetEntityCoords(Vehicle),
			Heading = GetEntityHeading(Vehicle),
			LastNpcRpm = 0
		}
		FreezeEntityPosition(Vehicle,false)
		SetVehicleHandbrake(Vehicle,true)
		SetVehicleBrake(Vehicle,true)
		SetVehicleBurnout(Vehicle,false)
		SetVehicleEngineOn(Vehicle,true,true,false)
	else
		CountdownLocks[Vehicle] = nil
		FreezeEntityPosition(Vehicle,false)
		SetVehicleHandbrake(Vehicle,false)
		SetVehicleBrake(Vehicle,false)
		SetVehicleBurnout(Vehicle,false)
		SetVehicleCurrentRpm(Vehicle,0.0)
	end
end

local function MaintainCountdownLock(Vehicle,IsNpc)
	local Lock = CountdownLocks[Vehicle]
	if not Lock or Vehicle == 0 or not DoesEntityExist(Vehicle) then
		return
	end

	RequestControl(Vehicle,100)
	SetVehicleEngineOn(Vehicle,true,true,false)

	local Settings = Config.CountdownLock or {}
	local Throttle = 0.0
	local LocalDriver = not IsNpc and GetPedInVehicleSeat(Vehicle,-1) == PlayerPedId()
	if LocalDriver then
		Throttle = math.max(0.0,GetControlNormal(0,71),GetDisabledControlNormal(0,71))
	end
	local BurnoutActive = LocalDriver and Throttle > 0.15
	SetVehicleBurnout(Vehicle,BurnoutActive)
	SetVehicleHandbrake(Vehicle,not BurnoutActive)
	SetVehicleBrake(Vehicle,not BurnoutActive)

	local MaximumSpeed = math.max(0.05,tonumber(Settings.MaximumSpeed) or 0.35)
	if GetEntitySpeed(Vehicle) > MaximumSpeed then
		SetEntityVelocity(Vehicle,0.0,0.0,0.0)
	end

	local CurrentCoords = GetEntityCoords(Vehicle)
	local PositionDrift = #(CurrentCoords - Lock.Coords)
	local HeadingDrift = math.abs(((GetEntityHeading(Vehicle) - Lock.Heading + 180.0) % 360.0) - 180.0)
	if PositionDrift > math.max(0.1,tonumber(Settings.MaximumPositionDrift) or 0.65) then
		SetEntityCoordsNoOffset(Vehicle,Lock.Coords.x,Lock.Coords.y,Lock.Coords.z,false,false,false)
	end
	if HeadingDrift > 3.0 then
		SetEntityHeading(Vehicle,Lock.Heading)
	end

	if Settings.ArtificialRpmFallback ~= false then
		if IsNpc then
			if GetGameTimer() >= Lock.LastNpcRpm then
				local Minimum = tonumber(Settings.NpcRpmMinimum) or 0.45
				local Maximum = tonumber(Settings.NpcRpmMaximum) or 0.78
				SetVehicleCurrentRpm(Vehicle,Minimum + (math.random() * math.max(0.0,Maximum - Minimum)))
				Lock.LastNpcRpm = GetGameTimer() + math.max(100,tonumber(Settings.NpcRpmInterval) or 350)
			end
		else
			SetVehicleCurrentRpm(Vehicle,math.min(0.95,0.18 + (Throttle * 0.75)))
		end
	end
end

local function ReleaseCountdownLocks()
	for Vehicle in pairs(CountdownLocks) do
		SetVehicleHeld(Vehicle,false)
	end
	CountdownLocks = {}
end

local function CloseLobby()
	ResolvePendingTerms(false,"A atualizacao foi cancelada porque a sala foi fechada.")
	CurrentLobby = nil
	SetNuiFocus(false,false)
	SendNUIMessage({ action = "closeLobby" })
end

local function RaceVehicle()
	if not CurrentRace then
		return 0
	end

	local Vehicle = NetToVeh(CurrentRace.VehicleNet or 0)
	if Vehicle == 0 or not DoesEntityExist(Vehicle) then
		local Ped = PlayerPedId()
		Vehicle = GetVehiclePedIsIn(Ped,false)
	end

	return Vehicle
end

local function NpcEntities()
	if not CurrentRace or CurrentRace.Mode ~= "npc" then
		return 0,0
	end

	return NetToPed(CurrentRace.NpcPedNet or 0),NetToVeh(CurrentRace.NpcVehicleNet or 0)
end

local function NpcDifficulty()
	local Difficulties = Config.NpcRace.Difficulties or {}
	return Difficulties[Config.NpcRace.Difficulty] or Difficulties.Normal or {
		Speed = 39.0,
		Ability = 0.90,
		Aggressiveness = 0.85
	}
end

local function ResetNpcDriveMonitor(Distance)
	NpcDriveMonitor.NextCheck = GetGameTimer() + (tonumber(Config.NpcRace.StuckCheckInterval) or 3000)
	NpcDriveMonitor.LastDistance = Distance
	NpcDriveMonitor.StuckSince = 0
	NpcDriveMonitor.RecoveryAttempts = 0
end

local function DriveNpcToCheckpoint(RecoveryAttempt,ClearDrivingTask)
	if not CurrentRace or CurrentRace.Mode ~= "npc" or CurrentRace.Status ~= "racing" then
		return false
	end

	local Ped,Vehicle = NpcEntities()
	local Point = CurrentRace.Route[CurrentRace.NpcCheckpoint]
	if Ped == 0 or Vehicle == 0 or not DoesEntityExist(Ped) or not DoesEntityExist(Vehicle) or not Point then
		return false
	end

	if not RequestControl(Ped,Config.NpcRace.ControlTimeout) or not RequestControl(Vehicle,Config.NpcRace.ControlTimeout) then
		return false
	end

	if GetPedInVehicleSeat(Vehicle,-1) ~= Ped then
		return false
	end

	local Difficulty = NpcDifficulty()
	local Attempt = math.max(0,math.floor(tonumber(RecoveryAttempt) or 0))
	local Speed = math.max(1.0,tonumber(Difficulty.Speed) or 39.0)
	if Attempt > 0 then
		Speed = Speed + (math.min(Attempt,2) * (tonumber(Config.NpcRace.RecoverySpeedBonus) or 3.0))
	end

	if ClearDrivingTask then
		ClearPedTasks(Ped)
	end

	SetDriverAbility(Ped,math.max(0.0,math.min(1.0,tonumber(Difficulty.Ability) or 0.90)))
	SetDriverAggressiveness(Ped,math.max(0.0,math.min(1.0,tonumber(Difficulty.Aggressiveness) or 0.85)))
	SetBlockingOfNonTemporaryEvents(Ped,true)
	SetVehicleEngineOn(Vehicle,true,true,false)
	SetDriveTaskDrivingStyle(Ped,Config.NpcRace.DrivingStyle)
	TaskVehicleDriveToCoordLongrange(Ped,Vehicle,Point.x,Point.y,Point.z,Speed,Config.NpcRace.DrivingStyle,Config.NpcRace.StopRange or 8.0)
	SetDriveTaskDrivingStyle(Ped,Config.NpcRace.DrivingStyle)
	LastNpcTask = GetGameTimer()
	return true
end

local function MonitorNpcDriver(Ped,Vehicle,Point,Distance)
	local Now = GetGameTimer()
	if Now < NpcDriveMonitor.NextCheck then
		return
	end

	NpcDriveMonitor.NextCheck = Now + (tonumber(Config.NpcRace.StuckCheckInterval) or 3000)
	local PreviousDistance = NpcDriveMonitor.LastDistance
	local Improvement = PreviousDistance and (PreviousDistance - Distance) or math.huge
	local MinimumImprovement = tonumber(Config.NpcRace.MinimumDistanceImprovement) or 3.0
	local Speed = GetEntitySpeed(Vehicle)
	local IsMoving = Speed >= (tonumber(Config.NpcRace.StuckMinimumSpeed) or 1.5)
	local IsProgressing = Improvement >= MinimumImprovement

	if IsMoving or IsProgressing then
		NpcDriveMonitor.StuckSince = 0
		if IsProgressing then
			NpcDriveMonitor.RecoveryAttempts = 0
		end
	else
		if NpcDriveMonitor.StuckSince <= 0 then
			NpcDriveMonitor.StuckSince = Now
		elseif Now - NpcDriveMonitor.StuckSince >= (tonumber(Config.NpcRace.StuckTimeout) or 7000) then
			NpcDriveMonitor.RecoveryAttempts = NpcDriveMonitor.RecoveryAttempts + 1
			local Attempt = NpcDriveMonitor.RecoveryAttempts
			TriggerServerEvent("af_illegal_races:NpcRecovery",CurrentRace.Id,CurrentRace.Token)

			if Attempt < (tonumber(Config.NpcRace.MaximumRecoveryAttempts) or 3) then
				DriveNpcToCheckpoint(Attempt,Attempt >= 2)
			end

			NpcDriveMonitor.StuckSince = Now
		end
	end

	NpcDriveMonitor.LastDistance = Distance
	if Now - LastNpcTask >= (tonumber(Config.NpcRace.TaskRefreshInterval) or 12000) then
		DriveNpcToCheckpoint(0,false)
	end
end

local function CleanupRace(KeepHud)
	ReleaseCountdownLocks()

	if CurrentRace and CurrentRace.Mode == "npc" then
		local Ped,NpcVehicle = NpcEntities()

		if Ped ~= 0 and DoesEntityExist(Ped) then
			RequestControl(Ped,500)
			SetBlockingOfNonTemporaryEvents(Ped,false)
			SetDriverAbility(Ped,0.5)
			SetDriverAggressiveness(Ped,0.2)
			if NpcVehicle ~= 0 and DoesEntityExist(NpcVehicle) then
				ClearPedTasks(Ped)
				SetDriveTaskDrivingStyle(Ped,Config.NpcRace.CleanupDrivingStyle or 786603)
				TaskVehicleDriveWander(Ped,NpcVehicle,16.0,Config.NpcRace.CleanupDrivingStyle or 786603)
			end
			SetEntityAsNoLongerNeeded(Ped)
		end

		if NpcVehicle ~= 0 and DoesEntityExist(NpcVehicle) then
			SetEntityAsNoLongerNeeded(NpcVehicle)
		end
	end

	RemoveRouteBlip()
	RemoveOpponentBlip()
	CheckpointPending = false
	NpcCheckpointPending = false
	NextCheckpointDetection = 0
	LastNpcTask = 0
	ResetNpcDriveMonitor()
	LocalPlayer.state:set("Races",false,false)
	CurrentRace = nil
	ReleasePendingNpc()
	SetNuiFocus(false,false)
	if not KeepHud then
		SendNUIMessage({ action = "hideRace" })
	end
end

local function ValidLocalDriver()
	local Ped = PlayerPedId()
	if not LocalPlayer.state.Active then
		return false,"Seu personagem ainda nao esta carregado."
	end

	if LocalPlayer.state.Safezone then
		return false,"Nao e permitido iniciar racha em safe zone."
	end

	if LocalPlayer.state.Races or LocalPlayer.state.StreetRace then
		return false,"Voce ja esta participando de uma corrida."
	end

	if IsPedDeadOrDying(Ped,true) or GetEntityHealth(Ped) <= 100 then
		return false,"Voce nao pode correr inconsciente."
	end

	local Vehicle = GetVehiclePedIsIn(Ped,false)
	if Vehicle == 0 or GetPedInVehicleSeat(Vehicle,-1) ~= Ped then
		return false,"Entre no banco do motorista para desafiar."
	end

	local Class = GetVehicleClass(Vehicle)
	if Config.BlockedVehicleClasses[Class] or Config.BlockedVehicleModels[GetEntityModel(Vehicle)] then
		return false,"Este tipo de veiculo nao pode participar."
	end

	if GetEntitySpeed(Vehicle) > Config.VehicleMaximumSpeedToChallenge then
		return false,"Reduza a velocidade antes de desafiar."
	end

	return true,Vehicle
end

local function ClosestPlayerDriver(OwnVehicle)
	local OwnCoords = GetEntityCoords(OwnVehicle)
	local BestPlayer = nil
	local BestVehicle = 0
	local BestDistance = Config.ChallengeDistance

	for _,Player in ipairs(GetActivePlayers()) do
		if Player ~= PlayerId() then
			local Ped = GetPlayerPed(Player)
			if DoesEntityExist(Ped) and not IsPedDeadOrDying(Ped,true) then
				local Vehicle = GetVehiclePedIsIn(Ped,false)
				if Vehicle ~= 0 and Vehicle ~= OwnVehicle and GetPedInVehicleSeat(Vehicle,-1) == Ped then
					local Distance = #(OwnCoords - GetEntityCoords(Vehicle))
					if Distance <= BestDistance then
						BestDistance = Distance
						BestPlayer = Player
						BestVehicle = Vehicle
					end
				end
			end
		end
	end

	return BestPlayer,BestVehicle
end

local function ClosestNpcDriver(OwnVehicle)
	local OwnCoords = GetEntityCoords(OwnVehicle)
	local BestPed = 0
	local BestVehicle = 0
	local BestDistance = Config.ChallengeDistance

	for _,Ped in ipairs(GetGamePool("CPed")) do
		if Ped ~= PlayerPedId() and DoesEntityExist(Ped) and not IsPedAPlayer(Ped) and not IsEntityAMissionEntity(Ped) and IsPedHuman(Ped) and not IsPedDeadOrDying(Ped,true) then
			local Vehicle = GetVehiclePedIsIn(Ped,false)
			if Vehicle ~= 0 and Vehicle ~= OwnVehicle and not IsEntityAMissionEntity(Vehicle) and GetPedInVehicleSeat(Vehicle,-1) == Ped then
				local Class = GetVehicleClass(Vehicle)
				local Distance = #(OwnCoords - GetEntityCoords(Vehicle))
				if Distance <= BestDistance and not Config.BlockedVehicleClasses[Class] and not Config.BlockedVehicleModels[GetEntityModel(Vehicle)] then
					BestDistance = Distance
					BestPed = Ped
					BestVehicle = Vehicle
				end
			end
		end
	end

	return BestPed,BestVehicle
end

local function PrepareNpcChallenge(Ped,Vehicle)
	if not RequestControl(Ped) or not RequestControl(Vehicle) then
		return nil
	end

	local MadePedMission = not IsEntityAMissionEntity(Ped)
	local MadeVehicleMission = not IsEntityAMissionEntity(Vehicle)
	SetEntityAsMissionEntity(Ped,true,false)
	SetEntityAsMissionEntity(Vehicle,true,false)
	SetBlockingOfNonTemporaryEvents(Ped,true)

	local PedNet = EnsureNetworked(Ped)
	local VehicleNet = EnsureNetworked(Vehicle)
	if PedNet <= 0 or VehicleNet <= 0 then
		SetBlockingOfNonTemporaryEvents(Ped,false)
		if MadePedMission then
			SetEntityAsNoLongerNeeded(Ped)
		end
		if MadeVehicleMission then
			SetEntityAsNoLongerNeeded(Vehicle)
		end
		return nil
	end

	PendingNpc = {
		Ped = Ped,
		Vehicle = Vehicle,
		PedNet = PedNet,
		VehicleNet = VehicleNet,
		MadePedMission = MadePedMission,
		MadeVehicleMission = MadeVehicleMission
	}

	SetTimeout(15000,function()
		if PendingNpc and (not CurrentRace or CurrentRace.NpcPedNet ~= PendingNpc.PedNet) and (not CurrentLobby or CurrentLobby.mode ~= "npc") then
			ReleasePendingNpc()
		end
	end)

	return PendingNpc
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- COMMAND
-----------------------------------------------------------------------------------------------------------------------------------------
local function AttemptRace()
	if RouteAudit then
		Notify("Encerre a auditoria com /racha_cancelarrotateste antes de iniciar um racha.","amarelo")
		return
	end

	if CurrentLobby or CurrentRace then
		Notify("Voce ja possui um racha em andamento.","amarelo")
		return
	end

	local Valid,VehicleOrReason = ValidLocalDriver()
	if not Valid then
		Notify(VehicleOrReason,"amarelo")
		return
	end

	local Vehicle = VehicleOrReason
	local Player,TargetVehicle = ClosestPlayerDriver(Vehicle)
	if Player then
		TriggerServerEvent("af_illegal_races:ChallengePlayer",
			GetPlayerServerId(Player),
			NetworkGetNetworkIdFromEntity(Vehicle),
			NetworkGetNetworkIdFromEntity(TargetVehicle),
			VehicleLabel(Vehicle),
			VehicleLabel(TargetVehicle)
		)
		return
	end

	if Config.NpcRace.Enabled then
		local NpcPed,NpcVehicle = ClosestNpcDriver(Vehicle)
		if NpcPed ~= 0 then
			local Prepared = PrepareNpcChallenge(NpcPed,NpcVehicle)
			if not Prepared then
				Notify("Nao foi possivel assumir o controle do piloto NPC.","vermelho")
				return
			end

			TriggerServerEvent("af_illegal_races:ChallengeNpc",
				Prepared.PedNet,
				Prepared.VehicleNet,
				NetworkGetNetworkIdFromEntity(Vehicle),
				VehicleLabel(Vehicle),
				VehicleLabel(NpcVehicle)
			)
			return
		end
	end

	Notify("Nao ha outro motorista valido proximo.","amarelo")
end

RegisterNetEvent("af_illegal_races:AttemptCommand",function()
	AttemptRace()
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- NUI
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("UpdateTerms",function(Data,Callback)
	if not CurrentLobby or (CurrentLobby.mode ~= "player" and CurrentLobby.mode ~= "test") then
		Callback({ success = false, message = "Sala de racha indisponivel." })
		return
	end
	if PendingTerms then
		Callback({ success = false, message = "Aguarde a atualizacao atual dos termos." })
		return
	end

	NextTermsRequest = NextTermsRequest + 1
	local RequestId = NextTermsRequest
	PendingTerms = {
		RequestId = RequestId,
		RaceId = CurrentLobby.id,
		Callback = Callback
	}
	TriggerServerEvent("af_illegal_races:UpdateTerms",CurrentLobby.id,Data.stake,Data.distance,RequestId)
	SetTimeout(8000,function()
		if PendingTerms and PendingTerms.RequestId == RequestId then
			ResolvePendingTerms(false,"O servidor demorou para confirmar os novos termos.")
		end
	end)
end)

RegisterNUICallback("ConfirmLobby",function(Data,Callback)
	if not CurrentLobby or (CurrentLobby.mode ~= "player" and CurrentLobby.mode ~= "test") then
		Callback({ success = false, message = "Sala de racha indisponivel." })
		return
	end

	TriggerServerEvent("af_illegal_races:ConfirmLobby",CurrentLobby.id,CurrentLobby.revision)
	Callback({ success = true })
end)

RegisterNUICallback("ConfirmNpc",function(Data,Callback)
	if not CurrentLobby or CurrentLobby.mode ~= "npc" then
		Callback({ success = false, message = "Desafio contra NPC indisponivel." })
		return
	end

	TriggerServerEvent("af_illegal_races:ConfirmNpc",CurrentLobby.id)
	SetNuiFocus(false,false)
	SendNUIMessage({ action = "waiting" })
	Callback({ success = true })
end)

RegisterNUICallback("Cancel",function(Data,Callback)
	if CurrentLobby then
		TriggerServerEvent("af_illegal_races:Cancel",CurrentLobby.id)
	end

	CloseLobby()
	ReleasePendingNpc()
	Callback({ success = true })
end)

RegisterNUICallback("Close",function(Data,Callback)
	if CurrentLobby then
		TriggerServerEvent("af_illegal_races:Cancel",CurrentLobby.id)
	end

	CloseLobby()
	ReleasePendingNpc()
	Callback({ success = true })
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- SERVER EVENTS
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("af_illegal_races:OpenLobby",function(Data)
	CurrentLobby = {
		id = Data.id,
		mode = Data.mode or "player",
		revision = Data.revision
	}
	SetNuiFocus(true,true)
	SendNUIMessage({ action = "openLobby", payload = Data })
end)

RegisterNetEvent("af_illegal_races:LobbyUpdate",function(Data)
	if not CurrentLobby or CurrentLobby.id ~= Data.id then
		return
	end

	CurrentLobby.revision = Data.revision
	SendNUIMessage({ action = "updateLobby", payload = Data })
end)

RegisterNetEvent("af_illegal_races:TermsAck",function(Data)
	if not PendingTerms or not Data or PendingTerms.RequestId ~= tonumber(Data.requestId) then
		return
	end

	if CurrentLobby and Data.revision then
		CurrentLobby.revision = tonumber(Data.revision) or CurrentLobby.revision
	end
	ResolvePendingTerms(Data.success == true,Data.message,Data.revision)
end)

RegisterNetEvent("af_illegal_races:OpenNpcOffer",function(Data)
	CurrentLobby = { id = Data.id, mode = "npc", revision = 1 }
	SetNuiFocus(true,true)
	SendNUIMessage({ action = "openNpc", payload = Data })
end)

RegisterNetEvent("af_illegal_races:ResolveLaunchAnchor",function(Data)
	if type(Data) ~= "table" or type(Data.start) ~= "table" or type(Data.forward) ~= "table" then
		return
	end

	local StartX = tonumber(Data.start.x)
	local StartY = tonumber(Data.start.y)
	local StartZ = tonumber(Data.start.z)
	local ForwardX = tonumber(Data.forward.x)
	local ForwardY = tonumber(Data.forward.y)
	local Distance = tonumber(Data.distance) or 120.0
	if not StartX or not StartY or not StartZ or not ForwardX or not ForwardY then
		return
	end

	local TargetX = StartX + (ForwardX * Distance)
	local TargetY = StartY + (ForwardY * Distance)
	local Found,NodeCoords,NodeHeading = GetClosestVehicleNodeWithHeading(TargetX,TargetY,StartZ,1,3.0,0)
	if not Found then
		Found,NodeCoords = GetClosestVehicleNode(TargetX,TargetY,StartZ,1,3.0,0)
	end

	local Payload = { found = Found == true }
	if Found and NodeCoords then
		Payload.x = NodeCoords.x
		Payload.y = NodeCoords.y
		Payload.z = NodeCoords.z
		Payload.heading = tonumber(NodeHeading) or 0.0
	end
	TriggerServerEvent("af_illegal_races:LaunchAnchorResolved",Data.raceId,Data.token,Payload)
end)

RegisterNetEvent("af_illegal_races:Prepare",function(Data)
	CloseLobby()
	RemoveOpponentBlip()
	CurrentRace = {
		Id = Data.id,
		Mode = Data.mode,
		Token = Data.token,
		Route = Data.route or {},
		Checkpoint = 1,
		NpcCheckpoint = 1,
		Status = "preparing",
		VehicleNet = Data.vehicleNet,
		OpponentSource = Data.opponentSource,
		OpponentVehicleNet = Data.opponentVehicleNet,
		NpcPedNet = Data.npcPedNet,
		NpcVehicleNet = Data.npcVehicleNet,
		OpponentName = Data.opponentName,
		Prize = Data.prize,
		StartedAt = 0,
		Progress = { current = 0, opponent = 0, total = #(Data.route or {}) },
		Metrics = BuildRouteMetrics(Data.start,Data.route or {}),
		OpponentMetrics = BuildRouteMetrics(Data.opponentStart or Data.start,Data.route or {})
	}
	local Vehicle = RaceVehicle()
	if Vehicle ~= 0 and DoesEntityExist(Vehicle) then
		CurrentRace.PreviousVehicleCoords = GetEntityCoords(Vehicle)
	end

	if PendingNpc and Data.mode == "npc" and PendingNpc.PedNet == Data.npcPedNet then
		PendingNpc = nil
	end

	LocalPlayer.state:set("Races",true,false)
	SetVehicleHeld(RaceVehicle(),true)
	if Data.mode == "npc" then
		local Ped,NpcVehicle = NpcEntities()
		if Ped ~= 0 and DoesEntityExist(Ped) then
			SetBlockingOfNonTemporaryEvents(Ped,true)
		end
		SetVehicleHeld(NpcVehicle,true)
	end

	SetRoutePoint(1)
	SendNUIMessage({
		action = "prepareRace",
		payload = {
			mode = Data.mode,
			opponent = Data.opponentName,
			destination = Data.destination,
			prize = Data.prize,
			total = #(Data.route or {})
		}
	})
end)

RegisterNetEvent("af_illegal_races:Countdown",function(RaceId,Seconds,Sync)
	if not CurrentRace or CurrentRace.Id ~= RaceId then
		return
	end

	CurrentRace.Status = "countdown"
	local DurationMs = math.max(750,math.floor(tonumber(Sync and Sync.remainingMs) or tonumber(Sync and Sync.durationMs) or ((tonumber(Seconds) or 5) * 1000)))
	CurrentRace.CountdownEndsAt = GetGameTimer() + DurationMs
	SetVehicleHeld(RaceVehicle(),true)
	if CurrentRace.Mode == "npc" then
		local _,NpcVehicle = NpcEntities()
		SetVehicleHeld(NpcVehicle,true)
	end
	SendNUIMessage({
		action = "countdown",
		payload = {
			seconds = Seconds,
			durationMs = DurationMs,
			serverStartAt = Sync and Sync.startAt or 0
		}
	})
end)

RegisterNetEvent("af_illegal_races:Start",function(RaceId)
	if not CurrentRace or CurrentRace.Id ~= RaceId then
		return
	end

	CurrentRace.Status = "racing"
	CurrentRace.StartedAt = GetGameTimer()
	ReleaseCountdownLocks()
	local Vehicle = RaceVehicle()
	if Vehicle ~= 0 and DoesEntityExist(Vehicle) then
		CurrentRace.PreviousVehicleCoords = GetEntityCoords(Vehicle)
	end
	if CurrentRace.Mode == "npc" then
		ResetNpcDriveMonitor()
		DriveNpcToCheckpoint()
	end
	SendNUIMessage({ action = "startRace" })
end)

RegisterNetEvent("af_illegal_races:CheckpointAccepted",function(Payload)
	if not CurrentRace then
		return
	end

	local Index = type(Payload) == "table" and Payload.acceptedSequence or Payload
	if type(Payload) == "table" and tonumber(Payload.raceId) ~= CurrentRace.Id then
		return
	end

	CheckpointPending = false
	CurrentRace.Checkpoint = tonumber(Index) + 1
	if CurrentRace.Checkpoint <= #CurrentRace.Route then
		SetRoutePoint(CurrentRace.Checkpoint)
		PlaySoundFrontend(-1,"CHECKPOINT_NORMAL","HUD_MINI_GAME_SOUNDSET",true)
	end
end)

RegisterNetEvent("af_illegal_races:CheckpointDebug",function(Enabled)
	CheckpointDebugEnabled = Enabled == true
	print(("[af_illegal_races] checkpoint_debug=%s"):format(tostring(CheckpointDebugEnabled)))
end)

RegisterNetEvent("af_illegal_races:NpcCheckpointAccepted",function(Index)
	if not CurrentRace or CurrentRace.Mode ~= "npc" then
		return
	end

	NpcCheckpointPending = false
	CurrentRace.NpcCheckpoint = tonumber(Index) + 1
	if CurrentRace.NpcCheckpoint <= #CurrentRace.Route then
		ResetNpcDriveMonitor()
		DriveNpcToCheckpoint()
	end
end)

RegisterNetEvent("af_illegal_races:Progress",function(Data)
	if not CurrentRace then
		return
	end

	CurrentRace.Progress = Data
end)

RegisterNetEvent("af_illegal_races:OpponentPosition",function(Data)
	if not CurrentRace or type(Data) ~= "table" or CurrentRace.Id ~= tonumber(Data.raceId) then
		return
	end
	if CurrentRace.Status ~= "countdown" and CurrentRace.Status ~= "racing" then
		return
	end

	UpdateOpponentBlip(Data,false)
end)

RegisterNetEvent("af_illegal_races:OpponentBlipClear",function(RaceId)
	RaceId = tonumber(RaceId)
	if not RaceId or OpponentBlipRaceId == RaceId then
		RemoveOpponentBlip()
	end
end)

RegisterNetEvent("af_illegal_races:OpponentBlipTest",function(Data)
	if CurrentRace then
		return
	end

	UpdateOpponentBlip(Data,true)
end)

RegisterNetEvent("af_illegal_races:OpponentBlipTestStop",function()
	if OpponentBlipTest then
		RemoveOpponentBlip()
	end
end)

RegisterNetEvent("af_illegal_races:End",function(Data)
	local WasRacing = CurrentRace and CurrentRace.Status == "racing"
	if WasRacing then
		SendNUIMessage({ action = "completeRace", payload = { complete = Data and Data.result == "win" } })
	end
	CleanupRace(WasRacing)
	CloseLobby()
	SendNUIMessage({ action = "result", payload = Data or {} })
end)

RegisterNetEvent("af_illegal_races:RouteAuditStart",function(Data)
	ClearRouteAudit()
	RouteAudit = Data
	for Index,Point in ipairs(Data.route or Data.Route or {}) do
		local Blip = AddBlipForCoord(Point.x,Point.y,Point.z)
		SetBlipSprite(Blip,Point.finish and 38 or 1)
		SetBlipColour(Blip,Point.finish and 2 or 1)
		SetBlipScale(Blip,Point.finish and 0.9 or 0.7)
		SetBlipAsShortRange(Blip,false)
		ShowNumberOnBlip(Blip,Index)
		BeginTextCommandSetBlipName("STRING")
		AddTextComponentString(Point.finish and "Destino da auditoria" or ("Checkpoint de auditoria "..Index))
		EndTextCommandSetBlipName(Blip)
		RouteAuditBlips[#RouteAuditBlips + 1] = Blip
	end
	RouteAudit.Route = Data.route or Data.Route or {}
	SetRouteAuditPoint(1)
end)

RegisterNetEvent("af_illegal_races:RouteAuditNext",function(Index)
	SetRouteAuditPoint(Index)
end)

RegisterNetEvent("af_illegal_races:RouteAuditStop",function()
	ClearRouteAudit()
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- RACE LOOP
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	while true do
		local Sleep = 1000
		if CurrentRace and (CurrentRace.Status == "racing" or CurrentRace.Status == "countdown") then
			Sleep = 0
			local Point = CurrentRace.Route[CurrentRace.Checkpoint]
			local Vehicle = RaceVehicle()

			if CurrentRace.Status == "countdown" then
				DisableControlAction(0,75,true)
				DisableControlAction(0,72,true)
				DisableControlAction(0,76,true)
				if Config.CountdownLock and Config.CountdownLock.LockSteering ~= false then
					DisableControlAction(0,59,true)
				end
				local PlayerPed = PlayerPedId()
				local IsActiveDriver = Vehicle ~= 0 and DoesEntityExist(Vehicle) and GetPedInVehicleSeat(Vehicle,-1) == PlayerPed and not IsPedDeadOrDying(PlayerPed,true) and GetEntityHealth(PlayerPed) > 100
				if IsActiveDriver then
					if not CountdownLocks[Vehicle] then
						SetVehicleHeld(Vehicle,true)
					end
					MaintainCountdownLock(Vehicle,false)
				else
					SetVehicleHeld(Vehicle,false)
				end
				if CurrentRace.Mode == "npc" then
					local _,NpcVehicle = NpcEntities()
					MaintainCountdownLock(NpcVehicle,true)
				end
			elseif Point and Vehicle ~= 0 and DoesEntityExist(Vehicle) then
				local Coords = GetEntityCoords(Vehicle)
				local Distance = HorizontalDistance(Coords,Point)
				local Radius = PointRadius(Point)

				DrawMarker(1,Point.x,Point.y,Point.z - 1.05,0.0,0.0,0.0,0.0,0.0,0.0,Radius * 1.25,Radius * 1.25,1.2,220,38,58,95,false,false,2,false)
				local DetectionInterval = math.max(0,tonumber(Config.CheckpointValidation and Config.CheckpointValidation.DetectionInterval) or 50)
				local Passed = CheckpointPassed(CurrentRace.PreviousVehicleCoords,Coords,Point,Radius)
				CurrentRace.PreviousVehicleCoords = Coords
				if Passed and GetGameTimer() >= NextCheckpointDetection and not CheckpointPending then
					CheckpointPending = true
					NextCheckpointDetection = GetGameTimer() + DetectionInterval
					TriggerServerEvent("af_illegal_races:Checkpoint",CurrentRace.Id,CurrentRace.Token,CurrentRace.Checkpoint,VehToNet(Vehicle))
					if CheckpointDebugEnabled then
						print(("[af_illegal_races] checkpoint_hit sequence=%s horizontal=%.2f vertical=%.2f"):format(CurrentRace.Checkpoint,Distance,math.abs(Coords.z - Point.z)))
					end
					SetTimeout(math.max(250,tonumber(Config.CheckpointValidation and Config.CheckpointValidation.PendingTimeout) or 1500),function()
						CheckpointPending = false
					end)
				end

				if GetGameTimer() >= LastHudUpdate then
					LastHudUpdate = GetGameTimer() + 200
					local OwnCompleted = math.max(CurrentRace.Progress.current or 0,CurrentRace.Checkpoint - 1)
					local OpponentCompleted = CurrentRace.Progress.opponent or 0
					local OwnProgress = ContinuousProgress(Vehicle,OwnCompleted,CurrentRace.Metrics,CurrentRace.Route)
					local OpponentVehicle = 0
					if CurrentRace.Mode == "npc" then
						local _,NpcVehicle = NpcEntities()
						OpponentVehicle = NpcVehicle
					elseif CurrentRace.OpponentVehicleNet and CurrentRace.OpponentVehicleNet > 0 then
						OpponentVehicle = NetToVeh(CurrentRace.OpponentVehicleNet)
					end
					local OpponentProgress = ContinuousProgress(OpponentVehicle,OpponentCompleted,CurrentRace.OpponentMetrics,CurrentRace.Route)
					local Position = "tie"
					if OwnProgress > OpponentProgress + 0.15 then
						Position = 1
					elseif OpponentProgress > OwnProgress + 0.15 then
						Position = 2
					end
					SendNUIMessage({
						action = "raceHud",
						payload = {
							position = Position,
							checkpoint = math.min(CurrentRace.Checkpoint,#CurrentRace.Route),
							total = #CurrentRace.Route,
							distance = math.floor(Distance),
							elapsed = math.max(0,GetGameTimer() - CurrentRace.StartedAt),
							opponent = CurrentRace.OpponentName,
							prize = CurrentRace.Prize,
							progress = OwnProgress,
							opponentProgress = OpponentProgress
						}
					})
				end
			end

			if CurrentRace.Status == "racing" and CurrentRace.Mode == "npc" then
				local NpcPed,NpcVehicle = NpcEntities()
				local NpcPoint = CurrentRace.Route[CurrentRace.NpcCheckpoint]
				if NpcPed ~= 0 and NpcVehicle ~= 0 and DoesEntityExist(NpcPed) and DoesEntityExist(NpcVehicle) and NpcPoint then
					local NpcDistance = #(GetEntityCoords(NpcVehicle) - vec3(NpcPoint.x,NpcPoint.y,NpcPoint.z))
					local NpcRadius = tonumber(NpcPoint.radius) or Config.CheckpointRadius
					if NpcDistance <= NpcRadius and not NpcCheckpointPending then
						NpcCheckpointPending = true
						TriggerServerEvent("af_illegal_races:NpcCheckpoint",CurrentRace.Id,CurrentRace.Token,CurrentRace.NpcCheckpoint)
						SetTimeout(1500,function()
							NpcCheckpointPending = false
						end)
					else
						MonitorNpcDriver(NpcPed,NpcVehicle,NpcPoint,NpcDistance)
					end
				end
			end
		end

		Wait(Sleep)
	end
end)

CreateThread(function()
	while true do
		Wait(1000)
		if OpponentBlip and DoesBlipExist(OpponentBlip) then
			local StaleAfter = math.max(1500,math.floor(tonumber(Config.OpponentBlip and Config.OpponentBlip.StaleAfter) or 3500))
			local InvalidRace = not OpponentBlipTest and (not CurrentRace or CurrentRace.Id ~= OpponentBlipRaceId or (CurrentRace.Status ~= "countdown" and CurrentRace.Status ~= "racing"))
			if InvalidRace or GetGameTimer() - OpponentBlipUpdatedAt > StaleAfter then
				RemoveOpponentBlip()
			end
		end
	end
end)

CreateThread(function()
	while true do
		local Sleep = 750
		if RouteAudit and RouteAudit.Route then
			Sleep = 0
			local Start = RouteAudit.Start
			local Forward = RouteAudit.Forward
			if Start and Forward then
				local Length = tonumber(Config.RouteAudit and Config.RouteAudit.ForwardLineDistance) or 120.0
				local FinishX = Start.x + ((Forward.x or 0.0) * Length)
				local FinishY = Start.y + ((Forward.y or 0.0) * Length)
				DrawLine(Start.x,Start.y,Start.z + 1.0,FinishX,FinishY,Start.z + 1.0,42,210,118,220)
				DrawMarker(28,FinishX,FinishY,Start.z + 1.0,0.0,0.0,0.0,0.0,0.0,0.0,1.2,1.2,1.2,42,210,118,190,false,false,2,false)
			end
			for Index,Point in ipairs(RouteAudit.Route) do
				local Active = Index == RouteAudit.Index
				local Radius = Active and 11.0 or 6.0
				DrawMarker(1,Point.x,Point.y,Point.z - 1.05,0.0,0.0,0.0,0.0,0.0,0.0,Radius,Radius,1.0,Active and 195 or 112,Active and 43 or 114,Active and 60 or 118,Active and 120 or 55,false,false,2,false)
			end
		end
		Wait(Sleep)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- RESOURCE STOP
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("onResourceStop",function(Resource)
	if Resource ~= GetCurrentResourceName() then
		return
	end

	CleanupRace()
	CloseLobby()
	ReleasePendingNpc()
	ClearRouteAudit()
	RemoveOpponentBlip()
end)
