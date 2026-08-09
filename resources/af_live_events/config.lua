Config = {}

Config.LiveEvents = {
    -- Habilite em server.cfg somente depois de definir um segredo forte:
    -- set af_live_events_enabled "1"
    -- set af_live_events_secret "uma-senha-aleatoria-com-24-ou-mais-caracteres"
    Enabled = false,
    EnabledConvar = "af_live_events_enabled",
    SecretConvar = "af_live_events_secret",
    RequireStrongSecret = true,
    MinimumSecretLength = 24,
    MaximumPayloadBytes = 8192,
    MaximumRequestsPerMinute = 10,
    ActionCooldownMs = 3000,

    AllowedActions = {
        spawn_npc = true
    },

    -- Lista vazia aceita qualquer origem que apresente o segredo. Quando o
    -- bridge tiver IP fixo, informe os enderecos reais observados pelo servidor.
    AllowedRemoteAddresses = {}
}

-- O modelo e fixo no servidor; a requisicao HTTP nunca escolhe um ped.
Config.NpcModel = "a_m_m_business_01"
Config.MaximumActiveNpcs = 8
Config.NpcLifetimeSeconds = 60
Config.SpawnDistance = 3.0
Config.DrawDistance = 20.0
