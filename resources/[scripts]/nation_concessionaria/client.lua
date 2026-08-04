local Tunnel = module("vrp", "lib/Tunnel")
local Proxy = module("vrp", "lib/Proxy")
vRP = Proxy.getInterface("vRP")
func = Tunnel.getInterface("nation_concessionaria")
fclient = {}
Tunnel.bindInterface("nation_concessionaria", fclient)

local timer = 0
local config = false
local inTest = false
local nearestConce = false

DoScreenFadeIn(1000)

RegisterNetEvent("nationConce:setConfig")
AddEventHandler(
	"nationConce:setConfig",
	function(cfg)
        config = cfg
    end
)

Citizen.CreateThread(
	function()
		SetNuiFocus(false,false)

        while not config do
            TriggerServerEvent("nationConce:getConfig")
            Citizen.Wait(1000)
        end
    end
)

--- THREAD PARA ENCONTRAR A CONCESSIONÁRIA MAIS PRÓXIMA ---

Citizen.CreateThread(
    function()
        --[[ TriggerScreenblurFadeOut(500)
    DoScreenFadeIn(1000)
    SetNuiFocus(false) ]]
        -- config = func.getConfig()
        while true do
            if not nui and not inTest and timer == 0 and config then
                local playercoords = GetEntityCoords(PlayerPedId())
                local closest = false
                local closestDistance = 999999.0

                for k, v in ipairs(config.locais) do
                    local distance = #(playercoords - v.conce)
                    if distance < closestDistance then
                        closestDistance = distance
                        closest = config.locais[k]
                    end
                end

                nearestConce = closestDistance <= 50.0 and closest or false
            end
            Citizen.Wait(500)
        end
    end
)

--- THREAD PARA DESENHAR OS MARKERS (CONCE MAIS PRÓXIMA) E ABRIR A NUI CASO O PLAYER PRESSIONE \"E\" ---

Citizen.CreateThread(
    function()
        while true do
			local idle = 500
            if not nui and not inTest and timer == 0 and nearestConce and nearestConce.conce then
                local coords = nearestConce.conce
                local playercoords = GetEntityCoords(PlayerPedId())
				local distance = #(playercoords - coords)
                idle = 5

                if distance <= 5 then
                    if conceMarker then
                        conceMarker(coords)
                    else
                        DrawMarker(36, coords, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, 153, 102, 255, 155, 1, 1, 1, 1)
                        DrawMarker(
                            28,
                            coords.x,
                            coords.y,
                            coords.z - 0.97,
                            0,
                            0,
                            0,
                            0,
                            0,
                            0,
                            1.0,
                            1.0,
                            0.5,
                            102,
                            0,
                            255,
                            155,
                            0,
                            0,
                            0,
                            1
                        )
				    end
                end
				
                if conceText and distance <= 1 then
                    conceText()
				end

                if IsControlJustPressed(0, 38) and distance <= 3 then
                    toggleNui()
                end
            end
            Citizen.Wait(idle)
        end
    end
)

function checkNui(coords)
    Citizen.CreateThread(
        function()
            while nui do
                local playercoords = GetEntityCoords(PlayerPedId())
                local distance = #(playercoords - coords)
                if distance > 1.5 then
                    closeConce()
                end
                Citizen.Wait(1000)
            end
        end
    )
end

function notify(mode, message, time)
    if showNotify then
        showNotify(mode, message, time)
    else
        TriggerEvent("Notify", mode, message, time)
    end
end

--- INICIA O TEST DRIVE

