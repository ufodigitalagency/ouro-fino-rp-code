-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
Proxy = module("lib/Proxy")
Tunnel = module("lib/Tunnel")
vRPC = Tunnel.getInterface("vRP")
-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECTION
-----------------------------------------------------------------------------------------------------------------------------------------
vRP = {}
tvRP = {}
-----------------------------------------------------------------------------------------------------------------------------------------
-- TUNNER/PROXY
-----------------------------------------------------------------------------------------------------------------------------------------
Proxy.addInterface("vRP",vRP)
Tunnel.bindInterface("vRP",tvRP)
DEVICE = Tunnel.getInterface("device")
REQUEST = Tunnel.getInterface("request")
TASKBAR = Tunnel.getInterface("taskbar")
SURVIVAL = Tunnel.getInterface("survival")
KEYBOARD = Tunnel.getInterface("keyboard")
LETTERGAME = Tunnel.getInterface("lettergame")
-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADSERVERSTART
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	SetMapName(ServerName)
	SetGameType(ServerName)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- CLEARINVENTORY
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.ClearInventory(Passport,Ignore)
	local Passport = parseInt(Passport)
	local Inventory = vRP.Inventory(Passport)

	exports.inventory:CleanWeapons(Passport)
	TriggerEvent("DebugWeapons",Passport)
	TriggerEvent("DebugObjects",Passport)

	for _,v in pairs(Inventory) do
		if not exports.vrp:BlockDelete(v.item) then
			vRP.RemoveItem(Passport,v.item,v.amount)
		end
	end

	if not Ignore then
		local Weight = 50
		for Permission,Multiplier in pairs({ Ouro = 25, Prata = 15, Bronze = 5 }) do
			if vRP.HasService(Passport,Permission) then
				Weight = Weight - Multiplier
			end
		end

		if Weight > 0 then
			vRP.UpgradeWeight(Passport,Weight,"-")
		end
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PHONE
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.Phone(Passport)
	local PhoneNumber = "Inativo"
	local source = vRP.Source(Passport)

	if source and Characters[source] and Characters[source].Phone then
		PhoneNumber = Characters[source].Phone
	else
		local Consult = vRP.SingleQuery("smartphone/Phone",{ Passport = tostring(Passport) })
		if Consult and Consult.phone_number then
			PhoneNumber = Consult.phone_number

			if source and Characters[source] then
				Characters[source].Phone = PhoneNumber
			end
		end
	end

	if PhoneNumber ~= "Inativo" and GetResourceState("lb-phone") == "started" then
		return exports["lb-phone"]:FormatNumber(PhoneNumber)
	end

	return PhoneNumber
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- CLEANPHONE
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.CleanPhone(Passport)
	local Consult = vRP.SingleQuery("smartphone/Phone",{ Passport = tostring(Passport) })
	return Consult and Consult.phone_number or false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP.REQUEST
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.Request(source,Title,Message)
	return REQUEST.Function(source,Title,Message)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP.REVIVE
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.Revive(source,Health,Arena)
	return SURVIVAL.Revive(source,Health,Arena)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP.TASK
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.Task(source,Amount,Speed)
	return TASKBAR.Task(source,Amount,Speed)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP.DEVICE
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.Device(source,Seconds)
    return DEVICE.Device(source,Seconds)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP.LETTERGAME
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.LetterGame(source,Duration,Speed)
    return LETTERGAME.LetterGame(source,Duration,Speed)
end
