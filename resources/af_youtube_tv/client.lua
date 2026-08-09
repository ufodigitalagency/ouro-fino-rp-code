local RESOURCE_NAME = GetCurrentResourceName()
local TXD_NAME = 'af_youtube_tv_txd'
local TXN_NAME = 'screen'
local WORLD_TXD_NAME = 'af_youtube_tv_world_txd'
local WORLD_TXN_NAME = 'screen'

local duiObject = nil
local duiHandle = nil
local runtimeTxd = nil
local runtimeTexture = nil
local tvOn = false
local drawThreadActive = false
local currentUrl = Config.DefaultUrl

local worldDuiObject = nil
local worldDuiHandle = nil
local worldRuntimeTxd = nil
local worldRuntimeTexture = nil
local worldDuiUrl = nil
local worldDrawThreadActive = false
local worldDuiVideoId = nil
local worldPlayerReady = false
local ownerAuthorized = false
local lastAppliedWorldVolume = -1
local currentEffectiveVolume = 0.0
local targetEffectiveVolume = 0.0
local lastVolumeUpdateAt = GetGameTimer()
local lastVolumeSentAt = 0
local audioDebugEnabled = (Config.Audio or {}).debug == true
local audioSimulatedDistance = nil
local audioEnvironment = {
    nextCheckAt = 0,
    occluded = false,
    differentInterior = false
}
local audioDiagnostics = {
    effectiveVolume = 0,
    targetVolume = 0,
    distance = 0.0,
    distanceFactor = 0.0,
    occlusionFactor = 1.0,
    interiorFactor = 1.0,
    occluded = false,
    differentInterior = false
}

local cropDefaults = Config.Crop or {}
local worldDefaults = Config.WorldScreen or {}

local crop = {
    x = cropDefaults.x or 0.02,
    y = cropDefaults.y or 0.06,
    w = cropDefaults.width or 0.85,
    h = cropDefaults.height or 0.75
}

local screen = {
    x = cropDefaults.screenX or 0.5,
    y = cropDefaults.screenY or 0.5,
    w = cropDefaults.screenWidth or 0.75,
    h = cropDefaults.screenHeight or 0.421875
}

local worldState = {
    enabled = worldDefaults.enabled == true,
    url = worldDefaults.url or Config.DefaultUrl,
    x = worldDefaults.x or 215.0,
    y = worldDefaults.y or -920.0,
    z = worldDefaults.z or 34.0,
    heading = worldDefaults.heading or 180.0,
    width = worldDefaults.width or 9.6,
    height = worldDefaults.height or 5.4,
    drawDistance = worldDefaults.drawDistance or 120.0,
    baseVolume = worldDefaults.baseVolume or worldDefaults.volume or 70,
    audioEnabled = worldDefaults.audioEnabled ~= false,
    maxAudioDistance = worldDefaults.maxAudioDistance or worldDefaults.audioRange or ((Config.Audio or {}).maximumDistance or 55.0),
    innerAudioRadius = worldDefaults.innerAudioRadius or ((Config.Audio or {}).innerRadius or 4.0),
    falloffExponent = worldDefaults.falloffExponent or ((Config.Audio or {}).falloffExponent or 1.6),
    fadeInTime = worldDefaults.fadeInTime or ((Config.Audio or {}).fadeInTime or 0.8),
    fadeOutTime = worldDefaults.fadeOutTime or ((Config.Audio or {}).fadeOutTime or 1.2),
    occlusionEnabled = worldDefaults.occlusionEnabled ~= false,
    playbackState = 'stopped',
    playbackSeconds = 0,
    revision = 0,
    lastAction = 'init',
    flipX = worldDefaults.flipX == true,
    flipY = worldDefaults.flipY == true,
    crop = {
        x = worldDefaults.cropX or cropDefaults.x or 0.02,
        y = worldDefaults.cropY or cropDefaults.y or 0.06,
        w = worldDefaults.cropWidth or cropDefaults.width or 0.85,
        h = worldDefaults.cropHeight or cropDefaults.height or 0.75
    }
}

local editMode = false
local editTarget = 'crop'
local editStep = cropDefaults.step or 0.005
local editFastStep = cropDefaults.fastStep or 0.02
local worldEditMode = false
local worldEditTarget = 'pos'
local worldEditStep = worldDefaults.editStep or 0.05
local worldEditFastStep = worldDefaults.editFastStep or 0.25
local worldRotationStep = worldDefaults.rotationStep or 1.0
local worldRotationFastStep = worldDefaults.rotationFastStep or 5.0
local worldCropStep = worldDefaults.cropStep or cropDefaults.step or 0.005
local worldCropFastStep = worldDefaults.cropFastStep or cropDefaults.fastStep or 0.02
local worldSyncPending = false
local worldNextSyncAt = 0
local drawUvMode = nil
local drawPolyMode = nil
local worldPolyMode = nil
local drawMode = tostring(cropDefaults.drawMode or 'uv'):lower()
local validDrawModes = {
    uv = true,
    mask = true,
    poly = true
}

if not validDrawModes[drawMode] then
    drawMode = 'uv'
end

local held = {
    left = false,
    right = false,
    up = false,
    down = false,
    shrinkW = false,
    growW = false,
    shrinkH = false,
    growH = false
}

local function Log(message)
    if Config.DebugLogs then
        print(('[af_youtube_tv] %s'):format(message))
    end
end

local function Chat(message)
    if Config.ShowChatMessages then
        TriggerEvent('chat:addMessage', {
            color = { 80, 180, 255 },
            args = { 'YouTube TV', message }
        })
    end
end

local function Clamp(value, minValue, maxValue)
    value = tonumber(value) or minValue

    if value < minValue then
        return minValue
    end

    if value > maxValue then
        return maxValue
    end

    return value
end

local function UrlEncode(value)
    value = tostring(value or '')
    value = value:gsub('\n', '\r\n')
    value = value:gsub('([^%w%-_%.~])', function(char)
        return string.format('%%%02X', string.byte(char))
    end)
    return value
end

local function BoolParam(value)
    return value and '1' or '0'
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
    input = tostring(input or ''):gsub('^%s+', ''):gsub('%s+$', '')

    if input == '' then
        return nil
    end

    if input:match('^[a-zA-Z0-9_-]+$') and #input == 11 then
        return input
    end

    if not IsAllowedYoutubeHost(input) then return nil end

    local patterns = {
        'v=([a-zA-Z0-9_-]+)',
        'youtu%.be/([a-zA-Z0-9_-]+)',
        'youtube%.com/embed/([a-zA-Z0-9_-]+)',
        'youtube%-nocookie%.com/embed/([a-zA-Z0-9_-]+)',
        'youtube%.com/live/([a-zA-Z0-9_-]+)',
        'youtube%.com/shorts/([a-zA-Z0-9_-]+)'
    }

    for _, pattern in ipairs(patterns) do
        local id = input:match(pattern)
        if id then
            return id
        end
    end

    return nil
end

-- Mantem compatibilidade com trechos antigos.
extractYoutubeId = ExtractYoutubeId

local defaultVideoId = ExtractYoutubeId(Config.DefaultUrl)

local function BuildLocalPlayerUrl(videoId, channel)
    local resourceHost = RESOURCE_NAME
    local isWorld = (channel or 'world') == 'world'
    local initialVolume = isWorld and 0 or math.floor((tonumber(worldState.baseVolume) or 70) + 0.5)
    local initialMuted = isWorld or Config.Muted == true
    return ('https://cfx-nui-%s/html/index.html?url=%s&mode=embed&autoplay=1&muted=%s&loop=%s&volume=%s&channel=%s'):format(
        resourceHost,
        UrlEncode(videoId),
        BoolParam(initialMuted),
        BoolParam(Config.Loop),
        initialVolume,
        UrlEncode(channel or 'world')
    )
end

local function ClampCrop()
    crop.w = Clamp(crop.w, 0.02, 1.0)
    crop.h = Clamp(crop.h, 0.02, 1.0)
    crop.x = Clamp(crop.x, 0.0, 1.0 - crop.w)
    crop.y = Clamp(crop.y, 0.0, 1.0 - crop.h)
end

local function ClampScreen()
    screen.w = Clamp(screen.w, 0.05, 1.5)
    screen.h = Clamp(screen.h, 0.05, 1.5)
    screen.x = Clamp(screen.x, -0.25, 1.25)
    screen.y = Clamp(screen.y, -0.25, 1.25)
end

local function SetCrop(x, y, w, h)
    crop.x = tonumber(x) or crop.x
    crop.y = tonumber(y) or crop.y
    crop.w = tonumber(w) or crop.w
    crop.h = tonumber(h) or crop.h
    ClampCrop()
end

local function SetScreen(x, y, w, h)
    screen.x = tonumber(x) or screen.x
    screen.y = tonumber(y) or screen.y
    screen.w = tonumber(w) or screen.w
    screen.h = tonumber(h) or screen.h
    ClampScreen()
end

local function ResetCrop()
    crop.x = cropDefaults.x or 0.02
    crop.y = cropDefaults.y or 0.06
    crop.w = cropDefaults.width or 0.85
    crop.h = cropDefaults.height or 0.75
    ClampCrop()
end

local function ResetScreen()
    screen.x = cropDefaults.screenX or 0.5
    screen.y = cropDefaults.screenY or 0.5
    screen.w = cropDefaults.screenWidth or 0.75
    screen.h = cropDefaults.screenHeight or 0.421875
    ClampScreen()
end

local function ResetAllCropSettings()
    ResetCrop()
    ResetScreen()
end

local function SetDrawMode(mode, silent)
    mode = tostring(mode or ''):lower()

    if not validDrawModes[mode] then
        return false
    end

    drawMode = mode

    if drawMode == 'uv' then
        drawUvMode = nil
    elseif drawMode == 'poly' then
        drawPolyMode = nil
    end

    if not silent then
        Chat(('Render do crop: %s'):format(drawMode))
    end

    return true
end

local function NormalizeHeading(value)
    value = tonumber(value) or 0.0
    value = value % 360.0

    if value < 0.0 then
        value = value + 360.0
    end

    return value
end

