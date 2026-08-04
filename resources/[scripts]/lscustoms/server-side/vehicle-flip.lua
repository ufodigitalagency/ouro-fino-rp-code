local Proxy = module("vrp","lib/Proxy")
local vRP = Proxy.getInterface("vRP")

local ActiveFlips = {}
local ActiveNetworks = {}
local FlipCooldowns = {}
local RequestLimits = {}

local function Notify(Source,Message,Color)
	if Source and Source > 0 and GetPlayerName(Source) then
		TriggerClientEvent("Notify",Source,"Mecanica",Message,Color or "amarelo",5000)
	end
end

local function Debug(Message)
	if VehicleFlipConfig.Debug then
		print(("[lscustoms/mechanic] %s"):format(Message))
	end
end

local function NormalizePlate(Plate)
	return tostring(Plate or ""):gsub("%s+",""):upper()
end

local function IsOnline(Source)
	return Source and Source > 0 and GetPlayerName(Source) ~= nil
end

local function IsRacing(Source)
	local State = Player(Source).state
	return State and State.StreetRace == true
end

local function HasMechanicAccess(Source,Passport,Silent)
	local Permission = MechanicConfig.Permission or "Bennys"
	if not Passport or not vRP.HasPermission(Passport,Permission) then
		if not Silent then
			Notify(Source,"Voce nao possui o cargo de mecanico.","vermelho")
		end
		return false,"not_mechanic"
	end

	if VehicleFlipConfig.RequireDuty and not vRP.HasService(Passport,Permission) then
		if not Silent then
			Notify(Source,"Entre em servico com /"..tostring(MechanicConfig.DutyCommand or "mecservico")..".","amarelo")
		end
		return false,"not_on_duty"
	end

	if IsRacing(Source) then
		if not Silent then
			Notify(Source,"Voce nao pode utilizar o servico mecanico enquanto participa de um racha.","vermelho")
		end
		return false,"mechanic_racing"
	end

	return true
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

local function OverturnedMetrics(Vehicle)
	local Success,Rotation = pcall(GetEntityRotation,Vehicle,2)
	if not Success or not Rotation then
		return false,0.0,0.0
	end
	local Pitch = math.abs(tonumber(Rotation.x) or 0.0)
	local Roll = math.abs(tonumber(Rotation.y) or 0.0)
	local Threshold = tonumber(VehicleFlipConfig.MinimumOverturnedAngle) or 55.0
	return Pitch >= Threshold or Roll >= Threshold,Pitch,Roll
end

