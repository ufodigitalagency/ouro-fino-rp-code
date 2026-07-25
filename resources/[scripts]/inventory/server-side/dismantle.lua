-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
Travel = {}
Boosting = {}
Dismantle = {}
-----------------------------------------------------------------------------------------------------------------------------------------
-- GENERATEPLATE
-----------------------------------------------------------------------------------------------------------------------------------------
exports("GeneratePlate",function()
	repeat
		Plate = GenerateString("LLDDDLLL")
	until Plate and not Dismantle[Plate] and not Boosting[Plate]

	return Plate
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- INVENTORY:BOOSTING
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("inventory:Boosting",function(Plate,Status)
	if not Boosting[Plate] then
		Boosting[Plate] = Status
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- GARAGES:DELETE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("garages:Delete")
AddEventHandler("garages:Delete",function(Network,Plate)
	if Plate then
		if Dismantle[Plate] then
			local source = vRP.Passport(Dismantle[Plate])
			if source then
				TriggerClientEvent("dismantle:Reset",source)
			end

			Dismantle[Plate] = nil
		end

		if Boosting[Plate] then
			local source = vRP.Passport(Boosting[Plate].Source)
			if source then
				TriggerClientEvent("boosting:Reset",Boosting[Plate].Source)
			end

			exports.boosting:Remove(Boosting[Plate].Passport,Plate)
			Boosting[Plate] = nil
		end
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- CREATEVEHICLE
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.CreateVehicle(Model,Coords)
	local source = source
	local Passport = vRP.Passport(source)
	if Passport then
		local CurrentTimer = os.time() + 10
		local Vehicle = CreateVehicle(Model,Coords,true,false)

		while not DoesEntityExist(Vehicle) or NetworkGetNetworkIdFromEntity(Vehicle) == 0 do
			if os.time() >= CurrentTimer then
				return false
			end

			Wait(100)
		end

		local Plate = exports.inventory:GeneratePlate()

		SetVehicleNumberPlateText(Vehicle,Plate)
		SetVehicleCustomPrimaryColour(Vehicle,math.random(255),math.random(255),math.random(255))
		SetVehicleCustomSecondaryColour(Vehicle,math.random(255),math.random(255),math.random(255))

		Entity(Vehicle).state:set("Nitro",0,true)
		Entity(Vehicle).state:set("Fuel",100,true)
		Entity(Vehicle).state:set("Tower",true,true)

		Dismantle[Plate] = source

		exports.vrp:CallPolice({
			Source = source,
			Passport = Passport,
			Permission = "Policia",
			Name = "Desmanche de Veículo",
			Vehicle = exports.vrp:VehicleName(Model).." - "..Plate,
			Coords = Coords,
			Code = 31,
			Color = 44
		})

		return NetworkGetNetworkIdFromEntity(Vehicle)
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- DISMANTLE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("inventory:Dismantle")
AddEventHandler("inventory:Dismantle",function(Entity)
	local source = source
	local Passport = vRP.Passport(source)
	if not Passport then
		return false
	end

	local Network = Entity[4]
	local Plate,Model = Entity[1],Entity[2]
	local UserVehicle = vRP.PassportPlate(Plate)
	if Active[Passport] or not exports.vrp:VehicleExist(Model) or (not UserVehicle and not Dismantle[Plate]) then
		return false
	end

	Active[Passport] = os.time() + 30
	Player(source).state.Buttons = true
	TriggerClientEvent("Progress",source,"Desmanchando",30000)
	vRPC.playAnim(source,false,{"anim@amb@clubhouse@tutorial@bkr_tut_ig3@","machinic_loop_mechandplayer"},true)

	CreateThread(function()
		while Active[Passport] and os.time() < Active[Passport] do
			Wait(100)
		end

		vRPC.Destroy(source)
		Player(source).state.Buttons = false

		if not Active[Passport] then
			return false
		end

		Active[Passport] = nil

		FinishDismantle(source,Passport,Network,Plate,Model,UserVehicle)
	end)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- FINISHDISMANTLE
-----------------------------------------------------------------------------------------------------------------------------------------
function FinishDismantle(source,Passport,Network,Plate,Model,UserVehicle,PaymentContext)
	if not source or not Passport or not Network or not Plate or not Model then
		return false
	end

	if (not UserVehicle and not Dismantle[Plate]) or (UserVehicle and not exports.garages:Spawn(Plate)) then
		return false
	end

	local GainExperience = 3
	local _,Level = vRP.GetExperience(Passport,"Dismantle")
	local Amount = exports.vrp:VehiclePrice(Model) * (UserVehicle and 0.05 or 0.025)
	local Valuation = Amount + (Amount * (0.025 * Level))

	if exports.inventory:Buffs("Dexterity",Passport) then
		Valuation = Valuation * 1.1
	end

	for Permission,Multiplier in pairs({ Ouro = 0.10, Prata = 0.075, Bronze = 0.05 }) do
		if vRP.HasService(Passport,Permission) then
			GainExperience = GainExperience + 1
			Valuation = Valuation * (1 + Multiplier)
		end
	end

	local Members = 1
	if exports.party:DoesExist(Passport,2) then
		Members = Members + 1
	end

	if UserVehicle and vRP.SingleQuery("vehicles/plateVehicles",{ Plate = Plate }) then
		vRP.Update("vehicles/Arrest",{ Plate = Plate })
	end

	local Reward = math.max(1,math.floor(Valuation * Members))
	local PombalPayment = PaymentContext and PaymentContext.Service == "chopshop"
	local Split = nil
	if PombalPayment then
		Split = exports.pombal_finance:SplitRevenue("chopshop",Passport,Reward,PaymentContext.Reference)
		if not Split or not Split.Success then
			return false
		end
	end

	TriggerClientEvent("dismantle:Reset",source)
	TriggerEvent("garages:Deleted",Network,Plate)

	vRP.BattlepassPoints(Passport,GainExperience)
	vRP.PutExperience(Passport,"Dismantle",GainExperience)
	if PombalPayment then
		vRP.GenerateItem(Passport,"dirtydollar",Split.WorkerAmount,true)
		TriggerClientEvent("Notify",source,"Desmanche do Pombal",("Voce recebeu <b>$%s</b>. A parte da faccao foi enviada ao cofre."):format(Dotted(Split.WorkerAmount)),"verde",5000)
	else
		vRP.GenerateItem(Passport,"ironfilings",Reward,true)
	end
	return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- EXPERIENCE
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Experience()
	local source = source
	local Passport = vRP.Passport(source)

	return Passport and vRP.GetExperience(Passport,"Dismantle") or 0
end
