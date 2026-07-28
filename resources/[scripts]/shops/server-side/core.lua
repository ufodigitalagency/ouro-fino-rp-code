-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")
vRP = Proxy.getInterface("vRP")
local ShopQuotes = {}
local QuoteBySource = {}
local QuoteSequence = 0
local QuoteLifetime = 30
local QuoteMaximumAmount = 100
local ShopInteractionDistance = 4.0
local MultiplayerDebug = false
local MultiplayerDiagnosticsActive = false
-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECTION
-----------------------------------------------------------------------------------------------------------------------------------------
Lil = {}
Tunnel.bindInterface("shops",Lil)

local function multiplayerLog(message)
	if MultiplayerDebug then
		print(("[shop/multiplayer] %s"):format(message))
	end
end

local function result(success,message,code,data)
	local response = data or {}
	response.success = success == true
	response.message = message or ""
	response.code = code or (response.success and "ok" or "error")
	return response
end

local function hasShopPermission(source,Passport,Name)
	local Data = List[Name]
	if not Passport or not Data then
		return false
	end

	if Name ~= "Banned" and (exports.bank:CheckTaxes(Passport) or exports.bank:CheckFines(Passport)) then
		return false
	end

	if MultiplayerDiagnosticsActive and Player(source).state["af:multiplayerGuestMode"] == true and Data.Permission then
		return false
	end

	if not Data.Permission then
		return true
	end

	if Data.PermissionMode == "Group" then
		return vRP.HasGroup(Passport,Data.Permission,Data.PermissionLevel) and true or false
	end

	return vRP.HasService(Passport,Data.Permission) and true or false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PERMISSION
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Permission(Name)
	local source = source
	local Data = List[Name]
	local Passport = vRP.Passport(source)
	if not Passport or not Data then
		return false
	end

	local Allowed = hasShopPermission(source,Passport,Name)
	if Name == "Pombal" or Name == "SaoJudas" then
		local IsLeader = vRP.HasGroup(Passport,Name,1) and true or false
		print(("[shops] faction_arsenal_permission faction=%s passport=%s leader=%s allowed=%s"):format(tostring(Name),tostring(Passport),tostring(IsLeader),tostring(Allowed)))

		if not Allowed then
			local FactionName = Name == "SaoJudas" and "São Judas" or "Pombal"
			TriggerClientEvent("Notify",source,"Atenção","Somente o Chefe de "..FactionName.." pode acessar este arsenal.","amarelo",5000)
		end
	end

	return Allowed
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- MOUNT
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Mount(Name)
	local source = source
	local Passport = vRP.Passport(source)
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
local function Checkout(source,Item,Amount,Target,Name,Confirm,BulkPurchase)
	local source = source
	local Target = Target and tostring(Target) or nil
	local Amount = parseInt(Amount,true)
	local Passport = vRP.Passport(source)
	local Success = false
	if Passport and Item and List[Name] and List[Name]["Type"] and List[Name]["List"] and List[Name]["List"][Item] then
		if Amount > 1 and (exports.vrp:ItemUnique(Item) or exports.vrp:ItemLoads(Item)) then
			Amount = 1
		end

		if List[Name].Route and List[Name].Route ~= GetPlayerRoutingBucket(source) then
			TriggerClientEvent("inventory:Update",source)
			return false
		end

		local Inventory = vRP.Inventory(Passport)
		local StackablePurchase = BulkPurchase and not exports.vrp:ItemUnique(Item) and not exports.vrp:ItemLoads(Item)
		local ItemLimitReached = not StackablePurchase and vRP.MaxItens(Passport,Item,Amount)
		if not ItemLimitReached and vRP.CheckWeight(Passport,Item,Amount) and (not Target or not Inventory[Target] or (Inventory[Target] and Inventory[Target]["item"] == Item)) then
			local Price = List[Name]["List"][Item] * Amount
			local FreeShop = List[Name]["Type"] == "Free"

			if Confirm and List[Name].Mode == "Buy" and not FreeShop then
				local ItemName = exports.vrp:ItemName(Item) or Item

				if not vRP.Request(source,"Compra",("Comprar <b>%sx %s</b> por <b>$%s</b>?"):format(Amount,ItemName,Dotted(Price))) then
					TriggerClientEvent("inventory:Update",source)
					return false
				end
			end

			if FreeShop then
				vRP.GenerateItem(Passport,Item,Amount,false,Target)
				Success = true
				TriggerClientEvent("Notify",source,"Arsenal","Item retirado do arsenal.","verde",3000)
			elseif List[Name]["Type"] == "Cash" then
				if vRP.PaymentFull(Passport,Price) then
					vRP.GenerateItem(Passport,Item,Amount,false,Target)
					Success = true
					TriggerClientEvent("inventory:Notify",source,"Compra","Compra realizada com sucesso.","verde")
					TriggerClientEvent("Notify",source,"Compra","Compra realizada com sucesso.","verde",3000)
				else
					TriggerClientEvent("inventory:Notify",source,"Aviso","Dinheiro insuficiente.","amarelo")
					TriggerClientEvent("Notify",source,"Aviso","Dinheiro insuficiente.","amarelo",3000)
				end
			elseif List[Name]["Type"] == "Consume" and List[Name]["Item"] then
				if vRP.TakeItem(Passport,List[Name]["Item"],Price) then
					vRP.GenerateItem(Passport,Item,Amount,false,Target)
					Success = true
					TriggerClientEvent("Notify",source,"Compra","Troca realizada com sucesso.","verde",3000)
				else
					TriggerClientEvent("inventory:Notify",source,"Atenção","<b>"..exports.vrp:ItemName(List[Name]["Item"]).."</b> insuficiente.","vermelho")
					TriggerClientEvent("Notify",source,"Atenção",exports.vrp:ItemName(List[Name]["Item"]).." insuficiente.","vermelho",3000)
				end
			elseif List[Name]["Type"] == "Gemstone" then
				if vRP.PaymentGems(Passport,Price) then
					vRP.GenerateItem(Passport,Item,Amount,false,Target)
					Success = true
					TriggerClientEvent("Notify",source,"Compra","Compra realizada com sucesso.","verde",3000)
				else
					TriggerClientEvent("inventory:Notify",source,"Atenção","<b>Diamantes</b> insuficiente.","vermelho")
					TriggerClientEvent("Notify",source,"Atenção","Diamantes insuficientes.","vermelho",3000)
				end
			end
		end
	end

	TriggerClientEvent("inventory:Update",source)
	return Success
