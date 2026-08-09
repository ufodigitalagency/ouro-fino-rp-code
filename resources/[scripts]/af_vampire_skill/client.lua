local Proxy = module("vrp","lib/Proxy")
local vRP = Proxy.getInterface("vRP")

local vampireAccess = false
local vampireMode = false
local draining = false
local victimEffect = false
local deathReported = false
local superJumpCharges = Config.SuperJumpCharges
local superJumpRechargeAt = 0
local jumpBoostArmed = true
local jumpBoostPendingUntil = 0
local jumpLastBoostAt = 0
local jumpWasAirborne = false
local fallProtectionActive = false
local fallProtectionPed = 0
local fallLandingGraceUntil = 0
local testNpc = 0
local pendingLocalNpc = 0
local pendingNpcMadeMission = false
local pendingNpcVehicle = 0
local pendingNpcVehicleLock = nil
local localNpcTarget = 0
local localNpcOperation = 0
local localNpcMadeMission = false
local networkNpcTarget = 0
local networkNpcMadeMission = false
local npcPreparationActive = false
local drainAttached = false
local umbrellaActive = false
local sunlightBurning = false
local sunlightProtected = false
local sunlightLastDamage = 0
local sunlightSmokeFx = nil
local sunlightSparksFx = nil
local sunlightFxPed = 0
local sunlightLastVisualPulse = 0
local sunlightLastRedFlash = 0
local replicatedSunlightSent = false
local remoteVampireFx = {}
local desiredRemoteVampireFx = {}
local multiplayerDiagnosticsActive = false
local diagnosticFxHandle = nil
local clearSunlightEffects
local closeUmbrella
local clearFallProtection
local resetVampireJumpState
local clearLocalNpcTarget
local clearNetworkNpcTarget
local clearPendingNpc

local function notify(message,color)
	TriggerEvent("Notify","Vampiro",message,color or "amarelo",5000)
end

local function debugLog(message)
	if Config.Debug then
		print(("[af_vampire_skill] %s"):format(message))
	end
end

local function multiplayerLog(message)
	if Config.MultiplayerDebug or multiplayerDiagnosticsActive then
		print(("[vampire/multiplayer] %s"):format(message))
	end
end

local function setReplicatedSunlightBurning(state)
	state = state == true
	if replicatedSunlightSent == state then
		return
	end

	replicatedSunlightSent = state
	TriggerServerEvent("af_vampire_skill:SetSunlightBurning",state)
end

local function updateHud()
	TriggerEvent("hud:Vampire",{
		Visible = vampireAccess,
		Active = vampireMode,
		Burning = sunlightBurning,
		Charges = superJumpCharges,
		Maximum = Config.SuperJumpCharges,
		RechargeRemaining = math.max(0,superJumpRechargeAt - GetGameTimer()),
		RechargeDuration = Config.SuperJumpRechargeSeconds * 1000
	})
end

local function requestAnim(dict)
	RequestAnimDict(dict)
	local timeout = GetGameTimer() + 3000
	while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
		Wait(10)
	end

	return HasAnimDictLoaded(dict)
end

local function resetPlayerState()
	local ped = PlayerPedId()
	draining = false
	victimEffect = false
	if clearSunlightEffects then
		clearSunlightEffects()
	end
	if closeUmbrella then
		closeUmbrella(true)
	end
	if resetVampireJumpState then
		resetVampireJumpState()
	end
	if clearFallProtection then
		clearFallProtection("modo vampiro desativado")
	end
	if drainAttached then
		DetachEntity(ped,true,true)
		drainAttached = false
	end
	if clearLocalNpcTarget then
		clearLocalNpcTarget()
	end
	if clearNetworkNpcTarget then
		clearNetworkNpcTarget()
	end
	if clearPendingNpc then
		clearPendingNpc()
	end
	FreezeEntityPosition(ped,false)
	ClearPedTasks(ped)
	StopScreenEffect(Config.Anim.ScreenEffect)
	StopGameplayCamShaking(true)
end

local function setMode(enabled)
	vampireMode = enabled == true and vampireAccess
	SetRunSprintMultiplierForPlayer(PlayerId(),vampireMode and Config.SpeedMultiplier or 1.0)

	if not vampireMode then
		resetPlayerState()
	end

	updateHud()
end

local function deleteTestNpc()
	if testNpc ~= 0 and DoesEntityExist(testNpc) then
		SetEntityAsMissionEntity(testNpc,true,true)
		DeletePed(testNpc)
	end

	testNpc = 0
end

local function requestModel(model)
	local hash = joaat(model)
	if not IsModelInCdimage(hash) or not IsModelValid(hash) then
		return nil
	end

	RequestModel(hash)
	local timeout = GetGameTimer() + 5000
	while not HasModelLoaded(hash) and GetGameTimer() < timeout do
		Wait(10)
	end

	return HasModelLoaded(hash) and hash or nil
end

local function isSunlightHour()
	local hour = GetClockHours()
	if Config.Sunlight.StartHour < Config.Sunlight.EndHour then
		return hour >= Config.Sunlight.StartHour and hour < Config.Sunlight.EndHour
	end

	return hour >= Config.Sunlight.StartHour or hour < Config.Sunlight.EndHour
end

local function isExposedToSun(ped)
	if GetInteriorFromEntity(ped) ~= 0 then
		return false
	end

	local room = GetRoomKeyFromEntity and GetRoomKeyFromEntity(ped) or 0
	if room and room ~= 0 and room ~= -1 then
		return false
	end

	local coords = GetEntityCoords(ped)
	local startZ = coords.z + 0.75
	local ray = StartExpensiveSynchronousShapeTestLosProbe(coords.x,coords.y,startZ,coords.x,coords.y,startZ + 120.0,-1,ped,4)
	local _,hit = GetShapeTestResult(ray)

	return hit == 0 or hit == false
end

