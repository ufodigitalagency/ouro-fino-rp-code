Config = {}

Config.Debug = false
-- TEMPORARY: remove after the final road checkpoints are captured and approved.
Config.DebugRouteRecorder = true
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
    },
    Route = {
        StartDelayMs = 1200,
        DefaultRadius = 6.0,
        Blip = {
            Sprite = 1,
            Color = 5,
            RouteColor = 5,
            Scale = 0.85
        },
        Marker = {
            Type = 1,
            DrawDistance = 80.0,
            Height = 1.0,
            Red = 216,
            Green = 173,
            Blue = 85,
            Alpha = 150
        },
        -- Intentionally empty until the road course is captured and approved in runtime.
        Checkpoints = {}
    },
    Parking = {
        Center = vec4(-2338.02,382.61,173.79,113.39),
        FrontReference = vec4(-2343.03,380.27,174.04,116.23),
        RearReference = vec4(-2332.78,385.07,173.99,110.56),
        PositionTolerance = 1.25,
        HeadingTolerance = 8.0,
        HoldMs = 3000,
        TimeoutMs = 180000,
        RequireReverse = true,
        StoppedSpeedMps = 0.15,
        ReverseSpeedMps = 0.20,
        ValidationIntervalMs = 100,
        FeedbackThrottleMs = 4000,
        Blip = {
            Sprite = 1,
            Color = 5,
            RouteColor = 5,
            Scale = 0.85
        },
        Marker = {
            Type = 1,
            DrawDistance = 80.0,
            CenterHeight = 0.35,
            ReferenceRadius = 0.45,
            ReferenceHeight = 1.25,
            Red = 216,
            Green = 173,
            Blue = 85,
            Alpha = 150
        }
    }
}

Config.Checklist = {
    WAITING_FOR_DRIVER = "Entre no veiculo da Autoescola e sente-se no banco do motorista.",
    WAITING_FOR_SEATBELT = "Coloque o cinto de seguranca.",
    WAITING_FOR_ENGINE = "Ligue o motor.",
    WAITING_FOR_LIGHTS = "Ligue os farois.",
    READY_FOR_ROUTE = "Percurso liberado. Siga a rota indicada."
}

Config.ResultUi = {
    DurationMs = 6500
}
