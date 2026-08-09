local Proxy = module("vrp","lib/Proxy")
local vRP = Proxy.getInterface("vRP")

local ServerRequestId = 0
local Runtime = {
	Revision = 1,
	Status = "idle",
	Event = nil
}

local AllowedTransitions = {
	idle = { draft = true },
	draft = { announced = true, cancelled = true },
	announced = { betting_open = true, cancelled = true },
	betting_open = { betting_closed = true, cancelled = true },
	betting_closed = { cancelled = true },
	cancelled = { idle = true }
}

local StatusTextKeys = {
	idle = "StatusIdle",
	draft = "StatusDraft",
	announced = "StatusAnnounced",
	betting_open = "StatusBettingOpen",
	betting_closed = "StatusBettingClosed",
	cancelled = "StatusIdle"
}

local Notifications = Config.OperationalTexts.Notifications

local function nextServerRequestId()
	ServerRequestId = ServerRequestId + 1
	if ServerRequestId > 2147483647 then
		ServerRequestId = 1
	end

	return ServerRequestId
end

local function notify(Source,Message,Color)
	TriggerClientEvent("Notify",Source,Config.Texts.Notifications.Title,Message,Color or "amarelo",5000)
end

local function denialMessage(Reason)
	local Messages = Config.Texts.Notifications
	local Reasons = {
		invalid_source = Messages.InvalidRequest,
		invalid_character = Messages.InvalidCharacter,
		invalid_state = Messages.InvalidState
	}

	return Reasons[Reason] or Messages.InvalidRequest
end

local function copyTable(Source)
	local Result = {}
	for Key,Value in pairs(Source or {}) do
		Result[Key] = Value
	end
	return Result
end

local function interfaceTexts()
	local Texts = copyTable(Config.Texts.Interface)
	for Key,Value in pairs(Config.OperationalTexts.Interface) do
		Texts[Key] = Value
	end
	return Texts
end

local function normalizeSpaces(Value)
	return Value:gsub("%s+"," "):match("^%s*(.-)%s*$")
end

local function validTitle(Value)
	if type(Value) ~= "string" then
		return nil
	end

	Value = normalizeSpaces(Value)
	local Length = utf8.len(Value)
	if not Length or Length < Config.Event.TitleMinimumLength or Length > Config.Event.TitleMaximumLength then
		return nil
	end

	for _,Codepoint in utf8.codes(Value) do
		local AllowedAscii = Codepoint == 32 or Codepoint == 33 or Codepoint == 39 or
			Codepoint == 40 or Codepoint == 41 or Codepoint == 44 or Codepoint == 45 or
			Codepoint == 46 or Codepoint == 63 or (Codepoint >= 48 and Codepoint <= 57) or
			(Codepoint >= 65 and Codepoint <= 90) or (Codepoint >= 97 and Codepoint <= 122)
		local AllowedLatin = (Codepoint >= 192 and Codepoint <= 214) or
			(Codepoint >= 216 and Codepoint <= 246) or (Codepoint >= 248 and Codepoint <= 383)
		if not AllowedAscii and not AllowedLatin then
			return nil
		end
	end

	return Value
end

local function safeIdentityPart(Value)
	if type(Value) ~= "string" then
		return ""
	end

	return normalizeSpaces(Value:gsub("[%c<>]","")):sub(1,32)
end

local function escapeHtml(Value)
	return tostring(Value or ""):gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"):gsub('"',"&quot;"):gsub("'","&#39;")
end

local function resolveFighter(Passport)
	local FighterSource = tonumber(vRP.Source(Passport))
	if not FighterSource or FighterSource <= 0 or not GetPlayerName(FighterSource) then
		return nil
	end

	if vRP.Passport(FighterSource) ~= Passport or not vRP.DoesEntityExist(FighterSource) then
		return nil
	end

	local State = Player(FighterSource).state
	if not State or State.Active ~= true then
		return nil
	end

	local Identity = vRP.Identity(Passport)
	if type(Identity) ~= "table" then
		return nil
	end

	local FirstName = safeIdentityPart(Identity.Name)
	local LastName = safeIdentityPart(Identity.Lastname)
	local FullName = normalizeSpaces(FirstName.." "..LastName)
	if FullName == "" then
		return nil
	end

	return {
		Passport = Passport,
		Name = FullName,
		CheckedIn = false
	}
