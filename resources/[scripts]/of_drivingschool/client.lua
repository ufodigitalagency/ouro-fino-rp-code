local Tunnel = module("vrp","lib/Tunnel")
local vSERVER = Tunnel.getInterface("of_drivingschool")

local InstructorTarget = "OFCNH:Instructor"
local InstructorTargetRegistered = false
local NextInstructorTargetLogAt = 0
local InstructorSetupInProgress = {}
local InstructorConfiguredSetup = {}
local ActiveExam = nil
local StartBusy = false
local ResourceStopping = false
local ResultGeneration = 0
local RecordedRoutePoints = {}

local function notify(Message,Color,Duration)
    TriggerEvent("Notify","Autoescola",Message,Color or "amarelo",Duration or 5000)
end

local function debugLog(Message)
    if Config.Debug then
        print("[of_drivingschool] "..Message)
    end
end

local function boolText(Value)
    return Value and "true" or "false"
end

local function nativeBool(Value)
    if Value == true then
        return true
    end

    if type(Value) == "number" then
        return Value ~= 0
    end

    return false
end

local function readSeatbelt()
    if GetResourceState("hud") ~= "started" then
        return nil,"hud_unavailable"
    end

    local Success,State = pcall(function()
        return exports["hud"]:IsSeatbeltOn()
    end)

    if not Success then
        return nil,"hud_export_unavailable"
    end

    return State == true,nil
end

local function readVehicleState()
    local Ped = PlayerPedId()
    local Vehicle = GetVehiclePedIsIn(Ped,false)

    if Vehicle == 0 then
        return {
            InVehicle = false
        }
    end

    local _,LightsOn,HighBeamsOn = GetVehicleLightsState(Vehicle)
    local Seatbelt,SeatbeltError = readSeatbelt()

    return {
        InVehicle = true,
        Vehicle = Vehicle,
        IsDriver = GetPedInVehicleSeat(Vehicle,-1) == Ped,
        Seatbelt = Seatbelt,
        SeatbeltError = SeatbeltError,
        EngineOn = nativeBool(GetIsVehicleEngineRunning(Vehicle)),
        LightsOn = nativeBool(LightsOn) or nativeBool(HighBeamsOn),
        HighBeamsOn = nativeBool(HighBeamsOn),
        SpeedKmh = math.floor((GetEntitySpeed(Vehicle) * 3.6) + 0.5)
    }
end

local function routeCheckpoints()
    local Route = Config.Exam and Config.Exam.Route
    return Route and type(Route.Checkpoints) == "table" and Route.Checkpoints or {}
end

local function checkpointRadius(Point)
    return math.max(0.5,tonumber(Point and Point.Radius) or tonumber(Config.Exam.Route.DefaultRadius) or 6.0)
end

local function headingDifference(First,Second)
    local Difference = math.abs(((tonumber(First) or 0.0) - (tonumber(Second) or 0.0)) % 360.0)
    return math.min(Difference,360.0 - Difference)
end

local function clearExamDestination(Exam)
    local Blip = Exam and Exam.DestinationBlip
    if Blip and DoesBlipExist(Blip) then
        SetBlipRoute(Blip,false)
        RemoveBlip(Blip)
    end

    if Exam then
        Exam.DestinationBlip = nil
    end
end

local function setExamDestination(Exam,Coords,Label,BlipConfig)
    if not Exam or not Coords then
        return false
    end

    clearExamDestination(Exam)
    local Blip = AddBlipForCoord(Coords.x,Coords.y,Coords.z)
    if not Blip or Blip == 0 then
        return false
    end

    BlipConfig = BlipConfig or {}
    SetBlipSprite(Blip,tonumber(BlipConfig.Sprite) or 1)
    SetBlipColour(Blip,tonumber(BlipConfig.Color) or 5)
    SetBlipScale(Blip,tonumber(BlipConfig.Scale) or 0.85)
    SetBlipAsShortRange(Blip,false)
    SetBlipRoute(Blip,true)
    SetBlipRouteColour(Blip,tonumber(BlipConfig.RouteColor) or tonumber(BlipConfig.Color) or 5)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(tostring(Label or "Autoescola"))
    EndTextCommandSetBlipName(Blip)
    Exam.DestinationBlip = Blip
    return true
end

local function clearPracticalState(Exam)
    if not Exam then
        return
    end

    clearExamDestination(Exam)
    Exam.RouteIndex = nil
    Exam.RouteAdvancing = false
    Exam.RouteStarting = false
    Exam.RouteUnavailable = false
    Exam.NextRouteStartAt = nil
    Exam.ParkingStarting = false
    Exam.ParkingStartedAt = nil
    Exam.ParkingHoldStartedAt = nil
    Exam.UsedReverse = false
    Exam.ReversePending = false
    Exam.PassRequestPending = false
    Exam.NextPassRequestAt = nil
    Exam.LastParkingFeedback = nil
    Exam.LastParkingFeedbackAt = nil
    Exam.LastSeatbeltWarningAt = nil
end

local function loadModel(ModelName,TimeoutMs)
    local Model = type(ModelName) == "number" and ModelName or GetHashKey(ModelName)
    if not IsModelInCdimage(Model) or not IsModelValid(Model) then
        return nil
    end

    RequestModel(Model)
    local Timeout = GetGameTimer() + (tonumber(TimeoutMs) or 5000)
    while not HasModelLoaded(Model) and GetGameTimer() < Timeout do
        Wait(50)
    end

    return HasModelLoaded(Model) and Model or nil
end

local function acknowledgeInstructor(Network,Generation,Revision)
    TriggerServerEvent("of_drivingschool:InstructorConfigured",Network,Generation,Revision)
end

