local GarbageDuoSessions = {}
local GarbageDuoByPlayer = {}
local GarbageDuoInvites = {}
local GarbageDuoInviteByDriver = {}
local GarbageTrucks = {}
local GarbageRewardCooldown = {}

local function duoDebug(message)
    if Config.Debug or (Config.GarbageDuo and Config.GarbageDuo.Debug) then
        print(("[garbage-duo] %s"):format(message))
    end
end

local function duoNotify(source, message, kind)
    if source and GetPlayerPed(source) ~= 0 then
        TriggerClientEvent("Notify", source, kind or "amarelo", message, 5000)
    end
end

local function isLixeiro(source)
    return source and CfWorksActiveJobs and CfWorksActiveJobs[source] == "lixeiro"
end

local function playerCoords(source)
    local ped = source and GetPlayerPed(source)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return nil
    end

    return GetEntityCoords(ped)
end

local function distanceBetween(first, second)
    if not first or not second then
        return math.huge
    end

    return #(first - second)
end

local function nearGarbageSpawn(coords)
    for _, spawn in ipairs(Config.Garbage.spawns or {}) do
        if distanceBetween(coords, vector3(spawn.x, spawn.y, spawn.z)) <= 8.0 then
            return true
        end
    end

    return false
end

local function networkVehicle(netId)
    netId = tonumber(netId)
    if not netId or netId <= 0 then
        return 0
    end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return 0
    end

    if GetEntityModel(vehicle) ~= GetHashKey(Config.Garbage.model) then
        return 0
    end

    return vehicle
end

local function waitNetworkVehicle(netId)
    local timeout = GetGameTimer() + 5000
    local vehicle = networkVehicle(netId)

    while vehicle == 0 and GetGameTimer() < timeout do
        Wait(100)
        vehicle = networkVehicle(netId)
    end

    return vehicle
end

local function playerSession(source)
    local sessionId = GarbageDuoByPlayer[source]
    return sessionId and GarbageDuoSessions[sessionId] or nil
end

local function sendDuoState(session, active, reason)
    local state = {
        active = active,
        reason = reason
    }

    if active then
        state.vehicleNetId = session.vehicleNetId
    end

    if session.driverSource and GetPlayerPed(session.driverSource) ~= 0 then
        state.role = active and "driver" or nil
        TriggerClientEvent("cfWorks:garbageDuoState", session.driverSource, state)
    end

    if session.collectorSource and GetPlayerPed(session.collectorSource) ~= 0 then
        state.role = active and "collector" or nil
        TriggerClientEvent("cfWorks:garbageDuoState", session.collectorSource, state)
    end
end

local function clearDriverInvite(driverSource)
    local targetSource = GarbageDuoInviteByDriver[driverSource]
    if targetSource then
        GarbageDuoInvites[targetSource] = nil
        GarbageDuoInviteByDriver[driverSource] = nil
    end
end

local function cancelDuo(sessionId, reason)
    local session = GarbageDuoSessions[sessionId]
    if not session then
        return
    end

    sendDuoState(session, false, reason)
    GarbageDuoSessions[sessionId] = nil
    GarbageDuoByPlayer[session.driverSource] = nil
    GarbageDuoByPlayer[session.collectorSource] = nil
    duoDebug(("dupla cancelada: driver=%s collector=%s motivo=%s"):format(session.driverSource, session.collectorSource, reason or "sem motivo"))
end

local function cancelDuoForPlayer(source, reason)
    local sessionId = GarbageDuoByPlayer[source]
    if sessionId then
        cancelDuo(sessionId, reason)
    end
end

local function validateTruckFor(source, expectedNetId)
    local truck = GarbageTrucks[source]
    if not truck or tonumber(truck.netId) ~= tonumber(expectedNetId) then
        return nil, 0
    end

    local vehicle = networkVehicle(truck.netId)
    if vehicle == 0 then
        return nil, 0
    end

    return truck, vehicle
end

