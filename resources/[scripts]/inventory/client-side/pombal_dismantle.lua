local Tunnel = module("vrp","lib/Tunnel")
local vSERVER = Tunnel.getInterface("inventory_pombal_chopshop")

local StartZone = "PombalChopshop:Start"
local StageZone = "PombalChopshop:Stage"
local StartRegistered = false
local HasAccess = false
local CurrentSession = nil
local CurrentVehicle = 0
local CurrentStage = nil
local StageBusy = false
local StageRequestPending = false
local DebugEnabled = false
local DebugStatus = {}
local PreviousVehicleState = nil
local LegacyDebugCenter = vector3(2546.44,2582.97,37.95)

local function notify(message,color)
    TriggerEvent("Notify","Desmanche do Pombal",message,color or "amarelo",5000)
end

local function helpText(text)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0,false,true,-1)
end

local CandidateMessages = {
    heading = "Alinhe o veiculo com a vaga antes de iniciar.",
    moving = "Pare completamente o veiculo antes de iniciar.",
    occupied_vehicle = "Todos precisam sair do veiculo antes do desmanche.",
    not_stolen = "Este veiculo nao possui um registro valido de furto.",
    invalid_model = "Este veiculo nao pode ser desmanchado.",
    invalid_network = "Este veiculo nao pode ser desmanchado.",
    vehicle_in_use = "Este veiculo ja esta vinculado a outro desmanche."
}

local SessionEndMessages = {
    player_left_vehicle = "Aproxime-se do veiculo para continuar o desmanche.",
    vehicle_left_bay = "O veiculo saiu da vaga de desmanche.",
    permission_lost = "Sua permissao para este desmanche foi removida.",
    player_dead = "O desmanche foi cancelado porque voce ficou incapacitado.",
    session_expired = "O tempo limite do desmanche foi atingido."
}

local function candidateFailureMessage(bays)
    for _,reason in ipairs({ "not_stolen", "occupied_vehicle", "moving", "heading", "vehicle_in_use", "invalid_model", "invalid_network" }) do
        for _,bay in ipairs(bays or {}) do
            if bay.Reason == reason then return CandidateMessages[reason] end
        end
    end
    return "Posicione o veiculo corretamente em uma das vagas de desmanche."
end

local function drawText3D(coords,text)
    SetDrawOrigin(coords.x,coords.y,coords.z,0)
    SetTextFont(0)
    SetTextScale(0.0,0.28)
    SetTextCentre(true)
    SetTextColour(255,255,255,230)
    SetTextOutline()
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0,0.0)
    ClearDrawOrigin()
end

local function bayConfig(bayId)
    for _,bay in ipairs(PombalChopshop.Bays) do
        if bay.Id == bayId then return bay end
    end
end

local function stageConfig(stageId)
    for index,stage in ipairs(PombalChopshop.Stages) do
        if stage.Id == stageId then return stage,index end
    end
end

local function requestControl(entity,timeoutMs)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    local timeout = GetGameTimer() + (timeoutMs or 2000)
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < timeout do
        NetworkRequestControlOfEntity(entity)
        Wait(50)
    end
    return NetworkHasControlOfEntity(entity)
end

local function removeStageTarget()
    if GetResourceState("target") == "started" then
        exports.target:RemCircleZone(StageZone)
    end
end

local function stageCoords(vehicle,stage)
    local bone = GetEntityBoneIndexByName(vehicle,stage.Bone)
    if bone and bone ~= -1 then
        return GetWorldPositionOfEntityBone(vehicle,bone)
    end
    return GetOffsetFromEntityInWorldCoords(vehicle,stage.FallbackOffset.x,stage.FallbackOffset.y,stage.FallbackOffset.z)
end

local function createStageTarget(stageIndex)
    removeStageTarget()
    if not CurrentSession or not DoesEntityExist(CurrentVehicle) then return end

    local stage = PombalChopshop.Stages[stageIndex]
    if not stage then return end
    CurrentStage = stage
    StageRequestPending = false

    local coords = stageCoords(CurrentVehicle,stage)
    exports.target:AddCircleZone(StageZone,coords,0.55,{
        name = StageZone,
        useZ = false
    },{
        Distance = 1.5,
        options = {
            {
                event = "pombalDismantle:BeginCurrentStage",
                label = stage.Label,
                tunnel = "client"
            }
        }
    })
