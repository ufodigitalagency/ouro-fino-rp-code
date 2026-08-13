Config = {}

Config.Debug = false
Config.DefaultCategory = "B"

Config.Categories = {
    A = {
        Label = "Categoria A",
        Description = "Motocicletas."
    },
    B = {
        Label = "Categoria B",
        Description = "Automoveis e veiculos leves."
    },
    C = {
        Label = "Categoria C",
        Description = "Veiculos de carga."
    },
    D = {
        Label = "Categoria D",
        Description = "Veiculos de transporte de passageiros."
    }
}

Config.Admin = {
    Permission = "Admin"
}

Config.Instructor = {
    Coords = vec4(-2290.48,364.09,174.60,36.86),
    GroundFallbackZ = 173.6017,
    -- Compensates the visual sole position of this model/scenario; it is not part of ground detection.
    VisualZOffset = -0.22,
    Model = "s_m_m_autoshop_01",
    Scenario = "WORLD_HUMAN_CLIPBOARD",
    CreateTimeoutMs = 5000,
    ConfigureTimeoutMs = 5000,
    GroundResolveTimeoutMs = 5000,
    ConfigureRetryMs = 5000,
    TargetRadius = 0.85,
    TargetDistance = 2.0,
    RespawnDebounceMs = 5000,
    HealthCheckMs = 2000,
    MissingChecksBeforeRespawn = 3
}

Config.Exam = {
    Category = "B",
    VehicleModel = "sentinel3",
    MaxSpeedKmh = 50.0,
    StartServerDistance = 4.0,
    VehicleRegistrationDistance = 2.0,
    SpawnOccupancyRadius = 2.5,
    SpawnReservationSeconds = 30,
    SessionTimeoutSeconds = 15 * 60,
    ModelTimeoutMs = 10000,
    VehicleNetworkTimeoutMs = 3000,
    ServerVehicleTimeoutMs = 5000,
    ClientWatchdogMs = 250,
    LimiterRefreshMs = 750,
    ServerWatchdogMs = 2000,
    SpawnSlots = {
        vec4(-2295.38,375.78,173.99,110.56),
        vec4(-2283.48,407.87,173.79,124.73),
        vec4(-2285.92,410.63,173.79,133.23)
    }
}

Config.Checklist = {
    WAITING_FOR_DRIVER = "Entre no veiculo da Autoescola e sente-se no banco do motorista.",
    WAITING_FOR_SEATBELT = "Coloque o cinto de seguranca.",
    WAITING_FOR_ENGINE = "Ligue o motor.",
    WAITING_FOR_LIGHTS = "Ligue os farois.",
    READY_FOR_ROUTE = "Preparacao concluida. Estrutura da prova pratica pronta."
}

-- As rotas reais serao cadastradas apenas depois da coleta e validacao runtime.
Config.Routes = {
    -- Route01 = {
    --     Name = "Rota media 01",
    --     Enabled = true,
    --     Weight = 1,
    --     Checkpoints = {
    --         {
    --             Coords = vec3(0.0,0.0,0.0),
    --             SpeedLimit = 50.0,
    --             StopRequired = false,
    --             TrafficLightZone = nil
    --         }
    --     },
    --     ReturnToParking = vec3(0.0,0.0,0.0)
    -- }
}

Config.ParkingTest = {
    Enabled = false,
    FrontVehicle = vec4(-2343.03,380.27,174.04,116.23),
    CandidateCenter = vec4(-2338.02,382.61,173.79,113.39),
    RearVehicle = vec4(-2332.78,385.07,173.99,110.56),
    PositionTolerance = 1.25,
    HeadingTolerance = 8.0,
    StopConfirmationMs = 3000,
    TimeoutSeconds = 180,
    EntryMustBeReverse = true,
    ImmediateFailOnContact = true
}

Config.ResultUi = {
    DurationMs = 6500
}