local function ClampWorldCrop(targetCrop)
    targetCrop.w = Clamp(targetCrop.w, 0.02, 1.0)
    targetCrop.h = Clamp(targetCrop.h, 0.02, 1.0)
    targetCrop.x = Clamp(targetCrop.x, 0.0, 1.0 - targetCrop.w)
    targetCrop.y = Clamp(targetCrop.y, 0.0, 1.0 - targetCrop.h)
end

local function ClampWorldState()
    local audioConfig = Config.Audio or {}
    worldState.width = Clamp(worldState.width, 0.5, 80.0)
    worldState.height = Clamp(worldState.height, 0.5, 45.0)
    worldState.drawDistance = Clamp(worldState.drawDistance, 5.0, 500.0)
    worldState.baseVolume = Clamp(worldState.baseVolume, 0.0, 100.0)
    worldState.maxAudioDistance = Clamp(
        worldState.maxAudioDistance,
        tonumber(audioConfig.minimumDistance) or 5.0,
        tonumber(audioConfig.maximumAllowedDistance) or 150.0
    )
    worldState.innerAudioRadius = Clamp(
        worldState.innerAudioRadius,
        0.0,
        math.max(worldState.maxAudioDistance - 0.1,0.0)
    )
    worldState.falloffExponent = Clamp(worldState.falloffExponent,0.25,4.0)
    worldState.fadeInTime = Clamp(worldState.fadeInTime,0.05,10.0)
    worldState.fadeOutTime = Clamp(worldState.fadeOutTime,0.05,10.0)
    worldState.heading = NormalizeHeading(worldState.heading)
    worldState.crop = worldState.crop or {
        x = worldDefaults.cropX or cropDefaults.x or 0.02,
        y = worldDefaults.cropY or cropDefaults.y or 0.06,
        w = worldDefaults.cropWidth or cropDefaults.width or 0.85,
        h = worldDefaults.cropHeight or cropDefaults.height or 0.75
    }
    ClampWorldCrop(worldState.crop)
end

local function SendWorldDuiCommand(payload)
    if not worldDuiObject or not SendDuiMessage or not json or not json.encode then
        return false
    end

    local ok = pcall(function()
        SendDuiMessage(worldDuiObject,json.encode(payload))
    end)
    return ok
end

local function WorldScreenDistance()
    if audioSimulatedDistance ~= nil then
        return audioSimulatedDistance
    end

    local coords = GetEntityCoords(PlayerPedId())
    local dx = coords.x - worldState.x
    local dy = coords.y - worldState.y
    local dz = coords.z - worldState.z
    return math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
end

local function IsWorldAudioOccluded(ped)
    if worldState.occlusionEnabled ~= true or (Config.Audio or {}).occlusionEnabled == false then
        return false
    end

    if not StartExpensiveSynchronousShapeTestLosProbe then
        return false
    end

    local origin = GetPedBoneCoords(ped,31086,0.0,0.0,0.0)
    local handle = StartExpensiveSynchronousShapeTestLosProbe(
        origin.x,origin.y,origin.z,
        worldState.x,worldState.y,worldState.z,
        273,ped,7
    )
    local _,hit,hitCoords = GetShapeTestResult(handle)
    if hit ~= 1 or not hitCoords then return false end

    local totalDx = worldState.x - origin.x
    local totalDy = worldState.y - origin.y
    local totalDz = worldState.z - origin.z
    local totalDistance = math.sqrt((totalDx * totalDx) + (totalDy * totalDy) + (totalDz * totalDz))
    local hitDx = hitCoords.x - origin.x
    local hitDy = hitCoords.y - origin.y
    local hitDz = hitCoords.z - origin.z
    local hitDistance = math.sqrt((hitDx * hitDx) + (hitDy * hitDy) + (hitDz * hitDz))

    -- Ignora a parede/moldura exatamente no ponto do telao.
    return hitDistance < math.max(totalDistance - 1.0,0.0)
end

local function IsDifferentInterior(ped)
    local playerInterior = GetInteriorFromEntity(ped)
    local screenInterior = GetInteriorAtCoords(worldState.x,worldState.y,worldState.z)
    return playerInterior ~= 0 and screenInterior ~= 0 and playerInterior ~= screenInterior
end

local function RefreshAudioEnvironment(ped,multiplier)
    local now = GetGameTimer()
    if now < audioEnvironment.nextCheckAt then return end

    audioEnvironment.nextCheckAt = now + (tonumber((Config.Audio or {}).occlusionInterval) or 400)
    audioEnvironment.occluded = multiplier > 0.0 and IsWorldAudioOccluded(ped)
    audioEnvironment.differentInterior = multiplier > 0.0 and IsDifferentInterior(ped)
end

local function CalculateWorldDuiTargetVolume()
    local baseVolume = tonumber(worldState.baseVolume) or 70.0
    local audioConfig = Config.Audio or {}
    local distance = WorldScreenDistance()
    local maximumDistance = tonumber(worldState.maxAudioDistance) or tonumber(audioConfig.maximumDistance) or 55.0
    local innerRadius = math.min(tonumber(worldState.innerAudioRadius) or tonumber(audioConfig.innerRadius) or 4.0,maximumDistance)
    local multiplier = 0.0

    if worldState.enabled and worldState.audioEnabled ~= false and audioConfig.enabled ~= false then
        if distance <= innerRadius then
            multiplier = 1.0
        elseif distance < maximumDistance and maximumDistance > innerRadius then
            local normalized = (distance - innerRadius) / (maximumDistance - innerRadius)
            multiplier = (1.0 - normalized) ^ (tonumber(worldState.falloffExponent) or tonumber(audioConfig.falloffExponent) or 1.6)
        end
    end

    local ped = PlayerPedId()
    local distanceFactor = multiplier
    RefreshAudioEnvironment(ped,multiplier)

    local occlusionFactor = audioEnvironment.occluded and (tonumber(audioConfig.occludedMultiplier) or 0.35) or 1.0
    local interiorFactor = audioEnvironment.differentInterior and (tonumber(audioConfig.differentInteriorMultiplier) or 0.20) or 1.0
    if audioEnvironment.occluded then
        multiplier = multiplier * occlusionFactor
    end
    if audioEnvironment.differentInterior then
        multiplier = multiplier * interiorFactor
    end

    local effectiveVolume = Clamp(baseVolume * multiplier,0.0,100.0)
    audioDiagnostics.targetVolume = effectiveVolume
    audioDiagnostics.distance = distance
    audioDiagnostics.distanceFactor = distanceFactor
    audioDiagnostics.occlusionFactor = occlusionFactor
    audioDiagnostics.interiorFactor = interiorFactor
    audioDiagnostics.occluded = audioEnvironment.occluded
    audioDiagnostics.differentInterior = audioEnvironment.differentInterior
    return effectiveVolume
end

local function ApplyWorldDuiVolume(force)
    targetEffectiveVolume = CalculateWorldDuiTargetVolume()

    local now = GetGameTimer()
    local elapsed = math.max((now - lastVolumeUpdateAt) / 1000.0,0.0)
    lastVolumeUpdateAt = now

    local difference = targetEffectiveVolume - currentEffectiveVolume
    local duration = difference > 0.0
        and (tonumber(worldState.fadeInTime) or tonumber((Config.Audio or {}).fadeInTime) or 0.8)
        or (tonumber(worldState.fadeOutTime) or tonumber((Config.Audio or {}).fadeOutTime) or 1.2)
    local alpha = 1.0 - math.exp(-elapsed / math.max(duration,0.01))
    currentEffectiveVolume = currentEffectiveVolume + (difference * alpha)
    if math.abs(targetEffectiveVolume - currentEffectiveVolume) < 0.05 then
        currentEffectiveVolume = targetEffectiveVolume
    end

    audioDiagnostics.effectiveVolume = currentEffectiveVolume
    if not worldDuiObject then return end

    local effectiveVolume = math.floor(Clamp(currentEffectiveVolume,0.0,100.0) + 0.5)
    local audioConfig = Config.Audio or {}
    local minimumChange = tonumber(audioConfig.minimumVolumeChange) or 1
    local maximumApplyInterval = tonumber(audioConfig.maximumApplyInterval) or 1000
    if not force
        and math.abs(effectiveVolume - lastAppliedWorldVolume) < minimumChange
        and (now - lastVolumeSentAt) < maximumApplyInterval then
        return
    end

    lastAppliedWorldVolume = effectiveVolume
    lastVolumeSentAt = now
    SendWorldDuiCommand({
        type = 'setVolume',
        volume = effectiveVolume,
        muted = effectiveVolume <= 0
    })
end

local function ApplyWorldPlayback()
    SendWorldDuiCommand({
        type = 'setPlayback',
        state = worldState.playbackState,
        time = tonumber(worldState.playbackSeconds) or 0,
        revision = tonumber(worldState.revision) or 0
    })
end

local function ApplyWorldState(state)
    if type(state) ~= 'table' then
        return
    end

    local previousOwnerAuthorization = ownerAuthorized

    worldState.enabled = state.enabled == true
    worldState.url = tostring(state.url or worldState.url or Config.DefaultUrl)
    worldState.x = tonumber(state.x) or worldState.x
    worldState.y = tonumber(state.y) or worldState.y
    worldState.z = tonumber(state.z) or worldState.z
    worldState.heading = tonumber(state.heading) or worldState.heading
    worldState.width = tonumber(state.width) or worldState.width
    worldState.height = tonumber(state.height) or worldState.height
    worldState.drawDistance = tonumber(state.drawDistance) or worldState.drawDistance
    worldState.baseVolume = tonumber(state.baseVolume or state.volume) or worldState.baseVolume
    worldState.audioEnabled = state.audioEnabled ~= false
    worldState.maxAudioDistance = tonumber(state.maxAudioDistance or state.audioRange) or worldState.maxAudioDistance
    worldState.innerAudioRadius = tonumber(state.innerAudioRadius) or worldState.innerAudioRadius
    worldState.falloffExponent = tonumber(state.falloffExponent) or worldState.falloffExponent
    worldState.fadeInTime = tonumber(state.fadeInTime) or worldState.fadeInTime
    worldState.fadeOutTime = tonumber(state.fadeOutTime) or worldState.fadeOutTime
    worldState.occlusionEnabled = state.occlusionEnabled ~= false
    worldState.playbackState = tostring(state.playbackState or worldState.playbackState or 'stopped')
    worldState.playbackSeconds = tonumber(state.playbackSeconds) or worldState.playbackSeconds or 0
    worldState.revision = tonumber(state.revision) or worldState.revision or 0
    worldState.lastAction = tostring(state.lastAction or worldState.lastAction or 'sync')
    audioEnvironment.nextCheckAt = 0
    if state.owner ~= nil then
        ownerAuthorized = state.owner == true
        if ownerAuthorized ~= previousOwnerAuthorization then
            Log(('Controle administrativo %s para este jogador.'):format(
                ownerAuthorized and 'autorizado' or 'bloqueado'
            ))
        end
        Log(('Estado recebido: enabled=%s video=%s baseVolume=%.0f maxAudioDistance=%.0f playback=%s'):format(
            tostring(worldState.enabled),
            tostring(worldState.url),
            tonumber(worldState.baseVolume) or 0,
            tonumber(worldState.maxAudioDistance) or 0,
            tostring(worldState.playbackState)
        ))
    end
    worldState.flipX = state.flipX == true
    worldState.flipY = state.flipY == true

    if type(state.crop) == 'table' then
        worldState.crop = {
            x = tonumber(state.crop.x) or worldState.crop.x,
            y = tonumber(state.crop.y) or worldState.crop.y,
            w = tonumber(state.crop.w or state.crop.width) or worldState.crop.w,
            h = tonumber(state.crop.h or state.crop.height) or worldState.crop.h
        }
    end

    ClampWorldState()
    ApplyWorldDuiVolume(true)
    ApplyWorldPlayback()
