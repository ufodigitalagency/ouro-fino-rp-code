local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")

local vRP = Proxy.getInterface("vRP")
local API = {}

Tunnel.bindInterface("of_aviao_sao_judas",API)

local Sessions = {}
local ActivePassports = {}
local RateLimits = {}

local function response(success,code,message,data)
    local result = data or {}
    result.success = success == true
    result.code = code or (result.success and "ok" or "error")
    result.message = message or ""
    return result
end

local function debugLog(message)
    if Config.Debug then
        print("[of_aviao_sao_judas] "..message)
    end
end

local function passport(playerSource)
    return playerSource and vRP.Passport(playerSource) or nil
end

local function rateAllowed(playerSource,key,intervalMs)
    local now = GetGameTimer()
    local identifier = tostring(playerSource)..":"..key
    local expiresAt = RateLimits[identifier] or 0

    if now < expiresAt then
        return false
    end

    RateLimits[identifier] = now + intervalMs
    return true
end

local function hasMembership(Passport)
    return Passport and vRP.HasGroup(Passport,Config.Permission) and true or false
end

local function isOnDuty(Passport)
    return Passport and vRP.HasService(Passport,Config.Permission) and true or false
end

local function playerPed(playerSource)
    local ped = GetPlayerPed(playerSource)
    if not ped or ped <= 0 or not DoesEntityExist(ped) then
        return 0
    end

    return ped
end

local function isAlive(playerSource)
    local ped = playerPed(playerSource)
    return ped ~= 0 and GetEntityHealth(ped) > 100
end

local function playerDistance(playerSource,coords)
    local ped = playerPed(playerSource)
    if ped == 0 or not coords then
        return math.huge
    end

    return #(GetEntityCoords(ped) - vector3(coords.x,coords.y,coords.z))
end

local function cooldownKey(Passport)
    return "AviaoSaoJudas:Cooldown:"..tostring(Passport)
end

local function cooldownRemaining(Passport)
    local data = vRP.GetSrvData(cooldownKey(Passport),true) or {}
    local expiresAt = tonumber(data.ExpiresAt) or 0
    return math.max(expiresAt - os.time(),0)
end

local function setCooldown(Passport)
    local expiresAt = os.time() + Config.Route.CooldownSeconds
    vRP.SetSrvData(cooldownKey(Passport),{ ExpiresAt = expiresAt },true)
    return expiresAt
end

local function clearSession(playerSource,reason)
    local session = Sessions[playerSource]
    if not session then
        return
    end

    ActivePassports[tostring(session.Passport)] = nil
    Sessions[playerSource] = nil
    debugLog(("session_cleared source=%s passport=%s reason=%s"):format(playerSource,session.Passport,tostring(reason)))
end

local function terminateSession(playerSource,reason,message)
    clearSession(playerSource,reason)
    TriggerClientEvent("of_aviao_sao_judas:ForceCleanup",playerSource,reason,message)
end

