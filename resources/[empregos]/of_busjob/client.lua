local Tunnel = module("vrp", "lib/Tunnel")

local vSERVER = Tunnel.getInterface("of_busjob")

local Active = false
local BusVehicle = 0
local BusNetId = nil
local DepotBlip = nil
local RouteBlip = nil
local Passenger = 0
local PickupIndex = 1
local DeliveryIndex = nil
local PassengerOnBoard = false
local Phase = "pickup"
local Busy = false
local TargetReady = false
local SavedOutfit = nil
local UniformApplied = false
local RouteStarted = false
local LastPassengerSpawnAttempt = 0

local function notify(kind, message, duration)
    TriggerEvent("Notify", kind or "amarelo", message, duration or 5000)
end

local function removeLegacyBusPoint()
    if GetResourceState("target") == "started" then
        exports.target:RemCircleZone("WorkBus")
    end

    local legacyCoords = vector3(453.47, -602.34, 28.59)
    local legacyModel = GetHashKey("a_m_y_business_02")
    for _, ped in ipairs(GetGamePool("CPed")) do
        if not IsPedAPlayer(ped) and DoesEntityExist(ped) and GetEntityModel(ped) == legacyModel then
            if #(GetEntityCoords(ped) - legacyCoords) < 3.0 then
                SetEntityAsMissionEntity(ped, true, true)
                DeletePed(ped)
            end
        end
    end
end

local function removeBlip(blip)
    if blip and DoesBlipExist(blip) then
        RemoveBlip(blip)
    end

    return nil
end

local function requestEntityControl(entity, timeoutMs)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return false
    end

    if NetworkHasControlOfEntity(entity) then
        return true
    end

    local timeout = GetGameTimer() + (timeoutMs or 1000)
    repeat
        NetworkRequestControlOfEntity(entity)
        Wait(0)
    until NetworkHasControlOfEntity(entity) or GetGameTimer() >= timeout

    return NetworkHasControlOfEntity(entity)
end

local function captureOutfit()
    local ped = PlayerPedId()
    local outfit = { components = {}, props = {} }

    for component = 0, 11 do
        outfit.components[component] = {
            drawable = GetPedDrawableVariation(ped, component),
            texture = GetPedTextureVariation(ped, component),
            palette = GetPedPaletteVariation(ped, component)
        }
    end

    for prop = 0, 7 do
        outfit.props[prop] = {
            drawable = GetPedPropIndex(ped, prop),
            texture = GetPedPropTextureIndex(ped, prop)
        }
    end

    return outfit
end

local function applyBusUniform()
    if UniformApplied then
        return
    end

    local ped = PlayerPedId()
    SavedOutfit = SavedOutfit or captureOutfit()

    SetPedComponentVariation(ped, 11, 349, 15, 0) -- Jaqueta
    SetPedComponentVariation(ped, 4, 24, 0, 0)    -- Calca
    SetPedComponentVariation(ped, 6, 103, 0, 0)   -- Sapato
    SetPedComponentVariation(ped, 7, 38, 0, 0)    -- Acessorios
    SetPedPropIndex(ped, 0, 0, 0, true)           -- Chapeu

    UniformApplied = true
end

local function restoreOutfit()
    if not SavedOutfit then
        UniformApplied = false
        return
    end

    local ped = PlayerPedId()
    for component, data in pairs(SavedOutfit.components) do
        SetPedComponentVariation(ped, component, data.drawable, data.texture, data.palette or 0)
    end

    for prop, data in pairs(SavedOutfit.props) do
        if data.drawable and data.drawable >= 0 then
            SetPedPropIndex(ped, prop, data.drawable, data.texture or 0, true)
        else
            ClearPedProp(ped, prop)
        end
    end

    SavedOutfit = nil
    UniformApplied = false
end

local function drawText3D(coords, text)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    SetTextFont(4)
    SetTextScale(0.35, 0.35)
    SetTextColour(255, 255, 255, 215)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

local function createDepotBlip()
    if DepotBlip and DoesBlipExist(DepotBlip) then
        return
    end

    local cfg = Config.DepotBlip
    DepotBlip = AddBlipForCoord(Config.Depot.x, Config.Depot.y, Config.Depot.z)
    SetBlipSprite(DepotBlip, cfg.sprite)
    SetBlipDisplay(DepotBlip, 4)
    SetBlipScale(DepotBlip, cfg.scale)
    SetBlipColour(DepotBlip, cfg.colour)
    SetBlipAsShortRange(DepotBlip, cfg.shortRange)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(cfg.name)
    EndTextCommandSetBlipName(DepotBlip)