clearSunlightEffects = function()
	local ped = PlayerPedId()
	if ped ~= 0 and DoesEntityExist(ped) then
		-- Native entity fire has its own GTA damage loop. Sunlight damage is
		-- applied manually below, so always extinguish the native fire state.
		StopEntityFire(ped)
	end

	if sunlightSmokeFx then
		StopParticleFxLooped(sunlightSmokeFx,false)
		sunlightSmokeFx = nil
	end

	if sunlightSparksFx then
		StopParticleFxLooped(sunlightSparksFx,false)
		sunlightSparksFx = nil
	end

	StopScreenEffect("HeistCooldown")
	setReplicatedSunlightBurning(false)
	sunlightFxPed = 0
	sunlightBurning = false
	sunlightProtected = false
	sunlightLastDamage = 0
	sunlightLastVisualPulse = 0
	sunlightLastRedFlash = 0
	updateHud()
end

closeUmbrella = function(silent)
	local ped = PlayerPedId()
	if umbrellaActive then
		vRP.Destroy()
	end

	umbrellaActive = false
	StopAnimTask(ped,Config.Sunlight.UmbrellaAnimation.Dict,Config.Sunlight.UmbrellaAnimation.Name,1.0)
	if not silent then
		notify("Guarda-chuva fechado.","amarelo")
	end
end

local function umbrellaInHand()
	local ped = PlayerPedId()
	local animation = Config.Sunlight.UmbrellaAnimation

	-- /e chuva cria um objeto de missao. GetClosestObjectOfType com o filtro
	-- antigo podia ignora-lo e fazia a protecao oscilar. A propria animacao e
	-- a fonte confiavel: F6 a encerra e a protecao termina no mesmo instante.
	return IsEntityPlayingAnim(ped,animation.Dict,animation.Name,3)
end

local function openUmbrella()
	local ped = PlayerPedId()
	if IsPedInAnyVehicle(ped,false) or IsPedDeadOrDying(ped,true) then
		notify("Voce nao pode usar o guarda-chuva agora.","amarelo")
		return
	end

	-- Reuse the base /e chuva emote. It already creates and attaches p_amb_brolly_01.
	TriggerEvent("emotes",Config.Sunlight.UmbrellaEmote)
	Wait(650)
	if not umbrellaInHand() then
		notify("Nao foi possivel abrir o guarda-chuva agora.","vermelho")
		return
	end

	umbrellaActive = true
	notify("Guarda-chuva aberto.","verde")
end

local function updateSunlight()
	if not Config.Sunlight.Enabled then
		clearSunlightEffects()
		return
	end

	local ped = PlayerPedId()
	if not vampireMode or IsPedDeadOrDying(ped,true) or IsPedInAnyVehicle(ped,false) or not isSunlightHour() or not isExposedToSun(ped) then
		clearSunlightEffects()
		return
	end

	if sunlightBurning and sunlightFxPed ~= ped then
		clearSunlightEffects()
	end

	if umbrellaInHand() then
		StopEntityFire(ped)
		if sunlightBurning then
			clearSunlightEffects()
		end
		if not sunlightProtected then
			notify("O guarda-chuva bloqueia o sol.","verde")
			sunlightProtected = true
		end
		return
	end

	sunlightProtected = false
	if not sunlightBurning then
		sunlightBurning = true
		sunlightFxPed = ped
		setReplicatedSunlightBurning(true)
		StopEntityFire(ped)
		RequestNamedPtfxAsset(Config.Sunlight.VisualAsset)
		local timeout = GetGameTimer() + 1500
		while not HasNamedPtfxAssetLoaded(Config.Sunlight.VisualAsset) and GetGameTimer() < timeout do
			Wait(0)
		end

		if HasNamedPtfxAssetLoaded(Config.Sunlight.VisualAsset) and Config.Sunlight.VisualSparks then
			-- Efeito looped opcional; por padrao fica desligado para nao poluir a tela.
			UseParticleFxAssetNextCall(Config.Sunlight.VisualAsset)
			sunlightSparksFx = StartParticleFxLoopedOnEntity(Config.Sunlight.VisualSparks,ped,0.0,0.0,0.35,0.0,0.0,0.0,Config.Sunlight.VisualSparkScale,false,false,false)
		end

		if HasNamedPtfxAssetLoaded(Config.Sunlight.VisualAsset) and Config.Sunlight.VisualSmoke then
			UseParticleFxAssetNextCall(Config.Sunlight.VisualAsset)
			sunlightSmokeFx = StartParticleFxLoopedOnEntity(Config.Sunlight.VisualSmoke,ped,0.0,0.0,0.5,0.0,0.0,0.0,Config.Sunlight.VisualSmokeScale,false,false,false)
		end

		-- Particulas sao apenas visuais. A vida e reduzida abaixo de forma controlada.
		local damageInterval = math.max(5000,math.floor(tonumber(Config.Sunlight.DamageInterval) or 5000))
		sunlightLastDamage = GetGameTimer() + damageInterval
		notify("O sol esta queimando seu corpo! Abra um guarda-chuva com /e chuva.","vermelho")
		updateHud()
	end

	local now = GetGameTimer()
	local health = GetEntityHealth(ped)

	-- Mantido apenas para compatibilidade de configuracao. Por padrao fica
	-- desligado porque particulas de chama podem causar dano nativo.
	if Config.Sunlight.VisualFlame and now >= sunlightLastVisualPulse and HasNamedPtfxAssetLoaded(Config.Sunlight.VisualAsset) then
		StopEntityFire(ped)
		UseParticleFxAssetNextCall(Config.Sunlight.VisualAsset)
		StartParticleFxNonLoopedOnEntity(Config.Sunlight.VisualFlame,ped,0.0,0.0,0.35,0.0,0.0,0.0,Config.Sunlight.VisualFlameScale,false,false,false)
		StopEntityFire(ped)
		sunlightLastVisualPulse = now + Config.Sunlight.VisualFlameInterval
	end

	-- Flash vermelho sutil na tela enquanto queimando
	if Config.Sunlight.ScreenRedFlash and now >= sunlightLastRedFlash then
		StartScreenEffect("HeistCooldown",0,false)
		SetTimeout(800,function()
			if not sunlightBurning then
				StopScreenEffect("HeistCooldown")
			end
		end)
		sunlightLastRedFlash = now + Config.Sunlight.ScreenRedInterval
	end

	-- Dano controlado: 1 HP a cada 5 segundos
	if now >= sunlightLastDamage and health > Config.Sunlight.MinimumHealth then
		local damage = math.max(1,math.floor(tonumber(Config.Sunlight.Damage) or 1))
		local damageInterval = math.max(5000,math.floor(tonumber(Config.Sunlight.DamageInterval) or 5000))
		SetEntityHealth(ped,math.max(Config.Sunlight.MinimumHealth,health - damage))
		sunlightLastDamage = now + damageInterval
	end