local function resolveInstructorPlacement(Ped,Coords)
    local TimeoutAt = GetGameTimer() + (tonumber(Config.Instructor.GroundResolveTimeoutMs) or 5000)
    local ProbeOffsets = { 1.0,5.0,20.0 }
    local GroundZ = nil
    local CollisionLoaded = false

    repeat
        RequestCollisionAtCoord(Coords.x,Coords.y,Coords.z)
        CollisionLoaded = HasCollisionLoadedAroundEntity(Ped)

        if CollisionLoaded then
            for _,Offset in ipairs(ProbeOffsets) do
                local Found,ResolvedZ = GetGroundZFor_3dCoord(Coords.x,Coords.y,Coords.z + Offset,false)
                if nativeBool(Found) then
                    GroundZ = ResolvedZ
                    break
                end
            end
        end

        if not GroundZ then
            Wait(100)
        end
    until GroundZ or ResourceStopping or GetGameTimer() >= TimeoutAt

    local GroundResolved = GroundZ ~= nil
    if not GroundResolved then
        GroundZ = tonumber(Config.Instructor.GroundFallbackZ) or Coords.z
        print(("[of_drivingschool] WARN instructor_ground_unresolved; using ground_fallback_z=%.4f"):format(GroundZ))
    end

    local ModelMinimum,ModelMaximum = GetModelDimensions(GetEntityModel(Ped))
    local MinimumZ = ModelMinimum and tonumber(ModelMinimum.z) or 0.0
    local MaximumZ = ModelMaximum and tonumber(ModelMaximum.z) or 0.0
    local FinalZ = GroundZ - MinimumZ + (tonumber(Config.Instructor.VisualZOffset) or 0.0)

    return {
        GroundZ = GroundZ,
        GroundResolved = GroundResolved,
        CollisionLoaded = CollisionLoaded,
        MinimumZ = MinimumZ,
        MaximumZ = MaximumZ,
        FinalZ = FinalZ
    }
end

local function configureNetworkedInstructor(Network,Generation,Revision,Reason)
    Network = math.floor(tonumber(Network) or 0)
    Generation = math.floor(tonumber(Generation) or 0)
    Revision = math.floor(tonumber(Revision) or 0)
    if ResourceStopping or Network <= 0 or Generation <= 0 or Revision <= 0 then
        return
    end

    local SetupToken = ("%s:%s"):format(Generation,Revision)
    if InstructorConfiguredSetup[Network] == SetupToken then
        acknowledgeInstructor(Network,Generation,Revision)
        return
    end

    if InstructorSetupInProgress[Network] == SetupToken then
        return
    end

    InstructorSetupInProgress[Network] = SetupToken
    CreateThread(function()
        local TimeoutAt = GetGameTimer() + (tonumber(Config.Instructor.ConfigureTimeoutMs) or 5000)
        local Ped = NetworkGetEntityFromNetworkId(Network)

        while not ResourceStopping and (Ped == 0 or not DoesEntityExist(Ped)) and GetGameTimer() < TimeoutAt do
            Wait(100)
            Ped = NetworkGetEntityFromNetworkId(Network)
        end

        local function finishSetup()
            if InstructorSetupInProgress[Network] == SetupToken then
                InstructorSetupInProgress[Network] = nil
            end
        end

        if ResourceStopping or Ped == 0 or not DoesEntityExist(Ped) or not NetworkGetEntityIsNetworked(Ped) then
            finishSetup()
            return
        end

        if not NetworkHasControlOfEntity(Ped) then
            debugLog(("instructor_setup_deferred network=%s generation=%s reason=no_control"):format(Network,Generation))
            finishSetup()
            return
        end

        local State = Entity(Ped).state
        local ExpectedModel = GetHashKey(Config.Instructor.Model)
        if State.OFCNHInstructor ~= true or tonumber(State.OFCNHInstructorGeneration) ~= Generation or tonumber(State.OFCNHInstructorSetupRevision) ~= Revision or GetEntityModel(Ped) ~= ExpectedModel then
            debugLog(("instructor_setup_rejected network=%s generation=%s reason=identity_mismatch"):format(Network,Generation))
            finishSetup()
            return
        end

        local FinalCoords = nil
        local Placement = nil
        local SetupSuccess,Configured,SetupError = xpcall(function()
            local Coords = Config.Instructor.Coords
            Placement = resolveInstructorPlacement(Ped,Coords)
            SetEntityCoordsNoOffset(Ped,Coords.x,Coords.y,Placement.FinalZ,false,false,false)
            SetEntityHeading(Ped,Coords.w)
            SetEntityInvincible(Ped,true)
            SetEntityCanBeDamaged(Ped,false)
            SetBlockingOfNonTemporaryEvents(Ped,true)
            TaskSetBlockingOfNonTemporaryEvents(Ped,true)
            SetPedCanRagdoll(Ped,false)
            SetPedDiesWhenInjured(Ped,false)
            SetPedFleeAttributes(Ped,0,false)

            if Config.Instructor.Scenario and Config.Instructor.Scenario ~= "" then
                TaskStartScenarioInPlace(Ped,Config.Instructor.Scenario,0,true)
                SetPedKeepTask(Ped,true)
            end

            Wait(0)
            if ResourceStopping or not DoesEntityExist(Ped) or not NetworkHasControlOfEntity(Ped) then
                return false,"entity_or_control_lost"
            end

            SetEntityCoordsNoOffset(Ped,Coords.x,Coords.y,Placement.FinalZ,false,false,false)
            SetEntityHeading(Ped,Coords.w)
            FreezeEntityPosition(Ped,true)
            FinalCoords = GetEntityCoords(Ped)
            return true,nil
        end,function(Error)
            return tostring(Error)
        end)
        finishSetup()

        if not SetupSuccess then
            debugLog(("instructor_setup_failed network=%s generation=%s revision=%s error=%s"):format(Network,Generation,Revision,tostring(Configured)))
            return
        end

        if not Configured then
            debugLog(("instructor_setup_deferred network=%s generation=%s revision=%s reason=%s"):format(Network,Generation,Revision,tostring(SetupError)))
            return
        end

        InstructorConfiguredSetup[Network] = SetupToken
        debugLog(("instructor_configured network=%s generation=%s reason=%s collision_loaded=%s ground_resolved=%s ground_z=%.4f model_min_z=%.4f model_max_z=%.4f calculated_final_z=%.4f coords=%.4f,%.4f,%.4f health=%s alpha=%s visible=%s frozen=%s"):format(
            Network,
            Generation,
            tostring(Reason or "server_owner"),
            boolText(Placement.CollisionLoaded),
            boolText(Placement.GroundResolved),
            Placement.GroundZ,
            Placement.MinimumZ,
            Placement.MaximumZ,
            Placement.FinalZ,
            FinalCoords.x,
            FinalCoords.y,
            FinalCoords.z,
            tostring(GetEntityHealth(Ped)),
            tostring(GetEntityAlpha(Ped)),
            boolText(IsEntityVisible(Ped)),
            boolText(IsEntityPositionFrozen(Ped))
        ))
        acknowledgeInstructor(Network,Generation,Revision)
    end)
