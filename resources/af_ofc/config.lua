Config = {}

Config.Debug = false

Config.PublicNpc = {
	Model = "s_m_m_bouncer_01",
	Coords = vec4(-541.55,-1681.05,19.31,17.01),
	Scenario = "WORLD_HUMAN_GUARD_STAND",
	SpawnTimeout = 10000,
	TargetRadius = 0.90,
	TargetDistance = 2.0
}

Config.OrganizerDesk = {
	Enabled = true,
	Coords = vec4(-498.8734,-1714.0134,19.8992,285.41),
	TargetRadius = 0.65,
	TargetDistance = 2.0
}

Config.CageCenter = vec3(-518.31,-1712.32,20.00)
Config.Entrance = vec4(-507.49,-1725.20,19.33,31.19)

Config.Interaction = {
	ServerMaximumDistance = 3.0,
	ClientCloseDistance = 4.0,
	ClientValidationInterval = 750,
	SessionTimeout = 300
}

Config.RateLimits = {
	OpenPublic = 900,
	OpenOrganizer = 1000,
	CheckIn = 1500,
	AttemptBet = 1200,
	OrganizerPreview = 900,
	CloseSession = 250
}

Config.Financial = {
	Enabled = false
}

Config.DemoBet = {
	MinimumInput = 1,
	MaximumInput = 999999999
}

Config.OrganizerPreviewActions = {
	create = true,
	announce = true,
	openBets = true,
	startFight = true,
	cancelEvent = true
}

Config.DemoEvent = {
	Revision = 1,
	Name = "NOITE DE ESTREIA",
	Status = "DEMONSTRAÇÃO",
	Schedule = "EM BREVE",
	DemoLabel = "VALORES DEMONSTRATIVOS",
	FighterA = {
		Name = "LUTADOR A",
		Corner = "CANTO VERMELHO",
		Pool = 125000,
		Odds = "1.85x DEMO"
	},
	FighterB = {
		Name = "LUTADOR B",
		Corner = "CANTO DOURADO",
		Pool = 98000,
		Odds = "2.10x DEMO"
	},
	CheckIns = {
		FighterA = false,
		FighterB = false
	}
}

Config.Texts = {
	Console = {
		NpcModelUnavailable = "[af_ofc] Não foi possível carregar o modelo de NPC %s.",
		PlayerCommandOnly = "[af_ofc] O comando /ofc está disponível somente para jogadores."
	},
	Target = {
		ViewEvent = "Ver evento do OFC",
		OpenBetting = "Abrir painel de apostas",
		CheckIn = "Fazer check-in",
		OrganizerPanel = "Painel do Organizador"
	},
	Notifications = {
		Title = "Ouro Fight Club",
		InvalidRequest = "Solicitação inválida.",
		InvalidSession = "Sua sessão do OFC não é mais válida.",
		InvalidCharacter = "Selecione um personagem válido antes de acessar o OFC.",
		InvalidState = "Você não pode acessar o OFC neste estado.",
		TooFar = "Aproxime-se do atendimento do OFC para continuar.",
		RateLimited = "Aguarde um instante antes de tentar novamente.",
		PermissionDenied = "Você não possui autorização para acessar o painel do organizador.",
		NotScheduled = "Você não está escalado para o combate atual.",
		FinancialPreparing = "O sistema financeiro do OFC ainda está sendo preparado.",
		ManagementPreparing = "A gestão de eventos do OFC ainda está sendo preparada.",
		NpcUnavailable = "O atendimento do OFC está temporariamente indisponível."
	},
	Interface = {
		BrandKicker = "OURO FINO ROLEPLAY APRESENTA",
		Brand = "OFC",
		BrandName = "OURO FIGHT CLUB",
		Close = "Fechar painel",
		PublicTab = "ARENA",
		OrganizerTab = "CONTROLE",
		LiveSignal = "SINAL CLANDESTINO // CANAL 01",
		Versus = "VS",
		Pool = "POOL DEMONSTRATIVO",
		Odds = "ODDS VISUAIS",
		ChooseFighter = "ESCOLHA SEU LADO",
		SelectedFighter = "LUTADOR SELECIONADO",
		NoSelection = "NENHUM",
		BetValue = "VALOR DA APOSTA",
		BetPlaceholder = "0",
		Currency = "R$",
		BetButton = "CONFIRMAR APOSTA",
		BetProcessing = "VALIDANDO...",
		SelectRequired = "Selecione um lutador antes de continuar.",
		FinancialWarning = "MODO DEMONSTRAÇÃO — NENHUM DINHEIRO SERÁ CONSULTADO, REMOVIDO OU ENTREGUE.",
		WarningSymbol = "!",
		OrganizerKicker = "CENTRAL DO ORGANIZADOR",
		OrganizerTitle = "OPERAÇÃO DA ARENA",
		OrganizerDescription = "Prévia operacional do Marco 1. Toda gestão permanece bloqueada.",
		EventStatus = "STATUS DO EVENTO",
		CheckInStatus = "CHECK-INS",
		CheckInSlots = "02",
		FighterA = "LUTADOR A",
		FighterB = "LUTADOR B",
		Pending = "PENDENTE",
		SystemStatus = "INDICADORES DE SISTEMA",
		SystemIndicators = "04",
		Backend = "BACKEND SERVER-SIDE",
		BackendValue = "ATIVO",
		Financial = "MOVIMENTAÇÃO FINANCEIRA",
		FinancialValue = "DESATIVADA",
		Database = "BANCO DE DADOS",
		DatabaseValue = "NÃO CONECTADO",
		Phase = "FASE DO PROJETO",
		PhaseValue = "MARCO 1 // DEMONSTRAÇÃO",
		FutureActions = "GESTÃO FUTURA",
		CreateEvent = "CRIAR EVENTO",
		Announce = "ANUNCIAR LUTA",
		OpenBets = "ABRIR APOSTAS",
		StartFight = "INICIAR COMBATE",
		CancelEvent = "CANCELAR EVENTO",
		Locked = "EM PREPARAÇÃO",
		ToastFallback = "Ação indisponível neste marco."
	}
}
