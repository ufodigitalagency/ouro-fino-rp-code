local Proxy = module("vrp","lib/Proxy")
local vRP = Proxy.getInterface("vRP")

local ActiveBrooms = {}
local PassportBySource = {}
local PendingSpawns = {}
local RequestCooldowns = {}
local ProxyTests = {}
local OperationSequence = 0

local function debugPrint(message)
	if Config.Debug then
		print(("[af_witch_broom] %s"):format(message))
	end
end

local function lifecycleLog(event,details)
	local suffix = details and details ~= "" and (" " .. details) or ""
	print(("[af_witch_broom] %s%s"):format(event,suffix))
end

local function safeDeleteEntity(entity)
	if not entity or entity == 0 then
		return
	end

	local ok,err = pcall(DeleteEntity,entity)
	if not ok then
		lifecycleLog("cleanup_failed",tostring(err))
	end
end

local function notify(source,message,color)
	TriggerClientEvent("Notify",source,"Vassoura Magica",message,color or "amarelo",5000)
end

local function plainCoords(coords)
	return { x = coords.x + 0.0, y = coords.y + 0.0, z = coords.z + 0.0 }
end

local function sourceOnline(source)
	return source and source > 0 and GetPlayerName(source) ~= nil and GetPlayerPed(source) ~= 0
end

local function removeProxyTest(source,reason)
	local test = ProxyTests[source]
	if not test then
		return
	end

	ProxyTests[source] = nil
	local networkId = test.networkId
	safeDeleteEntity(test.entity)
	if sourceOnline(source) then
		TriggerClientEvent("af_witch_broom:ProxyNetworkRemoved",source,networkId)
	end
	debugPrint(("proxy_test_removed source=%s reason=%s"):format(source,tostring(reason or "cleanup")))
end

local function hasPermission(source)
	local passport = sourceOnline(source) and vRP.Passport(source) or nil
	return passport and vRP.HasPermission(passport,Config.Permission) or false,passport
end

local function sessionForSource(source)
	local passport = PassportBySource[source]
	return passport and ActiveBrooms[passport] or nil
end

local function requestAllowed(source)
	local now = GetGameTimer()
	if RequestCooldowns[source] and RequestCooldowns[source] > now then
		return false
	end

	RequestCooldowns[source] = now + math.max(250,tonumber(Config.Security.RequestInterval) or 750)
	return true
end

local function playerBlocked(source)
	local ped = GetPlayerPed(source)
	local state = Player(source).state

	if Config.Restrictions.BlockWhenDead and (state.Death or state.Crawl or GetEntityHealth(ped) <= 100) then
		return true,"Voce nao pode invocar a vassoura enquanto estiver incapacitado."
	end

	if Config.Restrictions.AllowInSafeZones ~= true and state.Safezone then
		return true,"A magia da vassoura nao funciona em uma area segura."
	end

	if Config.Restrictions.BlockStreetRace and state.StreetRace then
		return true,"Nao e possivel usar a vassoura durante um racha."
	end

	if vRP.InsideVehicle(source) then
		return true,"Saia do veiculo antes de invocar a vassoura."
	end

	if Config.Restrictions.BlockInteriors and GetInteriorFromEntity then
		local ok,interior = pcall(GetInteriorFromEntity,ped)
		if ok and interior and interior ~= 0 then
			return true,"A vassoura precisa ser invocada ao ar livre."
		end
	end

	return false
end

local function proxyModelName()
	return Config.Proxy and Config.Proxy.VehicleModel or "oppressor2"
end

local function visualModelName()
	return Config.Proxy and Config.Proxy.VisualModel or Config.BroomModel
end