local function ValidateVehicle(Source,Passport,Network,Plate,Silent)
	local Allowed,Reason = HasMechanicAccess(Source,Passport,Silent)
	if not Allowed then
		return nil,Reason
	end

	Network = math.floor(tonumber(Network) or 0)
	local Ped = GetPlayerPed(Source)
	local Vehicle = Network > 0 and NetworkGetEntityFromNetworkId(Network) or 0
	if Ped <= 0 or not DoesEntityExist(Ped) or GetEntityHealth(Ped) <= 100 then
		if not Silent then Notify(Source,"Voce nao pode trabalhar neste estado.","vermelho") end
		return nil,"invalid_mechanic"
	end

	if GetVehiclePedIsIn(Ped,false) ~= 0 then
		if not Silent then Notify(Source,"Saia do veiculo para realizar o atendimento.","amarelo") end
		return nil,"mechanic_inside_vehicle"
	end

	if Vehicle <= 0 or not DoesEntityExist(Vehicle) or GetEntityType(Vehicle) ~= 2 then
		if not Silent then Notify(Source,"Veiculo invalido ou indisponivel.","vermelho") end
		return nil,"invalid_vehicle"
	end

	if GetEntityRoutingBucket(Vehicle) ~= GetPlayerRoutingBucket(Source) then
		if not Silent then Notify(Source,"O veiculo esta em outra instancia.","vermelho") end
		return nil,"routing_bucket"
	end

	if NormalizePlate(GetVehicleNumberPlateText(Vehicle)) ~= NormalizePlate(Plate) then
		if not Silent then Notify(Source,"A placa do veiculo nao confere.","vermelho") end
		return nil,"plate_mismatch"
	end

	local Distance = #(GetEntityCoords(Ped) - GetEntityCoords(Vehicle))
	if Distance > (tonumber(VehicleFlipConfig.MaximumServerCenterDistance) or 10.0) then
		if not Silent then Notify(Source,"Aproxime-se do veiculo.","amarelo") end
		return nil,"distance"
	end

	if GetEntitySpeed(Vehicle) > (tonumber(VehicleFlipConfig.MaximumVehicleSpeed) or 1.5) then
		if not Silent then Notify(Source,"O veiculo precisa estar parado.","amarelo") end
		return nil,"moving_vehicle"
	end

	if VehicleFlipConfig.RequireEmptyVehicle and not VehicleIsEmpty(Vehicle) then
		if not Silent then Notify(Source,"Todos precisam sair do veiculo antes de desvira-lo.","amarelo") end
		return nil,"occupied_vehicle"
	end

	local Overturned,Pitch,Roll = OverturnedMetrics(Vehicle)
	if not Overturned then
		if not Silent then Notify(Source,"Este veiculo nao precisa ser desvirado.","amarelo") end
		return nil,"not_overturned"
	end

	return Vehicle,nil,{
		distance = Distance,
		pitch = Pitch,
		roll = Roll,
		speed = GetEntitySpeed(Vehicle)
	}
end

local function ClearFlip(Source,Reason)
	local Session = ActiveFlips[Source]
	if not Session then
		return
	end

	ActiveFlips[Source] = nil
	if ActiveNetworks[Session.Network] == Source then
		ActiveNetworks[Session.Network] = nil
	end
	if Reason then
		Debug(("flip cancelled mechanic=%s network=%s reason=%s"):format(Session.Passport,Session.Network,Reason))
	end
end

RegisterNetEvent("lscustoms:flip:request",function(Network,Plate)
	local Source = source
	local Passport = vRP.Passport(Source)
	Network = math.floor(tonumber(Network) or 0)

	if not VehicleFlipConfig.Enabled or not Passport then
		return
	end

	local RequestNow = GetGameTimer()
	if RequestNow < (RequestLimits[Source] or 0) then
		return
	end
	RequestLimits[Source] = RequestNow + 500

	if ActiveFlips[Source] or ActiveNetworks[Network] then
		Notify(Source,"Este veiculo ja esta sendo preparado.","amarelo")
		return
	end

	local Now = GetGameTimer()
	if Now < (FlipCooldowns[Passport] or 0) then
		Notify(Source,"Aguarde antes de tentar desvirar outro veiculo.","amarelo")
		return
	end

	local Vehicle,Reason,Metrics = ValidateVehicle(Source,Passport,Network,Plate,false)
	if not Vehicle then
		Debug(("flip denied mechanic=%s network=%s reason=%s"):format(Passport,Network,tostring(Reason)))
		return
	end

	local Token = ("flip:%s:%s:%s:%s"):format(Source,Passport,os.time(),math.random(100000,999999))
	ActiveFlips[Source] = {
		Token = Token,
		Passport = Passport,
		Network = Network,
		Plate = NormalizePlate(Plate),
		StartedAt = Now,
		Duration = tonumber(VehicleFlipConfig.Duration) or 5000,
		ExpiresAt = Now + (tonumber(VehicleFlipConfig.SessionTimeout) or 12000),
		State = "preparing"
	}
	ActiveNetworks[Network] = Source
	FlipCooldowns[Passport] = Now + (tonumber(VehicleFlipConfig.Cooldown) or 8000)

	Debug(("flip requested mechanic=%s network=%s plate=%s pitch=%.2f roll=%.2f"):format(Passport,Network,NormalizePlate(Plate),Metrics.pitch,Metrics.roll))
	TriggerClientEvent("lscustoms:flip:start",Source,{
		token = Token,
		network = Network,
		plate = NormalizePlate(Plate),
		duration = ActiveFlips[Source].Duration
	})
end)