end

RegisterNetEvent("of_drivingschool:ConfigureInstructor",function(Network,Generation,Revision)
    configureNetworkedInstructor(Network,Generation,Revision,"server_owner")
end)

AddStateBagChangeHandler("OFCNHInstructorSetupRevision",nil,function(BagName,_,Value)
    local Revision = tonumber(Value)
    if ResourceStopping or not Revision or Revision <= 0 then
        return
    end

    local Ped = GetEntityFromStateBagName(BagName)
    if Ped == 0 or not DoesEntityExist(Ped) or not NetworkGetEntityIsNetworked(Ped) then
        return
    end

    local Network = NetworkGetNetworkIdFromEntity(Ped)
    local Generation = tonumber(Entity(Ped).state.OFCNHInstructorGeneration)
    configureNetworkedInstructor(Network,Generation,Revision,"state_bag")
end)

local function removeInstructorTarget()
    if GetResourceState("target") == "started" then
        pcall(function()
            exports.target:RemCircleZone(InstructorTarget)
        end)
    end

    InstructorTargetRegistered = false
end

local function registerInstructorTarget()
    if ResourceStopping or InstructorTargetRegistered or GetResourceState("target") ~= "started" then
        return false
    end

    pcall(function()
        exports.target:RemCircleZone(InstructorTarget)
    end)

    local Success,Error = pcall(function()
        local Coords = Config.Instructor.Coords
        exports.target:AddCircleZone(InstructorTarget,vector3(Coords.x,Coords.y,Coords.z),Config.Instructor.TargetRadius,{
            name = InstructorTarget,
            heading = Coords.w,
            useZ = false
        },{
            Distance = Config.Instructor.TargetDistance,
            options = {
                {
                    event = "of_drivingschool:StartExam",
                    tunnel = "client",
                    label = "Tirar CNH - Categoria B"
                }
            }
        })
    end)

    if not Success then
        InstructorTargetRegistered = false
        local Now = GetGameTimer()
        if Now >= NextInstructorTargetLogAt then
            local Diagnostic = tostring(Error or "unknown"):gsub("[\r\n]+"," "):sub(1,200)
            print("[of_drivingschool] WARN target_registration_failed; retrying: "..Diagnostic)
            NextInstructorTargetLogAt = Now + 10000
        end

        return false
    end

    InstructorTargetRegistered = true
    NextInstructorTargetLogAt = 0
    return true
end

local function hideResult()
    ResultGeneration = ResultGeneration + 1
    SendNUIMessage({ Action = "hideResult" })
end

local function hideChecklistHud()
    SendNUIMessage({ Action = "hideChecklist" })
end

local function showChecklistHud(State)
    State = tostring(State or "")
    if not Config.Checklist[State] then
        hideChecklistHud()
        return
    end

    SendNUIMessage({
        Action = "showChecklist",
        State = State
    })
end

local function showResult(Result,Reason,Category)
    local Normalized = Result == "approved" and "approved" or "failed"
    ResultGeneration = ResultGeneration + 1
    local Generation = ResultGeneration
    hideChecklistHud()

    SendNUIMessage({
        Action = "showResult",
        Result = Normalized,
        Category = tostring(Category or Config.Exam.Category),
        Reason = tostring(Reason or "")
    })

    SetTimeout(Config.ResultUi.DurationMs,function()
        if Generation == ResultGeneration then
            hideResult()
        end
    end)
end

local function examVehicleMatches(Vehicle,Exam)
    if not Exam or not Vehicle or Vehicle == 0 or not DoesEntityExist(Vehicle) then
        return false
    end

    if GetEntityModel(Vehicle) ~= GetHashKey(Config.Exam.VehicleModel) then
        return false
    end

    local Plate = GetVehicleNumberPlateText(Vehicle):gsub("%s+","")
    return Plate == tostring(Exam.Plate or ""):gsub("%s+","")
end

local function deleteExamVehicle(Exam)
    local Vehicle = Exam and Exam.Vehicle or 0
    if not examVehicleMatches(Vehicle,Exam) then
        return
    end

    if NetworkGetEntityIsNetworked(Vehicle) then
        NetworkRequestControlOfEntity(Vehicle)
        local Timeout = GetGameTimer() + 1000
        while not NetworkHasControlOfEntity(Vehicle) and GetGameTimer() < Timeout do
            Wait(25)
            NetworkRequestControlOfEntity(Vehicle)
        end
    end

    SetEntityAsMissionEntity(Vehicle,true,true)
    DeleteVehicle(Vehicle)
    if DoesEntityExist(Vehicle) then
        DeleteEntity(Vehicle)
    end
end

local function cleanupExam(DeleteVehicle)
    local Exam = ActiveExam
    ActiveExam = nil
    hideChecklistHud()
    clearPracticalState(Exam)

    if DeleteVehicle ~= false then
        deleteExamVehicle(Exam)
    end
end