function testDrive(model,price)
    if not nearestConce then
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local forward = GetEntityForwardVector(ped)
        nearestConce = {
            test_locais = {
                {
                    coords = vector3(coords.x + forward.x * 5.0, coords.y + forward.y * 5.0, coords.z),
                    h = GetEntityHeading(ped)
                }
            }
        }
    end
        local mhash = loadModel(model)
        closeConce()
        if mhash then
			local count = 0
            local testSpawns = nearestConce.test_locais
            if type(testSpawns) ~= "table" or #testSpawns <= 0 then
                local ped = PlayerPedId()
                local coords = GetEntityCoords(ped)
                local forward = GetEntityForwardVector(ped)
                testSpawns = {
                    {
                        coords = vector3(coords.x + forward.x * 5.0, coords.y + forward.y * 5.0, coords.z),
                        h = GetEntityHeading(ped)
                    }
                }
            end
            for _,spawn in ipairs(testSpawns) do
            local spawnCoords = spawn.coords
            local closestVehicleOnSpot = GetClosestVehicle(spawnCoords.x,spawnCoords.y,spawnCoords.z,3.001,0,71)
                if DoesEntityExist(closestVehicleOnSpot) then
                    count = count + 1
                    if count >= #testSpawns then
                        notify('negado', 'Todas as vagas estão ocupadas no momento.', 3000)
                        func.chargeBack(price)
                        return
                    end
                else
                    Citizen.CreateThread(function()
                    inTest = true
                    DoScreenFadeOut(1000)
                    Wait(1000)
                    local myCoords = GetEntityCoords(PlayerPedId())
                    SetEntityCoords(PlayerPedId(), spawnCoords)
                    local plate = ("TEST%04d"):format(math.random(0,9999))
                    local veh = createVehicle(mhash,spawnCoords,plate)
                    if not DoesEntityExist(veh) then
                        DoScreenFadeIn(1000)
                        notify("negado","Falha ao criar veiculo do test drive.",3000)
                        func.chargeBack(price)
                        return
                    end
                    SetEntityHeading(veh, spawn.h or GetEntityHeading(PlayerPedId()))
                    SetPedIntoVehicle(PlayerPedId(), veh, -1)
                    SetVehicleDoorsLocked(veh,1)
                    DoScreenFadeIn(1000)
                    SendNUIMessage({ action = "showTimer", time = config.tempo_testdrive })
                    notify("importante", "Test Drive iniciado. Não saia do veículo e nem vá para muito longe do local.",3000)
                    while inTest and IsPedInAnyVehicle(PlayerPedId(),false) and #(GetEntityCoords(PlayerPedId()) - spawnCoords) < config.maxDistance and GetPedInVehicleSeat(veh,-1) == PlayerPedId() do
                       Citizen.Wait(500)
                    end
                    if inTest then
                        inTest = false
                        notify("aviso", "Test Drive cancelado.",3000)
                        if #(GetEntityCoords(PlayerPedId()) - spawnCoords) >= config.maxDistance then
                            notify("aviso", "Você se afastou muito do local do test.",3000)
                        end
                        SendNUIMessage({ action = "stopTimer" })
                    else
                        notify("importante", "Test Drive finalizado com sucesso.",3000)
                    end
                        DoScreenFadeOut(1000)
                        Wait(1000)
                        SetEntityAsNoLongerNeeded(veh)
                        SetEntityAsMissionEntity(veh,true,true)
                        DeleteVehicle(veh)
                        SetEntityCoords(PlayerPedId(), myCoords)
                        Wait(1000)
                        DoScreenFadeIn(1000)
                        if GetEntityHealth(PlayerPedId()) < 102 then
                            SetEntityHealth(PlayerPedId(),150)
                        end
                    end)
                return
            end
        end 
    else
        notify("aviso","Veículo indisponível para test drive.",3000)
        func.chargeBack(price)
    end
end


--- CRIA O VEÍCULO DO TEST DRIVE

function createVehicle(mhash, spawnCoords, plate)
    local vehicle = CreateVehicle(mhash, spawnCoords.x, spawnCoords.y, spawnCoords.z, 0.0, true, true)
    if plate then
        SetVehicleNumberPlateText(vehicle, plate)
    end
    if DoesEntityExist(vehicle) then
        local netveh = VehToNet(vehicle)
        NetworkRegisterEntityAsNetworked(vehicle)
        while not NetworkGetEntityIsNetworked(vehicle) do
            NetworkRegisterEntityAsNetworked(vehicle)
            Citizen.Wait(1)
        end
        if NetworkDoesNetworkIdExist(netveh) then
            if SetEntitySomething then
                SetEntitySomething(vehicle, true)
            end
            if NetworkGetEntityIsNetworked(vehicle) then
                SetNetworkIdExistsOnAllMachines(netveh, true)
            end
        end
        SetVehicleIsStolen(vehicle, false)
        SetVehicleNeedsToBeHotwired(vehicle, false)
        SetEntityInvincible(vehicle, false)
        SetEntityAsMissionEntity(vehicle, true, true)
        SetVehicleHasBeenOwnedByPlayer(vehicle, true)
        SetVehRadioStation(vehicle, "OFF")
        SetModelAsNoLongerNeeded(mhash)
    end
    return vehicle
