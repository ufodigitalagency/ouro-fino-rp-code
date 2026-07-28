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
        ProductionEnabled = true,
        Coords = vector3(-482.9467,1613.3351,369.3726),
        PlayerCoords = vector4(-482.9467,1613.3351,369.3726,0.0),
        TargetRadius = 0.65,
        InteractionDistance = 1.5,
        ServerDistance = 2.5,
        ExclusiveSaoJudasLaboratory = true,
        MaximumBatch = 5,
        QueueCapacity = 1,
        SessionTimeoutSeconds = 180,
        Durations = {
            Processing = 15000,
            Packaging = 10000
        },
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
            joint = {
                Amount = 1,
                DurationKey = "Processing",
                Required = {
                    weed = 1
                }
            },
            cocaine = {
                Amount = 1,
                DurationKey = "Processing",
                Required = {
                    coke = 1
                }
            },
            meth = {
                Amount = 5,
                DurationKey = "Processing",
                Required = {
                    saline = 1,
                    sulfuric = 1
                }
            },
            weedsack = {
                Amount = 1,
                DurationKey = "Packaging",
                Required = {
                    joint = 10
                }
            },
            cokesack = {
                Amount = 1,
                DurationKey = "Packaging",
                Required = {
                    cocaine = 10
                }
            },
            methsack = {
                Amount = 1,
                DurationKey = "Packaging",
                Required = {
                    meth = 10
                }
            }
        }
    },

    SulfuricSupplier = {
        Enabled = true,
        Coords = vector3(179.90,2779.98,45.70),
        ServerDistance = 3.0,
        Item = "sulfuric",
        Label = "Ácido Sulfúrico",
        UnitPrice = 100,
        MinimumAmount = 1,
        MaximumAmount = 5,
        CooldownSeconds = 30 * 60,
        LockTimeoutSeconds = 90,
        Blip = {
            Enabled = true,
            Name = "Contato Químico",
            Sprite = 1,
            Color = 5,
            Scale = 0.55,
            Display = 4,
            ShortRange = true,
            RefreshSeconds = 10
        }
    },

    Debug = false
}
