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
local SaoJudasPassportStarting = {}
local SaoJudasRateLimits = {}
local SaoJudasPrepared = false
local SaoJudasStarting = {
	workbench = 0,
	laboratory = 0
}
local AllowedCancelReasons = {
	client_cancelled = true,
	animation_interrupted = true,
	progress_cancelled = true
}

local function craftingLog(Message)
	print("[saojudas/crafting] "..Message)
end

local function craftingNotify(source,Context,Message,Color)
	local Title = Context == "laboratory" and "Laboratorio de Sao Judas" or "Bancada de Sao Judas"
	TriggerClientEvent("Notify",source,Title,Message,Color or "amarelo",5000)
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

local function saoJudasActiveSessions(Context)
	local Amount = 0
	for _,Session in pairs(SaoJudasSessions) do
		if not Context or Session.Context == Context then Amount = Amount + 1 end
	end
	return Amount
end

local function contextSettings(Context)
	if Context == "workbench" then return SaoJudasOperations.Workbench end
	if Context == "laboratory" then return SaoJudasOperations.Laboratory end
end

local function resolveCraftContext(Name,Item)
	local Context
	if Name == "SaoJudas" then
		Context = "workbench"
	elseif Name == "SaoJudasLaboratory" then
		Context = "laboratory"
	else
		return nil
	end

	local Settings = contextSettings(Context)
	local Recipes = Settings and Settings.Recipes
	local Recipe = type(Item) == "string" and Recipes and Recipes[Item]
	if type(Recipe) ~= "table" or not strictInteger(Recipe.Amount) or type(Recipe.Required) ~= "table" then
		return nil
	end

	local Requirements = 0
	for Required,Multiplier in pairs(Recipe.Required) do
		if type(Required) ~= "string" or not strictInteger(Multiplier) then return nil end
		Requirements = Requirements + 1
	end
	if Requirements == 0 then return nil end

	return {
		Key = Context,
		Name = Name,
		Settings = Settings,
		Recipe = Recipe,
		RecipeKey = Context == "laboratory" and "laboratory:"..Item or Item
	}
end

local function recipeDuration(Settings,Recipe)
	local Duration = tonumber(Recipe and Recipe.Duration)
	if not Duration and Recipe and Recipe.DurationKey and type(Settings.Durations) == "table" then
		Duration = tonumber(Settings.Durations[Recipe.DurationKey])
	end

	if not Duration or Duration <= 0 or Duration ~= math.floor(Duration) then return nil end
	return Duration
end

local function saoJudasContext(source,Passport,Context,AllowBusy,SkipRoleCache)
	if not Passport then return false,"invalid_passport" end

	if Context == "laboratory" then
		local Laboratory = SaoJudasOperations.Laboratory
		if not Laboratory.Enabled then return false,"laboratory_disabled" end
		if Laboratory.ProductionEnabled ~= true then return false,"production_disabled" end
		if Laboratory.ExclusiveSaoJudasLaboratory ~= true then return false,"catalog_not_exclusive" end
		if not exports.sao_judas_operations:IsMember(Passport) then return false,"not_member" end
		if not exports.sao_judas_operations:CanUseLaboratory(Passport,SkipRoleCache == true) then
			return false,"permission_lost"
		end
		if not exports.sao_judas_operations:AtLaboratory(source) then return false,"too_far" end

		local Ped = GetPlayerPed(source)
		if Ped <= 0 or GetEntityHealth(Ped) <= 100 then return false,"player_dead" end
		if vRP.InsideVehicle(source) then return false,"player_in_vehicle" end
		if Player(source).state.Safezone then return false,"safezone" end
		if Player(source).state.Handcuff then return false,"player_handcuffed" end
		if not AllowBusy and Player(source).state.Buttons then return false,"player_busy" end
		if GetPlayerRoutingBucket(source) ~= 0 then return false,"routing_bucket_blocked" end
		return true
	end

	if Context ~= "workbench" or not SaoJudasOperations.Workbench.Enabled or
		SaoJudasOperations.Workbench.RecipesEnabled ~= true or
		not exports.sao_judas_operations:CanUseWorkbench(Passport) then
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

