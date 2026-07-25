local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")
local vRP = Proxy.getInterface("vRP")

local API = {}
Tunnel.bindInterface("sao_judas_street_sales",API)

local Prepared = false
local SaleCounter = 0
local SessionsByPassport = {}
local SessionsById = {}
local PedLocks = {}
local PedCooldowns = {}
local PlayerCooldowns = {}
local Attempts = {}
local StreetModes = {}

local function log(message)
    print("[saojudas/street-sales] "..message)
end

local function notify(source,message,color)
    TriggerClientEvent("Notify",source,"São Judas",message,color or "amarelo",5000)
end

local function prepareDatabase()
    if Prepared then return end

    exports.oxmysql:query_async([[CREATE TABLE IF NOT EXISTS sao_judas_street_sales (
        SaleId VARCHAR(96) NOT NULL,
        Passport BIGINT NOT NULL,
        NpcKey VARCHAR(160) NOT NULL,
        NpcNetwork INT NOT NULL DEFAULT 0,
        NpcModel BIGINT NOT NULL DEFAULT 0,
        RoutingBucket INT NOT NULL DEFAULT 0,
        Item VARCHAR(64) DEFAULT NULL,
        Quantity INT NOT NULL DEFAULT 0,
        UnitPrice INT NOT NULL DEFAULT 0,
        GrossAmount INT NOT NULL DEFAULT 0,
        WorkerAmount INT NOT NULL DEFAULT 0,
        FactionAmount INT NOT NULL DEFAULT 0,
        Region VARCHAR(64) NOT NULL DEFAULT 'Cidade',
        Demand VARCHAR(32) NOT NULL DEFAULT 'Normal',
        ReputationLevel INT NOT NULL DEFAULT 1,
        ReputationApplied TINYINT(1) NOT NULL DEFAULT 0,
        Reaction VARCHAR(32) DEFAULT NULL,
        Status VARCHAR(32) NOT NULL,
        Reason VARCHAR(96) DEFAULT NULL,
        CreatedAt BIGINT NOT NULL,
        UpdatedAt BIGINT NOT NULL,
        CompletedAt BIGINT DEFAULT NULL,
        PRIMARY KEY (SaleId),
        KEY idx_sj_sales_passport (Passport),
        KEY idx_sj_sales_npc (NpcKey),
        KEY idx_sj_sales_created (CreatedAt)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci]])

    exports.oxmysql:query_async([[CREATE TABLE IF NOT EXISTS sao_judas_distribution_reputation (
        Passport BIGINT NOT NULL,
        Sales INT NOT NULL DEFAULT 0,
        Units INT NOT NULL DEFAULT 0,
        GrossAmount BIGINT NOT NULL DEFAULT 0,
        Refusals INT NOT NULL DEFAULT 0,
        Reports INT NOT NULL DEFAULT 0,
        LastSale BIGINT DEFAULT NULL,
        Level INT NOT NULL DEFAULT 1,
        UpdatedAt BIGINT NOT NULL,
        PRIMARY KEY (Passport)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci]])

    exports.oxmysql:query_async([[ALTER TABLE sao_judas_street_sales
        ADD COLUMN IF NOT EXISTS ReputationLevel INT NOT NULL DEFAULT 1,
        ADD COLUMN IF NOT EXISTS ReputationApplied TINYINT(1) NOT NULL DEFAULT 0]])

    exports.oxmysql:execute_async([[UPDATE sao_judas_street_sales
        SET Status = 'cancelled',Reason = 'resource_restart',UpdatedAt = ?
        WHERE Status IN ('created','negotiating','accepted','processing')]],{ os.time() })

    Prepared = true
end

local function strictInteger(value)
    local number = tonumber(value)
    if not number or number ~= math.floor(number) or number <= 0 or number > 2147483647 then
        return nil
    end
    return number
end

local function revenueSplit(gross)
    local workerPercentage = strictInteger(SaoJudasStreetSales.Revenue.WorkerPercentage)
    local factionPercentage = strictInteger(SaoJudasStreetSales.Revenue.FactionPercentage)
    if not workerPercentage or not factionPercentage or workerPercentage + factionPercentage ~= 100 then
        return nil,"invalid_revenue_configuration"
    end

    local factionAmount = math.floor((gross * factionPercentage) / 100)
    local workerAmount = gross - factionAmount
    if workerAmount <= 0 or factionAmount <= 0 then return nil,"invalid_revenue_split" end
    return workerAmount,factionAmount
end

local function finiteNumber(value)
    value = tonumber(value)
    return value and value == value and value ~= math.huge and value ~= -math.huge and value or nil
end

local function distance(a,b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
end

local function canUseDistribution(Passport,skipCache)
    local ok,allowed = pcall(function()
        return exports.sao_judas_operations:CanUseDistribution(Passport,skipCache == true)
    end)
    return ok and allowed == true
end

local function distributionAccess(Passport,skipCache)
    local access = {
        IsMember = false,
        IsLeader = false,
        HasDistributionRole = false,
        Authorized = false
    }

    local ok = pcall(function()
        access.IsMember = exports.sao_judas_operations:IsMember(Passport) == true
        access.IsLeader = exports.sao_judas_operations:IsLeader(Passport) == true
        access.HasDistributionRole = exports.sao_judas_operations:HasDistributionRole(Passport,skipCache == true) == true
    end)

    access.Authorized = ok and access.IsMember and (access.IsLeader or access.HasDistributionRole)
    return access
end

local function playerAlive(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end
    return GetEntityHealth(ped) > 100
end

local function inventoryAmount(Passport,item)
    local result = vRP.InventoryItemAmount(Passport,item)
    return result and tonumber(result[1]) or 0,result and result[2] or item
end

local function availableDrugs(Passport)
    local products = {}
    for item,settings in pairs(SaoJudasStreetSales.Drugs) do
        if settings.Enabled then
            local amount = inventoryAmount(Passport,item)
            if amount >= settings.MinimumQuantity then
                products[#products + 1] = {
                    Item = item,
                    Name = exports.vrp:ItemName(item) or item,
                    Image = exports.vrp:ItemIndex(item) or item,
                    Available = amount,
                    Maximum = math.min(amount,settings.MaximumQuantity,SaoJudasStreetSales.Quantity.Maximum),
                    MinimumPrice = settings.MinimumPrice,
                    MaximumPrice = settings.MaximumPrice
                }
            end
        end
    end

    table.sort(products,function(a,b) return a.Name < b.Name end)
    return products
end

local function playerVehicleState(source,allowVehicle)
    local ped = GetPlayerPed(source)
    local vehicle = ped and ped ~= 0 and GetVehiclePedIsIn(ped,false) or 0
    if not vehicle or vehicle == 0 then
        return true,{ InVehicle = false,Vehicle = 0,Speed = 0.0 }
    end

    local settings = SaoJudasStreetSales.StreetMode.VehicleSales
    if not allowVehicle or not settings or settings.Enabled ~= true then
        return false,"player_in_vehicle"
    end

    if settings.DriverOnly ~= false and GetPedInVehicleSeat(vehicle,-1) ~= ped then
        return false,"vehicle_driver_required"
    end

    local speed = tonumber(GetEntitySpeed(vehicle)) or 0.0
    if speed > (tonumber(settings.MaximumSpeed) or 0.35) then
        return false,"vehicle_moving"
    end

    return true,{ InVehicle = true,Vehicle = vehicle,Speed = speed }
end

local function validPlayerState(source,Passport,options)
    if not SaoJudasStreetSales.Enabled then return false,"disabled" end
    if not Passport or not canUseDistribution(Passport,true) then return false,"not_authorized" end
    local bucket = GetPlayerRoutingBucket(source)
    if not SaoJudasStreetSales.StreetMode.AllowedRoutingBuckets[bucket] then return false,"routing_bucket_blocked" end
    if Player(source).state.Safezone then return false,"safezone" end
    if Player(source).state.Handcuff or Player(source).state.Buttons then return false,"player_busy" end
    if not playerAlive(source) then return false,"player_dead" end

    local vehicleValid,vehicleState = playerVehicleState(source,options and options.AllowVehicle == true)
    if not vehicleValid then return false,vehicleState end
    return true,nil,vehicleState
end

local function validateSessionPlayerState(source,Passport,session)
    local valid,reason,vehicleState = validPlayerState(source,Passport,{
        AllowVehicle = session and session.VehicleSale == true
    })
    if not valid then return false,reason end

    if session and session.VehicleSale then
        if not vehicleState or not vehicleState.InVehicle then return false,"vehicle_left" end
        if session.VehicleEntity and session.VehicleEntity ~= vehicleState.Vehicle then
            return false,"vehicle_changed"
        end
    end

    return true,nil,vehicleState
end

local function setStreetMode(source,Passport,enabled)
    if enabled then
        StreetModes[Passport] = source
    else
        StreetModes[Passport] = nil
    end

    if source and source > 0 and GetPlayerName(source) then
        Player(source).state:set("SaoJudasStreetSalesMode",enabled == true,true)
    end
end

local function entityValue(native,...)
    local ok,value = pcall(native,...)
    if not ok then return nil end
    return value
end

local function validateNpc(source,networkId,maximumDistance)
    networkId = tonumber(networkId)
    if not networkId or networkId <= 0 then return false,"npc_not_networked" end

    local entity = NetworkGetEntityFromNetworkId(networkId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false,"npc_not_found" end
    if GetEntityType(entity) ~= 1 then return false,"npc_not_ped" end

    local isPlayer = entityValue(IsPedAPlayer,entity)
    if isPlayer == true then return false,"npc_is_player" end

    local pedType = entityValue(GetPedType,entity)
    if pedType and not SaoJudasStreetSales.AllowedPedTypes[pedType] then return false,"npc_type_blocked" end
    if GetEntityHealth(entity) <= 100 then return false,"npc_dead" end

    local vehicle = entityValue(GetVehiclePedIsIn,entity,false)
    if vehicle and vehicle ~= 0 then return false,"npc_in_vehicle" end

    local playerPed = GetPlayerPed(source)
    local playerCoords = GetEntityCoords(playerPed)
    local npcCoords = GetEntityCoords(entity)
    if distance(playerCoords,npcCoords) > (maximumDistance or SaoJudasStreetSales.Interaction.MaximumDistance) then
        return false,"npc_too_far"
    end

    local playerBucket = GetPlayerRoutingBucket(source)
    local entityBucket = entityValue(GetEntityRoutingBucket,entity) or playerBucket
    if entityBucket ~= playerBucket then return false,"routing_bucket_mismatch" end

    local model = GetEntityModel(entity)
    local npcKey = ("net:%s:%s:%s"):format(playerBucket,networkId,model)
    return true,{
        Entity = entity,
        NetworkId = networkId,
        Model = model,
        Coords = npcCoords,
        Bucket = playerBucket,
        Key = npcKey,
        PedType = pedType
    }
end

local function currentZone(coords)
    for _,area in ipairs(SaoJudasStreetSales.Zones.Areas) do
        local radius = finiteNumber(area.Radius)
        if radius and area.Coords and distance(coords,area.Coords) <= radius then
            return area.Name or "Cidade",finiteNumber(area.Multiplier) or 1.0
        end
    end

    local default = SaoJudasStreetSales.Zones.Default
    return default.Name,default.Multiplier
end

local function randomWeighted(values)
    local total = 0
    for _,entry in ipairs(values) do total = total + math.max(0,entry.Weight or 0) end
    if total <= 0 then return values[1] end

    local roll = math.random(1,total)
    local cursor = 0
    for _,entry in ipairs(values) do
        cursor = cursor + math.max(0,entry.Weight or 0)
        if roll <= cursor then return entry end
    end
    return values[#values]
end

local function chooseDemand()
    return randomWeighted({
        { Name = "Low", Weight = SaoJudasStreetSales.Demand.Low.Weight, Settings = SaoJudasStreetSales.Demand.Low },
        { Name = "Normal", Weight = SaoJudasStreetSales.Demand.Normal.Weight, Settings = SaoJudasStreetSales.Demand.Normal },
        { Name = "High", Weight = SaoJudasStreetSales.Demand.High.Weight, Settings = SaoJudasStreetSales.Demand.High }
    })
end

local function reputationLevel(sales)
    local selected = SaoJudasStreetSales.Reputation.Levels[1]
    for _,level in ipairs(SaoJudasStreetSales.Reputation.Levels) do
        if sales >= level.MinimumSales then selected = level end
    end
    return selected
end

local function getReputation(Passport)
    prepareDatabase()
    local row = exports.oxmysql:single_async([[SELECT Sales,Units,GrossAmount,Refusals,Reports,LastSale,Level
        FROM sao_judas_distribution_reputation WHERE Passport = ?]],{ Passport }) or {}
    local level = reputationLevel(tonumber(row.Sales) or 0)
    return {
        Sales = tonumber(row.Sales) or 0,
        Units = tonumber(row.Units) or 0,
        GrossAmount = tonumber(row.GrossAmount) or 0,
        Refusals = tonumber(row.Refusals) or 0,
        Reports = tonumber(row.Reports) or 0,
        LastSale = tonumber(row.LastSale),
        Level = level.Level,
        LevelName = level.Name,
        PriceMultiplier = math.min(level.PriceMultiplier,SaoJudasStreetSales.Reputation.MaximumPriceMultiplier),
        AcceptBonus = level.AcceptBonus
    }
end

local function recordReputation(session,outcome)
    local claimed = exports.oxmysql:update_async([[UPDATE sao_judas_street_sales
        SET ReputationApplied = 1 WHERE SaleId = ? AND ReputationApplied = 0]],{ session.SaleId })
    if tonumber(claimed) ~= 1 then return false,"already_applied" end

    exports.oxmysql:insert_async([[INSERT IGNORE INTO sao_judas_distribution_reputation
        (Passport,UpdatedAt) VALUES (?,?)]],{ session.Passport,os.time() })

    if outcome == "completed" then
        exports.oxmysql:update_async([[UPDATE sao_judas_distribution_reputation SET
            Sales = Sales + 1,Units = Units + ?,GrossAmount = GrossAmount + ?,LastSale = ?,UpdatedAt = ?
            WHERE Passport = ?]],{ session.Quantity,session.GrossAmount,os.time(),os.time(),session.Passport })
    elseif outcome == "reported" then
        exports.oxmysql:update_async([[UPDATE sao_judas_distribution_reputation SET
            Reports = Reports + 1,UpdatedAt = ? WHERE Passport = ?]],{ os.time(),session.Passport })
    else
        exports.oxmysql:update_async([[UPDATE sao_judas_distribution_reputation SET
            Refusals = Refusals + 1,UpdatedAt = ? WHERE Passport = ?]],{ os.time(),session.Passport })
    end

    local row = exports.oxmysql:single_async("SELECT Sales FROM sao_judas_distribution_reputation WHERE Passport = ?",{ session.Passport }) or {}
    local level = reputationLevel(tonumber(row.Sales) or 0)
    exports.oxmysql:update_async("UPDATE sao_judas_distribution_reputation SET Level = ?,UpdatedAt = ? WHERE Passport = ?",{
        level.Level,os.time(),session.Passport
    })
    return true,level
end

local function chooseReaction(reputation)
    local reactions = SaoJudasStreetSales.Reactions
    local bonus = math.max(0,tonumber(reputation and reputation.AcceptBonus) or 0)
    return randomWeighted({
        { Name = "accept", Weight = reactions.Accept + bonus },
        { Name = "refuse", Weight = math.max(1,reactions.Refuse - bonus) },
        { Name = "report", Weight = reactions.Report },
        { Name = "walk_away", Weight = reactions.WalkAway }
    }).Name
end

local function newSaleId(Passport)
    SaleCounter = SaleCounter + 1
    return ("saojudas:sale:%s:%s:%06d:%06d"):format(os.time(),Passport,SaleCounter,math.random(0,999999))
end

local function updateSale(session,status,reason)
    session.Status = status
    session.Reason = reason
    exports.oxmysql:execute_async([[UPDATE sao_judas_street_sales SET
        Item = ?,Quantity = ?,UnitPrice = ?,GrossAmount = ?,WorkerAmount = ?,FactionAmount = ?,
        Region = ?,Demand = ?,ReputationLevel = ?,Reaction = ?,Status = ?,Reason = ?,UpdatedAt = ?,CompletedAt = ?
        WHERE SaleId = ?]],{
        session.Item,session.Quantity or 0,session.UnitPrice or 0,session.GrossAmount or 0,
        session.WorkerAmount or 0,session.FactionAmount or 0,session.Region or "Cidade",
        session.Demand or "Normal",session.ReputationLevel or 1,session.Reaction,status,reason,os.time(),
        status == "completed" and os.time() or nil,session.SaleId
    })
end

local function unlockSession(session,status,reason)
    if not session then return end
    updateSale(session,status,reason)

    SessionsByPassport[session.Passport] = nil
    SessionsById[session.SaleId] = nil
    if PedLocks[session.NpcKey] == session.SaleId then PedLocks[session.NpcKey] = nil end

    local pedWasUsed = status == "completed" or status == "refused" or status == "reported" or status == "walk_away"
    if pedWasUsed then
        PedCooldowns[session.NpcKey] = os.time() + SaoJudasStreetSales.Cooldowns.PedSeconds
    end
    PlayerCooldowns[session.Passport] = os.time() + (
        status == "cancelled" and SaoJudasStreetSales.Cooldowns.FailedAttemptSeconds
        or SaoJudasStreetSales.Cooldowns.PlayerSeconds
    )

    if session.Entity and DoesEntityExist(session.Entity) then
        Entity(session.Entity).state:set("SaoJudasStreetSale",nil,true)
        Entity(session.Entity).state:set("SaoJudasStreetSaleUsedUntil",PedCooldowns[session.NpcKey],true)
    end
end

local function attemptsAllowed(Passport)
    local now = os.time()
    local history = Attempts[Passport] or {}
    local kept = {}
    for _,timestamp in ipairs(history) do
        if timestamp > now - 60 then kept[#kept + 1] = timestamp end
    end
    if #kept >= SaoJudasStreetSales.Cooldowns.AttemptsPerMinute then
        Attempts[Passport] = kept
        return false
    end

    kept[#kept + 1] = now
    Attempts[Passport] = kept
    return true
end

local function databasePedCooldown(npcKey)
    local threshold = os.time() - SaoJudasStreetSales.Cooldowns.PedSeconds
    local found = exports.oxmysql:scalar_async([[SELECT 1 FROM sao_judas_street_sales
        WHERE NpcKey = ? AND CreatedAt >= ? AND Status IN
        ('completed','refused','reported','walk_away') LIMIT 1]],{ npcKey,threshold })
    return found ~= nil
end

local function dispatchSale(session)
    local settings = SaoJudasStreetSales.Dispatch
    if not settings.Enabled or session.DispatchSent then return false end

    local chance = session.Reaction == "report" and settings.ReportReactionChance or settings.GeneralWitnessChance
    if math.random(100) > chance then return false end

    local officers = vRP.NumPermission("Policia") or {}
    if #officers < settings.MinimumPolice then return false end

    local grid = settings.ApproximationGrid
    local coords = session.NpcCoords
    local approximate = vector3(
        math.floor((coords.x / grid) + 0.5) * grid,
        math.floor((coords.y / grid) + 0.5) * grid,
        coords.z
    )

    session.DispatchSent = true
    exports.vrp:CallPolice({
        Source = session.Source,
        Passport = session.Passport,
        Permission = "Policia",
        Name = "Atividade suspeita",
        Coords = approximate,
        Code = 20,
        Color = 16
    })
    return true
end

function API.Eligibility()
    local source = source
    local Passport = vRP.Passport(source)
    local valid = validPlayerState(source,Passport)
    return valid and #availableDrugs(Passport) > 0 and not SessionsByPassport[Passport]
end

local function shouldDisableStreetMode(reason)
    -- O modo deve permanecer ligado durante estados temporários. Entrar/sair do
    -- veículo, movimentar o carro, estar em cooldown, abrir a interface ou estar
    -- com uma venda em andamento apenas pausam a procura por compradores.
    -- Ele só é desligado automaticamente quando o jogador perde o direito real
    -- de usar o sistema ou entra em uma instância definitivamente bloqueada.
    return reason == "not_authorized"
        or reason == "disabled"
        or reason == "mode_disabled"
        or reason == "routing_bucket_blocked"
end

local function eligibilityDetails(source,Passport,allowVehicle)
    local access = distributionAccess(Passport,true)
    local products = Passport and availableDrugs(Passport) or {}
    local modeActive = Passport and StreetModes[Passport] == source or false
    local valid,reason = validPlayerState(source,Passport,{ AllowVehicle = allowVehicle == true or modeActive })

    -- Uma sessão ativa tem prioridade sobre estados temporários como Buttons ou
    -- player_busy. Antes, o refresh de elegibilidade enxergava player_busy no
    -- meio da barra e desligava o /venderdrogas sem o jogador pedir.
    if Passport and SessionsByPassport[Passport] then
        valid,reason = false,"sale_in_progress"
    elseif valid and #products == 0 then
        valid,reason = false,"no_drugs"
    end

    if modeActive and not valid and shouldDisableStreetMode(reason) then
        setStreetMode(source,Passport,false)
        modeActive = false
        log(("mode_auto_disabled passport=%s source=%s reason=%s"):format(
            tostring(Passport),tostring(source),tostring(reason)
        ))
    end

    return {
        Eligible = valid == true,
        Reason = valid == true and "ok" or reason,
        Passport = Passport,
        IsMember = access.IsMember,
        IsLeader = access.IsLeader,
        HasDistributionRole = access.HasDistributionRole,
        Authorized = access.Authorized,
        HasAllowedDrug = #products > 0,
        AvailableDrugs = products,
        Safezone = source > 0 and Player(source).state.Safezone == true or false,
        ResourceStarted = true,
        ModeEnabled = modeActive
    }
end

function API.EligibilityDetails()
    local source = source
    return eligibilityDetails(source,vRP.Passport(source))
end

function API.ToggleMode()
    local source = source
    local Passport = vRP.Passport(source)
    if not Passport then return { Ok = false,Reason = "not_authorized",Enabled = false } end
    if not SaoJudasStreetSales.StreetMode.Enabled then return { Ok = false,Reason = "mode_disabled",Enabled = false } end

    if StreetModes[Passport] == source then
        if SessionsByPassport[Passport] then
            return { Ok = false,Reason = "sale_in_progress",Enabled = true }
        end
        setStreetMode(source,Passport,false)
        log(("mode_disabled passport=%s source=%s"):format(Passport,source))
        return { Ok = true,Enabled = false }
    end

    local details = eligibilityDetails(source,Passport,true)
    if not details.Eligible then return { Ok = false,Reason = details.Reason,Enabled = false } end

    setStreetMode(source,Passport,true)
    log(("mode_enabled passport=%s source=%s"):format(Passport,source))
    return { Ok = true,Enabled = true,Products = details.AvailableDrugs }
end

function API.TargetDebug(localSnapshot,networkId)
    local source = source
    local Passport = vRP.Passport(source)
    if Passport ~= SaoJudasStreetSales.Debug.OwnerPassport then return nil end

    local snapshot = eligibilityDetails(source,Passport)
    snapshot.Local = type(localSnapshot) == "table" and localSnapshot or {}
    snapshot.NetworkId = tonumber(networkId) or 0
    snapshot.ServerNpcValid = false
    snapshot.ServerNpcReason = "npc_not_networked"

    if snapshot.NetworkId > 0 then
        local valid,npc = validateNpc(source,snapshot.NetworkId)
        snapshot.ServerNpcValid = valid == true
        snapshot.ServerNpcReason = valid == true and "ok" or npc
    end

    log("target_debug "..json.encode(snapshot))
    return snapshot
end

function API.StartOffer(networkId,automatic)
    prepareDatabase()

    local source = source
    local Passport = vRP.Passport(source)
    local automaticMode = automatic == true and Passport and StreetModes[Passport] == source
    local valid,reason,vehicleState = validPlayerState(source,Passport,{ AllowVehicle = automaticMode })
    if not valid then return { Ok = false, Reason = reason } end
    if SessionsByPassport[Passport] then return { Ok = false, Reason = "sale_in_progress" } end
    if (PlayerCooldowns[Passport] or 0) > os.time() then return { Ok = false, Reason = "player_cooldown" } end
    if not attemptsAllowed(Passport) then return { Ok = false, Reason = "attempt_limit" } end

    local vehicleSale = automaticMode and vehicleState and vehicleState.InVehicle == true

    -- A reserva automática precisa aceitar o mesmo raio usado pelo client para
    -- localizar o comprador. Antes, dentro do carro, o servidor limitava o início
    -- a 4 metros; por isso só funcionava quando o comando era ativado colado em um
    -- NPC. A distância curta continua sendo exigida na seleção e na conclusão.
    local maximumDistance = automaticMode
        and (SaoJudasStreetSales.StreetMode.SearchRadius + 1.0)
        or SaoJudasStreetSales.Interaction.MaximumDistance
    local npcValid,npc = validateNpc(source,networkId,maximumDistance)
    if not npcValid then return { Ok = false, Reason = npc } end
    if PedLocks[npc.Key] then return { Ok = false, Reason = "npc_busy" } end
    if (PedCooldowns[npc.Key] or 0) > os.time() or databasePedCooldown(npc.Key) then
        return { Ok = false, Reason = "npc_cooldown" }
    end

    local products = availableDrugs(Passport)
    if #products == 0 then return { Ok = false, Reason = "no_drugs" } end

    local region,zoneMultiplier = currentZone(npc.Coords)
    local demand = chooseDemand()
    local saleId = newSaleId(Passport)
    local session = {
        SaleId = saleId,
        Source = source,
        Passport = Passport,
        Entity = npc.Entity,
        NetworkId = npc.NetworkId,
        NpcKey = npc.Key,
        NpcModel = npc.Model,
        NpcCoords = npc.Coords,
        Bucket = npc.Bucket,
        Region = region,
        ZoneMultiplier = zoneMultiplier,
        Demand = demand.Name,
        DemandLabel = demand.Settings.Label,
        DemandMultiplier = demand.Settings.Multiplier,
        Status = "created",
        CreatedAt = os.time(),
        ExpiresAt = os.time() + SaoJudasStreetSales.Interaction.SessionTtlSeconds,
        AutomaticMode = automaticMode,
        VehicleSale = vehicleSale,
        VehicleEntity = vehicleSale and vehicleState.Vehicle or nil
    }

    local inserted = exports.oxmysql:insert_async([[INSERT INTO sao_judas_street_sales
        (SaleId,Passport,NpcKey,NpcNetwork,NpcModel,RoutingBucket,Region,Demand,Status,CreatedAt,UpdatedAt)
        VALUES (?,?,?,?,?,?,?,?,?,?,?)]],{
        saleId,Passport,npc.Key,npc.NetworkId,npc.Model,npc.Bucket,region,demand.Name,"created",os.time(),os.time()
    })
    if not inserted then return { Ok = false, Reason = "database_error" } end

    SessionsByPassport[Passport] = session
    SessionsById[saleId] = session
    PedLocks[npc.Key] = saleId
    Entity(npc.Entity).state:set("SaoJudasStreetSale",saleId,true)

    log(("created sale=%s passport=%s npc=%s region=%s products=%s"):format(saleId,Passport,npc.Key,region,#products))
    return {
        Ok = true,
        SaleId = saleId,
        Products = products,
        Demand = demand.Settings.Label,
        Region = region
    }
end

function API.SelectProduct(saleId,item)
    local source = source
    local Passport = vRP.Passport(source)
    local session = SessionsById[tostring(saleId or "")]
    if not session or session.Passport ~= Passport or session.Source ~= source then
        return { Ok = false, Reason = "invalid_session" }
    end
    if session.Status ~= "created" then return { Ok = false, Reason = "invalid_status" } end
    if os.time() > session.ExpiresAt then
        unlockSession(session,"cancelled","session_expired")
        return { Ok = false, Reason = "session_expired" }
    end

    local valid,reason = validateSessionPlayerState(source,Passport,session)
    if not valid then
        unlockSession(session,"cancelled",reason)
        return { Ok = false, Reason = reason }
    end

    local settings = SaoJudasStreetSales.Drugs[tostring(item or "")]
    if not settings or not settings.Enabled then
        unlockSession(session,"cancelled","invalid_item")
        return { Ok = false, Reason = "invalid_item" }
    end

    local vehicleSettings = SaoJudasStreetSales.StreetMode.VehicleSales or {}
    local interactionDistance = session.VehicleSale and (tonumber(vehicleSettings.ServerMaximumDistance) or 4.0)
        or SaoJudasStreetSales.Interaction.MaximumDistance
    local npcValid,npc = validateNpc(source,session.NetworkId,interactionDistance)
    if not npcValid or npc.Key ~= session.NpcKey then
        unlockSession(session,"cancelled",npcValid and "npc_changed" or npc)
        return { Ok = false, Reason = npcValid and "npc_changed" or npc }
    end

    local amount = inventoryAmount(Passport,item)
    if amount < settings.MinimumQuantity then
        unlockSession(session,"cancelled","item_unavailable")
        return { Ok = false, Reason = "item_unavailable" }
    end

    local reputation = getReputation(Passport)
    local maximum = math.min(amount,settings.MaximumQuantity,SaoJudasStreetSales.Quantity.Maximum)
    local minimum = math.min(maximum,math.max(settings.MinimumQuantity,SaoJudasStreetSales.Quantity.Minimum))
    local quantity = math.random(minimum,maximum)
    local basePrice = math.random(settings.MinimumPrice,settings.MaximumPrice)
    local unitPrice = math.floor((basePrice * session.ZoneMultiplier * session.DemandMultiplier * reputation.PriceMultiplier) + 0.5)
    unitPrice = math.max(settings.MinimumPrice,math.min(unitPrice,math.floor(settings.MaximumPrice * 1.20)))
    local gross = strictInteger(unitPrice * quantity)
    if not gross then
        unlockSession(session,"failed","invalid_price")
        return { Ok = false, Reason = "invalid_price" }
    end

    session.Item = item
    session.Quantity = quantity
    session.UnitPrice = unitPrice
    session.GrossAmount = gross
    local workerAmount,factionAmount = revenueSplit(gross)
    if not workerAmount then
        unlockSession(session,"failed",factionAmount)
        return { Ok = false, Reason = factionAmount }
    end
    session.WorkerAmount = workerAmount
    session.FactionAmount = factionAmount
    session.ReputationLevel = reputation.Level
    session.ReputationName = reputation.LevelName

    local automaticBuyer = session.AutomaticMode
        and SaoJudasStreetSales.StreetMode.AutomaticBuyersAlwaysAccept ~= false

    -- No modo /venderdrogas, o NPC é apresentado ao jogador como um comprador
    -- interessado e se desloca voluntariamente até ele. Portanto, esse NPC não
    -- deve chegar para depois recusar ou ir embora. O target manual continua
    -- usando as reações normais de aceitar, recusar, denunciar ou se afastar.
    session.Reaction = automaticBuyer and "accept" or chooseReaction(reputation)
    session.Status = session.Reaction == "accept" and "accepted" or session.Reaction
    updateSale(session,session.Status,nil)

    if session.Reaction ~= "accept" then
        if session.Reaction == "report" then dispatchSale(session) end
        local terminal = session.Reaction == "refuse" and "refused"
            or session.Reaction == "report" and "reported"
            or "walk_away"
        recordReputation(session,terminal)
        unlockSession(session,terminal,nil)
        log(("reaction sale=%s passport=%s item=%s reaction=%s automatic=%s"):format(
            session.SaleId,Passport,item,session.Reaction,tostring(session.AutomaticMode == true)
        ))
        return { Ok = true, Reaction = session.Reaction }
    end

    dispatchSale(session)
    return {
        Ok = true,
        Reaction = "accept",
        DurationMs = SaoJudasStreetSales.Interaction.AnimationDurationMs,
        Quantity = quantity,
        Product = exports.vrp:ItemName(item) or item
    }
end

function API.Complete(saleId)
    local source = source
    local Passport = vRP.Passport(source)
    local session = SessionsById[tostring(saleId or "")]
    if not session or session.Passport ~= Passport or session.Source ~= source then
        return { Ok = false, Reason = "invalid_session" }
    end
    if session.Status ~= "accepted" then return { Ok = false, Reason = "invalid_status" } end
    if os.time() > session.ExpiresAt then
        unlockSession(session,"cancelled","session_expired")
        return { Ok = false, Reason = "session_expired" }
    end

    local valid,reason = validateSessionPlayerState(source,Passport,session)
    if not valid then
        unlockSession(session,"cancelled",reason)
        return { Ok = false, Reason = reason }
    end

    local vehicleSettings = SaoJudasStreetSales.StreetMode.VehicleSales or {}
    local interactionDistance = session.VehicleSale and (tonumber(vehicleSettings.ServerMaximumDistance) or 4.0)
        or SaoJudasStreetSales.Interaction.MaximumDistance
    local completionDistance = session.VehicleSale and (tonumber(vehicleSettings.CompletionDistance) or 4.0)
        or SaoJudasStreetSales.Interaction.CompletionDistance
    local npcValid,npc = validateNpc(source,session.NetworkId,interactionDistance)
    if not npcValid or npc.Key ~= session.NpcKey then
        unlockSession(session,"cancelled",npcValid and "npc_changed" or npc)
        return { Ok = false, Reason = npcValid and "npc_changed" or npc }
    end
    if distance(GetEntityCoords(GetPlayerPed(source)),npc.Coords) > completionDistance then
        unlockSession(session,"cancelled","npc_too_far")
        return { Ok = false, Reason = "npc_too_far" }
    end

    local consult = vRP.ConsultItem(Passport,session.Item,session.Quantity)
    if not consult then
        unlockSession(session,"cancelled","item_unavailable")
        return { Ok = false, Reason = "item_unavailable" }
    end
    if vRP.MaxItens(Passport,SaoJudasStreetSales.Currency,session.WorkerAmount)
        or not vRP.CheckWeight(Passport,SaoJudasStreetSales.Currency,session.WorkerAmount) then
        unlockSession(session,"cancelled","inventory_full")
        return { Ok = false, Reason = "inventory_full" }
    end

    session.Status = "processing"
    updateSale(session,"processing",nil)
    if not vRP.TakeItem(Passport,consult.Item,session.Quantity,true,consult.Slot) then
        unlockSession(session,"failed","take_item_failed")
        return { Ok = false, Reason = "take_item_failed" }
    end

    local before = inventoryAmount(Passport,SaoJudasStreetSales.Currency)
    vRP.GenerateItem(Passport,SaoJudasStreetSales.Currency,session.WorkerAmount,true)
    local after = inventoryAmount(Passport,SaoJudasStreetSales.Currency)
    if after < before + session.WorkerAmount then
        vRP.GenerateItem(Passport,session.Item,session.Quantity,true)
        unlockSession(session,"refunded","worker_payment_failed")
        log(("payment_failed sale=%s passport=%s expected=%s before=%s after=%s"):format(
            session.SaleId,Passport,session.WorkerAmount,before,after
        ))
        return { Ok = false, Reason = "payment_failed" }
    end

    local credited,creditReason = exports.sao_judas_operations:CreditDirty(
        Passport,
        session.FactionAmount,
        "street-sale:"..session.SaleId,
        "street_sale",
        {
            TransactionType = "automatic_revenue",
            SaleId = session.SaleId,
            Product = session.Item,
            Quantity = session.Quantity,
            GrossAmount = session.GrossAmount,
            WorkerAmount = session.WorkerAmount,
            FactionAmount = session.FactionAmount,
            Region = session.Region,
            ReputationLevel = session.ReputationLevel
        }
    )
    if not credited then
        local workerRollback = vRP.TakeItem(Passport,SaoJudasStreetSales.Currency,session.WorkerAmount,false)
        if workerRollback then
            vRP.GenerateItem(Passport,session.Item,session.Quantity,true)
            unlockSession(session,"refunded","vault_credit_failed:"..tostring(creditReason))
            log(("vault_credit_rollback sale=%s passport=%s reason=%s"):format(
                session.SaleId,Passport,tostring(creditReason)
            ))
            return { Ok = false, Reason = "vault_credit_failed" }
        end

        unlockSession(session,"failed","partial_payment_requires_admin_review")
        log(("CRITICAL partial_payment sale=%s passport=%s worker=%s faction=%s reason=%s"):format(
            session.SaleId,Passport,session.WorkerAmount,session.FactionAmount,tostring(creditReason)
        ))
        return { Ok = false, Reason = "partial_payment_requires_admin_review" }
    end

    recordReputation(session,"completed")
    unlockSession(session,"completed",nil)
    TriggerClientEvent("player:Residual",source,"Resíduo de Orgânicos")
    vRP.UpgradeStress(Passport,1)
    log(("completed sale=%s passport=%s item=%s quantity=%s gross=%s"):format(
        session.SaleId,Passport,session.Item,session.Quantity,session.GrossAmount
    ))

    return {
        Ok = true,
        GrossAmount = session.GrossAmount,
        WorkerAmount = session.WorkerAmount,
        FactionAmount = session.FactionAmount,
        Currency = SaoJudasStreetSales.Currency
    }
end

function API.Cancel(saleId,reason)
    local source = source
    local Passport = vRP.Passport(source)
    local session = SessionsById[tostring(saleId or "")]
    if not session or session.Passport ~= Passport or session.Source ~= source then return false end
    unlockSession(session,"cancelled",tostring(reason or "client_cancelled"):sub(1,96))
    return true
end

local function debugSnapshot(source,Passport)
    local session = Passport and SessionsByPassport[Passport] or nil
    local ped = source > 0 and GetPlayerPed(source) or 0
    local coords = ped ~= 0 and GetEntityCoords(ped) or vector3(0.0,0.0,0.0)
    local region,zoneMultiplier = currentZone(coords)
    local valid,reason = false,"console"
    if source > 0 then
        valid,reason = validPlayerState(source,Passport)
    end
    local reputation = Passport and getReputation(Passport) or nil
    local dirty,clean = 0,0
    local vaultOk = pcall(function()
        dirty,clean = exports.sao_judas_operations:Balances()
    end)

    local database = {
        Sales = exports.oxmysql:scalar_async("SELECT COUNT(*) FROM sao_judas_street_sales") or 0,
        Completed = exports.oxmysql:scalar_async("SELECT COUNT(*) FROM sao_judas_street_sales WHERE Status = 'completed'") or 0,
        Active = exports.oxmysql:scalar_async([[SELECT COUNT(*) FROM sao_judas_street_sales
            WHERE Status IN ('created','negotiating','accepted','processing')]]) or 0
    }

    local npcDistance = nil
    if session and session.Entity and DoesEntityExist(session.Entity) and ped ~= 0 then
        npcDistance = distance(coords,GetEntityCoords(session.Entity))
    end

    return {
        Source = source,
        Passport = Passport,
        Authorized = source > 0 and canUseDistribution(Passport,true) or false,
        Eligible = valid == true and Passport and #availableDrugs(Passport) > 0 or false,
        EligibilityReason = valid == true and "ok" or reason,
        Drugs = Passport and availableDrugs(Passport) or {},
        SaleId = session and session.SaleId or nil,
        Status = session and session.Status or nil,
        NpcNetwork = session and session.NetworkId or nil,
        NpcKey = session and session.NpcKey or nil,
        NpcDistance = npcDistance,
        RoutingBucket = source > 0 and GetPlayerRoutingBucket(source) or 0,
        Region = region,
        ZoneMultiplier = zoneMultiplier,
        Demand = session and session.Demand or nil,
        Reaction = session and session.Reaction or nil,
        PlayerCooldown = Passport and math.max(0,(PlayerCooldowns[Passport] or 0) - os.time()) or 0,
        Reputation = reputation,
        Payment = session and {
            Gross = session.GrossAmount,
            Worker = session.WorkerAmount,
            Faction = session.FactionAmount
        } or nil,
        Vault = vaultOk and { Dirty = dirty,CleanPending = clean } or { Error = true },
        Database = database,
        Config = {
            RevenueTotal = SaoJudasStreetSales.Revenue.WorkerPercentage + SaoJudasStreetSales.Revenue.FactionPercentage,
            DispatchEnabled = SaoJudasStreetSales.Dispatch.Enabled,
            DrugCount = (function()
                local count = 0
                for _,settings in pairs(SaoJudasStreetSales.Drugs) do
                    if settings.Enabled then count = count + 1 end
                end
                return count
            end)()
        }
    }
end

RegisterCommand("saojudas_sales_debug",function(source)
    if not SaoJudasStreetSales.Debug.Enabled then return end

    local Passport = source > 0 and vRP.Passport(source) or nil
    if source > 0 and Passport ~= SaoJudasStreetSales.Debug.OwnerPassport then return end

    prepareDatabase()
    local snapshot = debugSnapshot(source,Passport)
    log("debug "..json.encode(snapshot))
    if source > 0 then
        TriggerClientEvent("sao_judas_street_sales:DebugPrint",source,snapshot)
        notify(source,"Diagnóstico enviado ao F8.","azul")
    end
end,false)

CreateThread(function()
    Wait(1000)
    local ok,err = pcall(prepareDatabase)
    if not ok then log("database_prepare_failed reason="..tostring(err)) end

    while true do
        Wait(5000)
        local now = os.time()
        local expired = {}
        for _,session in pairs(SessionsById) do
            if now > session.ExpiresAt or not GetPlayerName(session.Source) then
                expired[#expired + 1] = session
            end
        end
        for _,session in ipairs(expired) do unlockSession(session,"cancelled","session_timeout") end

        for key,expiresAt in pairs(PedCooldowns) do
            if expiresAt <= now then PedCooldowns[key] = nil end
        end
        for passport,expiresAt in pairs(PlayerCooldowns) do
            if expiresAt <= now then PlayerCooldowns[passport] = nil end
        end
    end
end)

AddEventHandler("playerDropped",function()
    local Passport = vRP.Passport(source)
    local session = Passport and SessionsByPassport[Passport]
    if not session then
        for _,candidate in pairs(SessionsById) do
            if candidate.Source == source then
                session = candidate
                Passport = candidate.Passport
                break
            end
        end
    end
    if session then unlockSession(session,"cancelled","player_dropped") end
    if Passport then
        Attempts[Passport] = nil
        StreetModes[Passport] = nil
    end
end)

AddEventHandler("onResourceStop",function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _,session in pairs(SessionsById) do
        if session.Entity and DoesEntityExist(session.Entity) then
            Entity(session.Entity).state:set("SaoJudasStreetSale",nil,true)
        end
    end
    for Passport,source in pairs(StreetModes) do
        setStreetMode(source,Passport,false)
    end
end)
