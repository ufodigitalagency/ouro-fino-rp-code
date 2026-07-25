local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")
local vRP = Proxy.getInterface("vRP")

local API = {}
Tunnel.bindInterface("inventory_pombal_chopshop",API)

local ChopshopBays = {}
local BayLocks = {}
local PassportSessions = {}
local VehicleSessions = {}
local RequestLimits = {}
local VehicleNamesByHash = {}

local function canUseChopshop(Passport)
    return Passport and GetResourceState("pombal_finance") == "started" and exports.pombal_finance:CanChopshop(Passport) or false
end

for name in pairs(exports.vrp:VehicleList()) do
    VehicleNamesByHash[GetHashKey(name)] = name
end

for _,bay in ipairs(PombalChopshop.Bays) do
    ChopshopBays[bay.Id] = {
        Occupied = false,
        SessionId = nil,
        VehicleNet = nil,
        Passport = nil,
        StartedAt = nil
    }
end

local function notify(source,message,color)
    if source and GetPlayerName(source) then
        TriggerClientEvent("Notify",source,"Desmanche do Pombal",message,color or "amarelo",5000)
    end
end

local function debugLog(message)
    if PombalChopshop.Debug then
        print("[pombal/chopshop] "..message)
    end
end

local function normalizePlate(plate)
    return tostring(plate or ""):gsub("%s+",""):upper()
end

local function headingDifference(first,second)
    local difference = math.abs((first - second) % 360.0)
    return math.min(difference,360.0 - difference)
end

local function horizontalDistance(first,second)
    local x = first.x - second.x
    local y = first.y - second.y
    return math.sqrt((x * x) + (y * y))
end

local function vehicleIsEmpty(vehicle)
    local success,maximum = pcall(GetVehicleMaxNumberOfPassengers,vehicle)
    maximum = success and math.max(0,tonumber(maximum) or 0) or 12
    for seat = -1,maximum - 1 do
        if GetPedInVehicleSeat(vehicle,seat) ~= 0 then
            return false
        end
    end
    return true
end

local function rateAllowed(source,key,interval)
    local id = tostring(source)..":"..key
    local now = GetGameTimer()
    if now < (RequestLimits[id] or 0) then return false end
    RequestLimits[id] = now + interval
    return true
end

local function playerContext(source,requireInteraction)
    local Passport = vRP.Passport(source)
    if not Passport or not PombalChopshop.Enabled then
        return nil,"invalid_passport"
    end
    if not canUseChopshop(Passport) then
        return nil,"permission"
    end

    local ped = GetPlayerPed(source)
    if ped <= 0 or not DoesEntityExist(ped) or GetEntityHealth(ped) <= 100 then
        return nil,"invalid_player"
    end
    if GetPlayerRoutingBucket(source) ~= 0 then
        return nil,"routing_bucket"
    end

    if requireInteraction then
        local coords = GetEntityCoords(ped)
        local interaction = PombalChopshop.Interaction
        if #(coords - vector3(interaction.x,interaction.y,interaction.z)) > PombalChopshop.ServerInteractionDistance then
            return nil,"interaction_distance"
        end
    end

    return Passport,nil
end

local function bayConfig(bayId)
    for _,bay in ipairs(PombalChopshop.Bays) do
        if bay.Id == bayId then return bay end
    end
end

local function nearestVehicleForBay(source,bay)
    local target = bay.VehicleCoords
    local bestVehicle,bestDistance = nil,math.huge
    for _,vehicle in ipairs(GetAllVehicles()) do
        if DoesEntityExist(vehicle) and GetEntityType(vehicle) == 2 and GetEntityRoutingBucket(vehicle) == GetPlayerRoutingBucket(source) then
            local coords = GetEntityCoords(vehicle)
            local horizontal = horizontalDistance(coords,target)
            local vertical = math.abs(coords.z - target.z)
            if horizontal <= bay.MaximumParkingDistance and vertical <= bay.MaximumVerticalDifference and horizontal < bestDistance then
                bestVehicle,bestDistance = vehicle,horizontal
            end
        end
    end

    if not bestVehicle then return nil,nil end
    local coords = GetEntityCoords(bestVehicle)
    return bestVehicle,{
        Distance = bestDistance,
        VerticalDifference = math.abs(coords.z - target.z),
        HeadingDifference = headingDifference(GetEntityHeading(bestVehicle),target.w),
        Speed = GetEntitySpeed(bestVehicle)
    }