local function validateDuoForPayment(session, vehicle)
    if not session or not vehicle then
        return false, "Dupla de lixeiro invalida."
    end

    if not isLixeiro(session.driverSource) or not isLixeiro(session.collectorSource) then
        return false, "A dupla foi cancelada porque um jogador saiu do servico."
    end

    local driverPed = GetPlayerPed(session.driverSource)
    local collectorPed = GetPlayerPed(session.collectorSource)
    if driverPed == 0 or collectorPed == 0 then
        return false, "A dupla de lixeiro nao esta mais online."
    end

    local vehicleCoords = GetEntityCoords(vehicle)
    local driverCoords = GetEntityCoords(driverPed)
    local collectorCoords = GetEntityCoords(collectorPed)
    local config = Config.GarbageDuo

    if distanceBetween(driverCoords, vehicleCoords) > config.TruckDistance then
        return false, "O pagamento compartilhado foi negado: motorista longe do caminhao."
    end

    if distanceBetween(collectorCoords, vehicleCoords) > config.TruckDistance then
        return false, "O pagamento compartilhado foi negado: coletor longe do caminhao."
    end

    if distanceBetween(driverCoords, collectorCoords) > config.MaxSeparation then
        return false, "O pagamento compartilhado foi negado: jogadores muito afastados."
    end

    if config.DriverMustBeInTruck then
        local driverVehicle = GetVehiclePedIsIn(driverPed, false)
        if driverVehicle ~= vehicle then
            return false, "O pagamento compartilhado foi negado: motorista fora do caminhao."
        end
    end

    return true
end

RegisterServerEvent("cfWorks:lixeiroTruckReady")
AddEventHandler("cfWorks:lixeiroTruckReady", function(netId, plate)
    local source = source
    if not isLixeiro(source) then
        return
    end

    local vehicle = waitNetworkVehicle(netId)
    if vehicle == 0 then
        duoDebug(("caminhao rejeitado: source=%s netId=%s"):format(source, tostring(netId)))
        return
    end

    if not nearGarbageSpawn(GetEntityCoords(vehicle)) then
        duoDebug(("caminhao rejeitado fora das vagas: source=%s"):format(source))
        return
    end

    if playerSession(source) then
        cancelDuoForPlayer(source, "A dupla foi cancelada porque o motorista trocou de caminhao.")
    end

    GarbageTrucks[source] = {
        netId = tonumber(netId),
        plate = tostring(plate or "")
    }

    local passport = vRP.Passport and vRP.Passport(source) or vRP.getUserId(source)
    if passport then
        Entity(vehicle).state:set("Lockpick", passport, true)
    end
    SetVehicleDoorsLocked(vehicle, 1)
    duoDebug(("caminhao registrado: source=%s netId=%s"):format(source, tostring(netId)))
end)

RegisterServerEvent("cfWorks:lixeiroTruckGone")
AddEventHandler("cfWorks:lixeiroTruckGone", function(netId)
    local source = source
    local truck = GarbageTrucks[source]
    if not truck then
        return
    end

    if not netId or tonumber(netId) == tonumber(truck.netId) then
        GarbageTrucks[source] = nil
        cancelDuoForPlayer(source, "Dupla cancelada porque o caminhao nao foi encontrado.")
    end
end)

RegisterCommand(Config.GarbageDuo.InviteCommand, function(source, args)
    if not Config.GarbageDuo.Enabled then
        return
    end

    local targetPassport = tonumber(args[1])
    local driverPassport = vRP.getUserId(source)
    if not targetPassport or not driverPassport then
        duoNotify(source, "Use: /"..Config.GarbageDuo.InviteCommand.." [id/passaporte]", "amarelo")
        return
    end

    local targetSource = vRP.getUserSource(targetPassport)
    if not targetSource or targetSource == source then
        duoNotify(source, "Jogador offline ou invalido.", "vermelho")
        return
    end

    if not isLixeiro(source) or not isLixeiro(targetSource) then
        duoNotify(source, "Os dois jogadores precisam estar em servico como Lixeiro.", "amarelo")
        return
    end

    if playerSession(source) or playerSession(targetSource) or GarbageDuoInviteByDriver[source] or GarbageDuoInvites[targetSource] then
        duoNotify(source, "Um dos jogadores ja esta em uma dupla ou possui convite pendente.", "amarelo")
        return
    end

    local truck = GarbageTrucks[source]
    local vehicle = truck and networkVehicle(truck.netId) or 0
    if vehicle == 0 then
        duoNotify(source, "Retire o caminhao de lixo antes de convidar um coletor.", "amarelo")
        return
    end

    if distanceBetween(playerCoords(source), playerCoords(targetSource)) > Config.GarbageDuo.InviteDistance then
        duoNotify(source, "Aproxime o outro jogador para convidar a dupla.", "amarelo")
        return
    end

    GarbageDuoInvites[targetSource] = {
        driverSource = source,
        driverPassport = driverPassport,
        expiresAt = os.time() + Config.GarbageDuo.InviteTimeout
    }
    GarbageDuoInviteByDriver[source] = targetSource

    TriggerClientEvent("cfWorks:garbageDuoInvite", targetSource, driverPassport, Config.GarbageDuo.InviteTimeout)
    duoNotify(source, "Convite enviado. O outro jogador deve usar /"..Config.GarbageDuo.AcceptCommand..".", "verde")
    duoDebug(("convite enviado: driver=%s collector=%s"):format(source, targetSource))
end, false)

