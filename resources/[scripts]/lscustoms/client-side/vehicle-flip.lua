local Tunnel = module("vrp","lib/Tunnel")
local vRP = Tunnel.getInterface("vRP")

local FlipProcess = nil
local DebugEnabled = false
local DebugText = ""

local function Notify(Message,Color)
	TriggerEvent("Notify","Mecanica",Message,Color or "amarelo",5000)
end

local function NormalizePlate(Plate)
	return tostring(Plate or ""):gsub("%s+",""):upper()
end

local function RequestControl(Entity)
	local Timeout = GetGameTimer() + (tonumber(VehicleFlipConfig.NetworkControlTimeout) or 1500)
	NetworkRequestControlOfEntity(Entity)
	while not NetworkHasControlOfEntity(Entity) and GetGameTimer() < Timeout do
		Wait(50)
		NetworkRequestControlOfEntity(Entity)
	end

	return NetworkHasControlOfEntity(Entity)
end

local function VehicleIsEmpty(Vehicle)
	local Success,Maximum = pcall(GetVehicleMaxNumberOfPassengers,Vehicle)
	Maximum = Success and math.max(0,tonumber(Maximum) or 0) or 12
	for Seat = -1,Maximum - 1 do
		if GetPedInVehicleSeat(Vehicle,Seat) ~= 0 then
			return false
		end
	end

	return true
end

local function IsOverturned(Vehicle)
	local Roll = math.abs(GetEntityRoll(Vehicle))
	local Rotation = GetEntityRotation(Vehicle,2)
	local Pitch = math.abs(tonumber(Rotation.x) or 0.0)
	local Threshold = tonumber(VehicleFlipConfig.MinimumOverturnedAngle) or 55.0
	return IsEntityUpsidedown(Vehicle) or Roll >= Threshold or Pitch >= Threshold,Pitch,Roll
end

local function Clamp(Value,Minimum,Maximum)
	return math.max(Minimum,math.min(Maximum,Value))
end

local function DistanceToVehicleBody(PedCoords,Vehicle)
	local Minimum,Maximum = GetModelDimensions(GetEntityModel(Vehicle))
	local LocalCoords = GetOffsetFromEntityGivenWorldCoords(Vehicle,PedCoords.x,PedCoords.y,PedCoords.z)
	local ClosestX = Clamp(LocalCoords.x,Minimum.x,Maximum.x)
	local ClosestY = Clamp(LocalCoords.y,Minimum.y,Maximum.y)
	local ClosestZ = Clamp(LocalCoords.z,Minimum.z,Maximum.z)
	local DifferenceX = LocalCoords.x - ClosestX
	local DifferenceY = LocalCoords.y - ClosestY
	local DifferenceZ = LocalCoords.z - ClosestZ

	return math.sqrt(
		DifferenceX * DifferenceX +
		DifferenceY * DifferenceY +
		DifferenceZ * DifferenceZ
	)
end

local function FindNearestVehicleForFlip()
	local PedCoords = GetEntityCoords(PlayerPedId())
	local SearchRadius = tonumber(VehicleFlipConfig.SearchRadius) or 10.0
	local MaximumDistance = tonumber(VehicleFlipConfig.MaximumDistance) or 4.5
	local NearestOverturned = nil
	local NearestVehicle = nil

	for _,Vehicle in ipairs(GetGamePool("CVehicle")) do
		if Vehicle ~= 0 and DoesEntityExist(Vehicle) then
			local CenterDistance = #(PedCoords - GetEntityCoords(Vehicle))
			if CenterDistance <= SearchRadius then
				local BodyDistance = DistanceToVehicleBody(PedCoords,Vehicle)
				if BodyDistance <= MaximumDistance then
					local Overturned,Pitch,Roll = IsOverturned(Vehicle)
					local Candidate = {
						vehicle = Vehicle,
						bodyDistance = BodyDistance,
						centerDistance = CenterDistance,
						overturned = Overturned,
						pitch = Pitch,
						roll = Roll
					}

					if not NearestVehicle or BodyDistance < NearestVehicle.bodyDistance then
						NearestVehicle = Candidate
					end

					if Overturned and (not NearestOverturned or BodyDistance < NearestOverturned.bodyDistance) then
						NearestOverturned = Candidate
					end
				end
			end
		end
	end

	local Selected = NearestOverturned or NearestVehicle
	if not Selected then
		return nil
	end

	Selected.network = NetworkGetNetworkIdFromEntity(Selected.vehicle)
	Selected.plate = NormalizePlate(GetVehicleNumberPlateText(Selected.vehicle))
	return Selected