end


local function eligibleVehicleForBay(source,bay,Passport)
    local state = ChopshopBays[bay.Id]
    if not state or state.Occupied then return nil,"occupied",nil end

    local bestVehicle,metrics = nearestVehicleForBay(source,bay)

    if not bestVehicle then return nil,"vehicle_not_in_bay",nil end
    if metrics.Speed > bay.MaximumVehicleSpeed then return nil,"moving",metrics end
    if metrics.HeadingDifference > bay.MaximumHeadingDifference then return nil,"heading",metrics end
    if not vehicleIsEmpty(bestVehicle) then return nil,"occupied_vehicle",metrics end

    local network = NetworkGetNetworkIdFromEntity(bestVehicle)
    if not network or network <= 0 then return nil,"invalid_network",metrics end
    if VehicleSessions[network] then return nil,"vehicle_in_use",metrics end

    local model = VehicleNamesByHash[GetEntityModel(bestVehicle)]
    if not model or not exports.vrp:VehicleExist(model) then return nil,"invalid_model",metrics end

    local plate = normalizePlate(GetVehicleNumberPlateText(bestVehicle))
    local userVehicle = vRP.PassportPlate(plate)
    local lockpickOwner = tonumber(Entity(bestVehicle).state.Lockpick)
    local missionOwner = tonumber(Dismantle[plate])
    local stolenByPlayer = lockpickOwner ~= nil and lockpickOwner == tonumber(Passport)
    local assignedMission = missionOwner ~= nil and missionOwner == tonumber(source)
    metrics.LockpickOwner = lockpickOwner
    metrics.StolenByPlayer = stolenByPlayer
    metrics.AssignedMission = assignedMission

    if not userVehicle and not stolenByPlayer and not assignedMission then
        return nil,"not_stolen",metrics
    end

    return {
        Entity = bestVehicle,
        Network = network,
        Plate = plate,
        Model = model,
        UserVehicle = userVehicle and true or false,
        Distance = metrics.Distance,
        HeadingDifference = metrics.HeadingDifference,
        StolenByPlayer = stolenByPlayer,
        AssignedMission = assignedMission
    },nil,metrics
end

local function publicCandidates(source,Passport)
    local candidates = {}
    for _,bay in ipairs(PombalChopshop.Bays) do
        local vehicle,reason,metrics = eligibleVehicleForBay(source,bay,Passport)
        debugLog(("candidate source=%s passport=%s bay=%s vehicleBayDistance=%.2f verticalDifference=%.2f headingDifference=%.2f speed=%.2f occupied=%s stolenRecord=%s eligible=%s reason=%s"):format(
            source,Passport,bay.Id,metrics and metrics.Distance or -1,metrics and metrics.VerticalDifference or -1,
            metrics and metrics.HeadingDifference or -1,metrics and metrics.Speed or -1,tostring(ChopshopBays[bay.Id].Occupied),
            tostring(metrics and (metrics.StolenByPlayer or metrics.AssignedMission) or false),tostring(vehicle ~= nil),tostring(reason or "accepted")
        ))
        candidates[#candidates + 1] = {
            Id = bay.Id,
            Label = bay.Label,
            Available = vehicle ~= nil,
            Occupied = ChopshopBays[bay.Id].Occupied,
            Vehicle = vehicle and exports.vrp:VehicleName(vehicle.Model) or nil,
            Plate = vehicle and vehicle.Plate or nil,
            Reason = reason
        }
    end
    return candidates
end