end

local function stopRemoteVampireFx(serverId)
	local current = remoteVampireFx[serverId]
	if not current then
		return
	end

	if current.handle then
		StopParticleFxLooped(current.handle,false)
	end

	remoteVampireFx[serverId] = nil
	multiplayerLog(("fx-stop observer=%s target=%s"):format(GetPlayerServerId(PlayerId()),serverId))
end

local function loadSunlightParticleAsset()
	local asset = Config.Sunlight.VisualAsset
	if HasNamedPtfxAssetLoaded(asset) then
		return true
	end

	RequestNamedPtfxAsset(asset)
	local timeout = GetGameTimer() + 1500
	while not HasNamedPtfxAssetLoaded(asset) and GetGameTimer() < timeout do
		Wait(10)
	end

	return HasNamedPtfxAssetLoaded(asset)
end

local function startRemoteVampireFx(serverId)
	if serverId == GetPlayerServerId(PlayerId()) or not Config.Sunlight.VisualSmoke then
		return false
	end

	local player = GetPlayerFromServerId(serverId)
	if player == -1 or not NetworkIsPlayerActive(player) then
		stopRemoteVampireFx(serverId)
		return false
	end

	local ped = GetPlayerPed(player)
	if ped == 0 or not DoesEntityExist(ped) then
		stopRemoteVampireFx(serverId)
		return false
	end

	local current = remoteVampireFx[serverId]
	if current and current.ped == ped then
		if not DoesParticleFxLoopedExist or DoesParticleFxLoopedExist(current.handle) then
			return true
		end
	end

	stopRemoteVampireFx(serverId)
	if not loadSunlightParticleAsset() then
		return false
	end

	UseParticleFxAssetNextCall(Config.Sunlight.VisualAsset)
	local handle = StartParticleFxLoopedOnEntity(
		Config.Sunlight.VisualSmoke,
		ped,
		0.0,0.0,0.5,
		0.0,0.0,0.0,
		Config.Sunlight.VisualSmokeScale,
		false,false,false
	)
	if not handle or handle == 0 then
		return false
	end

	remoteVampireFx[serverId] = { handle = handle, ped = ped }
	multiplayerLog(("fx-start observer=%s target=%s"):format(GetPlayerServerId(PlayerId()),serverId))
	return true
end

local function serverIdFromStateBag(bagName)
	if type(bagName) ~= "string" then
		return nil
	end

	return tonumber(bagName:match("^player:(%d+)$"))
end

local function moveCloseToTarget(ped,targetPed)
	local coords = GetOffsetFromEntityInWorldCoords(targetPed,0.0,0.42,0.0)
	SetEntityCoordsNoOffset(ped,coords.x,coords.y,coords.z,false,false,false)
	SetEntityHeading(ped,GetEntityHeading(targetPed) + 180.0)
end

local function playNpcBlood(targetPed)
	RequestNamedPtfxAsset("core")
	local timeout = GetGameTimer() + 1000
	while not HasNamedPtfxAssetLoaded("core") and GetGameTimer() < timeout do
		Wait(0)
	end

	if HasNamedPtfxAssetLoaded("core") then
		UseParticleFxAssetNextCall("core")
		StartParticleFxNonLoopedOnEntity("blood_stab",targetPed,0.0,0.0,0.45,0.0,0.0,0.0,0.7,false,false,false)
	end

	ApplyPedDamagePack(targetPed,"BigHitByVehicle",0.0,1.0)
end

local function disableCombatControls()
	DisableControlAction(0,21,true)
	DisableControlAction(0,22,true)
	DisableControlAction(0,23,true)
	DisableControlAction(0,24,true)
	DisableControlAction(0,25,true)
	DisableControlAction(0,30,true)
	DisableControlAction(0,31,true)
	DisableControlAction(0,37,true)
	DisablePlayerFiring(PlayerId(),true)
end

local function closestPlayer()
	local ped = PlayerPedId()
	local coords = GetEntityCoords(ped)
	local closestSource = nil
	local closestDistance = Config.Range

	for _,player in ipairs(GetActivePlayers()) do
		if player ~= PlayerId() then
			local targetPed = GetPlayerPed(player)
			if DoesEntityExist(targetPed) and not IsPedDeadOrDying(targetPed,true) and not IsPedInAnyVehicle(targetPed,false) then
				local distance = #(coords - GetEntityCoords(targetPed))
				if distance <= closestDistance then
					closestDistance = distance
					closestSource = GetPlayerServerId(player)
				end
			end
		end
	end

	return closestSource
end

local function validNpcCandidate(targetPed,allowVehicle,maxDistance)
	if targetPed == 0 or not DoesEntityExist(targetPed) or GetEntityType(targetPed) ~= 1 then
		return false
	end

	if IsPedAPlayer(targetPed) or not IsPedHuman(targetPed) or IsPedDeadOrDying(targetPed,true) then
		return false
	end

	if not allowVehicle and IsPedInAnyVehicle(targetPed,false) then
		return false
	end

	return #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(targetPed)) <= (maxDistance or Config.NpcSearchRange)
end

local function releaseNpcEntity(targetPed,madeMission)
	if targetPed ~= 0 and DoesEntityExist(targetPed) and madeMission then
		SetBlockingOfNonTemporaryEvents(targetPed,false)
		SetEntityAsNoLongerNeeded(targetPed)
	end
end

local function restorePendingVehicleLock()
	if pendingNpcVehicle ~= 0 and DoesEntityExist(pendingNpcVehicle) and pendingNpcVehicleLock ~= nil then
		SetVehicleDoorsLocked(pendingNpcVehicle,pendingNpcVehicleLock)
	end

	pendingNpcVehicle = 0
	pendingNpcVehicleLock = nil
end

clearPendingNpc = function()
	restorePendingVehicleLock()
	releaseNpcEntity(pendingLocalNpc,pendingNpcMadeMission)
	pendingLocalNpc = 0
	pendingNpcMadeMission = false
	npcPreparationActive = false
end