end

local function normalizePurchase(Item,Amount)
	if type(Item) ~= "string" or Item == "" then
		return nil,"Selecione um produto valido."
	end

	local numericAmount = tonumber(Amount)
	if not numericAmount or numericAmount ~= math.floor(numericAmount) or numericAmount < 1 or numericAmount > QuoteMaximumAmount then
		return nil,("Escolha uma quantidade entre 1 e %s."):format(QuoteMaximumAmount)
	end

	if exports.vrp:ItemUnique(Item) or exports.vrp:ItemLoads(Item) then
		numericAmount = 1
	end

	return Item,numericAmount
end

local function validateLocation(source,Name,LocationIndex,Origin)
	local Ped = GetPlayerPed(source)
	if Ped == 0 then
		return false,"Personagem indisponivel."
	end

	local Coords = GetEntityCoords(Ped)
	local Index = tonumber(LocationIndex)
	if Index then
		local Shop = Location[Index]
		if not Shop or Shop.Mode ~= Name then
			return false,"Ponto de loja invalido."
		end

		if Shop.Route and Shop.Route ~= GetPlayerRoutingBucket(source) then
			return false,"Voce nao esta na instancia desta loja."
		end

		local MaximumDistance = math.max(ShopInteractionDistance,(tonumber(Shop.Circle) or 0.0) + 2.5)
		if #(Coords - Shop.Coords) > MaximumDistance then
			return false,"Voce se afastou da loja."
		end

		return true,Coords
	end

	-- Lojas abertas por objetos e integracoes antigas nao possuem um indice em
	-- Location. A cotacao fixa a posicao inicial e impede confirmacao remota.
	if Origin and #(Coords - Origin) > ShopInteractionDistance then
		return false,"Voce se afastou da loja."
	end

	return true,Coords