function ReleaseChopshopBay(bayId,reason,completed)
    BayLocks[bayId] = nil

    local bayState = ChopshopBays[bayId]
    if not bayState or not bayState.Occupied then return false end

    local Passport = bayState.Passport
    local network = bayState.VehicleNet
    local source = Passport and vRP.Source(Passport) or nil
    local session = Passport and PassportSessions[Passport] or nil

    if not completed and session and session.CreatedDismantleRecord and Dismantle[session.Plate] == session.Source then
        Dismantle[session.Plate] = nil
    end

    PassportSessions[Passport] = nil
    VehicleSessions[network] = nil
    ChopshopBays[bayId] = {
        Occupied = false,
        SessionId = nil,
        VehicleNet = nil,
        Passport = nil,
        StartedAt = nil
    }

    local vehicle = network and NetworkGetEntityFromNetworkId(network) or 0
    if vehicle > 0 and DoesEntityExist(vehicle) then
        Entity(vehicle).state:set("of:chopshopBay",nil,true)
        Entity(vehicle).state:set("of:chopshopOwner",nil,true)
        Entity(vehicle).state:set("of:chopshopActive",false,true)
    end

    if not completed and network then
        TriggerClientEvent("pombalDismantle:RestoreVehicle",-1,network)
    end
    if source then
        TriggerClientEvent("pombalDismantle:SessionEnded",source,reason,completed == true)
    end

    debugLog(("release bay=%s passport=%s network=%s reason=%s completed=%s"):format(bayId,tostring(Passport),tostring(network),tostring(reason),tostring(completed == true)))
    return true
end

function API.Access()
    local Passport = vRP.Passport(source)
    return PombalChopshop.Enabled and canUseChopshop(Passport)
end

function API.Candidates()
    local playerSource = source
    local Passport,reason = playerContext(playerSource,true)
    if not Passport then return { Success = false, Reason = reason, Bays = {} } end
    return { Success = true, Active = PassportSessions[Passport] ~= nil, Bays = publicCandidates(playerSource,Passport) }
end

function API.LegacyDebugAccess()
    if not PombalChopshop.Debug then return false end
    return vRP.Passport(source) == 1
end

function API.DebugStatus()
    if not PombalChopshop.Debug then return {} end
    local Passport = vRP.Passport(source)
    if not Passport or not canUseChopshop(Passport) then return {} end

    local status = {}
    for _,bay in ipairs(PombalChopshop.Bays) do
        local entity,metrics = nearestVehicleForBay(source,bay)
        status[#status + 1] = {
            Id = bay.Id,
            Occupied = ChopshopBays[bay.Id].Occupied,
            Vehicle = entity and NetworkGetNetworkIdFromEntity(entity) or 0,
            Distance = metrics and metrics.Distance or -1,
            HeadingDifference = metrics and metrics.HeadingDifference or -1,
            Speed = metrics and metrics.Speed or -1
        }
    end
    return status
end

