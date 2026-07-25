local Tunnel = module("vrp","lib/Tunnel")
local vSERVER = Tunnel.getInterface("sao_judas_street_sales")

local ActiveSale = nil
local ActiveNpc = nil
local ActiveCandidate = nil
local ActiveStart = nil
local ProductMenuOpen = false
local StreetModeEnabled = false
local EligibilityCache = {
    Eligible = false,
    Reason = "loading",
    AvailableDrugs = {}
}
local LastTargetDebug = { Key = nil, At = 0 }

local Messages = {
    disabled = "As vendas estão indisponíveis no momento.",
    not_authorized = "Você não está autorizado a realizar vendas por São Judas.",
    safezone = "Não é possível oferecer produtos nesta área protegida.",
    player_busy = "Você não pode iniciar uma venda agora.",
    player_dead = "Você não pode iniciar uma venda agora.",
    player_in_vehicle = "Saia do veículo para oferecer manualmente. No modo /venderdrogas, permaneça parado no banco do motorista.",
    vehicle_driver_required = "Assuma o banco do motorista para vender pelo veículo.",
    vehicle_moving = "Pare completamente o veículo para negociar.",
    vehicle_left = "A venda foi cancelada porque você saiu do veículo.",
    vehicle_changed = "A venda foi cancelada porque você trocou de veículo.",
    sale_in_progress = "Você já possui uma negociação em andamento.",
    player_cooldown = "Aguarde um pouco antes de procurar outro comprador.",
    attempt_limit = "Você chamou atenção demais. Espere antes de tentar novamente.",
    npc_not_networked = "Este pedestre não está disponível para negociação.",
    npc_not_found = "O comprador não está mais disponível.",
    npc_not_ped = "Este alvo não pode comprar produtos.",
    npc_is_player = "Use apenas compradores civis.",
    npc_type_blocked = "Este pedestre não é um comprador elegível.",
    npc_dead = "Este pedestre não pode negociar.",
    npc_in_vehicle = "Este pedestre não pode negociar dentro de um veículo.",
    npc_too_far = "Aproxime-se do comprador.",
    npc_changed = "O comprador não está mais disponível.",
    npc_busy = "Este comprador já está negociando.",
    npc_cooldown = "Este pedestre não quer conversar novamente.",
    routing_bucket_mismatch = "O comprador não está na mesma instância.",
    routing_bucket_blocked = "O modo de venda não está disponível nesta instância.",
    mode_disabled = "O modo de venda de rua está desativado.",
    no_drugs = "Você não possui produtos disponíveis para venda.",
    database_error = "A negociação não pôde ser registrada.",
    invalid_session = "Esta negociação não é mais válida.",
    invalid_status = "Esta negociação já foi encerrada.",
    session_expired = "A negociação demorou demais e foi cancelada.",
    invalid_item = "Este produto não está autorizado para venda.",
    item_unavailable = "Você não possui mais a quantidade necessária.",
    invalid_price = "O preço da venda não pôde ser calculado.",
    inventory_full = "Seu inventário não comporta o pagamento.",
    take_item_failed = "O produto não pôde ser removido do inventário.",
    payment_failed = "A venda foi cancelada e o produto devolvido.",
    worker_payment_failed = "A venda foi cancelada e o produto devolvido.",
    vault_credit_failed = "A venda foi cancelada e o produto devolvido por uma falha no cofre.",
    partial_payment_requires_admin_review = "A operação foi bloqueada para revisão administrativa.",
    invalid_revenue_configuration = "A divisão financeira está configurada incorretamente.",
    invalid_revenue_split = "A divisão financeira não pôde ser calculada."
}

local function notify(message,color)
    TriggerEvent("Notify","São Judas",message,color or "amarelo",5000)
end

local function errorMessage(reason)
    return Messages[tostring(reason or "")] or "A negociação não pôde ser concluída."
end