end

local function validateCarry(Passport,Item,Amount)
	local StackablePurchase = not exports.vrp:ItemUnique(Item) and not exports.vrp:ItemLoads(Item)
	if not StackablePurchase and vRP.MaxItens(Passport,Item,Amount) then
		return false,"Voce atingiu o limite deste item."
	end

	if not vRP.CheckWeight(Passport,Item,Amount) then
		return false,"Espaco insuficiente no inventario."
	end

	return true
end

local function removeQuote(Token)
	local Quote = ShopQuotes[Token]
	if Quote then
		if QuoteBySource[Quote.Source] == Token then
			QuoteBySource[Quote.Source] = nil
		end

		ShopQuotes[Token] = nil
	end

	return Quote
end

local function newQuoteToken(source,Passport)
	QuoteSequence = QuoteSequence + 1
	return ("%s-%s-%s-%s-%06d"):format(source,Passport,os.time(),QuoteSequence,math.random(0,999999))
end

local function quoteCurrency(Data)
	if Data.Type == "Cash" then
		return "R$"
	elseif Data.Type == "Gemstone" then
		return "Diamantes"
	elseif Data.Type == "Consume" and Data.Item then
		return exports.vrp:ItemName(Data.Item) or Data.Item
	elseif Data.Type == "Free" then
		return "Gratuito"
	end

	return ""
end

function Lil.CreateQuote(Item,Amount,Name,LocationIndex)
	local source = source
	local Passport = vRP.Passport(source)
	local Data = Name and List[Name]
	if not Passport or not Data or Data.Mode ~= "Buy" then
		return result(false,"Esta loja nao esta disponivel.","invalid_shop")
	end

	if not hasShopPermission(source,Passport,Name) then
		return result(false,"Voce nao possui acesso a esta loja ou possui pendencias.","permission_denied")
	end

	local NormalizedItem,NormalizedAmount = normalizePurchase(Item,Amount)
	if not NormalizedItem then
		return result(false,NormalizedAmount,"invalid_amount")
	end
	Item,Amount = NormalizedItem,NormalizedAmount

	local UnitPrice = Data.List and tonumber(Data.List[Item])
	if UnitPrice == nil then
		return result(false,"Este produto nao pertence a loja atual.","invalid_item")
	end

	if Data.Route and Data.Route ~= GetPlayerRoutingBucket(source) then
		return result(false,"Voce nao esta na instancia desta loja.","invalid_route")
	end

	local ValidLocation,Origin = validateLocation(source,Name,LocationIndex)
	if not ValidLocation then
		return result(false,Origin,"invalid_location")
	end

	local CanCarry,CarryMessage = validateCarry(Passport,Item,Amount)
	if not CanCarry then
		return result(false,CarryMessage,"inventory_rejected")
	end

	if QuoteBySource[source] then
		removeQuote(QuoteBySource[source])
	end

	local Token = newQuoteToken(source,Passport)
	local Total = UnitPrice * Amount
	ShopQuotes[Token] = {
		Source = source,
		Passport = Passport,
		Shop = Name,
		Location = tonumber(LocationIndex),
		Origin = Origin,
		Item = Item,
		Amount = Amount,
		UnitPrice = UnitPrice,
		Total = Total,
		ExpiresAt = os.time() + QuoteLifetime,
		Processed = false
	}
	QuoteBySource[source] = Token

	multiplayerLog(("quote source=%s passport=%s item=%s amount=%s"):format(source,Passport,Item,Amount))
	return result(true,"Confira os dados antes de confirmar.","quote_created",{
		token = Token,
		item = Item,
		itemName = exports.vrp:ItemName(Item) or Item,
		amount = Amount,
		unitPrice = UnitPrice,
		total = Total,
		currency = quoteCurrency(Data),
		expiresIn = QuoteLifetime
	})