end

-- CARREGAR O MODEL DO VEÍCULO --
function loadModel(model)
    local mhash = GetHashKey(model)
    local timeout = 5000
    while not HasModelLoaded(mhash) do
        RequestModel(mhash)
        timeout = timeout - 1
        if timeout <= 0 then
            return false
        end
        Citizen.Wait(1)
    end
    return mhash
end

--- PEGA AS MODIFICAÇÕES DO VEÍCULO PARA SALVAR NO BANCO DE DADOS

function fclient.getVehicleMods(vehicle)
    if func.checkAuth() then
        local myveh = {}
        local mhash = loadModel(vehicle)
        local coords = GetEntityCoords(PlayerPedId())
        if mhash then
            local veh = CreateVehicle(mhash, coords.x, coords.y, coords.z - 10, 0.0, false, false)
            if DoesEntityExist(veh) then
                myveh = getVehicleMods(veh)
                SetEntityAsNoLongerNeeded(veh)
                SetEntityAsMissionEntity(veh, true, true)
                DeleteVehicle(veh)
            end
        end
        return myveh
    end
end

--- RETORNA A CLASSE DE UM VEÍCULO PELO ÍNDICE ---

function getVehicleClass(class)
    return config.vehicleClasses[class] or "none"
end

--- RETORNA A LISTA DE VEÍCULOS DA CONCE

function getConceVehicleList()
    if func.checkAuth() then
        local vehicles = func.getConceVehicles()
        local discount = func.getDiscount() / 100
        if vehicles and #vehicles > 0 then
            for i in ipairs(vehicles) do
                if not vehicles[i].class then
                    local class = GetVehicleClassFromName(vehicles[i].vehicle)
                    vehicles[i].class = getVehicleClass(class)
                end
                vehicles[i].price = vehicles[i].price - (vehicles[i].price * discount)
            end
        end
        return vehicles or {}
    end
end


--- RETORNA A LISTA DE VEÍCULOS EM DESTAQUE DA CONCE

function getTopVehicleList()
    if func.checkAuth() then
        local vehicles = func.getTopVehicles()
        local discount = func.getDiscount() / 100
        if vehicles and #vehicles > 0 then
            for i in ipairs(vehicles) do
                if not vehicles[i].class then
                    local class = GetVehicleClassFromName(vehicles[i].vehicle)
                    vehicles[i].class = getVehicleClass(class)
                end
                vehicles[i].price = vehicles[i].price - (vehicles[i].price * discount)
            end
        end
        return vehicles or {}
    end
end

--- RETORNA A LISTA DOS VEÍCULOS DO PLAYER

function getMyVehicles(force)
    if func.checkAuth() then
        local myVehicles = func.getMyVehicles(force)
        if myVehicles and #myVehicles > 0 then
            for i in ipairs(myVehicles) do
                if not myVehicles[i].class then
                    local class = GetVehicleClassFromName(myVehicles[i].vehicle)
                    myVehicles[i].class = getVehicleClass(class)
                end
            end
        end
        return myVehicles
    end
end

--- TOGGLE DA NUI ---
function toggleNui()
    nui = not nui
    if nui then
        openConce()
    else
        closeConce()
    end
end


--- ABRIR CONCE ---
function openConce()
    if func.checkAuth() then
        TriggerScreenblurFadeIn(500)
	    SetNuiFocus(true, true)
        SendNUIMessage(
            {
                action = "show",
                config = config,
                vehList = getConceVehicleList(),
                topVehicles = getTopVehicleList(),
                myVehicles = getMyVehicles(true)
            }
        )
        nui = true
        checkNui(GetEntityCoords(PlayerPedId()))
    end
end



--- ABRIR MENU DE GERENCIAMENTO DA CONCE
function fclient.showAdminMenu()
    if func.checkAuth() then
        if not nui then
            nui = true
            checkNui(GetEntityCoords(PlayerPedId()))
            TriggerScreenblurFadeIn(500)
            SetNuiFocus(true, true)
            SendNUIMessage(
                {
                    action = "showAdmin"
                }
            )
        end
    end
