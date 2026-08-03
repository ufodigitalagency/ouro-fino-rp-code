local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")
local vRP = Proxy.getInterface("vRP")
local vKEYBOARD = Tunnel.getInterface("keyboard")
local vSURVIVAL = Tunnel.getInterface("survival")
local vHUD = Tunnel.getInterface("hud")
local vPLAYER = Tunnel.getInterface("player")

local OWNER_PASSPORT = 1
local OWNER_RECOVERY_COOLDOWN = 4000
local OWNER_PROTECTION_COOLDOWN = 4000
local OWNER_RELEASE_COOLDOWN = 4000
local OwnerRecoveryCooldowns = {}
local OwnerProtectionCooldowns = {}
local OwnerReleaseCooldowns = {}
local OwnerProtectionBlockCooldowns = {}
local OwnerPendingCommandRelease = {}
local OwnerProtectionEnabled = true

local OwnerProtectionConsumers = {
    inventory = true,
    inspect = true,
    player = true
}

local OwnerProtectionActions = {
    inventory = { handcuff = true, hood = true, carry = true },
    inspect = { inspect = true },
    player = { force_vehicle = true }
}

local OwnerJobs = {
    { id = "LSPD", label = "Polícia - LSPD" },
    { id = "BCSO", label = "Polícia - BCSO" },
    { id = "SAPR", label = "Polícia Rodoviária - SAPR" },
    { id = "Paramedico", label = "Médico / Enfermagem" },
    { id = "Bennys", label = "Mecânico" },
    { id = "OFC", label = "Ouro Fight Club" },
    { id = "Vampire", label = "Habilidade: Vampiro" },
    { id = "Bruxo", label = "Habilidade: Bruxo" },
    { id = "Pombal", label = "Facção: Pombal" },
    { id = "SaoJudas", label = "Facção: São Judas" }
}

local OwnerJobIds = {}
for _,job in ipairs(OwnerJobs) do
    OwnerJobIds[job.id] = true
end

local EconomyConfig = {
    Enabled = true,
    MinimumGrant = 1,
    MaximumGrant = 10000000,
    MinimumReasonLength = 4,
    MaximumReasonLength = 120,
    CooldownMilliseconds = 1000
}

local AllowedEconomyAccounts = {
    cash = true,
    bank = true
}

local EconomyCooldowns = {}
local EconomyOperations = {}
local EconomyReady = false
local PlanOperations = {}
local PremiumOrderOperations = {}

local Plans = {
    premium = {
        priority = 3,
        permission = "Premium",
        label = "Premium",
        weaponLicense = true,
        vehicles = { "prototipo", "zentorno", "elegy2", "bmws", "p1", "baller6", "patriot2", "1016urus", "z1000", "supervolito2", "amarok" }
    },
    vip = {
        priority = 2,
        permission = "Vip",
        label = "VIP",
        weaponLicense = true,
        vehicles = { "1016urus", "bmws", "lp700r", "r6", "urus2018", "baller4", "patriot", "nero2", "supervolito2", "amarok" }
    },
    standard = {
        priority = 1,
        permission = "Standard",
        label = "Standard",
        weaponLicense = false,
        vehicles = { "omnis", "seven70", "x6m", "baller2", "i8", "g65amg", "kuruma" }
    }
}

local PlanPermissions = { "Premium", "Vip", "Standard" }
local DeprecatedPlanVehicles = { "r1", "2f2fgtr34" }

local AdminWeaponItems = {
    WEAPON_FLASHLIGHT = true,
    WEAPON_NIGHTSTICK = true,
    WEAPON_STUNGUN = true,
    WEAPON_COMBATPISTOL = true,
    WEAPON_PISTOL = true,
    WEAPON_SMG = true,
    WEAPON_CARBINERIFLE = true,
    WEAPON_PUMPSHOTGUN = true,
    WEAPON_PISTOL_AMMO = true,
    WEAPON_SMG_AMMO = true,
    WEAPON_RIFLE_AMMO = true,
    WEAPON_SHOTGUN_AMMO = true
}

local AdminWeaponAmmo = {
    WEAPON_COMBATPISTOL = "WEAPON_PISTOL_AMMO",
    WEAPON_PISTOL = "WEAPON_PISTOL_AMMO",
    WEAPON_SMG = "WEAPON_SMG_AMMO",
    WEAPON_CARBINERIFLE = "WEAPON_RIFLE_AMMO",
    WEAPON_PUMPSHOTGUN = "WEAPON_SHOTGUN_AMMO"
}

local WeatherWhitelist = {
    CLEAR = true,
    EXTRASUNNY = true,
    NEUTRAL = true,
    SMOG = true,
    FOGGY = true,
    OVERCAST = true,
    CLOUDS = true,
    CLEARING = true,
    RAIN = true,
    THUNDER = true,
    SNOW = true,
    BLIZZARD = true,
    SNOWLIGHT = true,
    XMAS = true,
    HALLOWEEN = true,
    RAIN_HALLOWEEN = true,
    SNOW_HALLOWEEN = true
}

local PoliceKit = {
    { item = "WEAPON_FLASHLIGHT", amount = 1 },
    { item = "WEAPON_NIGHTSTICK", amount = 1 },
    { item = "WEAPON_STUNGUN", amount = 1 },
    { item = "WEAPON_COMBATPISTOL", amount = 1 },
    { item = "WEAPON_PISTOL_AMMO", amount = 80 }
}

local function notify(source,message,kind)
    TriggerClientEvent("Notify",source,"Painel Admin",message,kind or "default",6000)
end

local function itemLabel(item)
    local ok,name = pcall(function()
        return exports.vrp:ItemName(item)
    end)

    return ok and name or item
end

local function isOwner(source)
    local passport = vRP.Passport(source)
    return passport and tonumber(passport) == OWNER_PASSPORT
end

local function ownerProtectionLog(source,passport,action,result,reason,before,after,released,preserved)
    print(("[af_owner_panel] owner_protection timestamp=%s source=%s passport=%s action=%s result=%s reason=%s before=%s after=%s released=%s preserved=%s"):format(
        os.date("!%Y-%m-%dT%H:%M:%SZ"),
        tostring(source or "unknown"),
        tostring(passport or "unknown"),
        tostring(action or "unknown"),
        tostring(result or "denied"),
        tostring(reason or "none"),
        tostring(before or "none"),
        tostring(after or "none"),
        tostring(released or "none"),
        tostring(preserved or "none")
    ))
end

local function ownerStateSummary(state)
    if not state then
        return "unavailable"
    end

    return ("active:%s,handcuff:%s,carry:%s,commands:%s,bed:%s,cancel:%s,buttons:%s,death:%s,crawl:%s,prison:%s,arena:%s,route:%s"):format(
        tostring(state.Active == true),
        tostring(state.Handcuff == true),
        tostring(state.Carry == true),
        tostring(state.Commands == true),
        tostring(state.Bed == true),
        tostring(state.Cancel == true),
        tostring(state.Buttons == true),
        tostring(state.Death == true),
        tostring(state.Crawl == true),
        tostring(state.Prison == true or tonumber(state.Prison or 0) > 0),
        tostring(state.Arena == true or tonumber(state.Arena or 0) > 0),
        tostring(tonumber(state.Route or 0) or 0)
    )
end

local function isOwnerProtectedSource(targetSource)
    targetSource = tonumber(targetSource)
    if not targetSource or targetSource <= 0 or not OwnerProtectionEnabled then
        return false
    end

    local passport = vRP.Passport(targetSource)
    return passport and tonumber(passport) == OWNER_PASSPORT and vRP.DoesEntityExist(targetSource) or false
end

exports("IsOwnerProtected",function(targetSource)
    local invokingResource = GetInvokingResource()
    if not OwnerProtectionConsumers[invokingResource] then
        return false
    end

    return isOwnerProtectedSource(targetSource)
end)

exports("ReportProtectionBlock",function(executorSource,targetSource,action)
    local invokingResource = GetInvokingResource()
    action = tostring(action or "")
    if not OwnerProtectionConsumers[invokingResource] or not OwnerProtectionActions[invokingResource] or not OwnerProtectionActions[invokingResource][action] then
        return false
    end

    executorSource = tonumber(executorSource)
    targetSource = tonumber(targetSource)
    if not executorSource or executorSource <= 0 or not isOwnerProtectedSource(targetSource) then
        return false
    end

    local now = GetGameTimer()
    local key = ("%s:%s:%s"):format(invokingResource,executorSource,action)
    if OwnerProtectionBlockCooldowns[key] and now < OwnerProtectionBlockCooldowns[key] then
        return true
    end

    OwnerProtectionBlockCooldowns[key] = now + OWNER_PROTECTION_COOLDOWN
    local executorPassport = vRP.Passport(executorSource)
    notify(executorSource,"O Dono esta com protecao preventiva ativa.","vermelho")
    if executorSource ~= targetSource then
        notify(targetSource,("Protecao bloqueou a acao %s do ID %s."):format(action,tostring(executorPassport or "desconhecido")),"amarelo")
    end

    ownerProtectionLog(executorSource,executorPassport,"blocked_"..action,"denied","owner_protected",nil,nil,nil,nil)
    return true
end)

local function ownerProtectionResponse(source,success,enabled,message)
    TriggerClientEvent("af_owner_panel:protectionResult",source,{
        success = success == true,
        enabled = enabled == true,
        message = message
    })
end