local function removeSession(session,reason)
	if not session or session.removing then
		return
	end

	session.removing = true
	ActiveBrooms[session.passport] = nil
	PassportBySource[session.source] = nil

	if sourceOnline(session.source) then
		TriggerClientEvent("af_witch_broom:Deactivate",session.source,reason or "removed")
		local player = Player(session.source)
		if player and player.state then
			player.state:set("WitchBroom",false,true)
		end
	end

	local effectEntity = session.proxy or session.vehicle
	if effectEntity and DoesEntityExist(effectEntity) then
		TriggerClientEvent("af_witch_broom:PlayFx",-1,"dismiss",plainCoords(GetEntityCoords(effectEntity)))
	end

	local visual = session.visual
	local proxy = session.proxy or session.vehicle
	SetTimeout(250,function()
		if visual and DoesEntityExist(visual) then
			safeDeleteEntity(visual)
		end
		if proxy and DoesEntityExist(proxy) then
			safeDeleteEntity(proxy)
		end
	end)

	debugPrint(("removed passport=%s reason=%s"):format(session.passport,tostring(reason)))
end

local function createToken(source,passport)
	OperationSequence = OperationSequence + 1
	return ("%s:%s:%s:%s"):format(passport,source,os.time(),OperationSequence)
end

local function waitForEntity(entity,timeoutMs)
	local timeout = GetGameTimer() + (timeoutMs or 5000)
	while entity and entity ~= 0 and not DoesEntityExist(entity) and GetGameTimer() < timeout do
		Wait(0)
	end
	return entity and entity ~= 0 and DoesEntityExist(entity)
end

local function createProxyNetworkTest(source)
	if ActiveBrooms[PassportBySource[source] or -1] then
		notify(source,"Guarde a vassoura antes do teste networkado.","amarelo")
		return
	end

	removeProxyTest(source,"replaced")
	local modelName = Config.Proxy and Config.Proxy.PoseTestModel or "of_broom_proxy"
	local ped = GetPlayerPed(source)
	if not ped or ped == 0 then
		notify(source,"Nao foi possivel localizar o personagem para o teste.","vermelho")
		return
	end

	local coords = GetEntityCoords(ped)
	local heading = GetEntityHeading(ped)
	local radians = math.rad(heading)
	local spawn = vector3(coords.x - math.sin(radians) * 3.0,coords.y + math.cos(radians) * 3.0,coords.z + 0.5)
	local vehicle = CreateVehicle(GetHashKey(modelName),spawn.x,spawn.y,spawn.z,heading,true,true)
	if not vehicle or vehicle == 0 or not waitForEntity(vehicle,5000) then
		notify(source,"O proxy networkado nao foi criado.","vermelho")
		return
	end

	local networkId = NetworkGetNetworkIdFromEntity(vehicle)
	if not networkId or networkId == 0 then
		safeDeleteEntity(vehicle)
		notify(source,"O proxy nao recebeu network ID.","vermelho")
		return
	end

	SetEntityRoutingBucket(vehicle,GetPlayerRoutingBucket(source))
	SetVehicleDoorsLocked(vehicle,1)
	if FreezeEntityPosition then
		pcall(FreezeEntityPosition,vehicle,false)
	end
	if SetEntityOrphanMode then
		SetEntityOrphanMode(vehicle,2)
	end

	Entity(vehicle).state:set("af:broomProxyTest",true,true)
	local token = createToken(source,0)
	ProxyTests[source] = {
		source = source,
		entity = vehicle,
		networkId = networkId,
		token = token,
		createdAt = GetGameTimer()
	}

	print(("[BROOM PROXY NETWORK] source=%s entity=%s network=%s model=%s bucket=%s"):format(source,vehicle,networkId,modelName,GetPlayerRoutingBucket(source)))
	TriggerClientEvent("af_witch_broom:ProxyNetworkSpawn",source,{ token = token, networkId = networkId })
end