end

local function statusLabel(Texts)
	return Texts[StatusTextKeys[Runtime.Status]] or Runtime.Status
end

local function buildSnapshot(Mode)
	local Texts = interfaceTexts()
	local Event = Runtime.Event
	local Name = Event and Event.Title or Texts.IdleEvent
	local FighterA = Event and Event.FighterA or { Name = Config.DemoEvent.FighterA.Name, CheckedIn = false }
	local FighterB = Event and Event.FighterB or { Name = Config.DemoEvent.FighterB.Name, CheckedIn = false }

	local Snapshot = {
		Revision = Runtime.Revision,
		Mode = Mode,
		State = Runtime.Status,
		FinancialEnabled = false,
		Actions = {
			CreateEvent = Runtime.Status == "idle",
			AnnounceEvent = Runtime.Status == "draft",
			OpenBets = Runtime.Status == "announced",
			CloseBets = Runtime.Status == "betting_open",
			CancelEvent = Runtime.Status ~= "idle" and Runtime.Status ~= "cancelled",
			StartFight = false
		},
		Event = {
			Name = Name,
			Status = statusLabel(Texts),
			Schedule = Runtime.Status == "betting_open" and Texts.StatusBettingOpen or "EM BREVE",
			DemoLabel = Notifications.TemporaryState,
			FighterA = {
				Name = FighterA.Name,
				Corner = Config.DemoEvent.FighterA.Corner,
				Pool = 0,
				Odds = Config.Texts.Interface.FinancialValue,
				CheckedIn = FighterA.CheckedIn == true
			},
			FighterB = {
				Name = FighterB.Name,
				Corner = Config.DemoEvent.FighterB.Corner,
				Pool = 0,
				Odds = Config.Texts.Interface.FinancialValue,
				CheckedIn = FighterB.CheckedIn == true
			}
		},
		Texts = Texts
	}

	if Mode == "organizer" and Event then
		Snapshot.Event.FighterA.Passport = Event.FighterA.Passport
		Snapshot.Event.FighterB.Passport = Event.FighterB.Passport
	end

	return Snapshot
end

local function pushSnapshots()
	for _,Source in ipairs(OFC.Security.GetSessionSources("public")) do
		TriggerClientEvent("af_ofc:snapshot",Source,buildSnapshot("public"))
	end

	for _,Source in ipairs(OFC.Security.GetSessionSources("organizer")) do
		local Passport = vRP.Passport(Source)
		if OFC.Security.IsOrganizer(Passport) then
			TriggerClientEvent("af_ofc:snapshot",Source,buildSnapshot("organizer"))
		else
			OFC.Security.CloseSession(Source)
			TriggerClientEvent("af_ofc:forceClose",Source)
		end
	end
end

local function transition(To)
	if not AllowedTransitions[Runtime.Status] or AllowedTransitions[Runtime.Status][To] ~= true then
		return false
	end

	Runtime.Status = To
	Runtime.Revision = Runtime.Revision + 1
	return true
end

local function actionResult(Source,RequestId,Kind,Success,Message)
	TriggerClientEvent("af_ofc:actionResult",Source,{
		RequestId = RequestId,
		Kind = Kind,
		Success = Success == true,
		Message = Message
	})
end

local function validateOrganizerAction(Source,Data,RateAction,Kind)
	if type(Data) ~= "table" then
		notify(Source,Config.Texts.Notifications.InvalidRequest,"vermelho")
		return nil
	end

	local RequestId = OFC.Security.ValidateRequestId(Data.RequestId)
	if not RequestId then
		notify(Source,Config.Texts.Notifications.InvalidRequest,"vermelho")
		return nil
	end

	local Valid,Passport,Reason = OFC.Security.ValidatePlayer(Source)
	if not Valid then
		notify(Source,denialMessage(Reason),"vermelho")
		TriggerClientEvent("af_ofc:forceClose",Source)
		return nil
	end

	if not OFC.Security.RateAllowed(Source,Passport,RateAction) then
		actionResult(Source,RequestId,Kind,false,Config.Texts.Notifications.RateLimited)
		return nil
	end

	if not OFC.Security.ValidateSession(Source,Passport,Data.SessionToken,"organizer") or not OFC.Security.IsOrganizer(Passport) then
		notify(Source,Config.Texts.Notifications.PermissionDenied,"vermelho")
		OFC.Security.CloseSession(Source,Data.SessionToken)
		TriggerClientEvent("af_ofc:forceClose",Source)
		return nil
	end

	return RequestId,Passport
