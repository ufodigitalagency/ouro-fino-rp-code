VehicleFlipConfig = {
	Enabled = true,
	Commands = {
		"desvirar",
		"flip"
	},
	SearchRadius = 10.0,
	MaximumDistance = 4.5,
	MaximumServerCenterDistance = 10.0,
	MaximumVehicleSpeed = 1.5,
	MinimumOverturnedAngle = 55.0,
	Duration = 5000,
	Cooldown = 8000,
	SessionTimeout = 12000,
	NetworkControlTimeout = 1500,
	RequireDuty = true,
	RequireEmptyVehicle = true,
	LiftHeight = 0.45,
	Price = 0,
	Debug = MechanicConfig and MechanicConfig.Debug == true,
	OwnerPassport = 1,
	DebugCommands = {
		Test = "mec_fliptest",
		Overlay = "mec_flipdebug"
	}
}
