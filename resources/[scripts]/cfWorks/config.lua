Config = {}
Config.Debug = false

Config.Marker = {-268.53,-957.4,31.22}

Config.JobCenter = {
    pos = vec3(-268.53,-957.4,31.22),
    blip = {
        name = "Central de Empregos",
        sprite = 457,
        color = 3,
        scale = 0.8
    }
}

Config.Jobs = {
    {
        id = "lixeiro",
        name = "Lixeiro",
        description = "Colete o lixo da cidade e ganhe por produtividade.",
        payment = 150,
    },
    {
        id = "minerador",
        name = "Minerador",
        description = "Extraia minérios valiosos nas cavernas da cidade.",
        payment = 200,
    },
    {
        id = "eletricista",
        name = "Eletricista",
        description = "Conserte postes e pontos de energia pela cidade.",
        payment = 120,
    },
    {
        id = "entregador",
        name = "Entregador iFood",
        description = "Realize entregas rapidas pela cidade usando rotas marcadas no GPS.",
        payment = 95,
    },
    {
        id = "taxista",
        name = "Taxista",
        description = "Leve passageiros por pontos movimentados de Los Santos.",
        payment = 135,
    },
    {
        id = "motorista_onibus",
        name = "Motorista de Onibus",
        description = "Transporte passageiros entre os pontos da cidade.",
        payment = 20,
    }
}

Config.RouteJobs = {
    entregador = {
        payment = 95,
        xp = 60,
        cooldown = 2500,
        progressTime = 4500,
        progressText = "Entregando pedido...",
        markerText = "~g~[E]~w~ ENTREGAR PEDIDO",
        blipName = "Entrega iFood",
        blipColor = 2,
        blipSprite = 1,
        anim = { "mp_common", "givetake1_a" },
        points = {
            vec3(115.18,-1461.67,29.29),
            vec3(315.79,-128.92,69.98),
            vec3(-47.57,-1758.77,29.42),
            vec3(-712.68,-818.91,23.73),
            vec3(-1222.28,-907.67,12.33),
            vec3(1137.94,-981.23,46.42)
        }
    }
}

Config.Garbage = {
    garage = vec4(-322.24,-1545.83,31.02,90.71),
    uniform = vec4(-338.87,-1518.92,27.73,357.17),
    model = "trash",
    spawns = {
        vec4(-319.6002,-1519.5863,27.2664,180.08),
        vec4(-322.8192,-1519.5385,27.2584,180.63),
        vec4(-329.2468,-1519.1699,27.2474,179.99)
    },
    routePoints = {
        vec3(-174.5,-1661.75,33.25),
        vec3(23.49,-1903.58,22.38),
        vec3(543.8,-1784.41,28.88),
        vec3(-127.36,-1690.81,31.13),
        vec3(1011.82,-743.03,57.63),
        vec3(485.93,208.27,104.5),
        vec3(-1122.98,-1558.25,4.88),
        vec3(-1548.55,-284.44,48.25),
        vec3(308.43,-2091.70,17.50),
        vec3(-136.56,-1590.17,34.00)
    },
    props = {
        "prop_bin_01a", "prop_bin_05a", "prop_bin_06a", "prop_bin_07a", "prop_bin_08a",
        "prop_bin_08open", "prop_bin_09a", "prop_bin_10a", "prop_bin_11a", "prop_bin_beach_01d",
        "prop_dumpster_01a", "prop_dumpster_02a", "prop_dumpster_02b", "prop_dumpster_3a", "prop_dumpster_4a"
    },
    cooldown = 30000, -- 30 segundos para a lixeira "resetar"
    anim = { "amb@prop_human_bum_bin@base", "base" },
    item = "techtrash", -- Item que o jogador recebe
    amount = 2, -- Quantidade do item
    xpPerAction = 50, -- XP ganho por lixeira
    moneyPerAction = 15 -- Dinheiro ganho por lixeira
}

Config.GarbageDuo = {
    Enabled = true,
    Debug = false,
    InviteDistance = 10.0,
    TruckDistance = 15.0,
    DriverMustBeInTruck = true,
    PayDriverSameAmount = true,
    DriverPayMultiplier = 1.0,
    EnableRearRide = true,
    RearRideCommand = "subirlixeiro",
    InviteCommand = "lixeirodupla",
    AcceptCommand = "aceitarlixeiro",
    LeaveCommand = "sairlixeirodupla",
    InviteTimeout = 30,
    MaxSeparation = 45.0,
    SeparationTimeout = 20,
    CollectionCooldown = 4
}

Config.Minerador = {
    AreaInicio = vec3(2952.93,2804.77,41.67),
    Locais = {
        { coords = vec3(2937.79,2772.08,39.73), id = 1 },
        { coords = vec3(2948.77,2768.04,38.94), id = 2 },
        { coords = vec3(2956.41,2771.32,39.36), id = 3 },
        { coords = vec3(2970.89,2774.01,38.16), id = 4 },
        { coords = vec3(2972.5,2797.48,41.2), id = 5 },
        { coords = vec3(2949.33,2819.25,42.63), id = 6 },
        { coords = vec3(2939.85,2813.73,42.8), id = 7 },
        { coords = vec3(2926.46,2793.91,40.66), id = 8 },
    },

    CooldownVolta = 30000,
    Item = "silverring",
    Qtd = math.random(1, 3),
    XP = 80,
    Pagamento = 40
}

Config.Eletricista = {
    props = {
        "prop_streetlight_07a",
        "prop_streetlight_05",
        "prop_streetlight_11c",
        "prop_streetlight_12b",
        "prop_oldlight_01a",
        "prop_streetlight_03d",
        "prop_streetlight_03e",
        "prop_ind_light_02a",
        "prop_streetlight_01b",
        "prop_streetlight_08",
        "prop_streetlight_01",
        "prop_snow_streetlight_09"
    },
    cooldown = 60000,
    Item = "copper",
    XP = 80,
    Pagamento = 45
}
