local pedrasColetadas = {}
local rotaBlip = nil

function CriarRotaMineradora()
    if rotaBlip then RemoveBlip(rotaBlip) end
    local pos = Config.Minerador.AreaInicio
    rotaBlip = AddBlipForCoord(pos.x, pos.y, pos.z)
    SetBlipSprite(rotaBlip, 1)
    SetBlipColour(rotaBlip, 5)
    SetBlipRoute(rotaBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Mineradora: Vá até aqui")
    EndTextCommandSetBlipName(rotaBlip)
end

CreateThread(function()
    while true do
        local idle = 1000
        if ActiveJob == "minerador" then
            local ped = PlayerPedId()
            local pCoords = GetEntityCoords(ped)

            if rotaBlip and #(pCoords - Config.Minerador.AreaInicio) < 10.0 then
                RemoveBlip(rotaBlip)
                rotaBlip = nil
                TriggerEvent("Notify", "importante", "Você chegou à mineradora! Comece a minerar as pedras.")
            end

            for _, v in pairs(Config.Minerador.Locais) do
                if not pedrasColetadas[v.id] then
                    local dist = #(pCoords - v.coords)
                    if dist < 10.0 then
                        idle = 5
                        DrawMarker(20, v.coords.x, v.coords.y, v.coords.z + 0.2, 0,0,0,0,180.0,0, 0.5,0.5,0.5, 255, 255, 0, 100, true, true, 2, true)

                        if dist < 1.5 then
                            DrawText3Ds(v.coords.x, v.coords.y, v.coords.z + 0.8, "~y~[E]~w~ MINERAR")
                            if IsControlJustPressed(0, 38) then
                                IniciarMineracao(v.id)
                            end
                        end
                    end
                end
            end
        else
            if rotaBlip then
                RemoveBlip(rotaBlip)
                rotaBlip = nil
            end
        end
        Wait(idle)
    end
end)

function IniciarMineracao(id)
    local ped = PlayerPedId()
    local animDict = "amb@world_human_const_drill@male@drill@base"
    local animName = "base"
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Wait(10)
    end
    pedrasColetadas[id] = true
    TaskPlayAnim(ped, animDict, animName, 8.0, 8.0, -1, 1, 0, false, false, false)
    TriggerEvent("Progress", 5000)
    Wait(5000)
    ClearPedTasks(ped)
    RemoveAnimDict(animDict)
    TriggerServerEvent("cfWorks:mineradorReward")
    SetTimeout(Config.Minerador.CooldownVolta, function()
        pedrasColetadas[id] = nil
    end)
end