end

local function BuildWorldPayload(extra)
    extra = type(extra) == 'table' and extra or {}

    local payload = {
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
        audioEnabled = worldState.audioEnabled,
        maxAudioDistance = worldState.maxAudioDistance,
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
        }
    }

    for key, value in pairs(extra) do
        payload[key] = value
    end

    return payload
end

local function SendWorldUpdate(action, payload)
    TriggerServerEvent('af_youtube_tv:updateWorldState', action, payload or BuildWorldPayload())
end

local function QueueWorldSync()
    worldSyncPending = true
end

local function FormatWorldValues()
    return ('pos x=%.3f y=%.3f z=%.3f h=%.1f | tam %.2fx%.2f | volume=%.0f | flipX=%s flipY=%s | crop %.3f %.3f %.3f %.3f'):format(
        worldState.x,
        worldState.y,
        worldState.z,
        worldState.heading,
        worldState.width,
        worldState.height,
        worldState.baseVolume,
        tostring(worldState.flipX),
        tostring(worldState.flipY),
        worldState.crop.x,
        worldState.crop.y,
        worldState.crop.w,
        worldState.crop.h
    )
end

local function GetWorldVectors(heading)
    local radians = math.rad(heading or worldState.heading or 0.0)
    local rightX = math.cos(radians)
    local rightY = math.sin(radians)
    local normalX = -math.sin(radians)
    local normalY = math.cos(radians)

    return rightX, rightY, normalX, normalY
end

local function FormatValues()
    return ('crop x=%.3f y=%.3f w=%.3f h=%.3f | tela x=%.3f y=%.3f w=%.3f h=%.3f'):format(
        crop.x, crop.y, crop.w, crop.h,
        screen.x, screen.y, screen.w, screen.h
    )
end

local function DrawTextLine(text, x, y, scale, r, g, b, a)
    SetTextFont(0)
    SetTextScale(scale or 0.35, scale or 0.35)
    SetTextColour(r or 255, g or 255, b or 255, a or 255)
    SetTextOutline()
    SetTextEntry('STRING')
    AddTextComponentString(text)
    DrawText(x, y)
end

local function DrawOutputBorder()
    local left = screen.x - (screen.w / 2)
    local top = screen.y - (screen.h / 2)
    local right = screen.x + (screen.w / 2)
    local bottom = screen.y + (screen.h / 2)
    local thickness = 0.003

    DrawRect(screen.x, top, screen.w, thickness, 0, 255, 0, 210)
    DrawRect(screen.x, bottom, screen.w, thickness, 0, 255, 0, 210)
    DrawRect(left, screen.y, thickness, screen.h, 0, 255, 0, 210)
    DrawRect(right, screen.y, thickness, screen.h, 0, 255, 0, 210)
end

local function DrawMaskRect(x, y, w, h)
    if cropDefaults.maskOverflow == false then
        return
    end

    if w <= 0.0 or h <= 0.0 then
        return
    end

    DrawRect(
        x,
        y,
        w,
        h,
        cropDefaults.maskR or 0,
        cropDefaults.maskG or 0,
        cropDefaults.maskB or 0,
        cropDefaults.maskA or 255
    )
end

local function DrawEditOverlay()
    if not editMode then
        return
    end

    DrawOutputBorder()
    DrawRect(0.5, 0.04, 0.96, 0.075, 0, 0, 0, 160)
    DrawTextLine(('AF TV EDITANDO [%s] passo %.3f'):format(editTarget, editStep), 0.02, 0.012, 0.42, 80, 255, 120, 255)
    DrawTextLine(FormatValues(), 0.02, 0.043, 0.32, 255, 255, 255, 255)
    DrawTextLine('NUM4/6/8/2 move | NUM7/9 largura | NUM1/3 altura | NUM5 alvo | NUM0 reset | /tveditar sair', 0.02, 0.073, 0.30, 220, 220, 220, 255)
end

local function DrawWorldEditOverlay()
    if not worldEditMode then
        return
    end

    DrawRect(0.5, 0.135, 0.96, 0.105, 0, 0, 0, 165)
    local stepText = worldEditTarget == 'crop' and worldCropStep or worldEditStep

    DrawTextLine(('AF TELAO EDITANDO [%s] passo %.3f'):format(worldEditTarget, stepText), 0.02, 0.088, 0.42, 80, 255, 120, 255)
    DrawTextLine(FormatWorldValues(), 0.02, 0.120, 0.31, 255, 255, 255, 255)

    if worldEditTarget == 'pos' then
        DrawTextLine('NUM4/6 lateral | NUM8/2 altura | NUM7/9 frente/fundo | NUM5 alvo | /telaoedit sair', 0.02, 0.150, 0.30, 220, 220, 220, 255)
    elseif worldEditTarget == 'size' then
        DrawTextLine('NUM7/9 largura | NUM1/3 altura | NUM4/6 escala geral | NUM5 alvo | /telaosalvar', 0.02, 0.150, 0.30, 220, 220, 220, 255)
    elseif worldEditTarget == 'crop' then
        DrawTextLine('CROP: NUM4/6/8/2 move | NUM7/9 largura | NUM1/3 altura | /telaosalvar', 0.02, 0.150, 0.30, 220, 220, 220, 255)
    else
        DrawTextLine('NUM4/6 gira heading | NUM8/2 ajuste fino | NUM5 alvo | /telaosalvar', 0.02, 0.150, 0.30, 220, 220, 220, 255)
    end
end

local function TryDrawSpriteUv(...)
    if drawUvMode == false then
        return false
    end

    if drawUvMode == 'function' then
        DrawSpriteUv(...)
        return true
    end

    if drawUvMode == 'underscore_function' then
        _DrawSpriteUv(...)
        return true
    end

    if drawUvMode == 'native' then
        Citizen.InvokeNative(0x95812F9B26074726, ...)
        return true
    end

    if type(DrawSpriteUv) == 'function' then
        local ok = pcall(DrawSpriteUv, ...)

        if ok then
            drawUvMode = 'function'
            Log('Crop UV ativo via DrawSpriteUv.')
            return true
        end
    end

    if type(_DrawSpriteUv) == 'function' then
        local ok = pcall(_DrawSpriteUv, ...)

        if ok then
            drawUvMode = 'underscore_function'
            Log('Crop UV ativo via _DrawSpriteUv.')
            return true
        end
    end

    if Citizen and Citizen.InvokeNative then
        local ok = pcall(Citizen.InvokeNative, 0x95812F9B26074726, ...)

        if ok then
            drawUvMode = 'native'
            Log('Crop UV ativo via native DRAW_SPRITE_UV.')
            return true
        end
    end

    drawUvMode = false
    Log('DrawSpriteUv indisponivel; usando modo mask como fallback.')
    return false
end

local function TryDrawTexturedTriangle(...)
    if drawPolyMode == false then
        return false
    end

    if drawPolyMode == 'function' then
        DrawSpritePoly(...)
        return true
    end

    if drawPolyMode == 'native' then
        Citizen.InvokeNative(0x29280002282F1928, ...)
        return true
    end

    if type(DrawSpritePoly) == 'function' then
        local ok = pcall(DrawSpritePoly, ...)

        if ok then
            drawPolyMode = 'function'
            Log('Crop real ativo via DrawSpritePoly.')
            return true
        end
    end

    if Citizen and Citizen.InvokeNative then
        local ok = pcall(Citizen.InvokeNative, 0x29280002282F1928, ...)

        if ok then
            drawPolyMode = 'native'
            Log('Crop real ativo via native DRAW_SPRITE_POLY.')
            return true
        end
    end

    drawPolyMode = false
    Log('Crop real indisponivel; usando DrawSprite sem recorte como fallback.')
    return false
end

local function TryDrawWorldTexturedTriangle(...)
    if worldPolyMode == false then
        return false
    end

    if worldPolyMode == 'function' then
        DrawSpritePoly(...)
        return true
    end

    if worldPolyMode == 'native' then
        Citizen.InvokeNative(0x29280002282F1928, ...)
        return true
    end

    if type(DrawSpritePoly) == 'function' then
        local ok = pcall(DrawSpritePoly, ...)

        if ok then
            worldPolyMode = 'function'
            Log('Telao 3D ativo via DrawSpritePoly.')
            return true
        end
    end

    if Citizen and Citizen.InvokeNative then
        local ok = pcall(Citizen.InvokeNative, 0x29280002282F1928, ...)

        if ok then
            worldPolyMode = 'native'
            Log('Telao 3D ativo via native DRAW_SPRITE_POLY.')
            return true
        end
    end

    worldPolyMode = false
    Log('DrawSpritePoly indisponivel; telao 3D nao pode ser desenhado neste build.')
    return false
end