local function consumePendingNpc(targetPed)
	local matches = pendingLocalNpc == targetPed
	if not matches and pendingLocalNpc ~= 0 and DoesEntityExist(pendingLocalNpc) and DoesEntityExist(targetPed) then
		if NetworkGetEntityIsNetworked(pendingLocalNpc) and NetworkGetEntityIsNetworked(targetPed) then
			matches = NetworkGetNetworkIdFromEntity(pendingLocalNpc) == NetworkGetNetworkIdFromEntity(targetPed)
		end
	end

	if not matches then
		return false
	end

	local madeMission = pendingNpcMadeMission
	restorePendingVehicleLock()
	pendingLocalNpc = 0
	pendingNpcMadeMission = false
	npcPreparationActive = false
	return madeMission
end

local function requestEntityControl(entity,label)
	if entity == 0 or not DoesEntityExist(entity) then
		debugLog(("controle negado (%s): entidade invalida"):format(label))
		return false
	end

	if not NetworkGetEntityIsNetworked(entity) then
		debugLog(("controle obtido (%s): entidade local"):format(label))
		return true
	end

	if NetworkHasControlOfEntity(entity) then
		debugLog(("controle obtido (%s)"):format(label))
		return true
	end

	local timeout = GetGameTimer() + (tonumber(Config.NpcControlTimeout) or 800)
	repeat
		NetworkRequestControlOfEntity(entity)
		Wait(25)
	until NetworkHasControlOfEntity(entity) or GetGameTimer() >= timeout or not DoesEntityExist(entity)

	local controlled = DoesEntityExist(entity) and NetworkHasControlOfEntity(entity)
	debugLog(("controle %s (%s)"):format(controlled and "obtido" or "negado",label))
	return controlled
end

local function ensureNpcNetworked(targetPed)
	if not NetworkGetEntityIsNetworked(targetPed) then
		NetworkRegisterEntityAsNetworked(targetPed)
		local timeout = GetGameTimer() + (tonumber(Config.NpcControlTimeout) or 800)
		while DoesEntityExist(targetPed) and not NetworkGetEntityIsNetworked(targetPed) and GetGameTimer() < timeout do
			Wait(25)
		end
	end

	if not DoesEntityExist(targetPed) or not NetworkGetEntityIsNetworked(targetPed) then
		debugLog("netId negado: NPC permaneceu local")
		return 0
	end

	local netId = NetworkGetNetworkIdFromEntity(targetPed)
	if netId and netId > 0 then
		SetNetworkIdCanMigrate(netId,true)
		debugLog(("netId obtido: %s"):format(netId))
		return netId
	end

	debugLog("netId negado: identificador invalido")
	return 0
end

local function closestNpc()
	local ped = PlayerPedId()
	local coords = GetEntityCoords(ped)
	local closestPed = nil
	local closestDistance = tonumber(Config.NpcSearchRange) or 3.5

	for _,targetPed in ipairs(GetGamePool("CPed")) do
		if targetPed ~= ped and validNpcCandidate(targetPed,true,closestDistance) then
			local distance = #(coords - GetEntityCoords(targetPed))
			if distance <= closestDistance then
				closestDistance = distance
				closestPed = targetPed
			end
		end
	end

	if closestPed then
		debugLog(("NPC encontrado: ped %s, distancia %.2f, em veiculo %s"):format(closestPed,closestDistance,IsPedInAnyVehicle(closestPed,false) and "sim" or "nao"))
	end

	return closestPed
end

local function prepareNpcForDrain(targetPed)
	if npcPreparationActive then
		return
	end

	npcPreparationActive = true
	CreateThread(function()
		if not validNpcCandidate(targetPed,true,Config.NpcSearchRange) then
			debugLog("NPC rejeitado: entidade invalida, morta, animal ou distante")
			npcPreparationActive = false
			notify("Aproxime-se de um NPC humano valido.","amarelo")
			return
		end

		pendingLocalNpc = targetPed
		pendingNpcMadeMission = not IsEntityAMissionEntity(targetPed)
		requestEntityControl(targetPed,"NPC")
		if pendingNpcMadeMission then
			SetEntityAsMissionEntity(targetPed,true,false)
		end
		SetBlockingOfNonTemporaryEvents(targetPed,true)

		if IsPedInAnyVehicle(targetPed,false) then
			local vehicle = GetVehiclePedIsIn(targetPed,false)
			debugLog(("NPC dentro de veiculo: ped %s, veiculo %s"):format(targetPed,vehicle))
			if vehicle == 0 or not DoesEntityExist(vehicle) then
				debugLog("NPC rejeitado: veiculo invalido")
				clearPendingNpc()
				return
			end

			pendingNpcVehicle = vehicle
			pendingNpcVehicleLock = GetVehicleDoorLockStatus(vehicle)
			requestEntityControl(vehicle,"veiculo do NPC")
			SetVehicleDoorsLocked(vehicle,1)
			TaskLeaveVehicle(targetPed,vehicle,0)

			local leaveTimeout = GetGameTimer() + (tonumber(Config.NpcVehicleExitTimeout) or 2500)
			while DoesEntityExist(targetPed) and IsPedInAnyVehicle(targetPed,false) and GetGameTimer() < leaveTimeout do
				Wait(50)
			end
			restorePendingVehicleLock()

			if not DoesEntityExist(targetPed) or IsPedInAnyVehicle(targetPed,false) then
				debugLog("NPC rejeitado: nao conseguiu sair do veiculo")
				notify("Nao foi possivel retirar o NPC do veiculo.","vermelho")
				clearPendingNpc()
				return
			end

			debugLog(("NPC saiu do veiculo: ped %s"):format(targetPed))
		end

		if not validNpcCandidate(targetPed,false,Config.NpcSearchRange) then
			debugLog("NPC rejeitado: indisponivel ou distante apos preparacao")
			notify("O NPC se afastou antes da drenagem.","amarelo")
			clearPendingNpc()
			return
		end

		local netId = ensureNpcNetworked(targetPed)
		if netId > 0 then
			TriggerServerEvent("af_vampire_skill:DrainNpc",netId)
		else
			debugLog("Usando fallback local sem cura: servidor nao pode validar o NPC")
			TriggerServerEvent("af_vampire_skill:DrainLocalNpc")
		end

		SetTimeout(Config.Duration + 2500,function()
			if pendingLocalNpc == targetPed and not draining then
				debugLog("NPC rejeitado: autorizacao do servidor expirou")
				clearPendingNpc()
			end
		end)
	end)