end

local function ClosestVehicle(Silent)
	local Ped = PlayerPedId()
	if GetEntityHealth(Ped) <= 100 then
		if not Silent then Notify("Voce nao pode trabalhar neste estado.","vermelho") end
		return nil
	end

	if IsPedInAnyVehicle(Ped,false) then
		if not Silent then Notify("Saia do veiculo para realizar o atendimento.","amarelo") end
		return nil
	end

	local Selected = FindNearestVehicleForFlip()
	if not Selected then
		if not Silent then Notify("Nenhum veiculo encontrado nas proximidades.","amarelo") end
		return nil
	end
	local Vehicle = Selected.vehicle

	if GetEntitySpeed(Vehicle) > (tonumber(VehicleFlipConfig.MaximumVehicleSpeed) or 1.5) then
		if not Silent then Notify("O veiculo precisa estar parado.","amarelo") end
		return nil
	end

	if VehicleFlipConfig.RequireEmptyVehicle and not VehicleIsEmpty(Vehicle) then
		if not Silent then Notify("Todos precisam sair do veiculo antes de desvira-lo.","amarelo") end
		return nil
	end

	if not Selected.overturned then
		if not Silent then Notify("Este veiculo nao precisa ser desvirado.","amarelo") end
		return nil
	end

	if not Selected.network or Selected.network <= 0 then
		if not Silent then Notify("Nao foi possivel identificar este veiculo na rede.","vermelho") end
		return nil
	end

	return Vehicle,Selected.network,Selected.plate
end

local function RequestNearestFlip(Silent)
	if not VehicleFlipConfig.Enabled then
		if not Silent then Notify("A funcao de desvirar esta desativada.","amarelo") end
		return false,"Funcao desativada."
	end

	if FlipProcess then
		if not Silent then Notify("Ja existe um atendimento em andamento.","amarelo") end
		return false,"Atendimento em andamento."
	end

	local Vehicle,Network,Plate = ClosestVehicle(Silent)
	if not Vehicle then
		return false,"Nenhum veiculo tombado disponivel."
	end

	TriggerServerEvent("lscustoms:flip:request",Network,Plate)
	return true,"Validando atendimento..."
end

for _,Command in ipairs(VehicleFlipConfig.Commands or { "desvirar","flip" }) do
	RegisterCommand(Command,function()
		RequestNearestFlip(false)
	end,false)
end

RegisterNUICallback("MechanicFlip",function(_,Callback)
	local Success,Message = RequestNearestFlip(true)
	Callback({ success = Success, message = Message })
end)

