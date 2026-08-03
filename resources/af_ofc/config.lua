Config = {}

Config.Debug = false

Config.PublicNpc = {
	Model = "s_m_m_bouncer_01",
	Coords = vec4(-541.55,-1681.05,19.31,17.01),
	Scenario = "WORLD_HUMAN_GUARD_STAND",
	SpawnTimeout = 10000,
	SpawnDistance = 75.0,
	SpawnCheckInterval = 2000,
	TargetRadius = 0.90,
	TargetDistance = 2.0
}

Config.OrganizerDesk = {
	Enabled = true,
	Coords = vec4(-498.8734,-1714.0134,19.8992,285.41),
	TargetRadius = 0.65,
	TargetDistance = 2.0
}

Config.Gong = {
	Enabled = true,
	Coords = vec3(-522.6145,-1714.2679,19.3278),
	TargetRadius = 0.65,
	TargetDistance = 2.0,
	ServerMaximumDistance = 3.0,
	NearbyRadius = 35.0,
	RequireBothCheckIns = true,
	Sound = {
		Enabled = false
	}
}

Config.CageCenter = vec3(-518.31,-1712.32,20.00)
Config.Entrance = vec4(-507.49,-1725.20,19.33,31.19)

Config.Interaction = {
	ServerMaximumDistance = 3.0,
	ClientCloseDistance = 4.0,
	ClientValidationInterval = 750,
	SessionTimeout = 300,
	ActionTokenTimeout = 10
}

Config.RateLimits = {
	OpenPublic = 900,
	OpenOrganizer = 1000,
	CheckIn = 1500,
	AttemptBet = 1200,
	CreateEvent = 1500,
	AnnounceEvent = 15000,
	OpenBets = 1200,
	CloseBets = 1200,
	CancelEvent = 1200,
	StartFight = 1200,
	GongAuthorization = 750,
	RingGong = 8000,
	CloseSession = 250
}

Config.Event = {
	TitleMinimumLength = 3,
	TitleMaximumLength = 48,
	PassportMinimum = 1,
	PassportMaximum = 2147483647
}

Config.Financial = {
	Enabled = false
}

Config.DemoBet = {
	MinimumInput = 1,
	MaximumInput = 999999999
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

Config.OperationalTexts = {
	Target = {
		RingGong = "Lutem!"
	},
	Notifications = {
		EventAlreadyActive = "Já existe um evento ativo no OFC.",
		NoActiveEvent = "Não existe evento ativo no OFC.",
		InvalidEventData = "Informe um título válido e dois passaportes online diferentes.",
		InvalidTransition = "Esta ação não é permitida no estado atual do evento.",
		EventCreated = "Evento criado e mantido temporariamente em memória.",
		EventAnnounced = "Luta anunciada para toda a cidade.",
		BetsOpened = "Período de apostas aberto. A movimentação financeira segue desabilitada.",
		BetsClosed = "Período de apostas fechado.",
		EventCancelled = "Evento cancelado e dados temporários removidos.",
		CheckInComplete = "Check-in confirmado para o combate atual.",
		CheckInAlreadyComplete = "Seu check-in já estava confirmado.",
		BothCheckInsRequired = "Os dois lutadores precisam concluir o check-in antes do gongo.",
		GongReadyNoAudio = "Gongo autorizado. O áudio está desabilitado porque não há asset local aprovado.",
		FightSignal = "Lutem!",
		AutomaticFightPreparing = "O controle automático do combate ainda está sendo preparado.",
		TemporaryState = "O estado do evento é temporário e volta ao modo ocioso após restart do resource."
	},
	Interface = {
		OrganizerDescription = "Central operacional temporária. O estado é mantido somente em memória.",
		PhaseValue = "MARCO OPERACIONAL // MEMÓRIA",
		FutureActions = "GESTÃO DO EVENTO",
		CloseBets = "FECHAR APOSTAS",
		Locked = "ESTADO AUTORITATIVO",
		CreateEventTitle = "CRIAR NOVO EVENTO",
		EventTitleLabel = "TÍTULO DO EVENTO",
		EventTitlePlaceholder = "NOITE DE ESTREIA",
		FighterAPassport = "PASSAPORTE DO LUTADOR A",
		FighterBPassport = "PASSAPORTE DO LUTADOR B",
		ConfirmCreate = "CRIAR EVENTO",
		CancelForm = "VOLTAR",
		CancelConfirmationTitle = "CANCELAR EVENTO?",
		CancelConfirmationText = "O evento, os lutadores e os check-ins serão removidos. Não há reembolso porque as finanças estão desabilitadas.",
		ConfirmCancel = "SIM, CANCELAR",
		KeepEvent = "MANTER EVENTO",
		IdleEvent = "AGUARDANDO NOVO EVENTO",
		StatusIdle = "OCIOSO",
		StatusDraft = "RASCUNHO",
		StatusAnnounced = "ANUNCIADO",
		StatusBettingOpen = "APOSTAS ABERTAS",
		StatusBettingClosed = "APOSTAS FECHADAS"
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