RegisterCommand(Config.GarbageDuo.AcceptCommand, function(source)
    if not Config.GarbageDuo.Enabled then
        return
    end

    local invite = GarbageDuoInvites[source]
    if not invite then
        duoNotify(source, "Voce nao possui convite de dupla pendente.", "amarelo")
        return
    end

    GarbageDuoInvites[source] = nil
    GarbageDuoInviteByDriver[invite.driverSource] = nil

    if invite.expiresAt < os.time() then
        duoNotify(source, "O convite da dupla expirou.", "amarelo")
        return
    end

    if not isLixeiro(source) or not isLixeiro(invite.driverSource) then
        duoNotify(source, "A dupla foi cancelada porque um jogador nao esta mais em servico.", "amarelo")
        return
    end

    if playerSession(source) or playerSession(invite.driverSource) then
        duoNotify(source, "Um dos jogadores ja esta em outra dupla.", "amarelo")
        return
    end

    if GarbageTrucks[source] then
        duoNotify(source, "Saia do seu caminhao atual antes de aceitar a dupla.", "amarelo")
        return
    end

    local truck = GarbageTrucks[invite.driverSource]
    local vehicle = truck and networkVehicle(truck.netId) or 0
    if vehicle == 0 then
        duoNotify(source, "O caminhao do motorista nao foi encontrado.", "amarelo")
        return
    end

    if distanceBetween(playerCoords(source), playerCoords(invite.driverSource)) > Config.GarbageDuo.InviteDistance then
        duoNotify(source, "Aproxime-se do motorista para aceitar o convite.", "amarelo")
        return
    end

    local sessionId = ("%s:%s"):format(invite.driverSource, source)
    local session = {
        id = sessionId,
        driverSource = invite.driverSource,
        collectorSource = source,
        vehicleNetId = truck.netId,
        plate = truck.plate,
        createdAt = os.time(),
        separatedSince = nil
    }

    GarbageDuoSessions[sessionId] = session
    GarbageDuoByPlayer[session.driverSource] = sessionId
    GarbageDuoByPlayer[session.collectorSource] = sessionId
    sendDuoState(session, true)
    duoNotify(session.driverSource, "Dupla de Lixeiro iniciada: voce e o MOTORISTA.", "verde")
    duoNotify(session.collectorSource, "Dupla de Lixeiro iniciada: voce e o COLETOR.", "verde")
    duoDebug(("dupla criada: driver=%s collector=%s truck=%s"):format(session.driverSource, session.collectorSource, session.vehicleNetId))
end, false)

RegisterCommand(Config.GarbageDuo.LeaveCommand, function(source)
    if playerSession(source) then
        cancelDuoForPlayer(source, "Voce saiu da dupla de Lixeiro.")
    else
        duoNotify(source, "Voce nao esta em uma dupla de Lixeiro.", "amarelo")
    end
end, false)

AddEventHandler("cfWorks:jobChanged", function(playerSource, jobId)
    if jobId ~= "lixeiro" then
        cancelDuoForPlayer(playerSource, "Dupla cancelada porque um jogador trocou de emprego.")
        clearDriverInvite(playerSource)
        GarbageDuoInvites[playerSource] = nil
        GarbageTrucks[playerSource] = nil
    end
end)

AddEventHandler("cfWorks:playerDropped", function(playerSource)
    cancelDuoForPlayer(playerSource, "Dupla cancelada porque um jogador saiu do servidor.")
    clearDriverInvite(playerSource)
    GarbageDuoInvites[playerSource] = nil
    GarbageTrucks[playerSource] = nil
    GarbageRewardCooldown[playerSource] = nil
end)

