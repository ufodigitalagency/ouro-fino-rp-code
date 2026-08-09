local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")
local vRPC = Tunnel.getInterface("vRP")
local vRP = Proxy.getInterface("vRP")

local VampireMode = {}
local Cooldowns = {}
local TargetCooldowns = {}
local LastRequest = {}
local Busy = {}
local Operations = {}
local OperationSequence = 0
local LastBurningRequest = {}
local MultiplayerDiagnosticsActive = false

local function debugPrint(message)
	if Config.Debug then
		print(("[af_vampire_skill] %s"):format(message))
	end
end

local function multiplayerLog(message)
	if Config.MultiplayerDebug or MultiplayerDiagnosticsActive then
		print(("[vampire/multiplayer] %s"):format(message))
	end
end

local function setReplicatedBurning(source,state)
	if not source or source <= 0 then
		return
	end

	local player = Player(source)
	if player and player.state then
		player.state:set(Config.Sunlight.ReplicatedState,state == true,true)
		multiplayerLog(("replicated source=%s state=%s"):format(source,tostring(state == true)))
	end
end

local function notify(source,message,color)
	TriggerClientEvent("Notify",source,"Vampiro",message,color or "amarelo",5000)
end

local function isOnline(source)
	return source and source > 0 and GetPlayerName(source) ~= nil and GetPlayerPed(source) ~= 0
end

local function isAlive(source)
	return isOnline(source) and vRP.GetHealth(source) > Config.MinimumAttackerHealth
end

local function isInBlockedZone(source)
	if Config.RespectSafezoneState and Player(source).state.Safezone then
		return true
	end

	local coords = vRP.GetEntityCoords(source)
	for _,zone in ipairs(Config.BlockedZones) do
		if #(coords - zone.coords) <= zone.radius then
			return true
		end
	end

	return false
end

local function hasPermission(source)
	if MultiplayerDiagnosticsActive and Player(source).state["af:multiplayerGuestMode"] == true then
		return false
	end

	local passport = vRP.Passport(source)
	return passport and vRP.HasPermission(passport,Config.Permission) or false
end

local function useUmbrella(source)
	if not isOnline(source) then
		return false
	end

	if not hasPermission(source) then
		notify(source,"Voce nao possui a habilidade Vampiro.","vermelho")
		return false
	end

	TriggerClientEvent("af_vampire_skill:ToggleUmbrella",source)
	return true
end

local function sameBucket(source,target)
	return GetPlayerRoutingBucket(source) == GetPlayerRoutingBucket(target)
end

local function closeEnough(source,target,maxDistance)
	local sourcePed = GetPlayerPed(source)
	local targetPed = GetPlayerPed(target)
	if sourcePed == 0 or targetPed == 0 then
		return false
	end

	return #(GetEntityCoords(sourcePed) - GetEntityCoords(targetPed)) <= maxDistance
end

local function releaseOperation(operationId)
	local operation = Operations[operationId]
	if not operation then
		return
	end

	if Busy[operation.attackerSource] == operationId then
		Busy[operation.attackerSource] = nil
	end

	if operation.targetSource and Busy[operation.targetSource] == operationId then
		Busy[operation.targetSource] = nil
	end

	TriggerClientEvent("af_vampire_skill:StopAnimation",operation.attackerSource)
	if operation.targetSource then
		TriggerClientEvent("af_vampire_skill:StopAnimation",operation.targetSource)
	end

	Operations[operationId] = nil
end

local function cancelPlayerOperation(source)
	local operationId = Busy[source]
	if operationId then
		releaseOperation(operationId)
	end
end

local function validateVampire(source)
	if not isOnline(source) then
		return false,"jogador invalido"
	end

	if not hasPermission(source) then
		return false,"sem permissao"
	end

	if not VampireMode[source] then
		return false,"modo vampiro desligado"
	end

	if not isAlive(source) then
		return false,"vampiro incapacitado"
	end

	if vRP.InsideVehicle(source) then
		return false,"vampiro em veiculo"
	end

	if isInBlockedZone(source) then
		return false,"safe zone"
	end

	return true
