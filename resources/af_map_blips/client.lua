local blipHandles = {}
local blipsEnabled = true
local loadedOnce = false
local routeBlip = nil

local baseResourceBlips = {
    "^banco",
    "^atm",
    "^mercearia_",
    "^roupas_",
    "^barbearia_",
    "^eletronicos$",
    "^mercado_central$"
}

local function Chat(message)
    TriggerEvent("chat:addMessage",{
        color = { 255, 215, 0 },
        multiline = true,
        args = { "Ouro Fino Blips", message }
    })
end

local function Notify(message,kind)
    TriggerEvent("Notify","Ouro Fino Blips",message,kind or "default",5000)
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

local function HelpText(text)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0,false,true,-1)
end

local function ToCoords(data)
    local coords = data.coords or data

    if type(coords) == "vector3" or type(coords) == "vector4" then
        return coords.x + 0.0,coords.y + 0.0,coords.z + 0.0
    end

    if type(coords) == "table" then
        return (coords.x or coords[1] or 0.0) + 0.0,(coords.y or coords[2] or 0.0) + 0.0,(coords.z or coords[3] or 0.0) + 0.0
    end

    return (data.x or 0.0) + 0.0,(data.y or 0.0) + 0.0,(data.z or 0.0) + 0.0
end

local function IsBaseResourceBlip(data)
    local id = tostring(data and data.id or ""):lower()

    for _,pattern in ipairs(baseResourceBlips) do
        if id:find(pattern) then
            return true
        end
    end

    return false
end

local function ShouldCreateMapBlip(data)
    if data.map == false then
        return false
    end

    return not IsBaseResourceBlip(data)
end

local function ShouldDrawWorldMarker(data)
    if data.marker ~= true then
        return false
    end

    return not IsBaseResourceBlip(data)
end

local function ClearBlips()
    for _,handle in pairs(blipHandles) do
        if DoesBlipExist(handle) then
            RemoveBlip(handle)
        end
    end

    blipHandles = {}
    routeBlip = nil
end

local function CreateBlip(data)
    local x,y,z = ToCoords(data)
    local blip = AddBlipForCoord(x,y,z)
    local shortRange = data.shortRange

    if shortRange == nil then
        shortRange = Config.DefaultShortRange
    end

    if shortRange == nil then
        shortRange = true
    end

    SetBlipSprite(blip,data.sprite or 1)
    SetBlipDisplay(blip,data.display or Config.DefaultDisplay or 2)
    SetBlipColour(blip,data.color or 0)
    SetBlipScale(blip,data.scale or 0.55)
    SetBlipAsShortRange(blip,shortRange == true)
    SetBlipPriority(blip,data.priority or 3)

    if data.highDetail == true then
        SetBlipHighDetail(blip,true)
    end

    if SetBlipCategory and data.category then
        SetBlipCategory(blip,data.category)
    end

    if SetBlipHiddenOnLegend and data.hiddenOnLegend ~= nil then
        SetBlipHiddenOnLegend(blip,data.hiddenOnLegend == true)
    end

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(data.name or data.id or "Ouro Fino")
    EndTextCommandSetBlipName(blip)

    return blip
end

local function ConfiguredBlipId(data,index)
    return tostring(data.id or ("blip_"..tostring(index)))
end

local function ReconcileBlips()
    if not loadedOnce or not blipsEnabled then
        return 0
    end

    local restored = 0
    for index,data in ipairs(Config and Config.Blips or {}) do
        if data.enabled ~= false and ShouldCreateMapBlip(data) then
            local id = ConfiguredBlipId(data,index)
            local handle = blipHandles[id]

            if not handle or not DoesBlipExist(handle) then
                blipHandles[id] = CreateBlip(data)
                restored = restored + 1
            end
        end
    end

    if restored > 0 then
        print(("[af_map_blips] Watchdog restaurou %s blip(s) ausente(s)."):format(restored))
    end

    return restored
end

local function FindBlip(key)
    key = tostring(key or ""):lower()

    local alias = Config and Config.NavAliases and Config.NavAliases[key] or key
    for _,data in ipairs(Config and Config.Blips or {}) do
        if data.enabled ~= false then
            local id = tostring(data.id or ""):lower()
            local name = tostring(data.name or ""):lower()

            if id == alias:lower() or id == key or name == key or name:find(key,1,true) then
                return data
            end
        end
    end

    return nil
end

local function SetGps(key)
    local data = FindBlip(key)
    if not data then
        Chat("Destino nao encontrado. Use: banco, caixa, mercearia, concessionaria, policia, hospital, garagem.")
        return
    end

    local x,y,z = ToCoords(data)
    SetNewWaypoint(x,y)

    if routeBlip and DoesBlipExist(routeBlip) then
        SetBlipRoute(routeBlip,false)
    end

    local id = tostring(data.id or "")
    routeBlip = blipHandles[id]
    if routeBlip and DoesBlipExist(routeBlip) then
        SetBlipRoute(routeBlip,true)
        SetBlipRouteColour(routeBlip,data.color or 5)
    end

    Chat(("GPS marcado: %s."):format(data.name or data.id or key))
    Notify(("GPS marcado: %s."):format(data.name or data.id or key),"verde")