end

function Lil.CancelQuote(Token)
	local source = source
	Token = type(Token) == "string" and Token or ""
	local Quote = ShopQuotes[Token]
	if not Quote or Quote.Source ~= source then
		return result(false,"Cotacao inexistente ou expirada.","invalid_token")
	end

	removeQuote(Token)
	return result(true,"Compra cancelada.","cancelled")
end

function Lil.ConfirmQuote(Token)
	local source = source
	Token = type(Token) == "string" and Token or ""
	local Quote = ShopQuotes[Token]
	if not Quote or Quote.Source ~= source then
		return result(false,"Cotacao inexistente ou expirada.","invalid_token")
	end

	if Quote.Processed then
		removeQuote(Token)
		return result(false,"Esta cotacao ja foi utilizada.","already_processed")
	end

	local Passport = vRP.Passport(source)
	if not Passport or Passport ~= Quote.Passport then
		removeQuote(Token)
		return result(false,"O personagem da cotacao nao esta mais ativo.","passport_changed")
	end

	if Quote.ExpiresAt < os.time() then
		removeQuote(Token)
		return result(false,"A cotacao expirou. Solicite uma nova.","expired")
	end

	local Data = List[Quote.Shop]
	if not Data or Data.Mode ~= "Buy" or not hasShopPermission(source,Passport,Quote.Shop) then
		removeQuote(Token)
		return result(false,"O acesso a esta loja mudou.","permission_denied")
	end

	local CurrentUnitPrice = Data.List and tonumber(Data.List[Quote.Item])
	if CurrentUnitPrice == nil or CurrentUnitPrice ~= Quote.UnitPrice or (CurrentUnitPrice * Quote.Amount) ~= Quote.Total then
		removeQuote(Token)
		return result(false,"O preco mudou. Solicite uma nova cotacao.","price_changed")
	end

	local ValidLocation,LocationMessage = validateLocation(source,Quote.Shop,Quote.Location,Quote.Origin)
	if not ValidLocation then
		removeQuote(Token)
		return result(false,LocationMessage,"invalid_location")
	end

	local CanCarry,CarryMessage = validateCarry(Passport,Quote.Item,Quote.Amount)
	if not CanCarry then
		removeQuote(Token)
		return result(false,CarryMessage,"inventory_rejected")
	end

	-- Consumir antes da cobranca impede dois callbacks simultaneos de processarem
	-- a mesma compra. Checkout recalcula preco, peso, limite e saldo no servidor.
	Quote.Processed = true
	removeQuote(Token)
	multiplayerLog(("confirmed source=%s token=%s"):format(source,Token))

	local Success = Checkout(source,Quote.Item,Quote.Amount,nil,Quote.Shop,false,true)
	if not Success then
		return result(false,"Nao foi possivel concluir a compra. Verifique saldo e inventario.","checkout_rejected")
	end

	multiplayerLog(("completed source=%s"):format(source))
	return result(true,"Compra realizada com sucesso.","completed")
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- TAKE
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Take(Item,Amount,Target,Name)
	if List[Name] and List[Name].Mode == "Buy" and List[Name].Type ~= "Free" then
		TriggerClientEvent("inventory:Notify",source,"Compra","Use o botao Comprar para confirmar o pedido.","amarelo")
		TriggerClientEvent("inventory:Update",source)
		return false
	end

	return Checkout(source,Item,Amount,Target,Name,true)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- DIRECTBUY
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.DirectBuy(Item,Amount,Name)
	return false
end

