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
        local SetupSuccess,Configured,SetupError = xpcall(function()
            local Coords = Config.Instructor.Coords
            local SpawnZ = tonumber(Config.Instructor.SpawnZ) or Coords.z
            SetEntityCoordsNoOffset(Ped,Coords.x,Coords.y,SpawnZ,false,false,false)
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

            SetEntityCoordsNoOffset(Ped,Coords.x,Coords.y,SpawnZ,false,false,false)
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
        debugLog(("instructor_configured network=%s generation=%s reason=%s coords=%.4f,%.4f,%.4f health=%s alpha=%s visible=%s frozen=%s"):format(
            Network,
            Generation,
            tostring(Reason or "server_owner"),
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

local function showResult(Result,Reason,Category)
    local Normalized = Result == "approved" and "approved" or "failed"
    ResultGeneration = ResultGeneration + 1
    local Generation = ResultGeneration

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
    notify(Registered.message or Config.Checklist.WAITING_FOR_DRIVER,"amarelo",7000)
    return true
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
    notify(Result.message or Config.Checklist[Exam.State] or "Etapa concluida.",Exam.State == "READY_FOR_ROUTE" and "verde" or "amarelo",7000)
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
            elseif not examVehicleMatches(Vehicle,Exam) then
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
                elseif Exam.State ~= "WAITING_FOR_DRIVER" and Exam.State ~= "READY_FOR_ROUTE" and not CorrectSeat then
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
                    end
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
    removeInstructorTarget()
    cleanupExam(true)
    InstructorSetupInProgress = {}
    InstructorConfiguredSetup = {}
end)