RegisterNetEvent("pombalDismantle:Start",function(bayId)
    local source = source
    if not rateAllowed(source,"start",1500) then return end

    local Passport,reason = playerContext(source,true)
    if not Passport then
        notify(source,reason == "interaction_distance" and "Aproxime-se do ponto de controle." or "Voce nao pode iniciar o desmanche neste local.","vermelho")
        return
    end
    if PassportSessions[Passport] or Active[Passport] then notify(source,"Voce ja possui um desmanche em andamento.") return end

    local bay = bayConfig(tostring(bayId or ""))
    if not bay then notify(source,"Vaga invalida.","vermelho") return end
    if ChopshopBays[bay.Id].Occupied or BayLocks[bay.Id] then notify(source,"Esta vaga ja esta sendo utilizada.") return end

    BayLocks[bay.Id] = true

    local validationOk,vehicle,vehicleReason,metrics = pcall(eligibleVehicleForBay,source,bay,Passport)
    if not validationOk then
        BayLocks[bay.Id] = nil
        debugLog(("start_validation_error bay=%s passport=%s error=%s"):format(bay.Id,Passport,tostring(vehicle)))
        notify(source,"Nao foi possivel validar o veiculo desta vaga.","vermelho")
        return
    end
    if not vehicle then
        BayLocks[bay.Id] = nil
        if vehicleReason == "occupied" then
            notify(source,"Esta vaga ja esta sendo utilizada.")
        elseif vehicleReason == "heading" then
            notify(source,"Alinhe o veiculo com a vaga antes de iniciar.")
        elseif vehicleReason == "moving" then
            notify(source,"Pare completamente o veiculo antes de iniciar.")
        elseif vehicleReason == "occupied_vehicle" then
            notify(source,"Todos precisam sair do veiculo antes do desmanche.")
        elseif vehicleReason == "not_eligible" then
            notify(source,"Este veiculo nao pertence a uma rota de desmanche valida.","vermelho")
        elseif vehicleReason == "not_stolen" then
            notify(source,"Este veiculo nao possui um registro valido de furto.","vermelho")
        elseif vehicleReason == "invalid_model" or vehicleReason == "invalid_network" then
            notify(source,"Este veiculo nao pode ser desmanchado.","vermelho")
        elseif vehicleReason == "vehicle_in_use" then
            notify(source,"Este veiculo ja esta vinculado a outro desmanche.")
        else
            notify(source,"Posicione o veiculo corretamente em uma das vagas de desmanche.")
        end
        local ped = GetPlayerPed(source)
        local interaction = PombalChopshop.Interaction
        local playerDistance = ped > 0 and #(GetEntityCoords(ped) - vector3(interaction.x,interaction.y,interaction.z)) or -1
        debugLog(("request source=%s passport=%s bay=%s playerInteractionDistance=%.2f vehicleBayDistance=%.2f verticalDifference=%.2f headingDifference=%.2f speed=%.2f occupied=%s stolenRecord=%s eligible=false reason=%s"):format(
            source,Passport,bay.Id,playerDistance,metrics and metrics.Distance or -1,metrics and metrics.VerticalDifference or -1,
            metrics and metrics.HeadingDifference or -1,metrics and metrics.Speed or -1,tostring(ChopshopBays[bay.Id].Occupied),
            tostring(metrics and (metrics.StolenByPlayer or metrics.AssignedMission) or false),tostring(vehicleReason)
        ))
        return
    end

    if PassportSessions[Passport] or VehicleSessions[vehicle.Network] or ChopshopBays[bay.Id].Occupied then
        BayLocks[bay.Id] = nil
        notify(source,"A vaga ou o veiculo acabou de ser reservado por outro jogador.")
        return
    end

    local sessionId = GenerateString("DDLLDDLL")
    local now = os.time()
    local createdDismantleRecord = false
    if vehicle.StolenByPlayer and not Dismantle[vehicle.Plate] then
        Dismantle[vehicle.Plate] = source
        createdDismantleRecord = true
    end
    local session = {
        Id = sessionId,
        BayId = bay.Id,
        Source = source,
        Passport = Passport,
        Vehicle = vehicle.Entity,
        VehicleNet = vehicle.Network,
        Plate = vehicle.Plate,
        Model = vehicle.Model,
        UserVehicle = vehicle.UserVehicle,
        CreatedDismantleRecord = createdDismantleRecord,
        Stage = 1,
        StageStartedAt = nil,
        StageInProgress = false,
        StartedAt = now,
        LastActivity = now
    }

    ChopshopBays[bay.Id] = {
        Occupied = true,
        SessionId = sessionId,
        VehicleNet = vehicle.Network,
        Passport = Passport,
        StartedAt = now
    }
    PassportSessions[Passport] = session
    VehicleSessions[vehicle.Network] = session
    BayLocks[bay.Id] = nil

    Entity(vehicle.Entity).state:set("of:chopshopBay",bay.Id,true)
    Entity(vehicle.Entity).state:set("of:chopshopOwner",Passport,true)
    Entity(vehicle.Entity).state:set("of:chopshopActive",true,true)

    local ped = GetPlayerPed(source)
    local interaction = PombalChopshop.Interaction
    local playerDistance = ped > 0 and #(GetEntityCoords(ped) - vector3(interaction.x,interaction.y,interaction.z)) or -1
    debugLog(("request source=%s passport=%s bay=%s playerInteractionDistance=%.2f vehicleBayDistance=%.2f verticalDifference=%.2f headingDifference=%.2f speed=%.2f occupied=false stolenRecord=%s eligible=true reason=accepted"):format(
        source,Passport,bay.Id,playerDistance,vehicle.Distance or -1,metrics and metrics.VerticalDifference or -1,
        vehicle.HeadingDifference or -1,metrics and metrics.Speed or -1,tostring(vehicle.StolenByPlayer or vehicle.AssignedMission)
    ))

    TriggerClientEvent("pombalDismantle:SessionStarted",source,{
        BayId = bay.Id,
        SessionId = sessionId,
        VehicleNet = vehicle.Network,
        Stage = 1
    })
    notify(source,("%s reservada. Inicie a desmontagem pelas pecas indicadas."):format(bay.Label),"verde")
    debugLog(("start bay=%s session=%s passport=%s network=%s plate=%s"):format(bay.Id,sessionId,Passport,vehicle.Network,vehicle.Plate))
end)

