local function ownerProtectionDenied(executorSource,targetSource,action)
	if GetResourceState("af_owner_panel") ~= "started" then
		return false
	end

	local ok,protected = pcall(function()
		return exports.af_owner_panel:IsOwnerProtected(targetSource)
	end)
	if not ok or protected ~= true then
		return false
	end

	local reported,result = pcall(function()
		return exports.af_owner_panel:ReportProtectionBlock(executorSource,targetSource,action)
	end)
	if not reported or result ~= true then
		TriggerClientEvent("Notify",executorSource,"Protecao","O Dono esta com protecao preventiva ativa.","vermelho",5000)
		TriggerClientEvent("Notify",targetSource,"Protecao","Uma restricao hostil foi bloqueada.","amarelo",5000)
		print(("[inventory] owner_protection_fallback timestamp=%s executor=%s target=%s action=%s"):format(os.date("!%Y-%m-%dT%H:%M:%SZ"),tostring(executorSource),tostring(targetSource),tostring(action)))
	end
	return true
end

local function validCarryPair(carrierSource,targetSource)
	carrierSource = tonumber(carrierSource)
	targetSource = tonumber(targetSource)
	if not carrierSource or carrierSource <= 0 or not targetSource or targetSource <= 0 or carrierSource == targetSource then
		return false
	end

	if not vRP.DoesEntityExist(carrierSource) or not vRP.DoesEntityExist(targetSource) then
		return false
	end

	return #(vRP.GetEntityCoords(carrierSource) - vRP.GetEntityCoords(targetSource)) <= 2.0
end

local function isCarryTarget(targetSource)
	for _,currentTarget in pairs(Carry) do
		if tonumber(currentTarget) == tonumber(targetSource) then
			return true
		end
	end

	return false
end

local function detachCarrier(carrierSource,carrierPassport)
	carrierSource = tonumber(carrierSource)
	carrierPassport = tonumber(carrierPassport)
	if not carrierSource or not carrierPassport or tonumber(vRP.Passport(carrierSource)) ~= carrierPassport then
		return false
	end

	local targetSource = Carry[carrierPassport]
	if not targetSource then
		return false
	end

	if vRP.DoesEntityExist(targetSource) then
		TriggerClientEvent("inventory:Carry",targetSource,carrierSource,"Detach")
		Player(targetSource).state.Carry = false
	end

	if vRP.DoesEntityExist(carrierSource) then
		Player(carrierSource).state.Carry = false
	end

	Carry[carrierPassport] = nil
	return true
end

local function attachCarrier(carrierSource,carrierPassport,targetSource,handcuff)
	carrierSource = tonumber(carrierSource)
	carrierPassport = tonumber(carrierPassport)
	targetSource = tonumber(targetSource)
	if not carrierSource or not carrierPassport or tonumber(vRP.Passport(carrierSource)) ~= carrierPassport or not validCarryPair(carrierSource,targetSource) then
		return false
	end

	local targetPassport = vRP.Passport(targetSource)
	if not targetPassport or Carry[carrierPassport] or Carry[targetPassport] or isCarryTarget(carrierSource) or isCarryTarget(targetSource) then
		return false
	end

	if ownerProtectionDenied(carrierSource,targetSource,"carry") then
		return false
	end

	Carry[carrierPassport] = targetSource
	Player(carrierSource).state.Carry = true
	Player(targetSource).state.Carry = true
	TriggerClientEvent("inventory:Carry",targetSource,carrierSource,"Attach",handcuff == true)
	return true
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- INVENTORY:CARRY
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("inventory:Carry")
AddEventHandler("inventory:Carry",function()
	local source = tonumber(source)
	local Passport = source and vRP.Passport(source) or nil
	if not source or not Passport or not vRP.DoesEntityExist(source) then
		return false
	end

	if Carry[Passport] then
		return detachCarrier(source,Passport)
	end

	local OtherSource = vRPC.ClosestPed(source)
	if not OtherSource or not validCarryPair(source,OtherSource) then
		return false
	end

	if vRPC.PlayingAnim(OtherSource,"amb@world_human_sunbathe@female@back@idle_a","idle_a") or vRP.IsEntityVisible(OtherSource) then
		return false
	end

	return attachCarrier(source,Passport,OtherSource,false)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- INVENTORY:SERVERCARRY (SERVER-ONLY CONTRACT)
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("inventory:ServerCarry",function(carrierSource,carrierPassport,targetSource,handcuff)
	carrierSource = tonumber(carrierSource)
	carrierPassport = tonumber(carrierPassport)
	if not carrierSource or not carrierPassport or tonumber(vRP.Passport(carrierSource)) ~= carrierPassport then
		return false
	end

	if Carry[carrierPassport] then
		return detachCarrier(carrierSource,carrierPassport)
	end

	return attachCarrier(carrierSource,carrierPassport,targetSource,handcuff)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- INVENTORY:CARRYDETACH (SERVER-ONLY CONTRACT)
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("inventory:CarryDetach",function(carrierSource,carrierPassport)
	carrierSource = tonumber(carrierSource)
	carrierPassport = tonumber(carrierPassport)
	if not carrierSource or not carrierPassport or tonumber(vRP.Passport(carrierSource)) ~= carrierPassport then
		return false
	end

	return detachCarrier(carrierSource,carrierPassport)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- FORCERELEASEOWNER
-----------------------------------------------------------------------------------------------------------------------------------------
exports("ForceReleaseOwner",function(targetSource)
	if GetInvokingResource() ~= "af_owner_panel" then
		return { success = false }
	end

	targetSource = tonumber(targetSource)
	local targetPassport = targetSource and vRP.Passport(targetSource) or nil
	if not targetSource or tonumber(targetPassport) ~= 1 or not vRP.DoesEntityExist(targetSource) then
		return { success = false }
	end

	local result = {
		success = true,
		handcuff = false,
		carryTarget = false,
		carryCarrier = false,
		carryStale = false,
		commandsOwned = false
	}
	local targetState = Player(targetSource).state

	if targetState.Handcuff == true then
		targetState.Handcuff = false
		result.handcuff = true
		result.commandsOwned = true
		TriggerClientEvent("sounds:Private",targetSource,"uncuff",0.5)
	end

	if Carry[targetPassport] then
		result.carryCarrier = detachCarrier(targetSource,targetPassport)
	end

	local carrierRelations = {}
	for carrierPassport,currentTarget in pairs(Carry) do
		if tonumber(currentTarget) == targetSource then
			carrierRelations[#carrierRelations + 1] = tonumber(carrierPassport)
		end
	end

	for _,carrierPassport in ipairs(carrierRelations) do
		local carrierSource = vRP.Source(carrierPassport)
		if carrierSource and detachCarrier(carrierSource,carrierPassport) then
			result.carryTarget = true
		else
			Carry[carrierPassport] = nil
			targetState.Carry = false
			TriggerClientEvent("inventory:Carry",targetSource,nil,"Detach")
			result.carryTarget = true
		end
	end

	if targetState.Carry == true then
		targetState.Carry = false
		TriggerClientEvent("inventory:Carry",targetSource,nil,"Detach")
		result.carryStale = true
	end

	if result.handcuff or result.carryTarget or result.carryCarrier or result.carryStale then
		vRPC.Destroy(targetSource)
	end

	return result
end)
