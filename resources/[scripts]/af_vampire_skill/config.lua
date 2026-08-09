Config = {}

Config.Debug = false
Config.MultiplayerDebug = false
Config.Permission = "Vampire"

Config.ToggleCommand = "vampiro"
Config.DrainCommand = "sugar"
Config.DrainKey = "E"

Config.Range = 1.8
Config.NpcSearchRange = 3.5
Config.FinalRange = 2.2
Config.Duration = 2500
Config.Cooldown = 60
Config.TargetCooldown = 30
Config.RequestInterval = 750
Config.NpcControlTimeout = 800
Config.NpcVehicleExitTimeout = 2500
-- O servidor nao consegue validar a existencia de um ped puramente local.
-- O fallback permanece visual, com cooldown, mas nunca concede cura.
Config.LocalNpcFallbackHeal = 0

Config.PlayerDamage = 25
Config.PlayerHeal = 25
Config.NpcDamage = 40
Config.NpcHeal = 20
Config.MinimumVictimHealth = 125
Config.MinimumNpcHealth = 110
Config.MinimumAttackerHealth = 101

-- GTA accepts a reliable sprint multiplier between 1.0 and 1.49.
Config.SpeedMultiplier = 1.35
Config.EnableSuperJump = true
Config.SuperJumpCharges = 5
Config.SuperJumpRechargeSeconds = 120
-- Compatibilidade com a configuracao antiga. O salto novo usa
-- Config.VampireJump.VerticalBoost abaixo.
Config.SuperJumpVerticalVelocity = 18.0

Config.VampireJump = {
	Enabled = true,
	-- Velocidade vertical final do impulso. Faixa recomendada: 14.0 a 18.0.
	VerticalBoost = 16.0,
	MinimumInterval = 350
}

Config.FallProtection = {
	Enabled = true,
	MinimumHeight = 2.8,
	MinimumFallVelocity = -3.5,
	LandingGraceMs = 350
}

Config.AllowPlayerDrain = true
Config.AllowNpcDrain = true
Config.ProtectAdmins = true
Config.RespectSafezoneState = true

Config.TestNpc = {
	Enabled = true,
	SpawnCommand = "vampnpc",
	RemoveCommand = "removervampnpc",
	Model = "a_m_m_business_01",
	DistanceAhead = 1.8
}

Config.Anim = {
	Dict = "anim@gangops@hostage@",
	Attacker = "perp_idle",
	Victim = "victim_idle",
	NpcVictimDict = "amb@world_human_bum_standing@twitchy@base",
	NpcVictim = "base",
	VictimReactionDict = "reaction@shove",
	VictimReaction = "shoved_back",
	ScreenEffect = "Rampage"
}

-- O fogo solar e visual; o dano e aplicado de forma controlada no client.
Config.Sunlight = {
	Enabled = true,
	StartHour = 6,
	EndHour = 19,
	Damage = 1,
	-- 1 ponto de dano a cada 5 segundos enquanto exposto ao sol.
	DamageInterval = 5000,
	CheckInterval = 500,
	ReplicatedState = "af:vampireBurning",
	StateUpdateInterval = 250,
	FxReconcileInterval = 1000,
	MinimumHealth = 125,
	-- Particulas visuais. Fogo nativo do GTA NAO e usado porque aplica
	-- dano proprio descontrolado independente do valor configurado.
	VisualAsset = "core",
	-- Nunca use particula de chama aqui: algumas variantes acionam o dano
	-- nativo do GTA. O efeito solar usa somente fumaca leve e inofensiva.
	VisualFlame = false,
	VisualFlameScale = 0.0,
	VisualFlameInterval = 2500,
	VisualSparks = false,
	VisualSparkScale = 0.0,
	VisualSmoke = "ent_anim_cig_smoke",
	VisualSmokeScale = 1.75,
	ScreenRedFlash = false,
	ScreenRedInterval = 4000,
	UmbrellaItem = "umbrella",
	-- Usa o mesmo emote base /e chuva, incluindo o attach nativo do prop.
	UmbrellaEmote = "chuva",
	UmbrellaAnimation = {
		Dict = "amb@world_human_drinking@coffee@male@base",
		Name = "base",
		Flag = 50
	}
}

Config.BlockedZones = {
	{ name = "Hospital Central", coords = vector3(-676.9,312.16,83.09), radius = 85.0 },
	{ name = "Centro Medico", coords = vector3(350.97,-1429.29,32.42), radius = 55.0 }
}
