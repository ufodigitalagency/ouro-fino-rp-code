-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")
vRP = Proxy.getInterface("vRP")
-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECTION
-----------------------------------------------------------------------------------------------------------------------------------------
Lil = {}
Tunnel.bindInterface("crafting",Lil)
-----------------------------------------------------------------------------------------------------------------------------------------
-- SAO JUDAS
-----------------------------------------------------------------------------------------------------------------------------------------
local SaoJudasSessions = {}
local SaoJudasPassportSessions = {}
local SaoJudasRateLimits = {}
local SaoJudasPrepared = false
local SaoJudasStarting = 0
local AllowedCancelReasons = {
	client_cancelled = true,
	animation_interrupted = true,
	progress_cancelled = true
}

local function craftingLog(Message)
	print("[saojudas/crafting] "..Message)
end

local function craftingNotify(source,Message,Color)
	TriggerClientEvent("Notify",source,"Bancada de Sao Judas",Message,Color or "amarelo",5000)
end

local function strictInteger(Value)
	local Raw = tostring(Value or "")
	if not Raw:match("^%d+$") then return nil end

	local Number = tonumber(Raw)
	if not Number or Number <= 0 or Number ~= math.floor(Number) then return nil end
	return Number
end

local function prepareSaoJudasDatabase()
	if SaoJudasPrepared then return true end

	local DatabaseOk,Result = pcall(function()
		return exports.oxmysql:query_async([[CREATE TABLE IF NOT EXISTS sao_judas_crafts (
			CraftId VARCHAR(64) NOT NULL,
			Passport BIGINT NOT NULL,
			Recipe VARCHAR(64) NOT NULL,
			Quantity INT NOT NULL,
			OutputAmount INT NOT NULL,
			Materials LONGTEXT NOT NULL,
			Status VARCHAR(24) NOT NULL,
			StartedAt BIGINT NOT NULL,
			ReadyAt BIGINT NOT NULL,
			FinishedAt BIGINT DEFAULT NULL,
			Reason VARCHAR(64) DEFAULT NULL,
			PRIMARY KEY (CraftId),
			KEY idx_sao_judas_crafts_passport (Passport),
			KEY idx_sao_judas_crafts_recipe (Recipe),
			KEY idx_sao_judas_crafts_started (StartedAt)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci]])
	end)

	if not DatabaseOk then
		return false,tostring(Result)
	end

	SaoJudasPrepared = true
	return true
end

local function saoJudasRateAllowed(source,Key,Interval)
	local Id = tostring(source)..":"..Key
	local Now = GetGameTimer()
	if Now < (SaoJudasRateLimits[Id] or 0) then return false end

	SaoJudasRateLimits[Id] = Now + Interval
	return true
end

local function saoJudasActiveSessions()
	local Amount = 0
	for _ in pairs(SaoJudasSessions) do Amount = Amount + 1 end
	return Amount
end

local function saoJudasContext(source,Passport)
	if not Passport or not exports.sao_judas_operations:CanUseWorkbench(Passport) then
		return false,"permission_lost"
	end

	if not exports.sao_judas_operations:AtWorkbench(source) then
		return false,"too_far"
	end

	local Ped = GetPlayerPed(source)
	if Ped <= 0 or GetEntityHealth(Ped) <= 100 then
		return false,"player_dead"
	end

	return true
end

local function updateCraftStatus(CraftId,Status,Reason)
	local Prepared,PrepareError = prepareSaoJudasDatabase()
	if not Prepared then
		craftingLog(("craftId=%s status=%s reason=status_database_unavailable sqlError=%s"):format(
			tostring(CraftId),tostring(Status),tostring(PrepareError)
		))
		return false
	end

	local AffectedRows = exports.oxmysql:update_async([[UPDATE sao_judas_crafts
		SET Status = ?, FinishedAt = ?, Reason = ? WHERE CraftId = ?]],{
		Status,(Status == "processing" and nil or os.time()),Reason,CraftId
	})

	return tonumber(AffectedRows) == 1
end

local function releaseSaoJudasSession(Session,Status,Reason,NotifyPlayer)
	if not Session or Session.Released then return end
	Session.Released = true
	Session.State = Status

	SaoJudasSessions[Session.CraftId] = nil
	if SaoJudasPassportSessions[Session.Passport] == Session.CraftId then
		SaoJudasPassportSessions[Session.Passport] = nil
	end

	local CurrentSource = vRP.Source(Session.Passport)
	if CurrentSource then
		Player(CurrentSource).state.Buttons = false
		TriggerClientEvent("crafting:SaoJudasCancelled",CurrentSource,Session.CraftId)
		if NotifyPlayer then craftingNotify(CurrentSource,NotifyPlayer,"vermelho") end
	end

	updateCraftStatus(Session.CraftId,Status,Reason)
	craftingLog(("craftId=%s passport=%s recipe=%s quantity=%s status=%s reason=%s"):format(
		Session.CraftId,Session.Passport,Session.Item,Session.Quantity,Status,tostring(Reason)
	))
end

local function reservedMaterials(Passport,Recipe,Quantity)
	local Reserved = {}
	for Item,Multiplier in pairs(Recipe.Required) do
		local Amount = Multiplier * Quantity
		local Consult = vRP.ConsultItem(Passport,Item,Amount)
		if not Consult then
			return nil,Item,Amount
		end

		Reserved[#Reserved + 1] = {
			Base = Item,
			Item = Consult.Item,
			Slot = tostring(Consult.Slot),
			Amount = Amount,
			OriginalAmount = Consult.Amount
		}
	end

	return Reserved
end

local function slotFreedByReservation(Reserved,Slot)
	for _,Material in ipairs(Reserved) do
		if Material.Slot == Slot and Material.OriginalAmount == Material.Amount then
			return true
		end
	end

	return false
end

local function resultSlot(Passport,Item,Reserved,Requested)
	local Inventory = vRP.Inventory(Passport)
	local Slots = vRP.InventorySlots(Passport)
	local Stackable = not exports.vrp:ItemUnique(Item) and not exports.vrp:ItemDurability(Item) and not exports.vrp:ItemNamed(Item)

	local function Available(Slot)
		local Entry = Inventory[Slot]
		return not Entry or slotFreedByReservation(Reserved,Slot) or (Stackable and Entry.item == Item)
	end

	local RequestedNumber = tonumber(Requested)
	if RequestedNumber and RequestedNumber >= 5 and RequestedNumber <= Slots then
		local Slot = tostring(math.floor(RequestedNumber))
		if Available(Slot) then return Slot end
	end

	if Stackable then
		for Slot,Entry in pairs(Inventory) do
			if Entry.item == Item then return tostring(Slot) end
		end
	end

	for Number = 5,Slots do
		local Slot = tostring(Number)
		if Available(Slot) then return Slot end
	end

	return nil
end

local function projectedWeightAllowed(Passport,Item,OutputAmount,Reserved)
	local Weight = vRP.InventoryWeight(Passport)
	for _,Material in ipairs(Reserved) do
		Weight = Weight - (exports.vrp:ItemWeight(Material.Item) * Material.Amount)
	end

	Weight = Weight + (exports.vrp:ItemWeight(Item) * OutputAmount)
	return Weight <= vRP.GetWeight(Passport)
end

local function dismantleDailyAmount(Passport)
	local Prepared,PrepareError = prepareSaoJudasDatabase()
	if not Prepared then
		craftingLog(("passport=%s recipe=dismantle status=rejected reason=database_unavailable sqlError=%s"):format(
			Passport,tostring(PrepareError)
		))
		return SaoJudasOperations.Workbench.DismantleDailyLimit
	end

	local Date = os.date("*t")
	local DayStart = os.time({ year = Date.year, month = Date.month, day = Date.day, hour = 0, min = 0, sec = 0 })

	return tonumber(exports.oxmysql:scalar_async([[SELECT COALESCE(SUM(Quantity),0)
		FROM sao_judas_crafts WHERE Passport = ? AND Recipe = 'dismantle'
		AND Status = 'completed' AND StartedAt >= ?]],{ Passport,DayStart })) or 0
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PERMISSION
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Permission(Name)
    local source = source
    local Passport = vRP.Passport(source)
    if not Passport or not List[Name] then
        return false
    end

    if exports.bank:CheckTaxes(Passport) or exports.bank:CheckFines(Passport) then
        return false
    end

	if Name == "SaoJudas" then
		local Allowed = saoJudasContext(source,Passport)
		return Allowed
	end

    local Permission = List[Name].Permission
    return not Permission or vRP.HasService(Passport,Permission)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- MOUNT
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Mount(Name)
	local source = source
	local Passport = vRP.Passport(source)
	if Name == "SaoJudas" and not saoJudasContext(source,Passport) then
		return false
	end
	if Name == "SaoJudasLaboratory" and not exports.sao_judas_operations:CanAccessLaboratory(source) then
		return false
	end

	if Passport and Name and List[Name] then
		local Primary = {}
		local Inv = vRP.Inventory(Passport)
		for Slot,v in pairs(Inv) do
			if v.amount <= 0 or not exports.vrp:ItemExist(v.item) then
				vRP.CleanSlot(Passport,Slot)
			else
				v.key = v.item

				local Split = splitString(v.item)
				local Item = Split[1]

				if not v.desc then
					if Item == "vehiclekey" and Split[3] then
						local Consult = exports.oxmysql:single_async("SELECT * FROM vehicles WHERE Plate = ? LIMIT 1",{ Split[3] })
						if Consult and exports.vrp:VehicleExist(Consult.Vehicle) then
							v.desc = "Proprietário: <common>"..vRP.FullName(Consult.Passport).."</common><br>Modelo: <common>"..exports.vrp:VehicleName(Consult.Vehicle).."</common><br>Placa: <common>"..Split[3].."</common>"
						end
					elseif Item == "propertys" and Split[2] then
						local Consult = exports.oxmysql:single_async("SELECT * FROM propertys WHERE Serial = ? LIMIT 1",{ Split[2] })
						if Consult then
							v.desc = "Proprietário: <common>"..vRP.FullName(Consult.Passport).."</common>"
						end
					elseif exports.vrp:ItemNamed(Item) and Split[2] and vRP.Identity(Split[2]) then
						if Item == "identity" then
							v.desc = "Passaporte: <rare>"..Dotted(Split[2]).."</rare><br>Nome: <rare>"..vRP.FullName(Split[2]).."</rare><br>Telefone: <rare>"..vRP.Phone(Split[2]).."</rare>"
						else
							v.desc = "Proprietário: <common>"..vRP.FullName(Split[2]).."</common>"
						end
					end
				end

				if Split[2] then
					local Loaded = exports.vrp:ItemLoads(v.item)
					if Loaded then
						v.charges = parseInt(Split[2] * (100 / Loaded))
					end

					if exports.vrp:ItemDurability(v.item) then
						v.durability = parseInt(os.time() - Split[2])
						v.days = exports.vrp:ItemDurability(v.item)
					end
				end

				Primary[Slot] = v
			end
		end

		return Primary,vRP.GetWeight(Passport),vRP.InventorySlots(Passport)
	end
end
---------------------------------------------------------------------------------------------------------------------------------
-- TAKE
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Take(Item,Amount,Target,Name)
	local source = source
	local Passport = vRP.Passport(source)
	if not Passport then
		return false
	end

	if Name == "SaoJudas" then
		return false
	end

	if Name == "SaoJudasLaboratory" then
		craftingNotify(source,"A producao do laboratorio ainda esta sendo preparada.","amarelo")
		return false
	end

	if not (List[Name] and List[Name].List and List[Name].List[Item]) then
		return false
	end

	local Amount = parseInt(Amount,true)
	if exports.vrp:ItemUnique(Item) and Amount > 1 then
		Amount = 1
	end

	local DoesExist = exports.vrp:ItemExist(Item)
	if DoesExist and DoesExist.Blueprint and not exports.inventory:Blueprint(Passport,Item) then
		TriggerClientEvent("inventory:Notify",source,"Aviso","Aprendizado não encontrado.","amarelo")
		return false
	end

	local Target = tostring(Target)
	local Recipe = List[Name].List[Item]
	local Inventory = vRP.Inventory(Passport)
	local TotalAmount = Recipe.Amount * Amount

	if vRP.MaxItens(Passport,Item,TotalAmount) or not vRP.CheckWeight(Passport,Item,TotalAmount) or (Inventory[Target] and Inventory[Target].item ~= Item) then
		return false
	end

	local RemoveList = {}
	for Required,Multiplier in pairs(Recipe.Required) do
		local NeedAmount = Multiplier * Amount
		local ConsultItem = vRP.ConsultItem(Passport,Required,NeedAmount)

		if not ConsultItem then
			TriggerClientEvent("inventory:Notify",source,"Atenção","Precisa de <default>"..Dotted(NeedAmount).."x "..exports.vrp:ItemName(Required).."</default>.","vermelho")
			return false
		end

		RemoveList[ConsultItem.Item] = NeedAmount
	end

	for Item,Multiplier in pairs(RemoveList) do
		vRP.RemoveItem(Passport,Item,Multiplier)
	end

	vRP.GenerateItem(Passport,Item,TotalAmount,false,Target)

	TriggerClientEvent("inventory:Update",source)
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- START SAO JUDAS
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.StartSaoJudas(Item,Amount,Target,Name)
	local source = source
	local Passport = vRP.Passport(source)
	local Workbench = SaoJudasOperations.Workbench
	local Recipe = Name == "SaoJudas" and Workbench.Recipes[Item]

	if not Recipe or not Passport or not saoJudasRateAllowed(source,"start",1000) then
		return false
	end

	local Allowed,Reason = saoJudasContext(source,Passport)
	if not Allowed then
		craftingNotify(source,"Voce nao esta autorizado a utilizar a bancada de Sao Judas.","vermelho")
		return false
	end

	if SaoJudasPassportSessions[Passport] then
		craftingNotify(source,"Voce ja possui uma fabricacao em andamento.","vermelho")
		return false
	end


	if saoJudasActiveSessions() + SaoJudasStarting >= Workbench.QueueCapacity then
		craftingNotify(source,"A bancada esta sendo utilizada por outro operador.","vermelho")
		return false
	end

	local Quantity = strictInteger(Amount)
	local Maximum = math.min(Workbench.MaximumBatch,Recipe.MaximumBatch or Workbench.MaximumBatch)
	if not Quantity or Quantity > Maximum then
		craftingNotify(source,("Escolha uma quantidade entre 1 e %s."):format(Maximum),"vermelho")
		return false
	end

	if Item == "dismantle" and dismantleDailyAmount(Passport) + Quantity > Workbench.DismantleDailyLimit then
		craftingNotify(source,("O limite diario deste item e %s unidades."):format(Workbench.DismantleDailyLimit),"vermelho")
		return false
	end

	local OutputAmount = Recipe.Amount * Quantity
	if not exports.vrp:ItemExist(Item) or vRP.MaxItens(Passport,Item,OutputAmount) then
		craftingNotify(source,"Voce atingiu o limite deste item.","vermelho")
		return false
	end

	local Reserved,MissingItem,MissingAmount = reservedMaterials(Passport,Recipe,Quantity)
	if not Reserved then
		craftingNotify(source,("Precisa de <b>%sx %s</b>."):format(Dotted(MissingAmount),exports.vrp:ItemName(MissingItem)),"vermelho")
		return false
	end

	if not projectedWeightAllowed(Passport,Item,OutputAmount,Reserved) then
		craftingNotify(source,"Voce nao possui espaco suficiente no inventario.","vermelho")
		return false
	end

	local OutputSlot = resultSlot(Passport,Item,Reserved,Target)
	if not OutputSlot then
		craftingNotify(source,"Voce nao possui um slot livre para o resultado.","vermelho")
		return false
	end

	if saoJudasActiveSessions() + SaoJudasStarting >= Workbench.QueueCapacity then
		craftingNotify(source,"A bancada esta sendo utilizada por outro operador.","vermelho")
		return false
	end

	SaoJudasStarting = SaoJudasStarting + 1
	local CraftId = ("SJ-%s-%s-%s"):format(Passport,os.time(),GenerateString("DDLLDD"))
	local Duration = Recipe.Duration * Quantity
	local StartedAt = os.time()
	local ReadyAt = StartedAt + math.ceil(Duration / 1000)
	local MaterialsJson = json.encode(Reserved)
	local DatabaseOk,DatabaseResult = pcall(function()
		local Prepared,PrepareError = prepareSaoJudasDatabase()
		if not Prepared then error(PrepareError or "database_prepare_failed") end

		return exports.oxmysql:update_async([[INSERT INTO sao_judas_crafts
			(CraftId,Passport,Recipe,Quantity,OutputAmount,Materials,Status,StartedAt,ReadyAt)
			VALUES (?,?,?,?,?,?,?,?,?)]],{
			CraftId,Passport,Item,Quantity,OutputAmount,MaterialsJson,"processing",StartedAt,ReadyAt
		})
	end)
	SaoJudasStarting = math.max(0,SaoJudasStarting - 1)
	local AffectedRows = DatabaseOk and tonumber(DatabaseResult) or nil

	if not DatabaseOk or AffectedRows ~= 1 then
		craftingLog(("passport=%s recipe=%s craftId=%s quantity=%s materialsJsonBytes=%s prepared=%s status=rejected reason=database_insert_failed databaseOk=%s affectedRows=%s returnType=%s sqlError=%s"):format(
			Passport,Item,CraftId,Quantity,#MaterialsJson,tostring(SaoJudasPrepared),tostring(DatabaseOk),
			tostring(AffectedRows),type(DatabaseResult),DatabaseOk and "none" or tostring(DatabaseResult)
		))
		craftingNotify(source,"A bancada esta temporariamente indisponivel. Tente novamente em instantes.","vermelho")
		return false
	end

	if SaoJudasOperations.Debug then
		local ConfirmOk,Confirm = pcall(function()
			return exports.oxmysql:single_async("SELECT CraftId,Status FROM sao_judas_crafts WHERE CraftId = ? LIMIT 1",{ CraftId })
		end)
		craftingLog(("craftId=%s status=reservation_confirmed databaseOk=%s persisted=%s persistedStatus=%s"):format(
			CraftId,tostring(ConfirmOk),tostring(Confirm and Confirm.CraftId == CraftId),tostring(Confirm and Confirm.Status)
		))
	end

	local Session = {
		CraftId = CraftId,
		Source = source,
		Passport = Passport,
		Item = Item,
		Quantity = Quantity,
		OutputAmount = OutputAmount,
		OutputSlot = OutputSlot,
		Reserved = Reserved,
		StartedAt = StartedAt,
		ReadyAt = ReadyAt,
		ReadyAtMs = GetGameTimer() + Duration,
		ExpiresAt = StartedAt + Workbench.SessionTimeoutSeconds,
		State = "processing"
	}

	SaoJudasSessions[CraftId] = Session
	SaoJudasPassportSessions[Passport] = CraftId
	Player(source).state.Buttons = true

	craftingLog(("craftId=%s passport=%s recipe=%s quantity=%s materials=%s status=processing"):format(
		CraftId,Passport,Item,Quantity,json.encode(Reserved)
	))

	return {
		Success = true,
		CraftId = CraftId,
		Duration = Duration,
		Label = exports.vrp:ItemName(Item)
	}
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- COMPLETE SAO JUDAS
-----------------------------------------------------------------------------------------------------------------------------------------
local function completeSaoJudasSession(source,Passport,Session)
	if not Session or Session.Released then
		return { Success = false, Status = "missing", Reason = "session_missing" }
	end

	if Session.Busy then
		return { Success = false, Status = "processing", Reason = "completion_in_progress" }
	end

	local Monitor = SaoJudasOperations.Workbench.AnimationMonitor or {}
	local CompletionTolerance = tonumber(Monitor.CompletionToleranceMs) or 350
	if GetGameTimer() + CompletionTolerance < Session.ReadyAtMs then
		craftingLog(("craftId=%s passport=%s status=rejected reason=early_completion"):format(Session.CraftId,Passport))
		return {
			Success = false,
			Status = "rejected",
			Reason = "early_completion",
			RemainingMs = math.max(0,Session.ReadyAtMs - GetGameTimer())
		}
	end

	local Allowed,Reason = saoJudasContext(source,Passport)
	if not Allowed then
		releaseSaoJudasSession(Session,"cancelled",Reason,"A fabricacao foi cancelada.")
		return { Success = false, Status = "cancelled", Reason = Reason }
	end

	local Recipe = SaoJudasOperations.Workbench.Recipes[Session.Item]
	if not Recipe then
		releaseSaoJudasSession(Session,"failed","recipe_missing","A receita nao esta mais disponivel.")
		return { Success = false, Status = "failed", Reason = "recipe_missing" }
	end

	Session.Busy = true
	Session.State = "completing"
	for _,Material in ipairs(Session.Reserved) do
		local Inventory = vRP.Inventory(Passport)
		local Entry = Inventory[Material.Slot]
		if not Entry or Entry.item ~= Material.Item or Entry.amount < Material.Amount then
			Session.Busy = false
			releaseSaoJudasSession(Session,"cancelled","reserved_material_missing","Os materiais reservados foram alterados.")
			return { Success = false, Status = "cancelled", Reason = "reserved_material_missing" }
		end
	end

	if not projectedWeightAllowed(Passport,Session.Item,Session.OutputAmount,Session.Reserved) then
		Session.Busy = false
		releaseSaoJudasSession(Session,"cancelled","weight_changed","Voce nao possui espaco suficiente no inventario.")
		return { Success = false, Status = "cancelled", Reason = "weight_changed" }
	end

	local Removed = {}
	for _,Material in ipairs(Session.Reserved) do
		if vRP.TakeItem(Passport,Material.Item,Material.Amount,false,Material.Slot) then
			Removed[#Removed + 1] = Material
		else
			for _,Refund in ipairs(Removed) do
				vRP.GiveItem(Passport,Refund.Item,Refund.Amount,false,Refund.Slot)
			end

			Session.Busy = false
			releaseSaoJudasSession(Session,"refunded","material_remove_failed","Nao foi possivel concluir. Os materiais foram preservados.")
			return { Success = false, Status = "refunded", Reason = "material_remove_failed" }
		end
	end

	vRP.GenerateItem(Passport,Session.Item,Session.OutputAmount,true,Session.OutputSlot)
	TriggerClientEvent("inventory:Update",source)
	Player(source).state.Buttons = false

	SaoJudasSessions[Session.CraftId] = nil
	SaoJudasPassportSessions[Passport] = nil
	Session.Released = true
	Session.State = "completed"
	updateCraftStatus(Session.CraftId,"completed")

	craftingNotify(source,("Fabricacao concluida: <b>%sx %s</b>."):format(Session.OutputAmount,exports.vrp:ItemName(Session.Item)),"verde")
	craftingLog(("craftId=%s passport=%s recipe=%s quantity=%s output=%s status=completed duration=%s"):format(
		Session.CraftId,Passport,Session.Item,Session.Quantity,Session.OutputAmount,os.time() - Session.StartedAt
	))

	return { Success = true, Status = "completed", CraftId = Session.CraftId }
end

function Lil.CompleteSaoJudas(CraftId)
	local source = source
	local Passport = vRP.Passport(source)
	local Session = SaoJudasSessions[tostring(CraftId)]

	if not Session or Session.Source ~= source or Session.Passport ~= Passport then
		return { Success = false, Status = "missing", Reason = "session_missing" }
	end

	return completeSaoJudasSession(source,Passport,Session)
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- CANCEL SAO JUDAS
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.CancelSaoJudas(CraftId,Reason)
	local source = source
	local Passport = vRP.Passport(source)
	local Session = SaoJudasSessions[tostring(CraftId)]

	if not Session or Session.Source ~= source or Session.Passport ~= Passport then
		return { Success = false, Status = "missing", Reason = "session_missing" }
	end

	Reason = tostring(Reason or "client_cancelled")
	if not AllowedCancelReasons[Reason] then
		craftingLog(("craftId=%s passport=%s status=rejected reason=unknown_cancel_reason supplied=%s"):format(
			Session.CraftId,Passport,Reason
		))
		return { Success = false, Status = "rejected", Reason = "unknown_cancel_reason" }
	end

	if Session.Busy then
		return { Success = false, Status = "processing", Reason = "completion_in_progress" }
	end

	local Monitor = SaoJudasOperations.Workbench.AnimationMonitor or {}
	local CompletionTolerance = tonumber(Monitor.CompletionToleranceMs) or 350
	if Reason == "animation_interrupted" and GetGameTimer() + CompletionTolerance >= Session.ReadyAtMs then
		craftingLog(("craftId=%s passport=%s status=rejected reason=ready_to_complete cancelReason=%s"):format(
			Session.CraftId,Passport,Reason
		))
		return { Success = false, Status = "ready_to_complete", Reason = "ready_to_complete" }
	end

	releaseSaoJudasSession(Session,"cancelled",Reason,"A fabricacao foi cancelada.")
	return { Success = true, Status = "cancelled", Reason = Reason }
end

function Lil.GetSaoJudasCraftStatus(CraftId)
	local source = source
	local Passport = vRP.Passport(source)
	local Id = tostring(CraftId)
	local Session = SaoJudasSessions[Id]

	if Session and Session.Source == source and Session.Passport == Passport then
		return { Success = true, Status = Session.State or (Session.Busy and "completing" or "processing") }
	end

	local Prepared = prepareSaoJudasDatabase()
	if not Prepared then
		return { Success = false, Status = "missing", Reason = "database_unavailable" }
	end

	local DatabaseOk,Row = pcall(function()
		return exports.oxmysql:single_async("SELECT Status,Reason FROM sao_judas_crafts WHERE CraftId = ? AND Passport = ? LIMIT 1",{
			Id,Passport
		})
	end)
	if not DatabaseOk then
		return { Success = false, Status = "missing", Reason = "database_unavailable" }
	end

	return {
		Success = Row ~= nil,
		Status = Row and Row.Status or "missing",
		Reason = Row and Row.Reason or "session_missing"
	}
end

CreateThread(function()
	Wait(1000)
	local Ok,Error = pcall(function()
		local Prepared,PrepareError = prepareSaoJudasDatabase()
		if not Prepared then error(PrepareError or "database_prepare_failed") end

		exports.oxmysql:update_async([[UPDATE sao_judas_crafts SET Status = 'cancelled',
			FinishedAt = ?, Reason = 'resource_restart' WHERE Status = 'processing']],{ os.time() })
	end)

	if not Ok then craftingLog("database_prepare_failed reason="..tostring(Error)) end

	while true do
		Wait(1000)
		local Cancel = {}
		for _,Session in pairs(SaoJudasSessions) do
			local CurrentSource = vRP.Source(Session.Passport)
			local Allowed,Reason = CurrentSource and saoJudasContext(CurrentSource,Session.Passport)
			if not CurrentSource then
				Cancel[#Cancel + 1] = { Session = Session, Reason = "player_dropped" }
			elseif not Allowed then
				Cancel[#Cancel + 1] = { Session = Session, Reason = Reason }
			elseif os.time() > Session.ExpiresAt then
				Cancel[#Cancel + 1] = { Session = Session, Reason = "session_timeout" }
			end
		end

		for _,Data in ipairs(Cancel) do
			releaseSaoJudasSession(Data.Session,"cancelled",Data.Reason,"A fabricacao foi cancelada.")
		end
	end
end)

AddEventHandler("playerDropped",function()
	local DroppedSource = source
	for _,Session in pairs(SaoJudasSessions) do
		if Session.Source == DroppedSource then
			releaseSaoJudasSession(Session,"cancelled","player_dropped")
			break
		end
	end

	local Prefix = tostring(DroppedSource)..":"
	for Key in pairs(SaoJudasRateLimits) do
		if Key:sub(1,#Prefix) == Prefix then SaoJudasRateLimits[Key] = nil end
	end
end)

AddEventHandler("onResourceStop",function(Resource)
	if Resource ~= GetCurrentResourceName() and Resource ~= "sao_judas_operations" then return end

	local Sessions = {}
	for _,Session in pairs(SaoJudasSessions) do Sessions[#Sessions + 1] = Session end

	for _,Session in ipairs(Sessions) do
		if Resource == "sao_judas_operations" then
			releaseSaoJudasSession(Session,"cancelled","dependency_stop","A fabricacao foi cancelada.")
		else
			local CurrentSource = vRP.Source(Session.Passport)
			if CurrentSource then Player(CurrentSource).state.Buttons = false end
			updateCraftStatus(Session.CraftId,"cancelled","resource_stop")
		end
	end
end)

RegisterCommand("saojudas_crafting_debug",function(source)
	if not SaoJudasOperations.Debug then return end

	local Passport = source > 0 and vRP.Passport(source) or 0
	if source > 0 and Passport ~= 1 then return end

	local Session = Passport and SaoJudasPassportSessions[Passport] and SaoJudasSessions[SaoJudasPassportSessions[Passport]]
	craftingLog(("debug source=%s passport=%s target=%s distance_ok=%s leader=%s operator=%s active=%s capacity=%s craftId=%s state=%s"):format(
		source,tostring(Passport),tostring(SaoJudasOperations.Workbench.Enabled),
		tostring(source > 0 and exports.sao_judas_operations:AtWorkbench(source) or false),
		tostring(Passport and exports.sao_judas_operations:IsLeader(Passport) or false),
		tostring(Passport and exports.sao_judas_operations:CanUseWorkbench(Passport) or false),
		tostring(saoJudasActiveSessions() + SaoJudasStarting),tostring(SaoJudasOperations.Workbench.QueueCapacity),
		tostring(Session and Session.CraftId),tostring(Session and "processing" or "idle")
	))
end,false)
