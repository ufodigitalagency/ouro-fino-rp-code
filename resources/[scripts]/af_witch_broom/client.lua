local hasAccess = false
local active = false
local token = nil
local proxyVehicle = nil
local visualVehicle = nil
local proxyNetwork = nil
local visualNetwork = nil
local originZ = 0.0
local landingRequested = false
local boostState = false
local boostEndsAt = 0
local boostCooldownEndsAt = 0
local nextHeartbeat = 0
local nextHudUpdate = 0
local nextGroundRecovery = 0
local localVisuals = {}
local preparedToken = nil
local preparedModels = {}
local debugVehicle = nil
local pendingActivation = nil
local knownProxies = {}
local runtimeHud = {
	left = tonumber(Config.Hud.LeftOffset) or 24,
	top = tonumber(Config.Hud.TopOffset) or 110
}

local runtimeOffset = {
	x = Config.ProxyVisual.Offset.x + 0.0,
	y = Config.ProxyVisual.Offset.y + 0.0,
	z = Config.ProxyVisual.Offset.z + 0.0
}

local runtimeRotation = {
	x = Config.ProxyVisual.Rotation.x + 0.0,
	y = Config.ProxyVisual.Rotation.y + 0.0,
	z = Config.ProxyVisual.Rotation.z + 0.0
}

local function debugPrint(message)
	if Config.Debug then
		print(("[af_witch_broom] %s"):format(message))
	end
end

local function notify(message,color)
	TriggerEvent("Notify","Vassoura Magica",message,color or "amarelo",5000)
end

local function loadModel(model,timeout)
	local hash = type(model) == "number" and model or GetHashKey(model)
	if not IsModelInCdimage(hash) or not IsModelValid(hash) then
		return nil
	end

	RequestModel(hash)
	local expires = GetGameTimer() + (timeout or 5000)
	while not HasModelLoaded(hash) and GetGameTimer() < expires do
		Wait(10)
	end

	return HasModelLoaded(hash) and hash or nil
end

local function printProxyModelDiagnostic(hash)
	local diagnostic = {
		inCdImage = IsModelInCdimage(hash),
		valid = IsModelValid(hash),
		isVehicle = IsModelAVehicle(hash),
		seats = GetVehicleModelNumberOfSeats(hash)
	}

	print(("[BROOM PROXY MODEL] model=%s inCdImage=%s valid=%s isVehicle=%s seats=%s"):format(
		tostring(Config.Proxy and Config.Proxy.PoseTestModel or "of_broom_proxy"),
		tostring(diagnostic.inCdImage),tostring(diagnostic.valid),tostring(diagnostic.isVehicle),tostring(diagnostic.seats)
	))

	return diagnostic
end

local function ensureProxyTestDecorator()
	if DecorIsRegisteredAsType("AF_BROOM_PROXY_TEST",2) then
		return true
	end

	pcall(DecorRegister,"AF_BROOM_PROXY_TEST",2)
	return DecorIsRegisteredAsType("AF_BROOM_PROXY_TEST",2)
end

local function requestControl(entity,timeout)
	if not entity or entity == 0 or not DoesEntityExist(entity) then
		return false
	end

	local expires = GetGameTimer() + (timeout or 1500)
	while not NetworkHasControlOfEntity(entity) and GetGameTimer() < expires do
		NetworkRequestControlOfEntity(entity)
		Wait(25)
	end

	return NetworkHasControlOfEntity(entity)
end

local function waitForNetworkVehicle(network,timeout)
	if not network or network == 0 then
		return nil
	end

	local expires = GetGameTimer() + (timeout or 5000)
	while not NetworkDoesEntityExistWithNetworkId(network) and GetGameTimer() < expires do
		Wait(25)
	end

	local vehicle = NetToVeh(network)
	return vehicle ~= 0 and DoesEntityExist(vehicle) and vehicle or nil
end

local function stopBoostFx(entry)
	if entry and entry.boostFx and DoesParticleFxLoopedExist(entry.boostFx) then
		StopParticleFxLooped(entry.boostFx,false)
	end
	if entry then
		entry.boostFx = nil
	end
end

local function startBoostFx(entry)
	local target = entry and entry.visual
	if Config.Boost.ParticleEffect ~= true or not Config.Effects.Enabled or not entry or entry.boostFx or not target or not DoesEntityExist(target) then
		return
	end

	local effects = Config.BoostEffects or Config.Effects
	RequestNamedPtfxAsset(effects.Dictionary or effects.Asset)
	local expires = GetGameTimer() + 1000
	while not HasNamedPtfxAssetLoaded(effects.Dictionary or effects.Asset) and GetGameTimer() < expires do
		Wait(0)
	end

	if HasNamedPtfxAssetLoaded(effects.Dictionary or effects.Asset) then
		local offset = effects.Offset or Config.ProxyVisual.BoostOffset or vector3(0.0,-1.2,0.0)
		local rotation = effects.Rotation or vector3(0.0,0.0,0.0)
		UseParticleFxAssetNextCall(effects.Dictionary or effects.Asset)
		entry.boostFx = StartParticleFxLoopedOnEntity(
			effects.Effect or Config.Effects.Boost,
			target,
			offset.x,offset.y,offset.z,
			rotation.x,rotation.y,rotation.z,
			tonumber(effects.Scale) or 0.75,
			false,false,false
		)
	end
end

local function removeVisualRecord(proxy)
	local entry = localVisuals[proxy]
	if not entry then
		return
	end

	stopBoostFx(entry)
	localVisuals[proxy] = nil
end

local function configureProxy(proxy)
	if not proxy or proxy == 0 or not DoesEntityExist(proxy) then
		return
	end

	SetEntityVisible(proxy,false,false)
	SetEntityAlpha(proxy,0,false)
	SetEntityCollision(proxy,true,true)
	SetVehicleRadioEnabled(proxy,false)
	SetVehRadioStation(proxy,"OFF")
	SetVehicleDirtLevel(proxy,0.0)
	SetVehicleEngineOn(proxy,true,true,false)
	SetVehicleUndriveable(proxy,false)
	knownProxies[proxy] = true
end

local function configureVisual(visual)
	if not visual or visual == 0 or not DoesEntityExist(visual) then
		return
	end

	SetEntityVisible(visual,true,false)
	ResetEntityAlpha(visual)
	SetEntityCollision(visual,Config.ProxyVisual.VisualCollision == true,false)
	SetEntityHasGravity(visual,false)
	SetEntityInvincible(visual,true)
	if Config.GroundStability and Config.GroundStability.DisableVisualDynamics == true and SetEntityDynamic then
		pcall(SetEntityDynamic,visual,false)
	end
	SetVehicleEngineOn(visual,false,true,true)
	SetVehicleUndriveable(visual,true)
	SetVehicleRadioEnabled(visual,false)
	SetVehRadioStation(visual,"OFF")