local function reservedMatchesRecipe(Session,Recipe)
	local Expected = {}
	for Item,Multiplier in pairs(Recipe.Required or {}) do
		local NumericMultiplier = tonumber(Multiplier)
		local Amount = NumericMultiplier and NumericMultiplier * Session.Quantity
		if not Amount or Amount <= 0 or Amount ~= math.floor(Amount) then return false end
		Expected[Item] = Amount
	end

	local Seen = {}
	for _,Material in ipairs(Session.Reserved or {}) do
		if type(Material.Base) ~= "string" or type(Material.Item) ~= "string" or
			type(Material.Slot) ~= "string" or Seen[Material.Base] or
			Expected[Material.Base] ~= Material.Amount then
			return false
		end
		Seen[Material.Base] = true
	end

	for Item in pairs(Expected) do
		if not Seen[Item] then return false end
	end
	return true
end

local function inventoryItemAmount(Passport,Item)
	local Amount = 0
	for _,Entry in pairs(vRP.Inventory(Passport)) do
		if Entry.item == Item then Amount = Amount + Entry.amount end
	end
	return Amount
end

local function inventorySlotBaseAmount(Passport,Item,Slot)
	local Entry = vRP.Inventory(Passport)[tostring(Slot)]
	return Entry and SplitOne(Entry.item) == SplitOne(Item) and Entry.amount or 0
end