end



--- FECHAR A NUI ---
function closeConce()
    TriggerScreenblurFadeOut(500)
    SetNuiFocus(false, false)
    SendNUIMessage({action = "hide"})
    nui = false
end

--- PEGAR A COR DO VEÍCULO

function split(s, delimiter)
    result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, parseInt(match));
    end
    return result;
end

function getColor(color)
    return split(color,",")
end

---


-- FECHAR --
local function makeNuiResponder(cb, timeoutPayload, timeoutMs)
    local replied = false

    local function reply(payload)
        if replied then
            return false
        end

        replied = true
        cb(payload)
        return true
    end

    if timeoutPayload then
        CreateThread(function()
            Wait(timeoutMs or 15000)
            reply(timeoutPayload)
        end)
    end

    return reply
end

RegisterNUICallback(
    "close",
    function(data, cb)
        closeConce()
        SendNUIMessage({action = "hideAdmin"})
        cb({ok = true})
    end
)


RegisterNUICallback(
    "buy-vehicle",
    function(data, cb)
        local reply = makeNuiResponder(cb)

        local function finish(state, message, extra)
            local response = {
                state == true,
                message or (state and "compra concluida" or "nao foi possivel comprar")
            }

            if extra ~= nil then
                response[3] = extra
            end

            if reply(response) then
                print(("[nation_concessionaria] Resposta da compra: state=%s message=%s"):format(
                    tostring(response[1]),
                    tostring(response[2])
                ))
            end
        end

        CreateThread(function()
            Wait(15000)
            finish(false, "tempo limite excedido; tente novamente")
        end)

        local authOk, authorized = pcall(func.checkAuth)
        if not authOk then
            print(("[nation_concessionaria] Erro ao validar compra: %s"):format(tostring(authorized)))
            finish(false, "erro interno ao validar a compra")
            return
        end

        if authorized ~= true then
            finish(false, "acesso negado")
            return
        end

        if type(data) ~= "table" then
            finish(false, "dados invalidos para a compra")
            return
        end

        if timer ~= 0 then
            finish(false, "aguarde antes de tentar novamente")
            return
        end

        local vehicle = tostring(data.vehicle or ""):match("^%s*(.-)%s*$")
        if vehicle == "" then
            finish(false, "veiculo invalido")
            return
        end

        local colorOk, color = pcall(getColor, tostring(data.color or "0,0,0"))
        if not colorOk or type(color) ~= "table" then
            print(("[nation_concessionaria] Cor invalida para %s: %s"):format(vehicle, tostring(color)))
            finish(false, "cor invalida para a compra")
            return
        end

        startTimer(3)
        local ok, state, message, extra = pcall(func.buyVehicle, vehicle, color)

        if not ok then
            print(("[nation_concessionaria] Erro ao comprar %s: %s"):format(tostring(vehicle),tostring(state)))
            finish(false, "erro interno ao concluir a compra")
            return
        end

        finish(state, message, extra)
    end
)



RegisterNUICallback(
    "sell-vehicle",
    function(data, cb)
        local reply = makeNuiResponder(cb, {false, "tempo limite excedido; tente novamente"})
        local authOk, authorized = pcall(func.checkAuth)

        if not authOk or authorized ~= true then
            reply({false, authOk and "acesso negado" or "erro interno ao validar a venda"})
            return
        end

        if type(data) ~= "table" or not data.vehicle then
            reply({false, "veiculo invalido"})
            return
        end

        if timer ~= 0 then
            reply({false, "aguarde antes de tentar novamente"})
            return
        end

        startTimer(3)
        local ok, state, message = pcall(func.sellVehicle, data.vehicle)
        if not ok then
            print(("[nation_concessionaria] Erro ao vender %s: %s"):format(tostring(data.vehicle),tostring(state)))
            reply({false, "erro interno ao concluir a venda"})
            return
        end

        reply({state == true, message or (state and "venda concluida" or "nao foi possivel vender")})
    end
)