end

local function attachVisual(proxy,visual,force)
	if not proxy or not visual or not DoesEntityExist(proxy) or not DoesEntityExist(visual) then
		return false
	end

	configureProxy(proxy)
	configureVisual(visual)

	local attachedTo = GetEntityAttachedTo(visual)
	if force or attachedTo ~= proxy then
		if IsEntityAttached(visual) then
			DetachEntity(visual,true,false)
		end

		AttachEntityToEntity(
			visual,proxy,0,
			runtimeOffset.x,runtimeOffset.y,runtimeOffset.z,
			runtimeRotation.x,runtimeRotation.y,runtimeRotation.z,
			false,false,false,false,2,true
		)
	end

	-- Mesmo com a colisao global da casca desativada, esta protecao evita
	-- que a Nimbus visual interfira no chassi durante curvas fechadas.
	if SetEntityNoCollisionEntity then
		pcall(SetEntityNoCollisionEntity,visual,proxy,true)
		pcall(SetEntityNoCollisionEntity,proxy,visual,true)
	end

	return GetEntityAttachedTo(visual) == proxy
end

local function ensureVisual(proxy)
	if not proxy or proxy == 0 or not DoesEntityExist(proxy) then
		return nil
	end

	local state = Entity(proxy).state
	if state["af:broomProxy"] ~= true or (state["af:broomActive"] ~= true and state["af:broomPreparing"] ~= true) then
		removeVisualRecord(proxy)
		return nil
	end

	configureProxy(proxy)
	local network = tonumber(state["af:broomVisualNet"])
	if not network or network == 0 or not NetworkDoesEntityExistWithNetworkId(network) then
		return nil
	end

	local visual = NetToVeh(network)
	if visual == 0 or not DoesEntityExist(visual) then
		return nil
	end

	local entry = localVisuals[proxy]
	if entry and entry.visual ~= visual then
		removeVisualRecord(proxy)
		entry = nil
	end

	if not entry then
		entry = { visual = visual, boostFx = nil }
		localVisuals[proxy] = entry
	end

	attachVisual(proxy,visual,false)
	if state["af:broomBoosting"] == true then
		startBoostFx(entry)
	else
		stopBoostFx(entry)
	end

	return visual
end

local function reconcileEntity(entity)
	if not entity or entity == 0 or not DoesEntityExist(entity) then
		return
	end

	local state = Entity(entity).state
	if state["af:broomProxy"] == true and (state["af:broomActive"] == true or state["af:broomPreparing"] == true) then
		ensureVisual(entity)
	elseif state["af:broomVisual"] == true then
		configureVisual(entity)
	end
end

local function playFx(kind,coords)
	if not Config.Effects.Enabled or type(coords) ~= "table" then
		return
	end

	local pedCoords = GetEntityCoords(PlayerPedId())
	local effectCoords = vector3(tonumber(coords.x) or 0.0,tonumber(coords.y) or 0.0,tonumber(coords.z) or 0.0)
	if #(pedCoords - effectCoords) > (tonumber(Config.Effects.MaximumDistance) or 120.0) then
		return
	end

	RequestNamedPtfxAsset(Config.Effects.Asset)
	local expires = GetGameTimer() + 1000
	while not HasNamedPtfxAssetLoaded(Config.Effects.Asset) and GetGameTimer() < expires do
		Wait(0)
	end

	if HasNamedPtfxAssetLoaded(Config.Effects.Asset) then
		UseParticleFxAssetNextCall(Config.Effects.Asset)
		local effect = kind == "dismiss" and Config.Effects.Dismiss or Config.Effects.Summon
		StartParticleFxNonLoopedAtCoord(effect,effectCoords.x,effectCoords.y,effectCoords.z,0.0,0.0,0.0,Config.Effects.Scale or 1.0,false,false,false)
	end
end

local function groundDistance(vehicle)
	if not vehicle or not DoesEntityExist(vehicle) then
		return nil,false
	end

	local coords = GetEntityCoords(vehicle)
	local probe = tonumber(Config.Landing.GroundProbeDistance) or 450.0
	local ray = StartShapeTestRay(coords.x,coords.y,coords.z + 1.0,coords.x,coords.y,coords.z - probe,1,vehicle,7)
	local _,hit,endCoords = GetShapeTestResult(ray)
	if hit == 1 then
		return math.max(0.0,coords.z - endCoords.z),true
	end

	return nil,false
end

local function setHudVisible(state)
	if not Config.Hud.Enabled then
		return
	end

	SendNUIMessage({
		action = state and "show" or "hide",
		layout = {
			anchor = Config.Hud.Anchor or "top-left",
			left = runtimeHud.left,
			top = runtimeHud.top,
			width = tonumber(Config.Hud.Width) or 270,
			scale = tonumber(Config.Hud.Scale) or 1.0
		}
	})
end

local function setBroomMode(state)
	LocalPlayer.state:set("af:broomMode",state == true,false)
	setHudVisible(state == true)
	SetNuiFocus(false,false)
end

local function releasePreparedModels()
	for _,hash in ipairs(preparedModels) do
		SetModelAsNoLongerNeeded(hash)
	end
	preparedModels = {}
	preparedToken = nil
end

local function cleanupLocal()
	local ped = PlayerPedId()
	if active and proxyVehicle and DoesEntityExist(proxyVehicle) and GetPedInVehicleSeat(proxyVehicle,-1) == ped then
		TaskLeaveVehicle(ped,proxyVehicle,16)
	end

	if proxyVehicle then
		removeVisualRecord(proxyVehicle)
	end

	LocalPlayer.state:set("WitchBroom",false,true)
	active = false
	token = nil
	proxyVehicle = nil
	visualVehicle = nil
	proxyNetwork = nil
	visualNetwork = nil
	originZ = 0.0
	landingRequested = false
	boostState = false
	boostEndsAt = 0
	boostCooldownEndsAt = 0
	pendingActivation = nil
	nextHeartbeat = 0
	nextHudUpdate = 0
	nextGroundRecovery = 0
	setBroomMode(false)
	StopGameplayCamShaking(true)
	StopScreenEffect("RaceTurbo")
	SetPedMotionBlur(ped,false)
	releasePreparedModels()
end