local function cancelActiveExam(Reason,Message)
    local Exam = ActiveExam
    if not Exam then
        return
    end

    pcall(function()
        vSERVER.CancelExam(Exam.Token,Reason or "client_cancel")
    end)
    cleanupExam(true)

    if Message and Message ~= "" then
        notify(Message,"vermelho")
    end
end

local function spawnOccupied(Coords)
    local Radius = Config.Exam.SpawnOccupancyRadius
    if IsAnyVehicleNearPoint(Coords.x,Coords.y,Coords.z,Radius) then
        return true
    end

    local Closest = GetClosestVehicle(Coords.x,Coords.y,Coords.z,Radius,0,71)
    return Closest and Closest ~= 0 and DoesEntityExist(Closest)
end

local function waitForNetworkId(Vehicle)
    local Timeout = GetGameTimer() + Config.Exam.VehicleNetworkTimeoutMs
    local Network = NetworkGetNetworkIdFromEntity(Vehicle)

    while (not Network or Network <= 0) and GetGameTimer() < Timeout do
        Wait(50)
        NetworkRegisterEntityAsNetworked(Vehicle)
        Network = NetworkGetNetworkIdFromEntity(Vehicle)
    end

    return tonumber(Network) or 0
end

local function configureExamVehicle(Vehicle,Plate)
    SetEntityAsMissionEntity(Vehicle,true,true)
    SetVehicleColours(Vehicle,27,27)
    ClearVehicleCustomPrimaryColour(Vehicle)
    ClearVehicleCustomSecondaryColour(Vehicle)
    SetVehicleCustomPrimaryColour(Vehicle,180,0,0)
    SetVehicleCustomSecondaryColour(Vehicle,180,0,0)
    SetVehicleOnGroundProperly(Vehicle)
    SetVehicleNumberPlateText(Vehicle,Plate)
    SetVehicleDirtLevel(Vehicle,0.0)
    SetVehicleDoorsLocked(Vehicle,1)
    SetVehicleEngineOn(Vehicle,false,true,true)
    SetVehRadioStation(Vehicle,"OFF")
    SetVehicleRadioEnabled(Vehicle,false)
    SetEntityMaxSpeed(Vehicle,Config.Exam.MaxSpeedKmh / 3.6)
end

local function requestUsableSlot(Exam,Reservation)
    local Current = Reservation

    while ActiveExam == Exam and Current and Current.success do
        local Slot = tonumber(Current.slot)
        local Coords = Slot and Config.Exam.SpawnSlots[Slot]
        if not Coords then
            return nil,"A configuracao da vaga da Autoescola e invalida."
        end

        if not spawnOccupied(Coords) then
            return Current,nil
        end

        Current = vSERVER.RequestNextSlot(Exam.Token,Slot,"world_occupied")
    end

    if ActiveExam ~= Exam then
        return nil,"A sessao da prova nao esta mais disponivel."
    end

    return nil,Current and Current.message or "Nao ha veiculos de prova disponiveis. Aguarde uma vaga."
end

local function createExamVehicle(Reservation)
    local Exam = ActiveExam
    if not Exam then
        return false
    end

    local Usable,SlotError = requestUsableSlot(Exam,Reservation)
    if not Usable then
        if ActiveExam == Exam then
            cleanupExam(false)
        end
        notify(SlotError,"amarelo")
        return false
    end

    Exam.Slot = tonumber(Usable.slot)
    Exam.Plate = tostring(Usable.plate or Exam.Plate or "")
    local Coords = Config.Exam.SpawnSlots[Exam.Slot]
    local Model = loadModel(Config.Exam.VehicleModel,Config.Exam.ModelTimeoutMs)

    if ActiveExam ~= Exam then
        if Model then
            SetModelAsNoLongerNeeded(Model)
        end
        return false
    end

    if not Model or not IsModelAVehicle(Model) then
        vSERVER.CancelExam(Exam.Token,"model_unavailable")
        cleanupExam(false)
        notify("O veiculo da Autoescola esta indisponivel.","vermelho")
        return false
    end

    if spawnOccupied(Coords) then
        SetModelAsNoLongerNeeded(Model)
        local Next = vSERVER.RequestNextSlot(Exam.Token,Exam.Slot,"occupied_during_load")
        if not Next or not Next.success then
            if ActiveExam == Exam then
                cleanupExam(false)
            end
            notify(Next and Next.message or "Nao ha veiculos de prova disponiveis. Aguarde uma vaga.","amarelo")
            return false
        end

        return createExamVehicle(Next)
    end

    local Vehicle = CreateVehicle(Model,Coords.x,Coords.y,Coords.z,Coords.w,true,true)
    SetModelAsNoLongerNeeded(Model)
    if not Vehicle or Vehicle == 0 or not DoesEntityExist(Vehicle) then
        vSERVER.CancelExam(Exam.Token,"vehicle_creation_failed")
        cleanupExam(false)
        notify("Nao foi possivel criar o veiculo de prova.","vermelho")
        return false
    end

    Exam.Vehicle = Vehicle
    configureExamVehicle(Vehicle,Exam.Plate)
    local Network = waitForNetworkId(Vehicle)
    if Network <= 0 then
        vSERVER.CancelExam(Exam.Token,"network_registration_failed")
        cleanupExam(true)
        notify("O veiculo de prova nao foi registrado na rede.","vermelho")
        return false
    end

    Exam.NetId = Network
    local Registered = vSERVER.RegisterVehicle(Exam.Token,Exam.Slot,Network)
    if ActiveExam ~= Exam then
        deleteExamVehicle(Exam)
        return false
    end

    if not Registered or not Registered.success then
        vSERVER.CancelExam(Exam.Token,"server_vehicle_rejected")
        cleanupExam(true)
        notify(Registered and Registered.message or "O servidor nao validou o veiculo de prova.","vermelho")
        return false
    end

    Exam.State = Registered.state
    Exam.VehicleRegistered = true
    showChecklistHud(Exam.State)
    return true