local function createBroom(source,passport,preparedToken)
	local proxyModel = proxyModelName()
	local visualModel = visualModelName()
	if not proxyModel or not visualModel then
		return nil,"Os modelos da vassoura nao estao configurados."
	end

	local ped = GetPlayerPed(source)
	local coords = GetEntityCoords(ped)
	local heading = GetEntityHeading(ped)
	local radians = math.rad(heading)
	local distance = tonumber(Config.Spawn.ForwardDistance) or 2.0
	local spawn = vector3(
		coords.x - math.sin(radians) * distance,
		coords.y + math.cos(radians) * distance,
		coords.z + (tonumber(Config.Spawn.Height) or 1.0)
	)

	local stagingDepth = math.max(15.0,tonumber(Config.Spawn.StagingDepth) or 60.0)
	local staging = vector3(spawn.x,spawn.y,spawn.z - stagingDepth)

	local proxy = CreateVehicle(GetHashKey(proxyModel),staging.x,staging.y,staging.z,heading,true,true)
	if not proxy or proxy == 0 then
		return nil,"Nao foi possivel criar o chassi magico."
	end

	-- Keep the visual shell clear of the physical proxy until the pilot attaches it.
	local visual = CreateVehicle(GetHashKey(visualModel),staging.x,staging.y,staging.z - 3.0,heading,true,true)
	if not visual or visual == 0 then
		safeDeleteEntity(proxy)
		return nil,"Nao foi possivel materializar a Nimbus."
	end

	local session = nil
	local function cleanupCreatedBroom()
		if session then
			if ActiveBrooms[passport] == session then
				ActiveBrooms[passport] = nil
			end
			if PassportBySource[source] == passport then
				PassportBySource[source] = nil
			end
			if sourceOnline(source) then
				pcall(function()
					Player(source).state:set("WitchBroom",false,true)
				end)
			end
		end

		safeDeleteEntity(visual)
		safeDeleteEntity(proxy)
	end

	local initialized,result,errorMessage = xpcall(function()
		if not waitForEntity(proxy,5000) or not waitForEntity(visual,5000) then
			return nil,"As entidades da vassoura nao foram criadas."
		end

		local proxyNetwork = NetworkGetNetworkIdFromEntity(proxy)
		local visualNetwork = NetworkGetNetworkIdFromEntity(visual)
		if not proxyNetwork or proxyNetwork == 0 or not visualNetwork or visualNetwork == 0 then
			return nil,"A vassoura nao recebeu identificacoes de rede validas."
		end

		local bucket = GetPlayerRoutingBucket(source)
		SetEntityRoutingBucket(proxy,bucket)
		SetEntityRoutingBucket(visual,bucket)
		SetVehicleNumberPlateText(proxy,("MAG%05d"):format(passport % 100000))
		SetVehicleNumberPlateText(visual,("VIS%05d"):format(passport % 100000))
		SetVehicleDoorsLocked(proxy,1)
		SetVehicleDoorsLocked(visual,2)
		if FreezeEntityPosition then
			pcall(FreezeEntityPosition,proxy,true)
			pcall(FreezeEntityPosition,visual,true)
		end

		if SetEntityOrphanMode then
			SetEntityOrphanMode(proxy,2)
			SetEntityOrphanMode(visual,2)
		end

		local token = preparedToken or createToken(source,passport)
		local proxyState = Entity(proxy).state
		proxyState:set("af:broomOwner",passport,true)
		proxyState:set("af:broomActive",false,true)
		proxyState:set("af:broomPreparing",true,true)
		proxyState:set("af:broomProxy",true,true)
		proxyState:set("af:broomVisualNet",visualNetwork,true)
		proxyState:set("af:broomBoosting",false,true)
		proxyState:set("af:broomHover",true,true)
		proxyState:set("Lockpick",passport,true)
		proxyState:set("SpecialVehicle","witch_broom",true)

		local visualState = Entity(visual).state
		visualState:set("af:broomOwner",passport,true)
		visualState:set("af:broomActive",false,true)
		visualState:set("af:broomPreparing",true,true)
		visualState:set("af:broomVisual",true,true)
		visualState:set("af:broomPhysicsNet",proxyNetwork,true)
		visualState:set("SpecialVehicle","witch_broom_visual",true)

		session = {
			source = source,
			passport = passport,
			vehicle = proxy,
			network = proxyNetwork,
			proxy = proxy,
			proxyNetwork = proxyNetwork,
			visual = visual,
			visualNetwork = visualNetwork,
			token = token,
			bucket = bucket,
			origin = plainCoords(coords),
			spawn = plainCoords(spawn),
			heading = heading,
			staging = plainCoords(staging),
			lastCoords = plainCoords(spawn),
			lastCheckAt = GetGameTimer(),
			createdAt = GetGameTimer(),
			lastHeartbeat = GetGameTimer(),
			lastBoostRequest = 0,
			violations = 0,
			state = "preparing",
			mounted = false,
			forcedLandingAt = nil,
			removing = false
		}

		ActiveBrooms[passport] = session
		PassportBySource[source] = passport
		Player(source).state:set("WitchBroom",false,true)

		lifecycleLog("proxy_created",("passport=%s entity=%s network=%s model=%s"):format(passport,proxy,proxyNetwork,proxyModel))
		lifecycleLog("visual_created",("passport=%s entity=%s network=%s model=%s"):format(passport,visual,visualNetwork,visualModel))
		lifecycleLog("session_registered",("passport=%s physicsNet=%s visualNet=%s"):format(passport,proxyNetwork,visualNetwork))

		TriggerClientEvent("af_witch_broom:Activate",source,{
			physicsNetwork = proxyNetwork,
			visualNetwork = visualNetwork,
			token = token,
			originZ = coords.z + 0.0,
			spawn = plainCoords(spawn),
			heading = heading
		})
		lifecycleLog("activate_sent",("passport=%s source=%s physicsNet=%s visualNet=%s"):format(passport,source,proxyNetwork,visualNetwork))

		SetTimeout(math.max(3000,tonumber(Config.Spawn.VisualReadyTimeout) or 6000),function()
			if ActiveBrooms[passport] == session and session.state == "preparing" then
				if sourceOnline(source) then
					notify(source,"A Nimbus nao ficou pronta a tempo. Tente novamente.","vermelho")
				end
				removeSession(session,"visual_ready_timeout")
			end
		end)

		return session
	end,function(error)
		return debug.traceback(tostring(error),2)
	end)

	if not initialized then
		cleanupCreatedBroom()
		lifecycleLog("initialization_failed",tostring(result))
		return nil,"A inicializacao da Nimbus falhou e as entidades foram removidas."
	end

	if not result then
		cleanupCreatedBroom()
		return nil,errorMessage or "A inicializacao da Nimbus nao foi concluida."
	end

	return result