local function localInvocationBlocked()
	local ped = PlayerPedId()
	if Config.Restrictions.BlockWhenDead and (LocalPlayer.state.Death or LocalPlayer.state.Crawl or IsEntityDead(ped) or GetEntityHealth(ped) <= 100) then
		return "Voce nao pode invocar a vassoura enquanto estiver incapacitado."
	end
	if Config.Restrictions.BlockInteriors and GetInteriorFromEntity(ped) ~= 0 then
		return "A vassoura precisa ser invocada ao ar livre."
	end
	if Config.Restrictions.BlockUnderwater and IsPedSwimmingUnderWater(ped) then
		return "Nao e possivel invocar a vassoura debaixo d'agua."
	end
	return nil
end

local function mountBroom(vehicle)
	local ped = PlayerPedId()
	if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
		return false,"missing_vehicle"
	end

	local driver = GetPedInVehicleSeat(vehicle,-1)
	if driver ~= 0 and driver ~= ped then
		return false,"seat_occupied"
	end

	SetVehicleDoorsLocked(vehicle,1)
	SetVehicleDoorsLockedForAllPlayers(vehicle,false)
	SetVehicleDoorsLockedForPlayer(vehicle,PlayerId(),false)
	SetPedIntoVehicle(ped,vehicle,-1)
	Wait(100)

	if GetPedInVehicleSeat(vehicle,-1) ~= ped then
		TaskWarpPedIntoVehicle(ped,vehicle,-1)
		Wait(250)
	end

	if GetPedInVehicleSeat(vehicle,-1) ~= ped then
		TaskEnterVehicle(ped,vehicle,3000,-1,1.0,16,0)
		local timeout = GetGameTimer() + 3500
		while GetPedInVehicleSeat(vehicle,-1) ~= ped and GetGameTimer() < timeout do
			Wait(50)
		end
	end

	if GetPedInVehicleSeat(vehicle,-1) ~= ped then
		return false,"mount_failed"
	end

	SetVehicleDoorsLocked(vehicle,2)
	SetVehicleDoorsLockedForPlayer(vehicle,PlayerId(),false)
	return true
end

local function waitForProxyCollision(vehicle,timeout)
	local expires = GetGameTimer() + (timeout or 2000)
	while not HasCollisionLoadedAroundEntity(vehicle) and GetGameTimer() < expires do
		Wait(50)
	end

	return HasCollisionLoadedAroundEntity(vehicle)
end

local function getNetworkIdIfNetworked(entity)

	if not entity or not DoesEntityExist(entity) or not NetworkGetEntityIsNetworked(entity) then
		return 0
	end

	return NetworkGetNetworkIdFromEntity(entity)
end

local function printProxyVehicleDiagnostic(label,vehicle,hash,mountMethod,collisionLoaded)
	local exists = vehicle and DoesEntityExist(vehicle)
	if not exists then
		print(("[BROOM PROXY %s] entity=%s exists=false seatCount=%s collisionLoaded=%s mountMethod=%s"):format(
			label,tostring(vehicle),tostring(GetVehicleModelNumberOfSeats(hash)),tostring(collisionLoaded),tostring(mountMethod or "none")
		))
		return
	end

	local driverSeatBone = GetEntityBoneIndexByName(vehicle,"seat_dside_f")
	local chassisBone = GetEntityBoneIndexByName(vehicle,"chassis")
	print(("[BROOM PROXY %s] entity=%s model=%s network=%s seatCount=%s seatFree=%s currentDriver=%s seat_dside_f=%s chassis=%s locked=%s frozen=%s undriveable=%s collisionLoaded=%s speed=%.2f mountMethod=%s"):format(
		label,tostring(vehicle),tostring(GetEntityModel(vehicle)),tostring(getNetworkIdIfNetworked(vehicle)),
		tostring(GetVehicleModelNumberOfSeats(hash)),tostring(IsVehicleSeatFree(vehicle,-1)),tostring(GetPedInVehicleSeat(vehicle,-1)),
		tostring(driverSeatBone),tostring(chassisBone),tostring(vehicle and GetVehicleDoorLockStatus(vehicle)),
		tostring(IsEntityPositionFrozen(vehicle)),tostring(IsVehicleDriveable(vehicle,false) == false),
		tostring(collisionLoaded),GetEntitySpeed(vehicle),tostring(mountMethod or "none")
	))
end

local function prepareProxyTestVehicle(vehicle,coords)
	SetEntityAsMissionEntity(vehicle,true,true)
	SetVehicleOnGroundProperly(vehicle)
	SetEntityVisible(vehicle,true,false)
	ResetEntityAlpha(vehicle)
	SetEntityCollision(vehicle,true,true)
	SetEntityHasGravity(vehicle,true)
	FreezeEntityPosition(vehicle,false)
	SetVehicleUndriveable(vehicle,false)
	SetVehicleEngineOn(vehicle,true,true,false)
	SetVehicleDoorsLocked(vehicle,1)
	SetVehicleDoorsLockedForAllPlayers(vehicle,false)
	SetVehicleDoorsLockedForPlayer(vehicle,PlayerId(),false)
	RequestCollisionAtCoord(coords.x,coords.y,coords.z)
	return waitForProxyCollision(vehicle,2000)
end

local function mountProxyTest(vehicle)
	local ped = PlayerPedId()
	if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
		return false,"missing_vehicle"
	end

	if GetVehicleModelNumberOfSeats(GetEntityModel(vehicle)) < 1 then
		return false,"no_driver_seat"
	end

	local driver = GetPedInVehicleSeat(vehicle,-1)
	if driver ~= 0 and driver ~= ped then
		return false,"seat_occupied"
	end

	SetVehicleDoorsLocked(vehicle,1)
	SetVehicleDoorsLockedForAllPlayers(vehicle,false)
	SetVehicleDoorsLockedForPlayer(vehicle,PlayerId(),false)

	TaskWarpPedIntoVehicle(ped,vehicle,-1)
	Wait(300)
	if GetPedInVehicleSeat(vehicle,-1) == ped then
		return true,"warp"
	end

	SetPedIntoVehicle(ped,vehicle,-1)
	Wait(300)
	if GetPedInVehicleSeat(vehicle,-1) == ped then
		return true,"set"
	end

	TaskEnterVehicle(ped,vehicle,5000,-1,2.0,16,0)
	local expires = GetGameTimer() + 5000
	while GetPedInVehicleSeat(vehicle,-1) ~= ped and GetGameTimer() < expires do
		Wait(50)
	end

	if GetPedInVehicleSeat(vehicle,-1) == ped then
		return true,"enter"
	end

	return false,"mount_failed"
end

local function isBoosting()
	return active and GetGameTimer() < boostEndsAt
end

local function boostCooldownRemaining()
	return math.max(0,boostCooldownEndsAt - GetGameTimer())