RegisterNetEvent("lscustoms:flip:commit",function(Token)
	local Source = source
	local Session = ActiveFlips[Source]
	if not Session or Session.Token ~= tostring(Token or "") or Session.State ~= "preparing" then
		return
	end

	if GetGameTimer() - Session.StartedAt < math.max(750,Session.Duration - 250) then
		Debug(("flip denied mechanic=%s network=%s reason=early_commit"):format(Session.Passport,Session.Network))
		return
	end

	local Passport = vRP.Passport(Source)
	local Vehicle,Reason = ValidateVehicle(Source,Passport,Session.Network,Session.Plate,false)
	if not Vehicle then
		TriggerClientEvent("lscustoms:flip:cancel",Source)
		ClearFlip(Source,Reason or "validation")
		return
	end

	Session.State = "executing"
	Session.ExpiresAt = GetGameTimer() + 5000
	TriggerClientEvent("lscustoms:flip:execute",Source,{
		token = Session.Token,
		network = Session.Network,
		plate = Session.Plate
	})
end)

RegisterNetEvent("lscustoms:flip:result",function(Token,Success,Reason)
	local Source = source
	local Session = ActiveFlips[Source]
	if not Session or Session.Token ~= tostring(Token or "") or Session.State ~= "executing" then
		return
	end

	local Passport = Session.Passport
	local Network = Session.Network
	if Success == true then
		local Vehicle = NetworkGetEntityFromNetworkId(Network)
		local StillOverturned = Vehicle <= 0 or not DoesEntityExist(Vehicle) or OverturnedMetrics(Vehicle)
		if StillOverturned then
			Success = false
			Reason = "O veiculo nao ficou em uma posicao segura."
		end
	end
	ClearFlip(Source)
	if Success == true then
		Notify(Source,"Veiculo desvirado com sucesso.","verde")
		Debug(("flip completed mechanic=%s network=%s"):format(Passport,Network))
	else
		Notify(Source,tostring(Reason or "Nao foi possivel desvirar o veiculo."),"vermelho")
		Debug(("flip cancelled mechanic=%s network=%s reason=%s"):format(Passport,Network,tostring(Reason or "client_failure")))
	end
end)

RegisterNetEvent("lscustoms:flip:cancel",function(Token,Reason)
	local Source = source
	local Session = ActiveFlips[Source]
	if not Session or Session.Token ~= tostring(Token or "") then
		return
	end

	ClearFlip(Source,tostring(Reason or "client_cancel"))
end)

local function DebugAllowed(Source)
	local Passport = vRP.Passport(Source)
	return VehicleFlipConfig.Debug and Passport and tonumber(Passport) == tonumber(VehicleFlipConfig.OwnerPassport or 1)
end

RegisterCommand(VehicleFlipConfig.DebugCommands.Test,function(Source)
	if not DebugAllowed(Source) then return end
	TriggerClientEvent("lscustoms:flip:diagnostic",Source)
end,false)

RegisterCommand(VehicleFlipConfig.DebugCommands.Overlay,function(Source)
	if not DebugAllowed(Source) then return end
	TriggerClientEvent("lscustoms:flip:toggleDebug",Source)
end,false)

CreateThread(function()
	while true do
		Wait(1000)
		local Now = GetGameTimer()
		for Source,Session in pairs(ActiveFlips) do
			if not IsOnline(Source) or Now > Session.ExpiresAt then
				if IsOnline(Source) then
					TriggerClientEvent("lscustoms:flip:cancel",Source)
				end
				ClearFlip(Source,"timeout_or_disconnect")
			end
		end
	end
end)

AddEventHandler("playerDropped",function()
	local Source = source
	local Passport = vRP.Passport(Source)
	ClearFlip(Source,"player_dropped")
	RequestLimits[Source] = nil
	if Passport then FlipCooldowns[Passport] = nil end
end)