CreateThread(function()
    while true do
        Wait(1000)

        for targetSource, invite in pairs(GarbageDuoInvites) do
            if invite.expiresAt < os.time() then
                GarbageDuoInvites[targetSource] = nil
                GarbageDuoInviteByDriver[invite.driverSource] = nil
            end
        end

        for sessionId, session in pairs(GarbageDuoSessions) do
            local vehicle = networkVehicle(session.vehicleNetId)
            local valid = vehicle ~= 0 and isLixeiro(session.driverSource) and isLixeiro(session.collectorSource)
            local separation = distanceBetween(playerCoords(session.driverSource), playerCoords(session.collectorSource))

            if not valid then
                cancelDuo(sessionId, "Dupla cancelada porque o caminhao ou um jogador nao foi encontrado.")
            elseif separation > Config.GarbageDuo.MaxSeparation then
                session.separatedSince = session.separatedSince or os.time()
                if os.time() - session.separatedSince >= Config.GarbageDuo.SeparationTimeout then
                    cancelDuo(sessionId, "Dupla cancelada porque os jogadores se afastaram demais.")
                end
            else
                session.separatedSince = nil
            end
        end
    end
end)

RegisterServerEvent("cfWorks:lixeiroReward")
AddEventHandler("cfWorks:lixeiroReward", function(routeIndex, vehicleNetId)
    local source = source
    local user_id = vRP.getUserId(source)

    if not user_id or not isLixeiro(source) then
        return
    end

    local routeNumber = tonumber(routeIndex)
    local totalRoutes = #(Config.Garbage.routePoints or {})
    if not routeNumber or routeNumber < 1 or routeNumber > totalRoutes then
        duoDebug(("pagamento negado: rota invalida source=%s route=%s"):format(source, tostring(routeIndex)))
        return
    end

    local routePoint = Config.Garbage.routePoints[routeNumber]
    if distanceBetween(playerCoords(source), routePoint) > 5.0 then
        duoDebug(("pagamento negado: jogador fora do ponto source=%s route=%s"):format(source, routeNumber))
        return
    end

    local truck, vehicle = validateTruckFor(source, vehicleNetId)
    local session = playerSession(source)
    if session and session.collectorSource == source then
        truck, vehicle = validateTruckFor(session.driverSource, vehicleNetId)
    end

    if not truck or vehicle == 0 then
        duoDebug(("pagamento negado: caminhao invalido source=%s netId=%s"):format(source, tostring(vehicleNetId)))
        TriggerClientEvent("Notify", source, "amarelo", "Caminhao de lixo nao validado pelo servidor.", 5000)
        return
    end

    local now = os.time()
    local cooldown = tonumber(Config.GarbageDuo.CollectionCooldown) or 4
    if GarbageRewardCooldown[source] and now - GarbageRewardCooldown[source] < cooldown then
        return
    end

    if session and session.collectorSource == source then
        if tonumber(session.vehicleNetId) ~= tonumber(vehicleNetId) then
            duoDebug(("pagamento negado: veiculo nao pertence a dupla source=%s"):format(source))
            return
        end
    elseif vRPC and vRPC.LastVehicle and not vRPC.LastVehicle(source, Config.Garbage.model) then
        TriggerClientEvent("Notify", source, "amarelo", "Voce precisa estar usando o caminhao de lixo.", 5000)
        return
    end

    GarbageRewardCooldown[source] = now
    if user_id and CfWorksActiveJobs and CfWorksActiveJobs[source] == "lixeiro" then
        vRP.giveInventoryItem(user_id, Config.Garbage.item, Config.Garbage.amount, true)
        addJobXP(user_id, "lixeiro", Config.Garbage.xpPerAction)
        payment(user_id, "lixeiro", Config.Garbage.moneyPerAction)

        if Config.GarbageDuo.Enabled and session and session.collectorSource == source and Config.GarbageDuo.PayDriverSameAmount then
            local valid, reason = validateDuoForPayment(session, vehicle)
            if valid then
                local driverPassport = vRP.getUserId(session.driverSource)
                local multiplier = tonumber(Config.GarbageDuo.DriverPayMultiplier) or 1.0
                local driverPayment = math.floor((tonumber(Config.Garbage.moneyPerAction) or 0) * multiplier)
                if driverPassport and driverPayment > 0 then
                    payment(driverPassport, "lixeiro", driverPayment)
                    TriggerClientEvent("Notify", session.driverSource, "verde", ("Motorista recebeu R$ %s pela coleta do parceiro."):format(driverPayment), 5000)
                    duoDebug(("pagamento motorista: source=%s valor=%s"):format(session.driverSource, driverPayment))
                end
            else
                duoDebug(("pagamento motorista negado: %s"):format(reason or "validacao falhou"))
            end
        end
        TriggerClientEvent("Notify", source, "sucesso", "Você coletou itens recicláveis e ganhou <b>XP</b>!")
    end
end)