end

local function stabilizeGroundedProxy(vehicle,distanceToGround,hasGround,speed,now)
	local settings = Config.GroundStability
	if not settings or settings.Enabled ~= true or settings.RecoveryEnabled ~= true then
		return
	end

	if not vehicle or not DoesEntityExist(vehicle) or not hasGround then
		return
	end

	if distanceToGround > (tonumber(settings.MaximumGroundDistance) or 1.35) then
		return
	end

	if speed > (tonumber(settings.MaximumRecoverySpeed) or 2.8) then
		return
	end

	if now < nextGroundRecovery or isBoosting() then
		return
	end

	local roll = math.abs(GetEntityRoll(vehicle))
	if roll < (tonumber(settings.RecoveryRoll) or 38.0) then
		return
	end

	if requestControl(vehicle,200) then
		pcall(SetVehicleOnGroundProperly,vehicle)
		nextGroundRecovery = now + math.max(500,tonumber(settings.RecoveryCooldownMs) or 1200)
	end
end

local function startPilotBoostEffects()
	local ped = PlayerPedId()
	if Config.Boost.MotionBlur == true then
		SetPedMotionBlur(ped,true)
	end
	if Config.Boost.ScreenEffect == true then
		StartScreenEffect("RaceTurbo",math.max(250,tonumber(Config.Boost.DurationMs) or 1600),false)
	end
	if tonumber(Config.Boost.CameraShake) and tonumber(Config.Boost.CameraShake) > 0.0 then
		ShakeGameplayCam("ROAD_VIBRATION_SHAKE",tonumber(Config.Boost.CameraShake))
	end
end

local function stopPilotBoostEffects()
	local ped = PlayerPedId()
	StopScreenEffect("RaceTurbo")
	StopGameplayCamShaking(true)
	SetPedMotionBlur(ped,false)
end

RegisterCommand(Config.Command,function()
	if not active then
		local reason = localInvocationBlocked()
		if reason then
			notify(reason,"vermelho")
			return
		end
	end

	-- A permissao e validada novamente pelo servidor. Nao bloqueie o comando
	-- com um cache local ainda nao recarregado apos restart do resource.
	TriggerServerEvent("af_witch_broom:RequestAccess")
	TriggerServerEvent("af_witch_broom:RequestToggle")
end,false)

RegisterNetEvent("af_witch_broom:SetAccess",function(state)
	hasAccess = state == true
	if not hasAccess then
		if active then
			cleanupLocal()
		else
			releasePreparedModels()
		end
	end
end)

RegisterNetEvent("af_witch_broom:CancelPreparation",function(receivedToken)
	if not receivedToken or preparedToken == receivedToken then
		releasePreparedModels()
	end
end)