local function GetWorldCorners(extraPadding, normalOffset)
    extraPadding = tonumber(extraPadding) or 0.0
    normalOffset = tonumber(normalOffset) or 0.0

    local rightX, rightY, normalX, normalY = GetWorldVectors(worldState.heading)
    local halfWidth = (worldState.width + (extraPadding * 2.0)) / 2.0
    local halfHeight = (worldState.height + (extraPadding * 2.0)) / 2.0
    local centerX = worldState.x + (normalX * normalOffset)
    local centerY = worldState.y + (normalY * normalOffset)
    local centerZ = worldState.z

    local topLeft = {
        x = centerX - (rightX * halfWidth),
        y = centerY - (rightY * halfWidth),
        z = centerZ + halfHeight
    }
    local topRight = {
        x = centerX + (rightX * halfWidth),
        y = centerY + (rightY * halfWidth),
        z = centerZ + halfHeight
    }
    local bottomLeft = {
        x = centerX - (rightX * halfWidth),
        y = centerY - (rightY * halfWidth),
        z = centerZ - halfHeight
    }
    local bottomRight = {
        x = centerX + (rightX * halfWidth),
        y = centerY + (rightY * halfWidth),
        z = centerZ - halfHeight
    }

    return topLeft, topRight, bottomLeft, bottomRight
end

local function DrawSolidWorldTriangle(a, b, c, red, green, blue, alpha)
    DrawPoly(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z, red, green, blue, alpha)
end

local function DrawWorldFrame()
    if worldDefaults.frame == false then
        return
    end

    local padding = worldDefaults.framePadding or 0.16
    local red = worldDefaults.frameR or 0
    local green = worldDefaults.frameG or 0
    local blue = worldDefaults.frameB or 0
    local alpha = worldDefaults.frameA or 230
    local topLeft, topRight, bottomLeft, bottomRight = GetWorldCorners(padding, -0.02)

    DrawSolidWorldTriangle(topLeft, topRight, bottomLeft, red, green, blue, alpha)
    DrawSolidWorldTriangle(topRight, bottomRight, bottomLeft, red, green, blue, alpha)
end

local function DrawWorldBorder()
    local topLeft, topRight, bottomLeft, bottomRight = GetWorldCorners(0.0, -0.01)

    DrawLine(topLeft.x, topLeft.y, topLeft.z, topRight.x, topRight.y, topRight.z, 0, 255, 80, 255)
    DrawLine(topRight.x, topRight.y, topRight.z, bottomRight.x, bottomRight.y, bottomRight.z, 0, 255, 80, 255)
    DrawLine(bottomRight.x, bottomRight.y, bottomRight.z, bottomLeft.x, bottomLeft.y, bottomLeft.z, 0, 255, 80, 255)
    DrawLine(bottomLeft.x, bottomLeft.y, bottomLeft.z, topLeft.x, topLeft.y, topLeft.z, 0, 255, 80, 255)
end

local function DrawWorldVideo()
    local topLeft, topRight, bottomLeft, bottomRight = GetWorldCorners(0.0, 0.015)
    local worldCrop = worldState.crop
    local u1 = worldCrop.x
    local v1 = worldCrop.y
    local u2 = worldCrop.x + worldCrop.w
    local v2 = worldCrop.y + worldCrop.h
    local uLeft = worldState.flipX == true and u2 or u1
    local uRight = worldState.flipX == true and u1 or u2
    local vTop = worldState.flipY == true and v2 or v1
    local vBottom = worldState.flipY == true and v1 or v2
    local red, green, blue, alpha = 255, 255, 255, 255

    local first = TryDrawWorldTexturedTriangle(
        topLeft.x, topLeft.y, topLeft.z,
        topRight.x, topRight.y, topRight.z,
        bottomLeft.x, bottomLeft.y, bottomLeft.z,
        red, green, blue, alpha,
        WORLD_TXD_NAME, WORLD_TXN_NAME,
        uLeft, vTop, 1.0,
        uRight, vTop, 1.0,
        uLeft, vBottom, 1.0
    )

    if not first then
        return false
    end

    TryDrawWorldTexturedTriangle(
        topRight.x, topRight.y, topRight.z,
        bottomRight.x, bottomRight.y, bottomRight.z,
        bottomLeft.x, bottomLeft.y, bottomLeft.z,
        red, green, blue, alpha,
        WORLD_TXD_NAME, WORLD_TXN_NAME,
        uRight, vTop, 1.0,
        uRight, vBottom, 1.0,
        uLeft, vBottom, 1.0
    )

    -- Reverso levemente separado para evitar sumir caso o heading inicial esteja invertido.
    local backTopLeft, backTopRight, backBottomLeft, backBottomRight = GetWorldCorners(0.0, -0.015)

    TryDrawWorldTexturedTriangle(
        backTopLeft.x, backTopLeft.y, backTopLeft.z,
        backBottomLeft.x, backBottomLeft.y, backBottomLeft.z,
        backTopRight.x, backTopRight.y, backTopRight.z,
        red, green, blue, alpha,
        WORLD_TXD_NAME, WORLD_TXN_NAME,
        uLeft, vTop, 1.0,
        uLeft, vBottom, 1.0,
        uRight, vTop, 1.0
    )

    TryDrawWorldTexturedTriangle(
        backTopRight.x, backTopRight.y, backTopRight.z,
        backBottomLeft.x, backBottomLeft.y, backBottomLeft.z,
        backBottomRight.x, backBottomRight.y, backBottomRight.z,
        red, green, blue, alpha,
        WORLD_TXD_NAME, WORLD_TXN_NAME,
        uRight, vTop, 1.0,
        uLeft, vBottom, 1.0,
        uRight, vBottom, 1.0
    )

    return true
end

local function DrawWorldScreen()
    DrawWorldFrame()
    DrawWorldVideo()

    if worldEditMode then
        DrawWorldBorder()
    end
end

local function DrawMaskTexture()
    local viewportLeft = screen.x - (screen.w / 2)
    local viewportTop = screen.y - (screen.h / 2)
    local viewportRight = screen.x + (screen.w / 2)
    local viewportBottom = screen.y + (screen.h / 2)

    -- Fallback: amplia/desloca a textura e mascara as sobras.
    local sourceW = screen.w / crop.w
    local sourceH = screen.h / crop.h
    local sourceLeft = viewportLeft - (crop.x * sourceW)
    local sourceTop = viewportTop - (crop.y * sourceH)
    local sourceRight = sourceLeft + sourceW
    local sourceBottom = sourceTop + sourceH
    local sourceX = sourceLeft + (sourceW / 2)
    local sourceY = sourceTop + (sourceH / 2)

    DrawRect(screen.x, screen.y, screen.w, screen.h, 0, 0, 0, 255)
    DrawSprite(TXD_NAME, TXN_NAME, sourceX, sourceY, sourceW, sourceH, 0.0, 255, 255, 255, 255)

    DrawMaskRect((sourceLeft + sourceRight) / 2, (sourceTop + viewportTop) / 2, sourceW, viewportTop - sourceTop)
    DrawMaskRect((sourceLeft + sourceRight) / 2, (viewportBottom + sourceBottom) / 2, sourceW, sourceBottom - viewportBottom)
    DrawMaskRect((sourceLeft + viewportLeft) / 2, screen.y, viewportLeft - sourceLeft, screen.h)
    DrawMaskRect((viewportRight + sourceRight) / 2, screen.y, sourceRight - viewportRight, screen.h)
end

local function DrawUvTexture()
    return TryDrawSpriteUv(
        TXD_NAME,
        TXN_NAME,
        screen.x,
        screen.y,
        screen.w,
        screen.h,
        crop.x,
        crop.y,
        crop.x + crop.w,
        crop.y + crop.h,
        0.0,
        255,
        255,
        255,
        255
    )
end

local function DrawPolyTexture()
    local left = screen.x - (screen.w / 2)
    local top = screen.y - (screen.h / 2)
    local right = screen.x + (screen.w / 2)
    local bottom = screen.y + (screen.h / 2)
    local u1 = crop.x
    local v1 = crop.y
    local u2 = crop.x + crop.w
    local v2 = crop.y + crop.h
    local r, g, b, a = 255, 255, 255, 255

    -- Dois triangulos formam o retangulo. Os UVs fazem o recorte real da textura DUI.
    local first = TryDrawTexturedTriangle(
        left, top, 0.0,
        right, top, 0.0,
        left, bottom, 0.0,
        r, g, b, a,
        TXD_NAME, TXN_NAME,
        u1, v1, 1.0,
        u2, v1, 1.0,
        u1, v2, 1.0
    )

    if first then
        TryDrawTexturedTriangle(
            right, top, 0.0,
            right, bottom, 0.0,
            left, bottom, 0.0,
            r, g, b, a,
            TXD_NAME, TXN_NAME,
            u2, v1, 1.0,
            u2, v2, 1.0,
            u1, v2, 1.0
        )
        return
    end

    DrawSprite(TXD_NAME, TXN_NAME, screen.x, screen.y, screen.w, screen.h, 0.0, r, g, b, a)
end

local function DrawCroppedTexture()
    if drawMode == 'uv' then
        if DrawUvTexture() then
            return
        end

        DrawMaskTexture()
        return
    end

    if drawMode == 'poly' then
        DrawPolyTexture()
        return
    end

    DrawMaskTexture()
end

function DrawTvSprite()
    if not tvOn or not duiObject then
        return
    end

    DrawCroppedTexture()
    DrawEditOverlay()
end

local function StartDrawThread()
    if drawThreadActive then
        return
    end

    drawThreadActive = true

    CreateThread(function()
        while drawThreadActive do
            if tvOn and duiObject then
                DrawTvSprite()
                Wait(0)
            else
                Wait(250)
            end
        end
    end)
end

local function GetWorldScreenDistance()
    return WorldScreenDistance()
end

local function StartWorldDrawThread()
    if worldDrawThreadActive then
        return
    end

    worldDrawThreadActive = true

    CreateThread(function()
        while worldDrawThreadActive do
            if worldState.enabled and worldDuiObject then
                local distance = GetWorldScreenDistance()

                if distance <= worldState.drawDistance or worldEditMode then
                    DrawWorldScreen()
                    DrawWorldEditOverlay()
                    Wait(0)
                else
                    Wait(500)
                end
            else
                Wait(500)
            end
        end
    end)