end

local function restoreVehicle(network)
    local vehicle = NetworkGetEntityFromNetworkId(tonumber(network) or 0)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end
    if not requestControl(vehicle,1000) then return end

    SetVehicleHandbrake(vehicle,false)
    SetVehicleUndriveable(vehicle,false)
    FreezeEntityPosition(vehicle,false)
    SetVehicleDoorsLockedForAllPlayers(vehicle,false)
    SetVehicleDoorsLocked(vehicle,PreviousVehicleState and PreviousVehicleState.LockStatus or 1)
    if PreviousVehicleState and PreviousVehicleState.EngineRunning then
        SetVehicleEngineOn(vehicle,true,true,false)
    end
end

local function clearSession(completed)
    removeStageTarget()
    ClearPedTasks(PlayerPedId())
    if CurrentSession and not completed then restoreVehicle(CurrentSession.VehicleNet) end
    CurrentSession = nil
    CurrentVehicle = 0
    CurrentStage = nil
    StageBusy = false
    StageRequestPending = false
    PreviousVehicleState = nil
end

local function lockVehicle(vehicle,bay)
    if not requestControl(vehicle,2500) then return false end

    PreviousVehicleState = {
        LockStatus = GetVehicleDoorLockStatus(vehicle),
        EngineRunning = GetIsVehicleEngineRunning(vehicle)
    }

    local current = GetEntityCoords(vehicle)
    local horizontal = #(vector2(current.x,current.y) - vector2(bay.VehicleCoords.x,bay.VehicleCoords.y))
    if PombalChopshop.Alignment.Enabled and horizontal <= PombalChopshop.Alignment.MaximumSnapDistance then
        SetEntityCoordsNoOffset(vehicle,bay.VehicleCoords.x,bay.VehicleCoords.y,bay.VehicleCoords.z,false,false,false)
        SetVehicleOnGroundProperly(vehicle)
    end

    SetEntityHeading(vehicle,bay.VehicleCoords.w)
    SetEntityVelocity(vehicle,0.0,0.0,0.0)
    SetVehicleHandbrake(vehicle,true)
    SetVehicleUndriveable(vehicle,true)
    SetVehicleEngineOn(vehicle,false,true,true)
    SetVehicleDoorsLockedForAllPlayers(vehicle,true)
    SetVehicleDoorsLocked(vehicle,2)
    return true
end

local function registerStartTarget()
    if StartRegistered or not HasAccess or GetResourceState("target") ~= "started" then return end
    local point = PombalChopshop.Interaction
    exports.target:AddCircleZone(StartZone,vector3(point.x,point.y,point.z),PombalChopshop.InteractionRadius,{
        name = StartZone,
        heading = point.w,
        useZ = false
    },{
        Distance = PombalChopshop.InteractionDistance,
        options = {
            { event = "pombalDismantle:Open", label = "Iniciar desmanche", tunnel = "client" },
            { event = "pombalDismantle:CancelCurrent", label = "Cancelar desmanche", tunnel = "client" }
        }
    })
    StartRegistered = true
end

local function removeStartTarget()
    if StartRegistered and GetResourceState("target") == "started" then
        exports.target:RemCircleZone(StartZone)
    end
    StartRegistered = false
end

local function selectBay(bayId)
    TriggerServerEvent("pombalDismantle:Start",bayId)
end

