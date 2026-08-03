local panelOpen = false
local noclip = false
local noclipSpeed = 1.4

local function focusAfterClose()
    if LocalPlayer.state.Active == true then
        SetNuiFocus(false,false)
    else
        SetNuiFocus(true,true)
    end

    SetNuiFocusKeepInput(false)
end

local function setPanel(state)
    panelOpen = state == true
    SendNUIMessage({ action = panelOpen and "open" or "close" })

    if panelOpen then
        SetNuiFocus(true,true)
        SetNuiFocusKeepInput(false)
        TriggerServerEvent("af_owner_panel:requestCatalog")
        TriggerServerEvent("af_owner_panel:requestJobHierarchies")
        TriggerServerEvent("af_owner_panel:requestPlayers")
        TriggerServerEvent("af_owner_panel:requestServerState")
        TriggerServerEvent("af_owner_panel:requestPremiumOrders","awaiting_review")
    else
        focusAfterClose()
    end
end

local function hardClose()
    panelOpen = false
    SendNUIMessage({ action = "close" })
    focusAfterClose()
end

local function notify(message)
    TriggerEvent("Notify","Painel Admin",message,"default",5000)
end

local function teleportToWaypoint()
    local blip = GetFirstBlipInfoId(8)
    if not DoesBlipExist(blip) then
        notify("Marque um waypoint no mapa primeiro.")
        return
    end

    local coord = GetBlipInfoIdCoord(blip)
    local ped = PlayerPedId()

    for height = 950.0, 0.0, -25.0 do
        SetPedCoordsKeepVehicle(ped,coord.x,coord.y,height)
        RequestCollisionAtCoord(coord.x,coord.y,height)
        Wait(25)

        local found,z = GetGroundZFor_3dCoord(coord.x,coord.y,height,false)
        if found then
            SetPedCoordsKeepVehicle(ped,coord.x,coord.y,z + 1.0)
            notify("Teleportado para o waypoint.")
            return
        end
    end

    SetPedCoordsKeepVehicle(ped,coord.x,coord.y,coord.z + 1.0)
end

local function toggleNoclip()
    noclip = not noclip
    local ped = PlayerPedId()
    SetEntityInvincible(ped,noclip)
    SetEntityVisible(ped,not noclip,false)
    FreezeEntityPosition(ped,noclip)
    notify(noclip and "Noclip ativado." or "Noclip desativado.")
end

CreateThread(function()
    while true do
        if noclip then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local camRot = GetGameplayCamRot(2)
            local heading = math.rad(camRot.z)
            local pitch = math.rad(camRot.x)
            local speed = noclipSpeed

            if IsControlPressed(0,21) then
                speed = speed * 3.0
            elseif IsControlPressed(0,36) then
                speed = speed * 0.35
            end

            local forward = vector3(-math.sin(heading) * math.cos(pitch), math.cos(heading) * math.cos(pitch), math.sin(pitch))
            local right = vector3(math.cos(heading), math.sin(heading), 0.0)
            local move = vector3(0.0,0.0,0.0)

            if IsControlPressed(0,32) then move = move + forward end
            if IsControlPressed(0,33) then move = move - forward end
            if IsControlPressed(0,34) then move = move - right end
            if IsControlPressed(0,35) then move = move + right end
            if IsControlPressed(0,22) then move = move + vector3(0.0,0.0,1.0) end
            if IsControlPressed(0,44) then move = move - vector3(0.0,0.0,1.0) end

            SetEntityVelocity(ped,0.0,0.0,0.0)
            SetEntityCoordsNoOffset(ped,coords.x + move.x * speed,coords.y + move.y * speed,coords.z + move.z * speed,true,true,true)
            SetEntityHeading(ped,camRot.z)
            Wait(0)
        else
            Wait(300)
        end
    end
end)

RegisterNetEvent("af_owner_panel:open",function()
    if panelOpen then
        setPanel(false)
        return
    end

    if LocalPlayer.state.Active ~= true then
        hardClose()
        notify("Finalize a selecao de personagem antes de abrir o painel.")
        return
    end

    setPanel(true)
end)

