local garbageVehicle = 0
local ownsGarbageVehicle = false
local routeBlip = nil
local routeIndex = 1
local routeActive = false
local collecting = false
local savedClothes = nil
local uniformApplied = false
local fixedBlips = {}
local duoActive = false
local duoRole = nil
local duoVehicleNetId = nil
local rearAttached = false

local function notify(kind, message, duration)
    TriggerEvent("Notify", kind, message, duration or 5000)
end

local function drawText3D(x, y, z, text)
    local onScreen, screenX, screenY = World3dToScreen2d(x, y, z)
    if not onScreen then
        return
    end

    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextCentre(1)
    SetTextOutline()
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(screenX, screenY)
end

local function removeRouteBlip()
    if routeBlip and DoesBlipExist(routeBlip) then
        SetBlipRoute(routeBlip, false)
        RemoveBlip(routeBlip)
    end

    routeBlip = nil
end

local function updateRouteBlip()
    removeRouteBlip()

    local points = Config.Garbage.routePoints or {}
    local point = points[routeIndex]
    if not point then
        return
    end

    routeBlip = AddBlipForCoord(point.x, point.y, point.z)
    SetBlipSprite(routeBlip, 318)
    SetBlipDisplay(routeBlip, 4)
    SetBlipScale(routeBlip, 0.8)
    SetBlipColour(routeBlip, 5)
    SetBlipAsShortRange(true)
    SetBlipRoute(routeBlip, true)
    SetBlipRouteColour(routeBlip, 5)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(("Coleta de lixo %s/%s"):format(routeIndex, #points))
    EndTextCommandSetBlipName(routeBlip)
end

local function debugDuo(message)
    if Config.Debug or (Config.GarbageDuo and Config.GarbageDuo.Debug) then
        print(("[garbage-duo] %s"):format(message))
    end
end

local function getDuoVehicle()
    if duoVehicleNetId then
        local vehicle = NetToVeh(duoVehicleNetId)
        if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
            garbageVehicle = vehicle
            return vehicle
        end
    end

    if garbageVehicle ~= 0 and DoesEntityExist(garbageVehicle) then
        return garbageVehicle
    end

    return 0
end

local function activateRoute()
    if routeActive then
        return
    end

    if #(Config.Garbage.routePoints or {}) <= 0 then
        return
    end

    routeActive = true
    routeIndex = 1
    updateRouteBlip()
    notify("verde", "Rota de coleta iniciada. Siga o GPS e saia do caminhao no ponto.", 5000)
end

local function detachRearRide()
    if not rearAttached then
        return
    end

    local ped = PlayerPedId()
    local vehicle = getDuoVehicle()
    DetachEntity(ped, true, true)
    SetEntityCollision(ped, true, true)

    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        local drop = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, -3.0, 0.25)
        SetEntityCoords(ped, drop.x, drop.y, drop.z, false, false, false, false)
    end

    ClearPedTasks(ped)
    rearAttached = false
end

local function clearDuoState()
    local previousRole = duoRole
    detachRearRide()
    duoActive = false
    duoRole = nil
    duoVehicleNetId = nil

    if not ownsGarbageVehicle then
        garbageVehicle = 0
    elseif previousRole == "collector" then
        garbageVehicle = 0
    end

    if previousRole == "collector" then
        routeActive = false
        routeIndex = 1
        removeRouteBlip()
    end

    debugDuo("estado da dupla limpo")
end

local function captureClothes(ped)
    local clothes = { components = {}, props = {} }

    for component = 0, 11 do
        clothes.components[component] = {
            drawable = GetPedDrawableVariation(ped, component),
            texture = GetPedTextureVariation(ped, component),
            palette = GetPedPaletteVariation(ped, component)
        }
    end

    for prop = 0, 7 do
        clothes.props[prop] = {
            drawable = GetPedPropIndex(ped, prop),
            texture = GetPedPropTextureIndex(ped, prop)
        }
    end

    return clothes
end

local function restoreClothes()
    if not savedClothes then
        return
    end

    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then
        return
    end

    for component, data in pairs(savedClothes.components) do
        SetPedComponentVariation(ped, component, data.drawable, data.texture, data.palette or 0)
    end

    for prop, data in pairs(savedClothes.props) do
        if data.drawable and data.drawable >= 0 then
            SetPedPropIndex(ped, prop, data.drawable, data.texture or 0, true)
        else
            ClearPedProp(ped, prop)
        end
    end

    savedClothes = nil
    uniformApplied = false
end

local function applyGarbageUniform()
    local ped = PlayerPedId()
    if not savedClothes then
        savedClothes = captureClothes(ped)
    end

    SetPedComponentVariation(ped, 8, 59, 0, 0)   -- Camiseta
    SetPedComponentVariation(ped, 11, 89, 0, 0)  -- Jaqueta
    SetPedComponentVariation(ped, 4, 120, 1, 0)  -- Calca
    SetPedComponentVariation(ped, 6, 52, 1, 0)   -- Sapatos
    uniformApplied = true

    notify("verde", "Uniforme de lixeiro aplicado.", 4000)
end

local function deleteGarbageVehicle()
    if not ownsGarbageVehicle then
        garbageVehicle = 0
        return
    end

    if garbageVehicle == 0 or not DoesEntityExist(garbageVehicle) then
        TriggerServerEvent("cfWorks:lixeiroTruckGone", duoVehicleNetId)
        garbageVehicle = 0
        ownsGarbageVehicle = false
        return
    end

    local networkId = duoVehicleNetId or NetworkGetNetworkIdFromEntity(garbageVehicle)
    TriggerServerEvent("cfWorks:lixeiroTruckGone", networkId)

    NetworkRequestControlOfEntity(garbageVehicle)
    local timeout = GetGameTimer() + 1000
    while not NetworkHasControlOfEntity(garbageVehicle) and GetGameTimer() < timeout do
        Wait(0)
        NetworkRequestControlOfEntity(garbageVehicle)
    end

    SetEntityAsMissionEntity(garbageVehicle, true, true)
    DeleteVehicle(garbageVehicle)
    if DoesEntityExist(garbageVehicle) then
        DeleteEntity(garbageVehicle)
    end

    garbageVehicle = 0
    ownsGarbageVehicle = false
end

local function cleanupLixeiro()
    removeRouteBlip()
    routeActive = false
    routeIndex = 1
    collecting = false
    deleteGarbageVehicle()
    clearDuoState()
    restoreClothes()
end

local function findFreeSpawn()
    for _, spawn in ipairs(Config.Garbage.spawns or {}) do
        local occupied = IsAnyVehicleNearPoint(spawn.x, spawn.y, spawn.z, 3.5)
        if not occupied then
            local closest = GetClosestVehicle(spawn.x, spawn.y, spawn.z, 3.5, 0, 71)
            occupied = closest and closest ~= 0 and DoesEntityExist(closest)
        end

        if not occupied then
            return spawn
        end
    end

    return nil
end

local function requestVehicleModel(model)
    local hash = GetHashKey(model)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
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

local function spawnGarbageTruck()
    if ActiveJob ~= "lixeiro" then
        notify("amarelo", "Voce precisa estar em servico como Lixeiro para retirar o caminhao.")
        return
    end

    if garbageVehicle ~= 0 and DoesEntityExist(garbageVehicle) then
        notify("amarelo", "Voce ja possui um caminhao de lixo em servico.")
        return
    end

    if vSERVER and vSERVER.LixeiroCanSpawn and not vSERVER.LixeiroCanSpawn() then
        notify("vermelho", "Seu servico de Lixeiro ainda nao foi registrado pelo servidor.")
        return
    end

    local spawn = findFreeSpawn()
    if not spawn then
        notify("amarelo", "Todas as vagas da garagem estao ocupadas no momento.")
        return
    end

    local hash = requestVehicleModel(Config.Garbage.model)
    if not hash then
        notify("vermelho", "Modelo do caminhao de lixo invalido.")
        return
    end

    local plate = ("LIX%05d"):format(GetPlayerServerId(PlayerId()) % 100000)
    local vehicle = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.w, true, true)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        SetModelAsNoLongerNeeded(hash)
        notify("vermelho", "Nao foi possivel retirar o caminhao de lixo agora.")
        return
    end

    local networkId = NetworkGetNetworkIdFromEntity(vehicle)
    SetNetworkIdCanMigrate(networkId, true)
    SetNetworkIdExistsOnAllMachines(networkId, true)

    garbageVehicle = vehicle
    ownsGarbageVehicle = true
    duoVehicleNetId = networkId
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    SetVehicleNeedsToBeHotwired(vehicle, false)
    SetVehicleUndriveable(vehicle, false)
    SetVehicleDoorsLocked(vehicle, 1)
    SetVehicleDoorsLockedForAllPlayers(vehicle, false)
    SetVehicleDoorsLockedForPlayer(vehicle, PlayerId(), false)
    pcall(function()
        Entity(vehicle).state:set("Lockpick", true, true)
    end)
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleNumberPlateText(vehicle, plate)
    SetVehicleColours(vehicle, 27, 27)
    SetVehicleCustomPrimaryColour(vehicle, 220, 0, 0)
    SetVehicleCustomSecondaryColour(vehicle, 220, 0, 0)
    SetVehicleDirtLevel(vehicle, 0.0)
    SetVehRadioStation(vehicle, "OFF")
    SetVehicleRadioEnabled(vehicle, false)
    SetVehicleNeedsToBeHotwired(vehicle, false)
    SetVehicleDoorsLocked(vehicle, 1)
    SetVehicleDoorsLockedForAllPlayers(vehicle, false)
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleEngineOn(vehicle, true, true, false)
    SetModelAsNoLongerNeeded(hash)

    TriggerServerEvent("cfWorks:lixeiroTruckReady", duoVehicleNetId, plate)

    notify("verde", "Caminhao de lixo retirado. Entre nele para iniciar a rota.", 5000)