local function requestOwnerProtectionToggle(requestSource)
    local source = tonumber(requestSource)
    if not source or source <= 0 then
        ownerProtectionLog(source,nil,"protection_toggle","denied","invalid_source")
        return false
    end

    local now = GetGameTimer()
    local passport = vRP.Passport(source)
    if OwnerProtectionCooldowns[source] and now < OwnerProtectionCooldowns[source] then
        ownerProtectionLog(source,passport,"protection_toggle","denied","cooldown")
        ownerProtectionResponse(source,false,OwnerProtectionEnabled,"Aguarde alguns segundos antes de alternar novamente.")
        return false
    end

    OwnerProtectionCooldowns[source] = now + OWNER_PROTECTION_COOLDOWN
    if not passport or not isOwner(source) then
        ownerProtectionLog(source,passport,"protection_toggle","denied","not_owner")
        ownerProtectionResponse(source,false,false,"Protecao permitida exclusivamente ao dono ID 1.")
        return false
    end

    local player = Player(source)
    local state = player and player.state
    if not state or state.Active ~= true or not vRP.DoesEntityExist(source) then
        ownerProtectionLog(source,passport,"protection_toggle","denied","inactive_character")
        ownerProtectionResponse(source,false,OwnerProtectionEnabled,"Finalize a selecao e aguarde o personagem ficar ativo.")
        return false
    end

    local before = OwnerProtectionEnabled
    OwnerProtectionEnabled = not OwnerProtectionEnabled
    local action = OwnerProtectionEnabled and "protection_on" or "protection_off"
    ownerProtectionLog(source,passport,action,"success","toggle",tostring(before),tostring(OwnerProtectionEnabled))
    ownerProtectionResponse(source,true,OwnerProtectionEnabled,OwnerProtectionEnabled and "Protecao preventiva ativada." or "Protecao preventiva desativada temporariamente.")
    return true
end