RegisterNetEvent("af_owner_panel:runClientAction",function(action)
    action = tostring(action or "")

    if action == "openPanel" then
        if LocalPlayer.state.Active ~= true then
            hardClose()
            notify("Finalize a selecao de personagem antes de abrir o painel.")
            return
        end

        setPanel(true)
    elseif action == "noclip" then
        toggleNoclip()
    elseif action == "tpway" then
        teleportToWaypoint()
    elseif action == "dogcds" then
        ExecuteCommand("dogcds")
        notify("CDS Pro aberto. Use Capturar Ped e copie vector4.")
    elseif action == "blipsreload" then
        ExecuteCommand("ofblipsreload")
    elseif action == "itemCatalog" then
        if LocalPlayer.state.Active ~= true then
            hardClose()
            notify("Finalize a selecao de personagem antes de abrir a lista.")
            return
        end

        setPanel(true)
        SendNUIMessage({ action = "catalogMode" })
        TriggerServerEvent("af_owner_panel:requestCatalog")
    elseif action == "telaoEdit" then
        ExecuteCommand("telaoedit")
    elseif action == "telaoSave" then
        ExecuteCommand("telaosalvar")
    end
end)

RegisterNetEvent("af_owner_panel:catalog",function(payload)
    SendNUIMessage({ action = "catalog", payload = payload or {} })
end)

RegisterNetEvent("af_owner_panel:jobHierarchies",function(payload)
    SendNUIMessage({ action = "jobHierarchies", payload = payload or {} })
end)

RegisterNetEvent("af_owner_panel:players",function(payload)
    SendNUIMessage({ action = "players", payload = payload or {} })
end)

RegisterNetEvent("af_owner_panel:grantMoneyResult",function(payload)
    SendNUIMessage({ action = "moneyGrantResult", payload = payload or {} })
end)

RegisterNetEvent("af_owner_panel:serverState",function(payload)
    SendNUIMessage({ action = "serverState", payload = payload or {} })
end)

RegisterNetEvent("af_owner_panel:premiumOrders",function(payload)
    SendNUIMessage({ action = "premiumOrders", payload = payload or {} })
end)

RegisterNetEvent("af_owner_panel:premiumOrdersChanged",function()
    if panelOpen then
        TriggerServerEvent("af_owner_panel:requestPremiumOrders","awaiting_review")
    end
end)

RegisterNetEvent("af_owner_panel:runTelaoHere",function(url)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local radians = math.rad(heading)
    local distance = 12.0
    local height = 5.4
    local x = coords.x + (-math.sin(radians) * distance)
    local y = coords.y + (math.cos(radians) * distance)

    TriggerServerEvent("af_owner_panel:telao","on",{
        enabled = true,
        url = url,
        x = x,
        y = y,
        z = coords.z + (height / 2.0),
        heading = (heading + 180.0) % 360.0,
        width = 9.6,
        height = height
    })
end)

RegisterNUICallback("close",function(_,cb)
    hardClose()
    cb(true)
end)

RegisterNUICallback("clientAction",function(data,cb)
    local action = data and data.action

    if action == "god" then
        TriggerServerEvent("af_owner_panel:requestPanelSelfRecovery")
    else
        TriggerServerEvent("af_owner_panel:clientAction",action)
    end

    cb(true)
end)

RegisterNUICallback("adminAction",function(data,cb)
    TriggerServerEvent("af_owner_panel:adminAction",data and data.action,data or {})
    cb(true)
end)

RegisterNUICallback("grantMoney",function(data,cb)
    TriggerServerEvent("af_owner_panel:grantMoney",type(data) == "table" and data or {})
    cb({ accepted = true })
end)

RegisterNUICallback("premiumOrders",function(data,cb)
    TriggerServerEvent("af_owner_panel:requestPremiumOrders",data and data.status or "awaiting_review")
    cb(true)
end)

RegisterNUICallback("reviewPremiumOrder",function(data,cb)
    TriggerServerEvent("af_owner_panel:reviewPremiumOrder",type(data) == "table" and data or {})
    cb({ accepted = true })
end)