end

local function validatePlayerTarget(source,target,maxDistance,allowBusy)
	if not target or target == source or not isOnline(target) then
		return false,"alvo invalido"
	end

	if not allowBusy and (Busy[source] or Busy[target]) then
		return false,"habilidade em andamento"
	end

	if not isAlive(target) then
		return false,"alvo incapacitado"
	end

	if vRP.InsideVehicle(target) then
		return false,"alvo em veiculo"
	end

	if Config.ProtectAdmins and Player(target).state.Admin then
		return false,"alvo protegido"
	end

	if isInBlockedZone(target) then
		return false,"alvo em safe zone"
	end

	if not sameBucket(source,target) then
		return false,"instancia diferente"
	end

	if not closeEnough(source,target,maxDistance) then
		return false,"alvo distante"
	end

	if vRP.GetHealth(target) - Config.PlayerDamage < Config.MinimumVictimHealth then
		return false,"vida do alvo muito baixa"
	end

	return true
end

local function requestAllowed(source)
	local now = GetGameTimer()
	if LastRequest[source] and LastRequest[source] > now then
		return false
	end

	LastRequest[source] = now + Config.RequestInterval
	return true
end

RegisterNetEvent("af_vampire_skill:RequestAccess",function()
	local source = source
	TriggerClientEvent("af_vampire_skill:SetAccess",source,hasPermission(source))
end)

RegisterNetEvent("af_vampire_skill:SetSunlightBurning",function(state)
	local source = source
	if type(state) ~= "boolean" then
		multiplayerLog(("blocked source=%s reason=invalid_state"):format(source))
		return
	end

	local passport = vRP.Passport(source)
	if not passport then
		return
	end

	local current = Player(source).state[Config.Sunlight.ReplicatedState] == true
	if current == state then
		return
	end

	local now = GetGameTimer()
	local interval = math.max(100,tonumber(Config.Sunlight.StateUpdateInterval) or 250)
	if state and LastBurningRequest[source] and LastBurningRequest[source] > now then
		multiplayerLog(("blocked source=%s reason=rate_limit"):format(source))
		return
	end

	-- A transicao para false sempre e aceita para nunca deixar um efeito preso.
	-- Para ativar, o servidor confirma personagem, permissao e modo vampiro.
	if state then
		local valid = validateVampire(source)
		if not valid then
			setReplicatedBurning(source,false)
			multiplayerLog(("blocked source=%s reason=invalid_vampire"):format(source))
			return
		end
	end

	LastBurningRequest[source] = now + interval
	setReplicatedBurning(source,state)
	multiplayerLog(("burning source=%s passport=%s state=%s"):format(source,passport,tostring(state)))
end)

AddEventHandler("af_vampire_skill:UseUmbrellaItem",function(playerSource)
	useUmbrella(tonumber(playerSource))
end)

RegisterNetEvent("af_vampire_skill:UseUmbrellaSlot",function(slot)
	local source = source
	local passport = vRP.Passport(source)
	slot = tonumber(slot)
	if not passport or not slot or slot < 1 or slot > 4 then
		return
	end

	local inventory = vRP.Inventory(passport)
	local item = inventory[tostring(slot)]
	if not item or not item.item or splitString(item.item)[1] ~= Config.Sunlight.UmbrellaItem then
		return
	end

	useUmbrella(source)
end)

RegisterNetEvent("af_vampire_skill:RequestTestNpc",function()
	local source = source
	if not Config.TestNpc.Enabled or not hasPermission(source) then
		notify(source,"Voce nao possui a habilidade Vampiro.","vermelho")
		return
	end

	TriggerClientEvent("af_vampire_skill:SpawnTestNpc",source)
end)