RegisterNetEvent("pombalDismantle:BeginStage",function(stageId)
    local source = source
    if not rateAllowed(source,"stage",500) then return end
    local Passport = vRP.Passport(source)
    local session = Passport and PassportSessions[Passport] or nil
    local stage = session and PombalChopshop.Stages[session.Stage] or nil

    if not session or session.Source ~= source or not stage or stage.Id ~= stageId or session.StageInProgress then return end
    if not canUseChopshop(Passport) then ReleaseChopshopBay(session.BayId,"permission_lost",false) return end
    local ped = GetPlayerPed(source)
    if ped <= 0 or not DoesEntityExist(ped) or GetEntityHealth(ped) <= 100 then
        ReleaseChopshopBay(session.BayId,"invalid_player",false)
        return
    end
    if not DoesEntityExist(session.Vehicle) then
        ReleaseChopshopBay(session.BayId,"vehicle_missing",false)
        return
    end
    if GetPlayerRoutingBucket(source) ~= GetEntityRoutingBucket(session.Vehicle) then
        ReleaseChopshopBay(session.BayId,"routing_bucket_changed",false)
        return
    end
    if #(GetEntityCoords(ped) - GetEntityCoords(session.Vehicle)) > PombalChopshop.Session.StageServerDistance then
        notify(source,"Aproxime-se da peca indicada.")
        return
    end

    session.StageInProgress = true
    session.StageStartedAt = GetGameTimer()
    session.LastActivity = os.time()
    TriggerClientEvent("pombalDismantle:PerformStage",source,stage.Id,PombalChopshop.Session.StageDurationMs)
end)

RegisterNetEvent("pombalDismantle:CompleteStage",function(stageId)
    local source = source
    if not rateAllowed(source,"complete",500) then return end
    local Passport = vRP.Passport(source)
    local session = Passport and PassportSessions[Passport] or nil
    local stage = session and PombalChopshop.Stages[session.Stage] or nil
    if not session or session.Source ~= source or not stage or stage.Id ~= stageId or not session.StageInProgress then return end

    local elapsed = GetGameTimer() - (session.StageStartedAt or GetGameTimer())
    if elapsed < (PombalChopshop.Session.StageDurationMs - PombalChopshop.Session.StageCompletionToleranceMs) then
        debugLog(("early_stage passport=%s stage=%s elapsed=%s"):format(Passport,stageId,elapsed))
        session.StageInProgress = false
        session.StageStartedAt = nil
        TriggerClientEvent("pombalDismantle:NextStage",source,session.Stage)
        return
    end
    if not canUseChopshop(Passport) then
        ReleaseChopshopBay(session.BayId,"permission_lost",false)
        return
    end

    local ped = GetPlayerPed(source)
    if ped <= 0 or not DoesEntityExist(ped) or GetEntityHealth(ped) <= 100 then
        ReleaseChopshopBay(session.BayId,"invalid_player",false)
        return
    end
    if not DoesEntityExist(session.Vehicle) or GetPlayerRoutingBucket(source) ~= GetEntityRoutingBucket(session.Vehicle) then
        ReleaseChopshopBay(session.BayId,"vehicle_unavailable",false)
        return
    end
    if #(GetEntityCoords(ped) - GetEntityCoords(session.Vehicle)) > PombalChopshop.Session.StageServerDistance then
        session.StageInProgress = false
        session.StageStartedAt = nil
        TriggerClientEvent("pombalDismantle:NextStage",source,session.Stage)
        notify(source,"A etapa foi cancelada porque voce se afastou.")
        return
    end

    session.StageInProgress = false
    session.StageStartedAt = nil
    session.LastActivity = os.time()
    TriggerClientEvent("pombalDismantle:ApplyStage",-1,session.VehicleNet,stage.Id)
    session.Stage = session.Stage + 1

    if session.Stage <= #PombalChopshop.Stages then
        TriggerClientEvent("pombalDismantle:NextStage",source,session.Stage)
        return
    end

    local finished = FinishDismantle(source,Passport,session.VehicleNet,session.Plate,session.Model,session.UserVehicle,{
        Service = "chopshop",
        Reference = session.Id..":"..session.Plate
    })
    if finished then
        notify(source,"Veiculo desmanchado e materiais separados.","verde")
        ReleaseChopshopBay(session.BayId,"completed",true)
    else
        notify(source,"O veiculo deixou de ser elegivel antes da finalizacao.","vermelho")
        ReleaseChopshopBay(session.BayId,"finish_validation_failed",false)
    end
end)

