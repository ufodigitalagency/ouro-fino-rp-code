-- =============================================================================
-- af_menino_porteira - client.lua
-- Spawn de multiplos monumentos "meninodaporteira" via script.
-- =============================================================================

local TAG = '[af_menino_porteira]'

local modelHash = nil
local monumentOrder = {}
local monumentsById = {}
local handlesById = {}

-- =============================================================================
-- Helpers
-- =============================================================================

local function Log(message)
    print(('%s %s'):format(TAG, tostring(message)))
end

local function Chat(message)
    TriggerEvent('chat:addMessage', {
        color = { 255, 210, 80 },
        args = { 'Menino da Porteira', tostring(message) }
    })
end

local function GetModelName()
    return tostring(Config.Model or 'meninodaporteira')
end

local function GetModelHash()
    if not modelHash then
        modelHash = GetHashKey(GetModelName())
    end

    return modelHash
end

local function NormalizeHeading(heading)
    heading = tonumber(heading) or 0.0
    heading = heading % 360.0

    if heading < 0.0 then
        heading = heading + 360.0
    end

    return heading
end

local function ToVector3(value)
    if type(value) == 'vector3' then
        return value
    end

    if type(value) == 'table' then
        return vector3(
            tonumber(value.x) or 0.0,
            tonumber(value.y) or 0.0,
            tonumber(value.z) or 0.0
        )
    end

    return vector3(0.0, 0.0, 0.0)
end

local function FormatNumber(value, decimals)
    decimals = decimals or 3
    return string.format('%.' .. tostring(decimals) .. 'f', tonumber(value) or 0.0)
end

local function SanitizeId(id)
    id = tostring(id or ''):lower()
    id = id:gsub('%s+', '_')
    id = id:gsub('[^%w_%-]', '')

    if id == '' then
        return nil
    end

    return id
end

local function WorldPosition(entry)
    local position = ToVector3(entry.position)
    local zOffset = tonumber(entry.zOffset) or 0.0

    return vector3(position.x, position.y, position.z + zOffset)
end

local function BuildConfigEntryLines(entry, indent)
    indent = indent or '    '

    local position = ToVector3(entry.position)
    local heading = NormalizeHeading(entry.heading)
    local zOffset = tonumber(entry.zOffset) or 0.0

    return {
        indent .. '{',
        indent .. ('    id = "%s",'):format(tostring(entry.id)),
        indent .. ('    enabled = %s,'):format(entry.enabled == false and 'false' or 'true'),
        indent .. ('    position = vector3(%s, %s, %s),'):format(
            FormatNumber(position.x, 3),
            FormatNumber(position.y, 3),
            FormatNumber(position.z, 3)
        ),
        indent .. ('    heading = %s,'):format(FormatNumber(heading, 2)),
        indent .. ('    zOffset = %s'):format(FormatNumber(zOffset, 3)),
        indent .. '},'
    }
end

local function PrintConfigEntry(entry, title)
    local lines = BuildConfigEntryLines(entry)

    Log(title or 'Cole esta entrada dentro de Config.Monuments:')

    for _, line in ipairs(lines) do
        Log(line)
    end

end

local function ListIds()
    if #monumentOrder == 0 then
        return '(nenhum)'
    end

    return table.concat(monumentOrder, ', ')
end

local function GetEntry(id)
    id = SanitizeId(id)

    if not id then
        return nil
    end

    return monumentsById[id]
end