end

function DestroyTvDui(silent)
    tvOn = false
    drawThreadActive = false

    if duiObject then
        DestroyDui(duiObject)
    end

    duiObject = nil
    duiHandle = nil
    runtimeTxd = nil
    runtimeTexture = nil

    if not silent then
        Chat('TV desligada.')
    end
end

local function DestroyWorldDui(silent)
    worldDrawThreadActive = false

    if worldDuiObject then
        DestroyDui(worldDuiObject)
    end

    worldDuiObject = nil
    worldDuiHandle = nil
    worldRuntimeTxd = nil
    worldRuntimeTexture = nil
    worldDuiUrl = nil
    worldDuiVideoId = nil
    worldPlayerReady = false
    lastAppliedWorldVolume = -1
    currentEffectiveVolume = 0.0
    targetEffectiveVolume = 0.0
    lastVolumeUpdateAt = GetGameTimer()
    lastVolumeSentAt = 0
    audioDiagnostics.effectiveVolume = 0.0
    audioDiagnostics.targetVolume = 0.0

    if not silent then
        Chat('Telao desligado.')
    end
end

local function AttachDui(url)
    local width = Config.Dui.width or 1280
    local height = Config.Dui.height or 720

    Log(('Criando DUI crop %sx%s: %s'):format(width, height, url))

    duiObject = CreateDui(url, width, height)

    if not duiObject then
        Chat('Falha ao criar DUI. Veja o console/F8.')
        return false
    end

    duiHandle = GetDuiHandle(duiObject)

    if not duiHandle then
        Chat('Falha ao obter handle do DUI.')
        DestroyTvDui(true)
        return false
    end

    runtimeTxd = CreateRuntimeTxd(TXD_NAME)
    runtimeTexture = CreateRuntimeTextureFromDuiHandle(runtimeTxd, TXN_NAME, duiHandle)

    tvOn = true
    StartDrawThread()
    Chat('DUI criado. Desenhando player na tela.')
    Log('DUI criado e textura conectada.')
    return true
end

local function AttachWorldDui(url)
    local width = Config.Dui.width or 1280
    local height = Config.Dui.height or 720

    if worldDuiObject and worldDuiUrl == url then
        StartWorldDrawThread()
        return true
    end

    if worldDuiObject then
        DestroyWorldDui(true)
        Wait(250)
    end

    Log(('Criando DUI do telao %sx%s: %s'):format(width, height, url))

    currentEffectiveVolume = 0.0
    targetEffectiveVolume = 0.0
    lastAppliedWorldVolume = -1
    lastVolumeUpdateAt = GetGameTimer()
    lastVolumeSentAt = 0

    worldDuiObject = CreateDui(url, width, height)

    if not worldDuiObject then
        Chat('Falha ao criar DUI do telao. Veja o console/F8.')
        return false
    end

    worldDuiHandle = GetDuiHandle(worldDuiObject)

    if not worldDuiHandle then
        Chat('Falha ao obter handle do DUI do telao.')
        DestroyWorldDui(true)
        return false
    end

    worldRuntimeTxd = CreateRuntimeTxd(WORLD_TXD_NAME)
    worldRuntimeTexture = CreateRuntimeTextureFromDuiHandle(worldRuntimeTxd, WORLD_TXN_NAME, worldDuiHandle)
    worldDuiUrl = url

    StartWorldDrawThread()
    ApplyWorldDuiVolume(true)
    ApplyWorldPlayback()
    Log('DUI do telao criado e textura conectada.')
    return true
end

local function RefreshWorldDui()
    if not worldState.enabled then
        DestroyWorldDui(true)
        return
    end

    local videoId = ExtractYoutubeId(worldState.url)

    if not videoId then
        Chat('URL/ID do telao invalido. Use /telao url URL_OU_ID.')
        return
    end

    worldDuiVideoId = videoId
    AttachWorldDui(BuildLocalPlayerUrl(videoId,'world'))
    ApplyWorldPlayback()
    ApplyWorldDuiVolume(true)
end

local function CropMode(videoId)
    if duiObject then
        DestroyTvDui(true)
        Wait(500)
    end

    local ok = AttachDui(BuildLocalPlayerUrl(videoId,'preview'))

    if ok then
        Chat('Modo crop ligado. Use /tveditar para ajustar sem usar WASD.')
    end

    return ok
end

function CreateTvDui()
    if duiObject then
        tvOn = true
        StartDrawThread()
        return
    end

    local videoId = ExtractYoutubeId(currentUrl)

    if not videoId then
        Chat('URL/ID invalido. Use /tvurl URL_OU_ID.')
        return
    end

    CropMode(videoId)
end

function ResetTvDui()
    DestroyTvDui(true)

    CreateThread(function()
        Wait(250)
        CreateTvDui()
        Chat('TV resetada.')
    end)
end

function SetTvUrl(url)
    url = tostring(url or ''):gsub('^%s+', ''):gsub('%s+$', '')

    if url == '' then
        Chat('Uso: /tvurl URL-ou-videoId')
        return
    end

    currentUrl = url
    Log(('URL atualizada para: %s'):format(currentUrl))

    if duiObject then
        ResetTvDui()
    else
        Chat('URL salva. Use /tvligar.')
    end
end

local function ApplyEditAction(action, amount)
    if not editMode then
        return
    end

    amount = amount or editStep

    if editTarget == 'screen' then
        if action == 'left' then
            screen.x = screen.x - amount
        elseif action == 'right' then
            screen.x = screen.x + amount
        elseif action == 'up' then
            screen.y = screen.y - amount
        elseif action == 'down' then
            screen.y = screen.y + amount
        elseif action == 'shrinkW' then
            screen.w = screen.w - amount
        elseif action == 'growW' then
            screen.w = screen.w + amount
        elseif action == 'shrinkH' then
            screen.h = screen.h - amount
        elseif action == 'growH' then
            screen.h = screen.h + amount
        end

        ClampScreen()
        return
    end

    if action == 'left' then
        crop.x = crop.x - amount
    elseif action == 'right' then
        crop.x = crop.x + amount
    elseif action == 'up' then
        crop.y = crop.y - amount
    elseif action == 'down' then
        crop.y = crop.y + amount
    elseif action == 'shrinkW' then
        crop.w = crop.w - amount
    elseif action == 'growW' then
        crop.w = crop.w + amount
    elseif action == 'shrinkH' then
        crop.h = crop.h - amount
    elseif action == 'growH' then
        crop.h = crop.h + amount
    end

    ClampCrop()
end

local function ApplyWorldEditAction(action, fast)
    if not worldEditMode then
        return
    end

    local moveAmount = fast and worldEditFastStep or worldEditStep
    local rotationAmount = fast and worldRotationFastStep or worldRotationStep
    local cropAmount = fast and worldCropFastStep or worldCropStep
    local rightX, rightY, normalX, normalY = GetWorldVectors(worldState.heading)

    if worldEditTarget == 'pos' then
        if action == 'left' then
            worldState.x = worldState.x - (rightX * moveAmount)
            worldState.y = worldState.y - (rightY * moveAmount)
        elseif action == 'right' then
            worldState.x = worldState.x + (rightX * moveAmount)
            worldState.y = worldState.y + (rightY * moveAmount)
        elseif action == 'up' then
            worldState.z = worldState.z + moveAmount
        elseif action == 'down' then
            worldState.z = worldState.z - moveAmount
        elseif action == 'shrinkW' then
            worldState.x = worldState.x - (normalX * moveAmount)
            worldState.y = worldState.y - (normalY * moveAmount)
        elseif action == 'growW' then
            worldState.x = worldState.x + (normalX * moveAmount)
            worldState.y = worldState.y + (normalY * moveAmount)
        end
    elseif worldEditTarget == 'size' then
        if action == 'left' then
            worldState.width = worldState.width - moveAmount
            worldState.height = worldState.height - (moveAmount * 0.5625)
        elseif action == 'right' then
            worldState.width = worldState.width + moveAmount
            worldState.height = worldState.height + (moveAmount * 0.5625)
        elseif action == 'shrinkW' then
            worldState.width = worldState.width - moveAmount
        elseif action == 'growW' then
            worldState.width = worldState.width + moveAmount
        elseif action == 'shrinkH' or action == 'down' then
            worldState.height = worldState.height - moveAmount
        elseif action == 'growH' or action == 'up' then
            worldState.height = worldState.height + moveAmount
        end
    elseif worldEditTarget == 'crop' then
        if action == 'left' then
            worldState.crop.x = worldState.crop.x - cropAmount
        elseif action == 'right' then
            worldState.crop.x = worldState.crop.x + cropAmount
        elseif action == 'up' then
            worldState.crop.y = worldState.crop.y - cropAmount
        elseif action == 'down' then
            worldState.crop.y = worldState.crop.y + cropAmount
        elseif action == 'shrinkW' then
            worldState.crop.w = worldState.crop.w - cropAmount
        elseif action == 'growW' then
            worldState.crop.w = worldState.crop.w + cropAmount
        elseif action == 'shrinkH' then
            worldState.crop.h = worldState.crop.h - cropAmount
        elseif action == 'growH' then
            worldState.crop.h = worldState.crop.h + cropAmount
        end
    else
        if action == 'left' or action == 'down' or action == 'shrinkW' then
            worldState.heading = worldState.heading - rotationAmount
        elseif action == 'right' or action == 'up' or action == 'growW' then
            worldState.heading = worldState.heading + rotationAmount
        end
    end

    ClampWorldState()
    QueueWorldSync()
end

local function CycleWorldEditTarget()
    if worldEditTarget == 'pos' then
        worldEditTarget = 'size'
    elseif worldEditTarget == 'size' then
        worldEditTarget = 'rot'
    elseif worldEditTarget == 'rot' then
        worldEditTarget = 'crop'
    else
        worldEditTarget = 'pos'
    end

    Chat(('Alvo do telao: %s'):format(worldEditTarget))
end

local function PlaceWorldScreenInFront(distance)
    distance = tonumber(distance) or 8.0
    distance = Clamp(distance, 2.0, 40.0)

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local radians = math.rad(heading)
    local forwardX = -math.sin(radians)
    local forwardY = math.cos(radians)

    worldState.x = coords.x + (forwardX * distance)
    worldState.y = coords.y + (forwardY * distance)
    worldState.z = coords.z + (worldState.height / 2.0)
    worldState.heading = NormalizeHeading(heading + 180.0)
    worldState.enabled = true
    ClampWorldState()
