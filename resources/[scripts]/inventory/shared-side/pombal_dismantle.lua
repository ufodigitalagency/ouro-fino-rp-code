PombalChopshop = {
    Permission = "Pombal",
    Enabled = true,
    Debug = true,

    Interaction = vector4(2545.0508,2591.9404,38.1714,296.59),
    InteractionRadius = 1.0,
    InteractionDistance = 1.8,
    ServerInteractionDistance = 3.5,

    Bays = {
        {
            Id = "pombal_bay_01",
            Label = "Vaga 1",
            VehicleCoords = vector4(2541.7397,2586.0786,37.4795,268.86),
            MaximumParkingDistance = 2.2,
            MaximumVerticalDifference = 1.5,
            MaximumHeadingDifference = 25.0,
            MaximumVehicleSpeed = 0.5
        },{
            Id = "pombal_bay_02",
            Label = "Vaga 2",
            VehicleCoords = vector4(2539.8096,2589.4773,37.4786,269.04),
            MaximumParkingDistance = 2.2,
            MaximumVerticalDifference = 1.5,
            MaximumHeadingDifference = 25.0,
            MaximumVehicleSpeed = 0.5
        }
    },

    Alignment = {
        Enabled = true,
        MaximumSnapDistance = 0.65
    },

    Session = {
        MaximumDurationSeconds = 15 * 60,
        MaximumVehicleDriftDistance = 4.5,
        PlayerVehicleDistance = 5.0,
        StartProximityGraceSeconds = 15,
        StageServerDistance = 4.0,
        StageDurationMs = 5500,
        StageCompletionToleranceMs = 500,
        MonitorIntervalMs = 2000
    },

    Animation = {
        Dictionary = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@",
        Name = "machinic_loop_mechandplayer"
    },

    Stages = {
        { Id = "wheel_lf", Bone = "wheel_lf", Label = "Remover roda dianteira esquerda", Type = "wheel", Index = 0, FallbackOffset = vector3(-0.85,1.25,-0.35) },
        { Id = "wheel_rf", Bone = "wheel_rf", Label = "Remover roda dianteira direita", Type = "wheel", Index = 1, FallbackOffset = vector3(0.85,1.25,-0.35) },
        { Id = "wheel_lr", Bone = "wheel_lr", Label = "Remover roda traseira esquerda", Type = "wheel", Index = 4, FallbackOffset = vector3(-0.85,-1.25,-0.35) },
        { Id = "wheel_rr", Bone = "wheel_rr", Label = "Remover roda traseira direita", Type = "wheel", Index = 5, FallbackOffset = vector3(0.85,-1.25,-0.35) },
        { Id = "door_dside_f", Bone = "door_dside_f", Label = "Remover porta esquerda", Type = "door", Index = 0, FallbackOffset = vector3(-1.0,0.15,0.0) },
        { Id = "door_pside_f", Bone = "door_pside_f", Label = "Remover porta direita", Type = "door", Index = 1, FallbackOffset = vector3(1.0,0.15,0.0) },
        { Id = "bonnet", Bone = "bonnet", Label = "Remover capo", Type = "door", Index = 4, FallbackOffset = vector3(0.0,1.85,0.15) },
        { Id = "engine", Bone = "engine", Label = "Remover motor", Type = "engine", FallbackOffset = vector3(0.0,1.25,0.15) },
        { Id = "boot", Bone = "boot", Label = "Remover porta-malas", Type = "door", Index = 5, FallbackOffset = vector3(0.0,-1.85,0.15) }
    }
}
