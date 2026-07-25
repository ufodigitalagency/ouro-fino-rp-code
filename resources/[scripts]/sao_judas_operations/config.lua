SaoJudasOperations = {
    Group = "SaoJudas",
    LeaderLevel = 1,
    DistributionRole = {
        Id = "SaoJudasDistribuicao",
        Label = "Operador de Distribuição",
        TagName = "Operador de Distribuição"
    },
    LaboratoryRole = {
        Id = "SaoJudasLaboratorio",
        Label = "Operador de Laboratório",
        TagName = "Operador de Laboratório"
    },
    WorkbenchRole = "Operador de Fabricação",

    Workbench = {
        Enabled = true,
        RecipesEnabled = true,
        ExclusiveRecipes = true,
        TargetCoords = vector3(-480.5672,1614.7445,369.4934),
        PlayerCoords = vector4(-480.64,1613.86,369.58,0.0),
        TargetRadius = 0.75,
        InteractionDistance = 1.5,
        ServerDistance = 3.0,
        MaximumBatch = 5,
        QueueCapacity = 1,
        SessionTimeoutSeconds = 120,
        DismantleDailyLimit = 10,
        Animation = {
            Dictionary = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@",
            Name = "machinic_loop_mechandplayer",
            Flag = 49
        },
        AnimationMonitor = {
            Enabled = true,
            StartupGraceMs = 750,
            MissingGraceMs = 750,
            CompletionIgnoreWindowMs = 1000,
            CheckIntervalMs = 150,
            CompletionToleranceMs = 350
        },
        Recipes = {
            lockpick = {
                Amount = 1,
                Duration = 10000,
                MaximumBatch = 5,
                Required = {
                    copper = 30,
                    aluminum = 30,
                    sheetmetal = 2
                }
            },
            blocksignal = {
                Amount = 1,
                Duration = 12000,
                MaximumBatch = 2,
                Required = {
                    plastic = 80
                }
            },
            dismantle = {
                Amount = 1,
                Duration = 12000,
                MaximumBatch = 2,
                Required = {
                    plastic = 25,
                    dirtydollar = 975
                }
            },
            lockpickplus = {
                Amount = 1,
                Duration = 20000,
                MaximumBatch = 1,
                Required = {
                    lockpick = 5,
                    copper = 100,
                    aluminum = 100,
                    sheetmetal = 10,
                    metalspring = 2,
                    electroniccomponents = 4
                }
            },
            WEAPON_CROWBAR = {
                Amount = 1,
                Duration = 15000,
                MaximumBatch = 1,
                Required = {
                    sheetmetal = 4,
                    aluminum = 20,
                    metalspring = 1
                }
            }
        }
    },

    FinancialVault = {
        Enabled = true,
        Coords = vector3(-479.68,1609.96,369.58),
        Heading = 184.26,
        TargetRadius = 0.75,
        InteractionDistance = 1.5,
        ServerDistance = 3.0,
        ManualDirtyDeposit = {
            Enabled = true,
            MinimumAmount = 1,
            MaximumPerTransaction = 500000,
            CooldownSeconds = 3,
            LeaderOnly = true
        }
    },

    Laboratory = {
        Enabled = true,
        Coords = vector3(-482.9467,1613.3351,369.3726),
        TargetRadius = 0.65,
        InteractionDistance = 1.5,
        ServerDistance = 2.5,
        ExclusiveSaoJudasLaboratory = false
    },

    Debug = false
}
