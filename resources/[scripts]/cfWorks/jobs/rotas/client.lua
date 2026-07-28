local routeJob = nil
local routeIndex = nil
local routeBlip = nil
local routeBusy = false
local lastReward = 0

local function drawRouteText(x,y,z,text)
    local onScreen,screenX,screenY = World3dToScreen2d(x,y,z)
    if not onScreen then
        return
    end

    SetTextScale(0.35,0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255,255,255,215)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(screenX,screenY)
end

local function clearRouteBlip()
    if routeBlip then
        RemoveBlip(routeBlip)
        routeBlip = nil
    end
end

local function setNextRoutePoint()
    clearRouteBlip()

    local cfg = routeJob and Config.RouteJobs and Config.RouteJobs[routeJob]
    if not cfg or not cfg.points or #cfg.points == 0 then
        return
    end

    local nextIndex = math.random(#cfg.points)
    if #cfg.points > 1 and routeIndex and nextIndex == routeIndex then
        nextIndex = (nextIndex % #cfg.points) + 1
    end

    routeIndex = nextIndex
    local point = cfg.points[routeIndex]

    routeBlip = AddBlipForCoord(point.x,point.y,point.z)
    SetBlipSprite(routeBlip,cfg.blipSprite or 1)
    SetBlipColour(routeBlip,cfg.blipColor or 5)
    SetBlipScale(routeBlip,0.8)
    SetBlipRoute(routeBlip,true)
    SetBlipRouteColour(routeBlip,cfg.blipColor or 5)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(cfg.blipName or "Rota de Trabalho")
    EndTextCommandSetBlipName(routeBlip)
end

RegisterNetEvent("cfWorks:startRouteJob",function(jobId)
    if not Config.RouteJobs or not Config.RouteJobs[jobId] then
        return
    end

    routeJob = jobId
    routeIndex = nil
    routeBusy = false
    setNextRoutePoint()
end)

RegisterNetEvent("cfWorks:stopRouteJob",function()
    routeJob = nil
    routeIndex = nil
    routeBusy = false
    clearRouteBlip()
end)

local function playRouteAnimation(cfg)
    local ped = PlayerPedId()
    local anim = cfg.anim

    if anim and anim[1] and anim[2] then
        RequestAnimDict(anim[1])
        while not HasAnimDictLoaded(anim[1]) do
            Wait(10)
        end

        TaskPlayAnim(ped,anim[1],anim[2],8.0,8.0,cfg.progressTime or 4000,1,0,false,false,false)
    end
end

local function completeRoutePoint()
    local cfg = routeJob and Config.RouteJobs and Config.RouteJobs[routeJob]
    if not cfg then
        return
    end

    local now = GetGameTimer()
    if routeBusy or now - lastReward < (cfg.cooldown or 2500) then
        return
    end

    routeBusy = true
    lastReward = now

    playRouteAnimation(cfg)
    TriggerEvent("progress",cfg.progressTime or 4000,cfg.progressText or "Trabalhando...")
    Wait(cfg.progressTime or 4000)
    ClearPedTasks(PlayerPedId())

    TriggerServerEvent("cfWorks:routeReward",routeJob)
    routeBusy = false
    setNextRoutePoint()
end

CreateThread(function()
    while true do
        local idle = 1000

        if routeJob and routeIndex and ActiveJob == routeJob then
            local cfg = Config.RouteJobs and Config.RouteJobs[routeJob]
            local point = cfg and cfg.points and cfg.points[routeIndex]

            if point then
                local ped = PlayerPedId()
                local coords = GetEntityCoords(ped)
                local dist = #(coords - point)

                if dist < 35.0 then
                    idle = 0
                    DrawMarker(21,point.x,point.y,point.z + 0.15,0,0,0,0,180.0,0,0.75,0.75,0.55,80,170,255,160,false,true,2,true)

                    if dist < 2.0 then
                        drawRouteText(point.x,point.y,point.z + 0.9,cfg.markerText or "~g~[E]~w~ CONCLUIR")

                        if IsControlJustPressed(0,38) then
                            completeRoutePoint()
                        end
                    end
                end
            end
        elseif routeJob then
            TriggerEvent("cfWorks:stopRouteJob")
        end

        Wait(idle)
    end
end)
