SaoJudasStreetSales = {
    Enabled = true,
    Group = "SaoJudas",
    Currency = "dirtydollar",
    TargetState = "SaoJudasStreetSalesEligible",

    Interaction = {
        MaximumDistance = 2.25,
        CompletionDistance = 2.75,
        AnimationDurationMs = 4500,
        SessionTtlSeconds = 35,
        EligibilityRefreshMs = 2500
    },

    StreetMode = {
        Enabled = true,
        Command = "venderdrogas",
        KeyDescription = "Ativar ou desativar o modo de venda de rua.",
        DefaultKey = "",
        -- O client sorteia um dos civis elegíveis mais próximos dentro deste raio.
        -- O servidor usa o mesmo alcance apenas para reservar a venda automática.
        SearchRadius = 14.0,
        RandomCandidatePool = 5,
        SearchIntervalMs = 1000,
        CandidateTimeoutMs = 16000,
        ApproachDistance = 1.6,
        PromptDistance = 2.15,
        InteractionControl = 38,
        AutomaticBuyersAlwaysAccept = true,

        -- Permite que o modo /venderdrogas funcione com o vendedor parado
        -- no banco do motorista. O comprador caminha ate a janela esquerda.
        VehicleSales = {
            Enabled = true,
            DriverOnly = true,
            MaximumSpeed = 0.35,
            WindowSideClearance = 0.45,
            WindowForwardOffset = 0.25,
            ArrivalTolerance = 0.90,
            ServerMaximumDistance = 4.00,
            CompletionDistance = 4.00
        },

        AllowedRoutingBuckets = {
            [0] = true
        }
    },

    Quantity = {
        Minimum = 1,
        Maximum = 3
    },

    Drugs = {
        joint = {
            Enabled = true,
            MinimumQuantity = 1,
            MaximumQuantity = 3,
            MinimumPrice = 75,
            MaximumPrice = 100
        },
        cocaine = {
            Enabled = true,
            MinimumQuantity = 1,
            MaximumQuantity = 3,
            MinimumPrice = 75,
            MaximumPrice = 100
        },
        meth = {
            Enabled = true,
            MinimumQuantity = 1,
            MaximumQuantity = 3,
            MinimumPrice = 75,
            MaximumPrice = 100
        },
        weedsack = {
            Enabled = true,
            MinimumQuantity = 1,
            MaximumQuantity = 1,
            MinimumPrice = 500,
            MaximumPrice = 625
        },
        cokesack = {
            Enabled = true,
            MinimumQuantity = 1,
            MaximumQuantity = 1,
            MinimumPrice = 500,
            MaximumPrice = 625
        },
        methsack = {
            Enabled = true,
            MinimumQuantity = 1,
            MaximumQuantity = 1,
            MinimumPrice = 500,
            MaximumPrice = 625
        }
    },

    Reactions = {
        Accept = 65,
        Refuse = 22,
        Report = 8,
        WalkAway = 5
    },

    Cooldowns = {
        PlayerSeconds = 8,
        PedSeconds = 1800,
        FailedAttemptSeconds = 5,
        AttemptsPerMinute = 8
    },

    Demand = {
        Low = { Weight = 20, Multiplier = 0.95, Label = "Procura baixa" },
        Normal = { Weight = 60, Multiplier = 1.00, Label = "Procura normal" },
        High = { Weight = 20, Multiplier = 1.05, Label = "Procura alta" }
    },

    Reputation = {
        Levels = {
            { Level = 1, Name = "Iniciante", MinimumSales = 0, PriceMultiplier = 1.00, AcceptBonus = 0 },
            { Level = 2, Name = "Conhecido", MinimumSales = 15, PriceMultiplier = 1.02, AcceptBonus = 2 },
            { Level = 3, Name = "Vendedor", MinimumSales = 40, PriceMultiplier = 1.04, AcceptBonus = 4 },
            { Level = 4, Name = "Distribuidor", MinimumSales = 90, PriceMultiplier = 1.06, AcceptBonus = 6 },
            { Level = 5, Name = "Referência", MinimumSales = 180, PriceMultiplier = 1.08, AcceptBonus = 8 }
        },
        MaximumPriceMultiplier = 1.08
    },

    Zones = {
        Default = { Name = "Cidade", Multiplier = 1.00 },
        Areas = {}
    },

    Revenue = {
        WorkerPercentage = 85,
        FactionPercentage = 15
    },

    Dispatch = {
        Enabled = false,
        ReportReactionChance = 100,
        GeneralWitnessChance = 5,
        MinimumPolice = 0,
        ApproximationGrid = 100.0
    },

    AllowedPedTypes = {
        [4] = true,
        [5] = true
    },

    Debug = {
        Enabled = true,
        OwnerPassport = 1,
        TargetLogCooldownMs = 10000
    }
}