end

local function openPublic(Source,View,RequestId)
	RequestId = OFC.Security.ValidateRequestId(RequestId)
	if not RequestId then
		notify(Source,Config.Texts.Notifications.InvalidRequest,"vermelho")
		return false
	end

	local Valid,Passport,Reason = OFC.Security.ValidatePlayer(Source)
	if not Valid then
		notify(Source,denialMessage(Reason),"vermelho")
		return false
	end

	if not OFC.Security.RateAllowed(Source,Passport,"OpenPublic") then
		notify(Source,Config.Texts.Notifications.RateLimited)
		return false
	end

	if not OFC.Security.IsNear(Source,Config.PublicNpc.Coords,Config.Interaction.ServerMaximumDistance) then
		notify(Source,Config.Texts.Notifications.TooFar,"vermelho")
		return false
	end

	local Token = OFC.Security.CreateSession(Source,Passport,"public")
	TriggerClientEvent("af_ofc:openAuthorized",Source,{
		RequestId = RequestId,
		Origin = "target",
		SessionToken = Token,
		View = View,
		Snapshot = buildSnapshot("public")
	})
	return true
end

local function openOrganizer(Source,RequestId,RequireDistance,Origin)
	RequestId = OFC.Security.ValidateRequestId(RequestId)
	if not RequestId then
		notify(Source,Config.Texts.Notifications.InvalidRequest,"vermelho")
		return false
	end

	local Valid,Passport,Reason = OFC.Security.ValidatePlayer(Source)
	if not Valid then
		notify(Source,denialMessage(Reason),"vermelho")
		return false
	end

	if not OFC.Security.RateAllowed(Source,Passport,"OpenOrganizer") then
		notify(Source,Config.Texts.Notifications.RateLimited)
		return false
	end

	if not OFC.Security.IsOrganizer(Passport) then
		notify(Source,Config.Texts.Notifications.PermissionDenied,"vermelho")
		return false
	end

	if RequireDistance and not OFC.Security.IsNear(Source,Config.OrganizerDesk.Coords,Config.Interaction.ServerMaximumDistance) then
		notify(Source,Config.Texts.Notifications.TooFar,"vermelho")
		return false
	end

	local Token = OFC.Security.CreateSession(Source,Passport,"organizer")
	TriggerClientEvent("af_ofc:openAuthorized",Source,{
		RequestId = RequestId,
		Origin = Origin,
		SessionToken = Token,
		View = "organizer",
		Snapshot = buildSnapshot("organizer")
	})
	return true
end

RegisterNetEvent("af_ofc:requestEvent",function(RequestId)
	openPublic(source,"event",RequestId)
end)

RegisterNetEvent("af_ofc:requestBettingPanel",function(RequestId)
	openPublic(source,"betting",RequestId)
end)

