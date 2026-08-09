local Proxy = module('vrp','lib/Proxy')
local vRP = Proxy.getInterface('vRP')

local RESOURCE_NAME = GetCurrentResourceName()
local KVP_WORLD_STATE = 'world_screen_state_v1'
local worldDefaults = Config.WorldScreen or {}
local cropDefaults = Config.Crop or {}
local audioDefaults = Config.Audio or {}
local accessDefaults = Config.Access or {}
local OWNER_PASSPORT = tonumber(accessDefaults.ownerPassport) or 1

local rateLimits = {}

local function Log(message)
    print(('[af_youtube_tv] %s'):format(message))
end

local function NumberOr(value, fallback)
    local number = tonumber(value)
    if number == nil or number ~= number or number == math.huge or number == -math.huge then
        return fallback
    end

    return number
end

local function Clamp(value, minValue, maxValue)
    value = NumberOr(value, minValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function Trim(value)
    return tostring(value or ''):gsub('^%s+',''):gsub('%s+$','')
end

local function IsAllowedYoutubeHost(input)
    local candidate = tostring(input or ''):lower():gsub('^https?://',''):gsub('^//','')
    local host = candidate:match('^([^/%?#]+)')
    if not host then return false end
    host = host:gsub(':%d+$','')

    return host == 'youtube.com'
        or host == 'www.youtube.com'
        or host == 'm.youtube.com'
        or host == 'music.youtube.com'
        or host == 'youtu.be'
        or host == 'youtube-nocookie.com'
        or host == 'www.youtube-nocookie.com'
end

local function ExtractYoutubeId(input)
    input = Trim(input)
    if input == '' or #input > 256 then return nil end

    if input:match('^[%w_-]+$') and #input == 11 then
        return input
    end

    if not IsAllowedYoutubeHost(input) then return nil end

    local patterns = {
        '[?&]v=([%w_-]+)',
        'youtu%.be/([%w_-]+)',
        'youtube%.com/embed/([%w_-]+)',
        'youtube%-nocookie%.com/embed/([%w_-]+)',
        'youtube%.com/live/([%w_-]+)',
        'youtube%.com/shorts/([%w_-]+)'
    }

    for _,pattern in ipairs(patterns) do
        local videoId = input:match(pattern)
        if videoId and #videoId == 11 then
            return videoId
        end
    end

    return nil
end

local function IsOwner(sourceId)
    sourceId = tonumber(sourceId) or 0
    if sourceId == 0 then return true, 0 end

    local passport = vRP.Passport(sourceId)
    if passport and tonumber(passport) == OWNER_PASSPORT then
        return true, tonumber(passport)
    end

    return false, tonumber(passport)
end

local function BuildDefaultWorldState()
    return {
        enabled = worldDefaults.enabled == true,
        url = ExtractYoutubeId(worldDefaults.url or Config.DefaultUrl) or tostring(Config.DefaultUrl or ''),
        x = NumberOr(worldDefaults.x,215.0),
        y = NumberOr(worldDefaults.y,-920.0),
        z = NumberOr(worldDefaults.z,34.0),
        heading = NumberOr(worldDefaults.heading,180.0),
        width = NumberOr(worldDefaults.width,9.6),
        height = NumberOr(worldDefaults.height,5.4),
        drawDistance = NumberOr(worldDefaults.drawDistance,120.0),
        baseVolume = NumberOr(worldDefaults.baseVolume,NumberOr(worldDefaults.volume,70.0)),
        audioEnabled = worldDefaults.audioEnabled ~= false and audioDefaults.enabled ~= false,
        maxAudioDistance = NumberOr(
            worldDefaults.maxAudioDistance,
            NumberOr(worldDefaults.audioRange,NumberOr(audioDefaults.maximumDistance,55.0))
        ),
        innerAudioRadius = NumberOr(worldDefaults.innerAudioRadius,NumberOr(audioDefaults.innerRadius,4.0)),
        falloffExponent = NumberOr(worldDefaults.falloffExponent,NumberOr(audioDefaults.falloffExponent,1.6)),
        fadeInTime = NumberOr(worldDefaults.fadeInTime,NumberOr(audioDefaults.fadeInTime,0.8)),
        fadeOutTime = NumberOr(worldDefaults.fadeOutTime,NumberOr(audioDefaults.fadeOutTime,1.2)),
        occlusionEnabled = worldDefaults.occlusionEnabled ~= false and audioDefaults.occlusionEnabled ~= false,
        flipX = worldDefaults.flipX == true,
        flipY = worldDefaults.flipY == true,
        crop = {
            x = NumberOr(worldDefaults.cropX,NumberOr(cropDefaults.x,0.02)),
            y = NumberOr(worldDefaults.cropY,NumberOr(cropDefaults.y,0.06)),
            w = NumberOr(worldDefaults.cropWidth,NumberOr(cropDefaults.width,0.85)),
            h = NumberOr(worldDefaults.cropHeight,NumberOr(cropDefaults.height,0.75))
        },
        playbackState = 'stopped',
        startedAt = 0,
        pausedAt = 0,
        revision = 0,
        lastAction = 'init',
        lastOperator = 0,
        lastChangedAt = 0
    }
end

local worldState = BuildDefaultWorldState()

local function NormalizeHeading(value)
    value = NumberOr(value,worldState.heading) % 360.0
    if value < 0.0 then value = value + 360.0 end
    return value
end

local function ClampWorldState()
    local maximumCoordinate = NumberOr(accessDefaults.maximumCoordinate,10000.0)
    worldState.x = Clamp(worldState.x,-maximumCoordinate,maximumCoordinate)
    worldState.y = Clamp(worldState.y,-maximumCoordinate,maximumCoordinate)
    worldState.z = Clamp(worldState.z,NumberOr(accessDefaults.minimumZ,-500.0),NumberOr(accessDefaults.maximumZ,2000.0))
    worldState.heading = NormalizeHeading(worldState.heading)
    worldState.width = Clamp(worldState.width,0.5,80.0)
    worldState.height = Clamp(worldState.height,0.5,45.0)
    worldState.drawDistance = Clamp(worldState.drawDistance,5.0,500.0)
    worldState.baseVolume = Clamp(worldState.baseVolume,0.0,100.0)
    worldState.maxAudioDistance = Clamp(
        worldState.maxAudioDistance,
        NumberOr(audioDefaults.minimumDistance,5.0),
        NumberOr(audioDefaults.maximumAllowedDistance,150.0)
    )
    worldState.innerAudioRadius = Clamp(
        worldState.innerAudioRadius,
        0.0,
        math.max(worldState.maxAudioDistance - 0.1,0.0)
    )
    worldState.falloffExponent = Clamp(worldState.falloffExponent,0.25,4.0)
    worldState.fadeInTime = Clamp(worldState.fadeInTime,0.05,10.0)
    worldState.fadeOutTime = Clamp(worldState.fadeOutTime,0.05,10.0)
    worldState.audioEnabled = worldState.audioEnabled == true
    worldState.occlusionEnabled = worldState.occlusionEnabled == true
    worldState.crop.w = Clamp(worldState.crop.w,0.02,1.0)
    worldState.crop.h = Clamp(worldState.crop.h,0.02,1.0)
    worldState.crop.x = Clamp(worldState.crop.x,0.0,1.0 - worldState.crop.w)
    worldState.crop.y = Clamp(worldState.crop.y,0.0,1.0 - worldState.crop.h)
end

local function GetPlaybackSeconds()
    if worldState.playbackState == 'paused' then
        return math.max(NumberOr(worldState.pausedAt,0),0)
    end

    if worldState.playbackState == 'playing' and NumberOr(worldState.startedAt,0) > 0 then
        return math.max(os.time() - worldState.startedAt,0)
    end

    return 0
end

local function BuildSnapshot(includeSensitive)
    local snapshot = {
        enabled = worldState.enabled,
        url = worldState.url,
        x = worldState.x,
        y = worldState.y,
        z = worldState.z,
        heading = worldState.heading,
        width = worldState.width,
        height = worldState.height,
        drawDistance = worldState.drawDistance,
        baseVolume = worldState.baseVolume,
        -- Aliases temporarios preservam compatibilidade com clients antigos.
        volume = worldState.baseVolume,
        audioEnabled = worldState.audioEnabled,
        maxAudioDistance = worldState.maxAudioDistance,
        audioRange = worldState.maxAudioDistance,
        innerAudioRadius = worldState.innerAudioRadius,
        falloffExponent = worldState.falloffExponent,
        fadeInTime = worldState.fadeInTime,
        fadeOutTime = worldState.fadeOutTime,
        occlusionEnabled = worldState.occlusionEnabled,
        flipX = worldState.flipX,
        flipY = worldState.flipY,
        crop = {
            x = worldState.crop.x,
            y = worldState.crop.y,
            w = worldState.crop.w,
            h = worldState.crop.h
        },
        playbackState = worldState.playbackState,
        playbackSeconds = GetPlaybackSeconds(),
        revision = worldState.revision,
        lastAction = worldState.lastAction,
        serverTime = os.time()
    }

    if includeSensitive then
        snapshot.lastOperator = worldState.lastOperator
        snapshot.lastChangedAt = worldState.lastChangedAt
    end

    return snapshot
end

local function LoadSavedWorldState()
    if worldDefaults.persist == false or not GetResourceKvpString or not json or not json.decode then return end
    local raw = GetResourceKvpString(KVP_WORLD_STATE)
    if not raw or raw == '' then return end

    local ok,saved = pcall(json.decode,raw)
    if not ok or type(saved) ~= 'table' then return end

    local fields = {
        'x','y','z','heading','width','height','drawDistance','baseVolume',
        'maxAudioDistance','innerAudioRadius','falloffExponent','fadeInTime','fadeOutTime'
    }
    for _,field in ipairs(fields) do
        if saved[field] ~= nil then worldState[field] = NumberOr(saved[field],worldState[field]) end
    end

    -- Migra silenciosamente o KVP legado sem alterar as chaves persistidas das demais opcoes.
    if saved.baseVolume == nil and saved.volume ~= nil then
        worldState.baseVolume = NumberOr(saved.volume,worldState.baseVolume)
    end
    if saved.maxAudioDistance == nil and saved.audioRange ~= nil then
        worldState.maxAudioDistance = NumberOr(saved.audioRange,worldState.maxAudioDistance)
    end

    local savedVideoId = ExtractYoutubeId(saved.url)
    if savedVideoId then worldState.url = savedVideoId end
    if saved.flipX ~= nil then worldState.flipX = saved.flipX == true end
    if saved.flipY ~= nil then worldState.flipY = saved.flipY == true end
    if saved.audioEnabled ~= nil then worldState.audioEnabled = saved.audioEnabled == true end
    if saved.occlusionEnabled ~= nil then worldState.occlusionEnabled = saved.occlusionEnabled == true end

    if type(saved.crop) == 'table' then
        worldState.crop.x = NumberOr(saved.crop.x,worldState.crop.x)
        worldState.crop.y = NumberOr(saved.crop.y,worldState.crop.y)
        worldState.crop.w = NumberOr(saved.crop.w or saved.crop.width,worldState.crop.w)
        worldState.crop.h = NumberOr(saved.crop.h or saved.crop.height,worldState.crop.h)
    end

    Log('Estado salvo do telao carregado.')
end

local function SaveWorldState()
    if worldDefaults.persist == false or not SetResourceKvp or not json or not json.encode then return false end
    SetResourceKvp(KVP_WORLD_STATE,json.encode(BuildSnapshot(true)))
    return true
end

local function SendWorldState(target)
    local snapshot = BuildSnapshot(false)
    if tonumber(target) and tonumber(target) > 0 then
        snapshot.owner = IsOwner(target)
    end
    TriggerClientEvent('af_youtube_tv:worldState',target,snapshot)
end

local function UpdateGlobalState()
    GlobalState.AfYoutubeTvVolume = math.floor(worldState.baseVolume + 0.5)
    GlobalState.AfYoutubeTvEnabled = worldState.enabled
    GlobalState.AfYoutubeTvState = BuildSnapshot(false)
end

local function BroadcastWorldState()
    TriggerClientEvent('af_youtube_tv:worldState',-1,BuildSnapshot(false))
end

local function ApplyWorldGeometry(payload)
    if type(payload) ~= 'table' then return end
    local numericFields = { 'x','y','z','heading','width','height','drawDistance' }
    for _,field in ipairs(numericFields) do
        if payload[field] ~= nil then
            worldState[field] = NumberOr(payload[field],worldState[field])
        end
    end

    if payload.flipX ~= nil then worldState.flipX = payload.flipX == true end
    if payload.flipY ~= nil then worldState.flipY = payload.flipY == true end
end

local function ApplyWorldCrop(payload)
    if type(payload) ~= 'table' then return end
    local sourceCrop = type(payload.crop) == 'table' and payload.crop or payload
    worldState.crop.w = NumberOr(sourceCrop.w or sourceCrop.width,worldState.crop.w)
    worldState.crop.h = NumberOr(sourceCrop.h or sourceCrop.height,worldState.crop.h)
    worldState.crop.x = NumberOr(sourceCrop.x,worldState.crop.x)
    worldState.crop.y = NumberOr(sourceCrop.y,worldState.crop.y)
end

local function StartPlayback(resetTime)
    local seconds = resetTime and 0 or GetPlaybackSeconds()
    worldState.startedAt = os.time() - math.floor(seconds)
    worldState.pausedAt = 0
    worldState.playbackState = 'playing'
end

local function ApplyWorldUpdate(action,payload)
    action = tostring(action or ''):lower()
    payload = type(payload) == 'table' and payload or {}

    if action == 'on' or action == 'url' then
        local requested = payload.url and Trim(payload.url) or ''
        local videoId = requested ~= '' and ExtractYoutubeId(requested) or ExtractYoutubeId(worldState.url)
        if not videoId then return false,'Informe um link ou ID valido do YouTube.' end

        local changed = worldState.url ~= videoId
        worldState.url = videoId
        worldState.enabled = true
        ApplyWorldGeometry(payload)
        ApplyWorldCrop(payload)
        ClampWorldState()
        StartPlayback(changed or worldState.playbackState == 'stopped')
        return true,changed and 'Video carregado no telao.' or 'Telao ligado.'
    end

    if action == 'off' then
        worldState.enabled = false
        worldState.playbackState = 'stopped'
        worldState.startedAt = 0
        worldState.pausedAt = 0
        return true,'Telao desligado.'
    end

    if action == 'pause' then
        if not worldState.enabled then return false,'O telao esta desligado.' end
        if worldState.playbackState == 'playing' then
            worldState.pausedAt = GetPlaybackSeconds()
            worldState.playbackState = 'paused'
        end
        return true,'Video pausado.'
    end

    if action == 'resume' or action == 'play' then
        if not worldState.enabled then return false,'O telao esta desligado.' end
        StartPlayback(false)
        return true,'Video retomado.'
    end

    if action == 'reload' or action == 'sync' then
        if not worldState.enabled then return false,'O telao esta desligado.' end
        return true,action == 'reload' and 'Player recarregado e sincronizado.' or 'Sincronizacao enviada.'
    end

    if action == 'set' or action == 'save' then
        ApplyWorldGeometry(payload)
        ApplyWorldCrop(payload)
        if payload.url and Trim(payload.url) ~= '' then
            local videoId = ExtractYoutubeId(payload.url)
            if not videoId then return false,'Link do YouTube invalido.' end
            worldState.url = videoId
        end
        if payload.enabled ~= nil then worldState.enabled = payload.enabled == true end
        ClampWorldState()
        if action == 'save' then
            if not SaveWorldState() then return false,'Nao foi possivel salvar o telao em KVP.' end
            return true,'Configuracao do telao salva.'
        end
        return true,'Telao atualizado.'
    end

    if action == 'crop' then
        ApplyWorldCrop(payload)
        ClampWorldState()
        return true,'Recorte do telao atualizado.'
    end

    if action == 'setbasevolume' or action == 'volume' then
        worldState.baseVolume = Clamp(payload.baseVolume or payload.volume,0.0,100.0)
        return true,('Volume geral definido em %.0f%%.'):format(worldState.baseVolume)
    end

    if action == 'setmaxaudiodistance' or action == 'range' or action == 'alcance' then
        worldState.maxAudioDistance = NumberOr(
            payload.maxAudioDistance or payload.audioRange or payload.range,
            worldState.maxAudioDistance
        )
        ClampWorldState()
        return true,('Alcance do audio definido em %.0f metros.'):format(worldState.maxAudioDistance)
    end

    if action == 'setinneraudioradius' then
        worldState.innerAudioRadius = NumberOr(payload.innerAudioRadius,worldState.innerAudioRadius)
        ClampWorldState()
        return true,('Raio de volume maximo definido em %.1f metros.'):format(worldState.innerAudioRadius)
    end

    if action == 'setaudiofalloff' then
        worldState.falloffExponent = NumberOr(payload.falloffExponent,worldState.falloffExponent)
        ClampWorldState()
        return true,('Suavidade da distancia definida em %.2f.'):format(worldState.falloffExponent)
    end

    if action == 'setaudiofade' then
        worldState.fadeInTime = NumberOr(payload.fadeInTime,worldState.fadeInTime)
        worldState.fadeOutTime = NumberOr(payload.fadeOutTime,worldState.fadeOutTime)
        ClampWorldState()
        return true,'Tempos de fade do audio atualizados.'
    end

    if action == 'setaudioenabled' or action == 'audio' or action == 'sound' then
        worldState.audioEnabled = payload.enabled == true or payload.audioEnabled == true
        return true,worldState.audioEnabled and 'Audio de proximidade ligado.' or 'Audio de proximidade desligado.'
    end

    if action == 'setocclusion' or action == 'occlusion' then
        worldState.occlusionEnabled = payload.enabled == true or payload.occlusionEnabled == true
        return true,worldState.occlusionEnabled and 'Obstrucao de audio ligada.' or 'Obstrucao de audio desligada.'
    end

    if action == 'reset' then
        worldState = BuildDefaultWorldState()
        worldState.enabled = false
        DeleteResourceKvp(KVP_WORLD_STATE)
        ClampWorldState()
        return true,'Telao resetado para o config.lua.'
    end

    return false,'Acao invalida.'
end

local function RateLimitFor(action)
    if action == 'url' or action == 'on' then
        return NumberOr(accessDefaults.urlRateLimitMs,1500)
    end
    if action == 'set' or action == 'crop' then
        return NumberOr(accessDefaults.editRateLimitMs,75)
    end
    return NumberOr(accessDefaults.rateLimitMs,250)
end

local function IsRateLimited(sourceId,action)
    if sourceId == 0 then return false end
    local now = GetGameTimer()
    local key = ('%s:%s'):format(sourceId,action)
    local allowedAt = rateLimits[key] or 0
    if now < allowedAt then return true end
    rateLimits[key] = now + RateLimitFor(action)
    return false
end

local function ProcessOwnerAction(sourceId,action,payload)
    sourceId = tonumber(sourceId) or 0
    action = tostring(action or ''):lower()
    local allowed,passport = IsOwner(sourceId)
    if not allowed then
        Log(('blocked source=%s passport=%s action=%s'):format(sourceId,tostring(passport),action))
        if sourceId > 0 then
            TriggerClientEvent('af_youtube_tv:worldMessage',sourceId,'Voce nao possui permissao para controlar o telao.')
        end
        return false
    end

    if IsRateLimited(sourceId,action) then
        return false
    end

    local ok,message = ApplyWorldUpdate(action,payload)
    if not ok then
        if sourceId > 0 then TriggerClientEvent('af_youtube_tv:worldMessage',sourceId,message) end
        return false
    end

    worldState.revision = (tonumber(worldState.revision) or 0) + 1
    worldState.lastAction = action
    worldState.lastOperator = passport or 0
    worldState.lastChangedAt = os.time()
    ClampWorldState()
    UpdateGlobalState()
    BroadcastWorldState()

    local silent = type(payload) == 'table' and payload.silent == true
    if sourceId > 0 and not silent then
        TriggerClientEvent('af_youtube_tv:worldMessage',sourceId,message)
    end

    Log(('owner=%s source=%s action=%s video=%s enabled=%s baseVolume=%.0f maxAudioDistance=%.0f playback=%s'):format(
        tostring(passport),sourceId,action,tostring(worldState.url),tostring(worldState.enabled),
        worldState.baseVolume,worldState.maxAudioDistance,worldState.playbackState
    ))
    return true
end

LoadSavedWorldState()
if worldDefaults.startDisabled ~= false then
    worldState.enabled = false
    worldState.playbackState = 'stopped'
end
ClampWorldState()
UpdateGlobalState()

RegisterNetEvent('af_youtube_tv:requestState',function()
    local sourceId = tonumber(source)
    if not sourceId or sourceId <= 0 then return end
    TriggerClientEvent('af_youtube_tv:syncState',sourceId,{
        url = Config.DefaultUrl,
        autoplay = Config.Autoplay,
        muted = Config.Muted,
        loop = Config.Loop
    })
end)

RegisterNetEvent('af_youtube_tv:requestWorldState',function()
    local sourceId = tonumber(source)
    if not sourceId or sourceId <= 0 then return end
    SendWorldState(sourceId)
end)

RegisterNetEvent('af_youtube_tv:updateWorldState',function(action,payload)
    ProcessOwnerAction(source,action,payload)
end)

-- Evento apenas server-side usado pelo painel. O source real continua sendo
-- validado aqui; o painel nao recebe uma rota privilegiada sem verificacao.
AddEventHandler('af_youtube_tv:serverAction',function(actorSource,action,payload)
    ProcessOwnerAction(actorSource,action,payload)
end)

AddEventHandler('playerDropped',function()
    local sourceId = tonumber(source)
    if not sourceId then return end
    for key in pairs(rateLimits) do
        if key:match('^'..sourceId..':') then rateLimits[key] = nil end
    end
end)

exports('GetState',function()
    return BuildSnapshot(true)
end)

exports('IsOwner',function(sourceId)
    return IsOwner(sourceId)
end)

AddEventHandler('onResourceStart',function(resourceName)
    if resourceName == RESOURCE_NAME then Log('server.lua carregado com controle exclusivo do dono.') end
end)

AddEventHandler('onResourceStop',function(resourceName)
    if resourceName == RESOURCE_NAME then Log('Server parado.') end
end)