end

local function tryDrain()
	if not vampireMode or draining or victimEffect or npcPreparationActive then
		return
	end

	local ped = PlayerPedId()
	if IsPedInAnyVehicle(ped,false) or IsPedDeadOrDying(ped,true) then
		return
	end

	local targetSource = Config.AllowPlayerDrain and closestPlayer() or nil
	if targetSource then
		TriggerServerEvent("af_vampire_skill:DrainPlayer",targetSource)
		return
	end

	local targetPed = Config.AllowNpcDrain and closestNpc() or nil
	if targetPed then
		prepareNpcForDrain(targetPed)
		return
	end

	debugLog("NPC rejeitado: nenhum humano encontrado no alcance")
	notify("Aproxime-se de um jogador ou NPC valido.","amarelo")
end

local function vampireUnavailable(ped)
	local state = LocalPlayer.state
	return ped == 0
		or not DoesEntityExist(ped)
		or IsPedDeadOrDying(ped,true)
		or GetEntityHealth(ped) <= 100
		or IsPedInAnyVehicle(ped,false)
		or state.Active == false
		or state.Death == true
end

local function jumpAnimationBlocked(ped)
	local state = LocalPlayer.state
	return vampireUnavailable(ped)
		or draining
		or victimEffect
		or not IsPedOnFoot(ped)
		or IsPedRagdoll(ped)
		or IsPedClimbing(ped)
		or IsPedVaulting(ped)
		or IsPedGettingUp(ped)
		or IsPedSwimming(ped)
		or IsPedSwimmingUnderWater(ped)
		or state.Cancel == true
		or state.Carry == true
		or state.Buttons == true
		or state.Commands == true
		or state.Handcuff == true
		or state.Prison == true
end

resetVampireJumpState = function()
	jumpBoostArmed = true
	jumpBoostPendingUntil = 0
	jumpLastBoostAt = 0
	jumpWasAirborne = false
end

local function updateVampireJump()
	local jumpConfig = Config.VampireJump or {}
	if not vampireMode or not Config.EnableSuperJump or jumpConfig.Enabled == false then
		resetVampireJumpState()
		return
	end

	local ped = PlayerPedId()
	if jumpAnimationBlocked(ped) then
		jumpBoostPendingUntil = 0
		if not IsEntityInAir(ped) and not IsPedFalling(ped) then
			jumpBoostArmed = true
			jumpWasAirborne = false
		end
		return
	end

	-- Sem cargas, nem o super pulo nativo nem o impulso vertical sao aplicados.
	-- O personagem continua podendo pular normalmente durante a recarga.
	if superJumpCharges <= 0 then
		jumpBoostPendingUntil = 0
		local inAir = IsEntityInAir(ped) or IsPedFalling(ped)
		jumpBoostArmed = not inAir
		jumpWasAirborne = inAir
		return
	end

	-- O native precisa ser aplicado por frame. O impulso adicional, abaixo,
	-- possui trava propria e acontece somente uma vez por decolagem.
	SetSuperJumpThisFrame(PlayerId())

	local now = GetGameTimer()
	local inAir = IsEntityInAir(ped) or IsPedFalling(ped)

	if not inAir then
		if jumpWasAirborne then
			jumpBoostArmed = true
		end
		jumpWasAirborne = false

		if jumpBoostPendingUntil > 0 and now > jumpBoostPendingUntil then
			jumpBoostPendingUntil = 0
			jumpBoostArmed = true
		end

		local minimumInterval = tonumber(jumpConfig.MinimumInterval) or 350
		if jumpBoostArmed and superJumpCharges > 0 and IsControlJustPressed(0,22) and now - jumpLastBoostAt >= minimumInterval then
			jumpBoostArmed = false
			jumpBoostPendingUntil = now + 500
		end

		return
	end

	jumpWasAirborne = true
	if jumpBoostPendingUntil <= 0 or now > jumpBoostPendingUntil or superJumpCharges <= 0 then
		jumpBoostPendingUntil = 0
		return
	end

	local velocity = GetEntityVelocity(ped)
	if not IsPedJumping(ped) and velocity.z <= 0.0 then
		return
	end

	local verticalBoost = tonumber(jumpConfig.VerticalBoost) or tonumber(Config.SuperJumpVerticalVelocity) or 14.0
	SetEntityVelocity(ped,velocity.x,velocity.y,math.max(velocity.z,verticalBoost))
	jumpBoostPendingUntil = 0
	jumpLastBoostAt = now
	superJumpCharges = math.max(0,superJumpCharges - 1)

	if superJumpCharges <= 0 then
		superJumpRechargeAt = now + (Config.SuperJumpRechargeSeconds * 1000)
	end

	debugLog(("impulso de salto aplicado: boost %.2f, cargas %s/%s"):format(verticalBoost,superJumpCharges,Config.SuperJumpCharges))
	updateHud()
end

local function setCollisionProof(ped,enabled)
	-- A base nao possui outro SetEntityProofs. Somente collisionProof muda;
	-- tiros, fogo, explosoes, melee e afogamento continuam causando dano.
	SetEntityProofs(ped,false,false,false,enabled == true,false,false,false,false)
end

clearFallProtection = function(reason)
	if fallProtectionPed ~= 0 and DoesEntityExist(fallProtectionPed) then
		setCollisionProof(fallProtectionPed,false)
	end

	if fallProtectionActive then
		debugLog(("protecao de queda removida%s"):format(reason and (": " .. reason) or ""))
	end

	fallProtectionActive = false
	fallProtectionPed = 0
	fallLandingGraceUntil = 0
end

