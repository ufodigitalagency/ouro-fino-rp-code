local RESOURCE_NAME = GetCurrentResourceName()
local liveConfig = Config.LiveEvents or {}
local requestWindows = {}
local actionCooldowns = {}

local function Log(message)
    print(("[af_live_events] %s"):format(tostring(message)))
end

local function Respond(response,status,payload)
    response.writeHead(status,{
        ["Content-Type"] = "application/json; charset=utf-8",
        ["Cache-Control"] = "no-store"
    })
    response.send(json.encode(payload))
end

local function Trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$") or ""
end

local function CleanText(value,maximumLength)
    local text = tostring(value or "")
        :gsub("[%z\1-\8\11\12\14-\31\127]","")
        :sub(1,maximumLength)
    return Trim(text)
end

local function ConstantTimeEquals(left,right)
    left = tostring(left or "")
    right = tostring(right or "")

    local maximum = math.max(#left,#right)
    local difference = #left == #right and 0 or 1
    for index = 1,maximum do
        local a = left:byte(index) or 0
        local b = right:byte(index) or 0
        if a ~= b then difference = 1 end
    end

    return difference == 0
end

local function IsStrongSecret(secret)
    if not liveConfig.RequireStrongSecret then return secret ~= "" end
    if #secret < (tonumber(liveConfig.MinimumSecretLength) or 24) then return false end
    if secret == "trocar_essa_senha" then return false end
    return secret:find("[^%w]") ~= nil or (secret:find("%l") and secret:find("%u") and secret:find("%d"))
end

local function IsEnabled()
    local defaultValue = liveConfig.Enabled == true and "1" or "0"
    return GetConvar(tostring(liveConfig.EnabledConvar or "af_live_events_enabled"),defaultValue) == "1"
end

local function CurrentSecret()
    return GetConvar(tostring(liveConfig.SecretConvar or "af_live_events_secret"),"")
end

local function RemoteAddress(request)
    local address = tostring(request.address or request.remoteAddress or request.ip or "unknown")
    return address:gsub("^::ffff:","")
end

local function IsAllowedAddress(address)
    local allowed = liveConfig.AllowedRemoteAddresses
    if type(allowed) ~= "table" or #allowed == 0 then return true end

    for _,candidate in ipairs(allowed) do
        if ConstantTimeEquals(address,tostring(candidate)) then return true end
    end
    return false
end

local function IsRateLimited(address)
    local now = os.time()
    local maximum = math.max(1,tonumber(liveConfig.MaximumRequestsPerMinute) or 10)
    local bucket = requestWindows[address]

    if not bucket or now - bucket.startedAt >= 60 then
        requestWindows[address] = { startedAt = now, count = 1 }
        return false
    end

    bucket.count = bucket.count + 1
    return bucket.count > maximum
end

local function IsActionCoolingDown(action)
    local now = GetGameTimer()
    local availableAt = actionCooldowns[action] or 0
    if now < availableAt then return true end
    actionCooldowns[action] = now + math.max(250,tonumber(liveConfig.ActionCooldownMs) or 3000)
    return false
end

local function ProcessGift(request,response,body)
    local maximumBytes = tonumber(liveConfig.MaximumPayloadBytes) or 8192
    body = tostring(body or "")
    if #body == 0 or #body > maximumBytes then
        Respond(response,413,{ ok = false, error = "Payload vazio ou muito grande." })
        return
    end

    local decoded,data = pcall(json.decode,body)
    if not decoded or type(data) ~= "table" then
        Respond(response,400,{ ok = false, error = "JSON invalido." })
        return
    end

    local configuredSecret = CurrentSecret()
    if not IsStrongSecret(configuredSecret) then
        Log("Requisicao recusada: configure um segredo forte antes de habilitar o endpoint.")
        Respond(response,503,{ ok = false, error = "Endpoint nao configurado." })
        return
    end

    if not ConstantTimeEquals(data.secret,configuredSecret) then
        Log(("Autenticacao recusada para origem %s."):format(RemoteAddress(request)))
        Respond(response,403,{ ok = false, error = "Credencial invalida." })
        return
    end

    local action = CleanText(data.action,32):lower()
    if liveConfig.AllowedActions[action] ~= true then
        Respond(response,400,{ ok = false, error = "Acao nao permitida." })
        return
    end

    if IsActionCoolingDown(action) then
        Respond(response,429,{ ok = false, error = "Aguarde antes de repetir esta acao." })
        return
    end

    if action == "spawn_npc" then
        local username = CleanText(data.username,64)
        local giftName = CleanText(data.giftName,64)
        if username == "" then username = "StreamToEarn" end

        TriggerClientEvent("af_live_events:spawnNpc",-1,username,giftName)
        Log(("spawn_npc aceito: user=%s gift=%s"):format(username,giftName))
        Respond(response,200,{
            ok = true,
            action = action,
            username = username,
            giftName = giftName,
            giftId = CleanText(data.giftId,64)
        })
        return
    end

    Respond(response,400,{ ok = false, error = "Acao sem processador." })
end

SetHttpHandler(function(request,response)
    local path = tostring(request.path or "")
    if path ~= "/gift" then
        Respond(response,404,{ ok = false, error = "Rota nao encontrada." })
        return
    end

    if tostring(request.method or ""):upper() ~= "POST" then
        Respond(response,405,{ ok = false, error = "Metodo nao permitido." })
        return
    end

    if not IsEnabled() then
        Respond(response,503,{ ok = false, error = "Live events desativado." })
        return
    end

    local address = RemoteAddress(request)
    if not IsAllowedAddress(address) then
        Log(("Origem bloqueada: %s"):format(address))
        Respond(response,403,{ ok = false, error = "Origem nao autorizada." })
        return
    end

    if IsRateLimited(address) then
        Log(("Rate limit atingido para origem %s."):format(address))
        Respond(response,429,{ ok = false, error = "Muitas requisicoes." })
        return
    end

    request.setDataHandler(function(body)
        ProcessGift(request,response,body)
    end)
end)

AddEventHandler("onResourceStart",function(resourceName)
    if resourceName ~= RESOURCE_NAME then return end

    local secretReady = IsStrongSecret(CurrentSecret())
    if IsEnabled() and secretReady then
        Log("Endpoint POST /af_live_events/gift habilitado com autenticacao.")
    else
        Log("Endpoint HTTP desativado. Configure os convars para habilitar com seguranca.")
    end
end)

AddEventHandler("onResourceStop",function(resourceName)
    if resourceName ~= RESOURCE_NAME then return end
    requestWindows = {}
    actionCooldowns = {}
end)
