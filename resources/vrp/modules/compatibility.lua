-----------------------------------------------------------------------------------------------------------------------------------------
-- COMPATIBILITY LAYER: CreativeV2 → Nossa Base
-- Mapeia funções legadas (camelCase) da CreativeV2 para nossas funções (PascalCase)
-- Isso permite que scripts da CreativeV2 funcionem na nossa base sem modificação pesada
-----------------------------------------------------------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------------------------------------------------------
-- BASE FUNCTIONS
-----------------------------------------------------------------------------------------------------------------------------------------
vRP.getUserId = vRP.Passport
vRP.getUserSource = vRP.Source
vRP.userSource = vRP.Source
vRP.getDatatable = vRP.Datatable

-----------------------------------------------------------------------------------------------------------------------------------------
-- PERMISSION/GROUP FUNCTIONS
-----------------------------------------------------------------------------------------------------------------------------------------
vRP.hasPermission = vRP.HasPermission
vRP.hasGroup = vRP.HasGroup
vRP.hasService = vRP.HasService
vRP.setPermission = vRP.SetPermission
vRP.removePermission = vRP.RemovePermission
vRP.userGroups = vRP.UserGroups

-----------------------------------------------------------------------------------------------------------------------------------------
-- MONEY FUNCTIONS
-----------------------------------------------------------------------------------------------------------------------------------------
vRP.paymentBank = vRP.PaymentBank
vRP.tryFullPayment = vRP.PaymentFull
vRP.giveBank = vRP.GiveBank
vRP.removeBank = vRP.RemoveBank
vRP.getBank = vRP.GetBank

-----------------------------------------------------------------------------------------------------------------------------------------
-- INVENTORY FUNCTIONS
-----------------------------------------------------------------------------------------------------------------------------------------
vRP.generateItem = vRP.GenerateItem
vRP.giveItem = vRP.GiveItem
vRP.takeItem = vRP.TakeItem
vRP.removeItem = vRP.RemoveItem
vRP.itemAmount = vRP.ItemAmount
vRP.userInventory = vRP.Inventory

-----------------------------------------------------------------------------------------------------------------------------------------
-- PLAYER FUNCTIONS
-----------------------------------------------------------------------------------------------------------------------------------------
vRP.teleport = vRP.Teleport
vRP.upgradeThirst = vRP.UpgradeThirst
vRP.upgradeHunger = vRP.UpgradeHunger
vRP.downgradeThirst = vRP.DowngradeThirst
vRP.downgradeHunger = vRP.DowngradeHunger
vRP.getHealth = vRP.GetHealth