end

local function PrintWorldEditHelp()
    Chat('Modo de edicao do TELAO:')
    Chat('NUM5 alterna alvo: pos, size, rot ou crop.')
    Chat('pos: NUM4/6 lateral, NUM8/2 altura, NUM7/9 frente/fundo.')
    Chat('size: NUM7/9 largura, NUM1/3 altura, NUM4/6 escala geral.')
    Chat('rot: NUM4/6 gira o heading.')
    Chat('crop: NUM4/6/8/2 move corte, NUM7/9 largura, NUM1/3 altura.')
    Chat(FormatWorldValues())
end

local function SetHeld(action, state)
    if held[action] == nil then
        return
    end

    held[action] = state

    if state then
        if editMode then
            ApplyEditAction(action, editFastStep)
        end

        if worldEditMode then
            ApplyWorldEditAction(action, true)
        end
    end
end

local function CycleEditTarget()
    editTarget = editTarget == 'crop' and 'screen' or 'crop'
    Chat(('Alvo do ajuste: %s'):format(editTarget == 'crop' and 'recorte da textura' or 'posicao/tamanho na tela'))
end

local function PrintEditHelp()
    Chat('Modo de ajuste AF TV:')
    Chat('NUM4/6/8/2 move o alvo atual.')
    Chat('NUM7/9 diminui/aumenta largura. NUM1/3 diminui/aumenta altura.')
    Chat('NUM5 alterna alvo: recorte ou tela. NUM0 reseta. /tveditar sai.')
    Chat(FormatValues())
end

CreateThread(function()
    while true do
        if editMode or worldEditMode then
            local anyHeld = false

            for action, isHeld in pairs(held) do
                if isHeld then
                    anyHeld = true

                    if editMode then
                        ApplyEditAction(action, editStep)
                    end

                    if worldEditMode then
                        ApplyWorldEditAction(action, false)
                    end
                end
            end

            Wait(anyHeld and 40 or 120)
        else
            Wait(250)
        end
    end
end)

local NativeRegisterCommand = RegisterCommand
local function RegisterCommand(name,handler,restricted)
    NativeRegisterCommand(name,function(source,args,rawCommand)
        if not ownerAuthorized then
            Log(('Comando /%s bloqueado: autorizacao do dono ausente.'):format(tostring(name)))
            if not tostring(name):match('^[+-]aftv_') then
                Chat('Voce nao possui permissao para controlar o telao.')
            end
            TriggerServerEvent('af_youtube_tv:requestWorldState')
            return
        end
        handler(source,args,rawCommand)
    end,restricted)
end

CreateThread(function()
    while true do
        if worldSyncPending then
            local now = GetGameTimer()

            if now >= worldNextSyncAt then
                worldSyncPending = false
                worldNextSyncAt = now + 350
                SendWorldUpdate('set', BuildWorldPayload({ silent = true }))
            end

            Wait(80)
        else
            Wait(250)
        end
    end
end)

local function RegisterHoldKey(action, defaultKey, description)
    RegisterCommand('+aftv_' .. action, function()
        SetHeld(action, true)
    end, false)

    RegisterCommand('-aftv_' .. action, function()
        SetHeld(action, false)
    end, false)

    RegisterKeyMapping('+aftv_' .. action, description, 'keyboard', defaultKey)
end

RegisterHoldKey('left', 'NUMPAD4', 'AF TV Crop: mover esquerda')
RegisterHoldKey('right', 'NUMPAD6', 'AF TV Crop: mover direita')
RegisterHoldKey('up', 'NUMPAD8', 'AF TV Crop: mover cima')
RegisterHoldKey('down', 'NUMPAD2', 'AF TV Crop: mover baixo')
RegisterHoldKey('shrinkW', 'NUMPAD7', 'AF TV Crop: diminuir largura')
RegisterHoldKey('growW', 'NUMPAD9', 'AF TV Crop: aumentar largura')
RegisterHoldKey('shrinkH', 'NUMPAD1', 'AF TV Crop: diminuir altura')
RegisterHoldKey('growH', 'NUMPAD3', 'AF TV Crop: aumentar altura')

RegisterCommand('aftv_cycle_target', function()
    if editMode then
        CycleEditTarget()
    elseif worldEditMode then
        CycleWorldEditTarget()
    end
end, false)
RegisterKeyMapping('aftv_cycle_target', 'AF TV Crop: alternar recorte/tela', 'keyboard', 'NUMPAD5')

RegisterCommand('aftv_reset_crop', function()
    if editMode then
        ResetAllCropSettings()
        Chat('Recorte e tela resetados.')
    elseif worldEditMode then
        PlaceWorldScreenInFront(8.0)
        SendWorldUpdate('set', BuildWorldPayload())
        Chat('Telao reposicionado a sua frente.')
    end
end, false)
RegisterKeyMapping('aftv_reset_crop', 'AF TV Crop: resetar', 'keyboard', 'NUMPAD0')

