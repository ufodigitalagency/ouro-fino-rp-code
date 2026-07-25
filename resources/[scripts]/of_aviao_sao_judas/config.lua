Config = {}

Config.Debug = false
Config.Permission = "SaoJudas"

Config.Start = vector4(-215.02,1541.95,345.22,73.71)

Config.StartNpc = {
    Model = "g_m_y_mexgoon_02",
    Scenario = "WORLD_HUMAN_SMOKING",
    ZOffset = -1.0
}

Config.StartBlip = {
    Name = "Aviãozinho - São Judas",
    Sprite = 280,
    Colour = 2,
    Scale = 0.52,
    ShortRange = true
}

Config.Route = {
    Deliveries = 5,
    CooldownSeconds = 30 * 60,
    AccessRefreshSeconds = 15,
    BlipColour = 2
}

Config.Delivery = {
    TargetRadius = 0.9,
    TargetDistance = 1.8,
    CustomerZOffset = -1.0,
    ServerDistance = 4.0,
    StartServerDistance = 4.0,
    MinimumIntervalSeconds = 5,
    ReservationSeconds = 12,
    AnimationMinimumMs = 1800,
    AnimationDurationMs = 2600
}

Config.Payment = {
    Item = "dirtydollar",
    Minimum = 200,
    Maximum = 300
}

Config.Police = {
    Chance = 15,
    Permission = "Policia",
    Name = "Denúncia de tráfico",
    WantedSeconds = 60,
    Code = 20,
    Colour = 16,
    NotifyPlayer = false
}

Config.Animation = {
    Dictionary = "mp_common",
    Player = "givetake1_a",
    Customer = "givetake1_b"
}

Config.PackageProp = {
    Enabled = true,
    Model = "prop_cs_package_01",
    Bone = 57005,
    Offset = vector3(0.12,0.02,-0.02),
    Rotation = vector3(-90.0,0.0,0.0)
}

Config.CustomerModels = {
    "a_m_y_business_02",
    "a_m_y_hipster_01",
    "a_m_m_bevhills_02",
    "a_f_y_business_01",
    "a_f_y_hipster_02",
    "a_f_m_bevhills_01"
}

-- Pontos reaproveitados das rotas funcionais do resource deliver.
Config.Destinations = {
    vector4(-513.92,-1019.31,23.47,91.0),
    vector4(-536.48,-45.61,42.57,176.0),
    vector4(-53.01,79.35,71.62,154.0),
    vector4(581.16,139.13,99.48,248.0),
    vector4(814.39,-93.48,80.60,242.0),
    vector4(1070.71,-780.46,58.36,178.0),
    vector4(1142.82,-986.58,45.91,279.0),
    vector4(343.13,-1297.91,32.51,319.0),
    vector4(485.92,-1477.41,29.29,302.0),
    vector4(-723.33,-1112.41,10.66,124.0),
    vector4(-842.54,-1128.21,7.02,115.0),
    vector4(488.46,-898.56,25.94,87.0),
    vector4(-350.03,-1569.90,25.23,211.0),
    vector4(182.93,-2027.68,18.28,163.0),
    vector4(-1109.76,-1690.72,4.36,126.0)
}