RegisterNetEvent("pombalDismantle:AbortStage",function(stageId)
    local source = source
    local Passport = vRP.Passport(source)
    local session = Passport and PassportSessions[Passport] or nil
    local stage = session and PombalChopshop.Stages[session.Stage] or nil
    if not session or session.Source ~= source or not stage or stage.Id ~= stageId or not session.StageInProgress then return end

    session.StageInProgress = false
    session.StageStartedAt = nil
    session.LastActivity = os.time()
    TriggerClientEvent("pombalDismantle:NextStage",source,session.Stage)
    debugLog(("abort_stage passport=%s stage=%s"):format(Passport,stageId))
end)

RegisterNetEvent("pombalDismantle:Cancel",function()
    local source = source
    local Passport = vRP.Passport(source)
    local session = Passport and PassportSessions[Passport] or nil
    if session and session.Source == source then
        ReleaseChopshopBay(session.BayId,"cancelled",false)
        notify(source,"Desmanche cancelado.")
    end
end)

CreateThread(function()
    while true do
        local now = os.time()
        local releases = {}
        for Passport,session in pairs(PassportSessions) do
            local reason = nil
            local source = vRP.Source(Passport)
            if not source or source ~= session.Source then
                reason = "disconnected"
            elseif not canUseChopshop(Passport) then
                reason = "permission_lost"
            elseif not DoesEntityExist(session.Vehicle) then
                reason = "vehicle_missing"
            elseif now - session.StartedAt > PombalChopshop.Session.MaximumDurationSeconds then
                reason = "session_expired"
            else
                local ped = GetPlayerPed(source)
                if ped <= 0 or not DoesEntityExist(ped) or GetEntityHealth(ped) <= 100 then
                    reason = "player_dead"
                elseif GetPlayerRoutingBucket(source) ~= GetEntityRoutingBucket(session.Vehicle) then
                    reason = "routing_bucket_changed"
                else
                    local bay = bayConfig(session.BayId)
                    local vehicleCoords = GetEntityCoords(session.Vehicle)
                    if not bay then
                        reason = "bay_missing"
                    elseif horizontalDistance(vehicleCoords,bay.VehicleCoords) > PombalChopshop.Session.MaximumVehicleDriftDistance then
                        reason = "vehicle_left_bay"
                    elseif now - session.StartedAt > PombalChopshop.Session.StartProximityGraceSeconds and #(GetEntityCoords(ped) - vehicleCoords) > PombalChopshop.Session.PlayerVehicleDistance then
                        reason = "player_left_vehicle"
                    end
                end
            end

            if reason then releases[#releases + 1] = { BayId = session.BayId, Reason = reason } end
        end

        for _,release in ipairs(releases) do
            ReleaseChopshopBay(release.BayId,release.Reason,false)
        end
        Wait(PombalChopshop.Session.MonitorIntervalMs)
    end
end)

AddEventHandler("playerDropped",function()
    local Passport = vRP.Passport(source)
    local session = Passport and PassportSessions[Passport] or nil
    if session then ReleaseChopshopBay(session.BayId,"disconnected",false) end
end)

AddEventHandler("onResourceStop",function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    local occupied = {}
    for bayId,state in pairs(ChopshopBays) do
        if state.Occupied then occupied[#occupied + 1] = bayId end
    end
    for _,bayId in ipairs(occupied) do ReleaseChopshopBay(bayId,"resource_stop",false) end
end)