local function JoinArgs(args, startIndex)
    local parts = {}

    for i = startIndex or 1, #args do
        parts[#parts + 1] = args[i]
    end

    return table.concat(parts, ' ')
end

local function PrintWorldHelp()
    Chat('Comandos do TELAO global:')
    Chat('/telao on [URL_OU_ID] - liga para todos')
    Chat('/telao off - desliga para todos')
    Chat('/telao url URL_OU_ID - troca a live e liga')
    Chat('/telao aqui [dist] - coloca a tela a sua frente')
    Chat('/telao pos X Y Z | /telao tamanho W H | /telao rot HEADING')
    Chat('/telao volume 0-100 - ajusta volume salvo/sincronizado')
    Chat('/telao crop - usa o crop atual do /tveditar no telao')
    Chat('/telao flipx ou /telao flipy - corrige espelhamento')
    Chat('/telao salvar - persiste posicao/tamanho/crop em KVP')
    Chat('/telaoalvo pos|size|rot|crop - escolhe alvo do NUMPAD')
    Chat('/telaoedit - ajuste fino com NUMPAD')
end

local function RequireOwnerControl()
    if ownerAuthorized then return true end
    Chat('Voce nao possui permissao para controlar o telao.')
    return false
end

local function PrintAudioDiagnostics()
    local summary = ('Base: %.0f%% | alvo: %.1f%% | atual: %.1f%% | distancia: %.1fm'):format(
        worldState.baseVolume,
        audioDiagnostics.targetVolume,
        audioDiagnostics.effectiveVolume,
        audioDiagnostics.distance
    )
    local curve = ('Raio: %.1fm | alcance: %.1fm | curva: %.2f | fator distancia: %.3f'):format(
        worldState.innerAudioRadius,
        worldState.maxAudioDistance,
        worldState.falloffExponent,
        audioDiagnostics.distanceFactor
    )
    local environment = ('Parede: %s (%.2f) | interior: %s (%.2f) | player: %s | DUI: %s'):format(
        tostring(audioDiagnostics.occluded),
        audioDiagnostics.occlusionFactor,
        tostring(audioDiagnostics.differentInterior),
        audioDiagnostics.interiorFactor,
        tostring(worldPlayerReady),
        tostring(worldDuiObject ~= nil)
    )
    local simulation = audioSimulatedDistance ~= nil
        and ('Simulacao local ativa: %.1fm'):format(audioSimulatedDistance)
        or 'Simulacao local: desligada'

    Chat(summary)
    Chat(curve)
    Chat(environment)
    Chat(simulation)
    Log(summary)
    Log(curve)
    Log(environment)
end

local function PrintWorldSaveValues()
    Chat('Copie para Config.WorldScreen:')
    Chat(('x = %.4f, y = %.4f, z = %.4f, heading = %.2f'):format(worldState.x, worldState.y, worldState.z, worldState.heading))
    Chat(('width = %.4f, height = %.4f, drawDistance = %.1f, volume = %.0f'):format(worldState.width, worldState.height, worldState.drawDistance, worldState.baseVolume))
    Chat(('flipX = %s, flipY = %s'):format(tostring(worldState.flipX), tostring(worldState.flipY)))
    Chat(('cropX = %.4f, cropY = %.4f, cropWidth = %.4f, cropHeight = %.4f'):format(worldState.crop.x, worldState.crop.y, worldState.crop.w, worldState.crop.h))
end

local function ValidateWorldUrl(preferCurrent)
    local currentVideoId = ExtractYoutubeId(currentUrl)
    local worldVideoId = ExtractYoutubeId(worldState.url)

    if preferCurrent and currentVideoId and currentVideoId ~= defaultVideoId then
        worldState.url = currentUrl
        return true
    end

    if worldVideoId and worldVideoId ~= defaultVideoId then
        return true
    end

    if currentVideoId then
        worldState.url = currentUrl
        return true
    end

    if worldVideoId then
        return true
    end

    Chat('URL/ID invalido. Use /telao url URL_OU_ID.')
    return false
end

local function SetWorldEditTarget(target)
    target = tostring(target or ''):lower()

    if target == 'pos' or target == 'position' or target == 'posicao' then
        worldEditTarget = 'pos'
    elseif target == 'size' or target == 'tamanho' or target == 'tam' then
        worldEditTarget = 'size'
    elseif target == 'rot' or target == 'rotation' or target == 'giro' then
        worldEditTarget = 'rot'
    elseif target == 'crop' or target == 'corte' or target == 'recorte' then
        worldEditTarget = 'crop'
    else
        return false
    end

    Chat(('Alvo do telao: %s'):format(worldEditTarget))
    return true
end

RegisterCommand('tvligar', function()
    CreateTvDui()
end, false)

RegisterCommand('tvdesligar', function()
    DestroyTvDui(false)
end, false)

RegisterCommand('tvreset', function()
    ResetTvDui()
end, false)

RegisterCommand('tvurl', function(_, args)
    SetTvUrl(table.concat(args, ' '))
end, false)

RegisterCommand('tvc', function(_, args)
    local url = table.concat(args, ' ')

    if url ~= '' then
        currentUrl = url
    end

    if not ExtractYoutubeId(currentUrl) then
        Chat('URL/ID invalido. Use /tvc URL_OU_ID.')
        return
    end

    if duiObject then
        ResetTvDui()
    else
        CreateTvDui()
    end

    if url ~= '' then
        worldState.url = currentUrl

        if worldState.enabled then
            SendWorldUpdate('url', { url = worldState.url })
            Chat('Telao atualizado com o link atual do /tvc.')
        else
            Chat('Link salvo para o telao. Use /telao on ou /telao aqui.')
        end
    end
end, false)

RegisterCommand('telao', function(_, args)
    if not RequireOwnerControl() then return end
    local action = tostring(args[1] or 'help'):lower()

    if action == 'help' or action == 'ajuda' then
        PrintWorldHelp()
        return
    end

    if action == 'on' or action == 'ligar' then
        local url = JoinArgs(args, 2)

        if url ~= '' then
            worldState.url = url
        end

        if not ValidateWorldUrl(url == '') then
            return
        end

        worldState.enabled = true
        ClampWorldState()
        SendWorldUpdate('on', BuildWorldPayload({ enabled = true }))
        return
    end

    if action == 'off' or action == 'desligar' then
        worldState.enabled = false
        SendWorldUpdate('off', { enabled = false })
        return
    end

    if action == 'url' then
        local url = JoinArgs(args, 2)

        if url == '' then
            Chat('Uso: /telao url URL_OU_ID')
            return
        end

        worldState.url = url

        if not ValidateWorldUrl(false) then
            return
        end

        worldState.enabled = true
        SendWorldUpdate('url', { url = worldState.url })
        return
    end

    if action == 'aqui' or action == 'here' then
        PlaceWorldScreenInFront(args[2])

        if not ValidateWorldUrl(true) then
            return
        end

        SendWorldUpdate('on', BuildWorldPayload({ enabled = true }))
        Chat('Telao colocado a sua frente. Use /telaoedit para ajustar fino.')
        return
    end

    if action == 'pos' or action == 'position' then
        if #args < 4 then
            Chat(('Atual: pos x=%.3f y=%.3f z=%.3f'):format(worldState.x, worldState.y, worldState.z))
            Chat('Uso: /telao pos X Y Z')
            return
        end

        worldState.x = tonumber(args[2]) or worldState.x
        worldState.y = tonumber(args[3]) or worldState.y
        worldState.z = tonumber(args[4]) or worldState.z
        ClampWorldState()
        SendWorldUpdate('set', BuildWorldPayload())
        return
    end

    if action == 'tamanho' or action == 'size' or action == 'tam' then
        if #args < 3 then
            Chat(('Atual: tamanho %.3f x %.3f'):format(worldState.width, worldState.height))
            Chat('Uso: /telao tamanho W H')
            return
        end

        worldState.width = tonumber(args[2]) or worldState.width
        worldState.height = tonumber(args[3]) or worldState.height
        ClampWorldState()
        SendWorldUpdate('set', BuildWorldPayload())
        return
    end

    if action == 'rot' or action == 'heading' or action == 'giro' then
        if #args < 2 then
            Chat(('Atual: heading %.2f'):format(worldState.heading))
            Chat('Uso: /telao rot HEADING')
            return
        end

        worldState.heading = NormalizeHeading(args[2])
        SendWorldUpdate('set', BuildWorldPayload())
        return
    end

    if action == 'dist' or action == 'distancia' then
        if #args < 2 then
            Chat(('Atual: drawDistance %.1f'):format(worldState.drawDistance))
            Chat('Uso: /telao distancia METROS')
            return
        end

        worldState.drawDistance = tonumber(args[2]) or worldState.drawDistance
        ClampWorldState()
        SendWorldUpdate('set', BuildWorldPayload())
        return
    end

    if action == 'alcance' or action == 'range' then
        if #args < 2 then
            Chat(('Atual: alcance do audio %.1f metros'):format(worldState.maxAudioDistance))
            Chat('Uso: /telao alcance METROS')
            return
        end

        worldState.maxAudioDistance = Clamp(
            tonumber(args[2]) or worldState.maxAudioDistance,
            tonumber((Config.Audio or {}).minimumDistance) or 5.0,
            tonumber((Config.Audio or {}).maximumAllowedDistance) or 150.0
        )
        SendWorldUpdate('setMaxAudioDistance',{ maxAudioDistance = worldState.maxAudioDistance })
        return
    end

    if action == 'som' or action == 'audio' then
        local mode = tostring(args[2] or ''):lower()
        if mode ~= 'on' and mode ~= 'off' then
            Chat(('Audio de proximidade: %s'):format(worldState.audioEnabled and 'ligado' or 'desligado'))
            Chat('Uso: /telao som on|off')
            return
        end

        worldState.audioEnabled = mode == 'on'
        SendWorldUpdate('setAudioEnabled',{ audioEnabled = worldState.audioEnabled })
        ApplyWorldDuiVolume(true)
        return
    end

    if action == 'oclusao' or action == 'occlusion' then
        local mode = tostring(args[2] or ''):lower()
        if mode ~= 'on' and mode ~= 'off' then
            Chat(('Obstrucao por paredes: %s'):format(worldState.occlusionEnabled and 'ligada' or 'desligada'))
            Chat('Uso: /telao oclusao on|off')
            return
        end

        worldState.occlusionEnabled = mode == 'on'
        SendWorldUpdate('setOcclusion',{ occlusionEnabled = worldState.occlusionEnabled })
        ApplyWorldDuiVolume(true)
        return
    end

    if action == 'volume' or action == 'vol' then
        if #args < 2 then
            Chat(('Atual: volume geral %.0f%%'):format(worldState.baseVolume))
            Chat('Uso: /telao volume 0-100')
            return
        end

        worldState.baseVolume = Clamp(tonumber(args[2]) or worldState.baseVolume, 0.0, 100.0)
        ApplyWorldDuiVolume(true)
        SendWorldUpdate('setBaseVolume',{ baseVolume = worldState.baseVolume })
        Chat(('Volume geral do telao: %.0f%%'):format(worldState.baseVolume))
        return
    end

    if action == 'pause' or action == 'pausar' then
        SendWorldUpdate('pause',{})
        return
    end

    if action == 'play' or action == 'resume' or action == 'continuar' then
        SendWorldUpdate('resume',{})
        return
    end

    if action == 'reload' or action == 'recarregar' then
        SendWorldUpdate('reload',{})
        return
    end

    if action == 'sync' or action == 'sincronizar' then
        SendWorldUpdate('sync',{})
        return
    end

    if action == 'audiostatus' then
        PrintAudioDiagnostics()
        return
    end

    if action == 'crop' or action == 'corte' then
        if #args >= 5 then
            worldState.crop = {
                x = tonumber(args[2]) or worldState.crop.x,
                y = tonumber(args[3]) or worldState.crop.y,
                w = tonumber(args[4]) or worldState.crop.w,
                h = tonumber(args[5]) or worldState.crop.h
            }
        else
            worldState.crop = {
                x = crop.x,
                y = crop.y,
                w = crop.w,
                h = crop.h
            }
        end

        ClampWorldState()
        SendWorldUpdate('crop', BuildWorldPayload())
        Chat('Crop enviado para o telao.')
        return
    end

    if action == 'flipx' or action == 'espelho' then
        worldState.flipX = not worldState.flipX
        SendWorldUpdate('set', BuildWorldPayload())
        Chat(('flipX do telao: %s'):format(tostring(worldState.flipX)))
        return
    end

    if action == 'flipy' or action == 'vertical' then
        worldState.flipY = not worldState.flipY
        SendWorldUpdate('set', BuildWorldPayload())
        Chat(('flipY do telao: %s'):format(tostring(worldState.flipY)))
        return
    end

    if action == 'alvo' or action == 'target' then
        if not SetWorldEditTarget(args[2]) then
            Chat('Uso: /telao alvo pos|size|rot|crop')
        end

        return
    end

    if action == 'status' or action == 'debug' then
        Chat(('Telao ligado=%s dui=%s poly=%s %s'):format(
            tostring(worldState.enabled),
            tostring(worldDuiObject ~= nil),
            tostring(worldPolyMode),
            FormatWorldValues()
        ))
        return
    end

    if action == 'salvar' or action == 'save' then
        SendWorldUpdate('save', BuildWorldPayload())
        PrintWorldSaveValues()
        return
    end

    if action == 'reset' then
        SendWorldUpdate('reset', {})
        return
    end

    PrintWorldHelp()
end, false)

RegisterCommand('telaoedit', function()
    if not RequireOwnerControl() then return end
    worldEditMode = not worldEditMode

    if worldEditMode then
        editMode = false

        if not worldState.enabled then
            worldState.enabled = true

            if not ValidateWorldUrl(true) then
                worldEditMode = false
                worldState.enabled = false
                return
            end

            SendWorldUpdate('on', BuildWorldPayload({ enabled = true }))
        end

        RefreshWorldDui()
        PrintWorldEditHelp()
    else
        Chat('Edicao do telao desativada.')
        Chat(FormatWorldValues())
    end
end, false)

RegisterCommand('telaoalvo', function(_, args)
    if not RequireOwnerControl() then return end
    if not SetWorldEditTarget(args[1]) then
        CycleWorldEditTarget()
    end
end, false)

RegisterCommand('telaosalvar', function()
    if not RequireOwnerControl() then return end
    SendWorldUpdate('save', BuildWorldPayload())
    PrintWorldSaveValues()
end, false)

RegisterCommand('telaoaqui', function(_, args)
    if not RequireOwnerControl() then return end
    PlaceWorldScreenInFront(args[1])

    if ValidateWorldUrl(true) then
        SendWorldUpdate('on', BuildWorldPayload({ enabled = true }))
        Chat('Telao colocado a sua frente. Use /telaoedit para ajustar fino.')
    end
end, false)

RegisterCommand('telaoon', function(_, args)
    if not RequireOwnerControl() then return end
    local url = table.concat(args, ' ')

    if url ~= '' then
        worldState.url = url
    end

    if ValidateWorldUrl(url == '') then
        worldState.enabled = true
        SendWorldUpdate('on', BuildWorldPayload({ enabled = true }))
    end
end, false)

RegisterCommand('telaooff', function()
    if not RequireOwnerControl() then return end
    worldState.enabled = false
    SendWorldUpdate('off', { enabled = false })
end, false)

RegisterCommand('telaoadmin',function(_,args)
    if not RequireOwnerControl() then return end

    local action = tostring(args[1] or ''):lower()
    if action == 'audiodebug' then
        audioDebugEnabled = not audioDebugEnabled
        Chat(('Diagnostico de audio: %s'):format(audioDebugEnabled and 'ligado' or 'desligado'))
        if audioDebugEnabled then PrintAudioDiagnostics() end
        return
    end

    if action == 'audiosim' then
        if not audioDebugEnabled then
            Chat('Ative primeiro: /telaoadmin audiodebug')
            return
        end

        local requested = tostring(args[2] or ''):lower()
        if requested == 'off' or requested == 'desligar' then
            audioSimulatedDistance = nil
            Chat('Simulacao de distancia desligada.')
        else
            local distance = tonumber(requested)
            if not distance then
                Chat('Uso: /telaoadmin audiosim DISTANCIA|off')
                return
            end
            audioSimulatedDistance = Clamp(distance,0.0,500.0)
            Chat(('Distancia local simulada: %.1fm'):format(audioSimulatedDistance))
        end

        audioEnvironment.nextCheckAt = 0
        lastVolumeUpdateAt = GetGameTimer()
        ApplyWorldDuiVolume(true)
        PrintAudioDiagnostics()
        return
    end

    ExecuteCommand(('telao %s'):format(table.concat(args,' ')))
end,false)

RegisterCommand('tveditar', function()
    editMode = not editMode

    if editMode then
        worldEditMode = false
        PrintEditHelp()
    else
        Chat('Modo de ajuste desativado.')
        Chat(FormatValues())
    end
end, false)

RegisterCommand('tvalvo', function(_, args)
    local target = tostring(args[1] or ''):lower()

    if target == 'crop' or target == 'recorte' then
        editTarget = 'crop'
    elseif target == 'screen' or target == 'tela' then
        editTarget = 'screen'
    else
        CycleEditTarget()
        return
    end

    Chat(('Alvo do ajuste: %s'):format(editTarget))
end, false)

RegisterCommand('tvpasso', function(_, args)
    local value = tonumber(args[1])

    if not value then
        Chat(('Passo atual: %.4f. Use /tvpasso 0.002 ou /tvpasso 0.01'):format(editStep))
        return
    end

    editStep = Clamp(value, 0.0005, 0.05)
    editFastStep = Clamp(editStep * 4.0, 0.002, 0.1)
    Chat(('Passo ajustado: %.4f'):format(editStep))
end, false)

RegisterCommand('tvajuste', function(_, args)
    if #args < 4 then
        Chat('Uso: /tvajuste X Y W H')
        Chat(('Atual: crop x=%.3f y=%.3f w=%.3f h=%.3f'):format(crop.x, crop.y, crop.w, crop.h))
        return
    end

    SetCrop(args[1], args[2], args[3], args[4])
    Chat(('Recorte ajustado: x=%.3f y=%.3f w=%.3f h=%.3f'):format(crop.x, crop.y, crop.w, crop.h))
end, false)

RegisterCommand('tvtamanho', function(_, args)
    if #args < 2 then
        Chat('Uso: /tvtamanho W H')
        Chat(('Atual: tela w=%.3f h=%.3f'):format(screen.w, screen.h))
        return
    end

    SetScreen(nil, nil, args[1], args[2])
    Chat(('Tamanho da tela: w=%.3f h=%.3f'):format(screen.w, screen.h))
end, false)

RegisterCommand('tvpos', function(_, args)
    if #args < 2 then
        Chat('Uso: /tvpos X Y')
        Chat(('Atual: tela x=%.3f y=%.3f'):format(screen.x, screen.y))
        return
    end

    SetScreen(args[1], args[2], nil, nil)
    Chat(('Posicao da tela: x=%.3f y=%.3f'):format(screen.x, screen.y))
end, false)

RegisterCommand('tvresetcrop', function()
    ResetAllCropSettings()
    Chat('Recorte e tela resetados.')
end, false)

RegisterCommand('tvresetcorte', function()
    ResetAllCropSettings()
    Chat('Recorte e tela resetados.')
end, false)

RegisterCommand('tvsalvar', function()
    Chat('Copie para config.lua em Config.Crop:')
    Chat(('x = %.4f, y = %.4f, width = %.4f, height = %.4f'):format(crop.x, crop.y, crop.w, crop.h))
    Chat(('screenX = %.4f, screenY = %.4f, screenWidth = %.4f, screenHeight = %.4f'):format(screen.x, screen.y, screen.w, screen.h))
end, false)

RegisterCommand('tvrender', function(_, args)
    local mode = tostring(args[1] or ''):lower()

    if mode == '' then
        Chat(('Render atual: %s. Use /tvrender uv, /tvrender mask ou /tvrender poly.'):format(drawMode))
        return
    end

    if not SetDrawMode(mode, false) then
        Chat('Modo invalido. Use: /tvrender uv, /tvrender mask ou /tvrender poly.')
    end
end, false)

RegisterCommand('tvdebug', function()
    local state = ('ligada=%s dui=%s render=%s uv=%s poly=%s edit=%s target=%s %s'):format(
        tostring(tvOn),
        tostring(duiObject ~= nil),
        drawMode,
        tostring(drawUvMode),
        tostring(drawPolyMode),
        tostring(editMode),
        tostring(editTarget),
        FormatValues()
    )

    print(('[af_youtube_tv] DEBUG %s'):format(state))
    Chat(state)

    local worldDebug = ('telao=%s worldDui=%s worldPoly=%s edit=%s target=%s %s'):format(
        tostring(worldState.enabled),
        tostring(worldDuiObject ~= nil),
        tostring(worldPolyMode),
        tostring(worldEditMode),
        tostring(worldEditTarget),
        FormatWorldValues()
    )

    print(('[af_youtube_tv] DEBUG %s'):format(worldDebug))
    Chat(worldDebug)
end, false)

RegisterCommand('tvhelp', function()
    Chat('Comandos AF TV:')
    Chat('/tvc URL_OU_ID ou /tvurl URL_OU_ID - carrega video/live')
    Chat('/tveditar - liga/desliga ajuste por NUMPAD')
    Chat('/tvalvo crop|tela - escolhe se as teclas ajustam recorte ou tela')
    Chat('/tvajuste X Y W H - ajuste manual do recorte')
    Chat('/tvtamanho W H e /tvpos X Y - ajuste manual da tela')
    Chat('/tvpasso VALOR - sensibilidade das teclas')
    Chat('/tvrender uv|mask|poly - troca o tipo de recorte')
    Chat('/tvresetcrop, /tvsalvar, /tvdebug')
    Chat('/telao on|off|url|aqui|pos|tamanho|rot|crop - controla telao global')
    Chat('/telaoedit, /telaosalvar - ajusta e salva posicao/tamanho/crop do telao 3D')
end, false)

RegisterNetEvent('af_youtube_tv:worldState', function(state)
    local oldEnabled = worldState.enabled
    local oldUrl = worldState.url
    local oldRevision = worldState.revision

    ApplyWorldState(state)
    RefreshWorldDui()

    if worldDuiObject and worldState.revision ~= oldRevision then
        if worldState.lastAction == 'reload' then
            SendWorldDuiCommand({ type = 'reload' })
        else
            ApplyWorldPlayback()
        end
        ApplyWorldDuiVolume(true)
    end

    if worldState.enabled and (not oldEnabled or oldUrl ~= worldState.url) then
        Log(('Telao sincronizado: %s'):format(worldState.url))
    elseif not worldState.enabled and oldEnabled then
        Log('Telao sincronizado desligado.')
    end
end)

RegisterNUICallback('duiStatus',function(data,cb)
    if type(data) == 'table' and tostring(data.channel or '') == 'world' then
        local wasReady = worldPlayerReady
        worldPlayerReady = data.ready == true
        if worldPlayerReady and not wasReady then
            Log(('YouTube IFrame API pronta. video=%s state=%s'):format(
                tostring(data.videoId or worldState.url),
                tostring(data.playerState or 'unknown')
            ))
        elseif data.error ~= nil then
            Log(('Falha reportada pelo YouTube: %s'):format(tostring(data.error)))
        end
        if data.ready == true then
            ApplyWorldPlayback()
            ApplyWorldDuiVolume(true)
        end
    end
    cb({ ok = true })
end)

RegisterNetEvent('af_youtube_tv:setEditMode',function(enabled)
    if not ownerAuthorized then return end
    worldEditMode = enabled == true
    if worldEditMode then
        if not worldState.enabled then
            worldState.enabled = true
            SendWorldUpdate('on',BuildWorldPayload({ enabled = true }))
        end
        RefreshWorldDui()
        PrintWorldEditHelp()
    else
        Chat('Edicao do telao desativada.')
    end
end)

RegisterNetEvent('af_youtube_tv:testAudio',function()
    if not ownerAuthorized then return end
    ApplyWorldDuiVolume(true)
    Chat(('Teste local: volume efetivo %.0f%% a %.1fm do telao.'):format(
        audioDiagnostics.effectiveVolume,
        audioDiagnostics.distance
    ))
end)

RegisterNetEvent('af_youtube_tv:worldMessage', function(message)
    Chat(tostring(message or ''))
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= RESOURCE_NAME then
        return
    end

    DestroyTvDui(true)
    DestroyWorldDui(true)
end)

CreateThread(function()
    Wait(1000)
    Log('client.lua carregado. Use /tvhelp para comandos.')
    TriggerServerEvent('af_youtube_tv:requestWorldState')

    if Config.StartOnResourceStart then
        CreateTvDui()
    end
end)

CreateThread(function()
    while true do
        if worldDuiObject and worldState.enabled then
            ApplyWorldDuiVolume(false)
            Wait(tonumber((Config.Audio or {}).updateInterval) or 250)
        else
            audioDiagnostics.effectiveVolume = 0
            audioDiagnostics.targetVolume = 0
            currentEffectiveVolume = 0.0
            targetEffectiveVolume = 0.0
            lastVolumeUpdateAt = GetGameTimer()
            lastAppliedWorldVolume = -1
            Wait(750)
        end
    end
end)