RegisterNetEvent("lscustoms:flip:start",function(Data)
	if type(Data) ~= "table" or FlipProcess then
		return
	end

	local Vehicle = NetworkDoesNetworkIdExist(Data.network) and NetToVeh(Data.network) or 0
	if Vehicle == 0 or not DoesEntityExist(Vehicle) or NormalizePlate(GetVehicleNumberPlateText(Vehicle)) ~= NormalizePlate(Data.plate) then
		TriggerServerEvent("lscustoms:flip:cancel",Data.token,"vehicle_unavailable")
		return
	end

	local Ped = PlayerPedId()
	local Duration = math.max(1000,tonumber(Data.duration) or 5000)
	local Dict = "mini@repair"
	RequestAnimDict(Dict)
	local Timeout = GetGameTimer() + 2500
	while not HasAnimDictLoaded(Dict) and GetGameTimer() < Timeout do
		Wait(10)
	end

	FlipProcess = {
		token = tostring(Data.token or ""),
		network = tonumber(Data.network),
		plate = NormalizePlate(Data.plate),
		vehicle = Vehicle,
		startedAt = GetGameTimer(),
		duration = Duration
	}

	if HasAnimDictLoaded(Dict) then
		TaskPlayAnim(Ped,Dict,"fixing_a_player",3.0,3.0,Duration,49,0.0,false,false,false)
	end
	TriggerEvent("Progress","Preparando o veiculo",Duration)

	CreateThread(function()
		while FlipProcess and GetGameTimer() - FlipProcess.startedAt < FlipProcess.duration do
			local Process = FlipProcess
			local CurrentPed = PlayerPedId()
			local TooFar = DoesEntityExist(Process.vehicle) and DistanceToVehicleBody(GetEntityCoords(CurrentPed),Process.vehicle) > (tonumber(VehicleFlipConfig.MaximumDistance) or 4.5) + 0.75
			if GetEntityHealth(CurrentPed) <= 100 or IsPedInAnyVehicle(CurrentPed,false) or not DoesEntityExist(Process.vehicle) or TooFar then
				TriggerServerEvent("lscustoms:flip:cancel",Process.token,"process_interrupted")
				ClearPedTasks(CurrentPed)
				FlipProcess = nil
				Notify("O atendimento foi cancelado.","amarelo")
				return
			end
			Wait(100)
		end

		if FlipProcess then
			local Token = FlipProcess.token
			ClearPedTasks(PlayerPedId())
			TriggerServerEvent("lscustoms:flip:commit",Token)
		end
	end)
end)

local function HasNearbyVehicleConflict(Vehicle,Coords)
	for _,Other in ipairs(GetGamePool("CVehicle")) do
		if Other ~= Vehicle and DoesEntityExist(Other) and #(GetEntityCoords(Other) - Coords) < 3.0 then
			return true
		end
	end

	return false
end

local function SafeToFlip(Vehicle)
	if IsEntityInWater(Vehicle) then
		return false,"Nao e seguro desvirar um veiculo dentro da agua."
	end

	local Coords = GetEntityCoords(Vehicle)
	if HasNearbyVehicleConflict(Vehicle,Coords) then
		return false,"Afaste os outros veiculos antes do atendimento."
	end

	local FoundGround,GroundZ = GetGroundZFor_3dCoord(Coords.x,Coords.y,Coords.z + 3.0,false)
	if not FoundGround or math.abs(Coords.z - GroundZ) > 4.0 then
		return false,"Nao foi encontrado solo seguro para o veiculo."
	end

	local Minimum,Maximum = GetModelDimensions(GetEntityModel(Vehicle))
	local RequiredHeight = math.max(1.5,(Maximum.z - Minimum.z) + 0.35)
	local Ray = StartShapeTestCapsule(Coords.x,Coords.y,Coords.z + 0.35,Coords.x,Coords.y,Coords.z + RequiredHeight,0.35,1,Vehicle,7)
	local _,Blocked = GetShapeTestResult(Ray)
	if Blocked == 1 then
		return false,"Nao ha espaco vertical suficiente para desvirar o veiculo."
	end

	return true,nil,GroundZ
end

