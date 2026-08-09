Config = {}

Config.DefaultUrl = 'M7lc1UVf-VE'
Config.TestUrl = 'M7lc1UVf-VE'
Config.DisplayMode = 'crop'

Config.Crop = {
    x = 0.02,
    y = 0.06,
    width = 0.85,
    height = 0.75,
    screenX = 0.5,
    screenY = 0.5,
    screenWidth = 0.75,
    screenHeight = 0.421875,
    step = 0.005,
    fastStep = 0.02,

    -- 'uv' desenha apenas a area escolhida, sem bordas pretas.
    -- 'mask' eh fallback: usa DrawSprite normal e mascara sobras.
    -- 'poly' tenta triangulos UV, mas pode falhar com DUI em alguns builds.
    drawMode = 'uv',
    maskOverflow = true,
    maskR = 0,
    maskG = 0,
    maskB = 0,
    maskA = 255
}

Config.Dui = {
    width = 1280,
    height = 720
}

-- Distancia apenas de renderizacao. O audio possui alcance independente.
Config.RenderDistance = 120.0

Config.Sprite = {
    x = 0.5,
    y = 0.5,
    width = 0.75,
    height = 0.421875,
    heading = 0.0,
    r = 255,
    g = 255,
    b = 255,
    a = 255
}

Config.WorldScreen = {
    enabled = false,

    -- Se true, o telao sempre inicia desligado no restart do servidor/resource.
    -- O KVP ainda salva posicao, crop e URL, mas o admin precisa ligar com /telaoon.
    startDisabled = true,
    url = Config.DefaultUrl,

    -- Posicao inicial aproximada perto da Legion Square.
    -- Use /telao aqui para reposicionar olhando para o local desejado.
    x = 215.0,
    y = -920.0,
    z = 34.0,
    heading = 180.0,

    -- 5.4m de altura fica perto de 3 personagens empilhados.
    -- A largura mantem proporcao 16:9.
    width = 9.6,
    height = 5.4,
    drawDistance = Config.RenderDistance,
    baseVolume = 70,
    audioEnabled = true,
    maxAudioDistance = 55.0,
    innerAudioRadius = 4.0,
    falloffExponent = 1.6,
    fadeInTime = 0.8,
    fadeOutTime = 1.2,
    occlusionEnabled = true,
    flipX = true,
    flipY = false,
    persist = true,

    -- Crop proprio do telao 3D. Ajuste com /telaoedit alvo crop.
    cropX = 0.02,
    cropY = 0.09,
    cropWidth = 0.685,
    cropHeight = 0.670,

    frame = true,
    framePadding = 0.16,
    frameR = 0,
    frameG = 0,
    frameB = 0,
    frameA = 230,

    editStep = 0.05,
    editFastStep = 0.25,
    rotationStep = 1.0,
    rotationFastStep = 5.0,
    cropStep = 0.005,
    cropFastStep = 0.02,

    -- ACE continua disponivel como camada opcional, mas a autoridade principal
    -- e o mesmo passaporte de dono usado pelo af_owner_panel.
    requireAce = false,
    ace = 'af_youtube_tv.admin'
}

Config.Audio = {
    enabled = true,
    mode = 'dui_proximity',
    innerRadius = 4.0,
    maximumDistance = 55.0,
    minimumDistance = 5.0,
    maximumAllowedDistance = 150.0,
    falloffExponent = 1.6,
    updateInterval = 100,
    minimumVolumeChange = 1,
    maximumApplyInterval = 1000,
    occlusionInterval = 400,
    fadeInTime = 0.8,
    fadeOutTime = 1.2,
    occlusionEnabled = true,
    occludedMultiplier = 0.35,
    differentInteriorMultiplier = 0.20,
    debug = false
}

Config.Access = {
    ownerPassport = 1,
    rateLimitMs = 250,
    urlRateLimitMs = 1500,
    editRateLimitMs = 75,
    maximumCoordinate = 10000.0,
    minimumZ = -500.0,
    maximumZ = 2000.0
}

Config.Autoplay = true
Config.Muted = true
Config.Loop = false
Config.StartOnResourceStart = false
Config.ShowChatMessages = true
Config.DebugLogs = true