end

local function createRouteBlip(stop, label)
    RouteBlip = removeBlip(RouteBlip)
    local cfg = Config.RouteBlip
    RouteBlip = AddBlipForCoord(stop.x, stop.y, stop.z)
    SetBlipSprite(RouteBlip, cfg.sprite)
    SetBlipDisplay(RouteBlip, 4)
    SetBlipScale(RouteBlip, cfg.scale)
    SetBlipColour(RouteBlip, cfg.colour)
    SetBlipRoute(RouteBlip, true)
    SetBlipRouteColour(RouteBlip, cfg.colour)
    SetBlipAsShortRange(RouteBlip, cfg.shortRange)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(label or cfg.name)
    EndTextCommandSetBlipName(RouteBlip)
end

local function loadModel(model)
    local hash = type(model) == "number" and model or GetHashKey(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then
        return nil
    end

    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do
        Wait(50)
    end

    if not HasModelLoaded(hash) then
        return nil
    end

    return hash
end

local function findFreeSpawn()
    for _, spawn in ipairs(Config.Spawns or {}) do
        local occupied = IsAnyVehicleNearPoint(spawn.x, spawn.y, spawn.z, 4.0)
        if not occupied then
            local closest = GetClosestVehicle(spawn.x, spawn.y, spawn.z, 4.0, 0, 71)
            occupied = closest and closest ~= 0 and DoesEntityExist(closest)
        end

        if not occupied then
            return spawn
        end
    end

    return nil
end

local function getBusVehicle()
    if BusVehicle ~= 0 and DoesEntityExist(BusVehicle) then
        return BusVehicle
    end

    if BusNetId and NetworkDoesNetworkIdExist(BusNetId) then
        local vehicle = NetToVeh(BusNetId)
        if vehicle ~= 0 and DoesEntityExist(vehicle) then
            BusVehicle = vehicle
            return vehicle
        end
    end

    return 0
end

local function deletePassenger()
    if Passenger ~= 0 and DoesEntityExist(Passenger) then
        ClearPedTasksImmediately(Passenger)
        SetEntityAsMissionEntity(Passenger, true, true)
        DeletePed(Passenger)
        if DoesEntityExist(Passenger) then
            DeleteEntity(Passenger)
        end
    end

    Passenger = 0
end

local function resetRoute()
    RouteBlip = removeBlip(RouteBlip)
    deletePassenger()
    PickupIndex = 1
    DeliveryIndex = nil
    PassengerOnBoard = false
    Phase = "pickup"
    Busy = false
    RouteStarted = false
    LastPassengerSpawnAttempt = 0
end

local function cleanupBus()
    local vehicle = getBusVehicle()
    local netId = BusNetId

    resetRoute()

    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        NetworkRequestControlOfEntity(vehicle)
        local timeout = GetGameTimer() + 1000
        while not NetworkHasControlOfEntity(vehicle) and GetGameTimer() < timeout do
            Wait(0)
            NetworkRequestControlOfEntity(vehicle)
        end

        SetEntityAsMissionEntity(vehicle, true, true)
        DeleteVehicle(vehicle)
        if DoesEntityExist(vehicle) then
            DeleteEntity(vehicle)
        end
    end

    if netId then
        pcall(function()
            vSERVER.ReleaseVehicle(netId)
        end)
    end

    BusVehicle = 0
    BusNetId = nil
end

local function findPassengerSpawn(stop)
    local offset = Config.PassengerSidewalkOffset or 3.0
    local heading = math.rad(stop.w or 0.0)
    local rightX, rightY = math.cos(heading), math.sin(heading)
    local forwardX, forwardY = -math.sin(heading), math.cos(heading)
    local candidates = {
        { x = stop.x + rightX * offset, y = stop.y + rightY * offset },
        { x = stop.x - rightX * offset, y = stop.y - rightY * offset },
        { x = stop.x + forwardX * offset, y = stop.y + forwardY * offset },
        { x = stop.x - forwardX * offset, y = stop.y - forwardY * offset }
    }
    local fallback = vector3(stop.x, stop.y, stop.z)

    for _, candidate in ipairs(candidates) do
        RequestCollisionAtCoord(candidate.x, candidate.y, stop.z)
        local foundGround, groundZ = GetGroundZFor_3dCoord(candidate.x, candidate.y, stop.z + 5.0, true)
        if foundGround then
            local foundSafe, safeCoords = GetSafeCoordForPed(candidate.x, candidate.y, groundZ, false, 16)
            if foundSafe then
                fallback = safeCoords
                if not IsPointOnRoad(safeCoords.x, safeCoords.y, safeCoords.z, 0) then
                    return safeCoords
                end
            end
        end
    end

    return fallback
end

local function spawnPassenger(stopIndex)
    deletePassenger()

    local stop = Config.Stops[stopIndex]
    if not stop then
        return false
    end

    local models = Config.PassengerModels or {}
    local model = models[math.random(1, #models)]
    local hash = loadModel(model)
    if not hash then
        notify("vermelho", "Nao foi possivel carregar o passageiro desta parada.")
        return false
    end

    local spawnCoords = findPassengerSpawn(stop)

    Passenger = CreatePed(4, hash, spawnCoords.x, spawnCoords.y, spawnCoords.z, stop.w, true, true)
    if Passenger == 0 or not DoesEntityExist(Passenger) then
        SetModelAsNoLongerNeeded(hash)
        return false
    end

    SetEntityAsMissionEntity(Passenger, true, true)
    SetEntityCoordsNoOffset(Passenger, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false)
    FreezeEntityPosition(Passenger, true)
    SetEntityInvincible(Passenger, true)
    SetEntityAlpha(Passenger, 255, false)
    SetEntityVisible(Passenger, true, false)
    SetBlockingOfNonTemporaryEvents(Passenger, true)
    SetPedCanRagdoll(Passenger, false)
    SetModelAsNoLongerNeeded(hash)
    return true
end

local function startRoute()
    if RouteStarted then
        return
    end

    RouteStarted = true
    PickupIndex = 1
    DeliveryIndex = nil
    Phase = "pickup"
    createRouteBlip(Config.Stops[PickupIndex], "Embarque de Passageiro")
    notify("amarelo", "Va ate o ponto marcado para embarcar o passageiro.", 5000)
end

local function findPassengerSeat(vehicle)
    local modelSeats = GetVehicleModelNumberOfSeats(GetEntityModel(vehicle))
    local maxPassengers = math.max(0, (modelSeats or 1) - 1)
    for seat = 0, maxPassengers - 1 do
        if IsVehicleSeatFree(vehicle, seat) then
            return seat
        end
    end

    return nil
end

local function forcePassengerIntoBus(passenger, vehicle, preferredSeat)
    requestEntityControl(vehicle, 1000)
    requestEntityControl(passenger, 1000)
    SetVehicleDoorsLocked(vehicle, 1)
    SetVehicleDoorsLockedForAllPlayers(vehicle, false)

    local modelSeats = GetVehicleModelNumberOfSeats(GetEntityModel(vehicle))
    local maxPassengers = math.max(16, (modelSeats or 1) - 1)
    local seats = { preferredSeat }

    for seat = 0, maxPassengers - 1 do
        if seat ~= preferredSeat then
            seats[#seats + 1] = seat
        end
    end

    local nearDoor = GetOffsetFromEntityInWorldCoords(vehicle, 2.0, -1.5, 0.0)
    SetEntityCoordsNoOffset(passenger, nearDoor.x, nearDoor.y, nearDoor.z, false, false, false)
    Wait(50)

    for _, seat in ipairs(seats) do
        local reportedSeatCount = modelSeats or 1
        local canTrySeat = seat and (seat >= reportedSeatCount or IsVehicleSeatFree(vehicle, seat))

        if canTrySeat then
            ClearPedTasksImmediately(passenger)
            TaskWarpPedIntoVehicle(passenger, vehicle, seat)
            Wait(150)

            if not IsPedInVehicle(passenger, vehicle, false) then
                SetPedIntoVehicle(passenger, vehicle, seat)
                Wait(150)
            end

            if IsPedInVehicle(passenger, vehicle, false) or GetVehiclePedIsIn(passenger, false) == vehicle then
                return seat
            end
        end
    end

    return nil
end

local function virtualBoardPassenger(passenger, vehicle)
    if Config.VirtualPassengerFallback == false then
        return false
    end

    requestEntityControl(passenger, 1000)
    ClearPedTasksImmediately(passenger)
    SetEntityCollision(passenger, false, false)
    SetEntityVisible(passenger, false, false)
    AttachEntityToEntity(passenger, vehicle, 0, 0.0, -2.0, 1.2, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
    return true
end

local function boardPassenger()
    if Busy or PassengerOnBoard then
        return
    end

    local vehicle = getBusVehicle()
    if vehicle == 0 then
        notify("amarelo", "Retire o onibus de trabalho antes de iniciar o embarque.")
        return
    end

    if Passenger == 0 or not DoesEntityExist(Passenger) then
        spawnPassenger(PickupIndex)
        Wait(150)
    end

    if Passenger == 0 or not DoesEntityExist(Passenger) then
        notify("vermelho", "Nao foi possivel criar o passageiro desta parada.")
        return
    end

    local seat = findPassengerSeat(vehicle) or 0

    Busy = true
    FreezeEntityPosition(Passenger, false)
    SetVehicleDoorsLocked(vehicle, 1)
    TaskGoToEntity(Passenger, vehicle, -1, 3.0, 1.0, 1073741824, 0)

    local deadline = GetGameTimer() + (Config.PassengerBoardTimeoutMs or 8000)
    while DoesEntityExist(Passenger) and not IsPedInVehicle(Passenger, vehicle, false) and GetGameTimer() < deadline do
        TaskEnterVehicle(Passenger, vehicle, 1500, seat, 1.0, 1, 0)
        Wait(250)
    end

    local boardedSeat = nil
    if DoesEntityExist(Passenger) then
        boardedSeat = IsPedInVehicle(Passenger, vehicle, false) and seat or forcePassengerIntoBus(Passenger, vehicle, seat)
    end

    if not DoesEntityExist(Passenger) or not boardedSeat then
        if DoesEntityExist(Passenger) and virtualBoardPassenger(Passenger, vehicle) then
            boardedSeat = -1
        else
            Busy = false
            notify("vermelho", "O passageiro nao conseguiu entrar no onibus. Reposicione o veiculo e tente novamente.")
            return
        end
    end

    local ok = vSERVER.BoardPassenger(PickupIndex, BusNetId)
    if not ok then
        TaskLeaveVehicle(Passenger, vehicle, 0)
        Busy = false
        notify("vermelho", "O embarque nao foi validado pelo servidor.")
        return
    end

    SetPedKeepTask(Passenger, true)
    PassengerOnBoard = true
    DeliveryIndex = (PickupIndex % #Config.Stops) + 1
    Phase = "delivery"
    RouteBlip = removeBlip(RouteBlip)
    createRouteBlip(Config.Stops[DeliveryIndex], "Desembarque de Passageiro")
    notify("verde", "Passageiro embarcado. Siga ate o proximo ponto.", 5000)
    Busy = false
end

local function completeStop()
    if Busy or not PassengerOnBoard or not DeliveryIndex then
        return
    end

    Busy = true
    local ok, amount = vSERVER.CompleteStop(DeliveryIndex, BusNetId)
    if not ok then
        Busy = false
        notify("vermelho", "A parada nao foi validada pelo servidor.")
        return
    end

    local passenger = Passenger
    Passenger = 0
    if passenger ~= 0 and DoesEntityExist(passenger) then
        if IsEntityAttached(passenger) then
            DetachEntity(passenger, true, true)
        end
        SetEntityVisible(passenger, true, false)
        SetEntityCollision(passenger, true, true)
        FreezeEntityPosition(passenger, false)
        local vehicle = getBusVehicle()
        if vehicle ~= 0 and IsPedInVehicle(passenger, vehicle, false) then
            TaskLeaveVehicle(passenger, vehicle, 0)
        else
            local exitCoords = vehicle ~= 0 and GetOffsetFromEntityInWorldCoords(vehicle, 2.2, 0.0, 0.0) or GetEntityCoords(passenger)
            SetEntityCoordsNoOffset(passenger, exitCoords.x, exitCoords.y, exitCoords.z, false, false, false)
            TaskWanderStandard(passenger, 10.0, 10)
        end
        SetTimeout(30000, function()
            if DoesEntityExist(passenger) then
                DeletePed(passenger)
            end
        end)
    end

    PassengerOnBoard = false
    PickupIndex = DeliveryIndex
    DeliveryIndex = nil
    Phase = "pickup"
    RouteBlip = removeBlip(RouteBlip)
    LastPassengerSpawnAttempt = 0
    createRouteBlip(Config.Stops[PickupIndex], "Embarque de Passageiro")
    notify("verde", ("Passageiro desembarcou. Voce recebeu $%s."):format(amount or 0), 5000)
    SetTimeout(1000, function()
        Busy = false
    end)
end

local function setupBus(vehicle, plate)
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    SetVehicleNeedsToBeHotwired(vehicle, false)
    SetVehicleUndriveable(vehicle, false)
    SetVehicleNumberPlateText(vehicle, plate)
    SetVehicleDirtLevel(vehicle, 0.0)
    SetVehRadioStation(vehicle, "OFF")
    SetVehicleRadioEnabled(vehicle, false)
    SetVehicleDoorsLocked(vehicle, 1)
    SetVehicleDoorsLockedForAllPlayers(vehicle, false)
    SetVehicleDoorsLockedForPlayer(vehicle, PlayerId(), false)
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleEngineOn(vehicle, true, true, false)
    SetNetworkIdCanMigrate(BusNetId, true)
    SetNetworkIdExistsOnAllMachines(BusNetId, true)
    pcall(function()
        Entity(vehicle).state:set("Lockpick", true, true)
        Entity(vehicle).state:set("Fuel", 100, true)
    end)
end

local function spawnBus()
    if not Active then
        notify("amarelo", "Pegue o emprego de Motorista de Onibus na Central de Empregos.")
        return
    end

    if getBusVehicle() ~= 0 then
        notify("amarelo", "Voce ja possui um onibus de trabalho ativo.")
        return
    end

    local spawn = findFreeSpawn()
    if not spawn then
        notify("amarelo", "A vaga da garagem esta ocupada no momento.")
        return
    end

    if not vSERVER.ReserveSpawn() then
        notify("amarelo", "A garagem esta sendo usada por outro motorista. Aguarde alguns segundos.")
        return
    end

    local plate = ("%s%05d"):format(Config.PlatePrefix, GetPlayerServerId(PlayerId()) % 100000)
    local hash = loadModel(Config.BusModel)
    if not hash or not IsModelAVehicle(hash) then
        vSERVER.CancelSpawnReservation()
        notify("vermelho", "Modelo do onibus invalido.")
        return
    end

    BusVehicle = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.w, true, true)
    if not BusVehicle or BusVehicle == 0 or not DoesEntityExist(BusVehicle) then
        vSERVER.CancelSpawnReservation()
        SetModelAsNoLongerNeeded(hash)
        notify("vermelho", "Nao foi possivel retirar o onibus agora.")
        return
    end

    BusNetId = NetworkGetNetworkIdFromEntity(BusVehicle)
    SetModelAsNoLongerNeeded(hash)

    setupBus(BusVehicle, plate)
    if not vSERVER.RegisterVehicle(BusNetId, plate) then
        cleanupBus()
        notify("vermelho", "O servidor nao validou o onibus de trabalho.")
        return
    end

    TaskWarpPedIntoVehicle(PlayerPedId(), BusVehicle, -1)
    startRoute()
    notify("verde", "Onibus retirado. Siga o GPS para buscar passageiros.", 5000)
end

local function depotAction()
    if not Active then
        notify("amarelo", "Este veiculo so esta disponivel para Motoristas de Onibus.")
        return
    end

    if getBusVehicle() ~= 0 then
        if PassengerOnBoard then
            notify("amarelo", "Desembarque o passageiro antes de guardar o onibus.")
            return
        end

        cleanupBus()
        notify("verde", "Onibus guardado.")
        return
    end

    spawnBus()
end

RegisterNetEvent("of_busjob:depotAction")
AddEventHandler("of_busjob:depotAction", depotAction)

RegisterNetEvent("of_busjob:jobState")
AddEventHandler("of_busjob:jobState", function(active)
    Active = active == true
    if Active then
        applyBusUniform()
        createDepotBlip()
        notify("verde", "Voce entrou em servico como Motorista de Onibus.")
    else
        cleanupBus()
        restoreOutfit()
    end
end)

CreateThread(function()
    createDepotBlip()

    local timeout = GetGameTimer() + 15000
    while GetResourceState("target") ~= "started" and GetGameTimer() < timeout do
        Wait(250)
    end

    if GetResourceState("target") == "started" then
        removeLegacyBusPoint()
        exports.target:AddBoxZone("OFBusDepot", Config.Depot.xyz, 0.75, 0.75, {
            name = "OFBusDepot",
            heading = Config.Depot.w,
            minZ = Config.Depot.z - 1.0,
            maxZ = Config.Depot.z + 1.0
        }, {
            Distance = 1.75,
            options = {
                {
                    label = "Abrir garagem de onibus",
                    tunnel = "client",
                    event = "of_busjob:depotAction"
                }
            }
        })
        TargetReady = true
    end
end)

CreateThread(function()
    for _ = 1, 10 do
        removeLegacyBusPoint()
        Wait(1000)
    end
end)

CreateThread(function()
    while true do
        local wait = 1000
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local depotDistance = #(coords - vector3(Config.Depot.x, Config.Depot.y, Config.Depot.z))

        if depotDistance < 10.0 then
            wait = 0
            DrawMarker(1, Config.Depot.x, Config.Depot.y, Config.Depot.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 2.0, 0.7, 88, 101, 242, 120, false, false, 2, false, nil, nil, false)
            if depotDistance < 2.0 then
                drawText3D(Config.Depot.xyz + vector3(0.0, 0.0, 0.5), "~b~[E]~w~ GARAGEM DE ONIBUS")
                if IsControlJustPressed(0, 38) then
                    depotAction()
                end
            end
        end

        if Active then
            local vehicle = getBusVehicle()
            if vehicle ~= 0 and DoesEntityExist(vehicle) then
                local driver = GetPedInVehicleSeat(vehicle, -1)
                if driver == ped and not RouteStarted then
                    startRoute()
                end

                if driver == ped and Phase == "pickup" then
                    local stop = Config.Stops[PickupIndex]
                    local distance = #(coords - vector3(stop.x, stop.y, stop.z))

                    if Passenger == 0 and distance < (Config.PassengerSpawnDistance or 90.0) then
                        local now = GetGameTimer()
                        if now - LastPassengerSpawnAttempt >= (Config.PassengerSpawnRetryMs or 5000) then
                            LastPassengerSpawnAttempt = now
                            spawnPassenger(PickupIndex)
                        end
                    end

                    if Passenger ~= 0 and distance < 35.0 then
                        wait = 0
                        DrawMarker(1, stop.x, stop.y, stop.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 3.0, 3.0, 0.8, 88, 101, 242, 130, false, false, 2, false, nil, nil, false)
                        if distance < 12.0 then
                            drawText3D(stop.xyz + vector3(0.0, 0.0, 0.6), "~b~[E]~w~ EMBARCAR PASSAGEIRO")
                            if IsControlJustPressed(0, 38) then
                                boardPassenger()
                            end
                        end
                    end
                elseif driver == ped and Phase == "delivery" and DeliveryIndex then
                    local stop = Config.Stops[DeliveryIndex]
                    local distance = #(coords - vector3(stop.x, stop.y, stop.z))
                    if distance < 35.0 then
                        wait = 0
                        DrawMarker(1, stop.x, stop.y, stop.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 3.0, 3.0, 0.8, 88, 101, 242, 130, false, false, 2, false, nil, nil, false)
                        if distance < 12.0 then
                            drawText3D(stop.xyz + vector3(0.0, 0.0, 0.6), "~b~[E]~w~ DESEMBARCAR PASSAGEIRO")
                            if IsControlJustPressed(0, 38) then
                                completeStop()
                            end
                        end
                    end
                end
            elseif BusNetId then
                cleanupBus()
                notify("amarelo", "O onibus foi perdido e a rota foi encerrada.")
            end
        end

        Wait(wait)
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    cleanupBus()
    restoreOutfit()
    DepotBlip = removeBlip(DepotBlip)
    if TargetReady and GetResourceState("target") == "started" then
        exports.target:RemCircleZone("OFBusDepot")
    end
end)
