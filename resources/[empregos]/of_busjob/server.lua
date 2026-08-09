local Tunnel = module("vrp", "lib/Tunnel")
local Proxy = module("vrp", "lib/Proxy")

local vRP = Proxy.getInterface("vRP")
local vRPC = Tunnel.getInterface("vRP")
local Bus = {}

Tunnel.bindInterface("of_busjob", Bus)

local ActiveJobs = {}
local Vehicles = {}
local Routes = {}
local PaymentCooldown = {}
local SpawnReservation = {
    source = nil,
    expiresAt = 0
}

local function passport(source)
    if vRP.Passport then
        return vRP.Passport(source)
    end

    if vRP.getUserId then
        return vRP.getUserId(source)
    end

    return nil
end

local function distanceBetween(first, second)
    if not first or not second then
        return math.huge
    end

    return #(first - second)
end

local function notify(source, kind, message)
    TriggerClientEvent("Notify", source, kind or "amarelo", message, 5000)
end

local function releaseSpawnReservation(playerSource)
    if not playerSource or SpawnReservation.source == playerSource then
        SpawnReservation.source = nil
        SpawnReservation.expiresAt = 0
    end
end

local function getVehicle(netId)
    local id = tonumber(netId)
    if not id or id <= 0 then
        return 0
    end

    local vehicle = NetworkGetEntityFromNetworkId(id)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return 0
    end

    if GetEntityModel(vehicle) ~= GetHashKey(Config.BusModel) then
        return 0
    end

    return vehicle
end

local function waitVehicle(netId)
    local timeout = GetGameTimer() + 5000
    local vehicle = getVehicle(netId)

    while vehicle == 0 and GetGameTimer() < timeout do
        Wait(100)
        vehicle = getVehicle(netId)
    end

    return vehicle
end

local function playerInVehicle(source, vehicle)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return false
    end

    return GetVehiclePedIsIn(ped, false) == vehicle and GetPedInVehicleSeat(vehicle, -1) == ped
end

local function clearVehicle(source)
    local data = Vehicles[source]
    if data and data.netId then
        local vehicle = NetworkGetEntityFromNetworkId(data.netId)
        if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
            DeleteEntity(vehicle)
        end
    end

    Vehicles[source] = nil
    Routes[source] = nil
    PaymentCooldown[source] = nil
end

local function sendJobState(source, active)
    TriggerClientEvent("of_busjob:jobState", source, active == true)
end

function Bus.RegisterVehicle(netId, plate)
    local source = source
    if not ActiveJobs[source] then
        releaseSpawnReservation(source)
        return false
    end

    if SpawnReservation.source ~= source or SpawnReservation.expiresAt < os.time() then
        releaseSpawnReservation(source)
        return false
    end

    local vehicle = waitVehicle(netId)
    if vehicle == 0 then
        releaseSpawnReservation(source)
        return false
    end

    local coords = GetEntityCoords(vehicle)
    if distanceBetween(coords, vector3(Config.Depot.x, Config.Depot.y, Config.Depot.z)) > 20.0 then
        releaseSpawnReservation(source)
        return false
    end

    clearVehicle(source)

    local Passport = passport(source)
    Vehicles[source] = {
        netId = tonumber(netId),
        plate = tostring(plate or "")
    }
    Routes[source] = {
        pickup = 1,
        passenger = false,
        delivery = nil
    }

    Entity(vehicle).state:set("Lockpick", Passport or true, true)
    Entity(vehicle).state:set("Fuel", 100, true)
    SetVehicleDoorsLocked(vehicle, 1)
    releaseSpawnReservation(source)

    if Config.Debug then
        print(("[of_busjob] onibus registrado source=%s netId=%s"):format(source, tostring(netId)))
    end

    return true
end

function Bus.ReserveSpawn()
    local source = source
    if not ActiveJobs[source] or Vehicles[source] then
        return false
    end

    local now = os.time()
    if SpawnReservation.source and SpawnReservation.expiresAt >= now and SpawnReservation.source ~= source then
        return false
    end

    SpawnReservation.source = source
    SpawnReservation.expiresAt = now + (Config.SpawnReservationSeconds or 10)
    return true
end

function Bus.CancelSpawnReservation()
    releaseSpawnReservation(source)
    return true
end

function Bus.ReleaseVehicle(netId)
    local source = source
    local data = Vehicles[source]
    if not data then
        return true
    end

    if netId and tonumber(netId) ~= tonumber(data.netId) then
        return false
    end

    clearVehicle(source)
    return true
end

function Bus.BoardPassenger(stopIndex, netId)
    local source = source
    local data = Vehicles[source]
    local route = Routes[source]
    local vehicle = data and getVehicle(data.netId) or 0
    local index = tonumber(stopIndex)
    local stop = index and Config.Stops[index]

    if not ActiveJobs[source] or not data or tonumber(netId) ~= tonumber(data.netId) or vehicle == 0 then
        return false
    end

    if not route or route.passenger or route.pickup ~= index or not stop then
        return false
    end

    if not playerInVehicle(source, vehicle) then
        return false
    end

    local ped = GetPlayerPed(source)
    if distanceBetween(GetEntityCoords(ped), vector3(stop.x, stop.y, stop.z)) > Config.Payment.stopDistance then
        return false
    end

    route.passenger = true
    route.delivery = (index % #Config.Stops) + 1
    return true
end

function Bus.CompleteStop(stopIndex, netId)
    local source = source
    local data = Vehicles[source]
    local route = Routes[source]
    local vehicle = data and getVehicle(data.netId) or 0
    local index = tonumber(stopIndex)
    local stop = index and Config.Stops[index]

    if not ActiveJobs[source] or not data or tonumber(netId) ~= tonumber(data.netId) or vehicle == 0 then
        return false, 0
    end

    if not route or not route.passenger or route.delivery ~= index or not stop then
        return false, 0
    end

    if not playerInVehicle(source, vehicle) then
        return false, 0
    end

    local ped = GetPlayerPed(source)
    if distanceBetween(GetEntityCoords(ped), vector3(stop.x, stop.y, stop.z)) > Config.Payment.stopDistance then
        return false, 0
    end

    local now = os.time()
    if PaymentCooldown[source] and now - PaymentCooldown[source] < (Config.Payment.cooldown or 3) then
        return false, 0
    end

    local Passport = passport(source)
    if not Passport then
        return false, 0
    end

    local amount = math.random(Config.Payment.min, Config.Payment.max)
    PaymentCooldown[source] = now
    route.passenger = false
    route.pickup = index
    route.delivery = nil

    vRP.GenerateItem(Passport, "dollar", amount, true)
    TriggerClientEvent("vrp_sound:source", source, "dinheiro", 0.3)

    if Config.Debug then
        print(("[of_busjob] pagamento source=%s valor=%s parada=%s"):format(source, amount, index))
    end

    return true, amount
end

AddEventHandler("cfWorks:jobChanged", function(playerSource, jobId)
    local active = jobId == Config.JobId
    ActiveJobs[playerSource] = active or nil

    if not active then
        clearVehicle(playerSource)
    end

    sendJobState(playerSource, active)
end)

AddEventHandler("cfWorks:playerDropped", function(playerSource)
    ActiveJobs[playerSource] = nil
    releaseSpawnReservation(playerSource)
    clearVehicle(playerSource)
end)

AddEventHandler("playerDropped", function()
    ActiveJobs[source] = nil
    releaseSpawnReservation(source)
    clearVehicle(source)
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    for playerSource in pairs(Vehicles) do
        clearVehicle(playerSource)
    end
end)