RegisterNetEvent("af_vampire_skill:ToggleMode",function()
	local source = source
	if not hasPermission(source) then
		VampireMode[source] = nil
		setReplicatedBurning(source,false)
		cancelPlayerOperation(source)
		TriggerClientEvent("af_vampire_skill:SetAccess",source,false)
		TriggerClientEvent("af_vampire_skill:SetMode",source,false)
		notify(source,"Voce nao possui a habilidade Vampiro.","vermelho")
		return
	end

	if VampireMode[source] then
		VampireMode[source] = nil
		setReplicatedBurning(source,false)
		cancelPlayerOperation(source)
		TriggerClientEvent("af_vampire_skill:SetMode",source,false)
		notify(source,"Modo vampiro desativado.","amarelo")
		debugPrint(("Passport %s desativou modo vampiro"):format(vRP.Passport(source)))
		return
	end

	VampireMode[source] = true
	TriggerClientEvent("af_vampire_skill:SetAccess",source,true)
	TriggerClientEvent("af_vampire_skill:SetMode",source,true)
	notify(source,"Modo vampiro ativado.","verde")
	debugPrint(("Passport %s ativou modo vampiro"):format(vRP.Passport(source)))
end)

RegisterNetEvent("af_vampire_skill:DrainPlayer",function(target)
	local source = source
	target = tonumber(target)
	if not Config.AllowPlayerDrain or not requestAllowed(source) then
		return
	end

	local valid,reason = validateVampire(source)
	if valid then
		valid,reason = validatePlayerTarget(source,target,Config.Range)
	end

	local passport = vRP.Passport(source)
	local targetPassport = target and vRP.Passport(target)
	local now = os.time()
	local targetKey = passport and targetPassport and (passport..":"..targetPassport) or nil

	if valid and Cooldowns[passport] and Cooldowns[passport] > now then
		valid,reason = false,"cooldown de "..(Cooldowns[passport] - now).."s"
	end

	if valid and targetKey and TargetCooldowns[targetKey] and TargetCooldowns[targetKey] > now then
		valid,reason = false,"alvo protegido por "..(TargetCooldowns[targetKey] - now).."s"
	end

	if not valid then
		debugPrint(("Sugar jogador negado (%s): %s"):format(passport or "?",reason or "desconhecido"))
		notify(source,"Nao foi possivel sugar sangue: "..(reason or "alvo invalido")..".","vermelho")
		return
	end

	OperationSequence = OperationSequence + 1
	local operationId = OperationSequence
	Operations[operationId] = {
		id = operationId,
		attackerSource = source,
		targetSource = target,
		attackerPassport = passport,
		targetPassport = targetPassport,
		kind = "player"
	}

	Busy[source] = operationId
	Busy[target] = operationId
	Cooldowns[passport] = now + Config.Cooldown
	TargetCooldowns[targetKey] = now + Config.TargetCooldown

	TriggerClientEvent("af_vampire_skill:StartAttacker",source,target,Config.Duration)
	TriggerClientEvent("af_vampire_skill:StartVictim",target,source,Config.Duration)

	SetTimeout(Config.Duration,function()
		local current = Operations[operationId]
		if not current then
			return
		end

		local stillValid = Busy[source] == operationId and Busy[target] == operationId
		stillValid = stillValid and vRP.Passport(source) == passport and vRP.Passport(target) == targetPassport
		stillValid = stillValid and validateVampire(source)
		if stillValid then
			stillValid = validatePlayerTarget(source,target,Config.FinalRange,true)
		end

		if not stillValid then
			debugPrint(("Sugar jogador cancelado: vampire %s target %s"):format(passport,targetPassport or "?"))
			releaseOperation(operationId)
			return
		end

		vRPC.DowngradeHealth(target,Config.PlayerDamage)
		vRPC.UpgradeHealth(source,Config.PlayerHeal)
		notify(source,"Sangue sugado com sucesso.","verde")
		notify(target,"Voce teve sangue sugado por um vampiro.","vermelho")
		debugPrint(("Sugar aplicado: vampire %s target %s"):format(passport,targetPassport))
		releaseOperation(operationId)
	end)
end)