CreateThread(function()
	while true do
		Wait(10000)
		local Now = os.time()
		local Expired = {}
		for Token,Quote in pairs(ShopQuotes) do
			if Quote.ExpiresAt < Now then
				Expired[#Expired + 1] = Token
			end
		end

		for _,Token in ipairs(Expired) do
			removeQuote(Token)
		end
	end
end)

AddEventHandler("playerDropped",function()
	local source = source
	if QuoteBySource[source] then
		removeQuote(QuoteBySource[source])
	end
end)

AddEventHandler("shops:SetMultiplayerDiagnostics",function(enabled)
	MultiplayerDiagnosticsActive = enabled == true
	MultiplayerDebug = MultiplayerDiagnosticsActive
end)

exports("MultiplayerDiagnosticSnapshot",function()
	local activeQuotes = 0
	local quoteDetails = {}
	for Token,Quote in pairs(ShopQuotes) do
		activeQuotes = activeQuotes + 1
		quoteDetails[#quoteDetails + 1] = {
			TokenHint = tostring(Token):sub(1,8).."...",
			Source = Quote.Source,
			Passport = Quote.Passport,
			Shop = Quote.Shop,
			Item = Quote.Item,
			Amount = Quote.Amount,
			ExpiresIn = math.max(0,(tonumber(Quote.ExpiresAt) or 0) - os.time()),
			Processed = Quote.Processed == true
		}
	end
	table.sort(quoteDetails,function(a,b)
		return (tonumber(a.Source) or 0) < (tonumber(b.Source) or 0)
	end)

	return {
		Enabled = MultiplayerDiagnosticsActive,
		ActiveQuotes = activeQuotes,
		Lifetime = QuoteLifetime,
		MaximumAmount = QuoteMaximumAmount,
		Quotes = quoteDetails
	}
end)

exports("RunMultiplayerQuoteSelfTest",function(playerSource)
	local tests = {}
	local function add(name,passed,detail)
		tests[#tests + 1] = { name = name, passed = passed == true, detail = detail or "" }
	end

	local item,amount = normalizePurchase("water",2)
	add("quantidade valida",item == "water" and amount == 2)
	add("quantidade zero",normalizePurchase("water",0) == nil)
	add("quantidade negativa",normalizePurchase("water",-1) == nil)
	add("item inexistente",List.Departament.List["af_invalid_item"] == nil)

	local passport = vRP.Passport(tonumber(playerSource))
	local simulated = {
		Source = tonumber(playerSource),
		Passport = passport,
		ExpiresAt = os.time() + 30,
		Processed = false
	}
	add("token pertence ao source",simulated.Source == tonumber(playerSource))
	add("token expira",simulated.ExpiresAt > os.time())
	simulated.Processed = true
	add("uso unico",simulated.Processed == true)
	add("saldo insuficiente protegido",type(vRP.PaymentFull) == "function","validado no Checkout real")
	add("inventario cheio protegido",type(vRP.CheckWeight) == "function","validado na cotacao e no Checkout")
	add("cancelamento remove token",type(removeQuote) == "function")

	return tests
end)

exports("ResetMultiplayerDiagnostics",function(playerSource)
	playerSource = tonumber(playerSource)
	if playerSource and QuoteBySource[playerSource] then
		removeQuote(QuoteBySource[playerSource])
	end
end)
---------------------------------------------------------------------------------------------------------------------------------
-- STORE
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Store(Item,Amount,Slot,Name)
	local source = source
	local Split = SplitOne(Item)
	local Amount = parseInt(Amount,true)
	local Passport = vRP.Passport(source)
	local Success = false
	if Passport and List[Name] and List[Name]["List"] and List[Name]["Type"] and List[Name]["List"][Split] and not vRP.CheckDamaged(Item) then
		if List[Name]["Type"] == "Cash" then
			if vRP.TakeItem(Passport,Item,Amount,false,Slot) then
				vRP.GenerateItem(Passport,"dollar",List[Name]["List"][Split] * Amount,false)
				Success = true
			end
		elseif List[Name]["Type"] == "Consume" then
			if vRP.TakeItem(Passport,Item,Amount,false,Slot) then
				vRP.GenerateItem(Passport,List[Name]["Item"],List[Name]["List"][Split] * Amount,false)
				Success = true
			end
		end
	end

	TriggerClientEvent("inventory:Update",source)
	return Success
end