RegisterNetEvent("af_ofc:requestCheckIn",function(RequestId)
	local Source = source
	RequestId = OFC.Security.ValidateRequestId(RequestId)
	if not RequestId then
		notify(Source,Config.Texts.Notifications.InvalidRequest,"vermelho")
		return
	end

	local Valid,Passport,Reason = OFC.Security.ValidatePlayer(Source)
	if not Valid then
		notify(Source,denialMessage(Reason),"vermelho")
		return
	end

	if not OFC.Security.RateAllowed(Source,Passport,"CheckIn") then
		actionResult(Source,RequestId,"checkIn",false,Config.Texts.Notifications.RateLimited)
		return
	end

	if not OFC.Security.IsNear(Source,Config.PublicNpc.Coords,Config.Interaction.ServerMaximumDistance) then
		notify(Source,Config.Texts.Notifications.TooFar,"vermelho")
		return
	end

	local Event = Runtime.Event
	local Fighter = Event and (Event.FighterA.Passport == Passport and Event.FighterA or Event.FighterB.Passport == Passport and Event.FighterB)
	if not Fighter then
		actionResult(Source,RequestId,"checkIn",false,Config.Texts.Notifications.NotScheduled)
		return
	end

	if Fighter.CheckedIn then
		actionResult(Source,RequestId,"checkIn",true,Notifications.CheckInAlreadyComplete)
		return
	end

	Fighter.CheckedIn = true
	Runtime.Revision = Runtime.Revision + 1
	actionResult(Source,RequestId,"checkIn",true,Notifications.CheckInComplete)
	pushSnapshots()
end)

RegisterNetEvent("af_ofc:requestOrganizerDesk",function(RequestId)
	openOrganizer(source,RequestId,true,"target")
end)

RegisterNetEvent("af_ofc:attemptBet",function(Data)
	local Source = source
	if type(Data) ~= "table" then
		notify(Source,Config.Texts.Notifications.InvalidRequest,"vermelho")
		return
	end

	local RequestId = OFC.Security.ValidateRequestId(Data.RequestId)
	local Side = type(Data.Side) == "string" and Data.Side or ""
	local Amount = OFC.Security.FiniteInteger(Data.Amount,Config.DemoBet.MinimumInput,Config.DemoBet.MaximumInput)
	if not RequestId or (Side ~= "A" and Side ~= "B") or not Amount then
		if RequestId then
			actionResult(Source,RequestId,"bet",false,Config.Texts.Notifications.InvalidRequest)
		else
			notify(Source,Config.Texts.Notifications.InvalidRequest,"vermelho")
		end
		return
	end

	local Valid,Passport,Reason = OFC.Security.ValidatePlayer(Source)
	if not Valid then
		notify(Source,denialMessage(Reason),"vermelho")
		TriggerClientEvent("af_ofc:forceClose",Source)
		return
	end

	if not OFC.Security.RateAllowed(Source,Passport,"AttemptBet") then
		actionResult(Source,RequestId,"bet",false,Config.Texts.Notifications.RateLimited)
		return
	end

	if not OFC.Security.ValidateSession(Source,Passport,Data.SessionToken,"public") then
		notify(Source,Config.Texts.Notifications.InvalidSession,"vermelho")
		TriggerClientEvent("af_ofc:forceClose",Source)
		return
	end

	if not OFC.Security.IsNear(Source,Config.PublicNpc.Coords,Config.Interaction.ServerMaximumDistance) then
		notify(Source,Config.Texts.Notifications.TooFar,"vermelho")
		OFC.Security.CloseSession(Source,Data.SessionToken)
		TriggerClientEvent("af_ofc:forceClose",Source)
		return
	end

	actionResult(Source,RequestId,"bet",false,Config.Texts.Notifications.FinancialPreparing)
end)

RegisterNetEvent("af_ofc:createEvent",function(Data)
	local Source = source
	local RequestId,Passport = validateOrganizerAction(Source,Data,"CreateEvent","createEvent")
	if not RequestId then return end

	if Runtime.Status ~= "idle" or Runtime.Event then
		actionResult(Source,RequestId,"createEvent",false,Notifications.EventAlreadyActive)
		return
	end

	local Title = validTitle(Data.Title)
	local PassportA = OFC.Security.FiniteInteger(Data.FighterA,Config.Event.PassportMinimum,Config.Event.PassportMaximum)
	local PassportB = OFC.Security.FiniteInteger(Data.FighterB,Config.Event.PassportMinimum,Config.Event.PassportMaximum)
	if not Title or not PassportA or not PassportB or PassportA == PassportB then
		actionResult(Source,RequestId,"createEvent",false,Notifications.InvalidEventData)
		return
	end

	local FighterA = resolveFighter(PassportA)
	local FighterB = resolveFighter(PassportB)
	if not FighterA or not FighterB then
		actionResult(Source,RequestId,"createEvent",false,Notifications.InvalidEventData)
		return
	end

	Runtime.Event = {
		Title = Title,
		CreatedAt = os.time(),
		CreatedBy = Passport,
		FighterA = FighterA,
		FighterB = FighterB
	}
	transition("draft")
	actionResult(Source,RequestId,"createEvent",true,Notifications.EventCreated)
	pushSnapshots()
end)