local function updateFallProtection()
	local fallConfig = Config.FallProtection or {}
	local ped = PlayerPedId()

	if not vampireMode or fallConfig.Enabled == false or vampireUnavailable(ped) then
		clearFallProtection("jogador indisponivel")
		return
	end

	if fallProtectionPed ~= 0 and fallProtectionPed ~= ped then
		clearFallProtection("ped alterado")
	end

	local now = GetGameTimer()
	local velocity = GetEntityVelocity(ped)
	local height = GetEntityHeightAboveGround(ped)
	local inAir = IsEntityInAir(ped) or IsPedFalling(ped)
	local minimumHeight = tonumber(fallConfig.MinimumHeight) or 2.8
	local minimumVelocity = tonumber(fallConfig.MinimumFallVelocity) or -3.5
	local realFall = inAir and velocity.z <= minimumVelocity and height >= minimumHeight

	if realFall then
		fallLandingGraceUntil = 0
		if not fallProtectionActive then
			fallProtectionActive = true
			fallProtectionPed = ped
			setCollisionProof(ped,true)
			debugLog(("inicio da protecao de queda: altura %.2f, velocidade Z %.2f"):format(height,velocity.z))
		end
		return
	end

	if not fallProtectionActive then
		return
	end

	-- Depois de ativada, a proof permanece durante toda a aproximacao do
	-- solo, inclusive quando a altura ja ficou abaixo do limite inicial.
	if inAir then
		fallLandingGraceUntil = 0
		return
	end

	if fallLandingGraceUntil <= 0 then
		fallLandingGraceUntil = now + (tonumber(fallConfig.LandingGraceMs) or 350)
		debugLog("aterrissagem detectada")
		return
	end

	if now >= fallLandingGraceUntil then
		clearFallProtection("janela de aterrissagem concluida")
	end
end

RegisterCommand(Config.ToggleCommand,function()
	TriggerServerEvent("af_vampire_skill:ToggleMode")
end,false)

RegisterCommand(Config.DrainCommand,function()
	tryDrain()
end,false)

-- Mantidos como no-op para neutralizar binds antigos de H salvos pelo FiveM.
RegisterCommand("+afVampireToggle",function() end,false)
RegisterCommand("-afVampireToggle",function() end,false)

RegisterCommand("+afVampireDrainKey",function()
	tryDrain()
end,false)
RegisterCommand("-afVampireDrainKey",function() end,false)
RegisterKeyMapping("+afVampireDrainKey","Vampiro: sugar sangue","keyboard",Config.DrainKey)

RegisterCommand(Config.TestNpc.SpawnCommand,function()
	if not vampireAccess then
		notify("Voce nao possui a habilidade Vampiro.","vermelho")
		return
	end

	TriggerServerEvent("af_vampire_skill:RequestTestNpc")
end,false)

RegisterCommand(Config.TestNpc.RemoveCommand,function()
	deleteTestNpc()
	notify("NPC de teste removido.","amarelo")
end,false)

RegisterNetEvent("af_vampire_skill:SetAccess",function(allowed)
	vampireAccess = allowed == true
	if not vampireAccess then
		setMode(false)
	else
		updateHud()
	end
end)

RegisterNetEvent("af_vampire_skill:SetMode",function(enabled)
	setMode(enabled)
end)

RegisterNetEvent("af_vampire_skill:ToggleUmbrella",function()
	if umbrellaActive then
		closeUmbrella(false)
	else
		openUmbrella()
	end
end)

RegisterNetEvent("af_vampire_skill:SpawnTestNpc",function()
	local model = requestModel(Config.TestNpc.Model)
	if not model then
		notify("Nao foi possivel carregar o NPC de teste.","vermelho")
		return
	end

	deleteTestNpc()
	local ped = PlayerPedId()
	local coords = GetOffsetFromEntityInWorldCoords(ped,0.0,Config.TestNpc.DistanceAhead,0.0)
	local foundGround,groundZ = GetGroundZFor_3dCoord(coords.x,coords.y,coords.z + 5.0,false)
	if foundGround then
		coords = vector3(coords.x,coords.y,groundZ)
	end

	testNpc = CreatePed(4,model,coords.x,coords.y,coords.z,GetEntityHeading(ped) + 180.0,true,true)
	if testNpc == 0 then
		notify("Nao foi possivel criar o NPC de teste.","vermelho")
		return
	end

	SetEntityAsMissionEntity(testNpc,true,true)
	SetBlockingOfNonTemporaryEvents(testNpc,true)
	SetPedFleeAttributes(testNpc,0,false)
	SetPedCanRagdoll(testNpc,true)
	TaskStandStill(testNpc,-1)
	NetworkRegisterEntityAsNetworked(testNpc)
	local netId = NetworkGetNetworkIdFromEntity(testNpc)
	SetNetworkIdCanMigrate(netId,true)
	SetNetworkIdExistsOnAllMachines(netId,true)
	SetModelAsNoLongerNeeded(model)
	notify(("NPC de teste criado. Ative o modo e use %s perto dele."):format(Config.DrainKey),"verde")
end)

RegisterNetEvent("af_vampire_skill:StartAttacker",function(targetSource,duration)
	local targetPlayer = GetPlayerFromServerId(targetSource)
	local targetPed = targetPlayer ~= -1 and GetPlayerPed(targetPlayer) or 0
	local ped = PlayerPedId()
	if targetPed == 0 then
		return
	end

	draining = true
	moveCloseToTarget(ped,targetPed)
	FreezeEntityPosition(ped,true)
	TaskTurnPedToFaceEntity(ped,targetPed,500)
	if requestAnim(Config.Anim.Dict) then
		TaskPlayAnim(ped,Config.Anim.Dict,Config.Anim.Attacker,8.0,-8.0,duration,49,0.0,false,false,false)
	end
end)

RegisterNetEvent("af_vampire_skill:StartVictim",function(attackerSource,duration)
	local attackerPlayer = GetPlayerFromServerId(attackerSource)
	local attackerPed = attackerPlayer ~= -1 and GetPlayerPed(attackerPlayer) or 0
	local ped = PlayerPedId()
	if attackerPed == 0 then
		return
	end

	victimEffect = true
	FreezeEntityPosition(ped,true)
	TaskTurnPedToFaceEntity(ped,attackerPed,500)
	if requestAnim(Config.Anim.Dict) then
		TaskPlayAnim(ped,Config.Anim.Dict,Config.Anim.Victim,8.0,-8.0,duration,49,0.0,false,false,false)
	end
	StartScreenEffect(Config.Anim.ScreenEffect,0,false)
	ShakeGameplayCam("SMALL_EXPLOSION_SHAKE",0.15)
end)