local function randomRoute(amount)
    local pool = {}
    for index = 1,#Config.Destinations do
        pool[index] = index
    end

    for index = #pool,2,-1 do
        local selected = math.random(index)
        pool[index],pool[selected] = pool[selected],pool[index]
    end

    local route = {}
    for index = 1,math.min(amount,#pool) do
        route[index] = pool[index]
    end

    return route
end

local function sessionDestination(session)
    if not session or session.AwaitingReturn then
        return nil,nil
    end

    local destinationId = session.Route[session.Current]
    return destinationId,destinationId and Config.Destinations[destinationId] or nil
end

local function policePercentage()
    local chance = math.max(0,math.min(tonumber(Config.Police.Chance) or 0,100))
    return math.floor((100 - chance) * 10)
end

local function callPolice(playerSource,Passport,coords)
    exports.vrp:CallPolice({
        Source = playerSource,
        Passport = Passport,
        Permission = Config.Police.Permission,
        Name = Config.Police.Name,
        Percentage = policePercentage(),
        Wanted = Config.Police.WantedSeconds,
        Code = Config.Police.Code,
        Color = Config.Police.Colour,
        Notify = Config.Police.NotifyPlayer,
        Coords = vector3(coords.x,coords.y,coords.z)
    })
end

function API.Access()
    local Passport = passport(source)
    return hasMembership(Passport)
end

function API.ToggleService()
    local playerSource = source
    if not rateAllowed(playerSource,"toggle",1000) then
        return response(false,"rate_limited","Aguarde um instante.")
    end

    local Passport = passport(playerSource)
    if not Passport then
        return response(false,"invalid_passport","Personagem não encontrado.")
    end

    if playerDistance(playerSource,Config.Start) > Config.Delivery.StartServerDistance then
        return response(false,"too_far","Aproxime-se do responsável pela rota.")
    end

    local session = Sessions[playerSource]
    if session then
        if not hasMembership(Passport) or not isOnDuty(Passport) then
            clearSession(playerSource,"service_lost")
            return response(false,"service_required","A rota foi encerrada porque você não está mais em serviço.")
        end

        if session.AwaitingReturn then
            local expiresAt = setCooldown(Passport)
            clearSession(playerSource,"completed")
            return response(true,"finished","Rota concluída. O contato estará disponível novamente em 30 minutos.",{
                action = "finished",
                cooldownExpiresAt = expiresAt
            })
        end

        clearSession(playerSource,"cancelled")
        return response(true,"cancelled","Rota cancelada.",{ action = "cancelled" })
    end

    if not hasMembership(Passport) then
        return response(false,"membership_required","Somente membros de São Judas podem acessar esta rota.")
    end

    if not isOnDuty(Passport) then
        return response(false,"service_required","Entre em serviço pelo menu da facção antes de iniciar.")
    end

    if not isAlive(playerSource) then
        return response(false,"player_dead","Você não pode iniciar a rota neste estado.")
    end

    local remaining = cooldownRemaining(Passport)
    if remaining > 0 then
        return response(false,"cooldown",("Aguarde %d minutos para iniciar outra rota."):format(math.ceil(remaining / 60)),{
            remaining = remaining
        })
    end

    if ActivePassports[tostring(Passport)] then
        return response(false,"already_active","Já existe uma rota ativa para este personagem.")
    end

    if #Config.Destinations < Config.Route.Deliveries then
        return response(false,"configuration_error","Não há destinos suficientes configurados.")
    end

    local route = randomRoute(Config.Route.Deliveries)
    Sessions[playerSource] = {
        Passport = Passport,
        Route = route,
        Current = 1,
        Completed = {},
        Pending = nil,
        LastPaymentAt = 0,
        AwaitingReturn = false,
        StartedAt = os.time()
    }
    ActivePassports[tostring(Passport)] = playerSource

    debugLog(("session_started source=%s passport=%s route=%s"):format(playerSource,Passport,json.encode(route)))

    return response(true,"started","Rota iniciada. Siga até o primeiro cliente.",{
        action = "started",
        destination = route[1],
        current = 1,
        total = #route
    })
end

function API.BeginDelivery(destinationId)
    local playerSource = source
    if not rateAllowed(playerSource,"begin_delivery",750) then
        return response(false,"rate_limited","Aguarde um instante.")
    end

    local session = Sessions[playerSource]
    local Passport = passport(playerSource)
    if not session or not Passport or session.Passport ~= Passport then
        return response(false,"inactive","Você não possui uma rota ativa.",{ terminate = true })
    end

    if not hasMembership(Passport) or not isOnDuty(Passport) then
        terminateSession(playerSource,"service_lost","A rota foi encerrada porque você saiu do serviço de São Judas.")
        return response(false,"service_required","Você não está mais em serviço.",{ terminate = true })
    end

    if not isAlive(playerSource) then
        terminateSession(playerSource,"death","A rota foi encerrada.")
        return response(false,"player_dead","Você não pode realizar a entrega.",{ terminate = true })
    end

    local expectedId,destination = sessionDestination(session)
    local requestedId = tonumber(destinationId)
    if not expectedId or requestedId ~= expectedId or not destination then
        return response(false,"wrong_destination","Este não é o cliente atual.")
    end

    if session.Completed[session.Current] then
        return response(false,"already_paid","Esta entrega já foi concluída.")
    end

    local now = os.time()
    if session.LastPaymentAt > 0 and now - session.LastPaymentAt < Config.Delivery.MinimumIntervalSeconds then
        return response(false,"delivery_interval","Aguarde antes da próxima entrega.")
    end

    if playerDistance(playerSource,destination) > Config.Delivery.ServerDistance then
        return response(false,"too_far","Aproxime-se do cliente.")
    end

    local timer = GetGameTimer()
    if session.Pending and session.Pending.ExpiresAt > timer then
        return response(false,"delivery_pending","Esta entrega já está em andamento.")
    end

    local token = ("%s:%s:%s:%s"):format(playerSource,Passport,expectedId,math.random(100000,999999))
    session.Pending = {
        Token = token,
        Destination = expectedId,
        NotBefore = timer + Config.Delivery.AnimationMinimumMs,
        ExpiresAt = timer + (Config.Delivery.ReservationSeconds * 1000)
    }

    return response(true,"reserved","Entrega autorizada.",{ token = token })
end

function API.CompleteDelivery(destinationId,token)
    local playerSource = source
    if not rateAllowed(playerSource,"complete_delivery",500) then
        return response(false,"rate_limited","Aguarde um instante.")
    end

    local session = Sessions[playerSource]
    local Passport = passport(playerSource)
    if not session or not Passport or session.Passport ~= Passport then
        return response(false,"inactive","Você não possui uma rota ativa.",{ terminate = true })
    end

    if not hasMembership(Passport) or not isOnDuty(Passport) then
        terminateSession(playerSource,"service_lost","A rota foi encerrada porque você saiu do serviço de São Judas.")
        return response(false,"service_required","Você não está mais em serviço.",{ terminate = true })
    end

    local expectedId,destination = sessionDestination(session)
    local pending = session.Pending
    local requestedId = tonumber(destinationId)
    local now = GetGameTimer()

    if not expectedId or requestedId ~= expectedId or not destination then
        return response(false,"wrong_destination","Destino inválido.")
    end

    if not pending or pending.Token ~= tostring(token) or pending.Destination ~= expectedId then
        return response(false,"invalid_token","A autorização desta entrega expirou.")
    end

    if now < pending.NotBefore or now > pending.ExpiresAt then
        session.Pending = nil
        return response(false,"invalid_timing","A entrega não foi concluída no tempo esperado.")
    end

    if not isAlive(playerSource) or playerDistance(playerSource,destination) > Config.Delivery.ServerDistance then
        session.Pending = nil
        return response(false,"too_far","Você se afastou do cliente.")
    end

    if session.Completed[session.Current] then
        session.Pending = nil
        return response(false,"already_paid","Esta entrega já foi paga.")
    end

    session.Pending = nil
    session.Completed[session.Current] = true
    session.LastPaymentAt = os.time()

    local amount = math.random(Config.Payment.Minimum,Config.Payment.Maximum)
    vRP.GenerateItem(Passport,Config.Payment.Item,amount,true)
    callPolice(playerSource,Passport,destination)

    local completed = session.Current
    session.Current = session.Current + 1

    if session.Current > #session.Route then
        session.AwaitingReturn = true
        debugLog(("route_deliveries_completed source=%s passport=%s"):format(playerSource,Passport))
        return response(true,"return_to_base","Entrega concluída. Retorne a São Judas para finalizar.",{
            reward = amount,
            completed = completed,
            total = #session.Route,
            returnToBase = true
        })
    end

    local nextId = session.Route[session.Current]
    return response(true,"delivery_completed","Entrega concluída.",{
        reward = amount,
        completed = completed,
        total = #session.Route,
        destination = nextId,
        current = session.Current
    })
end

function API.Cancel(reason)
    local playerSource = source
    if Sessions[playerSource] then
        clearSession(playerSource,reason or "client_cancel")
    end

    return true
end

AddEventHandler("playerDropped",function()
    local playerSource = source
    clearSession(playerSource,"player_dropped")

    local prefix = tostring(playerSource)..":"
    for key in pairs(RateLimits) do
        if key:sub(1,#prefix) == prefix then
            RateLimits[key] = nil
        end
    end
end)

CreateThread(function()
    while true do
        Wait(5000)

        local terminate = {}
        for playerSource,session in pairs(Sessions) do
            local Passport = passport(playerSource)
            if not Passport or Passport ~= session.Passport or not isAlive(playerSource) then
                terminate[#terminate + 1] = { Source = playerSource, Reason = "death", Message = "A rota foi encerrada." }
            elseif not hasMembership(Passport) or not isOnDuty(Passport) then
                terminate[#terminate + 1] = { Source = playerSource, Reason = "service_lost", Message = "A rota foi encerrada porque você saiu do serviço de São Judas." }
            end
        end

        for _,entry in ipairs(terminate) do
            terminateSession(entry.Source,entry.Reason,entry.Message)
        end
    end
end)

AddEventHandler("onResourceStop",function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    Sessions = {}
    ActivePassports = {}
    RateLimits = {}
end)