local function vehicleSaleContext()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped,false)
    local settings = SaoJudasStreetSales.StreetMode.VehicleSales
    if not vehicle or vehicle == 0 or not settings or settings.Enabled ~= true then
        return { Active = false,Ped = ped,Vehicle = 0,Speed = 0.0 }
    end

    local driver = GetPedInVehicleSeat(vehicle,-1) == ped
    local speed = GetEntitySpeed(vehicle)
    return {
        Active = driver and speed <= (tonumber(settings.MaximumSpeed) or 0.35),
        InVehicle = true,
        Driver = driver,
        Ped = ped,
        Vehicle = vehicle,
        Speed = speed
    }
end

local function vehicleMeetingPoint(vehicle)
    local settings = SaoJudasStreetSales.StreetMode.VehicleSales or {}
    local minimum,maximum = GetModelDimensions(GetEntityModel(vehicle))
    local leftEdge = minimum and minimum.x or -1.0
    local forward = tonumber(settings.WindowForwardOffset) or 0.25
    local side = leftEdge - (tonumber(settings.WindowSideClearance) or 0.45)
    local point = GetOffsetFromEntityInWorldCoords(vehicle,side,forward,0.0)
    local found,groundZ = GetGroundZFor_3dCoord(point.x,point.y,point.z + 2.0,false)
    if found then point = vector3(point.x,point.y,groundZ) end
    return point
end

local function requestAnim(dictionary)
    RequestAnimDict(dictionary)
    local timeout = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dictionary) and GetGameTimer() < timeout do Wait(10) end
    return HasAnimDictLoaded(dictionary)
end

local function requestControl(entity)
    if not DoesEntityExist(entity) then return false end
    NetworkRequestControlOfEntity(entity)
    local timeout = GetGameTimer() + 1500
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < timeout do
        NetworkRequestControlOfEntity(entity)
        Wait(10)
    end
    return NetworkHasControlOfEntity(entity)
end

local function faceEntityInstantly(entity,target)
    if not entity or not target or not DoesEntityExist(entity) or not DoesEntityExist(target) then
        return
    end

    local entityCoords = GetEntityCoords(entity)
    local targetCoords = GetEntityCoords(target)
    local heading = GetHeadingFromVector_2d(
        targetCoords.x - entityCoords.x,
        targetCoords.y - entityCoords.y
    )
    SetEntityHeading(entity,heading)
end

local function stopNpcLocomotion(entity)
    if not entity or not DoesEntityExist(entity) then return end

    SetPedDesiredMoveBlendRatio(entity,0.0)
    SetPedMoveRateOverride(entity,0.0)
    ResetPedMovementClipset(entity,0.0)
    ResetPedStrafeClipset(entity)
end

local function holdNpcForNegotiation(entity)
    if not entity or not DoesEntityExist(entity) or not requestControl(entity) then
        return false
    end

    -- O GTA pode disparar tarefas ambientes de medo/fuga enquanto o menu esta aberto.
    -- Bloqueamos essas tarefas e congelamos apenas a posicao do NPC durante a escolha.
    ClearPedSecondaryTask(entity)
    ClearPedTasks(entity)
    SetBlockingOfNonTemporaryEvents(entity,true)
    TaskSetBlockingOfNonTemporaryEvents(entity,true)
    SetPedCanEvasiveDive(entity,false)
    SetPedKeepTask(entity,true)
    TaskTurnPedToFaceEntity(entity,PlayerPedId(),500)
    TaskStandStill(entity,60000)
    Wait(250)

    if not DoesEntityExist(entity) then return false end
    FreezeEntityPosition(entity,true)
    return true
end

local function releaseNpc(entity,walkAway)
    if not entity or not DoesEntityExist(entity) then return end
    if requestControl(entity) then
        FreezeEntityPosition(entity,false)
        SetPedKeepTask(entity,false)
        SetPedCanEvasiveDive(entity,true)
        SetPedMoveRateOverride(entity,1.0)
        ClearPedSecondaryTask(entity)
        ClearPedTasks(entity)
        SetBlockingOfNonTemporaryEvents(entity,false)
        TaskSetBlockingOfNonTemporaryEvents(entity,false)
        if walkAway then TaskWanderStandard(entity,10.0,10) end
        SetEntityAsNoLongerNeeded(entity)
    end
