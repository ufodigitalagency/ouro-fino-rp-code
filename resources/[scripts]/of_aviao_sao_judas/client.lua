local Tunnel = module("vrp","lib/Tunnel")
local vSERVER = Tunnel.getInterface("of_aviao_sao_judas")

local StartNpc = 0
local CustomerNpc = 0
local StartNpcSpawning = false
local CustomerSpawning = false
local CustomerGeneration = 0
local CurrentCustomerModel = nil
local PackageObject = 0
local StartBlip = 0
local RouteBlip = 0
local StartTargetRegistered = false
local DeliveryTargetRegistered = false
local HasAccess = false
local RouteActive = false
local AwaitingReturn = false
local Busy = false
local PlayerFrozen = false
local CurrentDestination = nil
local CurrentStep = 0
local TotalSteps = 0

local function notify(message,color,duration)
    TriggerEvent("Notify","Aviãozinho",message,color or "amarelo",duration or 5000)
end

local function debugLog(message)
    if Config.Debug then
        print("[of_aviao_sao_judas] "..message)
    end
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

    return HasModelLoaded(hash) and hash or nil
end

local function loadAnimation(dictionary)
    RequestAnimDict(dictionary)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dictionary) and GetGameTimer() < timeout do
        Wait(50)
    end

    return HasAnimDictLoaded(dictionary)
end

local function removeBlip(handle)
    if handle and handle ~= 0 and DoesBlipExist(handle) then
        RemoveBlip(handle)
    end

    return 0
end

local function deletePedSafe(entity)
    if entity and entity ~= 0 and DoesEntityExist(entity) then
        SetEntityAsMissionEntity(entity,true,true)
        DeletePed(entity)
        if DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
    end

    return 0
end

local function deletePackage()
    if PackageObject ~= 0 and DoesEntityExist(PackageObject) then
        DetachEntity(PackageObject,true,true)
        SetEntityAsMissionEntity(PackageObject,true,true)
        DeleteObject(PackageObject)
        if DoesEntityExist(PackageObject) then
            DeleteEntity(PackageObject)
        end
    end

    PackageObject = 0
end

local function removeDeliveryTarget()
    if DeliveryTargetRegistered and GetResourceState("target") == "started" then
        exports.target:RemCircleZone("AviaoSaoJudas:Delivery")
    end

    DeliveryTargetRegistered = false
end

local function cleanupCustomer()
    CustomerGeneration = CustomerGeneration + 1
    CustomerSpawning = false
    removeDeliveryTarget()
    CustomerNpc = deletePedSafe(CustomerNpc)
end

local function stopDeliveryAnimation()
    local ped = PlayerPedId()
    StopAnimTask(ped,Config.Animation.Dictionary,Config.Animation.Player,1.0)
    ClearPedSecondaryTask(ped)

    if CustomerNpc ~= 0 and DoesEntityExist(CustomerNpc) then
        StopAnimTask(CustomerNpc,Config.Animation.Dictionary,Config.Animation.Customer,1.0)
    end

    if PlayerFrozen then
        FreezeEntityPosition(ped,false)
        PlayerFrozen = false
    end

    deletePackage()
end

local function startTargetOptions()
    local routeLabel = "Iniciar rota"
    if not RouteActive then
        routeLabel = "Iniciar rota"
    elseif AwaitingReturn then
        routeLabel = "Finalizar rota"
    else
        routeLabel = "Cancelar rota"
    end

    local onDuty = LocalPlayer.state[Config.Permission] ~= nil
    return {
        {
            event = "of_aviao_sao_judas:ToggleService",
            tunnel = "client",
            label = routeLabel
        },{
            event = "target:Service",
            tunnel = "proserver",
            service = Config.Permission,
            label = onDuty and "Finalizar expediente" or "Iniciar expediente"
        }
    }
end

local function refreshStartTargetOptions()
    if StartTargetRegistered and GetResourceState("target") == "started" then
        exports.target:LabelOptions("AviaoSaoJudas:Start",startTargetOptions())
    end
end

local function cleanupRoute()
    stopDeliveryAnimation()
    cleanupCustomer()
    RouteBlip = removeBlip(RouteBlip)
    RouteActive = false
    AwaitingReturn = false
    Busy = false
    CurrentDestination = nil
    CurrentCustomerModel = nil
    CurrentStep = 0
    TotalSteps = 0
    refreshStartTargetOptions()
end

