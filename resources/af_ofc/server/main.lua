local Proxy = module("vrp","lib/Proxy")
local vRP = Proxy.getInterface("vRP")

local ServerRequestId = 0

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

local function buildSnapshot(Mode)
	return {
		Revision = Config.DemoEvent.Revision,
		Mode = Mode,
		FinancialEnabled = Config.Financial.Enabled == true,
		Event = {
			Name = Config.DemoEvent.Name,
			Status = Config.DemoEvent.Status,
			Schedule = Config.DemoEvent.Schedule,
			DemoLabel = Config.DemoEvent.DemoLabel,
			FighterA = {
				Name = Config.DemoEvent.FighterA.Name,
				Corner = Config.DemoEvent.FighterA.Corner,
				Pool = Config.DemoEvent.FighterA.Pool,
				Odds = Config.DemoEvent.FighterA.Odds,
				CheckedIn = Config.DemoEvent.CheckIns.FighterA == true
			},
			FighterB = {
				Name = Config.DemoEvent.FighterB.Name,
				Corner = Config.DemoEvent.FighterB.Corner,
				Pool = Config.DemoEvent.FighterB.Pool,
				Odds = Config.DemoEvent.FighterB.Odds,
				CheckedIn = Config.DemoEvent.CheckIns.FighterB == true
			}
		},
		Texts = Config.Texts.Interface
	}
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
		notify(Source,Config.Texts.Notifications.RateLimited)
		return
	end

	if not OFC.Security.IsNear(Source,Config.PublicNpc.Coords,Config.Interaction.ServerMaximumDistance) then
		notify(Source,Config.Texts.Notifications.TooFar,"vermelho")
		return
	end

	TriggerClientEvent("af_ofc:actionResult",Source,{
		RequestId = RequestId,
		Kind = "checkIn",
		Success = false,
		Message = Config.Texts.Notifications.NotScheduled
	})
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
	if not RequestId then
		notify(Source,Config.Texts.Notifications.InvalidRequest,"vermelho")
		return
	end

	if (Side ~= "A" and Side ~= "B") or not Amount then
		TriggerClientEvent("af_ofc:actionResult",Source,{
			RequestId = RequestId,
			Kind = "bet",
			Success = false,
			Message = Config.Texts.Notifications.InvalidRequest
		})
		return
	end

	local Valid,Passport,Reason = OFC.Security.ValidatePlayer(Source)
	if not Valid then
		notify(Source,denialMessage(Reason),"vermelho")
		TriggerClientEvent("af_ofc:forceClose",Source)
		return
	end

	if not OFC.Security.RateAllowed(Source,Passport,"AttemptBet") then
		TriggerClientEvent("af_ofc:actionResult",Source,{
			RequestId = RequestId,
			Kind = "bet",
			Success = false,
			Message = Config.Texts.Notifications.RateLimited
		})
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

	TriggerClientEvent("af_ofc:actionResult",Source,{
		RequestId = RequestId,
		Kind = "bet",
		Success = false,
		Message = Config.Texts.Notifications.FinancialPreparing
	})
end)

RegisterNetEvent("af_ofc:organizerPreview",function(Data)
	local Source = source
	if type(Data) ~= "table" then
		notify(Source,Config.Texts.Notifications.InvalidRequest,"vermelho")
		return
	end

	local RequestId = OFC.Security.ValidateRequestId(Data.RequestId)
	local Action = type(Data.Action) == "string" and Data.Action or ""
	if not RequestId or Config.OrganizerPreviewActions[Action] ~= true then
		notify(Source,Config.Texts.Notifications.InvalidRequest,"vermelho")
		return
	end

	local Valid,Passport,Reason = OFC.Security.ValidatePlayer(Source)
	if not Valid then
		notify(Source,denialMessage(Reason),"vermelho")
		TriggerClientEvent("af_ofc:forceClose",Source)
		return
	end

	if not OFC.Security.RateAllowed(Source,Passport,"OrganizerPreview") then
		TriggerClientEvent("af_ofc:actionResult",Source,{
			RequestId = RequestId,
			Kind = "organizer",
			Success = false,
			Message = Config.Texts.Notifications.RateLimited
		})
		return
	end

	if not OFC.Security.ValidateSession(Source,Passport,Data.SessionToken,"organizer") or not OFC.Security.IsOrganizer(Passport) then
		notify(Source,Config.Texts.Notifications.PermissionDenied,"vermelho")
		OFC.Security.CloseSession(Source,Data.SessionToken)
		TriggerClientEvent("af_ofc:forceClose",Source)
		return
	end

	TriggerClientEvent("af_ofc:actionResult",Source,{
		RequestId = RequestId,
		Kind = "organizer",
		Success = false,
		Message = Config.Texts.Notifications.ManagementPreparing
	})
end)

RegisterNetEvent("af_ofc:closeSession",function(Data)
	local Source = source
	if type(Data) ~= "table" then
		return
	end

	local Passport = vRP.Passport(Source)
	if not Passport or not OFC.Security.RateAllowed(Source,Passport,"CloseSession") then
		return
	end

	OFC.Security.CloseSession(Source,Data.SessionToken)
end)

RegisterCommand("ofc",function(Source)
	Source = tonumber(Source)
	if not Source or Source <= 0 then
		print(Config.Texts.Console.PlayerCommandOnly)
		return
	end

	openOrganizer(Source,nextServerRequestId(),false,"command")
end,false)