end

local function setRouteDestination(Exam,Index)
    local Points = routeCheckpoints()
    local Point = Points[tonumber(Index) or 0]
    if not Point or not Point.Coords then
        clearExamDestination(Exam)
        return false
    end

    Exam.RouteIndex = tonumber(Index)
    local Label = Point.Label or ("Percurso %s/%s"):format(Exam.RouteIndex,#Points)
    return setExamDestination(Exam,Point.Coords,Label,Config.Exam.Route.Blip)
end

local function setParkingDestination(Exam)
    local Parking = Config.Exam.Parking
    return setExamDestination(Exam,Parking and Parking.Center,"Area de baliza",Parking and Parking.Blip)
end

local function handlePracticalFailure(Exam,Result)
    if ActiveExam ~= Exam then
        return
    end

    if Result and Result.terminate then
        cleanupExam(true)
    end

    if Result and Result.message and Result.message ~= "" then
        notify(Result.message,"vermelho")
    end
end

local function beginRoute()
    local Exam = ActiveExam
    if not Exam or Exam.State ~= "READY_FOR_ROUTE" or Exam.RouteStarting or Exam.RouteUnavailable then
        return
    end

    local State = readVehicleState()
    if not State.InVehicle or State.Vehicle ~= Exam.Vehicle or not State.IsDriver then
        return
    end

    Exam.RouteStarting = true
    local Result = vSERVER.BeginRoute(Exam.Token,Exam.NetId)
    if ActiveExam ~= Exam then
        return
    end

    Exam.RouteStarting = false
    if not Result or not Result.success then
        if Result and Result.code == "route_unavailable" then
            Exam.RouteUnavailable = true
        else
            Exam.NextRouteStartAt = GetGameTimer() + 1000
        end
        handlePracticalFailure(Exam,Result)
        return
    end

    Exam.State = "ROUTE_ACTIVE"
    Exam.RouteIndex = tonumber(Result.routeIndex) or 1
    hideChecklistHud()
    setRouteDestination(Exam,Exam.RouteIndex)
    notify("Percurso iniciado. Siga a rota indicada.","verde",6000)
    debugLog(("route_started index=%s total=%s"):format(Exam.RouteIndex,tostring(Result.total)))
end

local beginParking

local function reachRouteCheckpoint()
    local Exam = ActiveExam
    if not Exam or Exam.State ~= "ROUTE_ACTIVE" or Exam.RouteAdvancing then
        return
    end

    local Index = tonumber(Exam.RouteIndex)
    if not Index then
        return
    end

    Exam.RouteAdvancing = true
    local Result = vSERVER.ReachRouteCheckpoint(Exam.Token,Exam.NetId,Index)
    if ActiveExam ~= Exam then
        return
    end

    Exam.RouteAdvancing = false
    if not Result or not Result.success then
        handlePracticalFailure(Exam,Result)
        return
    end

    debugLog(("checkpoint_reached index=%s total=%s"):format(Index,tostring(Result.total)))
    if Result.state == "ROUTE_COMPLETE" then
        Exam.State = "ROUTE_COMPLETE"
        clearExamDestination(Exam)
        notify("Percurso concluido. Siga ate a area de baliza.","verde",7000)
        debugLog("route_completed")
        beginParking()
        return
    end

    Exam.State = "ROUTE_ACTIVE"
    Exam.RouteIndex = tonumber(Result.routeIndex) or (Index + 1)
    setRouteDestination(Exam,Exam.RouteIndex)
    notify(("Percurso %s/%s"):format(tostring(Result.completed or Index),tostring(Result.total or #routeCheckpoints())),"verde",3000)
end

beginParking = function()
    local Exam = ActiveExam
    if not Exam or Exam.State ~= "ROUTE_COMPLETE" or Exam.ParkingStarting then
        return
    end

    local State = readVehicleState()
    if not State.InVehicle or State.Vehicle ~= Exam.Vehicle or not State.IsDriver then
        return
    end

    Exam.ParkingStarting = true
    local Result = vSERVER.BeginParking(Exam.Token,Exam.NetId)
    if ActiveExam ~= Exam then
        return
    end

    Exam.ParkingStarting = false
    if not Result or not Result.success then
        handlePracticalFailure(Exam,Result)
        return
    end

    Exam.State = "PARKING_ACTIVE"
    Exam.ParkingStartedAt = GetGameTimer()
    Exam.ParkingHoldStartedAt = nil
    Exam.UsedReverse = Result.usedReverse == true
    Exam.ReversePending = false
    Exam.PassRequestPending = false
    setParkingDestination(Exam)
    notify("Baliza: use a marcha re e posicione o veiculo na vaga.","amarelo",7000)
    debugLog("parking_started")
end

local function parkingFeedback(Exam,Key,Message)
    local Now = GetGameTimer()
    local Throttle = tonumber(Config.Exam.Parking.FeedbackThrottleMs) or 4000
    if Exam.LastParkingFeedback ~= Key or Now >= (Exam.LastParkingFeedbackAt or 0) + Throttle then
        Exam.LastParkingFeedback = Key
        Exam.LastParkingFeedbackAt = Now
        notify(Message,"amarelo",3500)
    end
end

local function markParkingReverse(Exam)
    if Exam.UsedReverse or Exam.ReversePending then
        return
    end

    Exam.ReversePending = true
    local Result = vSERVER.MarkParkingReverse(Exam.Token,Exam.NetId)
    if ActiveExam ~= Exam then
        return
    end

    Exam.ReversePending = false
    if Result and Result.success then
        Exam.UsedReverse = true
        debugLog("parking_reverse_detected")
    elseif Result and Result.terminate then
        handlePracticalFailure(Exam,Result)
    end
end

local function completeParking(Exam)
    local Now = GetGameTimer()
    if Exam.PassRequestPending or Now < (Exam.NextPassRequestAt or 0) then
        return
    end

    Exam.PassRequestPending = true
    Exam.NextPassRequestAt = Now + 500
    local Result = vSERVER.CompleteParking(Exam.Token,Exam.NetId)
    if ActiveExam ~= Exam then
        return
    end

    Exam.PassRequestPending = false
    if not Result or not Result.success then
        if Result and Result.code == "parking_hold_pending" then
            return
        end
        handlePracticalFailure(Exam,Result)
        return
    end

    Exam.State = "PARKING_COMPLETE"
    debugLog("parking_completed")
    cleanupExam(true)
    showResult("approved",Result.message or "Voce foi aprovado na prova pratica.",Result.category or Config.Exam.Category)
    debugLog("exam_passed")
end

local function processRoute(Exam,State)
    if State.Seatbelt ~= true then
        local Now = GetGameTimer()
        if Now >= (Exam.LastSeatbeltWarningAt or 0) then
            Exam.LastSeatbeltWarningAt = Now + 5000
            notify("Coloque o cinto para continuar a prova.","amarelo",4500)
        end
        return
    end

    Exam.LastSeatbeltWarningAt = nil
    local Point = routeCheckpoints()[tonumber(Exam.RouteIndex) or 0]
    if not Point or not Point.Coords then
        cancelActiveExam("route_configuration_lost","A configuracao do percurso ficou indisponivel.")
        return
    end

    if #(GetEntityCoords(Exam.Vehicle) - vector3(Point.Coords.x,Point.Coords.y,Point.Coords.z)) <= checkpointRadius(Point) then
        reachRouteCheckpoint()
    end
end

local function processParking(Exam,State)
    local Parking = Config.Exam.Parking
    local Now = GetGameTimer()
    if State.Seatbelt ~= true then
        Exam.ParkingHoldStartedAt = nil
        if Now >= (Exam.LastSeatbeltWarningAt or 0) then
            Exam.LastSeatbeltWarningAt = Now + 5000
            notify("Coloque o cinto para continuar a prova.","amarelo",4500)
        end
        return
    end

    Exam.LastSeatbeltWarningAt = nil
    local LocalSpeed = GetEntitySpeedVector(Exam.Vehicle,true)
    if not Exam.UsedReverse and LocalSpeed and tonumber(LocalSpeed.y) and LocalSpeed.y < -(tonumber(Parking.ReverseSpeedMps) or 0.20) then
        markParkingReverse(Exam)
    end

    local Coords = GetEntityCoords(Exam.Vehicle)
    local Center = Parking.Center
    local Distance = #(Coords - vector3(Center.x,Center.y,Center.z))
    local HeadingValid = headingDifference(GetEntityHeading(Exam.Vehicle),Center.w) <= (tonumber(Parking.HeadingTolerance) or 8.0)
    local PositionValid = Distance <= (tonumber(Parking.PositionTolerance) or 1.25)
    local Stopped = GetEntitySpeed(Exam.Vehicle) <= (tonumber(Parking.StoppedSpeedMps) or 0.15)
    local ReverseValid = Parking.RequireReverse ~= true or Exam.UsedReverse == true
    local Valid = PositionValid and HeadingValid and Stopped and ReverseValid

    if not ReverseValid then
        Exam.ParkingHoldStartedAt = nil
        parkingFeedback(Exam,"reverse","Realize a manobra utilizando a marcha re.")
    elseif not PositionValid then
        Exam.ParkingHoldStartedAt = nil
        parkingFeedback(Exam,"position","Posicione o veiculo dentro da vaga indicada.")
    elseif not HeadingValid then
        Exam.ParkingHoldStartedAt = nil
        parkingFeedback(Exam,"heading","Ajuste o alinhamento do veiculo.")
    elseif not Stopped then
        Exam.ParkingHoldStartedAt = nil
        parkingFeedback(Exam,"moving","Pare o veiculo dentro da vaga.")
    elseif Valid then
        if not Exam.ParkingHoldStartedAt then
            Exam.ParkingHoldStartedAt = Now
            parkingFeedback(Exam,"hold","Mantenha o veiculo parado e alinhado.")
            debugLog("parking_position_valid")
        elseif Now - Exam.ParkingHoldStartedAt >= (tonumber(Parking.HoldMs) or 3000) then
            completeParking(Exam)
        end
    end
end

local function startExam()
    if StartBusy then
        return
    end

    if ActiveExam then
        notify("Voce ja possui uma prova pratica ativa.","amarelo")
        return
    end

    StartBusy = true
    local Result = vSERVER.StartExam(Config.Exam.Category)
    StartBusy = false

    if not Result or not Result.success then
        notify(Result and Result.message or "Nao foi possivel iniciar a prova pratica.","vermelho")
        return
    end

    ActiveExam = {
        Token = tostring(Result.token or ""),
        Slot = tonumber(Result.slot),
        Plate = tostring(Result.plate or ""),
        State = "SPAWNING",
        Vehicle = 0,
        NetId = 0,
        Advancing = false,
        VehicleRegistered = false,
        LastLimiterAt = 0,
        WrongSeatNotified = false
    }

    if ActiveExam.Token == "" or not ActiveExam.Slot then
        if ActiveExam.Token ~= "" then
            vSERVER.CancelExam(ActiveExam.Token,"invalid_initialization")
        end
        cleanupExam(false)
        notify("A sessao da prova pratica e invalida.","vermelho")
        return
    end

    createExamVehicle(Result)
end

local function advanceChecklist(Step)
    local Exam = ActiveExam
    if not Exam or Exam.Advancing or not Exam.VehicleRegistered then
        return
    end

    Exam.Advancing = true
    local Result = vSERVER.AdvanceChecklist(Exam.Token,Step,Exam.NetId)
    if ActiveExam ~= Exam then
        return
    end

    Exam.Advancing = false
    if not Result or not Result.success then
        if Result and Result.terminate then
            cleanupExam(true)
        end
        if Result and Result.message and Result.message ~= "" then
            notify(Result.message,"vermelho")
        end
        return
    end

    Exam.State = Result.state
    Exam.WrongSeatNotified = false
    showChecklistHud(Exam.State)
    if Exam.State == "READY_FOR_ROUTE" then
        Exam.NextRouteStartAt = GetGameTimer() + (tonumber(Config.Exam.Route.StartDelayMs) or 1200)
        notify("Percurso liberado. Siga a rota indicada.","verde",6000)
    end
end

RegisterCommand("ofcnhdiag",function()
    local State = readVehicleState()

    if not State.InVehicle then
        print("[of_drivingschool] DIAG | inVehicle=false")
        return
    end

    local SeatbeltText = State.Seatbelt == nil and ("unavailable:"..tostring(State.SeatbeltError)) or boolText(State.Seatbelt)
    print(("[of_drivingschool] DIAG | inVehicle=true driver=%s seatbelt=%s engine=%s lights=%s highbeams=%s speed=%dkm/h"):format(
        boolText(State.IsDriver),
        SeatbeltText,
        boolText(State.EngineOn),
        boolText(State.LightsOn),
        boolText(State.HighBeamsOn),
        State.SpeedKmh
    ))
end,false)

-- TEMPORARY development-only helper. It records local coordinates in memory
-- and never calls the server, mutates an exam session or persists data.
RegisterCommand("ofcnhroutepoint",function()
    if Config.DebugRouteRecorder ~= true then
        print("[of_drivingschool] ROUTE_RECORDER disabled")
        return
    end

    local Ped = PlayerPedId()
    local Vehicle = GetVehiclePedIsIn(Ped,false)
    local Entity = Vehicle ~= 0 and Vehicle or Ped
    local Coords = GetEntityCoords(Entity)
    local Heading = GetEntityHeading(Entity)
    RecordedRoutePoints[#RecordedRoutePoints + 1] = {
        x = Coords.x,
        y = Coords.y,
        z = Coords.z,
        heading = Heading
    }
    print(("[of_drivingschool] ROUTE_POINT vec3(%.4f,%.4f,%.4f) heading=%.2f"):format(Coords.x,Coords.y,Coords.z,Heading))
end,false)

RegisterCommand("ofcnhroutepoints",function()
    if Config.DebugRouteRecorder ~= true then
        print("[of_drivingschool] ROUTE_RECORDER disabled")
        return
    end

    print(("[of_drivingschool] ROUTE_POINTS_BEGIN count=%s"):format(#RecordedRoutePoints))
    local Radius = tonumber(Config.Exam.Route.DefaultRadius) or 6.0
    for Index,Point in ipairs(RecordedRoutePoints) do
        print(("    { Coords = vec3(%.4f,%.4f,%.4f), Radius = %.1f, Label = \"Ponto %s\" },"):format(
            Point.x,
            Point.y,
            Point.z,
            Radius,
            Index
        ))
    end
    print("[of_drivingschool] ROUTE_POINTS_END")
end,false)

RegisterCommand("ofcnhrouteclear",function()
    if Config.DebugRouteRecorder ~= true then
        print("[of_drivingschool] ROUTE_RECORDER disabled")
        return
    end

    RecordedRoutePoints = {}
    print("[of_drivingschool] ROUTE_POINTS_CLEARED")
end,false)

RegisterCommand("ofcnhcancelar",function()
    if not ActiveExam then
        notify("Voce nao possui uma prova pratica ativa.","amarelo")
        return
    end

    cancelActiveExam("player_cancelled","Prova pratica cancelada.")
end,false)

AddEventHandler("of_drivingschool:StartExam",startExam)

RegisterNetEvent("of_drivingschool:ForceCleanup",function(Token,_,Message)
    if not ActiveExam or tostring(Token or "") ~= ActiveExam.Token then
        return
    end

    cleanupExam(true)
    if Message and Message ~= "" then
        notify(Message,"vermelho",7000)
    end
end)

RegisterNetEvent("of_drivingschool:PrintCoords",function()
    local Ped = PlayerPedId()
    local Coords = GetEntityCoords(Ped)
    local Heading = GetEntityHeading(Ped)
    local Output = ("vec4(%.4f,%.4f,%.4f,%.2f)"):format(Coords.x,Coords.y,Coords.z,Heading)
    print("[of_drivingschool] COORDS | "..Output)
    notify("Coordenada exibida no console F8: "..Output,"verde",9000)
end)

RegisterNetEvent("of_drivingschool:ShowApproved",function(Reason,Category)
    showResult("approved",Reason or "Voce foi aprovado na prova pratica.",Category)
end)

RegisterNetEvent("of_drivingschool:ShowFailed",function(Reason,Category)
    showResult("failed",Reason or "A prova pratica nao foi concluida.",Category)
end)

RegisterNetEvent("of_drivingschool:ExamFinished",function(Token,Approved,Reason,Category)
    local Exam = ActiveExam
    if not Exam or tostring(Token or "") ~= Exam.Token then
        return
    end

    cleanupExam(true)
    showResult(Approved == true and "approved" or "failed",Reason,Category)
    debugLog(Approved == true and "exam_passed" or "exam_failed")
end)

CreateThread(function()
    while not ResourceStopping do
        if GetResourceState("target") == "started" then
            registerInstructorTarget()
        end

        Wait(Config.Instructor.HealthCheckMs)
    end
end)

CreateThread(function()
    while true do
        local WaitTime = 1000
        local Exam = ActiveExam

        if Exam and Exam.VehicleRegistered then
            WaitTime = Config.Exam.ClientWatchdogMs
            local Ped = PlayerPedId()
            local Vehicle = Exam.Vehicle

            if LocalPlayer.state.Death or IsPedDeadOrDying(Ped,true) or GetEntityHealth(Ped) <= 100 then
                cancelActiveExam("death","A prova pratica foi encerrada.")
            elseif not examVehicleMatches(Vehicle,Exam) or IsEntityDead(Vehicle) or GetEntityHealth(Vehicle) <= 0 then
                cancelActiveExam("vehicle_missing","O veiculo da prova nao esta mais disponivel.")
            else
                local Now = GetGameTimer()
                if Now >= (Exam.LastLimiterAt or 0) then
                    SetEntityMaxSpeed(Vehicle,Config.Exam.MaxSpeedKmh / 3.6)
                    Exam.LastLimiterAt = Now + Config.Exam.LimiterRefreshMs
                end

                local State = readVehicleState()
                local CorrectSeat = State.InVehicle and State.Vehicle == Vehicle and State.IsDriver

                if Exam.State == "WAITING_FOR_DRIVER" and CorrectSeat then
                    advanceChecklist("ENTER_DRIVER_SEAT")
                elseif Exam.State ~= "WAITING_FOR_DRIVER" and not CorrectSeat then
                    if not Exam.WrongSeatNotified then
                        Exam.WrongSeatNotified = true
                        notify("Retorne ao banco do motorista do veiculo da Autoescola.","amarelo")
                    end
                elseif CorrectSeat then
                    Exam.WrongSeatNotified = false
                    if Exam.State == "WAITING_FOR_SEATBELT" then
                        if State.Seatbelt == nil then
                            cancelActiveExam("seatbelt_state_unavailable","Nao foi possivel consultar o estado do cinto pelo HUD.")
                        elseif State.Seatbelt then
                            advanceChecklist("SEATBELT")
                        end
                    elseif Exam.State == "WAITING_FOR_ENGINE" and State.EngineOn then
                        advanceChecklist("ENGINE")
                    elseif Exam.State == "WAITING_FOR_LIGHTS" and State.LightsOn then
                        advanceChecklist("LIGHTS")
                    elseif Exam.State == "READY_FOR_ROUTE" and not Exam.RouteUnavailable and GetGameTimer() >= (Exam.NextRouteStartAt or 0) then
                        beginRoute()
                    elseif Exam.State == "ROUTE_ACTIVE" then
                        processRoute(Exam,State)
                    elseif Exam.State == "ROUTE_COMPLETE" then
                        beginParking()
                    elseif Exam.State == "PARKING_ACTIVE" then
                        processParking(Exam,State)
                    end
                end
            end
        end

        Wait(WaitTime)
    end
end)

CreateThread(function()
    while true do
        local WaitTime = 500
        local Exam = ActiveExam
        local Ped = PlayerPedId()
        local PedCoords = GetEntityCoords(Ped)

        if Exam and Exam.State == "ROUTE_ACTIVE" then
            local Point = routeCheckpoints()[tonumber(Exam.RouteIndex) or 0]
            local Marker = Config.Exam.Route.Marker
            if Point and Point.Coords and #(PedCoords - vector3(Point.Coords.x,Point.Coords.y,Point.Coords.z)) <= (tonumber(Marker.DrawDistance) or 80.0) then
                WaitTime = 0
                local Radius = checkpointRadius(Point)
                DrawMarker(
                    tonumber(Marker.Type) or 1,
                    Point.Coords.x,Point.Coords.y,Point.Coords.z - 1.05,
                    0.0,0.0,0.0,0.0,0.0,0.0,
                    Radius * 1.25,Radius * 1.25,tonumber(Marker.Height) or 1.0,
                    tonumber(Marker.Red) or 216,tonumber(Marker.Green) or 173,tonumber(Marker.Blue) or 85,tonumber(Marker.Alpha) or 150,
                    false,false,2,false
                )
            end
        elseif Exam and Exam.State == "PARKING_ACTIVE" then
            local Parking = Config.Exam.Parking
            local Marker = Parking.Marker
            local Center = Parking.Center
            if #(PedCoords - vector3(Center.x,Center.y,Center.z)) <= (tonumber(Marker.DrawDistance) or 80.0) then
                WaitTime = 0
                local Tolerance = tonumber(Parking.PositionTolerance) or 1.25
                DrawMarker(
                    tonumber(Marker.Type) or 1,
                    Center.x,Center.y,Center.z - 1.05,
                    0.0,0.0,0.0,0.0,0.0,0.0,
                    Tolerance * 2.0,Tolerance * 2.0,tonumber(Marker.CenterHeight) or 0.35,
                    tonumber(Marker.Red) or 216,tonumber(Marker.Green) or 173,tonumber(Marker.Blue) or 85,tonumber(Marker.Alpha) or 150,
                    false,false,2,false
                )

                for _,Reference in ipairs({ Parking.FrontReference,Parking.RearReference }) do
                    DrawMarker(
                        tonumber(Marker.Type) or 1,
                        Reference.x,Reference.y,Reference.z - 1.05,
                        0.0,0.0,0.0,0.0,0.0,0.0,
                        tonumber(Marker.ReferenceRadius) or 0.45,tonumber(Marker.ReferenceRadius) or 0.45,tonumber(Marker.ReferenceHeight) or 1.25,
                        tonumber(Marker.Red) or 216,tonumber(Marker.Green) or 173,tonumber(Marker.Blue) or 85,tonumber(Marker.Alpha) or 150,
                        false,false,2,false
                    )
                end
            end
        end

        Wait(WaitTime)
    end
end)

AddEventHandler("onClientResourceStart",function(ResourceName)
    if ResourceName == "target" then
        InstructorTargetRegistered = false
        Wait(250)
        registerInstructorTarget()
    end
end)

AddEventHandler("onClientResourceStop",function(ResourceName)
    if ResourceName == "target" then
        InstructorTargetRegistered = false
    end
end)

AddEventHandler("onResourceStop",function(ResourceName)
    if ResourceName ~= GetCurrentResourceName() then
        return
    end

    ResourceStopping = true
    hideResult()
    hideChecklistHud()
    removeInstructorTarget()
    cleanupExam(true)
    InstructorSetupInProgress = {}
    InstructorConfiguredSetup = {}
end)