RegisterNetEvent("af_witch_broom:PrepareSpawn",function(payload)
	if type(payload) ~= "table" or type(payload.token) ~= "string" or type(payload.models) ~= "table" then
		return
	end

	releasePreparedModels()
	local loaded = {}
	for _,model in ipairs(payload.models) do
		if type(model) ~= "string" then
			for _,hash in ipairs(loaded) do
				SetModelAsNoLongerNeeded(hash)
			end
			TriggerServerEvent("af_witch_broom:ModelReady",payload.token,false)
			return
		end

		local hash = loadModel(model,tonumber(Config.Spawn.ModelLoadTimeout) or 8000)
		if not hash then
			for _,loadedHash in ipairs(loaded) do
				SetModelAsNoLongerNeeded(loadedHash)
			end
			TriggerServerEvent("af_witch_broom:ModelReady",payload.token,false)
			notify(("O modelo %s nao esta disponivel."):format(model),"vermelho")
			return
		end
		loaded[#loaded + 1] = hash
	end

	preparedToken = payload.token
	preparedModels = loaded
	TriggerServerEvent("af_witch_broom:ModelReady",payload.token,true)
end)

RegisterNetEvent("af_witch_broom:Activate",function(payload)
	if type(payload) ~= "table" or not payload.physicsNetwork or not payload.visualNetwork or not payload.token then
		return
	end
	if preparedToken ~= payload.token then
		TriggerServerEvent("af_witch_broom:ClientFailed",payload.token,"model_handshake_missing")
		releasePreparedModels()
		return
	end

	local timeout = math.max(3000,tonumber(Config.Spawn.VisualReadyTimeout) or 6000)
	local proxy = waitForNetworkVehicle(payload.physicsNetwork,timeout)
	local visual = waitForNetworkVehicle(payload.visualNetwork,timeout)
	if not proxy or not visual then
		TriggerServerEvent("af_witch_broom:ClientFailed",payload.token,"entity_not_streamed")
		notify("A vassoura nao conseguiu chegar ate voce.","vermelho")
		releasePreparedModels()
		return
	end

	if not requestControl(proxy,2500) or not requestControl(visual,2500) then
		TriggerServerEvent("af_witch_broom:ClientFailed",payload.token,"network_control")
		notify("Nao foi possivel assumir o controle da vassoura.","vermelho")
		releasePreparedModels()
		return
	end

	configureProxy(proxy)
	configureVisual(visual)
	FreezeEntityPosition(proxy,true)
	FreezeEntityPosition(visual,true)
	if not attachVisual(proxy,visual,true) then
		TriggerServerEvent("af_witch_broom:ClientFailed",payload.token,"visual_attach_failed")
		notify("A Nimbus nao conseguiu se alinhar ao voo.","vermelho")
		releasePreparedModels()
		return
	end

	pendingActivation = {
		token = payload.token,
		proxy = proxy,
		visual = visual,
		physicsNetwork = payload.physicsNetwork,
		visualNetwork = payload.visualNetwork,
		originZ = tonumber(payload.originZ) or GetEntityCoords(proxy).z
	}
	TriggerServerEvent("af_witch_broom:VisualReady",payload.token)
	debugPrint(("visual_ready_sent physicsNet=%s visualNet=%s"):format(payload.physicsNetwork,payload.visualNetwork))
end)

RegisterNetEvent("af_witch_broom:FinalizeSpawn",function(payload)
	if type(payload) ~= "table" or not pendingActivation or pendingActivation.token ~= payload.token then
		return
	end

	local pending = pendingActivation
	local proxy = pending.proxy
	local visual = pending.visual
	if not proxy or not visual or not DoesEntityExist(proxy) or not DoesEntityExist(visual) then
		TriggerServerEvent("af_witch_broom:ClientFailed",payload.token,"finalize_missing_entity")
		cleanupLocal()
		return
	end

	if not requestControl(proxy,2500) or not requestControl(visual,2500) then
		TriggerServerEvent("af_witch_broom:ClientFailed",payload.token,"finalize_network_control")
		cleanupLocal()
		return
	end

	local spawn = payload.spawn
	if type(spawn) ~= "table" then
		TriggerServerEvent("af_witch_broom:ClientFailed",payload.token,"finalize_invalid_spawn")
		cleanupLocal()
		return
	end

	SetEntityCoordsNoOffset(proxy,tonumber(spawn.x) or 0.0,tonumber(spawn.y) or 0.0,tonumber(spawn.z) or 0.0,false,false,false)
	SetEntityHeading(proxy,tonumber(payload.heading) or GetEntityHeading(PlayerPedId()))
	configureProxy(proxy)
	configureVisual(visual)
	if not attachVisual(proxy,visual,true) then
		TriggerServerEvent("af_witch_broom:ClientFailed",payload.token,"finalize_visual_attach")
		cleanupLocal()
		return
	end

	FreezeEntityPosition(proxy,false)
	FreezeEntityPosition(visual,false)
	local mounted,mountReason = mountBroom(proxy)
	if not mounted then
		TriggerServerEvent("af_witch_broom:ClientFailed",payload.token,mountReason)
		notify("Nao foi possivel montar na vassoura.","vermelho")
		debugPrint(("mount_failed physicsNet=%s reason=%s"):format(pending.physicsNetwork,tostring(mountReason)))
		cleanupLocal()
		return
	end

	if not requestControl(proxy,2500) then
		TriggerServerEvent("af_witch_broom:ClientFailed",payload.token,"network_control_after_mount")
		cleanupLocal()
		return
	end

	if Config.Boost.NativeRocketBoost == true and SetVehicleRocketBoostPercentage then
		pcall(SetVehicleRocketBoostPercentage,proxy,100.0)
	end

	active = true
	token = payload.token
	proxyVehicle = proxy
	visualVehicle = visual
	proxyNetwork = pending.physicsNetwork
	visualNetwork = pending.visualNetwork
	originZ = tonumber(payload.originZ) or pending.originZ
	landingRequested = false
	boostState = false
	boostEndsAt = 0
	boostCooldownEndsAt = 0
	nextHeartbeat = 0
	nextHudUpdate = 0
	nextGroundRecovery = 0
	pendingActivation = nil
	LocalPlayer.state:set("WitchBroom",true,true)
	ensureVisual(proxy)
	setBroomMode(true)
	print(("[af_witch_broom] client_activated physicsNet=%s visualNet=%s nativeControls=true"):format(tostring(proxyNetwork),tostring(visualNetwork)))
	TriggerServerEvent("af_witch_broom:MountConfirmed",payload.token)
	releasePreparedModels()
	notify("A magia respondeu. Use os controles nativos e X para o impulso magico.","verde")
end)

RegisterNetEvent("af_witch_broom:MagicBoostGranted",function(receivedToken,duration,cooldownEndsAt)
	if not active or token ~= receivedToken then
		return
	end

	local now = GetGameTimer()
	boostEndsAt = now + math.max(250,tonumber(duration) or tonumber(Config.Boost.DurationMs) or 1600)
	boostCooldownEndsAt = math.max(boostEndsAt,tonumber(cooldownEndsAt) or boostEndsAt)
	boostState = true
	startPilotBoostEffects()

	CreateThread(function()
		while active and proxyVehicle and DoesEntityExist(proxyVehicle) and GetGameTimer() < boostEndsAt do
			if requestControl(proxyVehicle,250) then
				local speed = GetEntitySpeed(proxyVehicle)
				local maximum = tonumber(Config.Boost.MaximumSpeed) or 78.0
				if Config.Boost.ExtraForwardImpulse == true and speed < maximum then
					local forward = GetEntityForwardVector(proxyVehicle)
					local strength = tonumber(Config.Boost.ImpulseStrength) or 8.5
					ApplyForceToEntityCenterOfMass(
						proxyVehicle,1,
						forward.x * strength,forward.y * strength,forward.z * (strength * 0.25),
						0,false,true,true
					)
				end
			end
			Wait(50)
		end

		if GetGameTimer() >= boostEndsAt then
			boostState = false
			stopPilotBoostEffects()
		end
	end)
end)

RegisterNetEvent("af_witch_broom:MagicBoostDenied",function(receivedToken,remaining)
	if active and token == receivedToken then
		boostCooldownEndsAt = GetGameTimer() + math.max(0,tonumber(remaining) or 0)
	end
end)

RegisterCommand("+witchBroomBoost",function()
	if not active or not token or Config.Boost.Enabled ~= true or landingRequested then
		return
	end

	if GetGameTimer() < boostCooldownEndsAt then
		return
	end

	TriggerServerEvent("af_witch_broom:RequestMagicBoost",token)
end,false)

RegisterCommand("-witchBroomBoost",function()
end,false)

RegisterKeyMapping("+witchBroomBoost","Impulso magico da vassoura","keyboard",Config.Boost.Key or "X")

RegisterNetEvent("af_witch_broom:Deactivate",function()
	cleanupLocal()
end)

RegisterNetEvent("af_witch_broom:BeginLanding",function(reason)
	if not active then
		return
	end

	local distance,hasGround = groundDistance(proxyVehicle)
	local speed = DoesEntityExist(proxyVehicle) and GetEntitySpeed(proxyVehicle) or 999.0
	if hasGround and distance <= Config.Landing.MaximumDismountHeight and speed <= Config.Landing.MaximumDismountSpeed then
		TriggerServerEvent("af_witch_broom:Dismiss",token)
		return
	end

	landingRequested = true
	if reason == "restricted_zone" then
		notify("Area restrita: desca com os controles nativos para a vassoura ser guardada.","amarelo")
	else
		notify("Desca com NumPad 5 e pressione F perto do chao.","amarelo")
	end
end)

RegisterNetEvent("af_witch_broom:PlayFx",function(kind,coords)
	playFx(kind,coords)
end)

CreateThread(function()
	while true do
		local wait = 1000
		for _,vehicle in ipairs(GetGamePool("CVehicle")) do
			if DoesEntityExist(vehicle) then
				local state = Entity(vehicle).state
				if state["af:broomProxy"] == true and (state["af:broomActive"] == true or state["af:broomPreparing"] == true) then
					wait = 250
					ensureVisual(vehicle)
				elseif state["af:broomVisual"] == true then
					configureVisual(vehicle)
				end
			end
		end

		for entity in pairs(localVisuals) do
			if not DoesEntityExist(entity) or (Entity(entity).state["af:broomActive"] ~= true and Entity(entity).state["af:broomPreparing"] ~= true) then
				removeVisualRecord(entity)
			end
		end

		Wait(wait)
	end
end)

CreateThread(function()
	while true do
		local hasProxy = false
		for proxy in pairs(knownProxies) do
			if DoesEntityExist(proxy) and Entity(proxy).state["af:broomProxy"] == true then
				hasProxy = true
				SetEntityVisible(proxy,false,false)
				SetEntityAlpha(proxy,0,false)
				SetVehicleRadioEnabled(proxy,false)
			else
				knownProxies[proxy] = nil
			end
		end
		Wait(hasProxy and 0 or 500)
	end
end)

if AddStateBagChangeHandler and GetEntityFromStateBagName then
	local function reconcileBag(bagName)
		CreateThread(function()
			Wait(50)
			local entity = GetEntityFromStateBagName(bagName)
			if entity and entity ~= 0 then
				reconcileEntity(entity)
			end
		end)
	end

	AddStateBagChangeHandler("af:broomActive",nil,function(bagName)
		reconcileBag(bagName)
	end)
	AddStateBagChangeHandler("af:broomPreparing",nil,function(bagName)
		reconcileBag(bagName)
	end)
	AddStateBagChangeHandler("af:broomVisualNet",nil,function(bagName)
		reconcileBag(bagName)
	end)
	AddStateBagChangeHandler("af:broomBoosting",nil,function(bagName)
		reconcileBag(bagName)
	end)
end

CreateThread(function()
	while true do
		if not active then
			Wait(500)
		else
			Wait(0)
			local ped = PlayerPedId()
			if not proxyVehicle or not DoesEntityExist(proxyVehicle) or not visualVehicle or not DoesEntityExist(visualVehicle) then
				TriggerServerEvent("af_witch_broom:ClientFailed",token,"entity_lost")
				cleanupLocal()
			else
				configureProxy(proxyVehicle)
				attachVisual(proxyVehicle,visualVehicle,false)

				DisableControlAction(0,Config.Controls.Land,true)
				DisableControlAction(0,24,true)
				DisableControlAction(0,25,true)
				DisableControlAction(0,37,true)
				if Config.Restrictions.DisableWeaponsWhileMounted == true then
					DisablePlayerFiring(ped,true)
					SetCurrentPedWeapon(ped,GetHashKey("WEAPON_UNARMED"),true)
				end

				if GetPedInVehicleSeat(proxyVehicle,-1) ~= ped then
					TriggerServerEvent("af_witch_broom:ClientFailed",token,"invalid_driver")
					cleanupLocal()
				else
					local now = GetGameTimer()
					local distanceToGround,hasGround = groundDistance(proxyVehicle)
					local speed = GetEntitySpeed(proxyVehicle)
					local magicalBoost = isBoosting()
					stabilizeGroundedProxy(proxyVehicle,distanceToGround or 999.0,hasGround,speed,now)

					if IsDisabledControlJustPressed(0,Config.Controls.Land) then
						if hasGround and distanceToGround <= Config.Landing.MaximumDismountHeight and speed <= Config.Landing.MaximumDismountSpeed then
							TriggerServerEvent("af_witch_broom:Dismiss",token)
						elseif not landingRequested then
							landingRequested = true
							notify("Desca com NumPad 5 e pressione F perto do chao.","amarelo")
						end
					end

					if landingRequested and hasGround and distanceToGround <= Config.Landing.MaximumDismountHeight and speed <= Config.Landing.MaximumDismountSpeed then
						TriggerServerEvent("af_witch_broom:Dismiss",token)
					end

					if now >= nextHeartbeat then
						nextHeartbeat = now + math.max(500,Config.Security.HeartbeatInterval)
						TriggerServerEvent("af_witch_broom:Heartbeat",token)
					end

					if Config.Hud.Enabled and now >= nextHudUpdate then
						nextHudUpdate = now + math.max(50,Config.Hud.UpdateInterval)
						SendNUIMessage({
							action = "update",
							speed = math.floor(speed * 3.6 + 0.5),
							altitude = math.floor((distanceToGround or math.max(0.0,GetEntityCoords(proxyVehicle).z - originZ)) + 0.5),
							hover = true,
							landing = landingRequested,
							boost = magicalBoost,
							boostReady = boostCooldownRemaining() <= 0,
							boostCooldown = boostCooldownRemaining()
						})
					end
				end
			end
		end
	end
end)

local function removeDebugVehicle()
	if not debugVehicle or not DoesEntityExist(debugVehicle) then
		debugVehicle = nil
		return
	end

	requestControl(debugVehicle,1000)
	SetEntityAsMissionEntity(debugVehicle,true,true)
	DeleteEntity(debugVehicle)
	debugVehicle = nil
end

local function printProxySnapshot()
	local proxy = proxyVehicle
	local visual = visualVehicle
	if not proxy or not DoesEntityExist(proxy) then
		print("[af_witch_broom/proxy] active=false proxy=none")
		notify("Diagnostico enviado ao F8: nenhuma vassoura ativa.","amarelo")
		return
	end

	local proxyState = Entity(proxy).state
	local visualState = visual and DoesEntityExist(visual) and Entity(visual).state or {}
	print(("[af_witch_broom/proxy] active=%s entity=%s model=%s network=%s visible=%s alpha=%s localInvisible=not_required control=%s driver=%s playerPed=%s nativeControls=true customPhysics=false boostActive=%s boostCooldown=%sms maxSpeed=%s safezone=%s safezoneAllowed=%s owner=%s visualNetState=%s"):format(
		tostring(active),tostring(proxy),tostring(GetEntityModel(proxy)),tostring(getNetworkIdIfNetworked(proxy)),
		tostring(IsEntityVisible(proxy)),tostring(GetEntityAlpha(proxy)),tostring(NetworkHasControlOfEntity(proxy)),
		tostring(GetPedInVehicleSeat(proxy,-1)),tostring(PlayerPedId()),tostring(isBoosting()),tostring(math.ceil(boostCooldownRemaining())),
		tostring(Config.Boost.MaximumSpeed),tostring(LocalPlayer.state.Safezone == true),tostring(Config.Restrictions.AllowInSafeZones == true),
		tostring(proxyState["af:broomOwner"]),tostring(proxyState["af:broomVisualNet"])
	))
	print(("[af_witch_broom/visual] entity=%s model=%s network=%s visible=%s attached=%s parent=%s owner=%s physicsNetState=%s collisionConfigured=%s offset=%.3f,%.3f,%.3f rotation=%.3f,%.3f,%.3f hud=%s left=%s top=%s"):format(
		tostring(visual),tostring(visual and GetEntityModel(visual)),tostring(getNetworkIdIfNetworked(visual)),
		tostring(visual and IsEntityVisible(visual)),tostring(visual and IsEntityAttached(visual)),
		tostring(visual and GetEntityAttachedTo(visual)),tostring(visualState["af:broomOwner"]),
		tostring(visualState["af:broomPhysicsNet"]),tostring(Config.ProxyVisual.VisualCollision == true),
		runtimeOffset.x,runtimeOffset.y,runtimeOffset.z,runtimeRotation.x,runtimeRotation.y,runtimeRotation.z,
		tostring(Config.Hud.Anchor),tostring(runtimeHud.left),tostring(runtimeHud.top)
	))
	notify("Diagnostico proxy/Nimbus enviado ao console F8.","verde")
end

local function spawnDebugModel()
	removeDebugVehicle()
	local hash = loadModel(Config.BroomModel,tonumber(Config.Spawn.ModelLoadTimeout) or 8000)
	if not hash then
		notify("O modelo configurado da Nimbus nao foi encontrado.","vermelho")
		return
	end

	local ped = PlayerPedId()
	local coords = GetEntityCoords(ped)
	local forward = GetEntityForwardVector(ped)
	debugVehicle = CreateVehicle(hash,coords.x + forward.x * 3.0,coords.y + forward.y * 3.0,coords.z + 0.5,GetEntityHeading(ped),false,false)
	if debugVehicle and debugVehicle ~= 0 then
		SetEntityAsMissionEntity(debugVehicle,true,true)
		SetVehicleOnGroundProperly(debugVehicle)
		SetVehicleDoorsLocked(debugVehicle,1)
		notify("Modelo local da Nimbus criado para diagnostico.","verde")
	else
		debugVehicle = nil
		notify("Falha ao criar o modelo local da Nimbus.","vermelho")
	end
	SetModelAsNoLongerNeeded(hash)
end

local function spawnProxyLocalTest()
	if active then
		notify("Guarde a vassoura antes de testar o proxy de pose.","amarelo")
		return
	end

	removeDebugVehicle()
	local modelName = Config.Proxy and Config.Proxy.PoseTestModel or "of_broom_proxy"
	local requestedHash = GetHashKey(modelName)
	local modelDiagnostic = printProxyModelDiagnostic(requestedHash)
	if not modelDiagnostic.inCdImage or not modelDiagnostic.valid or not modelDiagnostic.isVehicle or modelDiagnostic.seats < 1 then
		notify("O proxy nao possui um assento valido. Consulte o diagnostico no F8.","vermelho")
		return
	end
	if not ensureProxyTestDecorator() then
		print("[BROOM PROXY LOCAL] decorator=AF_BROOM_PROXY_TEST unavailable")
		notify("A protecao do teste local nao foi registrada. Reinicie vrp e af_witch_broom.","vermelho")
		return
	end

	local hash = loadModel(modelName,tonumber(Config.Spawn.ModelLoadTimeout) or 8000)
	if not hash then
		notify("O modelo of_broom_proxy nao esta carregado. Confirme o resource [vehicles].","vermelho")
		return
	end

	local ped = PlayerPedId()
	local coords = GetOffsetFromEntityInWorldCoords(ped,0.0,3.0,0.0)
	debugVehicle = CreateVehicle(hash,coords.x,coords.y,coords.z,GetEntityHeading(ped),false,false)
	if not debugVehicle or debugVehicle == 0 then
		debugVehicle = nil
		SetModelAsNoLongerNeeded(hash)
		notify("Falha ao criar o proxy de pose.","vermelho")
		return
	end

	DecorSetBool(debugVehicle,"AF_BROOM_PROXY_TEST",true)
	Wait(0)
	if not DoesEntityExist(debugVehicle) then
		printProxyVehicleDiagnostic("LOCAL_CREATED",debugVehicle,hash,"create_failed",false)
		debugVehicle = nil
		SetModelAsNoLongerNeeded(hash)
		notify("O proxy local foi removido antes da preparacao.","vermelho")
		return
	end

	local collisionLoaded = prepareProxyTestVehicle(debugVehicle,coords)
	Wait(250)
	printProxyVehicleDiagnostic("LOCAL_PRE",debugVehicle,hash,"none",collisionLoaded)
	local mounted,reason = mountProxyTest(debugVehicle)
	printProxyVehicleDiagnostic("LOCAL_POST",debugVehicle,hash,reason,collisionLoaded)
	if not mounted then
		notify(("O proxy local nao montou: %s. Diagnostico completo no F8; sera limpo em 15 segundos."):format(tostring(reason)),"vermelho")
		local failedVehicle = debugVehicle
		CreateThread(function()
			Wait(15000)
			if debugVehicle == failedVehicle and DoesEntityExist(failedVehicle) and GetPedInVehicleSeat(failedVehicle,-1) ~= PlayerPedId() then
				removeDebugVehicle()
			end
		end)
	else
		notify(("Proxy local montado por %s. Teste a postura e os controles nativos."):format(reason),"verde")
	end

	SetModelAsNoLongerNeeded(hash)
end

local function spawnProxyPoseTest()
	spawnProxyLocalTest()
end

local function updateCalibration(kind,args)
	local x,y,z = tonumber(args[1]),tonumber(args[2]),tonumber(args[3])
	if not x or not y or not z then
		notify(("Use /%s x y z"):format(kind == "offset" and Config.DebugCommands.Offset or Config.DebugCommands.Rotation),"amarelo")
		return
	end

	local target = kind == "offset" and runtimeOffset or runtimeRotation
	target.x,target.y,target.z = x,y,z
	if proxyVehicle and visualVehicle then
		attachVisual(proxyVehicle,visualVehicle,true)
	end
	print(("[af_witch_broom/calibration] %s=vector3(%.3f,%.3f,%.3f)"):format(kind,x,y,z))
	notify("Calibracao visual aplicada nesta sessao.","verde")
end

if Config.Debug then
	RegisterNetEvent("af_witch_broom:DebugAction",function(action,args)
		args = type(args) == "table" and args or {}
		if action == "status" or action == "proxy" or action == "visual" then
			printProxySnapshot()
		elseif action == "spawn" then
			spawnDebugModel()
		elseif action == "proxy_pose_test" or action == "proxy_local_test" then
			spawnProxyPoseTest()
		elseif action == "proxy_diag" then
			local hash = GetHashKey(Config.Proxy and Config.Proxy.PoseTestModel or "of_broom_proxy")
			local modelDiagnostic = printProxyModelDiagnostic(hash)
			if debugVehicle and DoesEntityExist(debugVehicle) then
				printProxyVehicleDiagnostic("CURRENT",debugVehicle,hash,"none",HasCollisionLoadedAroundEntity(debugVehicle))
			end
			notify(modelDiagnostic.seats >= 1 and "Diagnostico do proxy enviado ao F8." or "Proxy sem assento valido; consulte o F8.",modelDiagnostic.seats >= 1 and "verde" or "vermelho")
		elseif action == "mount" or action == "remount" then
			local vehicle = proxyVehicle and DoesEntityExist(proxyVehicle) and proxyVehicle or debugVehicle
			local mounted,reason = mountBroom(vehicle)
			notify(mounted and "Teste de montagem concluido." or ("Montagem falhou: %s"):format(tostring(reason)),mounted and "verde" or "vermelho")
		elseif action == "cleanup" then
			removeDebugVehicle()
			cleanupLocal()
			notify("Entidades locais da Nimbus foram limpas.","verde")
		elseif action == "offset" or action == "rotation" then
			updateCalibration(action,args)
		elseif action == "offset_debug" then
			printProxySnapshot()
		elseif action == "hud_position" then
			local x,y = tonumber(args[1]),tonumber(args[2])
			if not x or not y then
				notify(("Use /%s X Y"):format(Config.DebugCommands.HudPosition),"amarelo")
				return
			end
			runtimeHud.left = math.max(0,x)
			runtimeHud.top = math.max(0,y)
			if active then
				setHudVisible(true)
			end
			print(("[af_witch_broom/calibration] Config.Hud.LeftOffset = %d Config.Hud.TopOffset = %d"):format(runtimeHud.left,runtimeHud.top))
			notify("Posicao do HUD aplicada nesta sessao.","verde")
		elseif action == "save_offset" then
			print(("[af_witch_broom/calibration] Config.ProxyVisual.Offset = vector3(%.3f,%.3f,%.3f)"):format(runtimeOffset.x,runtimeOffset.y,runtimeOffset.z))
			print(("[af_witch_broom/calibration] Config.ProxyVisual.Rotation = vector3(%.3f,%.3f,%.3f)"):format(runtimeRotation.x,runtimeRotation.y,runtimeRotation.z))
			print(("[af_witch_broom/calibration] Config.Hud.LeftOffset = %d Config.Hud.TopOffset = %d"):format(runtimeHud.left,runtimeHud.top))
			notify("Valores finais enviados ao F8 para salvar na config.","verde")
		end
	end)
end

RegisterNetEvent("af_witch_broom:ProxyNetworkSpawn",function(payload)
	if type(payload) ~= "table" or not payload.networkId or not payload.token then
		return
	end

	if active then
		TriggerServerEvent("af_witch_broom:ProxyNetworkResult",payload.token,false,"active_broom")
		return
	end

	removeDebugVehicle()
	local modelName = Config.Proxy and Config.Proxy.PoseTestModel or "of_broom_proxy"
	local hash = GetHashKey(modelName)
	local modelDiagnostic = printProxyModelDiagnostic(hash)
	if not modelDiagnostic.inCdImage or not modelDiagnostic.valid or not modelDiagnostic.isVehicle or modelDiagnostic.seats < 1 then
		TriggerServerEvent("af_witch_broom:ProxyNetworkResult",payload.token,false,"invalid_model")
		return
	end

	local timeout = GetGameTimer() + 5000
	local vehicle = 0
	while GetGameTimer() < timeout do
		if NetworkDoesEntityExistWithNetworkId(payload.networkId) then
			vehicle = NetToVeh(payload.networkId)
			if vehicle ~= 0 and DoesEntityExist(vehicle) then
				break
			end
		end
		Wait(50)
	end

	if vehicle == 0 or not DoesEntityExist(vehicle) then
		print(("[BROOM PROXY NETWORK] network=%s entity_missing_after_ms=5000"):format(tostring(payload.networkId)))
		TriggerServerEvent("af_witch_broom:ProxyNetworkResult",payload.token,false,"entity_timeout")
		return
	end

	local controlTimeout = GetGameTimer() + 2500
	while not NetworkHasControlOfEntity(vehicle) and GetGameTimer() < controlTimeout do
		NetworkRequestControlOfEntity(vehicle)
		Wait(50)
	end

	if not NetworkHasControlOfEntity(vehicle) then
		print(("[BROOM PROXY NETWORK] network=%s control=false"):format(tostring(payload.networkId)))
		TriggerServerEvent("af_witch_broom:ProxyNetworkResult",payload.token,false,"control_timeout")
		return
	end

	debugVehicle = vehicle
	local coords = GetEntityCoords(vehicle)
	local collisionLoaded = prepareProxyTestVehicle(vehicle,coords)
	Wait(250)
	printProxyVehicleDiagnostic("NETWORK_PRE",vehicle,hash,"none",collisionLoaded)
	local mounted,reason = mountProxyTest(vehicle)
	printProxyVehicleDiagnostic("NETWORK_POST",vehicle,hash,reason,collisionLoaded)
	TriggerServerEvent("af_witch_broom:ProxyNetworkResult",payload.token,mounted,reason)

	if mounted then
		notify(("Proxy networkado montado por %s. Teste os controles e use /vassoura_cleanup ao terminar."):format(reason),"verde")
	else
		notify(("Proxy networkado nao montou: %s. Diagnostico enviado ao F8."):format(reason),"vermelho")
	end
end)

RegisterNetEvent("af_witch_broom:ProxyNetworkRemoved",function(networkId)
	if debugVehicle and getNetworkIdIfNetworked(debugVehicle) == networkId then
		debugVehicle = nil
	end
end)

AddEventHandler("onClientResourceStart",function(resource)
	if resource == GetCurrentResourceName() then
		setBroomMode(false)
		Wait(1500)
		TriggerServerEvent("af_witch_broom:RequestAccess")
	end
end)

AddEventHandler("onClientResourceStop",function(resource)
	if resource ~= GetCurrentResourceName() then
		return
	end

	if active and token then
		TriggerServerEvent("af_witch_broom:ClientFailed",token,"client_resource_stop")
	elseif pendingActivation and pendingActivation.token then
		TriggerServerEvent("af_witch_broom:ClientFailed",pendingActivation.token,"client_resource_stop")
	end

	for entity in pairs(localVisuals) do
		removeVisualRecord(entity)
	end
	removeDebugVehicle()
	releasePreparedModels()
	LocalPlayer.state:set("WitchBroom",false,true)
	LocalPlayer.state:set("af:broomMode",false,false)
	setHudVisible(false)
end)