RegisterNUICallback("telao",function(data,cb)
    local action = data and data.action or ""

    if action == "here" then
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        local radians = math.rad(heading)
        local distance = tonumber(data.distance) or 12.0
        local height = tonumber(data.height) or 5.4
        local x = coords.x + (-math.sin(radians) * distance)
        local y = coords.y + (math.cos(radians) * distance)

        TriggerServerEvent("af_owner_panel:telao","on",{
            enabled = true,
            url = data.url,
            x = x,
            y = y,
            z = coords.z + (height / 2.0),
            heading = (heading + 180.0) % 360.0,
            width = tonumber(data.width) or 9.6,
            height = height
        })
    elseif action == "edit" then
        TriggerEvent("af_youtube_tv:setEditMode",true)
    elseif action == "save" then
        TriggerServerEvent("af_owner_panel:telao","save",data or {})
    elseif action == "cancelEdit" then
        TriggerEvent("af_youtube_tv:setEditMode",false)
    elseif action == "testAudio" then
        TriggerEvent("af_youtube_tv:testAudio")
    elseif action == "audioStatus" then
        ExecuteCommand("telao audiostatus")
    else
        TriggerServerEvent("af_owner_panel:telao",action,data or {})
    end

    cb(true)
end)

RegisterCommand("ofadminclose",function()
    hardClose()
end,false)

RegisterCommand("ofrecover",function(_,args)
    if type(args) == "table" and #args > 0 then
        notify("O comando ofrecover nao aceita argumentos.")
        return
    end

    TriggerServerEvent("af_owner_panel:requestEmergencySelfRecovery")
end,false)

RegisterCommand("ofprotection",function(_,args)
    if type(args) == "table" and #args > 0 then
        notify("O comando ofprotection nao aceita argumentos.")
        return
    end

    TriggerServerEvent("af_owner_panel:requestProtectionToggle")
end,false)

RegisterCommand("ofrelease",function(_,args)
    if type(args) == "table" and #args > 0 then
        notify("O comando ofrelease nao aceita argumentos.")
        return
    end

    TriggerServerEvent("af_owner_panel:requestSelfRelease")
end,false)

RegisterNetEvent("af_owner_panel:selfRecoveryResult",function(data)
    if type(data) ~= "table" then
        notify("Resposta invalida da recuperacao.")
        return
    end

    if data.success == true and data.result == "partial" then
        local preserved = type(data.preserved) == "table" and table.concat(data.preserved,", ") or "restricoes institucionais"
        notify("Recuperacao concluida parcialmente. Preservado: "..preserved..".")
    elseif data.success == true then
        notify("Recuperacao concluida com seguranca.")
    else
        notify(tostring(data.message or "Recuperacao negada pelo servidor."))
    end
end)

RegisterNetEvent("af_owner_panel:protectionResult",function(data)
    if type(data) ~= "table" then
        notify("Resposta invalida da protecao preventiva.")
        return
    end

    notify(tostring(data.message or (data.enabled == true and "Protecao preventiva ativada." or "Protecao preventiva desativada.")))
end)

RegisterNetEvent("af_owner_panel:releaseResult",function(data)
    if type(data) ~= "table" then
        notify("Resposta invalida da libertacao emergencial.")
        return
    end

    if data.success ~= true then
        notify(tostring(data.message or "Libertacao negada pelo servidor."))
        return
    end

    local released = type(data.released) == "table" and table.concat(data.released,", ") or ""
    local preserved = type(data.preserved) == "table" and table.concat(data.preserved,", ") or ""
    if data.result == "partial" then
        notify("Libertacao parcial. Liberado: "..(released ~= "" and released or "nenhum")..". Preservado: "..(preserved ~= "" and preserved or "contexto legitimo")..".")
    elseif released ~= "" then
        notify("Libertacao concluida: "..released..".")
    else
        notify(tostring(data.message or "Nenhuma restricao proprietaria estava ativa."))
    end
end)

RegisterNetEvent("af_owner_panel:close",function()
    hardClose()
end)

AddEventHandler("onResourceStart",function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end

    CreateThread(function()
        Wait(500)
        hardClose()

        Wait(1500)
        hardClose()
    end)
end)
