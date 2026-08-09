local Proxy = module("vrp","lib/Proxy")
local vRP = Proxy.getInterface("vRP")

OFC = OFC or {}
OFC.Security = OFC.Security or {}

local RateLimitsBySource = {}
local RateLimitsByPassport = {}
local Sessions = {}
local ActionTokens = {}

local function finiteNumber(Value)
	Value = tonumber(Value)
	return Value and Value == Value and Value > -math.huge and Value < math.huge and Value or nil
end

local function clearSession(Source)
	Sessions[tonumber(Source)] = nil
end

local function clearActionTokens(Source)
	ActionTokens[tonumber(Source)] = nil
end

function OFC.Security.ValidateRequestId(RequestId)
	RequestId = finiteNumber(RequestId)
	if not RequestId then
		return nil
	end

	RequestId = math.floor(RequestId)
	return RequestId >= 1 and RequestId <= 2147483647 and RequestId or nil
end

function OFC.Security.ValidatePlayer(Source)
	Source = tonumber(Source)
	if not Source or Source <= 0 or not GetPlayerName(Source) then
		return false,nil,"invalid_source"
	end

	local Passport = vRP.Passport(Source)
	if not Passport or not vRP.DoesEntityExist(Source) then
		return false,nil,"invalid_character"
	end

	if vRP.GetHealth(Source) <= 100 then
		return false,Passport,"invalid_state"
	end

	local State = Player(Source).state
	if State.Active ~= true then
		return false,Passport,"invalid_character"
	end

	if State.Death == true or State.Crawl == true then
		return false,Passport,"invalid_state"
	end

	return true,Passport
end

function OFC.Security.IsOrganizer(Passport)
	return Passport and vRP.HasPermission(Passport,"OFC") and true or false
end

function OFC.Security.IsNear(Source,Coords,MaximumDistance)
	if not Coords or not vRP.DoesEntityExist(Source) then
		return false
	end

	local PlayerCoords = vRP.GetEntityCoords(Source)
	local TargetCoords = vec3(Coords.x,Coords.y,Coords.z)
	return #(PlayerCoords - TargetCoords) <= (tonumber(MaximumDistance) or 0.0)
end

function OFC.Security.RateAllowed(Source,Passport,Action)
	Source = tonumber(Source)
	Passport = tonumber(Passport)
	local Interval = tonumber(Config.RateLimits[Action]) or 1000
	local Now = GetGameTimer()

	RateLimitsBySource[Source] = RateLimitsBySource[Source] or {}
	RateLimitsByPassport[Passport] = RateLimitsByPassport[Passport] or {}

	if Now < (RateLimitsBySource[Source][Action] or 0) or Now < (RateLimitsByPassport[Passport][Action] or 0) then
		return false
	end

	RateLimitsBySource[Source][Action] = Now + Interval
	RateLimitsByPassport[Passport][Action] = Now + Interval
	return true
end

function OFC.Security.CreateSession(Source,Passport,Mode)
	Source = tonumber(Source)
	Passport = tonumber(Passport)
	local Token = ("%s:%s:%s:%s"):format(Passport,Source,os.time(),math.random(100000,999999))

	Sessions[Source] = {
		Passport = Passport,
		Mode = Mode,
		Token = Token,
		ExpiresAt = os.time() + Config.Interaction.SessionTimeout
	}

	return Token
end

function OFC.Security.ValidateSession(Source,Passport,Token,Mode)
	Source = tonumber(Source)
	Passport = tonumber(Passport)
	local Session = Sessions[Source]

	if not Session or Session.Passport ~= Passport or Session.Mode ~= Mode or Session.Token ~= tostring(Token or "") then
		return false
	end

	if os.time() > Session.ExpiresAt then
		clearSession(Source)
		return false
	end

	return true
end

function OFC.Security.CloseSession(Source,Token)
	Source = tonumber(Source)
	local Session = Sessions[Source]
	if Session and (not Token or Session.Token == tostring(Token)) then
		clearSession(Source)
		return true
	end

	return false
end

function OFC.Security.GetSessionSources(Mode)
	local Sources = {}
	local Now = os.time()

	for Source,Session in pairs(Sessions) do
		if Now > Session.ExpiresAt or not GetPlayerName(Source) or vRP.Passport(Source) ~= Session.Passport then
			clearSession(Source)
		elseif Session.Mode == Mode then
			Sources[#Sources + 1] = Source
		end
	end

	return Sources
end

function OFC.Security.CreateActionToken(Source,Passport,Action)
	Source = tonumber(Source)
	Passport = tonumber(Passport)
	local Token = ("%s:%s:%s:%s:%s"):format(Passport,Source,Action,os.time(),math.random(100000,999999))

	ActionTokens[Source] = ActionTokens[Source] or {}
	ActionTokens[Source][Action] = {
		Passport = Passport,
		Token = Token,
		ExpiresAt = os.time() + Config.Interaction.ActionTokenTimeout
	}
	return Token
end

function OFC.Security.ConsumeActionToken(Source,Passport,Token,Action)
	Source = tonumber(Source)
	Passport = tonumber(Passport)
	local SourceTokens = ActionTokens[Source]
	local Entry = SourceTokens and SourceTokens[Action]
	if not Entry or Entry.Passport ~= Passport or Entry.Token ~= tostring(Token or "") or os.time() > Entry.ExpiresAt then
		return false
	end

	SourceTokens[Action] = nil
	if not next(SourceTokens) then
		clearActionTokens(Source)
	end
	return true
end

function OFC.Security.FiniteInteger(Value,Minimum,Maximum)
	Value = finiteNumber(Value)
	if not Value or Value % 1 ~= 0 then
		return nil
	end

	Value = math.floor(Value)
	return Value >= Minimum and Value <= Maximum and Value or nil
end

AddEventHandler("Disconnect",function(Passport)
	Passport = tonumber(Passport)
	if Passport then
		RateLimitsByPassport[Passport] = nil
	end

	for Source,Session in pairs(Sessions) do
		if Session.Passport == Passport then
			clearSession(Source)
		end
	end

	for Source,Tokens in pairs(ActionTokens) do
		for _,Entry in pairs(Tokens) do
			if Entry.Passport == Passport then
				clearActionTokens(Source)
				break
			end
		end
	end
end)

AddEventHandler("playerDropped",function()
	local Source = tonumber(source)
	RateLimitsBySource[Source] = nil
	clearSession(Source)
	clearActionTokens(Source)
end)