-----------------------------------------------------------------------------------------------------------------------------------------
-- USER DATA FUNCTIONS (key mapping for CreativeV2's getUData/_setUData)
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.getUData(Passport, Key)
	return vRP.UserData(Passport, Key)
end

function vRP._setUData(Passport, Key, Value)
	vRP.Query("playerdata/SetData", { Passport = Passport, Name = Key, Information = Value })
end

function vRP.setUData(Passport, Key, Value)
	vRP.Query("playerdata/SetData", { Passport = Passport, Name = Key, Information = Value })
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- PLAYER LIST (legacy compatibility)
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.userList()
	return Sources
end

function vRP.getPlayesOn()
	return Sources
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- KICK (legacy compatibility)
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.kick(Passport, Reason)
	local source = vRP.Source(Passport)
	if source then
		vRP.Kick(source, Reason or "Expulso")
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- MISC UTILITIES (from CreativeV2 utils.lua that our base may not have)
-----------------------------------------------------------------------------------------------------------------------------------------
if not parseFormat then
	function parseFormat(number)
		local left,num,right = string.match(parseInt(number),"^([^%d]*%d)(%d*)(.-)$")
		return left..(num:reverse():gsub("(%d%d%d)","%1."):reverse())..right
	end
end

if not completeTimers then
	function completeTimers(Seconds)
		local Days = math.floor(Seconds / 86400)
		Seconds = Seconds - Days * 86400
		local Hours = math.floor(Seconds / 3600)
		Seconds = Seconds - Hours * 3600
		local Minutes = math.floor(Seconds / 60)
		Seconds = Seconds - Minutes * 60

		if Days > 0 then
			return string.format("<b>%d Dias</b>, <b>%d Horas</b>, <b>%d Minutos</b>",Days,Hours,Minutes)
		elseif Hours > 0 then
			return string.format("<b>%d Horas</b>, <b>%d Minutos</b> e <b>%d Segundos</b>",Hours,Minutes,Seconds)
		elseif Minutes > 0 then
			return string.format("<b>%d Minutos</b> e <b>%d Segundos</b>",Minutes,Seconds)
		elseif Seconds > 0 then
			return string.format("<b>%d Segundos</b>",Seconds)
		end
	end
end

if not mathLegth then
	function mathLegth(n)
		return math.ceil(n * 100) / 100
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- SERVER DATA FUNCTIONS (Bennys, etc.)
-----------------------------------------------------------------------------------------------------------------------------------------
vRP.getSrvdata = vRP.GetSrvData
vRP.setSrvdata = vRP.SetSrvData
vRP.getSrvData = vRP.GetSrvData
vRP.setSrvData = vRP.SetSrvData
vRP.paymentFull = vRP.PaymentFull

-----------------------------------------------------------------------------------------------------------------------------------------
-- VEHICLE / PLATE FUNCTIONS
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.userPlate(Plate)
	local Consult = vRP.SingleQuery("vehicles/plateVehicles", { Plate = Plate })
	if Consult then
		return { user_id = Consult.Passport, vehicle = Consult.Vehicle, plate = Consult.Plate }
	end
	return false
end

vRP.passportPlate = vRP.PassportPlate
vRP.generatePlate = vRP.GeneratePlate
vRP.selectVehicle = vRP.SelectVehicle

-----------------------------------------------------------------------------------------------------------------------------------------
-- IDENTITY FUNCTIONS
-----------------------------------------------------------------------------------------------------------------------------------------
vRP.identity = vRP.Identity
vRP.fullName = vRP.FullName
vRP.lowerName = vRP.LowerName

-----------------------------------------------------------------------------------------------------------------------------------------
-- SERVICE / GROUPS EXTRA
-----------------------------------------------------------------------------------------------------------------------------------------
vRP.serviceToggle = vRP.ServiceToggle
vRP.serviceEnter = vRP.ServiceEnter
vRP.serviceLeave = vRP.ServiceLeave
vRP.amountService = vRP.AmountService
vRP.numPermission = vRP.NumPermission

-----------------------------------------------------------------------------------------------------------------------------------------
-- EXPERIENCE
-----------------------------------------------------------------------------------------------------------------------------------------
vRP.getExperience = vRP.GetExperience
vRP.putExperience = vRP.PutExperience

-----------------------------------------------------------------------------------------------------------------------------------------
-- DATABASE FUNCTIONS (cfWorks uses vRP._prepare, vRP.query, vRP.execute)
-----------------------------------------------------------------------------------------------------------------------------------------
vRP._prepare = vRP.Prepare
vRP.prepare = vRP.Prepare
vRP.query = vRP.Query
vRP.execute = vRP.Execute
vRP.singleQuery = vRP.SingleQuery

-----------------------------------------------------------------------------------------------------------------------------------------
-- IDENTITY EXTENDED (cfWorks uses vRP.userIdentity)
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.userIdentity(Passport)
	local Identity = vRP.Identity(Passport)
	if Identity then
		return {
			name = Identity.Name or "Desconhecido",
			name2 = Identity.Lastname or "",
			firstname = Identity.Name or "Desconhecido",
			lastname = Identity.Lastname or "",
			age = Identity.Age or 18,
			phone = Identity.Phone or "",
			passport = Passport
		}
	end
	return { name = "Desconhecido", name2 = "", firstname = "Desconhecido", lastname = "" }
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- BANK MONEY (cfWorks uses vRP.getBankMoney)
-----------------------------------------------------------------------------------------------------------------------------------------
vRP.getBankMoney = vRP.GetBank

-----------------------------------------------------------------------------------------------------------------------------------------
-- INVENTORY (cfWorks uses vRP.giveInventoryItem)
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.giveInventoryItem(Passport, Item, Amount)
	if Item == "dollars" or Item == "dollar" then
		vRP.GiveBank(Passport, Amount, true)
	else
		vRP.GenerateItem(Passport, Item, Amount, true)
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- USER DATA EXTENDED (barbershop uses vRP.userData, vRP.getUserDataTable)
-----------------------------------------------------------------------------------------------------------------------------------------
vRP.userData = vRP.UserData
vRP.simpleData = vRP.SimpleData

function vRP.getUserDataTable(Passport)
	return vRP.Datatable(Passport) or {}
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- CASH FUNCTIONS (skinshop uses vRP.withdrawCash)
-----------------------------------------------------------------------------------------------------------------------------------------
vRP.withdrawCash = vRP.WithdrawCash

-----------------------------------------------------------------------------------------------------------------------------------------
-- LOG
-----------------------------------------------------------------------------------------------------------------------------------------
print("^2[VRP]^7 Camada de compatibilidade CreativeV2 carregada com sucesso.")