local function createStartBlip()
    if not HasAccess or (StartBlip ~= 0 and DoesBlipExist(StartBlip)) then
        return
    end

    local cfg = Config.StartBlip
    StartBlip = AddBlipForCoord(Config.Start.x,Config.Start.y,Config.Start.z)
    SetBlipSprite(StartBlip,cfg.Sprite)
    SetBlipDisplay(StartBlip,4)
    SetBlipScale(StartBlip,cfg.Scale)
    SetBlipColour(StartBlip,cfg.Colour)
    SetBlipAsShortRange(StartBlip,cfg.ShortRange)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(cfg.Name)
    EndTextCommandSetBlipName(StartBlip)
end

local function updateAccessBlip(access)
    HasAccess = access == true
    if HasAccess then
        createStartBlip()
    else
        StartBlip = removeBlip(StartBlip)
    end
end

local function createRouteBlip(coords,label)
    local routeColour = Config.Route.BlipColour or Config.StartBlip.Colour or 1
    RouteBlip = removeBlip(RouteBlip)
    RouteBlip = AddBlipForCoord(coords.x,coords.y,coords.z)
    SetBlipSprite(RouteBlip,1)
    SetBlipDisplay(RouteBlip,4)
    SetBlipScale(RouteBlip,0.58)
    SetBlipColour(RouteBlip,routeColour)
    SetBlipRoute(RouteBlip,true)
    SetBlipRouteColour(RouteBlip,routeColour)
    SetBlipAsShortRange(RouteBlip,false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(label)
    EndTextCommandSetBlipName(RouteBlip)
end

local function configureNpc(entity,scenario)
    SetEntityInvincible(entity,true)
    SetBlockingOfNonTemporaryEvents(entity,true)
    FreezeEntityPosition(entity,true)
    SetPedCanRagdoll(entity,false)
    SetPedDiesWhenInjured(entity,false)
    DecorSetBool(entity,"CREATIVE_PED",true)
    SetEntityAsMissionEntity(entity,true,true)

    if scenario and scenario ~= "" then
        TaskStartScenarioInPlace(entity,scenario,0,true)
    end
end

local function createStartNpc()
    if StartNpc ~= 0 and DoesEntityExist(StartNpc) then
        return true
    end

    if StartNpcSpawning then
        return false
    end

    StartNpcSpawning = true

    local model = loadModel(Config.StartNpc.Model)
    if not model then
        StartNpcSpawning = false
        print("[of_aviao_sao_judas] Não foi possível carregar o modelo do NPC inicial.")
        return false
    end

    local entity = CreatePed(4,model,Config.Start.x,Config.Start.y,Config.Start.z + Config.StartNpc.ZOffset,Config.Start.w,false,false)
    SetModelAsNoLongerNeeded(model)
    if entity == 0 or not DoesEntityExist(entity) then
        StartNpcSpawning = false
        return false
    end

    StartNpc = entity
    configureNpc(StartNpc,Config.StartNpc.Scenario)
    StartNpcSpawning = false
    return true
end

local function registerStartTarget()
    if StartTargetRegistered or GetResourceState("target") ~= "started" then
        return
    end

    exports.target:AddCircleZone("AviaoSaoJudas:Start",vector3(Config.Start.x,Config.Start.y,Config.Start.z),1.1,{
        name = "AviaoSaoJudas:Start",
        heading = Config.Start.w,
        useZ = false
    },{
        Distance = 2.0,
            options = startTargetOptions()
        })

    StartTargetRegistered = true
    refreshStartTargetOptions()
end

local function createCustomer(destinationId)
    if CustomerSpawning then
        return false,"spawning"
    end

    if not RouteActive or AwaitingReturn or CurrentDestination ~= destinationId then
        return false,"stale_destination"
    end

    local destination = Config.Destinations[destinationId]
    if not destination then
        return false,"invalid_destination"
    end

    if CustomerNpc ~= 0 and DoesEntityExist(CustomerNpc) then
        return true
    end

    CustomerSpawning = true
    CustomerGeneration = CustomerGeneration + 1
    local generation = CustomerGeneration

    removeDeliveryTarget()
    CustomerNpc = deletePedSafe(CustomerNpc)

    if not CurrentCustomerModel then
        CurrentCustomerModel = Config.CustomerModels[math.random(#Config.CustomerModels)]
    end

    local modelName = CurrentCustomerModel
    local model = loadModel(modelName)
    if not model then
        if generation == CustomerGeneration then
            CustomerSpawning = false
        end
        print(("[of_aviao_sao_judas] Não foi possível carregar o cliente %s."):format(tostring(modelName)))
        return false,"model_load_failed"
    end

    if generation ~= CustomerGeneration or not RouteActive or AwaitingReturn or CurrentDestination ~= destinationId then
        SetModelAsNoLongerNeeded(model)
        return false,"spawn_cancelled"
    end

    local entity = CreatePed(4,model,destination.x,destination.y,destination.z + Config.Delivery.CustomerZOffset,destination.w,false,false)
    SetModelAsNoLongerNeeded(model)
    if entity == 0 or not DoesEntityExist(entity) then
        if generation == CustomerGeneration then
            CustomerSpawning = false
        end
        return false,"create_failed"
    end

    if generation ~= CustomerGeneration or not RouteActive or AwaitingReturn or CurrentDestination ~= destinationId then
        deletePedSafe(entity)
        return false,"spawn_cancelled"
    end

    CustomerNpc = entity
    configureNpc(CustomerNpc,"WORLD_HUMAN_STAND_MOBILE")

    if GetResourceState("target") == "started" then
        exports.target:AddCircleZone("AviaoSaoJudas:Delivery",vector3(destination.x,destination.y,destination.z),Config.Delivery.TargetRadius,{
            name = "AviaoSaoJudas:Delivery",
            heading = destination.w,
            useZ = false
        },{
            Distance = Config.Delivery.TargetDistance,
            options = {
                {
                    event = "of_aviao_sao_judas:Deliver",
                    tunnel = "client",
                    label = "Entregar pacote"
                }
            }
        })
        DeliveryTargetRegistered = true
    end

    if generation == CustomerGeneration then
        CustomerSpawning = false
    end

    debugLog(("customer_created destination=%s model=%s entity=%s"):format(destinationId,tostring(modelName),CustomerNpc))
    return true
end

local function setDestination(destinationId,current,total)
    local destination = Config.Destinations[destinationId]
    if not destination then
        notify("O destino recebido é inválido.","vermelho")
        cleanupRoute()
        return false
    end

    if CurrentDestination ~= destinationId then
        cleanupCustomer()
        CurrentCustomerModel = Config.CustomerModels[math.random(#Config.CustomerModels)]
    elseif not CurrentCustomerModel then
        CurrentCustomerModel = Config.CustomerModels[math.random(#Config.CustomerModels)]
    end

    CurrentDestination = destinationId
    CurrentStep = tonumber(current) or CurrentStep
    TotalSteps = tonumber(total) or TotalSteps
    AwaitingReturn = false
    createRouteBlip(destination,("Entrega %d/%d"):format(CurrentStep,TotalSteps))

    local created,reason = createCustomer(destinationId)
    if not created and reason ~= "spawning" then
        notify("O cliente ainda não apareceu. Aguarde alguns segundos.","amarelo")
    end

    debugLog(("destination_set id=%s step=%s/%s"):format(destinationId,CurrentStep,TotalSteps))
    return true
end

local function setReturnToBase()
    cleanupCustomer()
    CurrentDestination = nil
    CurrentCustomerModel = nil
    AwaitingReturn = true
    createRouteBlip(Config.Start,"Retornar a São Judas")
    refreshStartTargetOptions()
end

local function createPackage()
    if not Config.PackageProp.Enabled then
        return
    end

    local model = loadModel(Config.PackageProp.Model)
    if not model then
        return
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    PackageObject = CreateObject(model,coords.x,coords.y,coords.z,false,false,false)
    SetModelAsNoLongerNeeded(model)

    if PackageObject ~= 0 and DoesEntityExist(PackageObject) then
        local offset = Config.PackageProp.Offset
        local rotation = Config.PackageProp.Rotation
        AttachEntityToEntity(PackageObject,ped,GetPedBoneIndex(ped,Config.PackageProp.Bone),offset.x,offset.y,offset.z,rotation.x,rotation.y,rotation.z,true,true,false,true,1,true)
    end
end

local function playDeliveryAnimation()
    if CustomerNpc == 0 or not DoesEntityExist(CustomerNpc) or not loadAnimation(Config.Animation.Dictionary) then
        return false
    end

    local ped = PlayerPedId()
    TaskTurnPedToFaceEntity(ped,CustomerNpc,600)
    TaskTurnPedToFaceEntity(CustomerNpc,ped,600)
    Wait(500)

    FreezeEntityPosition(ped,true)
    PlayerFrozen = true
    createPackage()
    TaskPlayAnim(ped,Config.Animation.Dictionary,Config.Animation.Player,8.0,-8.0,Config.Delivery.AnimationDurationMs,49,0.0,false,false,false)
    TaskPlayAnim(CustomerNpc,Config.Animation.Dictionary,Config.Animation.Customer,8.0,-8.0,Config.Delivery.AnimationDurationMs,49,0.0,false,false,false)
    Wait(Config.Delivery.AnimationDurationMs)
    stopDeliveryAnimation()
    return true
end

AddEventHandler("of_aviao_sao_judas:ToggleService",function()
    if Busy then
        return
    end

    Busy = true
    local result = vSERVER.ToggleService()
    Busy = false

    if not result or not result.success then
        notify(result and result.message or "Não foi possível acessar a rota.","vermelho")
        return
    end

    if result.action == "started" then
        RouteActive = true
        AwaitingReturn = false
        CurrentStep = result.current or 1
        TotalSteps = result.total or Config.Route.Deliveries
        setDestination(result.destination,CurrentStep,TotalSteps)
    elseif result.action == "cancelled" or result.action == "finished" then
        cleanupRoute()
    end

    notify(result.message,result.action == "finished" and "verde" or "amarelo")
    refreshStartTargetOptions()
end)

RegisterNetEvent("service:Client")
AddEventHandler("service:Client",function(permission)
    if permission ~= Config.Permission then
        return
    end

    Wait(100)
    refreshStartTargetOptions()
end)

AddEventHandler("of_aviao_sao_judas:Deliver",function()
    if Busy or not RouteActive or AwaitingReturn or not CurrentDestination then
        return
    end

    if CustomerNpc == 0 or not DoesEntityExist(CustomerNpc) then
        notify("O cliente não está disponível.","vermelho")
        return
    end

    Busy = true
    local destinationId = CurrentDestination
    local reservation = vSERVER.BeginDelivery(destinationId)
    if not reservation or not reservation.success then
        Busy = false
        if reservation and reservation.terminate then
            cleanupRoute()
        end
        notify(reservation and reservation.message or "Não foi possível iniciar a entrega.","vermelho")
        return
    end

    if not playDeliveryAnimation() then
        Busy = false
        notify("A animação de entrega não pôde ser carregada.","vermelho")
        return
    end

    local result = vSERVER.CompleteDelivery(destinationId,reservation.token)
    Busy = false

    if not result or not result.success then
        if result and result.terminate then
            cleanupRoute()
        end
        notify(result and result.message or "A entrega não foi confirmada.","vermelho")
        return
    end

    notify(("Entrega concluída: %d dirtydollar."):format(result.reward or 0),"verde")

    if result.returnToBase then
        setReturnToBase()
        notify(result.message,"amarelo",7000)
    else
        setDestination(result.destination,result.current,result.total)
    end
end)

RegisterNetEvent("of_aviao_sao_judas:ForceCleanup",function(_,message)
    cleanupRoute()
    if message and message ~= "" then
        notify(message,"vermelho")
    end
end)

CreateThread(function()
    while GetResourceState("target") ~= "started" do
        Wait(500)
    end

    createStartNpc()
    registerStartTarget()

    while true do
        local access = vSERVER.Access()
        updateAccessBlip(access)
        Wait(Config.Route.AccessRefreshSeconds * 1000)
    end
end)

CreateThread(function()
    while true do
        local waitTime = 1000

        if RouteActive then
            local ped = PlayerPedId()
            if LocalPlayer.state.Death or IsPedDeadOrDying(ped,true) or GetEntityHealth(ped) <= 100 then
                vSERVER.Cancel("death")
                cleanupRoute()
            elseif not AwaitingReturn and CurrentDestination and not CustomerSpawning and (CustomerNpc == 0 or not DoesEntityExist(CustomerNpc)) then
                waitTime = 5000
                createCustomer(CurrentDestination)
            end
        elseif not StartNpcSpawning and (StartNpc == 0 or not DoesEntityExist(StartNpc)) then
            createStartNpc()
        end

        Wait(waitTime)
    end
end)

AddEventHandler("onResourceStop",function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    cleanupRoute()
    StartBlip = removeBlip(StartBlip)
    StartNpc = deletePedSafe(StartNpc)

    if GetResourceState("target") == "started" then
        if StartTargetRegistered then
            exports.target:RemCircleZone("AviaoSaoJudas:Start")
        end

        if DeliveryTargetRegistered then
            exports.target:RemCircleZone("AviaoSaoJudas:Delivery")
        end
    end
end)