RegisterNetEvent("af_vampire_skill:StartNpcDrain",function(netId,duration)
	local targetPed = NetworkGetEntityFromNetworkId(netId)
	local ped = PlayerPedId()
	if not validNpcCandidate(targetPed,false,Config.NpcSearchRange) then
		debugLog("NPC rejeitado em StartNpcDrain: entidade indisponivel")
		clearPendingNpc()
		TriggerServerEvent("af_vampire_skill:CancelNpcDrain",netId)
		return
	end

	networkNpcTarget = targetPed
	networkNpcMadeMission = consumePendingNpc(targetPed)
	if not IsEntityAMissionEntity(targetPed) then
		SetEntityAsMissionEntity(targetPed,true,false)
		networkNpcMadeMission = true
	end
	requestEntityControl(targetPed,"NPC autorizado")
	SetBlockingOfNonTemporaryEvents(targetPed,true)

	draining = true
	moveCloseToTarget(ped,targetPed)
	AttachEntityToEntity(ped,targetPed,0,0.0,0.42,0.0,0.0,0.0,180.0,false,false,false,false,2,true)
	drainAttached = true
	FreezeEntityPosition(ped,true)
	TaskTurnPedToFaceEntity(ped,targetPed,500)
	TaskTurnPedToFaceEntity(targetPed,ped,500)
	if requestAnim(Config.Anim.Dict) then
		TaskPlayAnim(ped,Config.Anim.Dict,Config.Anim.Attacker,8.0,-8.0,duration,49,0.0,false,false,false)
	end
	if requestAnim(Config.Anim.NpcVictimDict) then
		TaskPlayAnim(targetPed,Config.Anim.NpcVictimDict,Config.Anim.NpcVictim,8.0,-8.0,duration,49,0.0,false,false,false)
	end
	playNpcBlood(targetPed)
end)

RegisterNetEvent("af_vampire_skill:NpcReaction",function(netId)
	local targetPed = NetworkGetEntityFromNetworkId(netId)
	if targetPed == 0 or not DoesEntityExist(targetPed) then
		return
	end

	if requestAnim(Config.Anim.VictimReactionDict) then
		TaskPlayAnim(targetPed,Config.Anim.VictimReactionDict,Config.Anim.VictimReaction,8.0,-8.0,600,0,0.0,false,false,false)
	end
	playNpcBlood(targetPed)
end)

RegisterNetEvent("af_vampire_skill:ApplyNpcDamage",function(netId,damage)
	local targetPed = NetworkGetEntityFromNetworkId(netId)
	if targetPed == 0 or not DoesEntityExist(targetPed) or IsPedAPlayer(targetPed) or IsPedDeadOrDying(targetPed,true) then
		return
	end

	ApplyDamageToPed(targetPed,tonumber(damage) or 0,false)
end)

local function validLocalNpc(targetPed,maxDistance)
	return validNpcCandidate(targetPed,false,maxDistance or Config.NpcSearchRange)
		and GetEntityHealth(targetPed) > Config.MinimumNpcHealth
end

clearLocalNpcTarget = function()
	releaseNpcEntity(localNpcTarget,localNpcMadeMission)

	localNpcTarget = 0
	localNpcOperation = 0
	localNpcMadeMission = false
end

clearNetworkNpcTarget = function()
	releaseNpcEntity(networkNpcTarget,networkNpcMadeMission)
	networkNpcTarget = 0
	networkNpcMadeMission = false
end

RegisterNetEvent("af_vampire_skill:StartLocalNpcDrain",function(operationId,duration)
	local targetPed = pendingLocalNpc
	if not validLocalNpc(targetPed,Config.NpcSearchRange) then
		clearPendingNpc()
		TriggerServerEvent("af_vampire_skill:CancelLocalNpcDrain",operationId)
		notify("O NPC nao esta mais disponivel para a drenagem.","vermelho")
		return
	end

	localNpcTarget = targetPed
	localNpcOperation = tonumber(operationId) or 0
	localNpcMadeMission = consumePendingNpc(targetPed)
	if not IsEntityAMissionEntity(targetPed) then
		SetEntityAsMissionEntity(targetPed,true,false)
		localNpcMadeMission = true
	end
	SetBlockingOfNonTemporaryEvents(targetPed,true)

	local ped = PlayerPedId()
	draining = true
	moveCloseToTarget(ped,targetPed)
	AttachEntityToEntity(ped,targetPed,0,0.0,0.42,0.0,0.0,0.0,180.0,false,false,false,false,2,true)
	drainAttached = true
	FreezeEntityPosition(ped,true)
	TaskTurnPedToFaceEntity(ped,targetPed,500)
	TaskTurnPedToFaceEntity(targetPed,ped,500)
	TaskStandStill(targetPed,duration + 500)
	if requestAnim(Config.Anim.Dict) then
		TaskPlayAnim(ped,Config.Anim.Dict,Config.Anim.Attacker,8.0,-8.0,duration,49,0.0,false,false,false)
	end
	if requestAnim(Config.Anim.NpcVictimDict) then
		TaskPlayAnim(targetPed,Config.Anim.NpcVictimDict,Config.Anim.NpcVictim,8.0,-8.0,duration,49,0.0,false,false,false)
	end
	playNpcBlood(targetPed)

	SetTimeout(duration,function()
		if localNpcOperation ~= operationId then
			return
		end

		if validLocalNpc(localNpcTarget,Config.FinalRange) then
			TriggerServerEvent("af_vampire_skill:CompleteLocalNpcDrain",operationId)
		else
			TriggerServerEvent("af_vampire_skill:CancelLocalNpcDrain",operationId)
		end
	end)
end)

RegisterNetEvent("af_vampire_skill:ApplyLocalNpcDamage",function(operationId,damage)
	if localNpcOperation ~= operationId or not validLocalNpc(localNpcTarget,Config.FinalRange) then
		return
	end

	if requestAnim(Config.Anim.VictimReactionDict) then
		TaskPlayAnim(localNpcTarget,Config.Anim.VictimReactionDict,Config.Anim.VictimReaction,8.0,-8.0,600,0,0.0,false,false,false)
	end
	playNpcBlood(localNpcTarget)
	ApplyDamageToPed(localNpcTarget,tonumber(damage) or 0,false)
end)

RegisterNetEvent("af_vampire_skill:AbortNpcPreparation",function(reason)
	debugLog(("NPC rejeitado pelo servidor: %s"):format(reason or "motivo desconhecido"))
	clearPendingNpc()
end)

