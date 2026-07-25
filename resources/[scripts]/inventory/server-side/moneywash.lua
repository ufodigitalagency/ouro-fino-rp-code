-----------------------------------------------------------------------------------------------------------------------------------------
-- ITENS
-----------------------------------------------------------------------------------------------------------------------------------------
local Itens = {
	promissory1000 = {
		Value = 1000,
		Percentage = 0.750,
		Permission = 0.950,
		Police = 875
	},
	promissory2000 = {
		Value = 2000,
		Percentage = 0.725,
		Permission = 0.925,
		Police = 775
	},
	promissory3000 = {
		Value = 3000,
		Percentage = 0.700,
		Permission = 0.900,
		Police = 675
	},
	promissory4000 = {
		Value = 4000,
		Percentage = 0.675,
		Permission = 0.875,
		Police = 575
	},
	promissory5000 = {
		Value = 5000,
		Percentage = 0.650,
		Permission = 0.850,
		Police = 475
	}
}
-----------------------------------------------------------------------------------------------------------------------------------------
-- WASHERS
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Washers(Value)
	local source = source
	local Passport = vRP.Passport(source)
	if not Passport then
		return false
	end

	local ItemName = "wetdollar"
	local RewardItem = "promissory"..Value
	local Data = Itens[RewardItem]

	if vRP.TakeItem(Passport,ItemName,Value) and Data then
		exports.vrp:CallPolice({
			Source = source,
			Passport = Passport,
			Permission = "Policia",
			Name = "Lavagem de Dinheiro",
			Percentage = Data.Police,
			Wanted = 60,
			Code = 31,
			Color = 22
		})

		vRP.GenerateItem(Passport,RewardItem,1,true)

		return true
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- MONEYWASH:SWAP
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("moneywash:Swap")
AddEventHandler("moneywash:Swap",function()
	local source = source
	local Passport = vRP.Passport(source)
	if not Passport then
		return false
	end

	local Notify = false
	for ItemName,v in pairs(Itens) do
		local Amount,FullName = table.unpack(vRP.InventoryItemAmount(Passport,ItemName))

		if Amount > 0 and FullName ~= "" then
			if vRP.TakeItem(Passport,FullName,Amount) then
				local Multiplier = vRP.HasGroup(Passport,"MoneyWash") and v.Permission or v.Percentage
				local Total = v.Value * Multiplier

				vRP.GenerateItem(Passport,"dollar",Amount * Total)
				Notify = true
			end
		end
	end

	if Notify then
		TriggerClientEvent("Notify",source,"Sucesso","Troca concluída.","verde",5000)
	else
		TriggerClientEvent("Notify",source,"Aviso","Promissórias não encontradas.","amarelo",5000)
	end
end)