end

local function prepareBroom(source,passport)
	local proxyModel = proxyModelName()
	local visualModel = visualModelName()
	if not proxyModel or not visualModel then
		notify(source,"Os modelos da vassoura nao estao habilitados.","vermelho")
		return
	end

	local token = createToken(source,passport)
	local pending = {
		source = source,
		passport = passport,
		token = token,
		models = { proxyModel, visualModel },
		expiresAt = GetGameTimer() + math.max(5000,tonumber(Config.Spawn.PendingTimeout) or 12000)
	}
	PendingSpawns[source] = pending
	TriggerClientEvent("af_witch_broom:PrepareSpawn",source,{
		token = token,
		models = pending.models
	})

	SetTimeout(math.max(5000,tonumber(Config.Spawn.PendingTimeout) or 12000),function()
		if PendingSpawns[source] == pending then
			PendingSpawns[source] = nil
			if sourceOnline(source) then
				TriggerClientEvent("af_witch_broom:CancelPreparation",source,pending.token)
				notify(source,"A preparacao da Nimbus expirou. Tente novamente.","vermelho")
			end
		end
	end)
end

local function toggleBroom(source)
	if not requestAllowed(source) then
		return
	end

	local allowed,passport = hasPermission(source)
	if not allowed then
		notify(source,"Voce nao possui a habilidade Bruxo.","vermelho")
		return
	end

	local existing = ActiveBrooms[passport]
	if existing then
		TriggerClientEvent("af_witch_broom:BeginLanding",source,"command")
		return
	end
	if PendingSpawns[source] then
		return
	end

	local blocked,message = playerBlocked(source)
	if blocked then
		notify(source,message,"vermelho")
		return
	end

	prepareBroom(source,passport)
end

RegisterNetEvent("af_witch_broom:RequestToggle",function()
	toggleBroom(source)
end)

RegisterNetEvent("af_witch_broom:RequestAccess",function()
	local source = source
	local allowed = hasPermission(source)
	TriggerClientEvent("af_witch_broom:SetAccess",source,allowed == true)
end)