RegisterNetEvent("af_vampire_skill:StopAnimation",function()
	resetPlayerState()
end)

CreateThread(function()
	Wait(1500)
	TriggerServerEvent("af_vampire_skill:RequestAccess")
	updateHud()

	while true do
		local now = GetGameTimer()
		if vampireAccess and superJumpCharges <= 0 and superJumpRechargeAt > 0 and now >= superJumpRechargeAt then
			superJumpCharges = Config.SuperJumpCharges
			superJumpRechargeAt = 0
			updateHud()
			if vampireAccess then
				notify(("Super pulo recarregado: %s/%s cargas disponiveis."):format(superJumpCharges,Config.SuperJumpCharges),"verde")
			end
		end

		if vampireMode then
			local ped = PlayerPedId()
			if IsPedDeadOrDying(ped,true) or GetEntityHealth(ped) <= 100 or LocalPlayer.state.Death == true then
				if not deathReported then
					deathReported = true
					TriggerServerEvent("af_vampire_skill:PlayerUnavailable")
					setMode(false)
				end
			else
				deathReported = false
				updateVampireJump()
				updateFallProtection()
			end
		end

		if draining or victimEffect or vampireMode or vampireAccess then
			if draining or victimEffect then
				disableCombatControls()
			end
			Wait(0)
		else
			Wait(250)
		end
	end
end)

CreateThread(function()
	while true do
		updateSunlight()
		Wait(Config.Sunlight.CheckInterval)
	end
end)

AddStateBagChangeHandler(Config.Sunlight.ReplicatedState,nil,function(bagName,key,value)
	local serverId = serverIdFromStateBag(bagName)
	if not serverId or serverId == GetPlayerServerId(PlayerId()) then
		return
	end

	if value == true then
		desiredRemoteVampireFx[serverId] = true
	else
		desiredRemoteVampireFx[serverId] = nil
		stopRemoteVampireFx(serverId)
	end
end)

CreateThread(function()
	while true do
		local localServerId = GetPlayerServerId(PlayerId())
		for _,player in ipairs(GetActivePlayers()) do
			local serverId = GetPlayerServerId(player)
			if serverId ~= localServerId then
				local success,state = pcall(function()
					return Player(serverId).state[Config.Sunlight.ReplicatedState] == true
				end)

				if success and state then
					desiredRemoteVampireFx[serverId] = true
				elseif success then
					desiredRemoteVampireFx[serverId] = nil
					stopRemoteVampireFx(serverId)
				end
			end
		end

		for serverId in pairs(desiredRemoteVampireFx) do
			startRemoteVampireFx(serverId)
		end

		for serverId,current in pairs(remoteVampireFx) do
			local player = GetPlayerFromServerId(serverId)
			local ped = player ~= -1 and GetPlayerPed(player) or 0
			if not desiredRemoteVampireFx[serverId] or ped == 0 or not DoesEntityExist(ped) or current.ped ~= ped then
				stopRemoteVampireFx(serverId)
			end
		end

		Wait(math.max(500,tonumber(Config.Sunlight.FxReconcileInterval) or 1000))
	end
end)

exports("MultiplayerDiagnosticState",function()
	local active = 0
	local desired = 0
	for _ in pairs(remoteVampireFx) do
		active = active + 1
	end
	for _ in pairs(desiredRemoteVampireFx) do
		desired = desired + 1
	end

	return {
		Burning = sunlightBurning,
		ReplicatedSent = replicatedSunlightSent,
		ActiveRemoteFx = active,
		DesiredRemoteFx = desired,
		LocalHandle = sunlightSmokeFx ~= nil,
		DiagnosticHandle = diagnosticFxHandle ~= nil
	}
end)

RegisterNetEvent("af_vampire_skill:SetMultiplayerDiagnostics",function(enabled)
	multiplayerDiagnosticsActive = enabled == true
end)

RegisterNetEvent("af_vampire_skill:RunFxDiagnostic",function(duration)
	if diagnosticFxHandle then
		StopParticleFxLooped(diagnosticFxHandle,false)
		diagnosticFxHandle = nil
	end

	local target = testNpc ~= 0 and DoesEntityExist(testNpc) and testNpc or PlayerPedId()
	if target == 0 or not DoesEntityExist(target) or not loadSunlightParticleAsset() then
		notify("Falha ao preparar a particula de diagnostico.","vermelho")
		return
	end

	UseParticleFxAssetNextCall(Config.Sunlight.VisualAsset)
	diagnosticFxHandle = StartParticleFxLoopedOnEntity(
		Config.Sunlight.VisualSmoke,target,
		0.0,0.0,0.5,0.0,0.0,0.0,
		Config.Sunlight.VisualSmokeScale,
		false,false,false
	)

	if not diagnosticFxHandle or diagnosticFxHandle == 0 then
		diagnosticFxHandle = nil
		notify("A particula de diagnostico nao foi criada.","vermelho")
		return
	end

	notify("Diagnostico visual ativo por alguns segundos, sem dano.","verde")
	SetTimeout(math.max(1000,tonumber(duration) or 5000),function()
		if diagnosticFxHandle then
			StopParticleFxLooped(diagnosticFxHandle,false)
			diagnosticFxHandle = nil
			notify("Handle de diagnostico removido.","amarelo")
		end
	end)
end)

-- Keep only the visual particles while exposed. A native entity fire can
-- survive resource restarts and continues damaging the player indoors.
CreateThread(function()
	while true do
		if sunlightBurning then
			local ped = PlayerPedId()
			if ped ~= 0 and DoesEntityExist(ped) and IsEntityOnFire(ped) then
				StopEntityFire(ped)
			end
			Wait(0)
		else
			Wait(250)
		end
	end
end)

AddEventHandler("onClientResourceStop",function(resourceName)
	if resourceName == GetCurrentResourceName() then
		deleteTestNpc()
		setMode(false)
		for serverId in pairs(remoteVampireFx) do
			stopRemoteVampireFx(serverId)
		end
		desiredRemoteVampireFx = {}
		if diagnosticFxHandle then
			StopParticleFxLooped(diagnosticFxHandle,false)
			diagnosticFxHandle = nil
		end
	end
end)
