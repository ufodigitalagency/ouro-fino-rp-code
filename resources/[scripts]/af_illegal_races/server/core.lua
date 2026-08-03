-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Proxy = module("vrp","lib/Proxy")
local vRP = Proxy.getInterface("vRP")
-----------------------------------------------------------------------------------------------------------------------------------------
-- STATE
-----------------------------------------------------------------------------------------------------------------------------------------
local Challenges = {}
local ChallengeBySource = {}
local Sessions = {}
local SessionBySource = {}
local TestChallenges = {}
local LastDestination = {}
local NpcHistory = {}
local UndergroundState = nil
local UndergroundCache = nil
local RouteAudits = {}
local OpponentBlipTests = {}
local RateLimits = {}
local NextRaceId = 0
local PrepareSession

math.randomseed(os.time() + GetGameTimer())
-----------------------------------------------------------------------------------------------------------------------------------------
-- HELPERS
-----------------------------------------------------------------------------------------------------------------------------------------
local function Debug(Message)
	if Config.Debug then
		print(("[af_illegal_races] %s"):format(Message))
	end
end

local function Notify(Source,Title,Message,Color,Duration)
	if Source and Source > 0 and GetPlayerName(Source) then
		TriggerClientEvent("Notify",Source,Title,Message,Color or "amarelo",Duration or 5000)
	end
end

local function SourceOnline(Source)
	return Source and Source > 0 and GetPlayerName(Source) ~= nil and GetPlayerPed(Source) ~= 0
end

local function Trim(Value)
	return tostring(Value or ""):match("^%s*(.-)%s*$")
end

local function SafeLabel(Value,Fallback)
	Value = Trim(Value):gsub("[%c<>]",""):gsub("%s+"," ")
	if #Value > 40 then
		Value = Value:sub(1,40)
	end

	return Value ~= "" and Value or Fallback
end

local function Distance(First,Second)
	if not First or not Second then
		return math.huge
	end

	local X = (First.x or First[1] or 0.0) - (Second.x or Second[1] or 0.0)
	local Y = (First.y or First[2] or 0.0) - (Second.y or Second[2] or 0.0)
	local Z = (First.z or First[3] or 0.0) - (Second.z or Second[3] or 0.0)
	return math.sqrt((X * X) + (Y * Y) + (Z * Z))
end

local function HorizontalDistance(First,Second)
	if not First or not Second then
		return math.huge
	end

	local X = (First.x or First[1] or 0.0) - (Second.x or Second[1] or 0.0)
	local Y = (First.y or First[2] or 0.0) - (Second.y or Second[2] or 0.0)
	return math.sqrt((X * X) + (Y * Y))
end

local function VerticalDifference(First,Second)
	if not First or not Second then
		return math.huge
	end

	return math.abs((First.z or First[3] or 0.0) - (Second.z or Second[3] or 0.0))
end

local function PointRadius(Point)
	if Point and Point.finish then
		return tonumber(Point.radius) or Config.FinishRadius
	end

	return tonumber(Point and Point.radius) or Config.CheckpointRadius
end

local function CheckpointPositionValid(Point,Coords)
	local Validation = Config.CheckpointValidation or {}
	local Radius = PointRadius(Point) + math.max(0.0,tonumber(Validation.ServerRadiusTolerance) or 0.0)
	local MaximumVertical = math.max(0.0,tonumber(Validation.MaximumVerticalDifference) or 10.0)
	return HorizontalDistance(Coords,Point) <= Radius and VerticalDifference(Coords,Point) <= MaximumVertical
end

local function CheckpointDebug(Session,Source,Message)
	if (Config.CheckpointValidation and Config.CheckpointValidation.Debug) or (Session and Session.CheckpointDebug and Session.CheckpointDebug[Source]) then
		print(("[af_illegal_races] race=%s source=%s %s"):format(Session and Session.Id or "?",Source or "?",Message))
	end
end

local function PlainCoords(Coords)
	return {
		x = tonumber(Coords.x or Coords[1]) or 0.0,
		y = tonumber(Coords.y or Coords[2]) or 0.0,
		z = tonumber(Coords.z or Coords[3]) or 0.0
	}
end

local function NormalizeHorizontal(Vector)
	if not Vector then
		return nil
	end

	local X = tonumber(Vector.x or Vector[1]) or 0.0
	local Y = tonumber(Vector.y or Vector[2]) or 0.0
	local Length = math.sqrt((X * X) + (Y * Y))
	if Length <= 0.0001 then
		return nil
	end

	return { x = X / Length, y = Y / Length, z = 0.0 }
end

local function ForwardFromHeading(Heading)
	local Radians = math.rad(tonumber(Heading) or 0.0)
	return NormalizeHorizontal({
		x = -math.sin(Radians),
		y = math.cos(Radians),
		z = 0.0
	})
end

local function ForwardDot(Start,Forward,Finish)
	local Direction = NormalizeHorizontal({
		x = (Finish.x or Finish[1] or 0.0) - (Start.x or Start[1] or 0.0),
		y = (Finish.y or Finish[2] or 0.0) - (Start.y or Start[2] or 0.0),
		z = 0.0
	})
	if not Direction or not Forward then
		return -1.0
	end

	return (Direction.x * Forward.x) + (Direction.y * Forward.y)
end

local function HeadingDifference(First,Second)
	return math.abs(((tonumber(First) or 0.0) - (tonumber(Second) or 0.0) + 180.0) % 360.0 - 180.0)
end

local function FiniteNumber(Value)
	Value = tonumber(Value)
	return Value and Value == Value and Value > -math.huge and Value < math.huge and Value or nil
end

local function RouteDistance(Start,Route)
	local Total = 0.0
	local Previous = Start
	for _,Point in ipairs(Route or {}) do
		Total = Total + Distance(Previous,Point)
		Previous = Point
	end

	return Total
end

local function RateAllowed(Source,Key,Interval)
	local Now = GetGameTimer()
	RateLimits[Source] = RateLimits[Source] or {}
	local Until = RateLimits[Source][Key] or 0
	if Now < Until then
		return false
	end

	RateLimits[Source][Key] = Now + (Interval or 500)
	return true
end

local function NewRaceId()
	NextRaceId = NextRaceId + 1
	return NextRaceId
end

local function NewToken(RaceId,Passport)
	return ("%s:%s:%s:%s"):format(RaceId,Passport,os.time(),math.random(100000,999999))
end

local function InBlockedZone(Coords)
	for _,Zone in ipairs(Config.BlockedZones or {}) do
		if Distance(Coords,Zone.Coords) <= (tonumber(Zone.Radius) or 0.0) then
			return true,Zone.Label
		end
	end

	return false
end

local function EntityFromNetwork(Network)
	Network = tonumber(Network) or 0
	if Network <= 0 then
		return 0
	end

	local Entity = NetworkGetEntityFromNetworkId(Network)
	if Entity == 0 or not DoesEntityExist(Entity) then
		return 0
	end

	return Entity
end

local function VehicleBlocked(Vehicle)
	local Success,Class = pcall(GetVehicleClass,Vehicle)
	if Success and Config.BlockedVehicleClasses[Class] then
		return true
	end

	local Model = GetEntityModel(Vehicle)
	return Config.BlockedVehicleModels[Model] == true
end

local function DriverContext(Source,IgnoreSpeed)
	if not SourceOnline(Source) then
		return nil,"jogador indisponivel"
	end

	local Passport = vRP.Passport(Source)
	if not Passport then
		return nil,"personagem nao carregado"
	end

	if vRP.GetHealth(Source) <= 100 then
		return nil,"voce esta inconsciente"
	end

	local State = Player(Source).state
	if State.Safezone then
		return nil,"nao e permitido iniciar racha em safe zone"
	end

	local Ped = GetPlayerPed(Source)
	local Vehicle = GetVehiclePedIsIn(Ped,false)
	if Vehicle == 0 or not DoesEntityExist(Vehicle) or GetPedInVehicleSeat(Vehicle,-1) ~= Ped then
		return nil,"voce precisa estar dirigindo um veiculo"
	end

	if VehicleBlocked(Vehicle) then
		return nil,"este tipo de veiculo nao pode participar"
	end

	if GetEntityHealth(Vehicle) <= 0 then
		return nil,"o veiculo nao esta em condicoes de correr"
	end

	if not IgnoreSpeed and GetEntitySpeed(Vehicle) > Config.VehicleMaximumSpeedToChallenge then
		return nil,"reduza a velocidade antes de desafiar"
	end

	local Coords = GetEntityCoords(Ped)
	local VehicleCoords = GetEntityCoords(Vehicle)
	local Blocked,Zone = InBlockedZone(Coords)
	if Blocked then
		return nil,("nao e permitido iniciar racha em %s"):format(Zone)
	end

	local VehicleNet = NetworkGetNetworkIdFromEntity(Vehicle)
	if VehicleNet <= 0 then
		return nil,"nao foi possivel sincronizar o veiculo"
	end

	local Heading = GetEntityHeading(Vehicle)
	local Forward = ForwardFromHeading(Heading)
	if not Forward then
		return nil,"nao foi possivel determinar a direcao do veiculo"
	end

	return {
		Source = Source,
		Passport = Passport,
		Ped = Ped,
		Vehicle = Vehicle,
		VehicleNet = VehicleNet,
		Coords = Coords,
		VehicleCoords = VehicleCoords,
		Heading = Heading,
		Forward = Forward,
		Bucket = GetPlayerRoutingBucket(Source)
	}
end