end

local function clearActive(entity,walkAway)
    releaseNpc(entity or ActiveNpc,walkAway)
    ActiveSale = nil
    ActiveNpc = nil
    ActiveCandidate = nil
    ActiveStart = nil
    ProductMenuOpen = false
end

local function setInteractionState(active)
    LocalPlayer.state:set("Buttons",active,false)
    LocalPlayer.state:set("Commands",active,false)
end

local function localNpcStatus(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false,"npc_not_found" end
    if not IsEntityAPed(entity) then return false,"npc_not_ped" end
    if IsPedAPlayer(entity) then return false,"npc_is_player" end
    if not IsPedHuman(entity) then return false,"npc_not_human" end
    if IsEntityDead(entity) or IsPedDeadOrDying(entity,true) or IsPedInjured(entity) then return false,"npc_dead" end
    if IsPedInAnyVehicle(entity,false) then return false,"npc_in_vehicle" end
    if IsPedInCombat(entity,PlayerPedId()) then return false,"npc_in_combat" end
    if GetPedType(entity) ~= 4 and GetPedType(entity) ~= 5 then return false,"npc_type_blocked" end
    if DecorGetBool(entity,"CREATIVE_PED") then return false,"npc_scripted" end
    local reservedByThisSale = ActiveSale and ActiveNpc == entity
    if IsEntityAMissionEntity(entity) and not reservedByThisSale then return false,"npc_mission_entity" end

    local usedUntil = tonumber(Entity(entity).state.SaoJudasStreetSaleUsedUntil) or 0
    if Entity(entity).state.SaoJudasStreetSale and not reservedByThisSale then return false,"npc_busy" end
    if usedUntil > GetCloudTimeAsInt() then return false,"npc_cooldown" end
    return true,"ok"
end

local function localNpcEligible(entity)
    return localNpcStatus(entity)
end

local function ensureNetworked(entity)
    if NetworkGetEntityIsNetworked(entity) then return NetworkGetNetworkIdFromEntity(entity) end
    NetworkRegisterEntityAsNetworked(entity)
    local timeout = GetGameTimer() + 1000
    while not NetworkGetEntityIsNetworked(entity) and GetGameTimer() < timeout do Wait(10) end
    return NetworkGetEntityIsNetworked(entity) and NetworkGetNetworkIdFromEntity(entity) or 0
end

local function targetSnapshot(entity)
    local ped = PlayerPedId()
    local valid,reason = localNpcStatus(entity)
    local exists = entity and entity ~= 0 and DoesEntityExist(entity)
    local networked = exists and NetworkGetEntityIsNetworked(entity) or false
    local networkId = networked and NetworkGetNetworkIdFromEntity(entity) or 0
    local distance = exists and #(GetEntityCoords(ped) - GetEntityCoords(entity)) or -1.0

    return {
        Ped = entity or 0,
        Model = exists and GetEntityModel(entity) or 0,
        IsPlayer = exists and IsPedAPlayer(entity) or false,
        IsHuman = exists and IsPedHuman(entity) or false,
        IsCivilian = exists and (GetPedType(entity) == 4 or GetPedType(entity) == 5) or false,
        IsMissionPed = exists and IsEntityAMissionEntity(entity) or false,
        Networked = networked,
        NetworkId = networkId,
        Alive = exists and not IsEntityDead(entity) and not IsPedDeadOrDying(entity,true) or false,
        InVehicle = exists and IsPedInAnyVehicle(entity,false) or false,
        Distance = tonumber(("%.2f"):format(distance)),
        Safezone = LocalPlayer.state.Safezone == true,
        ResourceStarted = GetResourceState(GetCurrentResourceName()) == "started",
        CanOffer = EligibilityCache.Eligible == true and valid == true and (not ActiveSale or (ActiveNpc == entity and ActiveStart ~= nil)),
        RejectionReason = EligibilityCache.Eligible ~= true and EligibilityCache.Reason or reason
    }
end

local function logTargetOnce(entity,canOffer,reason)
    if not SaoJudasStreetSales.Debug.Enabled then return end
    local key = tostring(entity)..":"..tostring(canOffer)..":"..tostring(reason)
    local now = GetGameTimer()
    if LastTargetDebug.Key == key and now - LastTargetDebug.At < SaoJudasStreetSales.Debug.TargetLogCooldownMs then return end

    LastTargetDebug = { Key = key, At = now }
    local snapshot = targetSnapshot(entity)
    snapshot.Passport = EligibilityCache.Passport
    snapshot.IsMember = EligibilityCache.IsMember
    snapshot.IsLeader = EligibilityCache.IsLeader
    snapshot.HasDistributionRole = EligibilityCache.HasDistributionRole
    snapshot.HasAllowedDrug = EligibilityCache.HasAllowedDrug
    snapshot.AvailableDrugs = EligibilityCache.AvailableDrugs
    print("[saojudas/street-sales-target] "..json.encode(snapshot))
end

exports("CanOffer",function(entity)
    entity = tonumber(entity) or 0
    local valid,reason = localNpcStatus(entity)
    local continuingReservedSale = ActiveSale and ActiveNpc == entity and ActiveStart ~= nil
    local canOffer = EligibilityCache.Eligible == true and valid == true and (not ActiveSale or continuingReservedSale)
    local rejectionReason = canOffer and "ok" or (EligibilityCache.Eligible ~= true and EligibilityCache.Reason or reason)
    logTargetOnce(entity,canOffer,rejectionReason)
    return canOffer,rejectionReason
end)

local function optionsFor(products)
    local options = {}
    for _,product in ipairs(products or {}) do
        options[#options + 1] = {
            Label = ("%s | estoque %s | até %s | $%s-$%s"):format(
                product.Name,product.Available,product.Maximum,product.MinimumPrice,product.MaximumPrice
            ),
            Value = product.Item
        }
    end
    return options
end

local function react(entity,reaction)
    if not entity or not DoesEntityExist(entity) or not requestControl(entity) then return end
    FreezeEntityPosition(entity,false)
    SetPedKeepTask(entity,false)
    TaskTurnPedToFaceEntity(entity,PlayerPedId(),750)

    if reaction == "refuse" then
        if requestAnim("gestures@m@standing@casual") then
            TaskPlayAnim(entity,"gestures@m@standing@casual","gesture_no_way",4.0,-4.0,1800,48,0.0,false,false,false)
        end
        SetTimeout(1800,function() releaseNpc(entity,true) end)
    elseif reaction == "report" then
        TaskStartScenarioInPlace(entity,"WORLD_HUMAN_STAND_MOBILE",0,true)
        SetTimeout(3000,function() releaseNpc(entity,true) end)
    else
        TaskWanderStandard(entity,10.0,10)
        SetEntityAsNoLongerNeeded(entity)
    end
end

local function performAcceptedSale(entity,response,saleId)
    ActiveSale = saleId
    ActiveNpc = entity
    local initialVehicle = GetVehiclePedIsIn(PlayerPedId(),false)
    local vehicleSale = initialVehicle and initialVehicle ~= 0
    local vehicleSettings = SaoJudasStreetSales.StreetMode.VehicleSales or {}
    setInteractionState(true)

    if requestControl(entity) then
        -- O NPC fica preso à negociação, mas sem manter a task de caminhada que o
        -- trouxe até o jogador. A animação de troca precisa ser full-body; usar a
        -- flag 48 (upper-body/secondary) preservava a locomoção anterior e causava
        -- o efeito de caminhar parado ou deslizar enquanto a entidade estava congelada.
        FreezeEntityPosition(entity,true)
        SetPedKeepTask(entity,true)
        SetPedCanEvasiveDive(entity,false)
        ClearPedSecondaryTask(entity)
        ClearPedTasksImmediately(entity)
        TaskSetBlockingOfNonTemporaryEvents(entity,true)
        SetBlockingOfNonTemporaryEvents(entity,true)
        stopNpcLocomotion(entity)
        faceEntityInstantly(entity,PlayerPedId())
    end
    if not vehicleSale then
        TaskTurnPedToFaceEntity(PlayerPedId(),entity,500)
    end
    Wait(500)

    if requestAnim("mp_common") then
        if not vehicleSale then
            TaskPlayAnim(PlayerPedId(),"mp_common","givetake1_a",4.0,-4.0,response.DurationMs,48,0.0,false,false,false)
        end
        if DoesEntityExist(entity) then
            -- Flag 0 = animação primária/full-body. Isso substitui completamente
            -- qualquer ciclo de caminhada residual enquanto o NPC permanece imóvel.
            TaskPlayAnim(entity,"mp_common","givetake1_a",4.0,-4.0,response.DurationMs,0,0.0,false,false,false)
        end
    end
    TriggerEvent("Progress","Negociando",response.DurationMs)

    local deadline = GetGameTimer() + response.DurationMs
    local cancelled = nil
    while GetGameTimer() < deadline do
        local ped = PlayerPedId()
        if IsEntityDead(ped) or IsPedDeadOrDying(ped,true) then
            cancelled = "player_dead"
            break
        end
        if not DoesEntityExist(entity) or IsEntityDead(entity) then
            cancelled = "npc_dead"
            break
        end
        local completionDistance = vehicleSale and (tonumber(vehicleSettings.CompletionDistance) or 4.0)
            or SaoJudasStreetSales.Interaction.CompletionDistance
        if #(GetEntityCoords(ped) - GetEntityCoords(entity)) > completionDistance then
            cancelled = "npc_too_far"
            break
        end
        if vehicleSale then
            local currentVehicle = GetVehiclePedIsIn(ped,false)
            if currentVehicle == 0 then
                cancelled = "vehicle_left"
                break
            elseif currentVehicle ~= initialVehicle then
                cancelled = "vehicle_changed"
                break
            elseif GetPedInVehicleSeat(currentVehicle,-1) ~= ped then
                cancelled = "vehicle_driver_required"
                break
            elseif GetEntitySpeed(currentVehicle) > (tonumber(vehicleSettings.MaximumSpeed) or 0.35) then
                cancelled = "vehicle_moving"
                break
            end
        end
        if LocalPlayer.state.Safezone then
            cancelled = "safezone"
            break
        end
        if DoesEntityExist(entity) then
            stopNpcLocomotion(entity)
        end
        Wait(100)
    end

    if cancelled then
        vSERVER.Cancel(saleId,cancelled)
        notify(errorMessage(cancelled),"amarelo")
        TriggerEvent("Progress","Cancelando",500)
    else
        local result = vSERVER.Complete(saleId)
        if result and result.Ok then
            notify(("Venda concluída.<br>Você recebeu: <b>$%s sujos</b><br>Contribuição para São Judas: <b>$%s sujos</b>"):format(
                result.WorkerAmount,result.FactionAmount
            ),"verde")
        else
            notify(errorMessage(result and result.Reason),"vermelho")
        end
    end

    if not vehicleSale then ClearPedTasks(PlayerPedId()) end
    setInteractionState(false)
    clearActive(entity,true)
end

local function selectProduct(entity,start)
    if ProductMenuOpen then return end
    ProductMenuOpen = true

    -- Tanto o target manual quanto o modo automatico chegam aqui. Seguramos o NPC
    -- antes de abrir o teclado/menu, evitando que ele fuja ou saia da distancia.
    if not holdNpcForNegotiation(entity) then
        vSERVER.Cancel(start.SaleId,"npc_control_failed")
        notify("O comprador nao conseguiu permanecer para a negociacao.","amarelo")
        clearActive(entity,false)
        return
    end

    local options = optionsFor(start.Products)
    local selected = exports.keyboard:Instagram(
        options,
        "Oferecer produto",
        ("%s | %s"):format(start.Region,start.Demand)
    )
    if not selected or not selected[1] then
        vSERVER.Cancel(start.SaleId,"product_selection_cancelled")
        clearActive(entity,true)
        return
    end

    local response = vSERVER.SelectProduct(start.SaleId,tostring(selected[1]))
    if not response or not response.Ok then
        notify(errorMessage(response and response.Reason),"vermelho")
        clearActive(entity,true)
        return
    end

    if response.Reaction == "accept" then
        performAcceptedSale(entity,response,start.SaleId)
    elseif response.Reaction == "refuse" then
        notify("O comprador não demonstrou interesse.")
        react(entity,"refuse")
    elseif response.Reaction == "report" then
        notify("O comprador ficou desconfiado.","vermelho")
        react(entity,"report")
    else
        notify("O pedestre preferiu se afastar.")
        react(entity,"walk_away")
    end

    if response.Reaction ~= "accept" then
        ActiveSale = nil
        ActiveNpc = nil
        ActiveCandidate = nil
        ActiveStart = nil
        ProductMenuOpen = false
    end
end

local function startOffer(entity,automatic)
    if ActiveSale then return nil,"sale_in_progress" end

    local valid,reason = localNpcEligible(entity)
    if not valid then return nil,reason end

    local networkId = ensureNetworked(entity)
    if networkId <= 0 then return nil,"npc_not_networked" end

    local start = vSERVER.StartOffer(networkId,automatic == true)
    if not start or not start.Ok then return nil,start and start.Reason or "npc_not_found" end

    ActiveSale = start.SaleId
    ActiveNpc = entity
    ActiveStart = start
    return start
end

RegisterNetEvent("sao_judas_street_sales:Offer",function(selection)
    local entity = type(selection) == "table" and tonumber(selection[2]) or 0

    -- No modo automatico o servidor ja reservou o NPC e criou a venda.
    -- Nesse caso, clicar no target continua a negociacao existente em vez de tentar abrir outra.
    if ActiveSale and ActiveNpc == entity and ActiveStart then
        selectProduct(entity,ActiveStart)
        return
    end

    local start,reason = startOffer(entity,false)
    if not start then
        notify(errorMessage(reason))
        return
    end
    selectProduct(entity,start)
end)

local function showNegotiationHelp()
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName("Pressione ~INPUT_CONTEXT~ para ~y~negociar~s~.")
    EndTextCommandDisplayHelp(0,false,true,-1)
end

local function findStreetCandidate()
    local player = PlayerPedId()
    local coords = GetEntityCoords(player)
    local radius = tonumber(SaoJudasStreetSales.StreetMode.SearchRadius) or 12.0
    local poolLimit = math.max(1,math.floor(tonumber(SaoJudasStreetSales.StreetMode.RandomCandidatePool) or 5))
    local candidates = {}

    for _,entity in ipairs(GetGamePool("CPed")) do
        if entity ~= player then
            local valid = localNpcEligible(entity)
            if valid and HasEntityClearLosToEntity(player,entity,17) then
                local candidateDistance = #(coords - GetEntityCoords(entity))
                if candidateDistance <= radius then
                    candidates[#candidates + 1] = {
                        Entity = entity,
                        Distance = candidateDistance
                    }
                end
            end
        end
    end

    if #candidates == 0 then return 0 end

    -- Mantém a escolha natural e variada sem chamar um pedestre do outro lado do
    -- bairro: ordena por proximidade e sorteia entre os compradores mais próximos.
    table.sort(candidates,function(a,b) return a.Distance < b.Distance end)
    local maximumIndex = math.min(#candidates,poolLimit)
    return candidates[math.random(1,maximumIndex)].Entity
end


local function approachCandidate(entity,start)
    ActiveCandidate = entity
    local deadline = GetGameTimer() + SaoJudasStreetSales.StreetMode.CandidateTimeoutMs
    local nextTask = 0

    if not requestControl(entity) then
        vSERVER.Cancel(start.SaleId,"npc_control_failed")
        clearActive(entity,false)
        return
    end

    SetBlockingOfNonTemporaryEvents(entity,true)
    TaskSetBlockingOfNonTemporaryEvents(entity,true)

    while StreetModeEnabled and ActiveSale == start.SaleId and GetGameTimer() < deadline do
        local valid,reason = localNpcEligible(entity)
        if not valid and reason ~= "npc_busy" then
            vSERVER.Cancel(start.SaleId,reason)
            clearActive(entity,false)
            return
        end
        if not NetworkHasControlOfEntity(entity) then
            vSERVER.Cancel(start.SaleId,"npc_control_lost")
            clearActive(entity,false)
            return
        end

        local player = PlayerPedId()
        local vehicleContext = vehicleSaleContext()
        local vehicleSettings = SaoJudasStreetSales.StreetMode.VehicleSales or {}
        if vehicleContext.InVehicle and not vehicleContext.Active then
            local reason = not vehicleContext.Driver and "vehicle_driver_required" or "vehicle_moving"
            vSERVER.Cancel(start.SaleId,reason)
            notify(errorMessage(reason),"amarelo")
            clearActive(entity,true)
            return
        end

        local playerDistance = #(GetEntityCoords(player) - GetEntityCoords(entity))
        if playerDistance > SaoJudasStreetSales.StreetMode.SearchRadius + 3.0 then
            vSERVER.Cancel(start.SaleId,"npc_too_far")
            clearActive(entity,false)
            return
        end

        local destination
        local arrivalDistance
        if vehicleContext.Active then
            destination = vehicleMeetingPoint(vehicleContext.Vehicle)
            arrivalDistance = #(GetEntityCoords(entity) - destination)
        else
            destination = GetOffsetFromEntityInWorldCoords(player,0.0,SaoJudasStreetSales.StreetMode.ApproachDistance,0.0)
            arrivalDistance = playerDistance
        end

        local arrived = vehicleContext.Active
            and arrivalDistance <= (tonumber(vehicleSettings.ArrivalTolerance) or 0.90)
            or not vehicleContext.Active and arrivalDistance <= SaoJudasStreetSales.StreetMode.PromptDistance

        if arrived then
            -- A pe, o comprador para na frente. Dentro do carro, ele para junto
            -- a janela do motorista. Em ambos os casos o menu abre automaticamente.
            TaskStandStill(entity,2000)
            TaskTurnPedToFaceEntity(entity,player,500)
            if not vehicleContext.Active then TaskTurnPedToFaceEntity(player,entity,500) end
            Wait(350)

            if ActiveSale == start.SaleId and DoesEntityExist(entity) then
                selectProduct(entity,start)
            end
            return
        else
            local now = GetGameTimer()
            if now >= nextTask then
                TaskGoStraightToCoord(entity,destination.x,destination.y,destination.z,1.0,2500,GetEntityHeading(player) + 180.0,0.25)
                nextTask = now + 1200
            end
            Wait(100)
        end
    end

    if ActiveSale == start.SaleId then
        vSERVER.Cancel(start.SaleId,StreetModeEnabled and "candidate_timeout" or "street_mode_disabled")
        clearActive(entity,true)
    end
end

RegisterCommand(SaoJudasStreetSales.StreetMode.Command,function()
    if ActiveSale then
        notify("Finalize ou cancele a negociação atual.")
        return
    end

    local result = vSERVER.ToggleMode()
    if not result or not result.Ok then
        notify(errorMessage(result and result.Reason),"vermelho")
        return
    end

    StreetModeEnabled = result.Enabled == true
    notify(StreetModeEnabled and "Modo de venda de rua ativado." or "Modo de venda de rua desativado.",StreetModeEnabled and "verde" or "amarelo")
end,false)

if SaoJudasStreetSales.StreetMode.DefaultKey ~= "" then
    RegisterKeyMapping(SaoJudasStreetSales.StreetMode.Command,SaoJudasStreetSales.StreetMode.KeyDescription,"keyboard",SaoJudasStreetSales.StreetMode.DefaultKey)
end

CreateThread(function()
    while true do
        local wait = 1000

        -- O comando funciona como liga/desliga persistente. Estados temporários
        -- apenas pausam esta busca: venda em andamento, cooldown, veículo em
        -- movimento, safe zone ou ausência momentânea de produtos. Assim que a
        -- elegibilidade volta, a procura continua sem executar o comando de novo.
        if StreetModeEnabled and not ActiveSale and EligibilityCache.Eligible == true then
            wait = SaoJudasStreetSales.StreetMode.SearchIntervalMs
            local entity = findStreetCandidate()
            if entity ~= 0 then
                local start,reason = startOffer(entity,true)
                if start then
                    approachCandidate(entity,start)
                elseif reason ~= "npc_not_networked"
                    and reason ~= "npc_cooldown"
                    and reason ~= "player_cooldown" then
                    logTargetOnce(entity,false,reason)
                end
            end
        end
        Wait(wait)
    end
end)

RegisterNetEvent("sao_judas_street_sales:DebugPrint",function(snapshot)
    print("[saojudas/street-sales] debug "..json.encode(snapshot or {}))
end)

local function closestDebugPed(radius)
    local aiming,entity = GetEntityPlayerIsFreeAimingAt(PlayerId())
    if aiming and entity and entity ~= 0 and IsEntityAPed(entity) then return entity end

    local selected = 0
    local selectedDistance = radius + 0.001
    local coords = GetEntityCoords(PlayerPedId())
    for _,candidate in ipairs(GetGamePool("CPed")) do
        if candidate ~= PlayerPedId() and DoesEntityExist(candidate) then
            local candidateDistance = #(coords - GetEntityCoords(candidate))
            if candidateDistance < selectedDistance then
                selected = candidate
                selectedDistance = candidateDistance
            end
        end
    end
    return selected
end

RegisterCommand("saojudas_sales_target_debug",function()
    local entity = closestDebugPed(15.0)
    local localSnapshot = targetSnapshot(entity)
    local networkId = localSnapshot.NetworkId or 0
    local snapshot = vSERVER.TargetDebug(localSnapshot,networkId)
    if not snapshot then return end

    print("[saojudas/street-sales-target] "..json.encode(snapshot))
    notify("Diagnóstico do target enviado ao F8.","azul")
end,false)

CreateThread(function()
    while true do
        local details = { Eligible = false,Reason = "resource_disabled",AvailableDrugs = {},ModeEnabled = StreetModeEnabled }
        if SaoJudasStreetSales.Enabled then
            local ok,result = pcall(function() return vSERVER.EligibilityDetails() end)
            if ok and type(result) == "table" then
                details = result
            elseif not ok then
                details.Reason = "eligibility_callback_failed"
            end
        end
        EligibilityCache = details
        StreetModeEnabled = details.ModeEnabled == true
        LocalPlayer.state:set(SaoJudasStreetSales.TargetState,details.Eligible == true,false)
        Wait(SaoJudasStreetSales.Interaction.EligibilityRefreshMs)
    end
end)

AddEventHandler("onResourceStop",function(resource)
    if resource ~= GetCurrentResourceName() then return end
    LocalPlayer.state:set(SaoJudasStreetSales.TargetState,false,false)
    setInteractionState(false)
    ClearPedTasks(PlayerPedId())
    clearActive(ActiveNpc,true)
end)