end

local function collectAtRoute()
    if collecting or not routeActive then
        return
    end

    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) or garbageVehicle == 0 or not DoesEntityExist(garbageVehicle) then
        return
    end

    collecting = true
    local dict, anim = table.unpack(Config.Garbage.anim or { "amb@prop_human_bum_bin@base", "base" })
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end

    TaskPlayAnim(ped, dict, anim, 8.0, 8.0, 5000, 1, 0, false, false, false)
    TriggerEvent("progress", 5000, "Coletando lixo...")
    Wait(5000)
    ClearPedTasks(ped)

    if ActiveJob == "lixeiro" and garbageVehicle ~= 0 and DoesEntityExist(garbageVehicle) then
        local networkId = duoVehicleNetId or NetworkGetNetworkIdFromEntity(garbageVehicle)
        TriggerServerEvent("cfWorks:lixeiroReward", routeIndex, networkId)
        local points = Config.Garbage.routePoints or {}
        routeIndex = routeIndex + 1
        if routeIndex > #points then
            routeIndex = 1
        end
        updateRouteBlip()
    end

    collecting = false
end

local function createFixedBlip(coords, sprite, colour, name)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.8)
    SetBlipColour(blip, colour)
    SetBlipAsShortRange(false)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(name)
    EndTextCommandSetBlipName(blip)
    return blip