local function refundMaterials(Passport,Materials)
	local Failed = {}
	for _,Material in ipairs(Materials) do
		local Before = inventoryItemAmount(Passport,Material.Item)
		local Ok = pcall(function()
			vRP.GiveItem(Passport,Material.Item,Material.Amount,false,Material.Slot)
		end)
		local Refunded = inventoryItemAmount(Passport,Material.Item) - Before
		if not Ok or Refunded ~= Material.Amount then Failed[#Failed + 1] = Material.Item end
	end

	return #Failed == 0,table.concat(Failed,",")
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
	if CurrentSource == Session.Source then
		Player(CurrentSource).state.Buttons = false
		TriggerClientEvent("crafting:SaoJudasCancelled",CurrentSource,Session.CraftId)
		if NotifyPlayer then craftingNotify(CurrentSource,Session.Context,NotifyPlayer,"vermelho") end
	end

	updateCraftStatus(Session.CraftId,Status,Reason)
	craftingLog(("craftId=%s passport=%s context=%s recipe=%s quantity=%s status=%s reason=%s"):format(
		Session.CraftId,Session.Passport,Session.Context,Session.Item,Session.Quantity,Status,tostring(Reason)
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
		local Allowed = saoJudasContext(source,Passport,"workbench")
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
	if Name == "SaoJudas" and not saoJudasContext(source,Passport,"workbench") then
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

	if Name == "SaoJudas" or Name == "SaoJudasLaboratory" then
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
	local Context = resolveCraftContext(Name,Item)
	local Settings = Context and Context.Settings
	local Recipe = Context and Context.Recipe

	if not Context or not Passport or not saoJudasRateAllowed(source,"start:"..Context.Key,1000) then
		return false
	end

	local Allowed,Reason = saoJudasContext(source,Passport,Context.Key,false,Context.Key == "laboratory")
	if not Allowed then
		craftingNotify(source,Context.Key,"Voce nao esta autorizado a iniciar esta producao.","vermelho")
		craftingLog(("passport=%s context=%s recipe=%s status=rejected reason=%s"):format(
			Passport,Context.Key,tostring(Item),tostring(Reason)
		))
		return false
	end

	if SaoJudasPassportSessions[Passport] or SaoJudasPassportStarting[Passport] then
		craftingNotify(source,Context.Key,"Voce ja possui uma fabricacao em andamento.","vermelho")
		return false
	end

	local QueueCapacity = strictInteger(Settings.QueueCapacity) or 1
	if saoJudasActiveSessions(Context.Key) + (SaoJudasStarting[Context.Key] or 0) >= QueueCapacity then
		craftingNotify(source,Context.Key,"Este ponto de producao esta sendo utilizado por outro operador.","vermelho")
		return false
	end

	local Quantity = strictInteger(Amount)
	local ConfiguredMaximum = strictInteger(Settings.MaximumBatch) or 1
	local RecipeMaximum = strictInteger(Recipe.MaximumBatch) or ConfiguredMaximum
	local Maximum = math.min(ConfiguredMaximum,RecipeMaximum)
	if not Quantity or Quantity > Maximum then
		craftingNotify(source,Context.Key,("Escolha uma quantidade entre 1 e %s."):format(Maximum),"vermelho")
		return false
	end

	if Context.Key == "workbench" and Item == "dismantle" and
		dismantleDailyAmount(Passport) + Quantity > Settings.DismantleDailyLimit then
		craftingNotify(source,Context.Key,("O limite diario deste item e %s unidades."):format(Settings.DismantleDailyLimit),"vermelho")
		return false
	end

	local OutputAmount = Recipe.Amount * Quantity
	if not exports.vrp:ItemExist(Item) or vRP.MaxItens(Passport,Item,OutputAmount) then
		craftingNotify(source,Context.Key,"Voce atingiu o limite deste item.","vermelho")
		return false
	end

	local Reserved,MissingItem,MissingAmount = reservedMaterials(Passport,Recipe,Quantity)
	if not Reserved then
		craftingNotify(source,Context.Key,("Precisa de <b>%sx %s</b>."):format(Dotted(MissingAmount),exports.vrp:ItemName(MissingItem)),"vermelho")
		return false
	end

	if not projectedWeightAllowed(Passport,Item,OutputAmount,Reserved) then
		craftingNotify(source,Context.Key,"Voce nao possui espaco suficiente no inventario.","vermelho")
		return false
	end

	local OutputSlot = resultSlot(Passport,Item,Reserved,Target)
	if not OutputSlot then
		craftingNotify(source,Context.Key,"Voce nao possui um slot livre para o resultado.","vermelho")
		return false
	end

	if SaoJudasPassportSessions[Passport] or SaoJudasPassportStarting[Passport] then
		craftingNotify(source,Context.Key,"Voce ja possui uma fabricacao em andamento.","vermelho")
		return false
	end

	if saoJudasActiveSessions(Context.Key) + (SaoJudasStarting[Context.Key] or 0) >= QueueCapacity then
		craftingNotify(source,Context.Key,"Este ponto de producao esta sendo utilizado por outro operador.","vermelho")
		return false
	end

	local UnitDuration = recipeDuration(Settings,Recipe)
	if not UnitDuration then
		craftingNotify(source,Context.Key,"Esta receita esta temporariamente indisponivel.","vermelho")
		craftingLog(("passport=%s context=%s recipe=%s status=rejected reason=invalid_server_duration"):format(
			Passport,Context.Key,Item
		))
		return false
	end

	SaoJudasPassportStarting[Passport] = true
	SaoJudasStarting[Context.Key] = (SaoJudasStarting[Context.Key] or 0) + 1
	local Prefix = Context.Key == "laboratory" and "SJL" or "SJ"
	local CraftId = ("%s-%s-%s-%s"):format(Prefix,Passport,os.time(),GenerateString("DDLLDD"))
	local Duration = UnitDuration * Quantity
	local StartedAt = os.time()
	local ReadyAt = StartedAt + math.ceil(Duration / 1000)
	local MaterialsJson = json.encode(Reserved)
	local DatabaseOk,DatabaseResult = pcall(function()
		local Prepared,PrepareError = prepareSaoJudasDatabase()
		if not Prepared then error(PrepareError or "database_prepare_failed") end

		return exports.oxmysql:update_async([[INSERT INTO sao_judas_crafts
			(CraftId,Passport,Recipe,Quantity,OutputAmount,Materials,Status,StartedAt,ReadyAt)
			VALUES (?,?,?,?,?,?,?,?,?)]],{
			CraftId,Passport,Context.RecipeKey,Quantity,OutputAmount,MaterialsJson,"processing",StartedAt,ReadyAt
		})
	end)
	local AffectedRows = DatabaseOk and tonumber(DatabaseResult) or nil

	if not DatabaseOk or AffectedRows ~= 1 then
		SaoJudasStarting[Context.Key] = math.max(0,(SaoJudasStarting[Context.Key] or 1) - 1)
		SaoJudasPassportStarting[Passport] = nil
		craftingLog(("passport=%s context=%s recipe=%s craftId=%s quantity=%s materialsJsonBytes=%s prepared=%s status=rejected reason=database_insert_failed databaseOk=%s affectedRows=%s returnType=%s sqlError=%s"):format(
			Passport,Context.Key,Context.RecipeKey,CraftId,Quantity,#MaterialsJson,tostring(SaoJudasPrepared),tostring(DatabaseOk),
			tostring(AffectedRows),type(DatabaseResult),DatabaseOk and "none" or tostring(DatabaseResult)
		))
		craftingNotify(source,Context.Key,"Este ponto esta temporariamente indisponivel. Tente novamente em instantes.","vermelho")
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

	local CurrentPassport = vRP.Passport(source)
	local StillAllowed,StartReason = false,"passport_changed"
	if CurrentPassport == Passport then
		StillAllowed,StartReason = saoJudasContext(
			source,Passport,Context.Key,false,Context.Key == "laboratory"
		)
	end
	if not StillAllowed or SaoJudasPassportSessions[Passport] then
		SaoJudasStarting[Context.Key] = math.max(0,(SaoJudasStarting[Context.Key] or 1) - 1)
		SaoJudasPassportStarting[Passport] = nil
		updateCraftStatus(CraftId,"cancelled",StartReason or "session_conflict")
		craftingLog(("craftId=%s passport=%s context=%s status=cancelled reason=%s"):format(
			CraftId,Passport,Context.Key,tostring(StartReason or "session_conflict")
		))
		return false
	end

	local Session = {
		CraftId = CraftId,
		Source = source,
		Passport = Passport,
		Context = Context.Key,
		Name = Context.Name,
		RecipeKey = Context.RecipeKey,
		Item = Item,
		Quantity = Quantity,
		OutputAmount = OutputAmount,
		OutputSlot = OutputSlot,
		Reserved = Reserved,
		StartedAt = StartedAt,
		ReadyAt = ReadyAt,
		ReadyAtMs = GetGameTimer() + Duration,
		ExpiresAt = StartedAt + (strictInteger(Settings.SessionTimeoutSeconds) or 120),
		State = "processing"
	}

	SaoJudasSessions[CraftId] = Session
	SaoJudasPassportSessions[Passport] = CraftId
	SaoJudasStarting[Context.Key] = math.max(0,(SaoJudasStarting[Context.Key] or 1) - 1)
	SaoJudasPassportStarting[Passport] = nil
	Player(source).state.Buttons = true

	craftingLog(("craftId=%s passport=%s context=%s recipe=%s quantity=%s materials=%s status=processing"):format(
		CraftId,Passport,Context.Key,Context.RecipeKey,Quantity,json.encode(Reserved)
	))

	return {
		Success = true,
		CraftId = CraftId,
		Context = Context.Key,
		Duration = Duration,
		Action = Context.Key == "laboratory" and (Recipe.DurationKey == "Packaging" and "Empacotando" or "Processando") or "Fabricando",
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

	local Settings = contextSettings(Session.Context)
	local Monitor = Settings and Settings.AnimationMonitor or {}
	local CompletionTolerance = tonumber(Monitor.CompletionToleranceMs) or 350
	if GetGameTimer() + CompletionTolerance < Session.ReadyAtMs then
		craftingLog(("craftId=%s passport=%s context=%s status=rejected reason=early_completion"):format(
			Session.CraftId,Passport,tostring(Session.Context)
		))
		return {
			Success = false,
			Status = "rejected",
			Reason = "early_completion",
			RemainingMs = math.max(0,Session.ReadyAtMs - GetGameTimer())
		}
	end

	Session.Busy = true
	Session.State = "completing"

	local Allowed,Reason = saoJudasContext(source,Passport,Session.Context,true,Session.Context == "laboratory")
	if Session.Released then
		return { Success = false, Status = "missing", Reason = "session_missing" }
	end
	if not Allowed then
		releaseSaoJudasSession(Session,"cancelled",Reason,"A fabricacao foi cancelada.")
		return { Success = false, Status = "cancelled", Reason = Reason }
	end

	local Context = resolveCraftContext(Session.Name,Session.Item)
	local Recipe = Context and Context.Recipe
	local ConfiguredMaximum = Settings and strictInteger(Settings.MaximumBatch) or nil
	local RecipeMaximum = Recipe and strictInteger(Recipe.MaximumBatch) or ConfiguredMaximum
	local Maximum = ConfiguredMaximum and math.min(ConfiguredMaximum,RecipeMaximum or ConfiguredMaximum) or 0
	if not Context or Context.Key ~= Session.Context or Context.RecipeKey ~= Session.RecipeKey or
		not Recipe or not strictInteger(Session.Quantity) or Session.Quantity > Maximum or
		Session.OutputAmount ~= Recipe.Amount * Session.Quantity or not reservedMatchesRecipe(Session,Recipe) then
		releaseSaoJudasSession(Session,"failed","recipe_missing","A receita nao esta mais disponivel.")
		return { Success = false, Status = "failed", Reason = "recipe_missing" }
	end

	for _,Material in ipairs(Session.Reserved) do
		local Inventory = vRP.Inventory(Passport)
		local Entry = Inventory[Material.Slot]
		if not Entry or Entry.item ~= Material.Item or Entry.amount < Material.Amount then
			Session.Busy = false
			releaseSaoJudasSession(Session,"cancelled","reserved_material_missing","Os materiais reservados foram alterados.")
			return { Success = false, Status = "cancelled", Reason = "reserved_material_missing" }
		end
	end

	if vRP.MaxItens(Passport,Session.Item,Session.OutputAmount) or
		not projectedWeightAllowed(Passport,Session.Item,Session.OutputAmount,Session.Reserved) then
		releaseSaoJudasSession(Session,"cancelled","weight_changed","Voce nao possui espaco suficiente no inventario.")
		return { Success = false, Status = "cancelled", Reason = "weight_changed" }
	end

	local OutputSlot = resultSlot(Passport,Session.Item,Session.Reserved,Session.OutputSlot)
	if not OutputSlot then
		releaseSaoJudasSession(Session,"cancelled","output_slot_changed","Voce nao possui um slot livre para o resultado.")
		return { Success = false, Status = "cancelled", Reason = "output_slot_changed" }
	end
	Session.OutputSlot = OutputSlot

	local Removed = {}
	for _,Material in ipairs(Session.Reserved) do
		if vRP.TakeItem(Passport,Material.Item,Material.Amount,false,Material.Slot) then
			Removed[#Removed + 1] = Material
		else
			local Refunded,RefundItem = refundMaterials(Passport,Removed)
			local Status = Refunded and "refunded" or "recovery_required"
			local FailureReason = Refunded and "material_remove_failed" or "material_refund_failed"
			craftingLog(("craftId=%s passport=%s context=%s status=%s reason=%s refundItem=%s removed=%s"):format(
				Session.CraftId,Passport,Session.Context,Status,FailureReason,tostring(RefundItem),json.encode(Removed)
			))
			local Message = Refunded and "Nao foi possivel concluir. Os materiais foram preservados." or
				"A producao entrou em recuperacao segura. Avise a administracao com o codigo "..Session.CraftId.."."
			releaseSaoJudasSession(Session,Status,FailureReason,Message)
			return { Success = false, Status = Status, Reason = FailureReason }
		end
	end

	local BeforeOutput = inventorySlotBaseAmount(Passport,Session.Item,Session.OutputSlot)
	local DeliveryOk,DeliveryError = pcall(function()
		if Session.Context == "laboratory" then
			vRP.GiveItem(Passport,Session.Item,Session.OutputAmount,false,Session.OutputSlot)
		else
			vRP.GenerateItem(Passport,Session.Item,Session.OutputAmount,false,Session.OutputSlot)
		end
	end)
	local OutputEntry = vRP.Inventory(Passport)[tostring(Session.OutputSlot)]
	local DeliveredAmount = inventorySlotBaseAmount(Passport,Session.Item,Session.OutputSlot) - BeforeOutput
	if not DeliveryOk or DeliveredAmount ~= Session.OutputAmount then
		local OutputRolledBack = DeliveredAmount <= 0
		if DeliveredAmount > 0 and OutputEntry and SplitOne(OutputEntry.item) == SplitOne(Session.Item) then
			OutputRolledBack = vRP.TakeItem(Passport,OutputEntry.item,DeliveredAmount,false,Session.OutputSlot) and
				inventorySlotBaseAmount(Passport,Session.Item,Session.OutputSlot) == BeforeOutput
		end

		local Refunded,RefundItem = false,"output_not_rolled_back"
		if OutputRolledBack then Refunded,RefundItem = refundMaterials(Passport,Removed) end
		local Status = Refunded and "refunded" or "recovery_required"
		local FailureReason = Refunded and "output_delivery_failed" or "delivery_rollback_failed"
		craftingLog(("craftId=%s passport=%s context=%s status=%s reason=%s deliveryError=%s delivered=%s outputRolledBack=%s refundItem=%s removed=%s"):format(
			Session.CraftId,Passport,Session.Context,Status,FailureReason,tostring(DeliveryError),
			DeliveredAmount,tostring(OutputRolledBack),tostring(RefundItem),json.encode(Removed)
		))
		local Message = Refunded and "A entrega falhou e os materiais foram devolvidos integralmente." or
			"A producao entrou em recuperacao segura. Avise a administracao com o codigo "..Session.CraftId.."."
		releaseSaoJudasSession(Session,Status,FailureReason,Message)
		return { Success = false, Status = Status, Reason = FailureReason }
	end

	TriggerClientEvent("inventory:Update",source)
	Player(source).state.Buttons = false

	SaoJudasSessions[Session.CraftId] = nil
	SaoJudasPassportSessions[Passport] = nil
	Session.Released = true
	Session.State = "completed"
	local StatusUpdated = updateCraftStatus(Session.CraftId,"completed")
	if not StatusUpdated then
		craftingLog(("craftId=%s passport=%s context=%s status=completed reason=status_update_failed"):format(
			Session.CraftId,Passport,Session.Context
		))
	end

	craftingNotify(source,Session.Context,("Fabricacao concluida: <b>%sx %s</b>."):format(Session.OutputAmount,exports.vrp:ItemName(Session.Item)),"verde")
	craftingLog(("craftId=%s passport=%s context=%s recipe=%s quantity=%s output=%s status=completed duration=%s"):format(
		Session.CraftId,Passport,Session.Context,Session.RecipeKey,Session.Quantity,Session.OutputAmount,os.time() - Session.StartedAt
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

	local Settings = contextSettings(Session.Context)
	local Monitor = Settings and Settings.AnimationMonitor or {}
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
			local Allowed,Reason = false,"player_dropped"
			if CurrentSource == Session.Source then
				Allowed,Reason = saoJudasContext(
					CurrentSource,Session.Passport,Session.Context,true,Session.Context == "laboratory"
				)
			end
			if not CurrentSource or CurrentSource ~= Session.Source then
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
			if CurrentSource == Session.Source then Player(CurrentSource).state.Buttons = false end
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
		tostring(saoJudasActiveSessions("workbench") + (SaoJudasStarting.workbench or 0)),tostring(SaoJudasOperations.Workbench.QueueCapacity),
		tostring(Session and Session.CraftId),tostring(Session and "processing" or "idle")
	))
end,false)
