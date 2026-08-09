Config = {}

-- Temporariamente ativo para calibrar o visual e validar a sessao networkada.
Config.Debug = true
Config.OwnerPassport = 1
Config.Permission = "Bruxo"
Config.Command = "vassoura"

Config.ModelMode = "native_proxy"
Config.BroomModel = "of_magic_broom"

Config.Proxy = {
	-- O proxy privado preserva o handling/voo da Oppressor2, mas usa o
	-- layout de motocicleta da Nimbus que alinhou as maos no teste networkado.
	VehicleModel = "of_broom_proxy",
	VisualModel = "of_magic_broom",
	PoseTestModel = "of_broom_proxy",
	VisualCollision = false
}

Config.ProxyVisual = {
	-- Ponto inicial de calibracao: aproxima o cabo da Nimbus das maos
	-- da animacao nativa da Oppressor sem alterar o assento ou a fisica.
	Offset = vector3(0.0,0.02,0.12),
	Rotation = vector3(-5.0,0.0,0.0),
	BoostOffset = vector3(0.0,-1.2,0.05),
	VisualCollision = false
}

Config.Spawn = {
	ForwardDistance = 2.0,
	Height = 1.0,
	MountTimeout = 8000,
	ModelLoadTimeout = 8000,
	PendingTimeout = 12000,
	VisualReadyTimeout = 6000,
	StagingDepth = 60.0
}

Config.Flight = {
	MaximumAltitude = 300.0,
	MaximumWorldHeight = 700.0
}

Config.GroundStability = {
	Enabled = true,
	-- A Nimbus visual e apenas uma casca anexada. Desativar sua dinamica
	-- evita pequenos trancos e dessincronizacao em curvas no chao.
	DisableVisualDynamics = true,
	-- Recuperacao conservadora: so atua quando o proxy esta quase parado
	-- e ja inclinou demais. Nao interfere nas curvas normais nem no voo.
	RecoveryEnabled = true,
	MaximumGroundDistance = 1.35,
	MaximumRecoverySpeed = 2.8,
	RecoveryRoll = 38.0,
	RecoveryCooldownMs = 1200
}

Config.Boost = {
	Enabled = true,
	Key = "X",
	DurationMs = 1600,
	-- Intervalo total entre o inicio de dois impulsos. Com 3200 ms,
	-- restam aproximadamente 1.6 s de recarga depois do efeito de 1.6 s.
	CooldownMs = 3200,
	NativeRocketBoost = true,
	ExtraForwardImpulse = true,
	ImpulseStrength = 8.5,
	MaximumSpeed = 78.0,
	CameraShake = 0.30,
	MotionBlur = true,
	ScreenEffect = true,
	ParticleEffect = true,
	SoundEffect = false
}

Config.BoostEffects = {
	Dictionary = "core",
	Effect = "ent_sht_electrical_box",
	Offset = vector3(0.0,-1.2,0.05),
	Rotation = vector3(0.0,0.0,0.0),
	Scale = 0.75
}

Config.Landing = {
	MaximumDismountHeight = 1.8,
	MaximumDismountSpeed = 2.5,
	AutomaticDescentSpeed = 6.0,
	GroundProbeDistance = 450.0,
	Timeout = 20000
}

Config.Restrictions = {
	AllowInSafeZones = true,
	AllowBoostInSafeZones = true,
	DisableWeaponsWhileMounted = true,
	BlockStreetRace = true,
	BlockInteriors = true,
	BlockUnderwater = true,
	BlockWhenDead = true
}

Config.Security = {
	RequestInterval = 750,
	HeartbeatInterval = 1000,
	HeartbeatTimeout = 12000,
	MonitorInterval = 1000,
	MaximumNativeSpeed = 80.0,
	MaximumSpeedTolerance = 1.35,
	MaximumAltitudeTolerance = 40.0,
	MaximumViolations = 3
}

Config.Controls = {
	Land = 75
}

Config.Effects = {
	Enabled = true,
	MaximumDistance = 120.0,
	Asset = "core",
	Summon = "ent_sht_electrical_box",
	Dismiss = "ent_sht_electrical_box",
	Boost = "ent_dst_elec_fire_sp",
	Scale = 1.0
}

Config.Hud = {
	Enabled = true,
	UpdateInterval = 100,
	Anchor = "top-left",
	LeftOffset = 24,
	TopOffset = 110,
	Width = 270,
	Scale = 1.0
}

Config.DebugCommands = {
	Status = "vassoura_debug",
	SpawnModel = "vassoura_spawnmodel",
	MountTest = "vassoura_mounttest",
	Remount = "vassoura_remontar",
	Cleanup = "vassoura_cleanup",
	Proxy = "vassoura_proxydebug",
	Visual = "vassoura_visualdebug",
	Offset = "vassoura_offset",
	Rotation = "vassoura_rotacao",
	SaveOffset = "vassoura_salvaroffset",
	OffsetDebug = "vassoura_offsetdebug",
	HudPosition = "vassoura_hudpos",
	ProxyPoseTest = "vassoura_proxy_pose_test",
	ProxyLocalTest = "vassoura_proxy_localtest",
	ProxyNetworkTest = "vassoura_proxy_networktest",
	ProxyDiagnostic = "vassoura_proxy_diag"
}