RegisterNUICallback("updateVehicles", function(data, cb)
    local ok, response = pcall(function()
        return {
            vehList = getConceVehicleList(),
            topVehicles = getTopVehicleList(),
            myVehicles = getMyVehicles()
        }
    end)

    if not ok then
        print(("[nation_concessionaria] Erro ao atualizar veiculos: %s"):format(tostring(response)))
        cb({vehList = {}, topVehicles = {}, myVehicles = {}, error = "erro ao atualizar veiculos"})
        return
    end

    cb(response)
end)

RegisterNUICallback(
    "try-test",
    function(data, cb)
        local reply = makeNuiResponder(cb, {state = false, message = "tempo limite excedido; tente novamente"})
        if type(data) ~= "table" or not data.vehicle then
            reply({state = false, message = "veiculo invalido"})
            return
        end

        if timer ~= 0 then
            reply({state = false, message = "aguarde antes de tentar novamente"})
            return
        end

        startTimer(7)
        local ok, state, message = pcall(func.testDrive, data.vehicle)
        if not ok then
            print(("[nation_concessionaria] Erro ao iniciar test-drive: %s"):format(tostring(state)))
            reply({state = false, message = "erro interno ao iniciar o test-drive"})
            return
        end

        reply({state = state == true, message = message})
    end
)


RegisterNUICallback(
    "pay-test",
    function(data, cb)
        local reply = makeNuiResponder(cb, {false, "tempo limite excedido; tente novamente", 0})
        if type(data) ~= "table" or not data.vehicle then
            reply({false, "veiculo invalido", 0})
            return
        end

        local ok, state, message, price = pcall(func.payTest, data.vehicle)
        if not ok then
            print(("[nation_concessionaria] Erro ao pagar test-drive: %s"):format(tostring(state)))
            reply({false, "erro interno ao pagar o test-drive", 0})
            return
        end

        reply({state == true, message, price or 0})
    end
)


RegisterNUICallback(
    "test-drive",
    function(data, cb)
        if type(data) ~= "table" or not data.vehicle then
            cb({ok = false, message = "veiculo invalido"})
            return
        end

        local ok, err = pcall(testDrive, data.vehicle, data.price)
        cb({ok = ok, message = ok and "test-drive iniciado" or tostring(err)})
    end
)

RegisterNUICallback(
    "end-test",
    function(data, cb)
        inTest = false
        cb({ok = true})
    end
)
RegisterNUICallback(
    "try-rent",
    function(data, cb)
        local reply = makeNuiResponder(cb, {state = false, message = "tempo limite excedido; tente novamente"})
        if type(data) ~= "table" or not data.vehicle then
            reply({state = false, message = "veiculo invalido"})
            return
        end

        if timer ~= 0 then
            reply({state = false, message = "aguarde antes de tentar novamente"})
            return
        end

        startTimer(3)
        local ok, state, message = pcall(func.rentVehicle, data.vehicle)
        if not ok then
            print(("[nation_concessionaria] Erro ao consultar aluguel: %s"):format(tostring(state)))
            reply({state = false, message = "erro interno ao consultar o aluguel"})
            return
        end

        reply({state = state == true, message = message})
    end
)

RegisterNUICallback(
    "pay-rent",
    function(data, cb)
        local reply = makeNuiResponder(cb, {false, "tempo limite excedido; tente novamente"})
        if type(data) ~= "table" or not data.vehicle then
            reply({false, "veiculo invalido"})
            return
        end

        local ok, state, message = pcall(func.payRent, data.vehicle)
        if not ok then
            print(("[nation_concessionaria] Erro ao pagar aluguel: %s"):format(tostring(state)))
            reply({false, "erro interno ao concluir o aluguel"})
            return
        end

        reply({state == true, message})
    end
)

RegisterNUICallback(
    "manageConce",
    function(data, cb)
        if type(data) ~= "table" then
            cb({ok = false, message = "dados invalidos"})
            return
        end

        if timer ~= 0 then
            cb({ok = false, message = "aguarde antes de tentar novamente"})
            return
        end

        startTimer(3)
        local ok, err = pcall(func.manageConce, data.mode, data.vehicle, data.qtd)
        cb({ok = ok, message = ok and "operacao processada" or tostring(err)})
    end
)

--- COOLDOWN

function startTimer(time)
    Citizen.CreateThread(
        function()
            timer = time
            while timer > 0 do
                Citizen.Wait(1000)
                timer = timer - 1
            end
        end
    )
end
