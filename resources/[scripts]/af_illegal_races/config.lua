Config = {}

Config.Debug = false
Config.Command = "racha"
Config.CancelCommand = "cancelarracha"

Config.ChallengeDistance = 8.0
Config.VehicleMaximumSpeedToChallenge = 8.0
Config.ChallengeTimeout = 30
Config.SetupTimeout = 120
Config.CountdownSeconds = 5
Config.RaceTimeout = 600
Config.VehicleExitGraceSeconds = 8
Config.CheckpointRadius = 18.0
Config.FinishRadius = 22.0
Config.MaximumPlausibleSpeed = 135.0
Config.CheckpointTimeTolerance = 2500

-- Checkpoints are validated from the canonical server route. The client only
-- detects a pass and asks the server to validate the next expected sequence.
Config.CheckpointValidation = {
	DetectionInterval = 50,
	MaximumVerticalDifference = 10.0,
	ServerRadiusTolerance = 3.0,
	PendingTimeout = 1500,
	Debug = false
}

-- Keep the start honest without freezing the car. Drivers can rev the engine
-- during the countdown, but brake/handbrake prevent an early launch.
Config.CountdownLock = {
	MaximumSpeed = 0.35,
	MaximumPositionDrift = 0.65,
	LockSteering = true,
	ArtificialRpmFallback = true,
	NpcRpmMinimum = 0.45,
	NpcRpmMaximum = 0.78,
	NpcRpmInterval = 350
}

Config.InitialPlayerStake = 1000
Config.MinimumPlayerStake = 100
Config.MaximumPlayerStake = 50000
Config.MinimumPolice = 0

Config.DistanceOptions = {
	Short = {
		Label = "Curta",
		Minimum = 1200.0,
		Maximum = 2500.0,
		Checkpoints = 1
	},
	Medium = {
		Label = "Media",
		Minimum = 3200.0,
		Maximum = 5200.0,
		Checkpoints = 3
	},
	Long = {
		Label = "Longa",
		Minimum = 5000.0,
		Maximum = 9000.0,
		Checkpoints = 3
	}
}

Config.PlayerRace = {
	AlertChance = 85,
	HouseFeePercent = 0
}

Config.Ranking = {
	Enabled = true,
	InitialRating = 1000,
	KFactor = 24,
	MinimumStake = 500,
	MinimumDistance = 1200.0,
	RecentOpponentWindow = 3600,
	RepeatOpponentMultiplier = 0.25,
	TopLimit = 50,
	CacheSeconds = 5
}

local NpcRaceDrivingFlags = {
	SwerveAroundAllVehicles = 4,
	SteerAroundStationaryVehicles = 8,
	SteerAroundPeds = 16,
	SteerAroundObjects = 32,
	DriveIntoOncomingTraffic = 512,
	UseShortCutLinks = 262144,
	ChangeLanesAroundObstructions = 524288
}

local NpcRaceDrivingStyle = 0
for _,Flag in pairs(NpcRaceDrivingFlags) do
	NpcRaceDrivingStyle = NpcRaceDrivingStyle + Flag
end

Config.NpcRace = {
	Enabled = true,
	Stake = 200,
	WinnerPayment = 400,
	Distance = "Short",
	Cooldown = 300,
	MaximumPaidWinsPerHour = 5,
	AlertChance = 35,
	Difficulty = "Normal",
	Difficulties = {
		Easy = { Speed = 32.0, Ability = 0.75, Aggressiveness = 0.65 },
		Normal = { Speed = 39.0, Ability = 0.90, Aggressiveness = 0.85 },
		Hard = { Speed = 46.0, Ability = 1.00, Aggressiveness = 1.00 }
	},
	-- StopForVehicles(1), StopForPeds(2) e StopAtTrafficLights(128) ficam deliberadamente ausentes.
	-- O valor final e composto pelas flags nomeadas acima, sem depender de um numero magico.
	DrivingFlags = NpcRaceDrivingFlags,
	DrivingStyle = NpcRaceDrivingStyle,
	CleanupDrivingStyle = 786603,
	StopRange = 8.0,
	TaskRefreshInterval = 12000,
	StuckCheckInterval = 3000,
	StuckMinimumSpeed = 1.5,
	StuckTimeout = 7000,
	MinimumDistanceImprovement = 3.0,
	MaximumRecoveryAttempts = 3,
	RecoverySpeedBonus = 3.0,
	ControlTimeout = 1500
}

Config.Dispatch = {
	Enabled = true,
	UpdatesEnabled = true,
	InitialDelayMinimum = 4,
	InitialDelayMaximum = 9,
	UpdateInterval = 25,
	UpdateChance = 60,
	RadiusMinimum = 130.0,
	RadiusMaximum = 250.0,
	RandomOffsetMinimum = 40.0,
	RandomOffsetMaximum = 160.0,
	BlipDuration = 35
}

Config.BlockedVehicleClasses = {
	[13] = true, -- Bicicletas
	[14] = true, -- Barcos
	[15] = true, -- Helicopteros
	[16] = true, -- Avioes
	[18] = true, -- Emergencia
	[21] = true  -- Trens
}

Config.BlockedVehicleModels = {}

Config.BlockedZones = {
	{ Label = "Hospital SAMU", Coords = vec3(-676.90,312.16,83.09), Radius = 85.0 },
	{ Label = "Departamento Policial", Coords = vec3(-434.8,1123.9,325.86), Radius = 90.0 },
	{ Label = "Concessionaria", Coords = vec3(-54.30,-1094.80,26.42), Radius = 75.0 },
	{ Label = "Bennys", Coords = vec3(-553.92,-929.12,23.86), Radius = 75.0 }
}

Config.Route = {
	AvoidDestinationRepeat = true,
	IntermediateProjectionWindow = 0.28,
	RequireForwardDestination = true,
	MinimumForwardDot = 0.20,
	PreferredForwardDot = 0.55,
	MinimumFirstCheckpointDot = 0.30,
	DirectionScoreWeight = 1800.0,
	MaximumStartHeadingDifference = 55.0,
	MaximumRandomCandidates = 3,
	FallbackMaximumMultiplier = 1.35,
	MinimumCheckpointSpacing = 500.0,
	UseForwardLaunchCheckpoint = true,
	ForwardLaunchDistance = 120.0,
	ForwardLaunchMinimum = 60.0,
	ForwardLaunchMaximum = 200.0,
	ForwardLaunchRadius = 16.0,
	ForwardLaunchNodeTolerance = 80.0,
	ForwardLaunchRequestTimeout = 2000
}

Config.OpponentBlip = {
	Enabled = true,
	PlayerRaces = true,
	NpcRaces = true,
	UpdateInterval = 750,
	StaleAfter = 3500,
	Sprite = 225,
	Color = 5,
	Scale = 0.85,
	ShortRange = false,
	ShowHeading = true,
	Name = "Adversario do racha",
	TestRadius = 60.0
}

Config.RouteAudit = {
	Enabled = true,
	AdminPassport = 1,
	IssueDataKey = "StreetRace:RouteIssues",
	ForwardLineDistance = 120.0
}

Config.TestMode = false
Config.TestAdminPassport = 1
Config.TestUseRealMoney = false
Config.TestConvar = "af_illegal_races_test"