local function ParticipantSources(Session)
	local Sources = {}
	if Session.Mode == "player" then
		Sources[#Sources + 1] = Session.Challenger
		Sources[#Sources + 1] = Session.Challenged
	else
		Sources[#Sources + 1] = Session.Owner
	end

	return Sources
end

local function OtherPlayer(Session,Source)
	if Session.Mode ~= "player" then
		return nil
	end

	return Session.Challenger == Source and Session.Challenged or Session.Challenger
end

local function SetRaceState(Source,Value)
	if SourceOnline(Source) then
		Player(Source).state:set("StreetRace",Value or false,true)
	end
end

local function SessionFor(Source)
	local RaceId = SessionBySource[Source]
	return RaceId and Sessions[RaceId] or nil
end

local function ClearChallenge(Challenge)
	if not Challenge then
		return
	end

	Challenges[Challenge.Id] = nil
	ChallengeBySource[Challenge.Challenger] = nil
	ChallengeBySource[Challenge.Challenged] = nil
end

local function NpcHistoryKey(Passport)
	return ("StreetRace:NpcHistory:%s"):format(tonumber(Passport) or 0)
end

local function LoadNpcHistory(Passport)
	Passport = tonumber(Passport)
	if not Passport then
		return { Version = 1, Cooldown = 0, Wins = {} }
	end

	if NpcHistory[Passport] then
		return NpcHistory[Passport]
	end

	local History = { Version = 1, Cooldown = 0, Wins = {} }
	local Success,Stored = pcall(function()
		return vRP.GetSrvData(NpcHistoryKey(Passport),true)
	end)

	if Success and type(Stored) == "table" then
		History.Cooldown = math.max(0,math.floor(tonumber(Stored.Cooldown) or 0))
		for _,Timestamp in ipairs(type(Stored.Wins) == "table" and Stored.Wins or {}) do
			Timestamp = math.floor(tonumber(Timestamp) or 0)
			if Timestamp > 0 then
				History.Wins[#History.Wins + 1] = Timestamp
			end
		end
	elseif not Success then
		Debug(("historico NPC indisponivel passport=%s fallback=memoria erro=%s"):format(Passport,tostring(Stored)))
	end

	NpcHistory[Passport] = History
	return History
end

local function SaveNpcHistory(Passport)
	Passport = tonumber(Passport)
	local History = Passport and NpcHistory[Passport]
	if not Passport or not History then
		return false
	end

	local Payload = {
		Version = 1,
		Cooldown = math.max(0,math.floor(tonumber(History.Cooldown) or 0)),
		Wins = History.Wins or {}
	}
	local Success,Error = pcall(function()
		vRP.SetSrvData(NpcHistoryKey(Passport),Payload,true)
	end)
	if not Success then
		Debug(("falha ao persistir historico NPC passport=%s fallback=memoria erro=%s"):format(Passport,tostring(Error)))
	end

	return Success
end

local function RefundSession(Session,Reason)
	if not Session or not Session.Escrow or Session.FinancialState == "paid" or Session.FinancialState == "settled" or Session.FinancialState == "refunded" then
		return false
	end

	Session.Refunded = Session.Refunded or {}
	for Passport,Amount in pairs(Session.Escrow) do
		Passport = tonumber(Passport)
		Amount = tonumber(Amount) or 0
		if Passport and Amount > 0 and not Session.Refunded[Passport] then
			Session.Refunded[Passport] = true
			vRP.GiveBank(Passport,Amount,true)
			Debug(("race=%s reembolso passport=%s valor=%s motivo=%s"):format(Session.Id,Passport,Amount,Reason or "cancelamento"))
		end
	end

	Session.FinancialState = "refunded"
	return true
end

local function ClearSession(Session)
	if not Session or Session.Cleaned then
		return
	end

	Session.Cleaned = true
	for _,Source in ipairs(ParticipantSources(Session)) do
		if SessionBySource[Source] == Session.Id then
			SessionBySource[Source] = nil
		end
		if SourceOnline(Source) then
			TriggerClientEvent("af_illegal_races:OpponentBlipClear",Source,Session.Id)
		end
		SetRaceState(Source,false)
	end

	Sessions[Session.Id] = nil
end

local function EndClients(Session,Payload)
	for _,Source in ipairs(ParticipantSources(Session)) do
		if SourceOnline(Source) then
			TriggerClientEvent("af_illegal_races:End",Source,Payload or {})
		end
	end
end

local function CancelSession(Session,Reason,Refund)
	if not Session or Session.Cleaned or Session.Status == "completed" or Session.Status == "cancelled" then
		return
	end

	Session.Status = "cancelled"
	local Refunded = Refund and RefundSession(Session,Reason) or false

	EndClients(Session,{
		result = "cancelled",
		title = "Racha cancelado",
		message = Reason or "A corrida foi cancelada.",
		elapsed = Session.StartedAt and math.max(0,GetGameTimer() - Session.StartedAt) or 0,
		refunded = Refunded == true,
		refund = Refunded and "A aposta foi devolvida." or "Nenhum reembolso foi necessario."
	})
	Debug(("race=%s state=cancelled refund=%s reason=%s"):format(Session.Id,tostring(Refund == true),Reason or "sem motivo"))
	ClearSession(Session)
end

local function CleanNpcWins(Passport)
	local History = LoadNpcHistory(Passport)

	local Limit = os.time() - 3600
	local Filtered = {}
	for _,Timestamp in ipairs(History.Wins or {}) do
		if Timestamp >= Limit then
			Filtered[#Filtered + 1] = Timestamp
		end
	end

	local Changed = #Filtered ~= #(History.Wins or {})
	History.Wins = Filtered
	if Changed then
		SaveNpcHistory(Passport)
	end
	return #Filtered
end

local function NpcRaceAllowed(Passport)
	local History = LoadNpcHistory(Passport)

	if os.time() < (History.Cooldown or 0) then
		return false,("aguarde %s segundos para desafiar outro NPC"):format(History.Cooldown - os.time())
	end

	if CleanNpcWins(Passport) >= Config.NpcRace.MaximumPaidWinsPerHour then
		return false,"limite de vitorias remuneradas contra NPC atingido nesta hora"
	end

	return true
end

local function RecordNpcWin(Passport)
	local History = LoadNpcHistory(Passport)
	History.Wins[#History.Wins + 1] = os.time()
	SaveNpcHistory(Passport)
end

local function RankingDefaults(Passport,Data)
	Data = type(Data) == "table" and Data or {}
	return {
		Passport = tonumber(Passport) or tonumber(Data.Passport) or 0,
		Name = SafeLabel(Data.Name,"Piloto clandestino"),
		Rating = math.max(0,math.floor(tonumber(Data.Rating) or Config.Ranking.InitialRating)),
		Wins = math.max(0,math.floor(tonumber(Data.Wins) or 0)),
		Losses = math.max(0,math.floor(tonumber(Data.Losses) or 0)),
		CurrentStreak = math.max(0,math.floor(tonumber(Data.CurrentStreak) or 0)),
		BestStreak = math.max(0,math.floor(tonumber(Data.BestStreak) or 0)),
		Races = math.max(0,math.floor(tonumber(Data.Races) or 0)),
		Earnings = math.max(0,math.floor(tonumber(Data.Earnings) or 0)),
		Staked = math.max(0,math.floor(tonumber(Data.Staked) or 0)),
		BestPrize = math.max(0,math.floor(tonumber(Data.BestPrize) or 0)),
		LastRaceAt = math.max(0,math.floor(tonumber(Data.LastRaceAt) or 0)),
		LastOpponent = tonumber(Data.LastOpponent) or 0,
		RecentOpponents = type(Data.RecentOpponents) == "table" and Data.RecentOpponents or {}
	}
end

local function LoadUndergroundState()
	if UndergroundState then
		return UndergroundState
	end

	UndergroundState = { Version = 1, Players = {} }
	local Success,Stored = pcall(function()
		return vRP.GetSrvData("StreetRace:UndergroundRanking",true)
	end)

	if Success and type(Stored) == "table" then
		local Players = type(Stored.Players) == "table" and Stored.Players or {}
		for Passport,Data in pairs(Players) do
			Passport = tonumber(Passport) or tonumber(Data and Data.Passport)
			if Passport then
				UndergroundState.Players[tostring(Passport)] = RankingDefaults(Passport,Data)
			end
		end
	elseif not Success then
		Debug(("ranking underground indisponivel fallback=memoria erro=%s"):format(tostring(Stored)))
	end

	return UndergroundState
end

local function SaveUndergroundState()
	UndergroundCache = nil
	local Success,Error = pcall(function()
		vRP.SetSrvData("StreetRace:UndergroundRanking",LoadUndergroundState(),true)
	end)
	if not Success then
		Debug(("falha ao persistir ranking underground erro=%s"):format(tostring(Error)))
	end

	return Success
end

local function RankingPlayer(Passport,Name)
	local State = LoadUndergroundState()
	local Key = tostring(tonumber(Passport) or 0)
	State.Players[Key] = RankingDefaults(Passport,State.Players[Key])
	if Name then
		State.Players[Key].Name = SafeLabel(Name,State.Players[Key].Name)
	end

	return State.Players[Key]
end

local function CleanRecentOpponents(Data,Now)
	local Limit = Now - math.max(0,tonumber(Config.Ranking.RecentOpponentWindow) or 0)
	for Passport,Timestamp in pairs(Data.RecentOpponents) do
		if (tonumber(Timestamp) or 0) < Limit then
			Data.RecentOpponents[Passport] = nil
		end
	end
end

local function RankingSnapshot(Passport)
	local Now = os.time()
	local CacheSeconds = math.max(1,math.floor(tonumber(Config.Ranking.CacheSeconds) or 5))
	if not UndergroundCache or UndergroundCache.ExpiresAt <= Now then
		local Entries = {}
		for _,Data in pairs(LoadUndergroundState().Players) do
			if Data.Races > 0 then
				Entries[#Entries + 1] = {
					Name = Data.Name,
					Passport = Data.Passport,
					Rating = Data.Rating,
					Wins = Data.Wins,
					Losses = Data.Losses,
					Races = Data.Races,
					WinRate = Data.Races > 0 and math.floor((Data.Wins / Data.Races) * 100 + 0.5) or 0,
					CurrentStreak = Data.CurrentStreak,
					BestStreak = Data.BestStreak,
					Earnings = Data.Earnings
				}
			end
		end

		table.sort(Entries,function(A,B)
			if A.Rating ~= B.Rating then return A.Rating > B.Rating end
			if A.Wins ~= B.Wins then return A.Wins > B.Wins end
			if A.WinRate ~= B.WinRate then return A.WinRate > B.WinRate end
			if A.Races ~= B.Races then return A.Races > B.Races end
			return A.Name < B.Name
		end)

		local Positions = {}
		for Position,Data in ipairs(Entries) do
			Positions[Data.Passport] = Position
			Data.Position = Position
		end

		UndergroundCache = { Entries = Entries, Positions = Positions, ExpiresAt = Now + CacheSeconds }
	end

	local Limit = math.max(1,math.floor(tonumber(Config.Ranking.TopLimit) or 50))
	local Top = {}
	for Index = 1,math.min(Limit,#UndergroundCache.Entries) do
		local Data = UndergroundCache.Entries[Index]
		Top[#Top + 1] = {
			Position = Data.Position,
			Name = Data.Name,
			Rating = Data.Rating,
			Wins = Data.Wins,
			Losses = Data.Losses,
			Races = Data.Races,
			WinRate = Data.WinRate,
			CurrentStreak = Data.CurrentStreak,
			BestStreak = Data.BestStreak,
			Earnings = Data.Earnings
		}
	end

	local Data = RankingPlayer(Passport)
	local Personal = {
		Classified = Data.Races > 0,
		Position = UndergroundCache.Positions[Data.Passport],
		Rating = Data.Rating,
		Wins = Data.Wins,
		Losses = Data.Losses,
		Races = Data.Races,
		WinRate = Data.Races > 0 and math.floor((Data.Wins / Data.Races) * 100 + 0.5) or 0,
		CurrentStreak = Data.CurrentStreak,
		BestStreak = Data.BestStreak,
		Earnings = Data.Earnings,
		BestPrize = Data.BestPrize
	}

	return { Enabled = Config.Ranking.Enabled == true, Personal = Personal, Ranking = Top, UpdatedAt = Now }
end

local function ProcessUndergroundRanking(Session,WinnerSource,Prize)
	if not Config.Ranking.Enabled then
		return false
	end

	if Session.RankingProcessed then
		Debug(("[underground-ranking] atualizacao duplicada bloqueada race=%s"):format(Session.Id))
		return false
	end
	Session.RankingProcessed = true

	if Session.Mode ~= "player" then
		Debug(("[underground-ranking] corrida ignorada: modo %s race=%s"):format(tostring(Session.Mode),Session.Id))
		return false
	end

	local LoserSource = OtherPlayer(Session,WinnerSource)
	local WinnerPassport = Session.Passports[WinnerSource]
	local LoserPassport = LoserSource and Session.Passports[LoserSource]
	if Session.Status ~= "completed" or not Session.Paid or Session.FinancialState ~= "paid" or not WinnerPassport or not LoserPassport or WinnerPassport == LoserPassport then
		Debug(("[underground-ranking] corrida ignorada: resultado invalido race=%s"):format(Session.Id))
		return false
	end

	if next(Session.Refunded or {}) or Session.Suspicious then
		Debug(("[underground-ranking] corrida ignorada: reembolso ou suspeita race=%s"):format(Session.Id))
		return false
	end

	if (tonumber(Session.Stake) or 0) < Config.Ranking.MinimumStake or (tonumber(Session.RouteDistance) or 0) < Config.Ranking.MinimumDistance then
		Debug(("[underground-ranking] corrida ignorada: requisitos minimos race=%s stake=%s distance=%.1f"):format(Session.Id,Session.Stake or 0,Session.RouteDistance or 0))
		return false
	end

	local Winner = RankingPlayer(WinnerPassport,Session.Names[WinnerSource])
	local Loser = RankingPlayer(LoserPassport,Session.Names[LoserSource])
	local Now = os.time()
	CleanRecentOpponents(Winner,Now)
	CleanRecentOpponents(Loser,Now)

	local Repeat = Winner.RecentOpponents[tostring(LoserPassport)] or Loser.RecentOpponents[tostring(WinnerPassport)]
	local Multiplier = Repeat and Config.Ranking.RepeatOpponentMultiplier or 1.0
	local Expected = 1.0 / (1.0 + (10.0 ^ ((Loser.Rating - Winner.Rating) / 400.0)))
	local Delta = math.max(1,math.floor((Config.Ranking.KFactor * (1.0 - Expected) * Multiplier) + 0.5))

	Winner.Rating = Winner.Rating + Delta
	Winner.Wins = Winner.Wins + 1
	Winner.Races = Winner.Races + 1
	Winner.CurrentStreak = Winner.CurrentStreak + 1
	Winner.BestStreak = math.max(Winner.BestStreak,Winner.CurrentStreak)
	Winner.Earnings = Winner.Earnings + math.max(0,math.floor(tonumber(Prize) or 0))
	Winner.Staked = Winner.Staked + math.max(0,math.floor(tonumber(Session.Stake) or 0))
	Winner.BestPrize = math.max(Winner.BestPrize,math.max(0,math.floor(tonumber(Prize) or 0)))
	Winner.LastRaceAt = Now
	Winner.LastOpponent = LoserPassport
	Winner.RecentOpponents[tostring(LoserPassport)] = Now

	Loser.Rating = math.max(0,Loser.Rating - Delta)
	Loser.Losses = Loser.Losses + 1
	Loser.Races = Loser.Races + 1
	Loser.CurrentStreak = 0
	Loser.Staked = Loser.Staked + math.max(0,math.floor(tonumber(Session.Stake) or 0))
	Loser.LastRaceAt = Now
	Loser.LastOpponent = WinnerPassport
	Loser.RecentOpponents[tostring(WinnerPassport)] = Now

	SaveUndergroundState()
	Debug(("[underground-ranking] race=%s winner=%s loser=%s deltaWinner=%s deltaLoser=-%s repeat=%s"):format(Session.Id,WinnerPassport,LoserPassport,Delta,Delta,tostring(Repeat ~= nil)))
	return true
end

local function FinishSession(Session,Winner,Reason)
	if not Session or Session.Cleaned or Session.Status ~= "racing" then
		return
	end

	local Payload = {
		result = "loss",
		title = "Racha encerrado",
		message = Reason or "A corrida terminou.",
		prize = 0
	}

	if Session.Mode == "player" then
		local WinnerSource = tonumber(Winner)
		local WinnerPassport = WinnerSource and Session.Passports[WinnerSource]
		if not WinnerPassport then
			CancelSession(Session,Reason or "Nao foi possivel determinar o vencedor.",true)
			return
		end
	end

	if Session.FinancialState == "refunded" then
		Debug(("race=%s pagamento bloqueado motivo=sessao_reembolsada"):format(Session.Id))
		CancelSession(Session,"A sessao financeira ja havia sido reembolsada.",false)
		return
	end

	Session.Status = "completed"
	local Elapsed = Session.StartedAt and math.max(0,GetGameTimer() - Session.StartedAt) or 0

	if Session.Mode == "player" then
		local WinnerSource = tonumber(Winner)
		local WinnerPassport = Session.Passports[WinnerSource]
		local Fee = math.max(0,math.min(100,tonumber(Config.PlayerRace.HouseFeePercent) or 0))
		local Prize = math.floor((Session.Pot or 0) * (1.0 - (Fee / 100.0)))
		if Prize > 0 and not Session.Paid and Session.FinancialState ~= "refunded" then
			Session.Paid = true
			Session.FinancialState = "paid"
			vRP.GiveBank(WinnerPassport,Prize,true)
		end
		ProcessUndergroundRanking(Session,WinnerSource,Prize)

		local WinnerName = vRP.FullName(WinnerPassport) or "Piloto"
		for _,Source in ipairs(ParticipantSources(Session)) do
			if SourceOnline(Source) then
				if Source == WinnerSource then
					TriggerClientEvent("af_illegal_races:End",Source,{
						result = "win",
						title = "Vitoria",
						message = ("Voce venceu o racha e recebeu R$ %s."):format(Prize),
						prize = Prize,
						elapsed = Elapsed,
						opponent = Session.Names[OtherPlayer(Session,Source)] or "Adversario"
					})
				else
					TriggerClientEvent("af_illegal_races:End",Source,{
						result = "loss",
						title = "Derrota",
						message = ("Voce perdeu o racha para %s."):format(WinnerName),
						prize = 0,
						elapsed = Elapsed,
						opponent = WinnerName
					})
				end
			end
		end
	elseif Session.Mode == "npc" then
		ProcessUndergroundRanking(Session,Winner,0)
		local PlayerWon = Winner == Session.Owner
		if PlayerWon then
			local Prize = tonumber(Config.NpcRace.WinnerPayment) or 0
			if Prize > 0 and not Session.Paid and Session.FinancialState ~= "refunded" then
				Session.Paid = true
				Session.FinancialState = "paid"
				vRP.GiveBank(Session.Passports[Session.Owner],Prize,true)
				RecordNpcWin(Session.Passports[Session.Owner])
			end

			Payload = {
				result = "win",
				title = "Vitoria",
				message = ("Voce venceu o piloto clandestino e recebeu R$ %s."):format(Prize),
				prize = Prize,
				elapsed = Elapsed,
				opponent = Session.NpcName
			}
		else
			Payload = {
				result = "loss",
				title = "Derrota",
				message = Reason or "O piloto clandestino chegou primeiro.",
				prize = 0,
				elapsed = Elapsed,
				opponent = Session.NpcName
			}
			Session.FinancialState = "settled"
		end

		EndClients(Session,Payload)
	elseif Session.Mode == "test" then
		ProcessUndergroundRanking(Session,Winner,0)
		local PlayerWon = Winner == Session.Owner
		Payload = {
			result = PlayerWon and "win" or "loss",
			title = PlayerWon and "Teste vencido" or "Teste perdido",
			message = Reason or (PlayerWon and "O Piloto de Teste foi derrotado." or "O Piloto de Teste chegou primeiro."),
			prize = 0,
			elapsed = Elapsed,
			opponent = "Piloto de Teste"
		}
		Session.FinancialState = "settled"
		EndClients(Session,Payload)
	end

	Debug(("race=%s state=completed winner=%s mode=%s"):format(Session.Id,tostring(Winner),Session.Mode))
	ClearSession(Session)
end

local function Disqualify(Session,Source,Reason)
	if not Session or Session.Status ~= "racing" then
		return
	end

	if Session.Mode == "player" then
		local Other = OtherPlayer(Session,Source)
		if Other and SourceOnline(Other) then
			FinishSession(Session,Other,Reason)
		else
			Debug(("race=%s resultado ambiguo na desclassificacao; reembolsando passaportes"):format(Session.Id))
			CancelSession(Session,Reason or "Nao foi possivel determinar um vencedor online.",true)
		end
	elseif Session.Mode == "npc" then
		FinishSession(Session,"npc",Reason)
	elseif Session.Mode == "test" then
		FinishSession(Session,"virtual",Reason)
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- ROUTE GENERATION
-----------------------------------------------------------------------------------------------------------------------------------------
local function Projection(Start,Finish,Point)
	local DX = Finish.x - Start.x
	local DY = Finish.y - Start.y
	local DZ = Finish.z - Start.z
	local Length = (DX * DX) + (DY * DY) + (DZ * DZ)
	if Length <= 0.001 then
		return 0.0
	end

	return (((Point.x - Start.x) * DX) + ((Point.y - Start.y) * DY) + ((Point.z - Start.z) * DZ)) / Length
end

local function BuildRoute(StartCoords,DistanceKey,Passport,StartForward,Options)
	local Option = Config.DistanceOptions[DistanceKey] or Config.DistanceOptions.Medium
	local TargetDistance = (Option.Minimum + Option.Maximum) * 0.5
	local Start = PlainCoords(StartCoords)
	local Forward = NormalizeHorizontal(StartForward)
	local RequireForward = Config.Route.RequireForwardDestination ~= false
	if RequireForward and not Forward then
		return nil,nil,nil,{ Reason = "direcao da largada indisponivel" }
	end

	local MinimumDot = tonumber(Config.Route.MinimumForwardDot) or 0.20
	local MinimumFirstDot = tonumber(Config.Route.MinimumFirstCheckpointDot) or 0.30
	local RequiredDestinationDot = math.max(MinimumDot,MinimumFirstDot)
	local PreferredDot = math.max(RequiredDestinationDot,tonumber(Config.Route.PreferredForwardDot) or 0.55)
	local DirectionWeight = math.max(0.0,tonumber(Config.Route.DirectionScoreWeight) or 1800.0)
	local InRange = {}
	local InRangeRepeated = {}
	local Fallback = {}
	local FallbackRepeated = {}

	for Index,Node in ipairs(RaceRouteNodes) do
		local NodeDistance = Distance(Start,Node.Coords)
		local Dot = Forward and ForwardDot(Start,Forward,Node.Coords) or 1.0
		local Entry = {
			Index = Index,
			Node = Node,
			Distance = NodeDistance,
			ForwardDot = Dot,
			Score = math.abs(NodeDistance - TargetDistance) + ((1.0 - Dot) * DirectionWeight)
		}
		local IsForward = not RequireForward or Dot >= RequiredDestinationDot
		if IsForward then
			local Repeated = Config.Route.AvoidDestinationRepeat and LastDestination[Passport] == Index
			local InDistance = NodeDistance >= Option.Minimum and NodeDistance <= Option.Maximum
			if InDistance then
				local List = Repeated and InRangeRepeated or InRange
				List[#List + 1] = Entry
			end

			local FallbackMaximum = Option.Maximum * math.max(1.0,tonumber(Config.Route.FallbackMaximumMultiplier) or 1.35)
			if NodeDistance >= Option.Minimum and NodeDistance <= FallbackMaximum then
				local List = Repeated and FallbackRepeated or Fallback
				List[#List + 1] = Entry
			end
		end
	end

	local Candidates = #InRange > 0 and InRange or InRangeRepeated
	if #Candidates == 0 then
		Candidates = #Fallback > 0 and Fallback or FallbackRepeated
	end
	if #Candidates == 0 then
		return nil,nil,nil,{ Reason = "nenhum destino cadastrado esta a frente da largada" }
	end

	local Preferred = {}
	for _,Entry in ipairs(Candidates) do
		if Entry.ForwardDot >= PreferredDot then
			Preferred[#Preferred + 1] = Entry
		end
	end
	if #Preferred > 0 then
		Candidates = Preferred
	end

	table.sort(Candidates,function(A,B)
		return A.Score < B.Score
	end)
	local RandomLimit = math.max(1,math.floor(tonumber(Config.Route.MaximumRandomCandidates) or 3))
	local Destination = Candidates[math.random(1,math.min(RandomLimit,#Candidates))]
	if not Options or Options.RememberDestination ~= false then
		LastDestination[Passport] = Destination.Index
	end

	local Finish = PlainCoords(Destination.Node.Coords)
	local LaunchAnchor = Options and Options.LaunchAnchor and PlainCoords(Options.LaunchAnchor) or nil
	local Selected = {}
	local Used = { [Destination.Index] = true }
	local LastProjection = LaunchAnchor and math.max(0.0,Projection(Start,Finish,LaunchAnchor)) or 0.0
	local Window = tonumber(Config.Route.IntermediateProjectionWindow) or 0.28
	local CheckpointCount = math.max(0,math.floor(tonumber(Option.Checkpoints) or 0))
	local IntermediateCount = math.max(0,CheckpointCount - (LaunchAnchor and 1 or 0))
	local MinimumSpacing = math.max(100.0,tonumber(Config.Route.MinimumCheckpointSpacing) or 500.0)
	local LastCoords = LaunchAnchor or Start

	for Step = 1,IntermediateCount do
		local TargetProjection = Step / (IntermediateCount + 1)
		local Ideal = {
			x = Start.x + ((Finish.x - Start.x) * TargetProjection),
			y = Start.y + ((Finish.y - Start.y) * TargetProjection),
			z = Start.z + ((Finish.z - Start.z) * TargetProjection)
		}
		local Best

		for Index,Node in ipairs(RaceRouteNodes) do
			if not Used[Index] then
				local Coords = PlainCoords(Node.Coords)
				local Projected = Projection(Start,Finish,Coords)
				local PointForwardDot = Forward and ForwardDot(Start,Forward,Coords) or 1.0
				local FirstPointValid = Step > 1 or PointForwardDot >= MinimumFirstDot
				local SpacedFromPrevious = Distance(LastCoords,Coords) >= MinimumSpacing
				local SpacedFromFinish = Distance(Coords,Finish) >= MinimumSpacing
				if FirstPointValid and SpacedFromPrevious and SpacedFromFinish and Projected > (LastProjection + 0.04) and Projected < 0.96 and math.abs(Projected - TargetProjection) <= Window then
					local DirectionPenalty = Step == 1 and ((1.0 - PointForwardDot) * DirectionWeight * 0.25) or 0.0
					local Score = Distance(Ideal,Coords) + (math.abs(Projected - TargetProjection) * Destination.Distance * 0.35) + DirectionPenalty
					if not Best or Score < Best.Score then
						Best = { Index = Index, Node = Node, Coords = Coords, Projection = Projected, ForwardDot = PointForwardDot, Score = Score }
					end
				end
			end
		end

		if Best then
			Used[Best.Index] = true
			LastProjection = Best.Projection
			LastCoords = Best.Coords
			Selected[#Selected + 1] = Best
		end
	end

	table.sort(Selected,function(A,B)
		return A.Projection < B.Projection
	end)

	local Route = {}
	if LaunchAnchor then
		Route[#Route + 1] = {
			sequence = #Route + 1,
			type = "launch",
			x = LaunchAnchor.x,
			y = LaunchAnchor.y,
			z = LaunchAnchor.z,
			label = "Saida do racha",
			radius = tonumber(Config.Route.ForwardLaunchRadius) or Config.CheckpointRadius,
			launch = true
		}
	end
	for _,Entry in ipairs(Selected) do
		Route[#Route + 1] = {
			sequence = #Route + 1,
			type = "checkpoint",
			x = Entry.Coords.x,
			y = Entry.Coords.y,
			z = Entry.Coords.z,
			label = Entry.Node.Name,
			radius = Config.CheckpointRadius
		}
	end

	Route[#Route + 1] = {
		sequence = #Route + 1,
		type = "finish",
		x = Finish.x,
		y = Finish.y,
		z = Finish.z,
		label = Destination.Node.Name,
		radius = Config.FinishRadius,
		finish = true
	}

	local FirstDot = Forward and ForwardDot(Start,Forward,Route[1]) or 1.0
	if RequireForward and FirstDot < MinimumFirstDot then
		return nil,nil,nil,{
			Reason = "o primeiro checkpoint ficou atras da largada",
			Destination = Destination.Node.Name,
			DestinationDot = Destination.ForwardDot,
			FirstDot = FirstDot
		}
	end

	local GeneratedDistance = 0.0
	local PreviousPoint = Start
	for _,Point in ipairs(Route) do
		GeneratedDistance = GeneratedDistance + Distance(PreviousPoint,Point)
		PreviousPoint = Point
	end

	return Route,Destination.Node.Name,Destination.Distance,{
		Start = Start,
		Forward = Forward,
		DestinationIndex = Destination.Index,
		DestinationDot = Destination.ForwardDot,
		FirstDot = FirstDot,
		HasLaunchAnchor = LaunchAnchor ~= nil,
		CandidateCount = #Candidates,
		RouteDistance = GeneratedDistance
	}
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- LOBBY
-----------------------------------------------------------------------------------------------------------------------------------------
local function LobbyPayload(Session,Source)
	local IsChallenger = Session.Challenger == Source
	local Other = IsChallenger and Session.Challenged or Session.Challenger
	local OwnConfirmed = Session.Confirmed[Source] == Session.Revision
	local OtherConfirmed
	local OtherName
	local OtherVehicle

	if Session.Mode == "test" then
		OtherConfirmed = Session.VirtualConfirmed == Session.Revision
		OtherName = "Piloto de Teste"
		OtherVehicle = "Veiculo simulado"
	else
		OtherConfirmed = Session.Confirmed[Other] == Session.Revision
		OtherName = Session.Names[Other]
		OtherVehicle = Session.VehicleLabels[Other]
	end

	return {
		id = Session.Id,
		mode = Session.Mode,
		revision = Session.Revision,
		stake = Session.Stake,
		distance = Session.Distance,
		distanceLabel = Config.DistanceOptions[Session.Distance].Label,
		prize = Session.Stake * 2,
		player = {
			name = Session.Names[Source],
			vehicle = Session.VehicleLabels[Source],
			confirmed = OwnConfirmed
		},
		opponent = {
			name = OtherName,
			vehicle = OtherVehicle,
			confirmed = OtherConfirmed
		},
		distanceOptions = Config.DistanceOptions,
		minimumStake = Config.MinimumPlayerStake,
		maximumStake = Config.MaximumPlayerStake
	}
end

local function BroadcastLobby(Session,Open)
	for _,Source in ipairs(ParticipantSources(Session)) do
		if SourceOnline(Source) then
			TriggerClientEvent(Open and "af_illegal_races:OpenLobby" or "af_illegal_races:LobbyUpdate",Source,LobbyPayload(Session,Source))
		end
	end
end

local function TermsAck(Source,RequestId,Success,Message,Session)
	TriggerClientEvent("af_illegal_races:TermsAck",Source,{
		requestId = tonumber(RequestId) or 0,
		success = Success == true,
		message = Message,
		revision = Session and Session.Revision or nil
	})
end

local function MoveChallengeToLobby(Challenge)
	if not Challenge or not Challenges[Challenge.Id] then
		return
	end

	local ChallengerContext,ChallengerReason = DriverContext(Challenge.Challenger)
	local ChallengedContext,ChallengedReason = DriverContext(Challenge.Challenged)
	if not ChallengerContext or not ChallengedContext then
		ClearChallenge(Challenge)
		Notify(Challenge.Challenger,"Racha",ChallengerReason or ChallengedReason or "Um participante ficou indisponivel.","vermelho")
		Notify(Challenge.Challenged,"Racha","O desafio foi cancelado porque um participante ficou indisponivel.","amarelo")
		return
	end

	if ChallengerContext.Bucket ~= ChallengedContext.Bucket or Distance(ChallengerContext.Coords,ChallengedContext.Coords) > (Config.ChallengeDistance * 2.0) then
		ClearChallenge(Challenge)
		Notify(Challenge.Challenger,"Racha","Os veiculos se afastaram antes da preparacao.","amarelo")
		Notify(Challenge.Challenged,"Racha","Os veiculos se afastaram antes da preparacao.","amarelo")
		return
	end

	ClearChallenge(Challenge)
	local Session = {
		Id = Challenge.Id,
		Mode = "player",
		Status = "lobby",
		Challenger = Challenge.Challenger,
		Challenged = Challenge.Challenged,
		Passports = {
			[Challenge.Challenger] = ChallengerContext.Passport,
			[Challenge.Challenged] = ChallengedContext.Passport
		},
		Names = {
			[Challenge.Challenger] = vRP.FullName(ChallengerContext.Passport) or "Piloto",
			[Challenge.Challenged] = vRP.FullName(ChallengedContext.Passport) or "Piloto"
		},
		VehicleLabels = {
			[Challenge.Challenger] = Challenge.ChallengerVehicle,
			[Challenge.Challenged] = Challenge.ChallengedVehicle
		},
		Vehicles = {
			[Challenge.Challenger] = ChallengerContext.VehicleNet,
			[Challenge.Challenged] = ChallengedContext.VehicleNet
		},
		Revision = 1,
		Stake = Config.InitialPlayerStake,
		Distance = "Medium",
		Confirmed = {},
		CreatedAt = os.time(),
		ExpiresAt = os.time() + Config.SetupTimeout
	}

	Sessions[Session.Id] = Session
	SessionBySource[Session.Challenger] = Session.Id
	SessionBySource[Session.Challenged] = Session.Id
	Debug(("race=%s state=lobby_open players=%s,%s"):format(Session.Id,Session.Challenger,Session.Challenged))
	BroadcastLobby(Session,true)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- DISPATCH
-----------------------------------------------------------------------------------------------------------------------------------------
local function DispatchAlert(Session,Coords,Update)
	if not Config.Dispatch.Enabled or not Coords then
		return
	end

	local Chance = Session.Mode == "npc" and Config.NpcRace.AlertChance or Config.PlayerRace.AlertChance
	if not Update and math.random(1,100) > Chance then
		return
	end

	local Delay = math.random(Config.Dispatch.InitialDelayMinimum,Config.Dispatch.InitialDelayMaximum)
	local RaceId = Session.Id
	SetTimeout(Delay * 1000,function()
		local Current = Sessions[RaceId]
		if not Current or Current.Status ~= "racing" then
			return
		end

		local Angle = math.random() * math.pi * 2.0
		local Offset = math.random(Config.Dispatch.RandomOffsetMinimum,Config.Dispatch.RandomOffsetMaximum)
		local X = Coords.x + (math.cos(Angle) * Offset)
		local Y = Coords.y + (math.sin(Angle) * Offset)
		local Radius = math.random(Config.Dispatch.RadiusMinimum,Config.Dispatch.RadiusMaximum)
		local Service,Amount = vRP.NumPermission("Policia")

		if Amount < Config.MinimumPolice then
			return
		end

		for _,PoliceSource in pairs(Service or {}) do
			TriggerClientEvent("NotifyPush",PoliceSource,{
				code = 31,
				title = Update and "Nova avistagem de racha" or "Possivel racha clandestino",
				text = "Veiculos em alta velocidade foram vistos na regiao.",
				name = "Denuncia anonima - localizacao aproximada",
				x = X,
				y = Y,
				z = Coords.z,
				color = 1,
				sprite = 161,
				radius = Radius,
				duration = Config.Dispatch.BlipDuration * 1000,
				shortRange = false
			})
		end

		Current.LastDispatchAt = os.time()
		Debug(("race=%s dispatch update=%s radius=%s policiais=%s"):format(RaceId,tostring(Update == true),Radius,Amount))
	end)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- RACE PREPARATION
-----------------------------------------------------------------------------------------------------------------------------------------
local function RouteFrame(Session)
	local Owner = Session.Mode == "player" and Session.Challenger or Session.Owner
	local First,FirstReason = DriverContext(Owner)
	if not First then
		return nil,FirstReason
	end

	if Session.Mode ~= "player" then
		return {
			Start = PlainCoords(First.VehicleCoords or First.Coords),
			Forward = First.Forward,
			Heading = First.Heading,
			Passport = First.Passport
		}
	end

	local Second,SecondReason = DriverContext(Session.Challenged)
	if not Second then
		return nil,SecondReason
	end

	local MaximumDifference = math.max(0.0,tonumber(Config.Route.MaximumStartHeadingDifference) or 55.0)
	local Difference = HeadingDifference(First.Heading,Second.Heading)
	if Difference > MaximumDifference then
		return nil,("Alinhem os dois veiculos na mesma direcao antes de iniciar o racha. Diferenca atual: %.0f graus."):format(Difference)
	end

	local SharedForward = NormalizeHorizontal({
		x = First.Forward.x + Second.Forward.x,
		y = First.Forward.y + Second.Forward.y,
		z = 0.0
	})
	if not SharedForward then
		return nil,"Nao foi possivel determinar uma direcao comum para a largada."
	end

	local FirstCoords = PlainCoords(First.VehicleCoords or First.Coords)
	local SecondCoords = PlainCoords(Second.VehicleCoords or Second.Coords)
	return {
		Start = {
			x = (FirstCoords.x + SecondCoords.x) * 0.5,
			y = (FirstCoords.y + SecondCoords.y) * 0.5,
			z = (FirstCoords.z + SecondCoords.z) * 0.5
		},
		Forward = SharedForward,
		Heading = First.Heading,
		HeadingDifference = Difference,
		Passport = First.Passport
	}
end

local function ValidatePlayerSession(Session)
	for _,Source in ipairs(ParticipantSources(Session)) do
		local Context,Reason = DriverContext(Source)
		if not Context then
			return false,Reason
		end

		if Session.Vehicles[Source] ~= Context.VehicleNet then
			return false,"um participante trocou de veiculo"
		end
	end

	if Session.Mode == "player" then
		local First = DriverContext(Session.Challenger)
		local Second = DriverContext(Session.Challenged)
		if not First or not Second or First.Bucket ~= Second.Bucket or Distance(First.Coords,Second.Coords) > (Config.ChallengeDistance * 3.0) then
			return false,"os participantes se afastaram"
		end
	end

	return true
end

local function ReserveMoney(Session)
	Session.Escrow = {}
	Session.Refunded = {}
	Session.Paid = nil
	Session.FinancialState = "reserving"

	if Session.Mode == "test" and not Config.TestUseRealMoney then
		Session.Pot = Session.Stake * 2
		Session.FinancialState = "reserved"
		return true
	end

	if Session.Mode == "npc" then
		local Passport = Session.Passports[Session.Owner]
		if not vRP.PaymentFull(Passport,Config.NpcRace.Stake,true) then
			return false,"saldo insuficiente para a aposta"
		end

		Session.Escrow[Passport] = Config.NpcRace.Stake
		Session.Pot = Config.NpcRace.WinnerPayment
		Session.FinancialState = "reserved"
		return true
	end

	if Session.Mode == "test" then
		local Passport = Session.Passports[Session.Owner]
		if not vRP.PaymentFull(Passport,Session.Stake,true) then
			return false,"saldo insuficiente para a aposta de teste"
		end

		Session.Escrow[Passport] = Session.Stake
		Session.Pot = Session.Stake * 2
		Session.FinancialState = "reserved"
		return true
	end

	local FirstPassport = Session.Passports[Session.Challenger]
	local SecondPassport = Session.Passports[Session.Challenged]
	if not vRP.PaymentFull(FirstPassport,Session.Stake,true) then
		return false,("%s nao possui saldo para a aposta"):format(Session.Names[Session.Challenger])
	end

	Session.Escrow[FirstPassport] = Session.Stake
	if not vRP.PaymentFull(SecondPassport,Session.Stake,true) then
		RefundSession(Session,"segundo pagamento recusado")
		return false,("%s nao possui saldo para a aposta"):format(Session.Names[Session.Challenged])
	end

	Session.Escrow[SecondPassport] = Session.Stake
	Session.Pot = Session.Stake * 2
	Session.FinancialState = "reserved"
	return true
end

local function PreparePayload(Session,Source)
	local Other = OtherPlayer(Session,Source)
	local OpponentStart = Other and Session.StartCoords[Other] or nil
	if Session.Mode == "npc" then
		local NpcVehicle = EntityFromNetwork(Session.NpcVehicleNet)
		if NpcVehicle ~= 0 then
			OpponentStart = PlainCoords(GetEntityCoords(NpcVehicle))
		end
	elseif Session.Mode == "test" then
		OpponentStart = Session.StartCoords[Source]
	end

	return {
		id = Session.Id,
		mode = Session.Mode,
		token = Session.Tokens[Source],
		route = Session.Route,
		destination = Session.Destination,
		countdown = Config.CountdownSeconds,
		vehicleNet = Session.Vehicles[Source],
		opponentSource = Other or 0,
		opponentVehicleNet = Other and Session.Vehicles[Other] or 0,
		npcPedNet = Session.NpcPedNet or 0,
		npcVehicleNet = Session.NpcVehicleNet or 0,
		opponentName = Session.Mode == "npc" and Session.NpcName or (Session.Mode == "test" and "Piloto de Teste" or Session.Names[Other]),
		start = Session.StartCoords[Source],
		opponentStart = OpponentStart,
		prize = Session.Mode == "npc" and Config.NpcRace.WinnerPayment or Session.Pot,
		checkpointRadius = Config.CheckpointRadius,
		finishRadius = Config.FinishRadius
	}
end

local function StartSession(Session)
	if not Session or Session.Status ~= "countdown" then
		return
	end

	local Valid,Reason = ValidatePlayerSession(Session)
	if not Valid then
		CancelSession(Session,Reason or "Participante indisponivel antes da largada.",true)
		return
	end

	if Session.Mode == "npc" then
		local NpcVehicle = EntityFromNetwork(Session.NpcVehicleNet)
		local NpcPed = EntityFromNetwork(Session.NpcPedNet)
		if NpcVehicle == 0 or NpcPed == 0 or GetPedInVehicleSeat(NpcVehicle,-1) ~= NpcPed then
			CancelSession(Session,"O piloto NPC ficou indisponivel antes da largada.",true)
			return
		end
	end

	Session.Status = "racing"
	Session.StartedAt = GetGameTimer()
	Session.ExpiresAt = os.time() + Config.RaceTimeout
	for _,Source in ipairs(ParticipantSources(Session)) do
		TriggerClientEvent("af_illegal_races:Start",Source,Session.Id)
	end

	local FirstSource = ParticipantSources(Session)[1]
	local FirstCoords = SourceOnline(FirstSource) and GetEntityCoords(GetPlayerPed(FirstSource)) or Session.StartCoords[FirstSource]
	DispatchAlert(Session,PlainCoords(FirstCoords),false)
	Debug(("race=%s state=racing mode=%s destination=%s"):format(Session.Id,Session.Mode,Session.Destination))
end

local function ValidateLaunchAnchor(Frame,Payload)
	if not Frame or type(Payload) ~= "table" then
		return nil,"resposta do no viario ausente"
	end

	local X = FiniteNumber(Payload.x)
	local Y = FiniteNumber(Payload.y)
	local Z = FiniteNumber(Payload.z)
	if not X or not Y or not Z then
		return nil,"coordenadas do no viario invalidas"
	end

	local Point = { x = X, y = Y, z = Z }
	local Minimum = math.max(1.0,tonumber(Config.Route.ForwardLaunchMinimum) or 60.0)
	local Maximum = math.max(Minimum,tonumber(Config.Route.ForwardLaunchMaximum) or 200.0)
	local PointDistance = Distance(Frame.Start,Point)
	if PointDistance < Minimum or PointDistance > Maximum then
		return nil,("no viario fora do intervalo frontal: %.1f m"):format(PointDistance)
	end

	local Dot = ForwardDot(Frame.Start,Frame.Forward,Point)
	if Dot < (tonumber(Config.Route.MinimumFirstCheckpointDot) or 0.30) then
		return nil,("no viario nao ficou a frente: dot %.2f"):format(Dot)
	end

	local RequestedDistance = tonumber(Config.Route.ForwardLaunchDistance) or 120.0
	local Ideal = {
		x = Frame.Start.x + (Frame.Forward.x * RequestedDistance),
		y = Frame.Start.y + (Frame.Forward.y * RequestedDistance),
		z = Frame.Start.z
	}
	local Tolerance = math.max(10.0,tonumber(Config.Route.ForwardLaunchNodeTolerance) or 80.0)
	if Distance(Ideal,Point) > Tolerance then
		return nil,"no viario distante demais do ponto frontal solicitado"
	end

	return Point,nil,Dot
end

local function ContinuePreparation(Session,Frame,LaunchAnchor)
	if not Session or Session.Cleaned or Session.Status ~= "route_anchor" then
		return
	end

	Session.AnchorToken = nil
	Session.Status = "reserving"
	local Route,Destination,_,RouteMetadata = BuildRoute(Frame.Start,Session.Distance,Frame.Passport,Frame.Forward,{
		RememberDestination = false,
		LaunchAnchor = LaunchAnchor
	})
	if not Route then
		local RouteReason = RouteMetadata and RouteMetadata.Reason or "nao foi encontrada uma rota segura a frente"
		CancelSession(Session,("%s Posicione os veiculos em outra direcao e tente novamente."):format(RouteReason),false)
		return
	end

	local Paid,PaymentReason = ReserveMoney(Session)
	if not Paid then
		Session.Status = Session.Mode == "npc" and "npc_offer" or "lobby"
		Session.Confirmed = {}
		if Session.Mode == "player" or Session.Mode == "test" then
			BroadcastLobby(Session,false)
		elseif Session.Mode == "npc" and SourceOnline(Session.Owner) then
			TriggerClientEvent("af_illegal_races:OpenNpcOffer",Session.Owner,{
				id = Session.Id,
				stake = Config.NpcRace.Stake,
				prize = Config.NpcRace.WinnerPayment,
				opponent = Session.NpcName,
				vehicle = Session.NpcVehicleLabel
			})
		end
		for _,Source in ipairs(ParticipantSources(Session)) do
			Notify(Source,"Racha",PaymentReason or "Nao foi possivel reservar a aposta.","vermelho",6000)
		end
		return
	end

	Session.Route = Route
	Session.RouteFrame = Frame
	Session.RouteMetadata = RouteMetadata
	Session.RouteDistance = RouteDistance(Frame.Start,Route)
	Session.Destination = Destination
	if RouteMetadata and RouteMetadata.DestinationIndex then
		LastDestination[Frame.Passport] = RouteMetadata.DestinationIndex
	end
	Session.Status = "countdown"
	Session.Progress = {}
	Session.LastCheckpointAt = {}
	Session.LastPoint = {}
	Session.ExitSince = {}
	Session.Tokens = {}
	Session.StartCoords = {}
	Session.LastDispatchAt = 0
	Session.NpcProgress = 0
	Session.VirtualProgress = 0

	for _,Source in ipairs(ParticipantSources(Session)) do
		local Current = DriverContext(Source,true)
		if not Current then
			CancelSession(Session,"Um participante ficou indisponivel durante a preparacao.",true)
			return
		end

		Session.Progress[Source] = 0
		Session.LastCheckpointAt[Source] = GetGameTimer()
		Session.LastPoint[Source] = PlainCoords(Current.VehicleCoords or Current.Coords)
		Session.StartCoords[Source] = PlainCoords(Current.VehicleCoords or Current.Coords)
		Session.Tokens[Source] = NewToken(Session.Id,Session.Passports[Source])
		SetRaceState(Source,Session.Id)
	end

	for _,Source in ipairs(ParticipantSources(Session)) do
		TriggerClientEvent("af_illegal_races:Prepare",Source,PreparePayload(Session,Source))
	end

	if Session.Mode == "npc" then
		Session.NpcLastPoint = PlainCoords(GetEntityCoords(EntityFromNetwork(Session.NpcVehicleNet)))
		Session.NpcLastCheckpointAt = GetGameTimer()
		local Passport = Session.Passports[Session.Owner]
		local History = LoadNpcHistory(Passport)
		History.Cooldown = os.time() + Config.NpcRace.Cooldown
		SaveNpcHistory(Passport)
	end

	Debug(("race=%s state=stake_reserved pot=%s heading=%.1f destination_dot=%.2f first_dot=%.2f launch_anchor=%s"):format(
		Session.Id,
		Session.Pot or 0,
		tonumber(Frame.Heading) or 0.0,
		tonumber(RouteMetadata and RouteMetadata.DestinationDot) or 0.0,
		tonumber(RouteMetadata and RouteMetadata.FirstDot) or 0.0,
		tostring(RouteMetadata and RouteMetadata.HasLaunchAnchor == true)
	))
	SetTimeout(750,function()
		if Sessions[Session.Id] ~= Session or Session.Status ~= "countdown" then
			return
		end

		local DurationMs = math.max(1000,math.floor((tonumber(Config.CountdownSeconds) or 5) * 1000))
		Session.CountdownStartedAt = GetGameTimer()
		Session.StartAt = Session.CountdownStartedAt + DurationMs
		for _,Source in ipairs(ParticipantSources(Session)) do
			local OneWayLatency = math.max(0,math.floor((tonumber(GetPlayerPing(Source)) or 0) * 0.5))
			TriggerClientEvent("af_illegal_races:Countdown",Source,Session.Id,Config.CountdownSeconds,{
				durationMs = DurationMs,
				remainingMs = math.max(750,DurationMs - OneWayLatency),
				latencyMs = OneWayLatency,
				startAt = Session.StartAt
			})
		end

		SetTimeout(DurationMs,function()
			StartSession(Session)
		end)
	end)
end

PrepareSession = function(Session)
	if not Session or Session.Cleaned or (Session.Status ~= "lobby" and Session.Status ~= "npc_offer") then
		return
	end

	local Valid,Reason = ValidatePlayerSession(Session)
	if not Valid then
		CancelSession(Session,Reason or "Participante indisponivel.",false)
		return
	end

	local Frame,FrameReason = RouteFrame(Session)
	if not Frame then
		CancelSession(Session,FrameReason or "Nao foi possivel determinar a direcao da largada.",false)
		return
	end

	Session.Status = "route_anchor"
	Session.RouteFrame = Frame
	if Config.Route.UseForwardLaunchCheckpoint == false then
		ContinuePreparation(Session,Frame,nil)
		return
	end

	local Owner = Session.Mode == "player" and Session.Challenger or Session.Owner
	Session.AnchorToken = NewToken(Session.Id,Frame.Passport)
	local AnchorToken = Session.AnchorToken
	TriggerClientEvent("af_illegal_races:ResolveLaunchAnchor",Owner,{
		raceId = Session.Id,
		token = AnchorToken,
		start = Frame.Start,
		forward = Frame.Forward,
		distance = tonumber(Config.Route.ForwardLaunchDistance) or 120.0
	})

	SetTimeout(math.max(500,math.floor(tonumber(Config.Route.ForwardLaunchRequestTimeout) or 2000)),function()
		if Sessions[Session.Id] == Session and Session.Status == "route_anchor" and Session.AnchorToken == AnchorToken then
			Debug(("race=%s launch_anchor=timeout fallback=forward_route"):format(Session.Id))
			ContinuePreparation(Session,Frame,nil)
		end
	end)
end

RegisterNetEvent("af_illegal_races:LaunchAnchorResolved",function(RaceId,Token,Payload)
	local Source = source
	local Session = Sessions[tonumber(RaceId)]
	if not Session or Session.Cleaned or Session.Status ~= "route_anchor" or Session.AnchorToken ~= tostring(Token or "") then
		return
	end

	local Owner = Session.Mode == "player" and Session.Challenger or Session.Owner
	if Source ~= Owner or not RateAllowed(Source,"launch_anchor",500) then
		return
	end

	local Anchor,Reason,Dot = ValidateLaunchAnchor(Session.RouteFrame,Payload)
	if Anchor then
		Debug(("race=%s launch_anchor=accepted distance=%.1f dot=%.2f"):format(Session.Id,Distance(Session.RouteFrame.Start,Anchor),Dot or 0.0))
	else
		Debug(("race=%s launch_anchor=rejected reason=%s fallback=forward_route"):format(Session.Id,Reason or "invalid"))
	end
	ContinuePreparation(Session,Session.RouteFrame,Anchor)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PROGRESS
-----------------------------------------------------------------------------------------------------------------------------------------
local function BroadcastProgress(Session)
	for _,Source in ipairs(ParticipantSources(Session)) do
		if SourceOnline(Source) then
			local OpponentProgress = 0
			if Session.Mode == "player" then
				OpponentProgress = Session.Progress[OtherPlayer(Session,Source)] or 0
			elseif Session.Mode == "npc" then
				OpponentProgress = Session.NpcProgress or 0
			elseif Session.Mode == "test" then
				OpponentProgress = Session.VirtualProgress or 0
			end

			TriggerClientEvent("af_illegal_races:Progress",Source,{
				current = Session.Progress[Source] or 0,
				opponent = OpponentProgress,
				total = #Session.Route
			})
		end
	end
end

local function CheckpointPlausible(Session,Key,Point)
	local LastPoint = Session.LastPoint[Key]
	local LastAt = Session.LastCheckpointAt[Key] or Session.StartedAt or GetGameTimer()
	local Travel = Distance(LastPoint,Point)
	local Minimum = math.max(0,math.floor((Travel / Config.MaximumPlausibleSpeed) * 1000) - Config.CheckpointTimeTolerance)
	return (GetGameTimer() - LastAt) >= Minimum
end

local function MaybeDispatchUpdate(Session,Point)
	if not Config.Dispatch.UpdatesEnabled or Session.Status ~= "racing" then
		return
	end

	if os.time() - (Session.LastDispatchAt or 0) < Config.Dispatch.UpdateInterval then
		return
	end

	if math.random(1,100) <= Config.Dispatch.UpdateChance then
		DispatchAlert(Session,Point,true)
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- NETWORK EVENTS
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("af_illegal_races:ChallengePlayer",function(TargetSource,OwnVehicleNet,TargetVehicleNet,OwnVehicleLabel,TargetVehicleLabel)
	local Source = source
	TargetSource = tonumber(TargetSource) or 0
	if not RateAllowed(Source,"challenge",1500) then
		return
	end

	if Source == TargetSource or TargetSource <= 0 then
		return
	end

	if SessionFor(Source) or SessionFor(TargetSource) or ChallengeBySource[Source] or ChallengeBySource[TargetSource] then
		Notify(Source,"Racha","Um dos pilotos ja esta ocupado com outro racha.","amarelo")
		return
	end

	local Challenger,Reason = DriverContext(Source)
	if not Challenger then
		Notify(Source,"Racha",Reason,"amarelo")
		return
	end

	local Challenged,TargetReason = DriverContext(TargetSource)
	if not Challenged then
		Notify(Source,"Racha",TargetReason or "O outro motorista nao esta disponivel.","amarelo")
		return
	end

	if Challenger.Bucket ~= Challenged.Bucket or Distance(Challenger.Coords,Challenged.Coords) > Config.ChallengeDistance then
		Notify(Source,"Racha","Aproxime-se mais do outro motorista.","amarelo")
		return
	end

	if Challenger.VehicleNet ~= tonumber(OwnVehicleNet) or Challenged.VehicleNet ~= tonumber(TargetVehicleNet) then
		Notify(Source,"Racha","Os veiculos do desafio mudaram.","vermelho")
		return
	end

	local RaceId = NewRaceId()
	local Challenge = {
		Id = RaceId,
		Challenger = Source,
		Challenged = TargetSource,
		ChallengerVehicle = SafeLabel(OwnVehicleLabel,"Veiculo"),
		ChallengedVehicle = SafeLabel(TargetVehicleLabel,"Veiculo"),
		ExpiresAt = os.time() + Config.ChallengeTimeout
	}

	Challenges[RaceId] = Challenge
	ChallengeBySource[Source] = RaceId
	ChallengeBySource[TargetSource] = RaceId
	Notify(Source,"Racha","Desafio enviado. Aguardando resposta.","azul")
	Debug(("race=%s state=challenge_created challenger=%s challenged=%s"):format(RaceId,Source,TargetSource))

	CreateThread(function()
		local ChallengerName = vRP.FullName(Challenger.Passport) or "Um piloto"
		local Accepted = vRP.Request(TargetSource,"Racha clandestino",("%s desafiou voce para um racha. Deseja negociar a aposta?"):format(ChallengerName))
		local Current = Challenges[RaceId]
		if not Current then
			return
		end

		if os.time() >= Current.ExpiresAt then
			ClearChallenge(Current)
			Notify(Source,"Racha","O desafio expirou.","amarelo")
			return
		end

		if Accepted then
			Debug(("race=%s state=challenge_accepted"):format(RaceId))
			MoveChallengeToLobby(Current)
		else
			ClearChallenge(Current)
			Notify(Source,"Racha","O desafio foi recusado ou expirou.","amarelo")
			Notify(TargetSource,"Racha","Voce recusou o desafio.","amarelo")
		end
	end)
end)

RegisterNetEvent("af_illegal_races:ChallengeNpc",function(NpcPedNet,NpcVehicleNet,OwnVehicleNet,OwnVehicleLabel,NpcVehicleLabel)
	local Source = source
	if not Config.NpcRace.Enabled or not RateAllowed(Source,"npcChallenge",1500) then
		return
	end

	if SessionFor(Source) or ChallengeBySource[Source] then
		Notify(Source,"Racha","Voce ja esta ocupado com outro racha.","amarelo")
		return
	end

	local Context,Reason = DriverContext(Source)
	if not Context then
		Notify(Source,"Racha",Reason,"amarelo")
		return
	end

	if Context.VehicleNet ~= tonumber(OwnVehicleNet) then
		Notify(Source,"Racha","Seu veiculo mudou antes do desafio.","vermelho")
		return
	end

	local Allowed,AllowedReason = NpcRaceAllowed(Context.Passport)
	if not Allowed then
		Notify(Source,"Racha",AllowedReason,"amarelo",6000)
		return
	end

	local NpcPed = EntityFromNetwork(NpcPedNet)
	local NpcVehicle = EntityFromNetwork(NpcVehicleNet)
	if NpcPed == 0 or NpcVehicle == 0 or GetEntityType(NpcPed) ~= 1 or IsPedAPlayer(NpcPed) or GetPedInVehicleSeat(NpcVehicle,-1) ~= NpcPed then
		Notify(Source,"Racha","O piloto NPC nao esta disponivel.","amarelo")
		return
	end

	if GetEntityRoutingBucket(NpcVehicle) ~= Context.Bucket or Distance(Context.Coords,GetEntityCoords(NpcVehicle)) > Config.ChallengeDistance then
		Notify(Source,"Racha","Aproxime-se mais do piloto NPC.","amarelo")
		return
	end

	if VehicleBlocked(NpcVehicle) then
		Notify(Source,"Racha","Este veiculo NPC nao pode participar.","amarelo")
		return
	end

	local RaceId = NewRaceId()
	local Session = {
		Id = RaceId,
		Mode = "npc",
		Status = "npc_offer",
		Owner = Source,
		Passports = { [Source] = Context.Passport },
		Names = { [Source] = vRP.FullName(Context.Passport) or "Piloto" },
		VehicleLabels = { [Source] = SafeLabel(OwnVehicleLabel,"Seu veiculo") },
		Vehicles = { [Source] = Context.VehicleNet },
		NpcPedNet = tonumber(NpcPedNet),
		NpcVehicleNet = tonumber(NpcVehicleNet),
		NpcName = "Piloto clandestino",
		NpcVehicleLabel = SafeLabel(NpcVehicleLabel,"Veiculo rival"),
		Stake = Config.NpcRace.Stake,
		Distance = Config.NpcRace.Distance,
		CreatedAt = os.time(),
		ExpiresAt = os.time() + Config.ChallengeTimeout
	}

	Sessions[RaceId] = Session
	SessionBySource[Source] = RaceId
	TriggerClientEvent("af_illegal_races:OpenNpcOffer",Source,{
		id = RaceId,
		stake = Config.NpcRace.Stake,
		prize = Config.NpcRace.WinnerPayment,
		opponent = Session.NpcName,
		vehicle = Session.NpcVehicleLabel
	})
	Debug(("race=%s state=npc_offer owner=%s"):format(RaceId,Source))
end)

RegisterNetEvent("af_illegal_races:UpdateTerms",function(RaceId,Stake,DistanceKey,RequestId)
	local Source = source
	local Session = Sessions[tonumber(RaceId)]
	if not Session or Session.Status ~= "lobby" or (Session.Mode ~= "player" and Session.Mode ~= "test") then
		TermsAck(Source,RequestId,false,"Sala de racha indisponivel.",Session)
		return
	end

	if not RateAllowed(Source,"terms",300) then
		TermsAck(Source,RequestId,false,"Aguarde um instante antes de alterar novamente.",Session)
		return
	end

	if Session.Mode == "player" and Source ~= Session.Challenger and Source ~= Session.Challenged then
		TermsAck(Source,RequestId,false,"Voce nao participa desta sala.",Session)
		return
	elseif Session.Mode == "test" and Source ~= Session.Owner then
		TermsAck(Source,RequestId,false,"Voce nao participa desta sala.",Session)
		return
	end

	Stake = math.floor(tonumber(Stake) or 0)
	if Stake < Config.MinimumPlayerStake or Stake > Config.MaximumPlayerStake or not Config.DistanceOptions[DistanceKey] then
		Notify(Source,"Racha","Aposta ou distancia invalida.","vermelho")
		TermsAck(Source,RequestId,false,"Aposta ou distancia invalida.",Session)
		return
	end

	if Session.Stake == Stake and Session.Distance == DistanceKey then
		TermsAck(Source,RequestId,true,"Os termos ja estao atualizados.",Session)
		return
	end

	Session.Stake = Stake
	Session.Distance = DistanceKey
	Session.Revision = Session.Revision + 1
	Session.Confirmed = {}
	Session.VirtualConfirmed = nil
	Session.ExpiresAt = os.time() + Config.SetupTimeout
	Debug(("race=%s state=terms_updated revision=%s stake=%s distance=%s"):format(Session.Id,Session.Revision,Stake,DistanceKey))
	BroadcastLobby(Session,false)
	TermsAck(Source,RequestId,true,"Termos atualizados. Confirme a nova proposta.",Session)
end)

RegisterNetEvent("af_illegal_races:ConfirmLobby",function(RaceId,Revision)
	local Source = source
	local Session = Sessions[tonumber(RaceId)]
	if not Session or Session.Status ~= "lobby" or tonumber(Revision) ~= Session.Revision or not RateAllowed(Source,"confirm",500) then
		return
	end

	if Session.Mode == "player" and Source ~= Session.Challenger and Source ~= Session.Challenged then
		return
	elseif Session.Mode == "test" and Source ~= Session.Owner then
		return
	end

	Session.Confirmed[Source] = Session.Revision
	Session.ExpiresAt = os.time() + Config.SetupTimeout
	BroadcastLobby(Session,false)

	local Ready
	if Session.Mode == "player" then
		Ready = Session.Confirmed[Session.Challenger] == Session.Revision and Session.Confirmed[Session.Challenged] == Session.Revision
	else
		Ready = Session.Confirmed[Session.Owner] == Session.Revision and Session.VirtualConfirmed == Session.Revision
	end

	if Ready then
		Debug(("race=%s state=both_confirmed revision=%s"):format(Session.Id,Session.Revision))
		PrepareSession(Session)
	end
end)

RegisterNetEvent("af_illegal_races:ConfirmNpc",function(RaceId)
	local Source = source
	local Session = Sessions[tonumber(RaceId)]
	if not Session or Session.Mode ~= "npc" or Session.Status ~= "npc_offer" or Session.Owner ~= Source then
		return
	end

	PrepareSession(Session)
end)

RegisterNetEvent("af_illegal_races:Cancel",function(RaceId)
	local Source = source
	local Session = Sessions[tonumber(RaceId)] or SessionFor(Source)
	if not Session then
		return
	end

	local IsParticipant = false
	for _,Participant in ipairs(ParticipantSources(Session)) do
		if Participant == Source then
			IsParticipant = true
			break
		end
	end

	if not IsParticipant then
		return
	end

	if Session.Status == "racing" then
		Disqualify(Session,Source,"O adversario abandonou o racha.")
	else
		CancelSession(Session,"O atendimento do racha foi cancelado.",true)
	end
end)

RegisterNetEvent("af_illegal_races:Checkpoint",function(RaceId,Token,Index,VehicleNet)
	local Source = source
	local Session = Sessions[tonumber(RaceId)]
	if not Session or Session.Status ~= "racing" or Session.Tokens[Source] ~= Token or not RateAllowed(Source,"checkpoint",250) then
		return
	end

	Index = tonumber(Index) or 0
	local Expected = (Session.Progress[Source] or 0) + 1
	local Point = Session.Route[Expected]
	if Index ~= Expected or not Point then
		CheckpointDebug(Session,Source,("checkpoint_rejected reason=sequence expected=%s received=%s"):format(Expected,Index))
		return
	end

	local Context = DriverContext(Source,true)
	if not Context or Context.VehicleNet ~= Session.Vehicles[Source] or tonumber(VehicleNet) ~= Context.VehicleNet then
		CheckpointDebug(Session,Source,"checkpoint_rejected reason=vehicle")
		return
	end

	local VehicleCoords = Context.VehicleCoords or Context.Coords
	if not CheckpointPositionValid(Point,VehicleCoords) then
		CheckpointDebug(Session,Source,("checkpoint_rejected reason=position horizontal=%.2f vertical=%.2f radius=%.2f"):format(HorizontalDistance(VehicleCoords,Point),VerticalDifference(VehicleCoords,Point),PointRadius(Point)))
		return
	end

	if not CheckpointPlausible(Session,Source,Point) then
		Debug(("race=%s checkpoint rejeitado source=%s index=%s motivo=tempo_impossivel"):format(Session.Id,Source,Index))
		return
	end

	Session.Progress[Source] = Expected
	Session.LastCheckpointAt[Source] = GetGameTimer()
	Session.LastPoint[Source] = PlainCoords(VehicleCoords)
	TriggerClientEvent("af_illegal_races:CheckpointAccepted",Source,{
		raceId = Session.Id,
		acceptedSequence = Expected,
		nextSequence = Expected + 1,
		completed = Expected >= #Session.Route
	})
	BroadcastProgress(Session)
	MaybeDispatchUpdate(Session,PlainCoords(Point))
	Debug(("race=%s checkpoint source=%s index=%s/%s"):format(Session.Id,Source,Expected,#Session.Route))

	if Expected >= #Session.Route then
		FinishSession(Session,Source)
	end
end)

RegisterNetEvent("af_illegal_races:NpcCheckpoint",function(RaceId,Token,Index)
	local Source = source
	local Session = Sessions[tonumber(RaceId)]
	if not Session or Session.Mode ~= "npc" or Session.Status ~= "racing" or Session.Owner ~= Source or Session.Tokens[Source] ~= Token then
		return
	end

	Index = tonumber(Index) or 0
	local Expected = (Session.NpcProgress or 0) + 1
	local Point = Session.Route[Expected]
	if Index ~= Expected or not Point then
		return
	end

	local Vehicle = EntityFromNetwork(Session.NpcVehicleNet)
	local Ped = EntityFromNetwork(Session.NpcPedNet)
	if Vehicle == 0 or Ped == 0 or GetPedInVehicleSeat(Vehicle,-1) ~= Ped then
		return
	end

	local Coords = GetEntityCoords(Vehicle)
	if not CheckpointPositionValid(Point,Coords) then
		return
	end

	local LastPoint = Session.NpcLastPoint
	local Travel = Distance(LastPoint,Point)
	local Minimum = math.max(0,math.floor((Travel / Config.MaximumPlausibleSpeed) * 1000) - Config.CheckpointTimeTolerance)
	if GetGameTimer() - (Session.NpcLastCheckpointAt or Session.StartedAt) < Minimum then
		return
	end

	Session.NpcProgress = Expected
	Session.NpcLastPoint = PlainCoords(Point)
	Session.NpcLastCheckpointAt = GetGameTimer()
	Session.NpcRecoveryAttempts = 0
	Session.NpcRecoveryDistance = nil
	Session.NpcLastRecoveryAt = 0
	TriggerClientEvent("af_illegal_races:NpcCheckpointAccepted",Source,Expected)
	BroadcastProgress(Session)
	MaybeDispatchUpdate(Session,PlainCoords(Point))

	if Expected >= #Session.Route then
		FinishSession(Session,"npc")
	end
end)

RegisterNetEvent("af_illegal_races:NpcRecovery",function(RaceId,Token)
	local Source = source
	local Session = Sessions[tonumber(RaceId)]
	if not Session or Session.Mode ~= "npc" or Session.Status ~= "racing" or Session.Owner ~= Source or Session.Tokens[Source] ~= Token then
		return
	end

	local Interval = math.max(1000,tonumber(Config.NpcRace.StuckCheckInterval) or 3000)
	if not RateAllowed(Source,"npcRecovery",Interval) then
		return
	end

	local Vehicle = EntityFromNetwork(Session.NpcVehicleNet)
	local Ped = EntityFromNetwork(Session.NpcPedNet)
	local Point = Session.Route[(Session.NpcProgress or 0) + 1]
	if Vehicle == 0 or Ped == 0 or not Point or GetPedInVehicleSeat(Vehicle,-1) ~= Ped then
		return
	end

	local Now = GetGameTimer()
	local StuckTimeout = tonumber(Config.NpcRace.StuckTimeout) or 7000
	if Now - (Session.NpcLastRecoveryAt or Session.StartedAt or Now) < StuckTimeout then
		return
	end

	local Speed = GetEntitySpeed(Vehicle)
	if Speed > ((tonumber(Config.NpcRace.StuckMinimumSpeed) or 1.5) + 0.75) then
		return
	end

	local CurrentDistance = Distance(GetEntityCoords(Vehicle),Point)
	local MinimumImprovement = tonumber(Config.NpcRace.MinimumDistanceImprovement) or 3.0
	if Session.NpcRecoveryDistance and CurrentDistance <= Session.NpcRecoveryDistance - MinimumImprovement then
		Session.NpcRecoveryAttempts = 0
	end

	Session.NpcLastRecoveryAt = Now
	Session.NpcRecoveryDistance = CurrentDistance
	Session.NpcRecoveryAttempts = (Session.NpcRecoveryAttempts or 0) + 1
	local MaximumAttempts = math.max(1,math.floor(tonumber(Config.NpcRace.MaximumRecoveryAttempts) or 3))
	Debug(("race=%s npc_recovery=%s/%s speed=%.2f distance=%.1f"):format(Session.Id,Session.NpcRecoveryAttempts,MaximumAttempts,Speed,CurrentDistance))

	if Session.NpcRecoveryAttempts >= MaximumAttempts then
		Debug(("race=%s mode=npc rival desclassificado apos recuperacoes sem progresso"):format(Session.Id))
		FinishSession(Session,Source,"O piloto clandestino ficou preso e foi desclassificado.")
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- COMMANDS
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand(Config.Command,function(Source)
	if Source > 0 then
		TriggerClientEvent("af_illegal_races:AttemptCommand",Source)
	end
end)

RegisterCommand(Config.CancelCommand,function(Source)
	if Source <= 0 then
		return
	end

	local ChallengeId = ChallengeBySource[Source]
	if ChallengeId and Challenges[ChallengeId] then
		local Challenge = Challenges[ChallengeId]
		ClearChallenge(Challenge)
		Notify(Challenge.Challenger,"Racha","O desafio foi cancelado.","amarelo")
		Notify(Challenge.Challenged,"Racha","O desafio foi cancelado.","amarelo")
		return
	end

	local Session = SessionFor(Source)
	if not Session then
		Notify(Source,"Racha","Voce nao possui um racha ativo.","amarelo")
		return
	end

	if Session.Status == "racing" then
		Disqualify(Session,Source,"O adversario abandonou o racha.")
	else
		CancelSession(Session,"O racha foi cancelado por um participante.",true)
	end
end)

RegisterCommand("racha_checkpointdebug",function(Source)
	if Source <= 0 or tonumber(vRP.Passport(Source)) ~= tonumber((Config.RouteAudit and Config.RouteAudit.AdminPassport) or Config.TestAdminPassport) then
		return
	end

	local Session = SessionFor(Source)
	if not Session then
		Notify(Source,"Racha","Inicie um racha antes de ativar o diagnostico de checkpoint.","amarelo")
		return
	end

	Session.CheckpointDebug = Session.CheckpointDebug or {}
	Session.CheckpointDebug[Source] = not Session.CheckpointDebug[Source]
	TriggerClientEvent("af_illegal_races:CheckpointDebug",Source,Session.CheckpointDebug[Source])
	Notify(Source,"Racha",Session.CheckpointDebug[Source] and "Diagnostico de checkpoint ativado no F8." or "Diagnostico de checkpoint desativado.","azul")
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- ROUTE AUDIT
-----------------------------------------------------------------------------------------------------------------------------------------
local function RouteAuditAdmin(Source)
	return Config.RouteAudit and Config.RouteAudit.Enabled and Source > 0 and tonumber(vRP.Passport(Source)) == tonumber(Config.RouteAudit.AdminPassport or Config.TestAdminPassport)
end

local function RouteAuditDistance(Start,Route)
	local Total = 0.0
	local Previous = Start
	for _,Point in ipairs(Route or {}) do
		Total = Total + Distance(Previous,Point)
		Previous = Point
	end
	return Total
end

RegisterCommand("racha_rotateste",function(Source,Args)
	if not RouteAuditAdmin(Source) then
		return
	end

	if SessionFor(Source) or ChallengeBySource[Source] then
		Notify(Source,"Auditoria de rota","Cancele o racha atual antes de auditar rotas.","amarelo")
		return
	end

	local Aliases = {
		curta = "Short",
		short = "Short",
		media = "Medium",
		medium = "Medium",
		longa = "Long",
		long = "Long"
	}
	local DistanceKey = Aliases[string.lower(tostring(Args[1] or "media"))]
	if not DistanceKey then
		Notify(Source,"Auditoria de rota","Use /racha_rotateste curta, media ou longa.","amarelo")
		return
	end

	local Context,Reason = DriverContext(Source,true)
	if not Context then
		Notify(Source,"Auditoria de rota",Reason or "Entre em um veiculo para iniciar a auditoria.","vermelho")
		return
	end

	local Start = PlainCoords(Context.VehicleCoords or Context.Coords)
	local Route,Destination,DirectDistance,Metadata = BuildRoute(Start,DistanceKey,Context.Passport,Context.Forward,{ RememberDestination = false })
	if not Route then
		Notify(Source,"Auditoria de rota",Metadata and Metadata.Reason or "Nao foi possivel gerar uma rota para esta faixa.","vermelho")
		return
	end

	local Audit = {
		Id = ("%s:%s"):format(Context.Passport,os.time()),
		Passport = Context.Passport,
		DistanceKey = DistanceKey,
		Start = Start,
		Heading = Context.Heading,
		Forward = Context.Forward,
		Route = Route,
		Destination = Destination,
		DestinationDot = Metadata and Metadata.DestinationDot or 0.0,
		FirstDot = Metadata and Metadata.FirstDot or 0.0,
		DirectDistance = math.floor(tonumber(DirectDistance) or Distance(Context.Coords,Route[#Route])),
		ApproximateDistance = math.floor(RouteAuditDistance(Start,Route)),
		Index = 1,
		CreatedAt = os.time()
	}
	RouteAudits[Source] = Audit
	TriggerClientEvent("af_illegal_races:RouteAuditStart",Source,Audit)
	Notify(Source,"Auditoria de rota",("%s | heading %.1f | destino dot %.2f | primeiro dot %.2f | %.2f km"):format(Destination,Audit.Heading,Audit.DestinationDot,Audit.FirstDot,Audit.ApproximateDistance / 1000.0),"azul",9000)
	Debug(("route_audit=%s passport=%s distance=%s heading=%.1f forward=(%.3f,%.3f) destination=%s destination_dot=%.3f first_dot=%.3f direct=%sm approximate=%sm"):format(
		Audit.Id,
		Context.Passport,
		DistanceKey,
		Audit.Heading,
		Audit.Forward.x,
		Audit.Forward.y,
		Destination,
		Audit.DestinationDot,
		Audit.FirstDot,
		Audit.DirectDistance,
		Audit.ApproximateDistance
	))
end)

RegisterCommand("racha_rotadirecao",function(Source)
	if not RouteAuditAdmin(Source) then
		return
	end

	if SessionFor(Source) or ChallengeBySource[Source] then
		Notify(Source,"Auditoria de rota","Cancele o racha atual antes de auditar direcoes.","amarelo")
		return
	end

	local Context,Reason = DriverContext(Source,true)
	if not Context then
		Notify(Source,"Auditoria de rota",Reason or "Entre em um veiculo para auditar a direcao.","vermelho")
		return
	end

	local Start = PlainCoords(Context.VehicleCoords or Context.Coords)
	local Results = {}
	for _,DistanceKey in ipairs({ "Short", "Medium", "Long" }) do
		local Route,Destination,_,Metadata = BuildRoute(Start,DistanceKey,Context.Passport,Context.Forward,{ RememberDestination = false })
		Results[#Results + 1] = {
			Distance = DistanceKey,
			Destination = Destination,
			DestinationDot = Metadata and Metadata.DestinationDot or nil,
			FirstDot = Metadata and Metadata.FirstDot or nil,
			Points = Route and #Route or 0,
			Reason = Metadata and Metadata.Reason or nil
		}
	end

	print(("[af_illegal_races] route_direction passport=%s heading=%.1f forward=(%.3f,%.3f) results=%s"):format(
		Context.Passport,
		Context.Heading,
		Context.Forward.x,
		Context.Forward.y,
		json.encode(Results)
	))
	Notify(Source,"Auditoria de rota",("Heading %.1f | frente x %.2f y %.2f | resultados enviados ao console."):format(Context.Heading,Context.Forward.x,Context.Forward.y),"azul",9000)
end)

RegisterCommand("racha_proximarota",function(Source)
	if not RouteAuditAdmin(Source) then
		return
	end

	local Audit = RouteAudits[Source]
	if not Audit then
		Notify(Source,"Auditoria de rota","Inicie com /racha_rotateste curta, media ou longa.","amarelo")
		return
	end

	Audit.Index = Audit.Index >= #Audit.Route and 1 or Audit.Index + 1
	TriggerClientEvent("af_illegal_races:RouteAuditNext",Source,Audit.Index)
	local Point = Audit.Route[Audit.Index]
	Notify(Source,"Auditoria de rota",("Ponto %s/%s: %s"):format(Audit.Index,#Audit.Route,Point.label or "sem nome"),"azul",5000)
end)

RegisterCommand("racha_cancelarrotateste",function(Source)
	if not RouteAuditAdmin(Source) then
		return
	end

	RouteAudits[Source] = nil
	TriggerClientEvent("af_illegal_races:RouteAuditStop",Source)
	Notify(Source,"Auditoria de rota","Auditoria encerrada sem aposta, premio ou dispatch.","verde",5000)
end)

RegisterCommand("racha_marcarrotaproblema",function(Source,Args)
	if not RouteAuditAdmin(Source) then
		return
	end

	local Audit = RouteAudits[Source]
	if not Audit then
		Notify(Source,"Auditoria de rota","Nao existe uma rota em auditoria.","amarelo")
		return
	end

	local Reason = SafeLabel(table.concat(Args or {}," "),"Problema identificado em teste visual")
	local Success,Error = pcall(function()
		local Key = Config.RouteAudit.IssueDataKey or "StreetRace:RouteIssues"
		local Issues = vRP.GetSrvData(Key,true)
		if type(Issues) ~= "table" then
			Issues = {}
		end
		Issues[#Issues + 1] = {
			Version = 1,
			AuditId = Audit.Id,
			Passport = Audit.Passport,
			Distance = Audit.DistanceKey,
			Destination = Audit.Destination,
			Heading = Audit.Heading,
			Forward = Audit.Forward,
			DestinationDot = Audit.DestinationDot,
			FirstDot = Audit.FirstDot,
			Route = Audit.Route,
			Reason = Reason,
			CreatedAt = os.time()
		}
		while #Issues > 100 do
			table.remove(Issues,1)
		end
		vRP.SetSrvData(Key,Issues,true)
	end)

	if Success then
		Notify(Source,"Auditoria de rota","Rota marcada como problematica para revisao.","verde",6000)
		Debug(("route_audit=%s marked_problem reason=%s"):format(Audit.Id,Reason))
	else
		Notify(Source,"Auditoria de rota","Falha ao registrar. O problema foi enviado ao console.","vermelho",6000)
		Debug(("route_audit=%s persistence_error=%s reason=%s"):format(Audit.Id,tostring(Error),Reason))
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- TEST MODE
-----------------------------------------------------------------------------------------------------------------------------------------
local function TestEnabled()
	return Config.TestMode or GetConvarInt(Config.TestConvar,0) == 1
end

local function TestAdmin(Source)
	return TestEnabled() and tonumber(vRP.Passport(Source)) == tonumber(Config.TestAdminPassport)
end

if TestEnabled() then
	local function StartOpponentBlipTest(Source,Moving)
		if SessionFor(Source) then
			Notify(Source,"Racha teste","Encerre a corrida antes de testar o blip isolado.","amarelo")
			return false
		end

		local Context,Reason = DriverContext(Source,true)
		if not Context then
			Notify(Source,"Racha teste",Reason or "Entre em um veiculo para testar o blip.","vermelho")
			return false
		end

		OpponentBlipTests[Source] = {
			Center = PlainCoords(Context.VehicleCoords or Context.Coords),
			Forward = Context.Forward,
			Heading = Context.Heading,
			StartedAt = GetGameTimer(),
			Moving = Moving == true
		}
		return true
	end

	local function SendOpponentBlipTest(Source,Test)
		local Radius = math.max(10.0,tonumber(Config.OpponentBlip and Config.OpponentBlip.TestRadius) or 60.0)
		local X
		local Y
		local Heading
		if Test.Moving then
			local Angle = ((GetGameTimer() - Test.StartedAt) / 1000.0) * 0.65
			X = Test.Center.x + (math.cos(Angle) * Radius)
			Y = Test.Center.y + (math.sin(Angle) * Radius)
			Heading = (math.deg(Angle) + 90.0) % 360.0
		else
			X = Test.Center.x + (Test.Forward.x * Radius)
			Y = Test.Center.y + (Test.Forward.y * Radius)
			Heading = Test.Heading
		end

		TriggerClientEvent("af_illegal_races:OpponentBlipTest",Source,{
			raceId = -1,
			x = X,
			y = Y,
			z = Test.Center.z,
			heading = Heading
		})
	end

	RegisterCommand("racha_test_player",function(Source)
		if not TestAdmin(Source) then
			return
		end

		if SessionFor(Source) or TestChallenges[Source] then
			Notify(Source,"Racha teste","Ja existe um teste em andamento.","amarelo")
			return
		end

		local Context,Reason = DriverContext(Source)
		if not Context then
			Notify(Source,"Racha teste",Reason,"amarelo")
			return
		end

		local RaceId = NewRaceId()
		TestChallenges[Source] = {
			Id = RaceId,
			Source = Source,
			VehicleNet = Context.VehicleNet,
			VehicleLabel = "Veiculo de teste",
			ExpiresAt = os.time() + Config.ChallengeTimeout
		}
		Notify(Source,"Racha teste","Desafio criado. Use /racha_test_accept para simular o aceite.","azul",7000)
		Debug(("race=%s state=test_challenge_created"):format(RaceId))
	end)

	RegisterCommand("racha_test_accept",function(Source)
		if not TestAdmin(Source) then
			return
		end

		local Challenge = TestChallenges[Source]
		if not Challenge then
			Notify(Source,"Racha teste","Crie o desafio com /racha_test_player.","amarelo")
			return
		end

		local Context,Reason = DriverContext(Source)
		if not Context or Context.VehicleNet ~= Challenge.VehicleNet then
			TestChallenges[Source] = nil
			Notify(Source,"Racha teste",Reason or "O veiculo de teste mudou.","vermelho")
			return
		end

		TestChallenges[Source] = nil
		local Session = {
			Id = Challenge.Id,
			Mode = "test",
			Status = "lobby",
			Owner = Source,
			Challenger = Source,
			Passports = { [Source] = Context.Passport },
			Names = { [Source] = vRP.FullName(Context.Passport) or "Administrador" },
			VehicleLabels = { [Source] = Challenge.VehicleLabel },
			Vehicles = { [Source] = Context.VehicleNet },
			Revision = 1,
			Stake = Config.InitialPlayerStake,
			Distance = "Medium",
			Confirmed = {},
			CreatedAt = os.time(),
			ExpiresAt = os.time() + Config.SetupTimeout
		}

		Sessions[Session.Id] = Session
		SessionBySource[Source] = Session.Id
		BroadcastLobby(Session,true)
		Debug(("race=%s state=test_lobby_open"):format(Session.Id))
	end)

	RegisterCommand("racha_test_confirm",function(Source)
		if not TestAdmin(Source) then
			return
		end

		local Session = SessionFor(Source)
		if not Session or Session.Mode ~= "test" or Session.Status ~= "lobby" then
			return
		end

		Session.VirtualConfirmed = Session.Revision
		BroadcastLobby(Session,false)
		if Session.Confirmed[Source] == Session.Revision then
			PrepareSession(Session)
		end
	end)

	RegisterCommand("racha_test_start",function(Source)
		if not TestAdmin(Source) then
			return
		end

		local Session = SessionFor(Source)
		if not Session or Session.Mode ~= "test" or Session.Status ~= "lobby" then
			return
		end

		Session.Confirmed[Source] = Session.Revision
		Session.VirtualConfirmed = Session.Revision
		BroadcastLobby(Session,false)
		PrepareSession(Session)
	end)

	RegisterCommand("racha_test_finish",function(Source)
		if not TestAdmin(Source) then
			return
		end

		local Session = SessionFor(Source)
		if Session and Session.Mode == "test" and Session.Status == "racing" then
			FinishSession(Session,"virtual","O Piloto de Teste chegou primeiro.")
		end
	end)

	RegisterCommand("racha_test_lose",function(Source)
		if not TestAdmin(Source) then
			return
		end

		local Session = SessionFor(Source)
		if Session and Session.Mode == "test" and Session.Status == "racing" then
			FinishSession(Session,Source,"O Piloto de Teste foi desclassificado.")
		end
	end)

	RegisterCommand("racha_test_disconnect",function(Source)
		if not TestAdmin(Source) then
			return
		end

		local Session = SessionFor(Source)
		if not Session or Session.Mode ~= "test" then
			return
		end

		if Session.Status == "racing" then
			FinishSession(Session,Source,"O Piloto de Teste desconectou.")
		else
			CancelSession(Session,"O Piloto de Teste desconectou antes da largada.",true)
		end
	end)

	RegisterCommand("racha_test_cancel",function(Source)
		if not TestAdmin(Source) then
			return
		end

		TestChallenges[Source] = nil
		local Session = SessionFor(Source)
		if Session and Session.Mode == "test" then
			CancelSession(Session,"Teste cancelado pelo administrador.",true)
		end
	end)

	RegisterCommand("racha_debug",function(Source)
		if not TestAdmin(Source) then
			return
		end

		local Session = SessionFor(Source)
		local Challenge = TestChallenges[Source]
		print(("[af_illegal_races] DEBUG source=%s challenge=%s session=%s"):format(Source,json.encode(Challenge or {}),json.encode(Session or {})))
		Notify(Source,"Racha debug",("Sessao: %s | Estado: %s"):format(Session and Session.Id or "nenhuma",Session and Session.Status or "inativo"),"azul",7000)
	end)

	RegisterCommand("racha_test_opponentblip",function(Source)
		if TestAdmin(Source) and StartOpponentBlipTest(Source,false) then
			SendOpponentBlipTest(Source,OpponentBlipTests[Source])
			Notify(Source,"Racha teste","Blip estatico criado a frente do veiculo.","azul",6000)
		end
	end)

	RegisterCommand("racha_test_opponentmove",function(Source)
		if not TestAdmin(Source) then
			return
		end

		local Test = OpponentBlipTests[Source]
		if not Test and not StartOpponentBlipTest(Source,true) then
			return
		end
		Test = OpponentBlipTests[Source]
		Test.Moving = true
		Test.StartedAt = GetGameTimer()
		SendOpponentBlipTest(Source,Test)
		Notify(Source,"Racha teste","Movimento sintetico do blip ativado.","azul",6000)
	end)

	RegisterCommand("racha_test_opponentblipoff",function(Source)
		if not TestAdmin(Source) then
			return
		end

		OpponentBlipTests[Source] = nil
		TriggerClientEvent("af_illegal_races:OpponentBlipTestStop",Source)
		Notify(Source,"Racha teste","Teste do blip encerrado.","verde",5000)
	end)

	CreateThread(function()
		while true do
			Wait(math.max(250,math.floor(tonumber(Config.OpponentBlip and Config.OpponentBlip.UpdateInterval) or 750)))
			for Source,Test in pairs(OpponentBlipTests) do
				if SourceOnline(Source) and TestAdmin(Source) and not SessionFor(Source) then
					SendOpponentBlipTest(Source,Test)
				else
					OpponentBlipTests[Source] = nil
					if SourceOnline(Source) then
						TriggerClientEvent("af_illegal_races:OpponentBlipTestStop",Source)
					end
				end
			end
		end
	end)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- OPPONENT BLIP
-----------------------------------------------------------------------------------------------------------------------------------------
local function OpponentSnapshot(Network,TargetSource)
	local Entity = EntityFromNetwork(Network)
	if Entity == 0 or not SourceOnline(TargetSource) then
		return nil
	end

	local EntityBucket = GetEntityRoutingBucket(Entity)
	if EntityBucket ~= GetPlayerRoutingBucket(TargetSource) then
		return nil
	end

	local Coords = GetEntityCoords(Entity)
	return {
		x = tonumber(Coords.x) or 0.0,
		y = tonumber(Coords.y) or 0.0,
		z = tonumber(Coords.z) or 0.0,
		heading = tonumber(GetEntityHeading(Entity)) or 0.0
	}
end

local function SendOpponentPosition(Session,TargetSource,OpponentNetwork)
	local Snapshot = OpponentSnapshot(OpponentNetwork,TargetSource)
	if not Snapshot then
		return false
	end

	Snapshot.raceId = Session.Id
	TriggerClientEvent("af_illegal_races:OpponentPosition",TargetSource,Snapshot)
	return true
end

CreateThread(function()
	while true do
		local Interval = math.max(250,math.floor(tonumber(Config.OpponentBlip and Config.OpponentBlip.UpdateInterval) or 750))
		Wait(Interval)
		if Config.OpponentBlip and Config.OpponentBlip.Enabled ~= false then
			for _,Session in pairs(Sessions) do
				if not Session.Cleaned and (Session.Status == "countdown" or Session.Status == "racing") then
					if Session.Mode == "player" and Config.OpponentBlip.PlayerRaces ~= false then
						if SourceOnline(Session.Challenger) and SourceOnline(Session.Challenged) and GetPlayerRoutingBucket(Session.Challenger) == GetPlayerRoutingBucket(Session.Challenged) then
							SendOpponentPosition(Session,Session.Challenger,Session.Vehicles[Session.Challenged])
							SendOpponentPosition(Session,Session.Challenged,Session.Vehicles[Session.Challenger])
						end
					elseif Session.Mode == "npc" and Config.OpponentBlip.NpcRaces ~= false and SourceOnline(Session.Owner) then
						SendOpponentPosition(Session,Session.Owner,Session.NpcVehicleNet)
					end
				end
			end
		end
	end
end)
-------------------------------------------------------------------------
-- WATCHDOG
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	while true do
		Wait(2000)
		local Now = os.time()

		for RaceId,Challenge in pairs(Challenges) do
			if Now >= Challenge.ExpiresAt then
				ClearChallenge(Challenge)
				Notify(Challenge.Challenger,"Racha","O desafio expirou.","amarelo")
				Notify(Challenge.Challenged,"Racha","O desafio expirou.","amarelo")
				Debug(("race=%s state=challenge_expired"):format(RaceId))
			end
		end

		for Source,Challenge in pairs(TestChallenges) do
			if Now >= Challenge.ExpiresAt then
				TestChallenges[Source] = nil
			end
		end

		local Snapshot = {}
		for _,Session in pairs(Sessions) do
			Snapshot[#Snapshot + 1] = Session
		end

		for _,Session in ipairs(Snapshot) do
			if not Session.Cleaned then
				if (Session.Status == "lobby" or Session.Status == "npc_offer") and Now >= Session.ExpiresAt then
					CancelSession(Session,"O tempo de preparacao expirou.",true)
				elseif Session.Status == "racing" then
					if Now >= Session.ExpiresAt then
						if Session.Mode == "player" then
							local FirstProgress = Session.Progress[Session.Challenger] or 0
							local SecondProgress = Session.Progress[Session.Challenged] or 0
							if FirstProgress > SecondProgress then
								FinishSession(Session,Session.Challenger,"Tempo limite encerrado.")
							elseif SecondProgress > FirstProgress then
								FinishSession(Session,Session.Challenged,"Tempo limite encerrado.")
							else
								CancelSession(Session,"Tempo limite encerrado sem vencedor.",true)
							end
						else
							CancelSession(Session,"Tempo limite encerrado sem vencedor.",true)
						end
					else
						for _,Source in ipairs(ParticipantSources(Session)) do
							if Sessions[Session.Id] == Session then
								if not SourceOnline(Source) or vRP.GetHealth(Source) <= 100 then
									Disqualify(Session,Source,"O adversario ficou inconsciente.")
									break
								end

								local Ped = GetPlayerPed(Source)
								local Vehicle = GetVehiclePedIsIn(Ped,false)
								local CorrectVehicle = Vehicle ~= 0 and NetworkGetNetworkIdFromEntity(Vehicle) == Session.Vehicles[Source] and GetPedInVehicleSeat(Vehicle,-1) == Ped
								if not CorrectVehicle then
									Session.ExitSince[Source] = Session.ExitSince[Source] or Now
									if Now - Session.ExitSince[Source] >= Config.VehicleExitGraceSeconds then
										Disqualify(Session,Source,"O adversario abandonou ou trocou de veiculo.")
										break
									end
								else
									Session.ExitSince[Source] = nil
								end
							end
						end

						if Sessions[Session.Id] == Session and Session.Mode == "npc" then
							if EntityFromNetwork(Session.NpcPedNet) == 0 or EntityFromNetwork(Session.NpcVehicleNet) == 0 then
								CancelSession(Session,"O piloto NPC desapareceu. A aposta foi devolvida.",true)
							end
						end
					end
				end
			end
		end
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- DISCONNECT
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("playerDropped",function()
	local Source = source
	RateLimits[Source] = nil
	TestChallenges[Source] = nil
	RouteAudits[Source] = nil
	OpponentBlipTests[Source] = nil

	local ChallengeId = ChallengeBySource[Source]
	local Challenge = ChallengeId and Challenges[ChallengeId]
	if Challenge then
		local Other = Challenge.Challenger == Source and Challenge.Challenged or Challenge.Challenger
		ClearChallenge(Challenge)
		Notify(Other,"Racha","O outro piloto desconectou antes de aceitar.","amarelo")
	end

	local Session = SessionFor(Source)
	if not Session then
		return
	end

	if Session.Status == "racing" then
		if Session.Mode == "player" then
			local Other = OtherPlayer(Session,Source)
			if Other and SourceOnline(Other) then
				FinishSession(Session,Other,"O adversario desconectou durante o racha.")
			else
				Debug(("race=%s desconexao dupla ou ordem ambigua; reembolsando passaportes"):format(Session.Id))
				CancelSession(Session,"Os participantes desconectaram sem vencedor verificavel.",true)
			end
		elseif Session.Mode == "npc" then
			FinishSession(Session,"npc","Voce desconectou durante o racha.")
		elseif Session.Mode == "test" then
			FinishSession(Session,"virtual","O administrador desconectou durante o teste.")
		end
	else
		CancelSession(Session,"Um participante desconectou antes da largada.",true)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- RESOURCE STOP
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("onResourceStop",function(Resource)
	if Resource ~= GetCurrentResourceName() then
		return
	end

	for _,Session in pairs(Sessions) do
		if Session.Escrow then
			RefundSession(Session,"reinicio do resource")
		end

		EndClients(Session,{
			result = "cancelled",
			title = "Racha interrompido",
			message = "O sistema foi reiniciado e a aposta foi devolvida."
		})
		for _,Source in ipairs(ParticipantSources(Session)) do
			SetRaceState(Source,false)
		end
	end
end)

exports("GetUndergroundRanking",function(Passport)
	Passport = tonumber(Passport)
	if not Passport then
		return { Enabled = Config.Ranking.Enabled == true, Personal = false, Ranking = {} }
	end

	return RankingSnapshot(Passport)
end)

Debug(("resource iniciado testMode=%s rotas=%s"):format(tostring(TestEnabled()),#RaceRouteNodes))