RegisterNetEvent("af_vampire_skill:DrainNpc",function(netId)
	local source = source
	netId = tonumber(netId) or 0
	if not Config.AllowNpcDrain then
		TriggerClientEvent("af_vampire_skill:AbortNpcPreparation",source,"drenagem de NPC desativada")
		return
	end

	if not requestAllowed(source) then
		TriggerClientEvent("af_vampire_skill:AbortNpcPreparation",source,"muitas tentativas")
		return
	end

	local valid,reason = validateVampire(source)
	if valid and Busy[source] then
		valid,reason = false,"habilidade em andamento"
	end

	local npc = 0
	if valid and netId > 0 then
		local entityTimeout = GetGameTimer() + (tonumber(Config.NpcControlTimeout) or 800)
		repeat
			npc = NetworkGetEntityFromNetworkId(netId)
			if npc ~= 0 and DoesEntityExist(npc) then
				break
			end
			Wait(25)
		until GetGameTimer() >= entityTimeout
	end

	if valid and (npc == 0 or not DoesEntityExist(npc) or IsPedAPlayer(npc) or GetEntityType(npc) ~= 1) then
		valid,reason = false,"npc invalido"
	end

	if valid and GetEntityHealth(npc) <= Config.MinimumNpcHealth then
		valid,reason = false,"npc indisponivel"
	end

	if valid and GetEntityRoutingBucket(npc) ~= GetPlayerRoutingBucket(source) then
		valid,reason = false,"instancia diferente"
	end

	if valid and #(GetEntityCoords(GetPlayerPed(source)) - GetEntityCoords(npc)) > Config.NpcSearchRange then
		valid,reason = false,"npc distante"
	end

	local passport = vRP.Passport(source)
	local now = os.time()
	if valid and Cooldowns[passport] and Cooldowns[passport] > now then
		valid,reason = false,"cooldown de "..(Cooldowns[passport] - now).."s"
	end

	if not valid then
		debugPrint(("Sugar npc negado (%s): %s"):format(passport or "?",reason or "desconhecido"))
		TriggerClientEvent("af_vampire_skill:AbortNpcPreparation",source,reason or "npc invalido")
		notify(source,"Nao foi possivel sugar sangue: "..(reason or "npc invalido")..".","vermelho")
		return
	end

	OperationSequence = OperationSequence + 1
	local operationId = OperationSequence
	Operations[operationId] = {
		id = operationId,
		attackerSource = source,
		attackerPassport = passport,
		npc = npc,
		netId = netId,
		kind = "npc"
	}

	Busy[source] = operationId
	Cooldowns[passport] = now + Config.Cooldown
	TriggerClientEvent("af_vampire_skill:StartNpcDrain",source,netId,Config.Duration)

	SetTimeout(Config.Duration,function()
		local current = Operations[operationId]
		if not current then
			return
		end

		local stillValid = Busy[source] == operationId and vRP.Passport(source) == passport and validateVampire(source)
		stillValid = stillValid and DoesEntityExist(npc) and not IsPedAPlayer(npc) and GetEntityType(npc) == 1
		stillValid = stillValid and GetEntityHealth(npc) > Config.MinimumNpcHealth
		stillValid = stillValid and GetEntityRoutingBucket(npc) == GetPlayerRoutingBucket(source)
		stillValid = stillValid and #(GetEntityCoords(GetPlayerPed(source)) - GetEntityCoords(npc)) <= Config.FinalRange
		stillValid = stillValid and GetEntityHealth(npc) - Config.NpcDamage >= Config.MinimumNpcHealth

		if not stillValid then
			debugPrint(("Sugar npc cancelado: vampire %s"):format(passport))
			releaseOperation(operationId)
			return
		end

		-- NPCs nao possuem uma funcao de dano usada no servidor por esta base.
		-- O servidor ja validou entidade, distancia, instancia, permissao e cooldown;
		-- o cliente apenas aplica o impacto visual no NPC aprovado.
		TriggerClientEvent("af_vampire_skill:ApplyNpcDamage",source,netId,Config.NpcDamage)
		vRPC.UpgradeHealth(source,Config.NpcHeal)
		TriggerClientEvent("af_vampire_skill:NpcReaction",source,netId)
		notify(source,"Sangue sugado com sucesso.","verde")
		debugPrint(("Sugar npc aplicado: vampire %s net %s"):format(passport,netId))
		releaseOperation(operationId)
	end)
end)