end

local function ensureFixedBlips()
    local garbage = Config.Garbage
    if ActiveJob == "lixeiro" then
        if not fixedBlips.garage or not DoesBlipExist(fixedBlips.garage) then
            fixedBlips.garage = createFixedBlip(garbage.garage, 318, 5, "Central Lixeiros")
        end
    elseif fixedBlips.garage and DoesBlipExist(fixedBlips.garage) then
        RemoveBlip(fixedBlips.garage)
        fixedBlips.garage = nil
    end
end

CreateThread(function()
    while true do
        ensureFixedBlips()
        Wait(5000)
    end
end)

CreateThread(function()
    local wasLixeiro = false

    while true do
        local isLixeiro = ActiveJob == "lixeiro"

        if isLixeiro and not wasLixeiro then
            applyGarbageUniform()
        elseif not isLixeiro and wasLixeiro then
            restoreClothes()
        end

        wasLixeiro = isLixeiro
        Wait(250)
    end
end)

CreateThread(function()
    while true do
        local wait = 1000
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)

        if ActiveJob == "lixeiro" then
            local garage = Config.Garbage.garage
            local garageDistance = #(coords - vec3(garage.x, garage.y, garage.z))

            if garageDistance < 12.0 then
                wait = 0
                DrawMarker(1, garage.x, garage.y, garage.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 2.0, 0.7, 220, 0, 0, 120, false, false, 2, false, nil, nil, false)
                if garageDistance < 2.0 then
                    drawText3D(garage.x, garage.y, garage.z + 0.4, "~r~[E]~w~ RETIRAR CAMINHAO DE LIXO")
                    if IsControlJustPressed(0, 38) then
                        spawnGarbageTruck()
                    end
                end
            end

        end

        Wait(wait)
    end
end)

