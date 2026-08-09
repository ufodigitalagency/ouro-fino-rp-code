local RESOURCE_NAME = GetCurrentResourceName()
local activeNpcs = {}

local function Log(msg)
    print(('[af_live_events] %s'):format(msg))
end

-- ============================================================
-- Texto 3D acima do NPC
-- ============================================================

local function DrawText3D(x, y, z, text, scale, r, g, b, a)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)

    if not onScreen then return end

    SetTextScale(scale, scale)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(r or 255, g or 255, b or 255, a or 255)
    SetTextDropshadow(2, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextOutline()
    SetTextEntry('STRING')
    AddTextComponentString(text)
    DrawText(sx, sy)
end

-- ============================================================
-- Carregar modelo com timeout
-- ============================================================

local function LoadModel(modelHash, timeoutMs)
    timeoutMs = timeoutMs or 5000

    if HasModelLoaded(modelHash) then return true end

    RequestModel(modelHash)

    local waited = 0

    while not HasModelLoaded(modelHash) and waited < timeoutMs do
        Citizen.Wait(50)
        waited = waited + 50
    end

    return HasModelLoaded(modelHash)
end

-- ============================================================
-- Spawnar NPC
-- ============================================================

local function SpawnNpc(username, giftName)
    local maximumActive = math.max(1,tonumber(Config.MaximumActiveNpcs) or 8)
    while #activeNpcs >= maximumActive do
        local oldest = table.remove(activeNpcs,1)
        if oldest and DoesEntityExist(oldest.ped) then
            DeleteEntity(oldest.ped)
        end
    end

    local modelName = Config.NpcModel or 'a_m_m_business_01'
    local modelHash = GetHashKey(modelName)

    if not LoadModel(modelHash, 5000) then
        Log('Falha ao carregar modelo: ' .. modelName)
        return
    end

    local ped = PlayerPedId()
    local heading = GetEntityHeading(ped)
    local headingRad = heading * math.pi / 180.0
    local dist = Config.SpawnDistance or 3.0

    local px, py, pz = table.unpack(GetEntityCoords(ped, true))
    local nx = px - math.sin(headingRad) * dist
    local ny = py + math.cos(headingRad) * dist
    local nz = pz

    -- Encontrar Z do chao.
    local found, groundZ = GetGroundZFor_3dCoord(nx, ny, nz + 2.0, false)

    if found then
        nz = groundZ
    end

    local npc = CreatePed(4, modelHash, nx, ny, nz, heading + 180.0, false, true)

    if not DoesEntityExist(npc) then
        Log('Falha ao criar NPC para: ' .. username)
        SetModelAsNoLongerNeeded(modelHash)
        return
    end

    -- Tornar invencivel e parado.
    SetEntityInvincible(npc, true)
    SetBlockingOfNonTemporaryEvents(npc, true)
    FreezeEntityPosition(npc, true)
    SetPedFleeAttributes(npc, 0, false)
    SetPedCombatAttributes(npc, 17, true)  -- BF_CanFightArmedPedsWhenNotArmed desativado
    SetPedCanRagdoll(npc, false)

    SetModelAsNoLongerNeeded(modelHash)

    local entry = {
        ped = npc,
        username = username or 'StreamToEarn',
        giftName = giftName or '',
        spawnTime = GetGameTimer(),
        lifetime = (Config.NpcLifetimeSeconds or 60) * 1000
    }

    table.insert(activeNpcs, entry)
    Log(('NPC spawnado: user=%s gift=%s'):format(entry.username, entry.giftName))
end

-- ============================================================
-- Evento do servidor
-- ============================================================

RegisterNetEvent('af_live_events:spawnNpc', function(username, giftName)
    username = tostring(username or ''):gsub('[%z\1-\31\127]',''):sub(1,64)
    giftName = tostring(giftName or ''):gsub('[%z\1-\31\127]',''):sub(1,64)

    if username == '' then username = 'StreamToEarn' end

    SpawnNpc(username, giftName)
end)

-- ============================================================
-- Loop principal: desenhar texto e limpar NPCs expirados
-- ============================================================

Citizen.CreateThread(function()
    while true do
        local sleep = 500
        local now = GetGameTimer()
        local playerCoords = GetEntityCoords(PlayerPedId(), true)
        local drawDist = Config.DrawDistance or 20.0
        local toRemove = {}

        for i, entry in ipairs(activeNpcs) do
            -- Checar se expirou.
            if now - entry.spawnTime >= entry.lifetime then
                table.insert(toRemove, i)
            elseif DoesEntityExist(entry.ped) then
                local npcCoords = GetEntityCoords(entry.ped, true)
                local dist = #(playerCoords - npcCoords)

                if dist <= drawDist then
                    sleep = 0
                    local headZ = npcCoords.z + 1.1

                    -- Nome do usuario.
                    DrawText3D(npcCoords.x, npcCoords.y, headZ, entry.username, 0.45, 255, 255, 255, 255)

                    -- Nome do presente (menor, abaixo do nome).
                    if entry.giftName ~= '' then
                        DrawText3D(npcCoords.x, npcCoords.y, headZ - 0.15, '~y~' .. entry.giftName, 0.30, 255, 215, 0, 220)
                    end
                end
            else
                -- Entidade sumiu por algum motivo.
                table.insert(toRemove, i)
            end
        end

        -- Remover do fim para o inicio para nao baguncar indices.
        for j = #toRemove, 1, -1 do
            local idx = toRemove[j]
            local entry = activeNpcs[idx]

            if entry and DoesEntityExist(entry.ped) then
                DeleteEntity(entry.ped)
                Log(('NPC removido: user=%s'):format(entry.username))
            end

            table.remove(activeNpcs, idx)
        end

        Citizen.Wait(sleep)
    end
end)

-- ============================================================
-- Limpar todos os NPCs ao parar o resource.
-- ============================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= RESOURCE_NAME then return end

    for _, entry in ipairs(activeNpcs) do
        if DoesEntityExist(entry.ped) then
            DeleteEntity(entry.ped)
        end
    end

    activeNpcs = {}
    Log('Todos os NPCs removidos.')
end)
