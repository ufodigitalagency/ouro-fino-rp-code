Config = Config or {}

Config.Debug = false
Config.JobId = "motorista_onibus"
Config.BusModel = "bus"
Config.PlatePrefix = "BUS"
Config.SpawnReservationSeconds = 10
Config.PassengerSpawnDistance = 45.0
Config.PassengerSpawnRetryMs = 5000
Config.PassengerSidewalkOffset = 3.0
Config.PassengerBoardTimeoutMs = 2500
Config.VirtualPassengerFallback = true

Config.Depot = vector4(462.22, -641.15, 28.45, 175.0)
Config.Spawns = {
    vector4(462.22, -641.15, 28.45, 175.0)
}

Config.DepotBlip = {
    name = "Garagem de Onibus",
    sprite = 513,
    colour = 49,
    scale = 0.75,
    shortRange = true
}

Config.RouteBlip = {
    name = "Ponto de Onibus",
    sprite = 1,
    colour = 3,
    scale = 0.8,
    shortRange = false
}

Config.Payment = {
    min = 15,
    max = 25,
    cooldown = 3,
    stopDistance = 15.0
}

Config.Stops = {
    vector4(304.36, -764.56, 29.31, 252.09),
    vector4(-110.31, -1686.29, 29.31, 223.84),
    vector4(-712.83, -824.56, 23.54, 194.70),
    vector4(-692.63, -670.44, 30.86, 61.84),
    vector4(-250.14, -886.78, 30.63, 8.67)
}

Config.PassengerModels = {
    "a_f_m_skidrow_01",
    "a_f_y_business_01",
    "a_f_y_tourist_01",
    "a_m_m_business_01",
    "a_m_m_eastsa_01",
    "a_m_m_farmer_01",
    "a_m_m_genfat_01",
    "a_m_y_business_02",
    "a_m_y_hipster_01",
    "a_m_y_tourist_01"
}