RegisterNetEvent("af_witch_broom:ModelReady",function(receivedToken,ready)
	local source = source
	local pending = PendingSpawns[source]
	if not pending or pending.token ~= receivedToken then
		return
	end
	PendingSpawns[source] = nil

	if GetGameTimer() > pending.expiresAt then
		TriggerClientEvent("af_witch_broom:CancelPreparation",source,pending.token)
		return
	end

	if ready ~= true then
		TriggerClientEvent("af_witch_broom:CancelPreparation",source,pending.token)
		notify(source,"A Oppressor ou a Nimbus nao foi carregada. Verifique os resources.","vermelho")
		return
	end

	local allowed,passport = hasPermission(source)
	if not allowed or passport ~= pending.passport or ActiveBrooms[passport] then
		TriggerClientEvent("af_witch_broom:CancelPreparation",source,pending.token)
		return
	end

	local blocked,message = playerBlocked(source)
	if blocked then
		TriggerClientEvent("af_witch_broom:CancelPreparation",source,pending.token)
		notify(source,message,"vermelho")
		return
	end

	local session,errorMessage = createBroom(source,passport,pending.token)
	if not session then
		TriggerClientEvent("af_witch_broom:CancelPreparation",source,pending.token)
		notify(source,errorMessage or "Nao foi possivel invocar a vassoura.","vermelho")
	end
end)

RegisterNetEvent("af_witch_broom:VisualReady",function(receivedToken)
	local source = source
	local session = sessionForSource(source)
	if not session or session.token ~= receivedToken or session.state ~= "preparing" then
		return
	end

	if not DoesEntityExist(session.proxy) or not DoesEntityExist(session.visual) then
		removeSession(session,"visual_ready_missing_entity")
		return
	end

	local allowed,passport = hasPermission(source)
	if not allowed or passport ~= session.passport then
		removeSession(session,"visual_ready_invalid_owner")
		return
	end

	session.state = "mounting"
	session.lastCoords = plainCoords(session.spawn)
	session.lastCheckAt = GetGameTimer()
	Entity(session.proxy).state:set("af:broomPreparing",false,true)
	Entity(session.proxy).state:set("af:broomActive",true,true)
	Entity(session.visual).state:set("af:broomPreparing",false,true)
	Entity(session.visual).state:set("af:broomActive",true,true)

	TriggerClientEvent("af_witch_broom:FinalizeSpawn",source,{
		token = session.token,
		physicsNetwork = session.proxyNetwork,
		visualNetwork = session.visualNetwork,
		spawn = session.spawn,
		heading = session.heading,
		originZ = session.origin.z
	})
	lifecycleLog("visual_ready",("passport=%s physicsNet=%s visualNet=%s"):format(session.passport,session.proxyNetwork,session.visualNetwork))
end)

RegisterNetEvent("af_witch_broom:MountConfirmed",function(receivedToken)
	local source = source
	local session = sessionForSource(source)
	if not session or session.token ~= receivedToken or not DoesEntityExist(session.proxy) then
		return
	end
	if session.mounted then
		return
	end

	local ped = GetPlayerPed(source)
	if GetPedInVehicleSeat(session.proxy,-1) ~= ped then
		removeSession(session,"mount_confirmation_failed")
		return
	end

	session.mounted = true
	session.state = "active"
	SetVehicleDoorsLocked(session.proxy,2)
	Player(source).state:set("WitchBroom",true,true)
	TriggerClientEvent("af_witch_broom:PlayFx",-1,"summon",plainCoords(GetEntityCoords(session.proxy)))
	lifecycleLog("mount_confirmed",("passport=%s source=%s physicsNet=%s visualNet=%s"):format(session.passport,source,session.proxyNetwork,session.visualNetwork))
end)