RegisterNetEvent("af_vampire_skill:CancelNpcDrain",function(netId)
	local source = source
	local operationId = Busy[source]
	local operation = operationId and Operations[operationId]
	netId = tonumber(netId) or 0
	if operation and operation.kind == "npc" and operation.attackerSource == source and operation.netId == netId then
		debugPrint(("Sugar npc cancelado pelo cliente: vampire %s net %s"):format(operation.attackerPassport,netId))
		releaseOperation(operationId)
	end
end)

RegisterNetEvent("af_vampire_skill:DrainLocalNpc",function()
	local source = source
	if not Config.AllowNpcDrain then
		TriggerClientEvent("af_vampire_skill:AbortNpcPreparation",source,"drenagem de NPC desativada")
		return
	end

	if not requestAllowed(source) then
		TriggerClientEvent("af_vampire_skill:AbortNpcPreparation",source,"muitas tentativas")
		return
	end

	local valid,reason = validateVampire(source)
	if valid and Busy[source] then
		valid,reason = false,"habilidade em andamento"
	end

	local passport = vRP.Passport(source)
	local now = os.time()
	if valid and Cooldowns[passport] and Cooldowns[passport] > now then
		valid,reason = false,"cooldown de "..(Cooldowns[passport] - now).."s"
	end

	if not valid then
		debugPrint(("Sugar npc local negado (%s): %s"):format(passport or "?",reason or "desconhecido"))
		TriggerClientEvent("af_vampire_skill:AbortNpcPreparation",source,reason or "npc local invalido")
		notify(source,"Nao foi possivel sugar sangue: "..(reason or "npc invalido")..".","vermelho")
		return
	end

	OperationSequence = OperationSequence + 1
	local operationId = OperationSequence
	Operations[operationId] = {
		id = operationId,
		attackerSource = source,
		attackerPassport = passport,
		kind = "localNpc",
		startedAt = GetGameTimer(),
		startCoords = GetEntityCoords(GetPlayerPed(source)),
		bucket = GetPlayerRoutingBucket(source)
	}

	Busy[source] = operationId
	Cooldowns[passport] = now + Config.Cooldown
	TriggerClientEvent("af_vampire_skill:StartLocalNpcDrain",source,operationId,Config.Duration)
	debugPrint(("Sugar npc local iniciado: vampire %s operacao %s"):format(passport,operationId))

	SetTimeout(Config.Duration + 2000,function()
		if Operations[operationId] then
			debugPrint(("Sugar npc local expirado: vampire %s operacao %s"):format(passport,operationId))
			releaseOperation(operationId)
		end
	end)
end)