local function RegisterRuntimeMonument(entry, replaceExisting)
    if type(entry) ~= 'table' then
        return nil
    end

    local id = SanitizeId(entry.id)

    if not id then
        Log('Ignorando monumento sem id valido.')
        return nil
    end

    if monumentsById[id] and not replaceExisting then
        Log(('ID duplicado ignorado em Config.Monuments: %s'):format(id))
        return monumentsById[id]
    end

    if monumentsById[id] and replaceExisting then
        local oldHandle = handlesById[id]

        if oldHandle and DoesEntityExist(oldHandle) then
            SetEntityAsMissionEntity(oldHandle, true, true)
            DeleteEntity(oldHandle)
        end

        handlesById[id] = nil
    end

    local normalized = {
        id = id,
        enabled = entry.enabled ~= false,
        position = ToVector3(entry.position),
        heading = NormalizeHeading(entry.heading),
        zOffset = tonumber(entry.zOffset) or 0.0
    }

    if not monumentsById[id] then
        monumentOrder[#monumentOrder + 1] = id
    end

    monumentsById[id] = normalized

    return normalized
end

local function LoadRuntimeMonuments()
    monumentOrder = {}
    monumentsById = {}
    handlesById = {}

    if type(Config.Monuments) == 'table' and #Config.Monuments > 0 then
        for _, entry in ipairs(Config.Monuments) do
            RegisterRuntimeMonument(entry, false)
        end

        return
    end

    -- Compatibilidade com config antiga de monumento unico.
    if Config.Position then
        RegisterRuntimeMonument({
            id = 'principal',
            enabled = Config.Enabled ~= false,
            position = Config.Position,
            heading = Config.Heading or 0.0,
            zOffset = Config.ZOffset or 0.0
        }, false)
    end
end

local function LoadModel(timeout)
    timeout = timeout or 30000

    local hash = GetModelHash()

    if not IsModelInCdimage(hash) or not IsModelValid(hash) then
        Log(('FALHA: modelo invalido ou fora do cdimage: %s hash=%s'):format(GetModelName(), tostring(hash)))
        return false
    end

    RequestModel(hash)

    local waited = 0

    while not HasModelLoaded(hash) and waited < timeout do
        Wait(250)
        waited = waited + 250

        if waited % 4000 == 0 then
            Log(('Aguardando modelo carregar... (%dms / %dms)'):format(waited, timeout))
            RequestModel(hash)
        end
    end

    if HasModelLoaded(hash) then
        return true
    end

    Log(('FALHA: modelo nao carregou apos %dms'):format(timeout))
    return false
end

local function DeleteMonument(id, silent)
    id = SanitizeId(id)

    if not id then
        return
    end

    local handle = handlesById[id]

    if handle and DoesEntityExist(handle) then
        SetEntityAsMissionEntity(handle, true, true)
        DeleteEntity(handle)

        if not silent then
            Log(('Monumento deletado: %s'):format(id))
        end
    end

    handlesById[id] = nil
end

local function DeleteAllMonuments(silent)
    for _, id in ipairs(monumentOrder) do
        DeleteMonument(id, true)
    end

    if not silent then
        Log('Todos os monumentos spawnados foram deletados.')
        Chat('Monumentos removidos.')
    end
end

local function SpawnMonument(id, forceRecreate)
    id = SanitizeId(id)

    local entry = id and monumentsById[id] or nil

    if not entry then
        Log(('Monumento nao encontrado: %s | ids: %s'):format(tostring(id), ListIds()))
        return false
    end

    if entry.enabled == false then
        Log(('Monumento desativado no config/runtime: %s'):format(id))
        return false
    end

    local oldHandle = handlesById[id]

    if oldHandle and DoesEntityExist(oldHandle) then
        if not forceRecreate then
            return true
        end

        DeleteMonument(id, true)
    else
        handlesById[id] = nil
    end

    if not LoadModel(30000) then
        return false
    end

    local pos = WorldPosition(entry)
    local hash = GetModelHash()
    local handle = CreateObject(hash, pos.x, pos.y, pos.z, false, false, false)

    if not handle or handle == 0 or not DoesEntityExist(handle) then
        Log(('FALHA ao criar monumento id=%s'):format(id))
        handlesById[id] = nil
        return false
    end

    SetEntityAsMissionEntity(handle, true, true)
    SetEntityHeading(handle, entry.heading)
    SetEntityCollision(handle, true, true)
    FreezeEntityPosition(handle, true)

    handlesById[id] = handle

    Log(('Spawnado id=%s handle=%s pos=%.3f %.3f %.3f heading=%.2f zOffset=%.3f'):format(
        id,
        tostring(handle),
        pos.x,
        pos.y,
        pos.z,
        entry.heading,
        entry.zOffset
    ))

    return true
end

local function SpawnAllEnabled(forceRecreate)
    local count = 0

    for _, id in ipairs(monumentOrder) do
        local entry = monumentsById[id]

        if entry and entry.enabled ~= false then
            if SpawnMonument(id, forceRecreate) then
                count = count + 1
            end
        end
    end

    Log(('Spawn/reload finalizado. Monumentos ativos: %d'):format(count))
    return count
end

local function GetPositionInFrontOfPlayer(distance)
    distance = tonumber(distance) or 3.0

    local ped = PlayerPedId()
    local coords = GetOffsetFromEntityInWorldCoords(ped, 0.0, distance, 0.0)
    local heading = GetEntityHeading(ped)

    return vector3(coords.x, coords.y, coords.z), heading
end

local function ApplyZOffset(id, zOffset)
    local entry = GetEntry(id)

    if not entry then
        Log(('Uso: /meninoz [id] [valor] | ids: %s'):format(ListIds()))
        return false
    end

    entry.zOffset = tonumber(zOffset) or 0.0

    local handle = handlesById[entry.id]

    if handle and DoesEntityExist(handle) then
        local pos = WorldPosition(entry)
        SetEntityCoords(handle, pos.x, pos.y, pos.z, false, false, false, false)
        FreezeEntityPosition(handle, true)
    elseif entry.enabled ~= false then
        SpawnMonument(entry.id, false)
    end

    Log(('zOffset ajustado id=%s zOffset=%.3f'):format(entry.id, entry.zOffset))
    PrintConfigEntry(entry, 'Entrada atualizada para Config.Monuments:')
    return true
end

local function ApplyHeading(id, heading)
    local entry = GetEntry(id)

    if not entry then
        Log(('Uso: /meninorot [id] [graus] | ids: %s'):format(ListIds()))
        return false
    end

    entry.heading = NormalizeHeading(heading)

    local handle = handlesById[entry.id]

    if handle and DoesEntityExist(handle) then
        SetEntityHeading(handle, entry.heading)
        FreezeEntityPosition(handle, true)
    elseif entry.enabled ~= false then
        SpawnMonument(entry.id, false)
    end

    Log(('Heading ajustado id=%s heading=%.2f'):format(entry.id, entry.heading))
    PrintConfigEntry(entry, 'Entrada atualizada para Config.Monuments:')
    return true
end

local function PrintAllConfigEntries()
    Log('=== Config.Monuments atual em runtime ===')
    Log('Config.Monuments = {')

    for _, id in ipairs(monumentOrder) do
        local entry = monumentsById[id]

        if entry then
            local lines = BuildConfigEntryLines(entry)

            for _, line in ipairs(lines) do
                Log(line)
            end
        end
    end

    Log('}')
end

-- =============================================================================
-- Auto-spawn
-- =============================================================================

LoadRuntimeMonuments()

CreateThread(function()
    Wait(3000)

    if not Config.UseScriptSpawn then
        Log('UseScriptSpawn = false. Monumentos NAO serao spawnados via script (esperando YMAP).')
        return
    end

    if #monumentOrder == 0 then
        Log('Nenhum monumento configurado em Config.Monuments.')
        return
    end

    SpawnAllEnabled(false)
end)

-- =============================================================================
-- Comandos mantidos
-- =============================================================================

RegisterCommand('testmenino', function()
    Log('=== /testmenino ===')
    SpawnAllEnabled(false)
end, false)

RegisterCommand('delmenino', function()
    Log('=== /delmenino ===')
    DeleteAllMonuments(false)
end, false)

RegisterCommand('meninomodel', function()
    local hash = GetModelHash()

    Log('=== /meninomodel ===')
    Log(('Nome:  %s'):format(GetModelName()))
    Log(('Hash:  %s'):format(tostring(hash)))
    Log(('IsModelInCdimage: %s'):format(tostring(IsModelInCdimage(hash))))
    Log(('IsModelValid:     %s'):format(tostring(IsModelValid(hash))))
    Log(('HasModelLoaded:   %s'):format(tostring(HasModelLoaded(hash))))

    if IsModelInCdimage(hash) and IsModelValid(hash) then
        LoadModel(30000)
        Log(('HasModelLoaded apos request: %s'):format(tostring(HasModelLoaded(hash))))
    end
end, false)

RegisterCommand('meninohash', function()
    Log('=== /meninohash ===')
    Log(('GetHashKey("%s"): %s'):format(GetModelName(), tostring(GetModelHash())))
end, false)

-- =============================================================================
-- Comandos de multiplos monumentos
-- =============================================================================

RegisterCommand('meninostatus', function()
    Log('=== /meninostatus ===')
    Log(('UseScriptSpawn: %s'):format(tostring(Config.UseScriptSpawn == true)))
    Log(('Model: %s | ids=%s'):format(GetModelName(), ListIds()))

    for _, id in ipairs(monumentOrder) do
        local entry = monumentsById[id]
        local handle = handlesById[id]
        local exists = handle and DoesEntityExist(handle) or false
        local pos = ToVector3(entry.position)

        Log(('id=%s enabled=%s exists=%s handle=%s pos=%.3f %.3f %.3f heading=%.2f zOffset=%.3f'):format(
            id,
            tostring(entry.enabled ~= false),
            tostring(exists),
            tostring(handle),
            pos.x,
            pos.y,
            pos.z,
            entry.heading,
            entry.zOffset
        ))
    end

    Chat(('UseScriptSpawn=%s | Monumentos: %d. Detalhes no F8.'):format(
        tostring(Config.UseScriptSpawn == true),
        #monumentOrder
    ))
end, false)

RegisterCommand('meninoreload', function()
    Log('=== /meninoreload ===')
    DeleteAllMonuments(true)
    local count = SpawnAllEnabled(true)
    Chat(('Monumentos recriados: %d'):format(count))
end, false)

RegisterCommand('meninolimpar', function()
    Log('=== /meninolimpar ===')
    DeleteAllMonuments(false)
end, false)

RegisterCommand('meninoadd', function(_, args)
    local id = SanitizeId(args[1])

    if not id then
        Log('Uso: /meninoadd [id]')
        Chat('Uso: /meninoadd nome_do_local')
        return
    end

    local position, heading = GetPositionInFrontOfPlayer(3.0)
    local entry = RegisterRuntimeMonument({
        id = id,
        enabled = true,
        position = position,
        heading = heading,
        zOffset = 0.0
    }, true)

    if not entry then
        return
    end

    SpawnMonument(entry.id, true)
    PrintConfigEntry(entry, 'Cole esta entrada dentro de Config.Monuments:')
    Chat(('Monumento temporario criado: %s. Copie a entrada do F8 para o config.'):format(entry.id))
end, false)

RegisterCommand('meninoz', function(_, args)
    local id = args[1]
    local value = tonumber(args[2])

    if not id or value == nil then
        Log(('Uso: /meninoz [id] [valor] | ids: %s'):format(ListIds()))
        Chat('Uso: /meninoz principal 0.25')
        return
    end

    if ApplyZOffset(id, value) then
        Chat(('Z ajustado para %s: %.3f'):format(SanitizeId(id), value))
    end
end, false)

RegisterCommand('meninorot', function(_, args)
    local id = args[1]
    local heading = tonumber(args[2])

    -- Compatibilidade leve com o formato antigo: /meninorot 195
    if id and not heading and tonumber(id) and #monumentOrder == 1 then
        heading = tonumber(id)
        id = monumentOrder[1]
    end

    if not id or heading == nil then
        Log(('Uso: /meninorot [id] [graus] | ids: %s'):format(ListIds()))
        Chat('Uso: /meninorot principal 195')
        return
    end

    if ApplyHeading(id, heading) then
        Chat(('Rotacao ajustada para %s: %.2f'):format(SanitizeId(id), NormalizeHeading(heading)))
    end
end, false)

RegisterCommand('meninosalvar', function()
    PrintAllConfigEntries()
    Chat('Config.Monuments atual foi impresso no F8.')
end, false)

-- Compatibilidade util com o fluxo anterior.
RegisterCommand('meninoaqui', function(_, args)
    local id = SanitizeId(args[1] or 'principal') or 'principal'
    local distance = tonumber(args[2]) or 3.0

    -- Compatibilidade com o formato antigo: /meninoaqui 3
    if args[1] and tonumber(args[1]) then
        id = 'principal'
        distance = tonumber(args[1]) or 3.0
    end

    local position, heading = GetPositionInFrontOfPlayer(distance)
    local entry = RegisterRuntimeMonument({
        id = id,
        enabled = true,
        position = position,
        heading = heading,
        zOffset = 0.0
    }, true)

    if entry then
        SpawnMonument(entry.id, true)
        PrintConfigEntry(entry, 'Entrada atualizada para Config.Monuments:')
        Chat(('Monumento reposicionado: %s'):format(entry.id))
    end
end, false)
