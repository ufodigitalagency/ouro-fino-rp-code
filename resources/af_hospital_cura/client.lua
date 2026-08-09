-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIAVEIS
-----------------------------------------------------------------------------------------------------------------------------------------
local blipHandles = {}
local resting = false
local restingMacaId = nil

-----------------------------------------------------------------------------------------------------------------------------------------
-- HELPERS
-----------------------------------------------------------------------------------------------------------------------------------------
local function Notify(message,kind)
    TriggerEvent("Notify","Hospital SAMU",message,kind or "default",5000)
end

local function HelpText(text)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0,false,true,-1)
end

local function DrawText3D(x,y,z,text)
    local onScreen,screenX,screenY = World3dToScreen2d(x,y,z)
    if not onScreen then
        return
    end

    SetTextScale(0.28,0.28)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255,255,255,220)
    SetTextCentre(true)
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(screenX,screenY)
end

local function GetLayCoords(maca)
    if maca.lay then
        return maca.lay.x,maca.lay.y,maca.lay.z,maca.lay.heading
    end

    return maca.coords.x,maca.coords.y,maca.coords.z + 0.90,maca.heading
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- BLIPS DAS MACAS
-----------------------------------------------------------------------------------------------------------------------------------------
local function CreateMacaBlips()
    for _,maca in ipairs(Config.Macas) do
        local blip = AddBlipForCoord(maca.coords.x,maca.coords.y,maca.coords.z)

        SetBlipSprite(blip,80)
        SetBlipDisplay(blip,2)
        SetBlipColour(blip,38)
        SetBlipScale(blip,0.35)
        SetBlipAsShortRange(blip,true)

        if SetBlipHiddenOnLegend then
            SetBlipHiddenOnLegend(blip,true)
        end

        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Maca "..maca.id)
        EndTextCommandSetBlipName(blip)

        blipHandles[maca.id] = blip
    end
end

CreateThread(function()
    while not NetworkIsSessionStarted() do
        Wait(500)
    end

    Wait(2000)
    -- CreateMacaBlips() -- Removido: icones "H" das macas no mapa
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- DEITAR / LEVANTAR DA MACA
-----------------------------------------------------------------------------------------------------------------------------------------
local function StopRest()
    if not resting then
        return
    end

    local ped = PlayerPedId()

    resting = false
    restingMacaId = nil

    ClearPedTasksImmediately(ped)
    FreezeEntityPosition(ped,false)

    TriggerServerEvent("af_hospital_cura:stopRest")
    Notify("Voce levantou da maca.","amarelo")
end

local function StartRest(maca)
    if resting then
        return
    end

    local ped = PlayerPedId()
    local x,y,z,heading = GetLayCoords(maca)

    resting = true
    restingMacaId = maca.id

    SetEntityCoordsNoOffset(ped,x,y,z,false,false,false)
    SetEntityHeading(ped,heading)
    FreezeEntityPosition(ped,true)

    TriggerServerEvent("af_hospital_cura:startRest",maca.id)
    Notify("Voce deitou na maca. A recuperacao e lenta - pressione F6 para levantar quando quiser, ou procure um paramedico se precisar de atendimento rapido.","amarelo")

    -- A anim roda em thread separada e com timeout: se o dict nao carregar por
    -- qualquer motivo, o jogador NAO fica preso, so nao vai ter a animacao visual.
    CreateThread(function()
        RequestAnimDict(Config.LayAnim.Dict)

        local attempts = 0
        while not HasAnimDictLoaded(Config.LayAnim.Dict) and attempts < 200 do
            Wait(10)
            attempts = attempts + 1
        end

        if not resting or restingMacaId ~= maca.id then
            return
        end

        if HasAnimDictLoaded(Config.LayAnim.Dict) then
            TaskPlayAnim(PlayerPedId(),Config.LayAnim.Dict,Config.LayAnim.Clip,3.0,3.0,-1,Config.LayAnim.Flag or 1,0,false,false,false)
        elseif Config.Debug then
            Notify("[debug] anim dict "..Config.LayAnim.Dict.." nao carregou a tempo.","vermelho")
        end
    end)
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- TECLA DE SAIR (F6) - via RegisterKeyMapping, roda independente de qualquer outra thread
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterKeyMapping("af_hospital_cura_sair","Levantar da maca (Hospital SAMU)","keyboard",Config.ExitKey or "F6")
RegisterCommand("af_hospital_cura_sair",function()
    StopRest()
end,false)

RegisterNetEvent("af_hospital_cura:forceStop")
AddEventHandler("af_hospital_cura:forceStop",function()
    StopRest()
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- THREAD DE INTERACAO (markers, texto e deitar)
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()

        if resting then
            sleep = 0
            HelpText("Pressione F6 para levantar da maca")
        elseif not IsPedInAnyVehicle(ped,false) then
            local coords = GetEntityCoords(ped)

            for _,maca in ipairs(Config.Macas) do
                local distance = #(coords - vector3(maca.coords.x,maca.coords.y,maca.coords.z))

                if distance <= Config.MarkerDistance then
                    sleep = 0
                    DrawMarker(1,maca.coords.x,maca.coords.y,maca.coords.z - 0.95,0.0,0.0,0.0,0.0,0.0,0.0,0.6,0.6,0.15,0,140,255,110,false,true,2,false,nil,nil,false)

                    if distance <= 3.0 then
                        DrawText3D(maca.coords.x,maca.coords.y,maca.coords.z + 0.55,"Maca "..maca.id)
                    end

                    if distance <= Config.InteractionDistance then
                        HelpText("Pressione ~INPUT_CONTEXT~ para deitar na maca")

                        if IsControlJustPressed(0,38) then
                            StartRest(maca)
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- SEGURANCA: cancela deitado se morrer, trocar de resource ou respawnar
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("onResourceStop",function(resource)
    if resource == GetCurrentResourceName() and resting then
        StopRest()
    end
end)

AddEventHandler("playerSpawned",function()
    if resting then
        StopRest()
    end
end)