RegisterNetEvent("lscustoms:flip:execute",function(Data)
	local Process = FlipProcess
	if not Process or type(Data) ~= "table" or Process.token ~= tostring(Data.token or "") then
		return
	end

	local Vehicle = NetworkDoesNetworkIdExist(Data.network) and NetToVeh(Data.network) or 0
	if Vehicle == 0 or not DoesEntityExist(Vehicle) or NormalizePlate(GetVehicleNumberPlateText(Vehicle)) ~= Process.plate then
		TriggerServerEvent("lscustoms:flip:result",Process.token,false,"O veiculo ficou indisponivel.")
		FlipProcess = nil
		return
	end

	local Safe,Reason,GroundZ = SafeToFlip(Vehicle)
	if not Safe then
		TriggerServerEvent("lscustoms:flip:result",Process.token,false,Reason)
		FlipProcess = nil
		return
	end

	if not RequestControl(Vehicle) then
		TriggerServerEvent("lscustoms:flip:result",Process.token,false,"Nao foi possivel obter controle do veiculo.")
		FlipProcess = nil
		return
	end

	local Coords = GetEntityCoords(Vehicle)
	local Heading = GetEntityHeading(Vehicle)
	FreezeEntityPosition(Vehicle,true)
	SetEntityVelocity(Vehicle,0.0,0.0,0.0)
	SetEntityCoordsNoOffset(Vehicle,Coords.x,Coords.y,math.max(Coords.z,GroundZ) + (tonumber(VehicleFlipConfig.LiftHeight) or 0.45),false,false,false)
	SetEntityRotation(Vehicle,0.0,0.0,Heading,2,true)
	SetVehicleOnGroundProperly(Vehicle)
	Wait(350)
	SetEntityVelocity(Vehicle,0.0,0.0,0.0)
	FreezeEntityPosition(Vehicle,false)

	local Token = Process.token
	local StillOverturned = IsOverturned(Vehicle)
	FlipProcess = nil
	TriggerServerEvent("lscustoms:flip:result",Token,not StillOverturned,StillOverturned and "O veiculo nao estabilizou corretamente." or nil)
end)

RegisterNetEvent("lscustoms:flip:cancel",function()
	if FlipProcess then
		ClearPedTasks(PlayerPedId())
		FlipProcess = nil
	end
end)

local function DiagnosticText()
	local Selected = FindNearestVehicleForFlip()
	if not Selected then
		return "MEC FLIP | nenhum veiculo proximo"
	end

	return ("MEC FLIP | ent %s | net %s | placa %s | centro %.2f | carroceria %.2f | vel %.2f | pitch %.1f | roll %.1f | invertido %s | tombado %s | controle %s"):format(
		tostring(Selected.vehicle),
		tostring(Selected.network),
		Selected.plate,
		Selected.centerDistance,
		Selected.bodyDistance,
		GetEntitySpeed(Selected.vehicle),
		Selected.pitch,
		Selected.roll,
		tostring(IsEntityUpsidedown(Selected.vehicle)),
		tostring(Selected.overturned),
		tostring(NetworkHasControlOfEntity(Selected.vehicle))
	)
end

RegisterNetEvent("lscustoms:flip:diagnostic",function()
	local Text = DiagnosticText()
	print(("[lscustoms/mechanic] %s"):format(Text))
	Notify(Text,"azul")
end)

RegisterNetEvent("lscustoms:flip:toggleDebug",function()
	DebugEnabled = not DebugEnabled
	Notify(DebugEnabled and "Diagnostico de desvirar ativado." or "Diagnostico de desvirar desativado.","azul")
end)

local function DrawDebug(Text)
	SetTextFont(4)
	SetTextScale(0.32,0.32)
	SetTextColour(255,255,255,225)
	SetTextOutline()
	SetTextEntry("STRING")
	AddTextComponentString(Text)
	DrawText(0.015,0.76)
end

CreateThread(function()
	local UpdatedAt = 0
	while true do
		if DebugEnabled then
			if GetGameTimer() >= UpdatedAt then
				UpdatedAt = GetGameTimer() + 500
				DebugText = DiagnosticText()
			end
			DrawDebug(DebugText)
			Wait(0)
		else
			Wait(500)
		end
	end
end)

AddEventHandler("onResourceStop",function(Resource)
	if Resource ~= GetCurrentResourceName() then return end
	ClearPedTasks(PlayerPedId())
	if FlipProcess and FlipProcess.vehicle and DoesEntityExist(FlipProcess.vehicle) then
		FreezeEntityPosition(FlipProcess.vehicle,false)
	end
	FlipProcess = nil
end)