RegisterNetEvent("af_ofc:announceEvent",function(Data)
	local Source = source
	local RequestId = validateOrganizerAction(Source,Data,"AnnounceEvent","announceEvent")
	if not RequestId then return end

	if not Runtime.Event or not transition("announced") then
		actionResult(Source,RequestId,"announceEvent",false,Notifications.InvalidTransition)
		return
	end

	local Event = Runtime.Event
	local Message = ("<b>%s</b> — %s x %s.<br>Compareça ao Ouro Fight Club."):format(escapeHtml(Event.Title),escapeHtml(Event.FighterA.Name),escapeHtml(Event.FighterB.Name))
	TriggerClientEvent("Notify",-1,"Ouro Fight Club",Message,"vermelho",15000,"bottom-center")
	actionResult(Source,RequestId,"announceEvent",true,Notifications.EventAnnounced)
	pushSnapshots()
end)

RegisterNetEvent("af_ofc:openBets",function(Data)
	local Source = source
	local RequestId = validateOrganizerAction(Source,Data,"OpenBets","openBets")
	if not RequestId then return end

	if not Runtime.Event or not transition("betting_open") then
		actionResult(Source,RequestId,"openBets",false,Notifications.InvalidTransition)
		return
	end

	actionResult(Source,RequestId,"openBets",true,Notifications.BetsOpened)
	pushSnapshots()
end)

RegisterNetEvent("af_ofc:closeBets",function(Data)
	local Source = source
	local RequestId = validateOrganizerAction(Source,Data,"CloseBets","closeBets")
	if not RequestId then return end

	if not Runtime.Event or not transition("betting_closed") then
		actionResult(Source,RequestId,"closeBets",false,Notifications.InvalidTransition)
		return
	end

	actionResult(Source,RequestId,"closeBets",true,Notifications.BetsClosed)
	pushSnapshots()
end)

RegisterNetEvent("af_ofc:cancelEvent",function(Data)
	local Source = source
	local RequestId = validateOrganizerAction(Source,Data,"CancelEvent","cancelEvent")
	if not RequestId then return end

	if not Runtime.Event or not transition("cancelled") then
		actionResult(Source,RequestId,"cancelEvent",false,Notifications.InvalidTransition)
		return
	end

	Runtime.Event = nil
	transition("idle")
	actionResult(Source,RequestId,"cancelEvent",true,Notifications.EventCancelled)
	pushSnapshots()
end)

RegisterNetEvent("af_ofc:startFight",function(Data)
	local Source = source
	local RequestId = validateOrganizerAction(Source,Data,"StartFight","startFight")
	if not RequestId then return end

	actionResult(Source,RequestId,"startFight",false,Notifications.AutomaticFightPreparing)
end)

RegisterNetEvent("af_ofc:requestRingGong",function(RequestId)
	local Source = source
	RequestId = OFC.Security.ValidateRequestId(RequestId)
	if not RequestId then
		notify(Source,Config.Texts.Notifications.InvalidRequest,"vermelho")
		return
	end

	local Valid,Passport,Reason = OFC.Security.ValidatePlayer(Source)
	if not Valid then
		notify(Source,denialMessage(Reason),"vermelho")
		return
	end

	if not OFC.Security.RateAllowed(Source,Passport,"GongAuthorization") then
		notify(Source,Config.Texts.Notifications.RateLimited)
		return
	end

	if not OFC.Security.IsOrganizer(Passport) then
		notify(Source,Config.Texts.Notifications.PermissionDenied,"vermelho")
		return
	end

	if not OFC.Security.IsNear(Source,Config.Gong.Coords,Config.Gong.ServerMaximumDistance) then
		notify(Source,Config.Texts.Notifications.TooFar,"vermelho")
		return
	end

	TriggerClientEvent("af_ofc:ringGongAuthorized",Source,{
		RequestId = RequestId,
		SessionToken = OFC.Security.CreateActionToken(Source,Passport,"ringGong")
	})
end)

