-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")
vRPC = Tunnel.getInterface("vRP")
vRP = Proxy.getInterface("vRP")
-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIAVEIS
-----------------------------------------------------------------------------------------------------------------------------------------
local Resting = {}

local function FindMaca(MacaId)
    for _,maca in ipairs(Config.Macas) do
        if maca.id == MacaId then
            return maca
        end
    end

    return nil
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- AF_HOSPITAL_CURA:STARTREST
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("af_hospital_cura:startRest")
AddEventHandler("af_hospital_cura:startRest",function(MacaId)
    local source = source
    local Passport = vRP.Passport(source)
    if not Passport or Resting[source] then
        return
    end

    local Maca = FindMaca(MacaId)
    if not Maca then
        return
    end

    local Ped = GetPlayerPed(source)
    if not Ped or Ped == 0 then
        return
    end

    local Coords = GetEntityCoords(Ped)
    local Distance = #(Coords - vector3(Maca.coords.x,Maca.coords.y,Maca.coords.z))

    -- Margem de tolerancia para latencia/teleporte do proprio sistema de deitar
    if Distance > 6.0 then
        return
    end

    Resting[source] = true

    CreateThread(function()
        while Resting[source] do
            Wait(Config.PassiveHealInterval)

            if not Resting[source] then
                break
            end

            local StillPassport = vRP.Passport(source)
            if not StillPassport or StillPassport ~= Passport then
                Resting[source] = nil
                break
            end

            local Health = vRP.GetHealth(source)
            if not Health then
                Resting[source] = nil
                break
            end

            if Health <= 100 then
                -- jogador caido/inconsciente, nao mexe na vida aqui (fica a cargo do sistema de paramedico)
            elseif Health < Config.PassiveHealCap then
                vRPC.UpgradeHealth(source,Config.PassiveHealAmount)
            else
                Resting[source] = nil
                TriggerClientEvent("af_hospital_cura:forceStop",source)
                TriggerClientEvent("Notify",source,"Hospital SAMU","Voce recuperou o suficiente na maca. Procure um paramedico para atendimento completo.","verde",6000)
            end
        end
    end)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- AF_HOSPITAL_CURA:STOPREST
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("af_hospital_cura:stopRest")
AddEventHandler("af_hospital_cura:stopRest",function()
    local source = source
    Resting[source] = nil
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PLAYERDROPPED
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("playerDropped",function()
    local source = source
    Resting[source] = nil
end)