RegisterNetEvent("af_vampire_skill:CompleteLocalNpcDrain",function(operationId)
	local source = source
	operationId = tonumber(operationId) or 0
	local operation = Operations[operationId]
	if not operation or operation.kind ~= "localNpc" or operation.attackerSource ~= source or Busy[source] ~= operationId then
		return
	end

	local valid = vRP.Passport(source) == operation.attackerPassport and validateVampire(source)
	valid = valid and GetPlayerRoutingBucket(source) == operation.bucket
	valid = valid and GetGameTimer() - operation.startedAt >= math.max(0,Config.Duration - 250)
	valid = valid and #(GetEntityCoords(GetPlayerPed(source)) - operation.startCoords) <= (Config.FinalRange + 2.0)

	if not valid then
		debugPrint(("Sugar npc local cancelado: vampire %s operacao %s"):format(operation.attackerPassport,operationId))
		releaseOperation(operationId)
		return
	end

	TriggerClientEvent("af_vampire_skill:ApplyLocalNpcDamage",source,operationId,Config.NpcDamage)
	-- Um ped local nao existe no escopo do servidor. O fallback pode manter a
	-- animacao e o dano local, mas nunca concede cura baseada apenas no client.
	notify(source,"Drenagem concluida. NPC local nao concede cura.","amarelo")
	debugPrint(("Sugar npc local aplicado sem cura: vampire %s operacao %s"):format(operation.attackerPassport,operationId))
	releaseOperation(operationId)
end)

RegisterNetEvent("af_vampire_skill:CancelLocalNpcDrain",function(operationId)
	local source = source
	operationId = tonumber(operationId) or 0
	local operation = Operations[operationId]
	if operation and operation.kind == "localNpc" and operation.attackerSource == source then
		debugPrint(("Sugar npc local cancelado pelo cliente: vampire %s operacao %s"):format(operation.attackerPassport,operationId))
		releaseOperation(operationId)
	end
end)

RegisterNetEvent("af_vampire_skill:PlayerUnavailable",function()
	local source = source
	VampireMode[source] = nil
	setReplicatedBurning(source,false)
	cancelPlayerOperation(source)
	TriggerClientEvent("af_vampire_skill:SetMode",source,false)
end)

AddEventHandler("af_vampire_skill:PermissionChanged",function(passport,enabled)
	local source = vRP.Source(passport)
	if source and enabled then
		TriggerClientEvent("af_vampire_skill:SetAccess",source,true)
		return
	end

	if source then
		VampireMode[source] = nil
		setReplicatedBurning(source,false)
		cancelPlayerOperation(source)
		TriggerClientEvent("af_vampire_skill:SetAccess",source,false)
		TriggerClientEvent("af_vampire_skill:SetMode",source,false)
		notify(source,"Sua habilidade Vampiro foi removida.","amarelo")
	end
end)

AddEventHandler("af_vampire_skill:SetMultiplayerDiagnostics",function(enabled)
	MultiplayerDiagnosticsActive = enabled == true
	TriggerClientEvent("af_vampire_skill:SetMultiplayerDiagnostics",-1,MultiplayerDiagnosticsActive)
end)

AddEventHandler("af_vampire_skill:DiagnosticsGuestMode",function(playerSource,enabled)
	if not MultiplayerDiagnosticsActive then
		return
	end

	playerSource = tonumber(playerSource)
	if not playerSource or not isOnline(playerSource) then
		return
	end

	if enabled == true then
		VampireMode[playerSource] = nil
		cancelPlayerOperation(playerSource)
		setReplicatedBurning(playerSource,false)
		TriggerClientEvent("af_vampire_skill:SetAccess",playerSource,false)
		TriggerClientEvent("af_vampire_skill:SetMode",playerSource,false)
	else
		TriggerClientEvent("af_vampire_skill:SetAccess",playerSource,hasPermission(playerSource))
	end
end)

AddEventHandler("playerDropped",function()
	local source = source
	local passport = vRP.Passport(source)
	setReplicatedBurning(source,false)
	VampireMode[source] = nil
	Cooldowns[passport] = nil
	LastRequest[source] = nil
	LastBurningRequest[source] = nil
	cancelPlayerOperation(source)
end)

AddEventHandler("onResourceStop",function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end

	local activeOperations = {}
	for operationId in pairs(Operations) do
		table.insert(activeOperations,operationId)
	end

	for _,operationId in ipairs(activeOperations) do
		releaseOperation(operationId)
	end

	for _,playerSource in ipairs(GetPlayers()) do
		setReplicatedBurning(tonumber(playerSource),false)
	end
end)