RegisterNetEvent("af_witch_broom:RequestMagicBoost",function(receivedToken)
	local source = source
	local session = sessionForSource(source)
	if not session or session.token ~= receivedToken or not session.mounted or session.state ~= "active" then
		return
	end

	if Config.Boost.Enabled ~= true or not DoesEntityExist(session.proxy) then
		return
	end

	local ped = GetPlayerPed(source)
	if GetPedInVehicleSeat(session.proxy,-1) ~= ped then
		return
	end

	local state = Player(source).state
	if Config.Restrictions.AllowBoostInSafeZones ~= true and state.Safezone then
		return
	end

	local now = GetGameTimer()
	local cooldown = math.max(0,tonumber(Config.Boost.CooldownMs) or 3200)
	if session.boostCooldownUntil and now < session.boostCooldownUntil then
		TriggerClientEvent("af_witch_broom:MagicBoostDenied",source,session.token,session.boostCooldownUntil - now)
		return
	end

	local duration = math.max(250,tonumber(Config.Boost.DurationMs) or 1600)
	-- CooldownMs representa o intervalo total entre dois impulsos, e nao
	-- uma espera adicional depois da duracao. Isso evita somar 1.6 s + 6 s.
	session.boostCooldownUntil = now + math.max(duration,cooldown)
	session.boostUntil = now + duration
	Entity(session.proxy).state:set("af:broomBoosting",true,true)
	TriggerClientEvent("af_witch_broom:MagicBoostGranted",source,session.token,duration,session.boostCooldownUntil)

	SetTimeout(duration,function()
		if ActiveBrooms[session.passport] == session and DoesEntityExist(session.proxy) then
			Entity(session.proxy).state:set("af:broomBoosting",false,true)
		end
	end)
end)

RegisterNetEvent("af_witch_broom:Heartbeat",function(receivedToken)
	local session = sessionForSource(source)
	if session and session.token == receivedToken then
		session.lastHeartbeat = GetGameTimer()
	end
end)

RegisterNetEvent("af_witch_broom:Dismiss",function(receivedToken)
	local source = source
	local session = sessionForSource(source)
	if not session or session.token ~= receivedToken then
		return
	end

	if DoesEntityExist(session.proxy) then
		local ped = GetPlayerPed(source)
		if GetPedInVehicleSeat(session.proxy,-1) ~= ped then
			return
		end

		local vehicleCoords = GetEntityCoords(session.proxy)
		if #(vehicleCoords - GetEntityCoords(ped)) > 8.0 then
			return
		end

		local velocity = GetEntityVelocity(session.proxy)
		local speed = math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y + velocity.z * velocity.z)
		if speed > math.max(10.0,(tonumber(Config.Landing.AutomaticDescentSpeed) or 6.0) + 4.0) then
			return
		end
	end

	removeSession(session,"dismissed")
end)

RegisterNetEvent("af_witch_broom:ClientFailed",function(receivedToken,reason)
	local session = sessionForSource(source)
	if session and session.token == receivedToken then
		removeSession(session,reason or "client_failed")
	end
end)

RegisterNetEvent("af_witch_broom:ProxyNetworkResult",function(receivedToken,mounted,mountMethod)
	local source = source
	local test = ProxyTests[source]
	if not test or test.token ~= receivedToken then
		return
	end

	local vehicle = test.entity
	local driver = DoesEntityExist(vehicle) and GetPedInVehicleSeat(vehicle,-1) or 0
	print(("[BROOM PROXY NETWORK RESULT] source=%s entity=%s network=%s mounted=%s method=%s driver=%s locked=%s frozen=%s"):format(
		source,tostring(vehicle),tostring(test.networkId),tostring(mounted == true),tostring(mountMethod),tostring(driver),
		tostring(DoesEntityExist(vehicle) and GetVehicleDoorLockStatus(vehicle)),tostring(DoesEntityExist(vehicle) and IsEntityPositionFrozen(vehicle))
	))

	if mounted ~= true then
		removeProxyTest(source,"mount_"..tostring(mountMethod or "failed"))
	end
end)

AddEventHandler("af_witch_broom:PermissionChanged",function(passport,enabled)
	passport = tonumber(passport)
	if not passport then
		return
	end

	local target = vRP.Source(passport)
	if target then
		TriggerClientEvent("af_witch_broom:SetAccess",target,enabled == true)
		if not enabled and PendingSpawns[target] then
			TriggerClientEvent("af_witch_broom:CancelPreparation",target,PendingSpawns[target].token)
			PendingSpawns[target] = nil
		end
	end

	if not enabled and ActiveBrooms[passport] then
		removeSession(ActiveBrooms[passport],"permission_removed")
	end
end)