CreateThread(function()
    while true do
        local wait = 1000
        if ActiveJob == "lixeiro" and (garbageVehicle ~= 0 or (duoActive and duoVehicleNetId)) then
            local sharedVehicle = getDuoVehicle()
            if sharedVehicle == 0 or not DoesEntityExist(sharedVehicle) then
                garbageVehicle = 0
                if not (duoActive and duoRole == "collector") then
                    removeRouteBlip()
                    routeActive = false
                else
                    wait = 500
                end
            else
                local ped = PlayerPedId()
                if rearAttached and (not duoActive or GetEntitySpeed(sharedVehicle) > 12.0 or IsEntityUpsidedown(sharedVehicle)) then
                    detachRearRide()
                end

                if IsPedInVehicle(ped, sharedVehicle, false) then
                    activateRoute()
                elseif routeActive then
                    local point = (Config.Garbage.routePoints or {})[routeIndex]
                    if point then
                        local coords = GetEntityCoords(ped)
                        local distance = #(coords - point)
                        if distance < 20.0 then
                            wait = 0
                            DrawMarker(1, point.x, point.y, point.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 2.0, 0.6, 220, 0, 0, 150, false, false, 2, false, nil, nil, false)
                            if distance < 2.0 then
                                drawText3D(point.x, point.y, point.z + 0.5, "~r~[E]~w~ COLETAR LIXO")
                                if IsControlJustPressed(0, 38) then
                                    collectAtRoute()
                                end
                            end
                        end
                    end
                end
            end
        end

        Wait(wait)
    end
end)

RegisterNetEvent("cfWorks:garbageDuoInvite")
AddEventHandler("cfWorks:garbageDuoInvite", function(driverPassport, expiresIn)
    notify("amarelo", ("Voce foi convidado para ser COLETOR do Lixeiro pelo passaporte %s. Use /%s em ate %ss."):format(driverPassport, Config.GarbageDuo.AcceptCommand, expiresIn or Config.GarbageDuo.InviteTimeout), 8000)
end)

RegisterNetEvent("cfWorks:garbageDuoState")
AddEventHandler("cfWorks:garbageDuoState", function(state)
    if not state or not state.active then
        clearDuoState()
        if state and state.reason then
            notify("amarelo", state.reason, 5000)
        end
        return
    end

    duoActive = true
    duoRole = state.role
    duoVehicleNetId = tonumber(state.vehicleNetId)

    if duoRole == "collector" then
        ownsGarbageVehicle = false
        garbageVehicle = 0
        activateRoute()
    elseif garbageVehicle ~= 0 and DoesEntityExist(garbageVehicle) then
        ownsGarbageVehicle = true
    end

    debugDuo(("dupla ativa: papel=%s veiculo=%s"):format(duoRole or "?", duoVehicleNetId or "?"))
end)

RegisterCommand(Config.GarbageDuo.RearRideCommand, function()
    if not Config.GarbageDuo.EnableRearRide then
        notify("amarelo", "O modo pendurado na traseira esta desativado.")
        return
    end

    if not duoActive or duoRole ~= "collector" then
        notify("amarelo", "Somente o coletor de uma dupla pode usar este comando.")
        return
    end

    if rearAttached then
        detachRearRide()
        notify("verde", "Voce desceu da traseira do caminhao.", 3000)
        return
    end

    local vehicle = getDuoVehicle()
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        notify("vermelho", "O caminhao da dupla nao foi encontrado.")
        return
    end

    if GetEntitySpeed(vehicle) > 5.0 or IsEntityUpsidedown(vehicle) then
        notify("amarelo", "O caminhao precisa estar parado e em pe.")
        return
    end

    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        notify("amarelo", "Saia do caminhao antes de usar a traseira.")
        return
    end

    local dict = "amb@world_human_hang_out_street@male_c@base"
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end

    SetEntityCollision(ped, false, false)
    AttachEntityToEntity(ped, vehicle, 0, 0.0, -2.45, 0.75, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
    TaskPlayAnim(ped, dict, "base", 8.0, 8.0, -1, 1, 0.0, false, false, false)
    rearAttached = true
    notify("verde", "Voce subiu na traseira. Use /"..Config.GarbageDuo.RearRideCommand.." novamente para descer.", 4000)
end, false)

RegisterNetEvent("cfWorks:cleanupLixeiro")
AddEventHandler("cfWorks:cleanupLixeiro", function()
    cleanupLixeiro()
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    cleanupLixeiro()
    for _, blip in pairs(fixedBlips) do
        if blip and DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
end)