RegisterNetEvent("pombalDismantle:Open",function()
    local result = vSERVER.Candidates()
    if not result or not result.Success then
        notify(result and result.Reason == "interaction_distance" and "Aproxime-se do ponto de controle." or "Voce nao pode utilizar este desmanche.","vermelho")
        return
    end
    if result.Active then
        notify("Voce ja possui um desmanche em andamento.")
        return
    end

    local available = {}
    for _,bay in ipairs(result.Bays or {}) do
        if bay.Available then available[#available + 1] = bay end
    end

    if #available == 0 then
        local allOccupied = #(result.Bays or {}) > 0
        for _,bay in ipairs(result.Bays or {}) do allOccupied = allOccupied and bay.Occupied end
        notify(allOccupied and "As vagas disponiveis ja estao sendo utilizadas." or candidateFailureMessage(result.Bays))
    elseif #available == 1 then
        selectBay(available[1].Id)
    else
        for _,bay in ipairs(available) do
            exports.dynamic:AddButton(bay.Label,("%s - placa %s"):format(bay.Vehicle or "Veiculo",bay.Plate or ""),"pombalDismantle:SelectBay",bay.Id,false,false)
        end
        exports.dynamic:Open()
    end
end)

RegisterNetEvent("pombalDismantle:SelectBay",function(bayId)
    TriggerEvent("dynamic:Close")
    selectBay(bayId)
end)

RegisterNetEvent("pombalDismantle:CancelCurrent",function()
    TriggerServerEvent("pombalDismantle:Cancel")
end)

RegisterNetEvent("pombalDismantle:SessionStarted",function(data)
    local vehicle = 0
    local timeout = GetGameTimer() + 5000
    while vehicle == 0 and GetGameTimer() < timeout do
        vehicle = NetworkGetEntityFromNetworkId(data.VehicleNet)
        Wait(50)
    end
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        TriggerServerEvent("pombalDismantle:Cancel")
        notify("Nao foi possivel acessar o veiculo da vaga.","vermelho")
        return
    end

    local bay = bayConfig(data.BayId)
    if not bay or not lockVehicle(vehicle,bay) then
        TriggerServerEvent("pombalDismantle:Cancel")
        notify("Nao foi possivel travar o veiculo para o desmanche.","vermelho")
        return
    end

    CurrentSession = data
    CurrentVehicle = vehicle
    createStageTarget(data.Stage or 1)
    notify("A primeira peca esta marcada em vermelho. Aproxime-se e pressione E.","verde")
end)

RegisterNetEvent("pombalDismantle:BeginCurrentStage",function()
    if not CurrentSession or not CurrentStage or StageBusy or StageRequestPending then return end
    StageRequestPending = true
    TriggerServerEvent("pombalDismantle:BeginStage",CurrentStage.Id)
    SetTimeout(2000,function()
        if not StageBusy then StageRequestPending = false end
    end)
end)

RegisterNetEvent("pombalDismantle:PerformStage",function(stageId,duration)
    if not CurrentSession or not CurrentStage or CurrentStage.Id ~= stageId or StageBusy then return end
    StageRequestPending = false
    StageBusy = true
    removeStageTarget()

    local ped = PlayerPedId()
    local animation = PombalChopshop.Animation
    RequestAnimDict(animation.Dictionary)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(animation.Dictionary) and GetGameTimer() < timeout do Wait(50) end

    if not HasAnimDictLoaded(animation.Dictionary) then
        StageBusy = false
        TriggerServerEvent("pombalDismantle:AbortStage",stageId)
        notify("Nao foi possivel carregar a animacao desta etapa.","vermelho")
        return
    end

    TaskTurnPedToFaceEntity(ped,CurrentVehicle,500)
    Wait(500)
    TriggerEvent("Progress",CurrentStage.Label,duration)
    TaskPlayAnim(ped,animation.Dictionary,animation.Name,4.0,4.0,duration,49,0.0,false,false,false)
    Wait(duration)
    StopAnimTask(ped,animation.Dictionary,animation.Name,1.0)
    RemoveAnimDict(animation.Dictionary)
    StageBusy = false
    TriggerServerEvent("pombalDismantle:CompleteStage",stageId)
end)

CreateThread(function()
    while true do
        local sleep = 1000
        if CurrentSession and CurrentStage and not StageBusy and DoesEntityExist(CurrentVehicle) then
            local coords = stageCoords(CurrentVehicle,CurrentStage)
            local distance = #(GetEntityCoords(PlayerPedId()) - coords)
            if distance <= 25.0 then
                sleep = 0
                DrawMarker(20,coords.x,coords.y,coords.z + 0.35,0.0,0.0,0.0,0.0,180.0,0.0,0.32,0.32,0.32,225,35,45,220,true,true,2,false,nil,nil,false)
                drawText3D(vector3(coords.x,coords.y,coords.z + 0.62),CurrentStage.Label)

                if distance <= 2.0 then
                    helpText(("Pressione ~INPUT_CONTEXT~ para ~r~%s"):format(CurrentStage.Label:lower()))
                    if distance <= 1.6 and (IsControlJustPressed(0,38) or IsDisabledControlJustPressed(0,38)) then
                        TriggerEvent("pombalDismantle:BeginCurrentStage")
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

RegisterNetEvent("pombalDismantle:NextStage",function(stageIndex)
    if CurrentSession then
        CurrentSession.Stage = stageIndex
        createStageTarget(stageIndex)
    end
end)

RegisterNetEvent("pombalDismantle:ApplyStage",function(network,stageId)
    local vehicle = NetworkGetEntityFromNetworkId(tonumber(network) or 0)
    local stage = stageConfig(stageId)
    if vehicle == 0 or not DoesEntityExist(vehicle) or not stage then return end
    if not requestControl(vehicle,750) then return end

    if stage.Type == "wheel" then
        if BreakOffVehicleWheel then
            BreakOffVehicleWheel(vehicle,stage.Index,true,false,true,false)
        else
            SetVehicleTyreBurst(vehicle,stage.Index,true,1000.0)
        end
    elseif stage.Type == "door" then
        SetVehicleDoorBroken(vehicle,stage.Index,true)
    elseif stage.Type == "engine" then
        SetVehicleEngineOn(vehicle,false,true,true)
        SetVehicleEngineHealth(vehicle,100.0)
    end
end)

RegisterNetEvent("pombalDismantle:RestoreVehicle",function(network)
    restoreVehicle(network)
end)

RegisterNetEvent("pombalDismantle:SessionEnded",function(reason,completed)
    clearSession(completed == true)
    if not completed and reason ~= "cancelled" then
        notify(SessionEndMessages[reason] or ("O desmanche foi encerrado: "..tostring(reason).."."))
    end
end)

RegisterCommand("desmanche_debug",function()
    if not PombalChopshop.Debug or not HasAccess then return end
    DebugEnabled = not DebugEnabled
    local status = vSERVER.DebugStatus()
    DebugStatus = {}
    for _,bay in ipairs(status or {}) do
        DebugStatus[bay.Id] = bay
        print(("[POMBAL CHOPSHOP] %s distance=%.2f heading_difference=%.2f speed=%.2f occupied=%s vehicle=%s"):format(bay.Id,tonumber(bay.Distance) or -1,tonumber(bay.HeadingDifference) or -1,tonumber(bay.Speed) or -1,tostring(bay.Occupied),tostring(bay.Vehicle)))
    end
end,false)

local function entityDebugLine(kind,entity)
    local coords = GetEntityCoords(entity)
    local networked = NetworkGetEntityIsNetworked(entity)
    local dimensionsMin,dimensionsMax = GetModelDimensions(GetEntityModel(entity))
    print(("[LEGACY DEBUG] kind=%s entity=%s model=%s coords=%.3f,%.3f,%.3f heading=%.2f distance=%.2f networked=%s network=%s mission=%s frozen=%s dimensions=%.2f,%.2f,%.2f"):format(
        kind,entity,GetEntityModel(entity),coords.x,coords.y,coords.z,GetEntityHeading(entity),#(coords - LegacyDebugCenter),
        tostring(networked),networked and NetworkGetNetworkIdFromEntity(entity) or 0,tostring(IsEntityAMissionEntity(entity)),
        tostring(IsEntityPositionFrozen(entity)),dimensionsMax.x - dimensionsMin.x,dimensionsMax.y - dimensionsMin.y,dimensionsMax.z - dimensionsMin.z
    ))
end

RegisterCommand("local_entities_debug",function()
    if not vSERVER.LegacyDebugAccess() then return end
    print("[LEGACY DEBUG] entities_begin center=2546.44,2582.97,37.95 radius=15.0")
    for _,pool in ipairs({ { "ped", "CPed" }, { "object", "CObject" }, { "vehicle", "CVehicle" } }) do
        for _,entity in ipairs(GetGamePool(pool[2])) do
            if DoesEntityExist(entity) and #(GetEntityCoords(entity) - LegacyDebugCenter) <= 15.0 then
                entityDebugLine(pool[1],entity)
            end
        end
    end
    print("[LEGACY DEBUG] entities_end")
end,false)

RegisterCommand("legacy_gate_debug",function()
    if not vSERVER.LegacyDebugAccess() then return end
    print("[LEGACY GATE DEBUG] candidates_begin center=2546.44,2582.97,37.95 radius=15.0")
    for _,entity in ipairs(GetGamePool("CObject")) do
        if DoesEntityExist(entity) and #(GetEntityCoords(entity) - LegacyDebugCenter) <= 15.0 then
            entityDebugLine("gate_candidate",entity)
        end
    end
    print("[LEGACY GATE DEBUG] candidates_end")
end,false)

CreateThread(function()
    while true do
        local access = vSERVER.Access() == true
        if access ~= HasAccess then
            HasAccess = access
            if HasAccess then registerStartTarget() else removeStartTarget() end
        elseif HasAccess and not StartRegistered then
            registerStartTarget()
        end
        Wait(15000)
    end
end)

CreateThread(function()
    while true do
        if DebugEnabled then
            local status = vSERVER.DebugStatus()
            DebugStatus = {}
            for _,bay in ipairs(status or {}) do DebugStatus[bay.Id] = bay end
            Wait(1000)
        else
            Wait(1000)
        end
    end
end)

CreateThread(function()
    while true do
        if DebugEnabled then
            local interaction = PombalChopshop.Interaction
            DrawMarker(1,interaction.x,interaction.y,interaction.z - 1.0,0.0,0.0,0.0,0.0,0.0,0.0,0.45,0.45,0.25,255,220,50,120,false,false,2,false,nil,nil,false)
            local interactionHeading = math.rad(interaction.w)
            DrawLine(interaction.x,interaction.y,interaction.z,interaction.x - math.sin(interactionHeading) * 1.5,interaction.y + math.cos(interactionHeading) * 1.5,interaction.z,255,220,50,220)
            drawText3D(vector3(interaction.x,interaction.y,interaction.z + 0.35),"Pombal - controle")
            for _,bay in ipairs(PombalChopshop.Bays) do
                local coords = bay.VehicleCoords
                local status = DebugStatus[bay.Id]
                local red = status and status.Occupied and 230 or 50
                local green = status and status.Occupied and 70 or 220
                DrawMarker(1,coords.x,coords.y,coords.z - 1.0,0.0,0.0,0.0,0.0,0.0,0.0,bay.MaximumParkingDistance * 2.0,bay.MaximumParkingDistance * 2.0,0.12,red,green,100,80,false,false,2,false,nil,nil,false)
                local heading = math.rad(coords.w)
                local lineX = coords.x - math.sin(heading) * 2.5
                local lineY = coords.y + math.cos(heading) * 2.5
                DrawLine(coords.x,coords.y,coords.z + 0.05,lineX,lineY,coords.z + 0.05,255,90,70,220)
                drawText3D(vector3(coords.x,coords.y,coords.z + 0.45),("%s | %s"):format(bay.Label,status and (status.Occupied and "ocupada" or "livre") or "consultando"))
            end
            Wait(0)
        else
            Wait(1000)
        end
    end
end)

AddEventHandler("onClientResourceStart",function(resourceName)
    if resourceName == "target" and HasAccess then
        StartRegistered = false
        registerStartTarget()
    end
end)

AddEventHandler("onResourceStop",function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    removeStartTarget()
    clearSession(false)
end)