AddEventHandler("playerDropped",function()
	local droppedSource = source
	PendingSpawns[droppedSource] = nil
	removeProxyTest(droppedSource,"player_dropped")
	local session = sessionForSource(droppedSource)
	if session then
		removeSession(session,"player_dropped")
	end
	RequestCooldowns[droppedSource] = nil
end)

local function ownerDebugAllowed(source)
	if not Config.Debug or not sourceOnline(source) then
		return false
	end

	local passport = vRP.Passport(source)
	if tonumber(passport) ~= tonumber(Config.OwnerPassport) then
		notify(source,"Este diagnostico e exclusivo do proprietario.","vermelho")
		return false
	end

	return true
end

local function registerDebugCommand(command,action)
	if type(command) ~= "string" or command == "" then
		return
	end

	RegisterCommand(command,function(source,args)
		if not ownerDebugAllowed(source) then
			return
		end

		if action == "cleanup" then
			removeProxyTest(source,"owner_debug_cleanup")
			local session = sessionForSource(source)
			if session then
				removeSession(session,"owner_debug_cleanup")
			end
			if PendingSpawns[source] then
				TriggerClientEvent("af_witch_broom:CancelPreparation",source,PendingSpawns[source].token)
				PendingSpawns[source] = nil
			end
		end

		if action == "proxy_network_test" then
			createProxyNetworkTest(source)
			return
		end

		TriggerClientEvent("af_witch_broom:DebugAction",source,action,args or {})
	end,false)
end

if Config.Debug then
	registerDebugCommand(Config.DebugCommands.Status,"status")
	registerDebugCommand(Config.DebugCommands.SpawnModel,"spawn")
	registerDebugCommand(Config.DebugCommands.MountTest,"mount")
	registerDebugCommand(Config.DebugCommands.Remount,"remount")
	registerDebugCommand(Config.DebugCommands.Cleanup,"cleanup")
	registerDebugCommand(Config.DebugCommands.Proxy,"proxy")
	registerDebugCommand(Config.DebugCommands.Visual,"visual")
	registerDebugCommand(Config.DebugCommands.Offset,"offset")
	registerDebugCommand(Config.DebugCommands.Rotation,"rotation")
	registerDebugCommand(Config.DebugCommands.SaveOffset,"save_offset")
	registerDebugCommand(Config.DebugCommands.OffsetDebug,"offset_debug")
	registerDebugCommand(Config.DebugCommands.HudPosition,"hud_position")
	registerDebugCommand(Config.DebugCommands.ProxyPoseTest,"proxy_pose_test")
	registerDebugCommand(Config.DebugCommands.ProxyLocalTest,"proxy_local_test")
	registerDebugCommand(Config.DebugCommands.ProxyNetworkTest,"proxy_network_test")
	registerDebugCommand(Config.DebugCommands.ProxyDiagnostic,"proxy_diag")
end

