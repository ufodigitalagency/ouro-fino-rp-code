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

Config.Evaluator = {
    Enabled = true,
    Coords = vec4(-2334.07,387.16,174.60,167.25),
    GroundFallbackZ = 173.90,
    VisualZOffset = -0.22,
    Model = "s_m_m_autoshop_01",
    Scenario = "WORLD_HUMAN_CLIPBOARD",
    CreateTimeoutMs = 5000,
    ConfigureTimeoutMs = 5000,
    GroundResolveTimeoutMs = 5000,
    ConfigureRetryMs = 5000,
    RespawnDebounceMs = 5000,
    HealthCheckMs = 2000,
    MissingChecksBeforeRespawn = 3
}

Config.Exam = {
    Category = "B",
    VehicleModel = "sentinel3",
    MaxSpeedKmh = 50.0,
    Scoring = {
        StartingPoints = 3
    },
    Infractions = {
        -- Shared window prevents one crash + the rollover caused by that same crash from charging twice.
        PhysicalIncidentCooldownMs = 2500,
        Collision = {
            Enabled = true,
            -- Intentionally sensitive: even a small pole/curb impact should cost one point.
            BodyHealthDrop = 0.5,
            EngineHealthDrop = 0.5,
            MinimumSpeedMps = 0.35,
            MinimumSpeedDeltaMps = 0.15,
            RearmClearMs = 650,
            CooldownMs = 1000
        },
        Water = {
            Enabled = true,
            RearmClearMs = 1500,
            CooldownMs = 5000
        },
        Rollover = {

            Enabled = true,
            MinimumRollDegrees = 70.0,
            HoldMs = 1250,
            RecoveryHoldMs = 1500,
            CooldownMs = 5000
        }
    },
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
        Stop = {
            WarningDistance = 18.0,
            HoldRadius = 4.5,
            HoldMs = 2000,
            SpeedMps = 0.15,
            Penalty = 1,
            PassProjectionMeters = 0.5
        },
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
        Checkpoints = {
            { Coords = vec3(-2299.2698,475.8217,173.7578), Radius = 6.0, Label = "Ponto 1" },
            { Coords = vec3(-2145.7812,399.8969,135.5422), Radius = 6.0, Label = "Ponto 2" },
            { Coords = vec3(-2003.0409,131.8377,100.9889), Radius = 6.0, Label = "Ponto 3" },
            { Coords = vec3(-1808.2689,72.3628,71.0404), Radius = 6.0, Label = "Ponto 4", StopRequired = true },
            { Coords = vec3(-1779.0399,64.7816,68.3278), Radius = 6.0, Label = "Ponto 5" },
            { Coords = vec3(-1757.7206,65.0573,67.6389), Radius = 6.0, Label = "Ponto 6" },
            { Coords = vec3(-1595.3376,292.6775,57.5272), Radius = 6.0, Label = "Ponto 7" },
            { Coords = vec3(-1750.4303,249.5412,65.4708), Radius = 6.0, Label = "Ponto 8" },
            { Coords = vec3(-1827.5443,147.0405,77.0835), Radius = 6.0, Label = "Ponto 9", StopRequired = true },
            { Coords = vec3(-1848.5021,86.1217,78.0002), Radius = 6.0, Label = "Ponto 10" },
            { Coords = vec3(-2138.8445,401.0434,135.4923), Radius = 6.0, Label = "Ponto 11" },
            { Coords = vec3(-2310.8662,416.3783,173.9017), Radius = 6.0, Label = "Ponto 12" },

            -- Exact staging position immediately before reversing into the parking space.
            { Coords = vec3(-2343.3057,377.0819,173.9019), Radius = 2.5, Label = "Inicio da baliza" }
        },
        -- Hidden geometry from the complete captured route. Used only by the server anti-abuse corridor.
        CorridorAnchors = {
            { Coords = vec3(-2299.2698,475.8217,173.7578) },
            { Coords = vec3(-2145.7812,399.8969,135.5422) },
            { Coords = vec3(-2003.0409,131.8377,100.9889) },
            { Coords = vec3(-1808.2689,72.3628,71.0404) },
            { Coords = vec3(-1779.0399,64.7816,68.3278) },
            { Coords = vec3(-1757.7206,65.0573,67.6389) },
            { Coords = vec3(-1678.9906,111.1456,63.3248) },
            { Coords = vec3(-1500.5083,214.5021,58.8857) },
            { Coords = vec3(-1517.9240,235.4915,60.4641) },
            { Coords = vec3(-1595.3376,292.6775,57.5272) },
            { Coords = vec3(-1750.4303,249.5412,65.4708) },
            { Coords = vec3(-1827.5443,147.0405,77.0835) },
            { Coords = vec3(-1835.5773,123.8974,76.7221) },
            { Coords = vec3(-1833.5927,98.9690,74.4916) },
            { Coords = vec3(-1816.2979,74.9599,71.5511) },
            { Coords = vec3(-1848.5021,86.1217,78.0002) },
            { Coords = vec3(-2033.6007,181.0393,111.7222) },
            { Coords = vec3(-2138.8445,401.0434,135.4923) },
            { Coords = vec3(-2207.4355,568.2988,162.6942) },
            { Coords = vec3(-2310.8662,416.3783,173.9017) },
            { Coords = vec3(-2320.2808,394.1084,173.9017) },
            { Coords = vec3(-2343.3057,377.0819,173.9019) }
        }
    },
    AntiAbuse = {
        DriverSeatGraceMs = 15000,
        DriverSeatHeartbeatIntervalMs = 1000,
        DriverSeatHeartbeatFreshnessMs = 3000,
        NoProgressTimeoutMs = 180000,
        MaxRouteDeviationMeters = 120.0,
        OffRouteGraceMs = 10000
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
        ReservationRetryMs = 1500,
        WaitingAreaRadius = 25.0,
        WaitingAreaGraceMs = 10000,
        ReferenceVehicles = {
            Model = "asea",
            CreateTimeoutMs = 3000,
            ContactValidationDistance = 6.0
        },
        TrafficControl = {
            Enabled = true,
            Radius = 35.0,
            ObstructionRadius = 15.0,
            InspectIntervalMs = 1000,
            WanderSpeedMps = 8.0
        },
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
