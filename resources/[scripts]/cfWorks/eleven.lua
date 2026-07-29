local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")
vRP = Proxy.getInterface("vRP")

tks = {}
Tunnel.bindInterface(GetCurrentResourceName(), tks)
vSERVER = Tunnel.getInterface(GetCurrentResourceName())

local menuActive = false
ActiveJob = nil

function toggleNui(status)
    menuActive = status
    SetNuiFocus(status, status)
    if status then
        TriggerServerEvent("cfWorks:requestData")
    end
    SendNUIMessage({ action = "toggle", show = status })
end

CreateThread(function()
    while true do
        local idle = 1000
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local dist = #(coords - vec3(Config.Marker[1], Config.Marker[2], Config.Marker[3]))

        if dist < 5.0 then
            idle = 0
            DrawMarker(20, Config.Marker[1], Config.Marker[2], Config.Marker[3]-0.5, 0,0,0,0,0,0,0.7,0.7,0.7, 255, 255, 255, 100, false, false, 2, true)
            DrawMarker(25, Config.Marker[1], Config.Marker[2], Config.Marker[3]-0.9, 0,0,0,0,0,0,1.0,1.0,1.0, 255, 255, 255, 100, false, false, 2, true)
            if dist < 1.5 and IsControlJustPressed(0, 38) then
                toggleNui(true)
            end
        end
        Wait(idle)
    end
end)

RegisterNUICallback("closeUI", function(data, cb)
    toggleNui(false)
    cb('ok')
end)

RegisterNetEvent("cfWorks:syncActiveJob")
AddEventHandler("cfWorks:syncActiveJob", function(jobId)
    if ActiveJob == jobId then
        return
    end

    if ActiveJob == "lixeiro" then
        TriggerEvent("cfWorks:cleanupLixeiro")
    elseif ActiveJob == "taxista" then
        TriggerEvent("taxi:StopShift")
    end

    ActiveJob = jobId

    if not (jobId and Config.RouteJobs and Config.RouteJobs[jobId]) then
        TriggerEvent("cfWorks:stopRouteJob")
    end
end)

RegisterNUICallback("selectJob", function(data, cb)
    local jobId = data.jobId

    -- Trocar ou sair do Lixeiro remove o caminhao e restaura a roupa atual.
    if ActiveJob == "lixeiro" then
        TriggerEvent("cfWorks:cleanupLixeiro")
    end

    if ActiveJob == "taxista" and jobId ~= "taxista" then
        TriggerEvent("taxi:StopShift")
    end

    ActiveJob = jobId
    if ActiveJob == "minerador" then
        CriarRotaMineradora()
        TriggerEvent("Notify", "amarelo", "Vá até a mineradora e inicie o seu trabalho!", 5000)
    end
    if ActiveJob == "eletricista" then
        TriggerEvent("cfWorks:iniciarEletricista")
        TriggerEvent("Notify", "amarelo", "Faça sua rota pela cidade e conserte os postes com defeito!", 5000)
    end
    if ActiveJob == "lixeiro" then
        TriggerEvent("Notify", "amarelo", "Recolha os lixos pela cidade!", 5000)
    end
    if ActiveJob == "taxista" then
        TriggerEvent("taxi:SelectedJob")
        TriggerEvent("Notify", "amarelo", "Va ate a Central de Taxi para iniciar as corridas.", 5000)
    end
    if Config.RouteJobs and Config.RouteJobs[ActiveJob] then
        TriggerEvent("cfWorks:startRouteJob",ActiveJob)
        TriggerEvent("Notify", "amarelo", "Siga o GPS para iniciar sua rota.", 5000)
    else
        TriggerEvent("cfWorks:stopRouteJob")
    end
    TriggerServerEvent("cfWorks:setJob", jobId)
    TriggerEvent("Notify", "verde", "Você entrou em serviço como: <b>"..jobId.."</b>", 5000)
    toggleNui(false)
    cb('ok')
end)

RegisterNUICallback("renewWorkPermit", function(data, cb)
    TriggerServerEvent("cfWorks:renewPermit")
    cb('ok')
end)

RegisterNetEvent("cfWorks:updateUI")
AddEventHandler("cfWorks:updateUI", function(payload)
    SendNUIMessage({
        action = "update",
        data = payload,
        jobs = Config.Jobs
    })
end)

CreateThread(function()
    local cfg = Config.JobCenter.blip
    local blip = AddBlipForCoord(Config.JobCenter.pos)

    SetBlipSprite(blip, cfg.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, cfg.scale)
    SetBlipColour(blip, cfg.color)
    SetBlipAsShortRange(blip, true)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(cfg.name)
    EndTextCommandSetBlipName(blip)
end)

CreateThread(function()
    while true do
        local msec = 1000
        if ActiveJob then
            msec = 0
            DrawTextJob("Para sair de servico, use ~y~/sairtrabalho~w~")
        end
        Wait(msec)
    end
end)

function DrawTextJob(text)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextScale(0.35, 0.35)
    SetTextColour(255, 255, 255, 215)
    SetTextDropShadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(0.2, 0.95)
end

RegisterCommand("sairtrabalho", function()
    local jobAtExit = ActiveJob
    if ActiveJob then
        TriggerEvent("Notify", "amarelo", "Você saiu de serviço como <b>"..ActiveJob.."</b>", 5000)
        TriggerEvent("cfWorks:stopRouteJob")
        if jobAtExit == "lixeiro" then
            TriggerEvent("cfWorks:cleanupLixeiro")
        end
        if jobAtExit == "taxista" then
            TriggerEvent("taxi:StopShift")
        end
        TriggerServerEvent("cfWorks:stopJob")
        ActiveJob = nil
    end
end)