CreateThread(function()
	while true do
		Wait(math.max(500,tonumber(Config.Security.MonitorInterval) or 1000))
		local now = GetGameTimer()
		local snapshot = {}
		for _,session in pairs(ActiveBrooms) do
			snapshot[#snapshot + 1] = session
		end

		for _,session in ipairs(snapshot) do
			if not session.removing then
				local reason = nil
				local allowed,passport = hasPermission(session.source)
				if not sourceOnline(session.source) or not allowed or passport ~= session.passport then
					reason = "invalid_owner"
				elseif not DoesEntityExist(session.proxy) or not DoesEntityExist(session.visual) then
					reason = "missing_entity"
				elseif GetPlayerRoutingBucket(session.source) ~= session.bucket or GetEntityRoutingBucket(session.proxy) ~= session.bucket or GetEntityRoutingBucket(session.visual) ~= session.bucket then
					reason = "routing_bucket"
				elseif session.state == "preparing" then
					if now - session.createdAt > math.max(3000,tonumber(Config.Spawn.VisualReadyTimeout) or 6000) then
						reason = "visual_ready_timeout"
					end
				elseif session.state == "mounting" then
					if now - session.createdAt > math.max(3000,tonumber(Config.Spawn.MountTimeout) or 8000) then
						reason = "mount_timeout"
					end
				elseif session.mounted and now - session.lastHeartbeat > math.max(3000,tonumber(Config.Security.HeartbeatTimeout) or 12000) then
					reason = "heartbeat_timeout"
				else
					local ped = GetPlayerPed(session.source)
					local state = Player(session.source).state
					if Config.Restrictions.BlockWhenDead and (state.Death or state.Crawl or GetEntityHealth(ped) <= 100) then
						reason = "owner_incapacitated"
					elseif (Config.Restrictions.AllowInSafeZones ~= true and state.Safezone) or (Config.Restrictions.BlockStreetRace and state.StreetRace) then
						if not session.forcedLandingAt then
							session.forcedLandingAt = now
							TriggerClientEvent("af_witch_broom:BeginLanding",session.source,"restricted_zone")
						elseif now - session.forcedLandingAt > math.max(5000,tonumber(Config.Landing.Timeout) or 20000) then
							reason = "landing_timeout"
						end
					else
						session.forcedLandingAt = nil
					end

					if not reason then
						local driver = GetPedInVehicleSeat(session.proxy,-1)
						if driver ~= 0 and driver ~= ped then
							reason = "intruder_driver"
						elseif not session.mounted then
							if now - session.createdAt > math.max(3000,tonumber(Config.Spawn.MountTimeout) or 8000) then
								reason = "mount_timeout"
							end
						elseif driver ~= ped then
							reason = "invalid_driver"
						end
					end

					if not reason then
						local velocity = GetEntityVelocity(session.proxy)
						local speed = math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y + velocity.z * velocity.z)
						local maximum = tonumber(Config.Security.MaximumNativeSpeed) or 80.0
						local tolerance = tonumber(Config.Security.MaximumSpeedTolerance) or 1.35
						if speed > maximum * tolerance then
							session.violations = session.violations + 1
						else
							session.violations = math.max(0,session.violations - 1)
						end

						local currentCoords = GetEntityCoords(session.proxy)
						local elapsed = math.max(0.25,(now - session.lastCheckAt) / 1000.0)
						local lastCoords = vector3(session.lastCoords.x,session.lastCoords.y,session.lastCoords.z)
						local maximumTravel = maximum * elapsed * tolerance + 25.0
						if #(currentCoords - lastCoords) > maximumTravel then
							session.violations = session.violations + 1
						end
						session.lastCoords = plainCoords(currentCoords)
						session.lastCheckAt = now

						local altitudeLimit = math.min(
							tonumber(Config.Flight.MaximumWorldHeight) or 700.0,
							session.origin.z + (tonumber(Config.Flight.MaximumAltitude) or 300.0) + (tonumber(Config.Security.MaximumAltitudeTolerance) or 40.0)
						)
						if currentCoords.z > altitudeLimit then
							session.violations = session.violations + 1
						end

						if session.violations >= math.max(1,tonumber(Config.Security.MaximumViolations) or 3) then
							reason = "security_limit"
						end
					end
				end

				if reason then
					removeSession(session,reason)
				end
			end
		end
	end
end)

AddEventHandler("onResourceStop",function(resource)
	if resource ~= GetCurrentResourceName() then
		return
	end

	for _,session in pairs(ActiveBrooms) do
		safeDeleteEntity(session.visual)
		safeDeleteEntity(session.proxy)
		if sourceOnline(session.source) then
			Player(session.source).state:set("WitchBroom",false,true)
		end
	end

	for source,pending in pairs(PendingSpawns) do
		if sourceOnline(source) then
			TriggerClientEvent("af_witch_broom:CancelPreparation",source,pending.token)
		end
	end

	local proxyTestSources = {}
	for source in pairs(ProxyTests) do
		proxyTestSources[#proxyTestSources + 1] = source
	end

	for _,source in ipairs(proxyTestSources) do
		removeProxyTest(source,"resource_stop")
	end
end)
