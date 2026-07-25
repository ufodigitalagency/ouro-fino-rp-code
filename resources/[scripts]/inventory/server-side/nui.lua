-----------------------------------------------------------------------------------------------------------------------------------------
-- MOUNT
-----------------------------------------------------------------------------------------------------------------------------------------
-- Mantido temporariamente para identificar qualquer slot que interrompa a montagem da mochila.
local InventoryMountDebug = true

print("[inventory:mount] diagnostic hooks loaded")

local function MountDebug(Message)
	if not InventoryMountDebug then
		return
	end

	local Line = ("[%s] %s\n"):format(os.date("%Y-%m-%d %H:%M:%S"),Message)
	print("[inventory:mount] "..Message)

	local Resource = GetCurrentResourceName()
	local Previous = LoadResourceFile(Resource,"mount_debug.log") or ""
	SaveResourceFile(Resource,"mount_debug.log",(Previous..Line):sub(-30000),-1)
end

function Lil.Mount(Mode)
	local source = source
	local Passport = vRP.Passport(source)
	if Passport then
		local Primary = {}
		local InventorySuccess, Inv = pcall(function()
			return vRP.Inventory(Passport)
		end)

		if not InventorySuccess or type(Inv) ~= "table" then
			MountDebug(("inventory read failed | source=%s passport=%s error=%s"):format(source,Passport,tostring(Inv)))
			return Primary,0,Theme.inventory.slots.default
		end
		
		local InventoryCount = 0
		local PrimaryCount = 0
		for Slot,v in pairs(Inv) do
			InventoryCount = InventoryCount + 1
			local Success,Error = pcall(function()
				if v.amount <= 0 or not exports.vrp:ItemExist(v.item) then
					vRP.CleanSlot(Passport,Slot)
				else
					v.key = v.item

				local Split = splitString(v.item)
				local Item = Split[1]

				if not v.desc then
					if Item == "vehiclekey" and Split[3] then
						local Consult = exports["oxmysql"]:single_async("SELECT * FROM vehicles WHERE Plate = ? LIMIT 1",{ Split[3] })
						if Consult and exports.vrp:VehicleExist(Consult.Vehicle) then
							v.desc = "Proprietário: <common>"..vRP.FullName(Consult.Passport).."</common><br>Modelo: <common>"..exports.vrp:VehicleName(Consult.Vehicle).."</common><br>Placa: <common>"..Split[3].."</common>"
						end
					elseif Item == "propertys" and Split[2] then
						local Consult = exports["oxmysql"]:single_async("SELECT * FROM propertys WHERE Serial = ? LIMIT 1",{ Split[2] })
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
					PrimaryCount = PrimaryCount + 1
				end
			end)

			if not Success then
				MountDebug(("slot skipped | source=%s passport=%s slot=%s item=%s error=%s"):format(source,Passport,tostring(Slot),tostring(v and v.item),tostring(Error)))
			end
		end

		if Mode == "Blueprint" and Users["Blueprints"][Passport] then
			local Secondary = {}
			for Item,v in pairs(Users.Blueprints[Passport]) do
				if (not exports.vrp:ItemExist(Item) or not exports.vrp:ItemExist("blueprint_"..Item)) and Users.Blueprints[Passport][Item] then
					Users.Blueprints[Passport][Item] = nil
				else
					local Calculated = CountTable(Secondary)
					local Number = tostring(Calculated)

					Secondary[Number] = { key = Item, amount = 1 }

					if Crafting[Item] then
						Secondary[Number].required = Crafting[Item].Required
					end
				end
			end
			
			return Primary,Secondary,vRP.GetWeight(Passport),vRP.InventorySlots(Passport)
		end

		local Weight = vRP.GetWeight(Passport) or 0
		local Slots = vRP.InventorySlots(Passport) or Theme.inventory.slots.default
		if InventoryMountDebug then
			MountDebug(("completed | source=%s passport=%s inventory=%s primary=%s weight=%s slots=%s"):format(source,Passport,InventoryCount,PrimaryCount,Weight,Slots))
		end

		return Primary,Weight,Slots
	end

	if InventoryMountDebug then
		MountDebug(("denied | source=%s passport=nil"):format(source))
	end

	return {},0,Theme.inventory.slots.default
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- MISSIONS
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Missions()
	local List = {}
	local source = source
	local Passport = vRP.Passport(source)

	if not Passport then
		return List
	end

	local Consult = vRP.SimpleData(Passport,"Missions")
	for Index,v in pairs(Missions) do
		List[Index] = v
		List[Index].Active = Consult and Consult[v.Code] and true or false
	end

	return { Experience = vRP.GetExperience(Passport,"Missions"), Levels = TableLevel(), List = List }
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- RESCUEMISSION
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.RescueMission(Index)
	local source = source
	local Passport = vRP.Passport(source)

	if not Passport or not Missions[Index] then
		return false
	end

	local Code = Missions[Index].Code
	local Consult = vRP.SimpleData(Passport,"Missions")
	if not Code or (Consult and Consult[Code]) then
		return false
	end

	for Item,Amount in pairs(Missions[Index].Required) do
		if not vRP.ConsultItem(Passport,Item,Amount) then
			TriggerClientEvent("inventory:Notify",source,"Atenção","Precisa de <default>"..Dotted(Amount).."x "..exports.vrp:ItemName(Item).."</default>.","vermelho")
			return false
		end
	end

	for Item,Amount in pairs(Missions[Index].Required) do
		vRP.RemoveItem(Passport,Item,Amount)
	end

	for Item,Amount in pairs(Missions[Index].Rewards) do
		vRP.GenerateItem(Passport,Item,Amount)
	end

	if Missions[Index].Xp then
		vRP.PutExperience(Passport,"Missions",Missions[Index].Xp)
	end

	Consult = Consult or {}
	Consult[Code] = true

	vRP.Query("playerdata/SetData",{ Passport = Passport, Name = "Missions", Information = json.encode(Consult) })

	return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- CRAFTING
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Crafting(Item,Amount,Target)
	local source = source
	local Target = tostring(Target)
	local Amount = parseInt(Amount,true)
	local Passport = vRP.Passport(source)
	if Passport and Item and Target and Crafting[Item] then
		if Amount > 1 and (exports.vrp:ItemUnique(Item) or exports.vrp:ItemLoads(Item)) then
			Amount = 1
		end

		local Inventory = vRP.Inventory(Passport)
		local Multiplier = Crafting[Item].Amount * Amount
		if vRP.CheckWeight(Passport,Item,Multiplier) and (not Inventory[Target] or (Inventory[Target] and Inventory[Target].item == Item)) then
			if vRP.MaxItens(Passport,Item,Multiplier) then
				TriggerClientEvent("inventory:Notify",source,"Aviso","Limite atingido.","amarelo")

				return false
			end

			for Index,Value in pairs(Crafting[Item].Required) do
				if not vRP.ConsultItem(Passport,Index,Value * Amount) then
					TriggerClientEvent("inventory:Notify",source,"Atenção","Precisa de <default>"..Dotted(Value * Amount).."x "..exports.vrp:ItemName(Index).."</default>.","vermelho")

					return false
				end
			end

			for Index,Value in pairs(Crafting[Item].Required) do
				vRP.RemoveItem(Passport,vRP.InventoryItemAmount(Passport,Index)[2],Value * Amount)
			end

			vRP.GenerateItem(Passport,Item,Multiplier,false,Target)
			TriggerClientEvent("inventory:Blueprint",source)

			return true
		end
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- CALCULATE
-----------------------------------------------------------------------------------------------------------------------------------------
local function Calculate(Slots,Amount,Prices)
	local Quantity = math.floor(tonumber(Amount) or 0)

	local SlotsTable = Theme.inventory.slots

	local Extras = (tonumber(Slots) or 0) - (tonumber(SlotsTable.default) or 0)
	local Total = 0

	for Index = 1, Quantity do
		Total = Total + (Prices[math.min(Extras + Index, #Prices)] or 0)
	end

	return Total
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PURCHASESLOT
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.PurchaseSlot(Mode,Amount)
	local source = source
	local Passport = vRP.Passport(source)
	if Passport and Mode and Amount then
		local Slots = vRP.InventorySlots(Passport) or Theme.inventory.slots.default

		local Modes = {
			["Bank"] = function ()
				local Price = Calculate(Slots, Amount, Theme.inventory.slots.bank) 
				if vRP.PaymentBank(Passport,Price) then
					vRP.UpdateDatatable(Passport,"Slots",Slots + Amount)
					TriggerClientEvent("inventory:Update",source)
					return true
				end
			end,
			["Gemstone"] = function ()
				local Price = Calculate(Slots, Amount, Theme.inventory.slots.gemstone) 
				if vRP.PaymentGems(Passport,Price) then
					vRP.UpdateDatatable(Passport,"Slots",Slots + Amount)
					TriggerClientEvent("inventory:Update",source)
					return true
				end
			end
		}

		Modes[Mode]()
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- ONRESOURCESTOP
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("onResourceStop",function(Resource)
    if GetCurrentResourceName() ~= "inventory" then
        return
    end
    
    local List = vRP.Players()
    for Passport in pairs(List) do
        Users.Blueprints[Passport] = vRP.UserData(Passport,"Blueprints") or {}
    end
end)