local function appendUnique(list,lookup,value)
    value = tostring(value or "")
    if value ~= "" and not lookup[value] then
        lookup[value] = true
        list[#list + 1] = value
    end
end

local function requestOwnerRelease(requestSource)
    local source = tonumber(requestSource)
    if not source or source <= 0 then
        ownerProtectionLog(source,nil,"self_release","denied","invalid_source")
        return false
    end

    local now = GetGameTimer()
    local passport = vRP.Passport(source)
    if OwnerReleaseCooldowns[source] and now < OwnerReleaseCooldowns[source] then
        ownerProtectionLog(source,passport,"self_release","denied","cooldown")
        TriggerClientEvent("af_owner_panel:releaseResult",source,{ success = false, result = "denied", message = "Aguarde alguns segundos antes de tentar novamente." })
        return false
    end

    OwnerReleaseCooldowns[source] = now + OWNER_RELEASE_COOLDOWN
    local player = Player(source)
    local state = player and player.state
    local before = ownerStateSummary(state)

    local function deny(reason,message)
        ownerProtectionLog(source,passport,"self_release","denied",reason,before,ownerStateSummary(state))
        TriggerClientEvent("af_owner_panel:releaseResult",source,{ success = false, result = "denied", message = message })
        return false
    end

    if not passport or not isOwner(source) then
        return deny("not_owner","Libertacao permitida exclusivamente ao dono ID 1.")
    end

    if not state or state.Active ~= true or not vRP.DoesEntityExist(source) then
        return deny("inactive_character","Finalize a selecao e aguarde o personagem ficar ativo.")
    end

    if state.Banned == true then
        return deny("banned_context","Libertacao indisponivel neste contexto.")
    end

    if state.Prison == true or tonumber(state.Prison or 0) > 0 then
        return deny("prison_context","Libertacao indisponivel durante a prisao.")
    end

    if state.Bed == true then
        return deny("bed_context","Libertacao indisponivel durante tratamento em cama.")
    end

    if state.Arena == true or tonumber(state.Arena or 0) > 0 then
        return deny("arena_context","Libertacao indisponivel durante uma arena.")
    end

    if state.Creation == true then
        return deny("creation_context","Libertacao indisponivel durante a criacao do personagem.")
    end

    local route = tonumber(state.Route or 0) or 0
    local bucket = GetPlayerRoutingBucket(source)
    if route ~= 0 or bucket ~= 0 then
        return deny("routing_bucket_context","Libertacao indisponivel fora da rota principal.")
    end

    local released,releasedLookup = {},{}
    local preserved,preservedLookup = {},{}
    local commandsOwned = false

    if GetResourceState("inventory") == "started" then
        local ok,result = pcall(function()
            return exports.inventory:ForceReleaseOwner(source)
        end)
        if ok and type(result) == "table" and result.success == true then
            if result.handcuff then appendUnique(released,releasedLookup,"algema") end
            if result.carryTarget then appendUnique(released,releasedLookup,"carry_alvo") end
            if result.carryCarrier then appendUnique(released,releasedLookup,"carry_carregador") end
            if result.carryStale then appendUnique(released,releasedLookup,"carry_residual") end
            commandsOwned = result.commandsOwned == true
        else
            appendUnique(preserved,preservedLookup,"inventory_indisponivel")
        end
    else
        appendUnique(preserved,preservedLookup,"inventory_indisponivel")
    end

    if GetResourceState("hud") == "started" then
        local ok,removed = pcall(function()
            return vHUD.RemoveHood(source)
        end)
        if ok then
            if removed == true then appendUnique(released,releasedLookup,"capuz") end
        else
            appendUnique(preserved,preservedLookup,"hud_indisponivel")
        end
    else
        appendUnique(preserved,preservedLookup,"hud_indisponivel")
    end

    if GetResourceState("player") == "started" then
        local ok,result = pcall(function()
            return vPLAYER.OwnerForceRelease(source)
        end)
        if ok and type(result) == "table" and result.success == true then
            if result.trunk then appendUnique(released,releasedLookup,"porta_malas") end
            if result.trash then appendUnique(released,releasedLookup,"lixo") end
            commandsOwned = commandsOwned or result.commandsOwned == true
        else
            appendUnique(preserved,preservedLookup,"player_indisponivel")
        end
    else
        appendUnique(preserved,preservedLookup,"player_indisponivel")
    end

    if GetResourceState("inspect") == "started" then
        local ok,result = pcall(function()
            return exports.inspect:ForceReleaseOwner(source)
        end)
        if ok and type(result) == "table" and result.success == true then
            if result.inspect then appendUnique(released,releasedLookup,"revista") end
        else
            appendUnique(preserved,preservedLookup,"inspect_indisponivel")
        end
    else
        appendUnique(preserved,preservedLookup,"inspect_indisponivel")
    end

    if commandsOwned then
        OwnerPendingCommandRelease[source] = true
    end

    local commandBlockers = {}
    if state.Bed == true then commandBlockers[#commandBlockers + 1] = "Bed" end
    if state.Cancel == true then commandBlockers[#commandBlockers + 1] = "Cancel" end
    if state.Buttons == true then commandBlockers[#commandBlockers + 1] = "Buttons" end
    if state.Death == true then commandBlockers[#commandBlockers + 1] = "Death" end
    if state.Crawl == true then commandBlockers[#commandBlockers + 1] = "Crawl" end
    if state.Prison == true or tonumber(state.Prison or 0) > 0 then commandBlockers[#commandBlockers + 1] = "Prison" end
    if state.Banned == true then commandBlockers[#commandBlockers + 1] = "Banned" end
    if state.Arena == true or tonumber(state.Arena or 0) > 0 then commandBlockers[#commandBlockers + 1] = "Arena" end

    if OwnerPendingCommandRelease[source] then
        if #commandBlockers == 0 then
            state.Commands = false
            OwnerPendingCommandRelease[source] = nil
            appendUnique(released,releasedLookup,"commands")
        else
            state.Commands = true
            appendUnique(preserved,preservedLookup,"commands:"..table.concat(commandBlockers,"|"))
        end
    elseif state.Commands == true then
        appendUnique(preserved,preservedLookup,"commands_sem_ownership")
    end

    if state.Handcuff == true then appendUnique(preserved,preservedLookup,"algema") end
    if state.Carry == true then appendUnique(preserved,preservedLookup,"carry") end
    if state.Death == true then appendUnique(preserved,preservedLookup,"Death") end
    if state.Crawl == true then appendUnique(preserved,preservedLookup,"Crawl") end
    if state.Cancel == true then appendUnique(preserved,preservedLookup,"Cancel") end
    if state.Buttons == true then appendUnique(preserved,preservedLookup,"Buttons") end

    local partial = #preserved > 0
    local result = partial and "partial" or "success"
    local releasedText = #released > 0 and table.concat(released,"|") or "none"
    local preservedText = #preserved > 0 and table.concat(preserved,"|") or "none"
    ownerProtectionLog(source,passport,"self_release",result,partial and "protected_context_preserved" or "complete",before,ownerStateSummary(state),releasedText,preservedText)
    TriggerClientEvent("af_owner_panel:releaseResult",source,{
        success = true,
        result = result,
        released = released,
        preserved = preserved,
        message = #released == 0 and not partial and "Nenhuma restricao proprietaria estava ativa." or nil
    })
    return true
end

local function ownerRecoveryLog(source,passport,origin,before,result,reason)
    before = before or {}

    print(("[af_owner_panel] owner_recovery timestamp=%s source=%s passport=%s origin=%s before_death=%s before_crawl=%s before_health=%s result=%s reason=%s"):format(
        os.date("!%Y-%m-%dT%H:%M:%SZ"),
        tostring(source or "unknown"),
        tostring(passport or "unknown"),
        tostring(origin or "unknown"),
        tostring(before.Death == true),
        tostring(before.Crawl == true),
        tostring(before.Health or "unknown"),
        tostring(result or "denied"),
        tostring(reason or "none")
    ))
end

local function ownerRecoveryResponse(source,success,result,message,preserved)
    TriggerClientEvent("af_owner_panel:selfRecoveryResult",source,{
        success = success == true,
        result = result,
        message = message,
        preserved = preserved or {}
    })
end

local function requestOwnerRecovery(requestSource,origin)
    local source = tonumber(requestSource)
    origin = tostring(origin or "unknown")

    if not source or source <= 0 then
        ownerRecoveryLog(source,nil,origin,nil,"denied","invalid_source")
        return false
    end

    local now = GetGameTimer()
    if OwnerRecoveryCooldowns[source] and now < OwnerRecoveryCooldowns[source] then
        local passport = vRP.Passport(source)
        local state = Player(source) and Player(source).state
        local before = state and {
            Death = state.Death,
            Crawl = state.Crawl,
            Health = vRP.GetHealth(source)
        } or nil

        ownerRecoveryLog(source,passport,origin,before,"denied","cooldown")
        ownerRecoveryResponse(source,false,"denied","Aguarde alguns segundos antes de tentar novamente.")
        return false
    end

    OwnerRecoveryCooldowns[source] = now + OWNER_RECOVERY_COOLDOWN

    local passport = vRP.Passport(source)
    local player = Player(source)
    local state = player and player.state
    local before = state and {
        Death = state.Death,
        Crawl = state.Crawl,
        Health = vRP.GetHealth(source)
    } or nil

    local function deny(reason,message)
        ownerRecoveryLog(source,passport,origin,before,"denied",reason)
        ownerRecoveryResponse(source,false,"denied",message)
        return false
    end

    if not passport or not isOwner(source) then
        return deny("not_owner","Recuperacao permitida exclusivamente ao dono ID 1.")
    end

    if not state or state.Active ~= true or not vRP.DoesEntityExist(source) then
        return deny("inactive_character","Finalize a selecao e aguarde o personagem ficar ativo.")
    end

    if state.Banned == true then
        return deny("banned_context","Recuperacao indisponivel neste contexto.")
    end

    if state.Prison == true or tonumber(state.Prison or 0) > 0 then
        return deny("prison_context","Recuperacao indisponivel durante a prisao.")
    end

    if state.Creation == true then
        return deny("creation_context","Recuperacao indisponivel durante a criacao do personagem.")
    end

    if state.Bed == true then
        return deny("bed_context","Saia da cama antes de solicitar a recuperacao.")
    end

    if state.Arena == true or tonumber(state.Arena or 0) > 0 then
        return deny("arena_context","Recuperacao indisponivel durante uma arena.")
    end

    local route = tonumber(state.Route or 0) or 0
    local bucket = GetPlayerRoutingBucket(source)
    if route ~= 0 or bucket ~= 0 then
        return deny("routing_bucket_context","Recuperacao indisponivel fora da rota principal.")
    end

    TriggerClientEvent("af_owner_panel:close",source)

    local ok,recovery = pcall(function()
        return vSURVIVAL.CanonicalRecovery(source,200,100)
    end)

    if not ok or type(recovery) ~= "table" or recovery.success ~= true then
        local reason = not ok and "survival_tunnel_error" or "invalid_survival_result"
        ownerRecoveryLog(source,passport,origin,before,"failed",reason)
        ownerRecoveryResponse(source,false,"failed","A recuperacao nao foi concluida com seguranca.")
        return false
    end

    state.Death = false
    state.Crawl = false

    local result = recovery.partial and "partial" or "success"
    local reason = recovery.partial and "protected_restrictions_preserved" or "canonical_recovery_complete"
    ownerRecoveryLog(source,passport,origin,before,result,reason)
    ownerRecoveryResponse(source,true,result,nil,recovery.preserved)
    return true
end

local function getSourceFromPassport(passport)
    passport = parseInt(passport)
    if passport <= 0 then
        return false
    end

    return vRP.Source(passport)
end

local function getCashBalance(passport)
    return math.max(0,parseInt(vRP.ItemAmount(passport,"dollar") or 0))
end

local function getBankBalance(passport)
    return math.max(0,parseInt(vRP.GetBank(passport) or 0))
end

local function sanitizeReason(reason)
    reason = tostring(reason or ""):gsub("[%c<>]",""):gsub("%s+"," ")
    reason = reason:match("^%s*(.-)%s*$") or ""

    if #reason > EconomyConfig.MaximumReasonLength then
        reason = reason:sub(1,EconomyConfig.MaximumReasonLength)
    end

    return reason
end

local function validOperationId(operationId)
    operationId = tostring(operationId or "")
    if #operationId < 12 or #operationId > 64 then
        return nil
    end

    return operationId:match("^[%w:_%-]+$") and operationId or nil
end

local function moneyResult(source,payload)
    if source and source > 0 and GetPlayerName(source) then
        TriggerClientEvent("af_owner_panel:grantMoneyResult",source,payload or {
            success = false,
            message = "Nao foi possivel concluir a concessao."
        })
    end
end

local function getAccountFromPassport(passport)
    local identity = vRP.Identity(passport)
    if not identity or not identity.License then
        return nil
    end

    return vRP.Account(identity.License),identity
end

local function handleTelao(source,action,payload)
    TriggerEvent("af_youtube_tv:serverAction",source,action,payload or {})
end

local function getTelaoState()
    if GetResourceState("af_youtube_tv") ~= "started" then
        return { available = false }
    end

    local ok,state = pcall(function()
        return exports["af_youtube_tv"]:GetState()
    end)
    if not ok or type(state) ~= "table" then
        return { available = false }
    end

    state.available = true
    return state
end

local function giveAdminItem(source,passport,item,amount)
    passport = parseInt(passport)
    item = tostring(item or "")
    amount = math.max(parseInt(amount or 1),1)

    if passport <= 0 or item == "" then
        notify(source,"ID ou item invalido.","vermelho")
        return false
    end

    if not AdminWeaponItems[item] then
        notify(source,"Item nao liberado no painel de armas.","vermelho")
        return false
    end

    local target = getSourceFromPassport(passport)
    if not target or target <= 0 or not GetPlayerName(target) then
        notify(source,"Jogador alvo precisa estar online para receber armas.","vermelho")
        return false
    end

    local ok,exists = pcall(function()
        return exports.vrp:ItemExist(item)
    end)

    if not ok or not exists then
        notify(source,("Item inexistente na base: %s."):format(item),"vermelho")
        return false
    end

    if vRP.MaxItens(passport,item,amount) then
        notify(source,("Limite maximo atingido para %s."):format(itemLabel(item)),"vermelho")
        return false
    end

    if not vRP.CheckWeight(passport,item,amount) then
        notify(source,"Mochila do jogador sem peso disponivel.","vermelho")
        return false
    end

    vRP.GenerateItem(passport,item,amount,true)
    notify(source,("Entregue %sx %s ao ID %s."):format(amount,itemLabel(item),passport),"verde")
    notify(target,("Voce recebeu %sx %s."):format(amount,itemLabel(item)),"verde")
    return true
end

local function givePanelItem(source,passport,item,amount)
    passport = parseInt(passport)
    item = tostring(item or ""):gsub("%s+","")
    amount = math.max(parseInt(amount or 1),1)

    if passport <= 0 or item == "" then
        notify(source,"ID ou item invalido.","vermelho")
        return false
    end

    if not vRP.Identity(passport) then
        notify(source,"Passaporte nao encontrado.","vermelho")
        return false
    end

    local ok,exists = pcall(function()
        return exports.vrp:ItemExist(item)
    end)

    if not ok or not exists then
        notify(source,("Item inexistente na base: %s."):format(item),"vermelho")
        return false
    end

    if exports.vrp:ItemLocked(item) then
        notify(source,"Este item e bloqueado e nao pode ser entregue pelo painel.","vermelho")
        return false
    end

    local target = getSourceFromPassport(passport)
    if target and target > 0 and GetPlayerName(target) then
        if vRP.MaxItens(passport,item,amount) then
            notify(source,("Limite maximo atingido para %s."):format(itemLabel(item)),"vermelho")
            return false
        end

        if not vRP.CheckWeight(passport,item,amount) then
            notify(source,"Mochila do jogador sem peso disponivel.","vermelho")
            return false
        end

        vRP.GenerateItem(passport,item,amount,true)
        TriggerClientEvent("inventory:Update",target)
        notify(target,("Voce recebeu %sx %s."):format(amount,itemLabel(item)),"verde")
        notify(source,("Entregue %sx %s ao ID %s."):format(amount,itemLabel(item),passport),"verde")
        return true
    end

    local selected
    local deliveries = vRP.GetSrvData("Offline:"..passport,true) or {}
    repeat
        selected = GenerateString("DDLLDDLL")
    until selected and not deliveries[selected]

    deliveries[selected] = { Item = item, Amount = amount }
    vRP.SetSrvData("Offline:"..passport,deliveries,true)
    notify(source,("ID offline. %sx %s ficou na lista de entregas."):format(amount,itemLabel(item)),"verde")
    return true
end

local function buildCatalog()
    local items = {}
    local list = exports.vrp:ItemList() or {}

    for code,data in pairs(list) do
        if data and not data.Locked then
            local index = data.Index or code
            items[#items + 1] = {
                code = code,
                name = data.Name or code,
                index = index,
                type = data.Type or "Comum",
                image = ("http://localhost/vrp_images/%s.png"):format(index)
            }
        end
    end

    table.sort(items,function(a,b)
        return tostring(a.name):lower() < tostring(b.name):lower()
    end)

    local weapons = {}
    for code in pairs(AdminWeaponItems) do
        weapons[#weapons + 1] = {
            code = code,
            name = itemLabel(code),
            index = code,
            type = "Armamento",
            image = ("http://localhost/vrp_images/%s.png"):format(code)
        }
    end

    table.sort(weapons,function(a,b)
        return tostring(a.name):lower() < tostring(b.name):lower()
    end)

    return { items = items, weapons = weapons }
end

local function identityName(identity,source,passport)
    if identity then
        local first = identity.Name or identity.name or identity.Firstname or identity.firstname or ""
        local last = identity.Lastname or identity.lastname or identity.LastName or ""
        local combined = tostring(first.." "..last):gsub("^%s+",""):gsub("%s+$","")

        if combined ~= "" then
            return combined
        end
    end

    return GetPlayerName(source) or ("ID "..tostring(passport or source))
end

local function buildPlayers()
    local players = {}

    for _,playerSource in ipairs(GetPlayers()) do
        local sourceNumber = tonumber(playerSource)
        local passport = sourceNumber and vRP.Passport(sourceNumber)
        local identity = passport and vRP.Identity(passport) or nil

        players[#players + 1] = {
            source = sourceNumber,
            passport = passport,
            name = identityName(identity,sourceNumber,passport),
            cash = passport and getCashBalance(passport) or 0,
            bank = passport and getBankBalance(passport) or 0
        }
    end

    table.sort(players,function(a,b)
        return tonumber(a.passport or a.source or 0) < tonumber(b.passport or b.source or 0)
    end)

    return players
end

local function sendServerState(source)
    local telaoState = getTelaoState()
    TriggerClientEvent("af_owner_panel:serverState",source,{
        weather = GlobalState.Weather or "CLEAR",
        hour = GlobalState.Hours or 0,
        minute = GlobalState.Minutes or 0,
        telaoVolume = telaoState.baseVolume or telaoState.volume or GlobalState.AfYoutubeTvVolume or 70,
        telao = telaoState
    })
end

local function preparePlans()
    vRP.Prepare("ofplans/create",[[CREATE TABLE IF NOT EXISTS ouro_fino_plans (
        Passport INT NOT NULL,
        Plan VARCHAR(20) NOT NULL,
        AssignedBy INT NOT NULL DEFAULT 1,
        AssignedAt INT NOT NULL DEFAULT 0,
        ExpiresAt INT NOT NULL DEFAULT 0,
        PRIMARY KEY (Passport)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])
    vRP.Prepare("ofplans/get","SELECT Plan,AssignedBy,AssignedAt,ExpiresAt FROM ouro_fino_plans WHERE Passport = @Passport LIMIT 1")
    vRP.Prepare("ofplans/all","SELECT Passport,Plan,ExpiresAt FROM ouro_fino_plans")
    vRP.Prepare("ofplans/set","INSERT INTO ouro_fino_plans (Passport,Plan,AssignedBy,AssignedAt,ExpiresAt) VALUES (@Passport,@Plan,@AssignedBy,UNIX_TIMESTAMP(),@ExpiresAt) ON DUPLICATE KEY UPDATE Plan = VALUES(Plan), AssignedBy = VALUES(AssignedBy), AssignedAt = VALUES(AssignedAt), ExpiresAt = VALUES(ExpiresAt)")
    vRP.Prepare("ofplans/remove","DELETE FROM ouro_fino_plans WHERE Passport = @Passport")
    vRP.Execute("ofplans/create")

    pcall(function()
        MySQL.query.await("ALTER TABLE ouro_fino_plans ADD COLUMN IF NOT EXISTS ExpiresAt INT NOT NULL DEFAULT 0 AFTER AssignedAt")
    end)

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS ouro_fino_premium_orders (
        OrderId VARCHAR(64) NOT NULL,
        Passport INT NOT NULL,
        Plan VARCHAR(20) NOT NULL,
        ExpectedAmountCents INT UNSIGNED NOT NULL,
        DurationSeconds INT UNSIGNED NOT NULL DEFAULT 2592000,
        Status VARCHAR(24) NOT NULL DEFAULT 'pending',
        CreatedAt INT NOT NULL,
        UpdatedAt INT NOT NULL,
        ExpiresAt INT NOT NULL,
        ApprovedBy INT NOT NULL DEFAULT 0,
        ProcessedAt INT NOT NULL DEFAULT 0,
        LastError VARCHAR(255) NOT NULL DEFAULT '',
        PRIMARY KEY (OrderId),
        KEY idx_premium_passport (Passport,Status),
        KEY idx_premium_status (Status,CreatedAt)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

    pcall(function()
        MySQL.query.await("ALTER TABLE ouro_fino_premium_orders ADD COLUMN IF NOT EXISTS DurationSeconds INT UNSIGNED NOT NULL DEFAULT 2592000 AFTER ExpectedAmountCents")
    end)
end

local function prepareEconomy()
    vRP.Prepare("ofmoney/create",[[CREATE TABLE IF NOT EXISTS ouro_fino_admin_money_grants (
        OperationId VARCHAR(64) NOT NULL,
        OwnerSource INT NOT NULL,
        OwnerPassport INT NOT NULL,
        TargetPassport INT NOT NULL,
        TargetName VARCHAR(100) NOT NULL,
        AccountType VARCHAR(12) NOT NULL,
        Amount BIGINT UNSIGNED NOT NULL,
        Reason VARCHAR(120) NOT NULL,
        BalanceBefore BIGINT NOT NULL DEFAULT 0,
        BalanceAfter BIGINT NOT NULL DEFAULT 0,
        Status VARCHAR(20) NOT NULL DEFAULT 'processing',
        CreatedAt INT NOT NULL,
        CompletedAt INT NOT NULL DEFAULT 0,
        PRIMARY KEY (OperationId),
        KEY idx_target_created (TargetPassport,CreatedAt)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])
    vRP.Prepare("ofmoney/get","SELECT OperationId,Status FROM ouro_fino_admin_money_grants WHERE OperationId = @OperationId LIMIT 1")
    vRP.Prepare("ofmoney/insert","INSERT INTO ouro_fino_admin_money_grants (OperationId,OwnerSource,OwnerPassport,TargetPassport,TargetName,AccountType,Amount,Reason,BalanceBefore,BalanceAfter,Status,CreatedAt) VALUES (@OperationId,@OwnerSource,@OwnerPassport,@TargetPassport,@TargetName,@AccountType,@Amount,@Reason,@BalanceBefore,@BalanceAfter,'processing',UNIX_TIMESTAMP())")
    vRP.Prepare("ofmoney/finish","UPDATE ouro_fino_admin_money_grants SET BalanceAfter = @BalanceAfter, Status = @Status, CompletedAt = UNIX_TIMESTAMP() WHERE OperationId = @OperationId")
    vRP.Execute("ofmoney/create")
end

local function vehicleWeight(model)
    local ok,weight = pcall(function()
        return exports.vrp:VehicleWeight(model)
    end)

    weight = ok and parseInt(weight or 0) or 0
    return weight > 0 and weight or 40
end

local function removePlanBenefits(passport)
    for _,permission in ipairs(PlanPermissions) do
        vRP.RemovePermission(passport,permission)
    end

    vRP.RemovePermission(passport,"Porte")

    for _,model in ipairs(DeprecatedPlanVehicles) do
        vRP.Query("vehicles/removeVehicles",{ Passport = passport, Vehicle = model })
    end

    local removed = {}
    for _,plan in pairs(Plans) do
        for _,model in ipairs(plan.vehicles) do
            if not removed[model] then
                removed[model] = true
                vRP.Query("vehicles/removeVehicles",{ Passport = passport, Vehicle = model })
            end
        end
    end
end

local function applyPlan(passport,source,planKey)
    local plan = Plans[planKey]
    if not passport or not plan then
        return false,0
    end

    for _,model in ipairs(DeprecatedPlanVehicles) do
        vRP.Query("vehicles/removeVehicles",{ Passport = passport, Vehicle = model })
    end

    for _,permission in ipairs(PlanPermissions) do
        if permission ~= plan.permission then
            vRP.RemovePermission(passport,permission)
        end
    end

    vRP.SetPermission(passport,plan.permission,1)

    if plan.weaponLicense then
        vRP.SetPermission(passport,"Porte",1)
    else
        vRP.RemovePermission(passport,"Porte")
    end

    local added = 0
    for _,model in ipairs(plan.vehicles) do
        if not vRP.SelectVehicle(passport,model) then
            vRP.Query("vehicles/addVehicles",{
                Passport = passport,
                Vehicle = model,
                Plate = vRP.GeneratePlate(),
                Weight = vehicleWeight(model),
                Work = 0
            })
            added = added + 1
        end
    end

    if source and source > 0 then
        notify(source,("Plano %s aplicado. %s veiculos conferidos."):format(plan.label,added),"verde")
    end

    return true,added
end

local function grantPlan(passport,planKey,assignedBy,durationSeconds,reason)
    passport = parseInt(passport)
    planKey = tostring(planKey or ""):lower()
    assignedBy = math.max(0,parseInt(assignedBy or OWNER_PASSPORT))
    durationSeconds = math.max(0,parseInt(durationSeconds or 0))

    local requested = Plans[planKey]
    if passport <= 0 or not requested then
        return false,"ID ou plano invalido."
    end

    if PlanOperations[passport] then
        return false,"Ja existe uma alteracao de plano em processamento."
    end

    PlanOperations[passport] = true
    local now = os.time()
    local current = vRP.SingleQuery("ofplans/get",{ Passport = passport })
    local currentKey = current and tostring(current.Plan or ""):lower() or ""
    local currentPlan = Plans[currentKey]
    local currentExpires = current and parseInt(current.ExpiresAt or 0) or 0

    if currentPlan and currentExpires > 0 and currentExpires <= now then
        vRP.Query("ofplans/remove",{ Passport = passport })
        removePlanBenefits(passport)
        current = nil
        currentKey = ""
        currentPlan = nil
        currentExpires = 0
    end

    if currentPlan and currentPlan.priority > requested.priority then
        PlanOperations[passport] = nil
        return false,("O jogador ja possui o plano superior %s."):format(currentPlan.label)
    end

    if currentPlan and currentKey == planKey and currentExpires == 0 and durationSeconds > 0 then
        PlanOperations[passport] = nil
        return false,("O jogador ja possui %s permanente."):format(currentPlan.label)
    end

    local expiresAt = 0
    if durationSeconds > 0 then
        local base = now
        if currentPlan and currentKey == planKey and currentExpires > now then
            base = currentExpires
        end
        expiresAt = base + durationSeconds
    end

    if currentPlan and currentKey ~= planKey then
        removePlanBenefits(passport)
    end

    vRP.Query("ofplans/set",{
        Passport = passport,
        Plan = planKey,
        AssignedBy = assignedBy,
        ExpiresAt = expiresAt
    })

    local applied = applyPlan(passport,getSourceFromPassport(passport),planKey)
    PlanOperations[passport] = nil

    if not applied then
        return false,"Nao foi possivel aplicar os beneficios do plano."
    end

    local durationMessage = expiresAt > 0 and (" valido ate %s"):format(os.date("%d/%m/%Y %H:%M",expiresAt)) or " permanente"
    print(("[af_owner_panel/plans] passport=%s plan=%s assignedBy=%s expiresAt=%s reason=%s"):format(passport,planKey,assignedBy,expiresAt,tostring(reason or "admin")))
    return true,("Plano %s ativado%s."):format(requested.label,durationMessage),expiresAt
end

local function expirePlan(passport)
    passport = parseInt(passport)
    if passport <= 0 or PlanOperations[passport] then
        return false
    end

    PlanOperations[passport] = true
    local current = vRP.SingleQuery("ofplans/get",{ Passport = passport })
    local expiresAt = current and parseInt(current.ExpiresAt or 0) or 0
    if not current or expiresAt <= 0 or expiresAt > os.time() then
        PlanOperations[passport] = nil
        return false
    end

    vRP.Query("ofplans/remove",{ Passport = passport })
    removePlanBenefits(passport)
    PlanOperations[passport] = nil
    print(("[af_owner_panel/plans] expired passport=%s plan=%s"):format(passport,tostring(current.Plan or "")))
    return true
end

exports("GrantPlan",function(passport,planKey,assignedBy,durationSeconds,reason)
    local invokingResource = GetInvokingResource()
    if invokingResource ~= "pause" then
        print(("[af_owner_panel/plans] export bloqueado resource=%s"):format(tostring(invokingResource)))
        return false,"Origem nao autorizada."
    end

    return grantPlan(passport,planKey,assignedBy,durationSeconds,reason)
end)

CreateThread(function()
    preparePlans()
    local economyOk,economyError = pcall(prepareEconomy)
    EconomyReady = economyOk
    if not economyOk then
        print(("[af_owner_panel/economy] falha ao preparar auditoria: %s"):format(tostring(economyError)))
    end
    Wait(500)

    local ok,rows = pcall(function()
        return vRP.Query("ofplans/all")
    end)

    if ok and rows then
        for _,row in ipairs(rows) do
            local passport = parseInt(row.Passport)
            local planKey = tostring(row.Plan or ""):lower()

            local expiresAt = parseInt(row.ExpiresAt or 0)
            if passport > 0 and Plans[planKey] then
                if expiresAt > 0 and expiresAt <= os.time() then
                    expirePlan(passport)
                else
                    applyPlan(passport,nil,planKey)
                end
            end
        end
    end
end)

AddEventHandler("Connect",function(Passport,source)
    local ok,row = pcall(function()
        return vRP.SingleQuery("ofplans/get",{ Passport = Passport })
    end)

    if not ok then
        preparePlans()
        row = vRP.SingleQuery("ofplans/get",{ Passport = Passport })
    end

    if row and row.Plan and Plans[row.Plan] then
        local expiresAt = parseInt(row.ExpiresAt or 0)
        if expiresAt > 0 and expiresAt <= os.time() then
            expirePlan(Passport)
        else
            applyPlan(Passport,source,row.Plan)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(60000)
        local rows = MySQL.query.await("SELECT Passport FROM ouro_fino_plans WHERE ExpiresAt > 0 AND ExpiresAt <= UNIX_TIMESTAMP()") or {}
        for _,row in ipairs(rows) do
            expirePlan(row.Passport)
        end
    end
end)

local function keyboardPrimary(source,first)
    local keyboard = vKEYBOARD.Primary(source,first)
    return keyboard and keyboard[1]
end

local function keyboardSecondary(source,first,second)
    local keyboard = vKEYBOARD.Secondary(source,first,second)
    return keyboard and keyboard[1],keyboard and keyboard[2]
end

local function keyboardTertiary(source,first,second,third)
    local keyboard = vKEYBOARD.Tertiary(source,first,second,third)
    return keyboard and keyboard[1],keyboard and keyboard[2],keyboard and keyboard[3]
end

local function normalizePlan(plan)
    plan = tostring(plan or ""):lower():gsub("%s+","")

    if plan == "premium" then
        return "premium"
    elseif plan == "vip" then
        return "vip"
    elseif plan == "standard" or plan == "padrao" then
        return "standard"
    end

    return plan
end

local function normalizeJob(job)
    local raw = tostring(job or "")
    local key = raw:lower():gsub("%s+","")
    local aliases = {
        policia = "LSPD",
        police = "LSPD",
        lspd = "LSPD",
		bcso = "BCSO",
		sapr = "SAPR",
        medico = "Paramedico",
        medica = "Paramedico",
        enfermeiro = "Paramedico",
        enfermeira = "Paramedico",
        paramedico = "Paramedico",
        mecanico = "Bennys",
        mecanica = "Bennys",
        bennys = "Bennys",
		ofc = "OFC",
		ourofightclub = "OFC",
        vampiro = "Vampire",
		vampire = "Vampire",
		bruxo = "Bruxo",
		wizard = "Bruxo",
		witch = "Bruxo",
		pombal = "Pombal",
		ballas = "Pombal",
		saojudas = "SaoJudas",
		["sãojudas"] = "SaoJudas",
		vagos = "SaoJudas"
	}

    return aliases[key] or raw
end

local function jobHierarchy(job)
    job = normalizeJob(job)
    if not OwnerJobIds[job] then
        return nil
    end

    local group = type(Groups) == "table" and Groups[job] or nil
    if type(group) ~= "table" or type(group.Hierarchy) ~= "table" or #group.Hierarchy == 0 then
        return nil
    end

    return group.Hierarchy,job
end

local function buildJobHierarchies()
    local payload = {}

    for _,job in ipairs(OwnerJobs) do
        local hierarchy = jobHierarchy(job.id)
        if hierarchy then
            local ranks = {}
            for level,rank in ipairs(hierarchy) do
                ranks[#ranks + 1] = {
                    level = level,
                    label = tostring(rank)
                }
            end

            payload[#payload + 1] = {
                id = job.id,
                label = job.label,
                ranks = ranks
            }
        end
    end

    return payload
end

local function persistSpecialPermission(passport,permission,enabled)
	if permission ~= "Vampire" and permission ~= "Bruxo" and permission ~= "Pombal" and permission ~= "SaoJudas" then
		return true
	end

    local granted = vRP.HasPermission(passport,permission) and true or false
    if granted ~= enabled then
        print(("[af_owner_panel] special_permission_failed passport=%s permission=%s enabled=%s"):format(passport,permission,tostring(enabled)))
        return false
    end

	if permission == "Vampire" then
		TriggerEvent("af_vampire_skill:PermissionChanged",passport,enabled)
	elseif permission == "Bruxo" then
		TriggerEvent("af_witch_broom:PermissionChanged",passport,enabled)
	end

    -- SetPermission salva no entitydata em lote. O cargo especial precisa
    -- sobreviver ate mesmo a um restart logo apos a acao do dono.
    TriggerEvent("SaveServer",true)
    print(("[af_owner_panel] special_permission_saved passport=%s permission=%s enabled=%s"):format(passport,permission,tostring(enabled)))
    return true
end

RegisterNetEvent("af_owner_panel:dynamicAction",function(action)
    local source = source
    action = tostring(action or "")

    if action == "god" then
        if requestOwnerRecovery(source,"owner_panel") then
            TriggerClientEvent("dynamic:Close",source)
        end
        return
    end

    if not isOwner(source) then
        return
    end

    TriggerClientEvent("dynamic:Close",source)
    Wait(100)

    if action == "openPanel" or action == "noclip" or action == "tpway" or action == "dogcds" or action == "blipsreload" or action == "itemCatalog" or action == "giveItem" or action == "telaoEdit" or action == "telaoSave" then
        TriggerClientEvent("af_owner_panel:runClientAction",source,action)
        return
    end

    if action == "setAdmin" then
        local passport,level = keyboardSecondary(source,"ID/passaporte","Nivel Admin")
        passport = parseInt(passport)
        level = math.max(parseInt(level or 1),1)

        if passport <= 0 then
            notify(source,"ID/passaporte invalido.","vermelho")
            return
        end

        vRP.SetPermission(passport,"Admin",level)
        notify(source,("Admin nivel %s aplicado ao ID %s."):format(level,passport),"verde")
        return
    end

    if action == "removeAdmin" then
        local passport = parseInt(keyboardPrimary(source,"ID/passaporte"))

        if passport <= 0 then
            notify(source,"ID/passaporte invalido.","vermelho")
            return
        end

        vRP.RemovePermission(passport,"Admin")
        notify(source,("Admin removido do ID %s."):format(passport),"verde")
        return
    end

    if action == "setJob" then
		local passport,job,level = keyboardTertiary(source,"ID/passaporte","Cargo: LSPD, Paramedico, Bennys, OFC, Vampire, Bruxo, Pombal ou Sao Judas","Nivel")
        passport = parseInt(passport)
        job = normalizeJob(job)
        level = math.max(parseInt(level or 1),1)
		local hierarchy = jobHierarchy(job)

        if passport <= 0 or not hierarchy or level > #hierarchy then
            notify(source,"ID, cargo ou patente invalida.","vermelho")
            return
        end

        vRP.SetPermission(passport,job,level)
        if not persistSpecialPermission(passport,job,true) then
            notify(source,"O cargo nao foi persistido pela base.","vermelho")
            return
        end
        notify(source,("Cargo %s - %s aplicado ao ID %s."):format(job,hierarchy[level],passport),"verde")
        return
    end

    if action == "removeJob" then
		local passport,job = keyboardSecondary(source,"ID/passaporte","Cargo: LSPD, Paramedico, Bennys, OFC, Vampire, Bruxo, Pombal ou Sao Judas")
        passport = parseInt(passport)
        job = normalizeJob(job)
		local hierarchy = jobHierarchy(job)

        if passport <= 0 or not hierarchy then
            notify(source,"ID ou cargo invalido.","vermelho")
            return
        end

        vRP.RemovePermission(passport,job)
        if not persistSpecialPermission(passport,job,false) then
            notify(source,"O cargo nao foi removido da persistencia.","vermelho")
            return
        end
        notify(source,("Cargo %s removido do ID %s."):format(job,passport),"verde")
        return
    end

    if action == "setPlan" then
        local passport,planKey = keyboardSecondary(source,"ID/passaporte","Plano: premium, vip ou standard")
        passport = parseInt(passport)
        planKey = normalizePlan(planKey)

        if passport <= 0 or not Plans[planKey] then
            notify(source,"ID ou plano invalido.","vermelho")
            return
        end

        local granted,message = grantPlan(passport,planKey,OWNER_PASSPORT,0,"owner-dynamic")
        notify(source,granted and message or (message or "Nao foi possivel aplicar o plano."),granted and "verde" or "vermelho")
        return
    end

    if action == "removePlan" then
        local passport = parseInt(keyboardPrimary(source,"ID/passaporte"))

        if passport <= 0 then
            notify(source,"ID/passaporte invalido.","vermelho")
            return
        end

        vRP.Query("ofplans/remove",{ Passport = passport })
        removePlanBenefits(passport)
        notify(source,("Plano removido do ID %s."):format(passport),"verde")
        return
    end

    if action == "tptome" then
        local passport = parseInt(keyboardPrimary(source,"ID/passaporte online"))
        local target = getSourceFromPassport(passport)

        if not target or target <= 0 or not GetPlayerName(target) then
            notify(source,"Jogador alvo nao encontrado online.","vermelho")
            return
        end

        local ped = GetPlayerPed(source)
        local targetPed = GetPlayerPed(target)
        local coords = GetEntityCoords(ped)
        SetEntityCoords(targetPed,coords.x + 1.0,coords.y,coords.z,false,false,false,false)
        notify(source,"Jogador puxado ate voce.","verde")
        return
    end

    if action == "ban" then
        local passport,reason = keyboardSecondary(source,"ID/passaporte","Motivo")
        passport = parseInt(passport)
        reason = tostring(reason or "Banimento administrativo")
        local account = getAccountFromPassport(passport)

        if passport <= 0 or not account then
            notify(source,"Conta do ID informado nao encontrada.","vermelho")
            return
        end

        vRP.Update("accounts/BannedPermanent",{ Account = account.id, Reason = reason })

        local target = getSourceFromPassport(passport)
        if target then
            DropPlayer(target,"Banido: "..reason)
        end

        notify(source,("ID %s banido."):format(passport),"verde")
        return
    end

    if action == "giveWeapon" then
        local passport,item,ammo = keyboardTertiary(source,"ID/passaporte online","Arma ex: WEAPON_COMBATPISTOL","Municao")
        passport = parseInt(passport)
        item = tostring(item or "")
        ammo = math.max(parseInt(ammo or 0),0)

        if giveAdminItem(source,passport,item,1) and ammo > 0 and AdminWeaponAmmo[item] then
            giveAdminItem(source,passport,AdminWeaponAmmo[item],ammo)
        end
        return
    end

    if action == "givePoliceKit" then
        local passport = parseInt(keyboardPrimary(source,"ID/passaporte online"))

        if passport <= 0 then
            notify(source,"ID/passaporte invalido.","vermelho")
            return
        end

        local delivered = 0
        for _,entry in ipairs(PoliceKit) do
            if giveAdminItem(source,passport,entry.item,entry.amount) then
                delivered = delivered + 1
            else
                break
            end
        end

        if delivered > 0 then
            notify(source,("Kit policial enviado ao ID %s."):format(passport),"verde")
        end
        return
    end

    if action == "telaoOn" or action == "telaoUrl" then
        local url = keyboardPrimary(source,"Link YouTube / live")
        if not url or url == "" then
            notify(source,"Link invalido.","vermelho")
            return
        end

        handleTelao(source,action == "telaoOn" and "on" or "url",{ url = url, silent = false })
        notify(source,"Comando enviado ao telao.","verde")
        return
    end

    if action == "telaoOff" then
        handleTelao(source,"off",{ silent = false })
        notify(source,"Telao desligado.","verde")
        return
    end

    if action == "telaoHere" then
        local url = keyboardPrimary(source,"Link YouTube / live")
        if not url or url == "" then
            notify(source,"Link invalido.","vermelho")
            return
        end

        TriggerClientEvent("af_owner_panel:runTelaoHere",source,url)
        return
    end
end)

local function buildPremiumOrders(status)
    local allowed = { all = true, pending = true, awaiting_review = true, approved = true, rejected = true, expired = true }
    status = tostring(status or "awaiting_review"):lower()
    if not allowed[status] then
        status = "awaiting_review"
    end

    MySQL.update.await("UPDATE ouro_fino_premium_orders SET Status = 'expired', UpdatedAt = UNIX_TIMESTAMP() WHERE Status IN ('pending','awaiting_review') AND ExpiresAt > 0 AND ExpiresAt <= UNIX_TIMESTAMP()",{})

    local where = status == "all" and "" or "WHERE premium_orders.Status = ?"
    local parameters = status == "all" and {} or { status }
    local rows = MySQL.query.await(([[SELECT premium_orders.OrderId,premium_orders.Passport,premium_orders.Plan,premium_orders.ExpectedAmountCents,
        premium_orders.DurationSeconds,premium_orders.Status,premium_orders.CreatedAt,premium_orders.UpdatedAt,premium_orders.ExpiresAt,
        premium_orders.ApprovedBy,premium_orders.ProcessedAt,premium_orders.LastError,characters.Name,characters.Lastname
        FROM ouro_fino_premium_orders premium_orders
        LEFT JOIN characters ON characters.id = premium_orders.Passport
        %s ORDER BY premium_orders.CreatedAt DESC LIMIT 200]]):format(where),parameters) or {}

    local result = {}
    for _,row in ipairs(rows) do
        result[#result + 1] = {
            orderId = row.OrderId,
            passport = parseInt(row.Passport),
            playerName = ((row.Name or "Jogador").." "..(row.Lastname or "")):gsub("%s+$",""),
            plan = tostring(row.Plan or ""),
            planName = Plans[tostring(row.Plan or ""):lower()] and Plans[tostring(row.Plan or ""):lower()].label or tostring(row.Plan or ""),
            amountCents = parseInt(row.ExpectedAmountCents or 0),
            durationSeconds = parseInt(row.DurationSeconds or 0),
            status = tostring(row.Status or "pending"),
            createdAt = parseInt(row.CreatedAt or 0),
            expiresAt = parseInt(row.ExpiresAt or 0),
            approvedBy = parseInt(row.ApprovedBy or 0),
            processedAt = parseInt(row.ProcessedAt or 0),
            lastError = tostring(row.LastError or "")
        }
    end

    return result
end

local function sendPremiumOrders(source,status)
    TriggerClientEvent("af_owner_panel:premiumOrders",source,{
        status = status or "awaiting_review",
        orders = buildPremiumOrders(status)
    })
end

RegisterCommand("ofadmin",function(source)
    if source == 0 then
        print("[af_owner_panel] Use F9 > Central Administrativa dentro do jogo.")
        return
    end

    if not isOwner(source) then
        notify(source,"Acesso permitido apenas ao dono ID 1.","vermelho")
        return
    end

    notify(source,"O painel /ofadmin foi removido. Use F9 > Central Administrativa.","amarelo")
end,false)

RegisterNetEvent("af_owner_panel:requestOpen",function()
    local source = source
    if not isOwner(source) then
        notify(source,"Acesso permitido apenas ao dono ID 1.","vermelho")
        return
    end

    notify(source,"Use F9 > Central Administrativa.","amarelo")
end)

RegisterNetEvent("af_owner_panel:clientAction",function(action)
    local source = source

    if tostring(action or "") == "god" then
        requestOwnerRecovery(source,"owner_panel")
        return
    end

    if not isOwner(source) then
        return
    end

    TriggerClientEvent("af_owner_panel:runClientAction",source,tostring(action or ""))
end)

RegisterNetEvent("af_owner_panel:requestPanelSelfRecovery",function()
    requestOwnerRecovery(source,"owner_panel")
end)

RegisterNetEvent("af_owner_panel:requestEmergencySelfRecovery",function()
    requestOwnerRecovery(source,"ofrecover")
end)

RegisterNetEvent("af_owner_panel:requestProtectionToggle",function()
    requestOwnerProtectionToggle(source)
end)

RegisterNetEvent("af_owner_panel:requestSelfRelease",function()
    requestOwnerRelease(source)
end)

RegisterNetEvent("af_owner_panel:requestCatalog",function()
    local source = source
    if not isOwner(source) then
        return
    end

    TriggerClientEvent("af_owner_panel:catalog",source,buildCatalog())
end)

RegisterNetEvent("af_owner_panel:requestJobHierarchies",function()
    local source = source
    if not isOwner(source) then
        return
    end

    TriggerClientEvent("af_owner_panel:jobHierarchies",source,buildJobHierarchies())
end)

RegisterNetEvent("af_owner_panel:requestPlayers",function()
    local source = source
    if not isOwner(source) then
        return
    end

    TriggerClientEvent("af_owner_panel:players",source,buildPlayers())
end)

RegisterNetEvent("af_owner_panel:requestServerState",function()
    local source = source
    if not isOwner(source) then
        return
    end

    sendServerState(source)
end)

RegisterNetEvent("af_owner_panel:requestPremiumOrders",function(status)
    local source = source
    if not isOwner(source) then
        return
    end

    sendPremiumOrders(source,status)
end)

RegisterNetEvent("af_owner_panel:reviewPremiumOrder",function(payload)
    local source = source
    if not isOwner(source) then
        return
    end

    payload = type(payload) == "table" and payload or {}
    local orderId = tostring(payload.orderId or ""):match("^[%w%-]+$")
    local action = tostring(payload.action or ""):lower()
    if not orderId or (action ~= "approve" and action ~= "reject") or PremiumOrderOperations[orderId] then
        notify(source,"Pedido ou acao invalida.","vermelho")
        return
    end

    PremiumOrderOperations[orderId] = true
    local row = MySQL.single.await("SELECT * FROM ouro_fino_premium_orders WHERE OrderId = ? LIMIT 1",{ orderId })
    if not row then
        PremiumOrderOperations[orderId] = nil
        notify(source,"Pedido nao encontrado.","vermelho")
        sendPremiumOrders(source,payload.status)
        return
    end

    if parseInt(row.ExpiresAt or 0) > 0 and parseInt(row.ExpiresAt) <= os.time() and row.Status ~= "approved" then
        MySQL.update.await("UPDATE ouro_fino_premium_orders SET Status = 'expired', UpdatedAt = UNIX_TIMESTAMP() WHERE OrderId = ? AND Status <> 'approved'",{ orderId })
        PremiumOrderOperations[orderId] = nil
        notify(source,"Este pedido expirou.","amarelo")
        sendPremiumOrders(source,payload.status)
        return
    end

    if action == "reject" then
        local updated = MySQL.update.await([[UPDATE ouro_fino_premium_orders
            SET Status = 'rejected', UpdatedAt = UNIX_TIMESTAMP(), ApprovedBy = ?, ProcessedAt = UNIX_TIMESTAMP(), LastError = ''
            WHERE OrderId = ? AND Status IN ('pending','awaiting_review')]],{ OWNER_PASSPORT,orderId })
        PremiumOrderOperations[orderId] = nil

        if parseInt(updated or 0) == 1 then
            local target = getSourceFromPassport(row.Passport)
            if target then
                notify(target,"Seu pedido Premium foi recusado. Procure o suporte para mais informacoes.","amarelo")
            end
            notify(source,"Pedido recusado.","verde")
        else
            notify(source,"O pedido ja foi processado por outra acao.","amarelo")
        end

        sendPremiumOrders(source,payload.status)
        return
    end

    local reserved = MySQL.update.await([[UPDATE ouro_fino_premium_orders
        SET Status = 'processing', UpdatedAt = UNIX_TIMESTAMP(), ApprovedBy = ?, LastError = ''
        WHERE OrderId = ? AND Status = 'awaiting_review']],{ OWNER_PASSPORT,orderId })

    if parseInt(reserved or 0) ~= 1 then
        PremiumOrderOperations[orderId] = nil
        notify(source,"O pedido precisa estar aguardando revisao ou ja foi processado.","amarelo")
        sendPremiumOrders(source,payload.status)
        return
    end

    local granted,message = grantPlan(row.Passport,row.Plan,OWNER_PASSPORT,row.DurationSeconds,"pix:"..orderId)
    if granted then
        MySQL.update.await([[UPDATE ouro_fino_premium_orders
            SET Status = 'approved', UpdatedAt = UNIX_TIMESTAMP(), ProcessedAt = UNIX_TIMESTAMP(), LastError = ''
            WHERE OrderId = ? AND Status = 'processing']],{ orderId })
        local target = getSourceFromPassport(row.Passport)
        if target then
            notify(target,message or "Seu plano foi aprovado e ativado.","verde")
        end
        notify(source,message or "Pagamento aprovado e plano ativado.","verde")
    else
        local errorMessage = tostring(message or "Falha ao aplicar o plano."):gsub("[%c]"," "):sub(1,255)
        MySQL.update.await([[UPDATE ouro_fino_premium_orders
            SET Status = 'awaiting_review', UpdatedAt = UNIX_TIMESTAMP(), ApprovedBy = 0, LastError = ?
            WHERE OrderId = ? AND Status = 'processing']],{ errorMessage,orderId })
        notify(source,errorMessage,"vermelho")
    end

    PremiumOrderOperations[orderId] = nil
    sendPremiumOrders(source,payload.status)
end)

RegisterNetEvent("af_owner_panel:telao",function(action,payload)
    local source = source
    if not isOwner(source) then
        return
    end

    action = tostring(action or "")
    payload = type(payload) == "table" and payload or {}

    local allowedActions = {
        on = true,
        off = true,
        url = true,
        set = true,
        save = true,
        volume = true,
        range = true,
        audio = true,
        occlusion = true,
        setBaseVolume = true,
        setMaxAudioDistance = true,
        setInnerAudioRadius = true,
        setAudioFalloff = true,
        setAudioFade = true,
        setAudioEnabled = true,
        setOcclusion = true,
        pause = true,
        resume = true,
        reload = true,
        sync = true,
        reset = true
    }

    if allowedActions[action] then
        payload.silent = payload.silent == true
        handleTelao(source,action,payload)
        SetTimeout(150,function()
            if GetPlayerName(source) then sendServerState(source) end
        end)
    end
end)

RegisterNetEvent("af_owner_panel:grantMoney",function(payload)
    local source = source
    payload = type(payload) == "table" and payload or {}
    local operationId = validOperationId(payload.operationId)

    if not isOwner(source) then
        print(("[af_owner_panel/economy] blocked source=%s action=grantMoney"):format(tostring(source)))
        return
    end

    if not EconomyConfig.Enabled or not EconomyReady then
        moneyResult(source,{ success = false, operationId = operationId, message = "A ferramenta financeira esta temporariamente indisponivel." })
        return
    end

    if not operationId then
        moneyResult(source,{ success = false, message = "Identificador da operacao invalido." })
        return
    end

    if EconomyOperations[operationId] then
        moneyResult(source,{ success = false, operationId = operationId, message = "Esta operacao ja esta em processamento." })
        return
    end

    local now = GetGameTimer()
    if now < (EconomyCooldowns[source] or 0) then
        moneyResult(source,{ success = false, operationId = operationId, message = "Aguarde um instante antes de realizar outra concessao." })
        return
    end

    local ownerPassport = vRP.Passport(source)
    local targetPassport = parseInt(payload.passport)
    local targetSource = getSourceFromPassport(targetPassport)
    local account = tostring(payload.account or ""):lower()
    local amountNumber = tonumber(payload.amount)
    local reason = sanitizeReason(payload.reason)

    if not ownerPassport or tonumber(ownerPassport) ~= OWNER_PASSPORT then
        moneyResult(source,{ success = false, operationId = operationId, message = "Acesso financeiro negado." })
        return
    end

    if targetPassport <= 0 or not targetSource or targetSource <= 0 or not GetPlayerName(targetSource) then
        moneyResult(source,{ success = false, operationId = operationId, message = "O jogador selecionado nao esta mais conectado." })
        return
    end

    if not AllowedEconomyAccounts[account] then
        moneyResult(source,{ success = false, operationId = operationId, message = "Destino financeiro invalido." })
        return
    end

    if not amountNumber or amountNumber ~= amountNumber or amountNumber == math.huge or amountNumber == -math.huge or amountNumber ~= math.floor(amountNumber) then
        moneyResult(source,{ success = false, operationId = operationId, message = "Informe um valor inteiro valido." })
        return
    end

    local amount = math.floor(amountNumber)
    if amount < EconomyConfig.MinimumGrant or amount > EconomyConfig.MaximumGrant then
        moneyResult(source,{ success = false, operationId = operationId, message = ("O valor deve ficar entre $%s e $%s."):format(EconomyConfig.MinimumGrant,EconomyConfig.MaximumGrant) })
        return
    end

    if #reason < EconomyConfig.MinimumReasonLength then
        moneyResult(source,{ success = false, operationId = operationId, message = "Informe um motivo com pelo menos 4 caracteres." })
        return
    end

    EconomyOperations[operationId] = true
    EconomyCooldowns[source] = now + EconomyConfig.CooldownMilliseconds

    local existingOk,existing = pcall(function()
        return vRP.SingleQuery("ofmoney/get",{ OperationId = operationId })
    end)
    if not existingOk then
        EconomyOperations[operationId] = nil
        moneyResult(source,{ success = false, operationId = operationId, message = "Nao foi possivel consultar o registro da operacao." })
        return
    end

    if existing then
        EconomyOperations[operationId] = nil
        moneyResult(source,{ success = false, operationId = operationId, message = existing.Status == "success" and "Esta concessao ja foi concluida." or "Esta operacao ja foi registrada." })
        return
    end

    local identity = vRP.Identity(targetPassport)
    local targetName = identityName(identity,targetSource,targetPassport):sub(1,100)
    local balanceBefore = account == "cash" and getCashBalance(targetPassport) or getBankBalance(targetPassport)
    local inserted,insertError = pcall(function()
        vRP.Query("ofmoney/insert",{
            OperationId = operationId,
            OwnerSource = source,
            OwnerPassport = ownerPassport,
            TargetPassport = targetPassport,
            TargetName = targetName,
            AccountType = account,
            Amount = amount,
            Reason = reason,
            BalanceBefore = balanceBefore,
            BalanceAfter = balanceBefore
        })
    end)

    if not inserted then
        EconomyOperations[operationId] = nil
        print(("[af_owner_panel/economy] operation=%s status=insert_failed error=%s"):format(operationId,tostring(insertError)))
        moneyResult(source,{ success = false, operationId = operationId, message = "A concessao foi bloqueada porque o log nao pode ser criado." })
        return
    end

    if account == "cash" then
        vRP.GenerateItem(targetPassport,"dollar",amount,true)
    else
        vRP.GiveBank(targetPassport,amount,true)
    end

    local balanceAfter = account == "cash" and getCashBalance(targetPassport) or getBankBalance(targetPassport)
    local success = balanceAfter == balanceBefore + amount
    local status = success and "success" or "failed"
    pcall(function()
        vRP.Query("ofmoney/finish",{
            OperationId = operationId,
            BalanceAfter = balanceAfter,
            Status = status
        })
    end)

    EconomyOperations[operationId] = nil
    local accountLabel = account == "cash" and "carteira" or "banco"
    print(("[af_owner_panel/economy] operation=%s owner=%s target=%s account=%s amount=%s before=%s after=%s reason=%q status=%s"):format(operationId,ownerPassport,targetPassport,account,amount,balanceBefore,balanceAfter,reason,status))

    if success then
        pcall(function()
            if GetResourceState("discord") == "started" then
                exports.discord:Embed("Money",("**[DONO]:** %s\n**[PASSAPORTE]:** %s\n**[DESTINO]:** %s\n**[VALOR]:** $%s\n**[MOTIVO]:** %s\n**[OPERACAO]:** %s"):format(ownerPassport,targetPassport,accountLabel,amount,reason,operationId))
            end
        end)
        notify(source,("$%s concedidos na %s de %s."):format(amount,accountLabel,targetName),"verde")
        notify(targetSource,("Voce recebeu $%s na sua %s por uma concessao administrativa."):format(amount,accountLabel),"verde")
        TriggerClientEvent("af_owner_panel:players",source,buildPlayers())
        moneyResult(source,{
            success = true,
            operationId = operationId,
            message = ("$%s concedidos com sucesso a %s."):format(amount,targetName),
            passport = targetPassport,
            cash = getCashBalance(targetPassport),
            bank = getBankBalance(targetPassport)
        })
    else
        notify(source,"A API financeira nao confirmou a alteracao; a operacao foi marcada como falha.","vermelho")
        moneyResult(source,{ success = false, operationId = operationId, message = "A API financeira nao confirmou a concessao." })
    end
end)

RegisterNetEvent("af_owner_panel:adminAction",function(action,payload)
    local source = source
    if not isOwner(source) then
        return
    end

    action = tostring(action or "")
    payload = type(payload) == "table" and payload or {}

    if action == "setAdmin" then
        local passport = parseInt(payload.passport)
        local level = parseInt(payload.level or 1)
        if passport <= 0 then
            notify(source,"ID/passaporte invalido.","vermelho")
            return
        end

        vRP.SetPermission(passport,"Admin",math.max(level,1))
        notify(source,("Admin aplicado ao ID %s."):format(passport),"verde")

        local target = getSourceFromPassport(passport)
        if target then
            notify(target,"Voce recebeu permissao Admin.","verde")
        end
        return
    end

    if action == "removeAdmin" then
        local passport = parseInt(payload.passport)
        if passport <= 0 then
            notify(source,"ID/passaporte invalido.","vermelho")
            return
        end

        vRP.RemovePermission(passport,"Admin")
        notify(source,("Admin removido do ID %s."):format(passport),"verde")
        return
    end

    if action == "setJob" then
        local passport = parseInt(payload.passport)
        local job = normalizeJob(payload.job)
        local level = parseInt(payload.level or 1)
		local hierarchy,permission = jobHierarchy(job)

        if passport <= 0 or not hierarchy or level < 1 or level > #hierarchy then
            notify(source,"ID, cargo ou patente invalida.","vermelho")
            return
        end

		vRP.SetPermission(passport,permission,level)
        if not persistSpecialPermission(passport,permission,true) then
            notify(source,"O cargo nao foi persistido pela base.","vermelho")
            return
        end
		notify(source,("Cargo %s - %s aplicado ao ID %s."):format(permission,hierarchy[level],passport),"verde")
        return
    end

    if action == "removeJob" then
        local passport = parseInt(payload.passport)
		local hierarchy,permission = jobHierarchy(payload.job)

        if passport <= 0 or not hierarchy then
            notify(source,"ID ou cargo invalido.","vermelho")
            return
        end

        vRP.RemovePermission(passport,permission)
        if not persistSpecialPermission(passport,permission,false) then
            notify(source,"O cargo nao foi removido da persistencia.","vermelho")
            return
        end
        notify(source,("Cargo %s removido do ID %s."):format(permission,passport),"verde")
        return
    end

    if action == "setPlan" then
        local passport = parseInt(payload.passport)
        local planKey = tostring(payload.plan or ""):lower()

        if passport <= 0 or not Plans[planKey] then
            notify(source,"ID ou plano invalido.","vermelho")
            return
        end

        local granted,message = grantPlan(passport,planKey,OWNER_PASSPORT,0,"owner-panel")
        notify(source,granted and message or (message or "Nao foi possivel aplicar o plano."),granted and "verde" or "vermelho")
        return
    end

    if action == "removePlan" then
        local passport = parseInt(payload.passport)
        if passport <= 0 then
            notify(source,"ID/passaporte invalido.","vermelho")
            return
        end

        vRP.Query("ofplans/remove",{ Passport = passport })
        removePlanBenefits(passport)
        notify(source,("Plano removido do ID %s."):format(passport),"verde")
        return
    end

    if action == "giveItem" then
        givePanelItem(source,payload.passport,payload.item,payload.amount)
        return
    end

    if action == "giveWeapon" then
        local passport = parseInt(payload.passport)
        local item = tostring(payload.item or "")
        local ammoAmount = math.max(parseInt(payload.ammo or 0),0)

        if giveAdminItem(source,passport,item,1) and ammoAmount > 0 and AdminWeaponAmmo[item] then
            giveAdminItem(source,passport,AdminWeaponAmmo[item],ammoAmount)
        end
        return
    end

    if action == "givePoliceKit" then
        local passport = parseInt(payload.passport)
        if passport <= 0 then
            notify(source,"ID/passaporte invalido.","vermelho")
            return
        end

        local delivered = 0
        for _,entry in ipairs(PoliceKit) do
            if giveAdminItem(source,passport,entry.item,entry.amount) then
                delivered = delivered + 1
            else
                break
            end
        end

        if delivered > 0 then
            notify(source,("Kit policial enviado ao ID %s."):format(passport),"verde")
        end
        return
    end

    if action == "playersList" then
        TriggerClientEvent("af_owner_panel:players",source,buildPlayers())
        return
    end

    if action == "setWeather" then
        local weather = tostring(payload.weather or ""):upper()
        if not WeatherWhitelist[weather] then
            notify(source,"Clima invalido.","vermelho")
            return
        end

        GlobalState.Weather = weather
        sendServerState(source)
        notify(source,("Clima definido para %s."):format(weather),"verde")
        return
    end

    if action == "setTime" then
        local hour = parseInt(payload.hour)
        local minute = parseInt(payload.minute)

        if hour < 0 or hour > 23 or minute < 0 or minute > 59 then
            notify(source,"Horario invalido.","vermelho")
            return
        end

        GlobalState.Hours = hour
        GlobalState.Minutes = minute
        sendServerState(source)
        notify(source,("Horario definido para %02d:%02d."):format(hour,minute),"verde")
        return
    end

    if action == "tptome" then
        local passport = parseInt(payload.passport)
        local target = getSourceFromPassport(passport)

        if not target or target <= 0 or not GetPlayerName(target) then
            notify(source,"Jogador alvo nao encontrado online.","vermelho")
            return
        end

        local ped = GetPlayerPed(source)
        local targetPed = GetPlayerPed(target)
        local coords = GetEntityCoords(ped)
        SetEntityCoords(targetPed,coords.x + 1.0,coords.y,coords.z,false,false,false,false)
        notify(source,"Jogador puxado ate voce.","verde")
        return
    end

    if action == "ban" then
        local passport = parseInt(payload.passport)
        local reason = tostring(payload.reason or "Banimento administrativo")
        local account = getAccountFromPassport(passport)

        if passport <= 0 or not account then
            notify(source,"Conta do ID informado nao encontrada.","vermelho")
            return
        end

        vRP.Update("accounts/BannedPermanent",{ Account = account.id, Reason = reason })
        local target = getSourceFromPassport(passport)
        if target then
            DropPlayer(target,"Banido: "..reason)
        end

        notify(source,("ID %s banido."):format(passport),"verde")
    end
end)

AddEventHandler("playerDropped",function()
    local droppedSource = tonumber(source)
    EconomyCooldowns[source] = nil
    OwnerRecoveryCooldowns[source] = nil
    OwnerProtectionCooldowns[source] = nil
    OwnerReleaseCooldowns[source] = nil
    OwnerPendingCommandRelease[source] = nil

    if droppedSource then
        for key in pairs(OwnerProtectionBlockCooldowns) do
            if key:match("^[^:]+:"..droppedSource..":") then
                OwnerProtectionBlockCooldowns[key] = nil
            end
        end
    end
end)

AddEventHandler("Connect",function(Passport,source)
    if tonumber(Passport) == OWNER_PASSPORT then
        OwnerProtectionEnabled = true
        OwnerProtectionBlockCooldowns = {}
        OwnerProtectionCooldowns[source] = nil
        OwnerReleaseCooldowns[source] = nil
        OwnerPendingCommandRelease[source] = nil
    end
end)

AddEventHandler("Disconnect",function(Passport,source)
    if tonumber(Passport) == OWNER_PASSPORT then
        OwnerProtectionEnabled = true
        OwnerProtectionBlockCooldowns = {}
        OwnerProtectionCooldowns[source] = nil
        OwnerReleaseCooldowns[source] = nil
        OwnerPendingCommandRelease[source] = nil
    end
end)