end

local function TryInteract(data)
    local id = tostring(data.id or "")

    if id:find("^banco") or id:find("^atm") then
        TriggerEvent("Bank")
        return true
    end

    local shopNumber = id:match("^mercearia_(%d+)")
    if shopNumber then
        TriggerEvent("shops:Open",tonumber(shopNumber))
        return true
    end

    if id == "policia_vestiario" then
        TriggerEvent("skinshop:Open")
        return true
    end

    if id == "policia_arsenal" then
        TriggerEvent("shops:Open","Policia")
        return true
    end

    if id == "hospital_farmacia" then
        TriggerEvent("shops:Open","hospital_farmacia")
        return true
    end

    if id == "hospital_lanchonete" then
        TriggerEvent("shops:Open","Lanchonete")
        return true
    end

    return false
end

local function LoadBlips(silent)
    ClearBlips()

    if not blipsEnabled then
        if not silent then
            Chat("Blips principais desativados.")
        end
        return 0
    end

    local created = 0
    local list = Config and Config.Blips or {}

    for index,data in ipairs(list) do
        if data.enabled ~= false and ShouldCreateMapBlip(data) then
            local id = ConfiguredBlipId(data,index)
            if not blipHandles[id] or not DoesBlipExist(blipHandles[id]) then
                blipHandles[id] = CreateBlip(data)
                created = created + 1
            end
        end
    end

    loadedOnce = true
    print(("[af_map_blips] %s blips principais carregados."):format(created))

    if not silent then
        Chat(("Blips principais carregados: %s. Abra o mapa e procure Banco/Mercearia/Concessionaria."):format(created))
        Notify(("Blips carregados: %s."):format(created),"verde")
    end

    return created
end

local function Status()
    local total = Config and Config.Blips and #Config.Blips or 0
    local handles = 0

    for _,handle in pairs(blipHandles) do
        if DoesBlipExist(handle) then
            handles = handles + 1
        end
    end

    local message = ("Ativo: %s | visiveis: %s | config: %s"):format(tostring(blipsEnabled),handles,total)
    Chat(message)
    Notify(message)
    print("[af_map_blips] "..message)
end

CreateThread(function()
    while not NetworkIsSessionStarted() do
        Wait(500)
    end

    Wait(5000)
    LoadBlips(false)
end)

CreateThread(function()
    while true do
        Wait(Config and Config.ReconcileInterval or 15000)
        ReconcileBlips()
    end
end)

AddEventHandler("playerSpawned",function()
    if not loadedOnce then
        Wait(2500)
        LoadBlips(false)
    end
end)

RegisterNetEvent("af_map_blips:reload",function()
    blipsEnabled = true
    LoadBlips(false)
end)

RegisterNetEvent("af_map_blips:toggle",function()
    blipsEnabled = not blipsEnabled

    if blipsEnabled then
        LoadBlips(false)
    else
        ClearBlips()
        Chat("Blips principais desativados.")
        Notify("Blips principais desativados.")
    end
end)

RegisterNetEvent("af_map_blips:status",Status)

RegisterNetEvent("af_map_blips:gps",SetGps)

RegisterCommand("ofblipsreload",function()
    blipsEnabled = true
    LoadBlips(false)
end,false)

RegisterCommand("ofblips",function()
    TriggerEvent("af_map_blips:toggle")
end,false)

RegisterCommand("ofblipsstatus",Status,false)

RegisterCommand("ofgps",function(_,args)
    SetGps(args[1] or "banco")
end,false)

CreateThread(function()
    while true do
        local sleep = 1000

        if Config and Config.WorldMarkers and blipsEnabled then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local distanceLimit = Config.WorldMarkerDistance or 80.0

            for _,data in ipairs(Config.Blips or {}) do
                if data.enabled ~= false and ShouldDrawWorldMarker(data) then
                    local x,y,z = ToCoords(data)
                    local distance = #(coords - vector3(x,y,z))

                    if distance <= distanceLimit then
                        sleep = 0
                        DrawMarker(2,x,y,z - 0.15,0.0,0.0,0.0,0.0,0.0,0.0,0.22,0.22,0.16,255,255,255,75,false,true,2,false,nil,nil,false)

                        if data.text ~= false and distance <= 8.0 then
                            DrawText3D(x,y,z + 0.65,data.name or data.id or "Ouro Fino")
                        end

                        if distance <= (data.interactionDistance or Config.InteractionDistance or 2.2) then
                            local id = tostring(data.id or "")

                            if id:find("^banco") or id:find("^atm") or id:find("^mercearia_") or id == "policia_vestiario" or id == "policia_arsenal" or id == "hospital_farmacia" or id == "hospital_lanchonete" then
                                HelpText("Pressione ~INPUT_CONTEXT~ para acessar ~y~"..(data.name or "local"))

                                if IsControlJustPressed(0,38) then
                                    TryInteract(data)
                                end
                            end
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)