RegisterNetEvent("af_ofc:ringGong",function(Data)
	local Source = source
	if type(Data) ~= "table" then
		notify(Source,Config.Texts.Notifications.InvalidRequest,"vermelho")
		return
	end

	local RequestId = OFC.Security.ValidateRequestId(Data.RequestId)
	local Valid,Passport,Reason = OFC.Security.ValidatePlayer(Source)
	if not RequestId or not Valid then
		notify(Source,RequestId and denialMessage(Reason) or Config.Texts.Notifications.InvalidRequest,"vermelho")
		return
	end

	if not OFC.Security.ConsumeActionToken(Source,Passport,Data.SessionToken,"ringGong") then
		notify(Source,Config.Texts.Notifications.InvalidSession,"vermelho")
		return
	end

	if not OFC.Security.RateAllowed(Source,Passport,"RingGong") then
		notify(Source,Config.Texts.Notifications.RateLimited)
		return
	end

	if not OFC.Security.IsOrganizer(Passport) then
		notify(Source,Config.Texts.Notifications.PermissionDenied,"vermelho")
		return
	end

	if not OFC.Security.IsNear(Source,Config.Gong.Coords,Config.Gong.ServerMaximumDistance) then
		notify(Source,Config.Texts.Notifications.TooFar,"vermelho")
		return
	end

	if not Runtime.Event then
		notify(Source,Notifications.NoActiveEvent,"vermelho")
		return
	end

	if Config.Gong.RequireBothCheckIns and (not Runtime.Event.FighterA.CheckedIn or not Runtime.Event.FighterB.CheckedIn) then
		notify(Source,Notifications.BothCheckInsRequired,"vermelho")
		return
	end

	for _,PlayerId in ipairs(GetPlayers()) do
		local Target = tonumber(PlayerId)
		if Target and vRP.DoesEntityExist(Target) and OFC.Security.IsNear(Target,Config.Gong.Coords,Config.Gong.NearbyRadius) then
			TriggerClientEvent("Notify",Target,Config.Texts.Notifications.Title,Notifications.FightSignal,"vermelho",5000)
		end
	end

	notify(Source,Notifications.GongReadyNoAudio,"amarelo")
end)

RegisterNetEvent("af_ofc:closeSession",function(Data)
	local Source = source
	if type(Data) ~= "table" then return end

	local Passport = vRP.Passport(Source)
	if not Passport or not OFC.Security.RateAllowed(Source,Passport,"CloseSession") then return end
	OFC.Security.CloseSession(Source,Data.SessionToken)
end)

AddEventHandler("Disconnect",function(Passport)
	Passport = tonumber(Passport)
	if not Passport or not Runtime.Event then return end

	local Changed = false
	if Runtime.Event.FighterA.Passport == Passport and Runtime.Event.FighterA.CheckedIn then
		Runtime.Event.FighterA.CheckedIn = false
		Changed = true
	end
	if Runtime.Event.FighterB.Passport == Passport and Runtime.Event.FighterB.CheckedIn then
		Runtime.Event.FighterB.CheckedIn = false
		Changed = true
	end

	if Changed then
		Runtime.Revision = Runtime.Revision + 1
		pushSnapshots()
	end
end)

CreateThread(function()
	while true do
		Wait(1000)
		for _,Source in ipairs(OFC.Security.GetSessionSources("organizer")) do
			local Passport = vRP.Passport(Source)
			if not OFC.Security.IsOrganizer(Passport) then
				OFC.Security.CloseSession(Source)
				TriggerClientEvent("af_ofc:forceClose",Source)
			end
		end
	end
end)

RegisterCommand("ofc",function(Source)
	Source = tonumber(Source)
	if not Source or Source <= 0 then
		print(Config.Texts.Console.PlayerCommandOnly)
		return
	end

	openOrganizer(Source,nextServerRequestId(),false,"command")
end,false)
