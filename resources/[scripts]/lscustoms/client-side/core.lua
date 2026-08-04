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
Tunnel.bindInterface("lscustoms",Lil)
vSERVER = Tunnel.getInterface("lscustoms")
-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Initial = {}
local Focus = false
local Opened = false
local Information = {}
local HornPreviewAt = 0

local CategoryLabels = {
	Respray = "Pintura",
	Wheels = "Rodas",
	VehicleExtras = "Extras",
	WindowTint = "Insulfilm",
	Xenons = "Farois xenon",
	Turbo = "Turbo",
	Neons = "Neon",
	PlateHolder = "Placa",
	Spoiler = "Aerofolio",
	FrontBumper = "Parachoque dianteiro",
	RearBumper = "Parachoque traseiro",
	SideSkirt = "Saias laterais",
	Exhaust = "Escapamento",
	RollCage = "Santo antonio",
	Grille = "Grade",
	Hood = "Capo",
	Roof = "Teto",
	EngineUpgrade = "Motor",
	BrakeUpgrade = "Freios",
	TransmissionUpgrade = "Transmissao",
	Horns = "Buzina",
	SuspensionUpgrade = "Suspensao",
	ShieldingUpgrade = "Blindagem",
	Mod17 = "Modificacao 17",
	Mod19 = "Modificacao 19",
	TyreSmokeToggle = "Fumaca dos pneus",
	Mod21 = "Modificacao 21",
	RearWheels = "Roda traseira",
	Mod47 = "Modificacao 47",
	Lightbar = "Giroflex"
}

local function DeepCopy(Value)
	if type(Value) ~= "table" then
		return Value
	end

	local Copy = {}
	for Key,Data in pairs(Value) do
		Copy[Key] = DeepCopy(Data)
	end
	return Copy
end

local function SameValue(First,Second)
	if type(First) ~= type(Second) then
		return false
	end
	if type(First) ~= "table" then
		return First == Second
	end
	for Key,Value in pairs(First) do
		if not SameValue(Value,Second[Key]) then
			return false
		end
	end
	for Key in pairs(Second) do
		if First[Key] == nil then
			return false
		end
	end
	return true
end

local function ResetSelected(Entry)
	if type(Entry) ~= "table" then
		return
	end
	if Entry.Installed ~= nil then
		Entry.Selected = DeepCopy(Entry.Installed)
		return
	end
	for _,SubEntry in pairs(Entry) do
		ResetSelected(SubEntry)
	end
end

local function EntryChanged(Entry)
	if type(Entry) ~= "table" then
		return false
	end
	if Entry.Installed ~= nil then
		return not SameValue(Entry.Installed,Entry.Selected)
	end
	for _,SubEntry in pairs(Entry) do
		if EntryChanged(SubEntry) then
			return true
		end
	end
	return false
end

local function SelectedLabel(Index,Entry)
	if not Information.Vehicle or not DoesEntityExist(Information.Vehicle) then
		return "Alteracao selecionada"
	end

	if Entry and type(Entry.Selected) == "number" and Entry.Selected >= 0 and Mods[Index] and Mods[Index] < 99 then
		local LabelKey = GetModTextLabel(Information.Vehicle,Mods[Index],Entry.Selected)
		if LabelKey and LabelKey ~= "" then
			local Label = GetLabelText(LabelKey)
			if Label and Label ~= "NULL" and Label ~= "" then
				return Label
			end
		end
		return ("Opcao %s"):format(Entry.Selected + 1)
	end

	return "Alteracao selecionada"
end

local function CategoryPrice(Index)
	local Proposal = DeepCopy(Initial)
	for OtherIndex,Entry in pairs(Proposal) do
		if OtherIndex ~= Index then
			ResetSelected(Entry)
		end
	end
	return Calculate(Proposal,Information.Model or vRP.VehicleName())
end

local function NativeStateEnabled(Value)
	return Value == true or Value == 1
end

local function UpdateMechanicCart()
	if not Opened then
		return
	end

	local Doors = {}
	local VehicleState = {
		engine = false,
		lights = false
	}
	if Information.Vehicle and DoesEntityExist(Information.Vehicle) then
		for Door = 0,5 do
			if type(GetIsDoorValid) ~= "function" or GetIsDoorValid(Information.Vehicle,Door) then
				Doors[tostring(Door)] = true
			end
		end

		VehicleState.engine = GetIsVehicleEngineRunning(Information.Vehicle)
		local _,LightsOn,HighBeams = GetVehicleLightsState(Information.Vehicle)
		VehicleState.lights = NativeStateEnabled(LightsOn) or NativeStateEnabled(HighBeams)
	end

	local Items = {}
	for Index,Entry in pairs(Initial) do
		if EntryChanged(Entry) then
			Items[#Items + 1] = {
				id = Index,
				label = CategoryLabels[Index] or Index,
				detail = SelectedLabel(Index,Entry),
				price = CategoryPrice(Index)
			}
		end
	end
	table.sort(Items,function(First,Second)
		return First.label < Second.label
	end)

	SendNUIMessage({
		Action = "MechanicCart",
		Payload = {
			items = Items,
			total = Calculate(Initial,Information.Model or vRP.VehicleName()),
			waiting = Information.Waiting == true,
			owner = Information.Owner or "",
			doors = Doors,
			vehicleState = VehicleState
		}
	})
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- OPEN
-----------------------------------------------------------------------------------------------------------------------------------------
function Open(Vehicle,Logo)
	Initial = {}
	Information = { Vehicle = Vehicle }

	SetVehicleModKit(Vehicle,0)
	SetVehicleOnGroundProperly(Vehicle)
	FreezeEntityPosition(Vehicle,true)
	SetVehicleEngineOn(Vehicle,false,true,true)
	SetVehicleUndriveable(Vehicle,true)

	Wheel(Vehicle)
	Respray(Vehicle)
	WindowTint(Vehicle)
	PlateHolder(Vehicle)
	Xenons(Vehicle)
	Turbo(Vehicle)
	Neons(Vehicle)
	VehicleExtras(Vehicle)

	local Ignore = {
		["Wheels"] = true,
		["Respray"] = true,
		["WindowTint"] = true,
		["Xenons"] = true,
		["Turbo"] = true,
		["Neons"] = true,
		["PlateHolder"] = true,
		["VehicleExtras"] = true
	}

	for Mod,Number in pairs(Mods) do
		if not Ignore[Mod] then
			local Exist = GetVehicleMod(Information["Vehicle"],Number)
			local Amount = GetNumVehicleMods(Information["Vehicle"],Number)

			if Amount > 0 then
				Initial[Mod] = {
					["Installed"] = Exist,
					["Selected"] = Exist,
					["Amount"] = Amount,
					["Price"] = {},
					["Label"] = CategoryLabels[Mod] or Mod,
					["OptionLabels"] = {}
				}

				for Value = 1,Amount do
					local Price = 0
					if type(Values[Mod]) ~= "table" then
						Price = Values[Mod] or 100
					else
						if Mod:match("Upgrade") then
							local Model = vRP.VehicleName()
							local VehiclePrice = exports.vrp:VehiclePrice(Model)

							Values[Mod] = {
								parseInt(VehiclePrice * 0.01),
								parseInt(VehiclePrice * 0.02),
								parseInt(VehiclePrice * 0.03),
								parseInt(VehiclePrice * 0.04),
								parseInt(VehiclePrice * 0.05),
								parseInt(VehiclePrice * 0.06)
							}
						end

						local Total = #Values[Mod]
						if Values[Mod] and Values[Mod][Value] and Value <= Total then
							Price = Values[Mod][Value]
						else
							Price = Values[Mod][Total]
						end
					end

					Initial[Mod]["Price"][Value - 1] = Price
					local LabelKey = GetModTextLabel(Information["Vehicle"],Number,Value - 1)
					local Label = LabelKey and GetLabelText(LabelKey) or ""
					if not Label or Label == "" or Label == "NULL" then
						Label = ("Opcao %s"):format(Value)
					end
					Initial[Mod]["OptionLabels"][Value - 1] = Label
				end
			end
		end
	end

	Information["Model"] = GetEntityArchetypeName(Information["Vehicle"])
	Information["Plate"] = GetVehicleNumberPlateText(Information["Vehicle"])
	local Network = NetworkGetNetworkIdFromEntity(Information["Vehicle"])
	local Started = vSERVER.StartSession(Network,Information["Plate"],Information["Model"],Initial)
	if type(Started) ~= "table" or not Started.success then
		Apply(Information["Vehicle"],Initial,"Installed")
		FreezeEntityPosition(Information["Vehicle"],false)
		SetVehicleUndriveable(Information["Vehicle"],false)
		TriggerEvent("Notify","Mecanica",type(Started) == "table" and Started.message or "Nao foi possivel iniciar o atendimento.","vermelho",5000)
		Information = {}
		Initial = {}
		return false
	end

	Information["SessionId"] = Started.sessionId
	Information["Owner"] = Started.owner
	Information["SelfOwned"] = Started.selfOwned == true
	Information["Waiting"] = false
	Opened = true
	Focus = true

	SetNuiFocus(true,true)
	SetNuiFocusKeepInput(false)
	SetCursorLocation(0.5,0.5)
	TriggerEvent("hud:Active",false)
	SendNUIMessage({ Action = "Open", Payload = { Logo = Logo, Customs = Initial } })
	TriggerServerEvent("lscustoms:Network",Network,Information["Plate"])
	UpdateMechanicCart()
	return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- RESPRAY
-----------------------------------------------------------------------------------------------------------------------------------------
function Respray(Vehicle)
	if not Initial["Respray"] then
		Initial["Respray"] = {}
	end

	local Primary,Secondary = GetVehicleColours(Vehicle)
	local InteriorColor = GetVehicleInteriorColour(Vehicle)
	local DashboardColor = GetVehicleDashboardColour(Vehicle)
	local PearlescentColor,WheelColor = GetVehicleExtraColours(Vehicle)
	local PrimaryR,PrimaryG,PrimaryB = GetVehicleCustomPrimaryColour(Vehicle)
	local SecondaryR,SecondaryG,SecondaryB = GetVehicleCustomSecondaryColour(Vehicle)

	if Primary ~= 0 and Primary ~= 12 and Primary ~= 120 then
		Primary = 0
	end

	if Secondary ~= 0 and Secondary ~= 12 and Secondary ~= 120 then
		Secondary = 0
	end

	for Mode,Result in pairs(Resprays) do
		if Mode == "PrimaryColour" or Mode == "SecondaryColour" then
			Initial["Respray"][Mode] = {
				["Installed"] = {
					["Type"] = (Mode == "PrimaryColour" and Primary or Secondary),
					["Color"] = (Mode == "PrimaryColour" and { PrimaryR,PrimaryG,PrimaryB } or { SecondaryR,SecondaryG,SecondaryB })
				},
				["Selected"] = {
					["Type"] = (Mode == "PrimaryColour" and Primary or Secondary),
					["Color"] = (Mode == "PrimaryColour" and { PrimaryR,PrimaryG,PrimaryB } or { SecondaryR,SecondaryG,SecondaryB })
				},
				["Price"] = Values["Respray"]
			}
		else
			Initial["Respray"][Mode] = {
				["Installed"] = (Mode == "PearlescentColour" and PearlescentColor) or (Mode == "WheelColour" and WheelColor) or (Mode == "DashboardColour" and DashboardColor) or (Mode == "InteriorColour" and InteriorColor),
				["Selected"] = (Mode == "PearlescentColour" and PearlescentColor) or (Mode == "WheelColour" and WheelColor) or (Mode == "DashboardColour" and DashboardColor) or (Mode == "InteriorColour" and InteriorColor),
				["Price"] = Values[Mod]
			}
		end
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- WHEEL
-----------------------------------------------------------------------------------------------------------------------------------------
function Wheel(Vehicle)
	if not Initial.Wheels then
		Initial.Wheels = {}
	end

	local Number = Mods.Wheels
	local WheelPrice = Values.Wheels
	local VehicleType = GetVehicleType(Vehicle)
	local WheelType = GetVehicleWheelType(Vehicle)
	local R,G,B = GetVehicleTyreSmokeColor(Vehicle)
	local CurrentMod = GetVehicleMod(Vehicle,Number)
	local CurrentVariation = GetVehicleModVariation(Vehicle,Number)

	for Mode,Result in pairs(Wheels) do
		if Mode == "TyreSmoke" then
			Initial.Wheels[Mode] = {
				Installed = { R,G,B },
				Selected = { R,G,B },
				Price = WheelPrice
			}
		elseif Mode == "CustomTyres" then
			Initial.Wheels[Mode] = {
				Installed = CurrentVariation,
				Selected = CurrentVariation,
				Price = WheelPrice
			}
		elseif (VehicleType == "bike" and Mode == "Super") or VehicleType ~= "bike" then
			SetVehicleWheelType(Vehicle,Result)

			Initial.Wheels[Mode] = {
				Amount = GetNumVehicleMods(Vehicle,Number),
				Selected = (WheelType == Result and CurrentMod or -1),
				Installed = (WheelType == Result and CurrentMod or -1),
				Initial = { WheelType,Number,CurrentMod,CurrentVariation },
				Price = WheelPrice
			}
		end
	end

	SetVehicleWheelType(Vehicle,WheelType)
	SetVehicleMod(Vehicle,Number,CurrentMod,CurrentVariation)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PLATEHOLDER
-----------------------------------------------------------------------------------------------------------------------------------------
function PlateHolder(Vehicle)
	local Exist = GetVehicleNumberPlateTextIndex(Vehicle)

	Initial["PlateHolder"] = {
		["Selected"] = Exist,
		["Installed"] = Exist,
		["Price"] = Values["PlateHolder"]
	}
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- VEHICLEEXTRAS
-----------------------------------------------------------------------------------------------------------------------------------------
function VehicleExtras(Vehicle)
	for Number = 1,12 do
		if DoesExtraExist(Vehicle,Number) then
			if not Initial["VehicleExtras"] then
				Initial["VehicleExtras"] = {}
			end

			local Status = IsVehicleExtraTurnedOn(Vehicle,Number)

			Initial["VehicleExtras"][tostring(Number)] = {
				["Selected"] = not Status and 1 or 0,
				["Installed"] = not Status and 1 or 0,
				["Price"] = Values["VehicleExtras"]
			}
		end
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- WINDOWTINT
-----------------------------------------------------------------------------------------------------------------------------------------
function WindowTint(Vehicle)
	local Exist = GetVehicleWindowTint(Vehicle)

	Initial["WindowTint"] = {
		["Selected"] = Exist,
		["Installed"] = Exist,
		["Price"] = Values["WindowTint"]
	}
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- XENONS
-----------------------------------------------------------------------------------------------------------------------------------------
function Xenons(Vehicle)
	local Enable = IsToggleModOn(Vehicle,22)
	local Color = GetVehicleHeadlightsColour(Vehicle)

	Initial["Xenons"] = {
		["Installed"] = {
			["Enable"] = Enable,
			["Color"] = Color
		},
		["Selected"] = {
			["Enable"] = Enable,
			["Color"] = Color
		},
		["Price"] = Values["Xenons"]
	}
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- TURBO
-----------------------------------------------------------------------------------------------------------------------------------------
function Turbo(Vehicle)
	local Enable = IsToggleModOn(Vehicle,18)

	Initial["Turbo"] = {
		["Installed"] = Enable and 1 or 0,
		["Selected"] = Enable and 1 or 0,
		["Price"] = Values["Turbo"]
	}
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- NEONS
-----------------------------------------------------------------------------------------------------------------------------------------
function Neons(Vehicle)
	local R,G,B = GetVehicleNeonLightsColour(Vehicle)
	local Enable = IsVehicleNeonLightEnabled(Vehicle,0)

	Initial["Neons"] = {
		["Installed"] = {
			["Enable"] = Enable,
			["Color"] = { R,G,B }
		},
		["Selected"] = {
			["Enable"] = Enable,
			["Color"] = { R,G,B }
		},
		["Price"] = Values["Neons"]
	}
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- APPLY
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("Apply",function(Data,Callback)
	if not Opened or type(Data) ~= "table" then
		Callback("Ok")
		return
	end
	if Information.Waiting then
		Callback("Ok")
		return
	end

	local Item = Data["Item"]
	local Index = Data["Index"]
	local Category = Data["Category"]
	if not Index or type(Initial[Index]) ~= "table" then
		Callback("Ok")
		return
	end

	local Applied,ApplyError = pcall(function()
	if Index == "Respray" then
		if Category == "PrimaryColour" then
			Initial[Index][Category]["Selected"]["Type"] = Data["Type"]
			Initial[Index][Category]["Selected"]["Color"] = { Data["Color"][1],Data["Color"][2],Data["Color"][3] }

			SetVehicleColours(Information["Vehicle"],Data["Type"],Initial[Index]["SecondaryColour"]["Selected"]["Type"])
			SetVehicleCustomPrimaryColour(Information["Vehicle"],Data["Color"][1],Data["Color"][2],Data["Color"][3])
		elseif Category == "SecondaryColour" then
			Initial[Index][Category]["Selected"]["Type"] = Data["Type"]
			Initial[Index][Category]["Selected"]["Color"] = { Data["Color"][1],Data["Color"][2],Data["Color"][3] }

			SetVehicleColours(Information["Vehicle"],Initial[Index]["PrimaryColour"]["Selected"]["Type"],Data["Type"])
			SetVehicleCustomSecondaryColour(Information["Vehicle"],Data["Color"][1],Data["Color"][2],Data["Color"][3])
		elseif Category == "PearlescentColour" then
			Initial[Index][Category]["Selected"] = Data["Color"]

			SetVehicleExtraColours(Information["Vehicle"],Data["Color"],Initial[Index]["WheelColour"]["Selected"])
		elseif Category == "WheelColour" then
			Initial[Index][Category]["Selected"] = Data["Color"]

			SetVehicleExtraColours(Information["Vehicle"],Initial[Index]["PearlescentColour"]["Selected"],Data["Color"])
		elseif Category == "DashboardColour" then
			Initial[Index][Category]["Selected"] = Data["Color"]

			SetVehicleDashboardColor(Information["Vehicle"],Data["Color"])
		elseif Category == "InteriorColour" then
			Initial[Index][Category]["Selected"] = Data["Color"]

			SetVehicleInteriorColor(Information["Vehicle"],Data["Color"])
		end
	elseif Index == "Wheels" then
		if Category == "TyreSmoke" then
			Initial[Index][Category]["Selected"] = { Data["Color"][1],Data["Color"][2],Data["Color"][3] }

			ToggleVehicleMod(Information["Vehicle"],Wheels[Category],true)
			SetVehicleTyreSmokeColor(Information["Vehicle"],Data["Color"][1],Data["Color"][2],Data["Color"][3])
		elseif Category == "CustomTyres" then
			Initial[Index][Category]["Selected"] = Data["Enable"] and 1 or 0

			local ExistWheel = GetVehicleMod(Information["Vehicle"],Mods[Index])

			SetVehicleMod(Information["Vehicle"],Mods[Index],ExistWheel,Initial[Index][Category]["Selected"])
		else
			for Categ,_ in pairs(Initial[Index]) do
				if Categ ~= "TyreSmoke" and Categ ~= "CustomTyres" then
					Initial[Index][Categ]["Selected"] = Initial[Index][Categ]["Installed"]
				end
			end

			Initial[Index][Category]["Selected"] = Item

			SetVehicleWheelType(Information["Vehicle"],Wheels[Category])
			SetVehicleMod(Information["Vehicle"],Mods[Index],Item,Initial[Index]["CustomTyres"]["Selected"])

			if Mods[Index] == 23 and GetVehicleType(Information["Vehicle"]) == "bike" then
				SetVehicleMod(Information["Vehicle"],24,Item,Initial[Index]["CustomTyres"]["Selected"])
			end
		end
	elseif Index == "VehicleExtras" then
		local Disabled = Data["Enable"] == true or tonumber(Data["Enable"]) == 1
		Initial[Index][Item]["Selected"] = Disabled and 1 or 0

		local Windows,Tyres,Doors = {},{},{}
		local Health = GetEntityHealth(Information["Vehicle"])
		local Body = GetVehicleBodyHealth(Information["Vehicle"])
		local Engine = GetVehicleEngineHealth(Information["Vehicle"])

		for Number = 0,7 do
			Tyres[Number] = (GetTyreHealth(Information["Vehicle"],Number) ~= 1000.0 and true or false)
		end

		for Number = 0,5 do
			Doors[Number] = IsVehicleDoorDamaged(Information["Vehicle"],Number)
		end

		for Number = 0,5 do
			Windows[Number] = IsVehicleWindowIntact(Information["Vehicle"],Number)
		end

		SetVehicleExtra(Information["Vehicle"],parseInt(Item),Disabled)

		SetVehiclePetrolTankHealth(Information["Vehicle"],4000.0)
		SetVehicleEngineHealth(Information["Vehicle"],Engine)
		SetVehicleBodyHealth(Information["Vehicle"],Body)
		SetEntityHealth(Information["Vehicle"],Health)

		for Number,Enable in pairs(Tyres) do
			if Enable then
				SetVehicleTyreBurst(Information["Vehicle"],Number,true,1000.0)
			end
		end

		for Number,Enable in pairs(Windows) do
			if not Enable then
				SmashVehicleWindow(Information["Vehicle"],Number)
			end
		end

		for Number,Enable in pairs(Doors) do
			if Enable then
				SetVehicleDoorBroken(Information["Vehicle"],Number,true)
			end
		end
	elseif Index == "WindowTint" then
		Initial[Index]["Selected"] = Item

		SetVehicleWindowTint(Information["Vehicle"],Item)
	elseif Index == "Xenons" then
		if Data["Type"] == "Toggle" then
			Initial[Index]["Selected"]["Enable"] = Data["Enable"]

			if not Data["Enable"] then
				Initial[Index]["Selected"]["Color"] = Initial[Index]["Installed"]["Color"]
			end

			ToggleVehicleMod(Information["Vehicle"],Mods[Index],Initial[Index]["Selected"]["Enable"])
		else
			Initial[Index]["Selected"]["Color"] = Data["Color"] or 0

			SetVehicleHeadlightsColour(Information["Vehicle"],Data["Color"] or 0)
		end
	elseif Index == "Turbo" then
		Initial[Index]["Selected"] = Data["Enable"] and 1 or 0

		ToggleVehicleMod(Information["Vehicle"],Mods[Index],Initial[Index]["Selected"])
	elseif Index == "PlateHolder" then
		Initial[Index]["Selected"] = Item

		SetVehicleNumberPlateTextIndex(Information["Vehicle"],Item)
	elseif Index == "Neons" then
		if Data["Type"] == "Toggle" then
			Initial[Index]["Selected"]["Enable"] = Data["Enable"]

			if not Data["Enable"] then
				Initial[Index]["Selected"]["Color"] = Initial[Index]["Installed"]["Color"]
			end

			SetVehicleNeonLightEnabled(Information["Vehicle"],0,Initial[Index]["Selected"]["Enable"])
			SetVehicleNeonLightEnabled(Information["Vehicle"],1,Initial[Index]["Selected"]["Enable"])
			SetVehicleNeonLightEnabled(Information["Vehicle"],2,Initial[Index]["Selected"]["Enable"])
			SetVehicleNeonLightEnabled(Information["Vehicle"],3,Initial[Index]["Selected"]["Enable"])
		else
			Initial[Index]["Selected"]["Color"] = { Data["Color"][1] or 0,Data["Color"][2] or 0,Data["Color"][3] or 0 }

			SetVehicleNeonLightsColour(Information["Vehicle"],Data["Color"][1] or 0,Data["Color"][2] or 0,Data["Color"][3] or 0)
		end
	else
		Initial[Index]["Selected"] = Item

		SetVehicleMod(Information["Vehicle"],Mods[Index],Item)
		if Index == "Horns" and GetGameTimer() >= HornPreviewAt then
			HornPreviewAt = GetGameTimer() + MechanicConfig.HornPreviewCooldown
			StartVehicleHorn(Information["Vehicle"],MechanicConfig.HornPreviewDuration,GetHashKey("NORMAL"),false)
		end
	end
	end)

	if not Applied then
		print(("[lscustoms] Falha ao aplicar preview %s/%s: %s"):format(tostring(Index),tostring(Category),tostring(ApplyError)))
		Callback("Ok")
		return
	end

	SendNUIMessage({ Action = "Price", Payload = Calculate(Initial,vRP.VehicleName()) })
	UpdateMechanicCart()

	Callback("Ok")
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- APPLY
-----------------------------------------------------------------------------------------------------------------------------------------
function Apply(Spawn,Table,Mode)
	for Index,v in pairs(Table) do
		if Index == "Respray" then
			for Type,Results in pairs(Table[Index]) do
				if Type == "PrimaryColour" then
					SetVehicleColours(Spawn,Results[Mode]["Type"],Table[Index]["SecondaryColour"][Mode]["Type"])
					SetVehicleCustomPrimaryColour(Spawn,Results[Mode]["Color"][1],Results[Mode]["Color"][2],Results[Mode]["Color"][3])
				elseif Type == "SecondaryColour" then
					SetVehicleColours(Spawn,Table[Index]["PrimaryColour"][Mode]["Type"],Results[Mode]["Type"])
					SetVehicleCustomSecondaryColour(Spawn,Results[Mode]["Color"][1],Results[Mode]["Color"][2],Results[Mode]["Color"][3])
				elseif Type == "PearlescentColour" then
					SetVehicleExtraColours(Spawn,Results[Mode],Table[Index]["WheelColour"][Mode])
				elseif Type == "WheelColour" then
					SetVehicleExtraColours(Spawn,Table[Index]["PearlescentColour"][Mode],Results[Mode])
				elseif Type == "DashboardColour" then
					SetVehicleDashboardColor(Spawn,Results[Mode])
				elseif Type == "InteriorColour" then
					SetVehicleInteriorColor(Spawn,Results[Mode])
				end
			end
		elseif Index == "Wheels" then
			for Type,Results in pairs(Table[Index]) do
				if Type == "TyreSmoke" then
					ToggleVehicleMod(Spawn,Wheels[Type],true)
					SetVehicleTyreSmokeColor(Spawn,Results[Mode][1],Results[Mode][2],Results[Mode][3])
				elseif Type == "Highend" then
					SetVehicleWheelType(Spawn,Results["Initial"][1])
					SetVehicleMod(Spawn,Results["Initial"][2],Results["Initial"][3],Table[Index]["CustomTyres"][Mode])

					if Results["Initial"][2] == 23 and GetVehicleType(Spawn) == "bike" then
						SetVehicleMod(Spawn,24,Results["Initial"][3],Table[Index]["CustomTyres"][Mode])
					end
				end
			end
		elseif Index == "PlateHolder" then
			SetVehicleNumberPlateTextIndex(Spawn,v[Mode])
		elseif Index == "Turbo" then
			ToggleVehicleMod(Spawn,Mods[Index],v[Mode])
		elseif Index == "VehicleExtras" then
			local Windows,Tyres,Doors = {},{},{}
			local Health = GetEntityHealth(Spawn)
			local Body = GetVehicleBodyHealth(Spawn)
			local Engine = GetVehicleEngineHealth(Spawn)

			for Number = 0,7 do
				Tyres[Number] = (GetTyreHealth(Spawn,Number) ~= 1000.0 and true or false)
			end

			for Number = 0,5 do
				Doors[Number] = IsVehicleDoorDamaged(Spawn,Number)
			end

			for Number = 0,5 do
				Windows[Number] = IsVehicleWindowIntact(Spawn,Number)
			end

			for Type,Results in pairs(Table[Index]) do
				SetVehicleExtra(Spawn,parseInt(Type),Results[Mode])
			end

			SetVehiclePetrolTankHealth(Spawn,4000.0)
			SetVehicleEngineHealth(Spawn,Engine)
			SetVehicleBodyHealth(Spawn,Body)
			SetEntityHealth(Spawn,Health)

			for Number,Enable in pairs(Tyres) do
				if Enable then
					SetVehicleTyreBurst(Spawn,Number,true,1000.0)
				end
			end

			for Number,Enable in pairs(Windows) do
				if not Enable then
					SmashVehicleWindow(Spawn,Number)
				end
			end

			for Number,Enable in pairs(Doors) do
				if Enable then
					SetVehicleDoorBroken(Spawn,Number,true)
				end
			end
		elseif Index == "WindowTint" then
			SetVehicleWindowTint(Spawn,v[Mode])
		elseif Index == "Xenons" then
			local Information = v[Mode]["Enable"]

			ToggleVehicleMod(Spawn,Mods[Index],Information)
			SetVehicleHeadlightsColour(Spawn,v[Mode]["Color"] or 0)
		elseif Index == "Neons" then
			local Information = v[Mode]["Enable"]

			SetVehicleNeonLightEnabled(Spawn,0,Information)
			SetVehicleNeonLightEnabled(Spawn,1,Information)
			SetVehicleNeonLightEnabled(Spawn,2,Information)
			SetVehicleNeonLightEnabled(Spawn,3,Information)
			SetVehicleNeonLightsColour(Spawn,v[Mode]["Color"][1] or 0,v[Mode]["Color"][2] or 0,v[Mode]["Color"][3] or 0)
		elseif Mods[Index] and v[Mode] ~= nil then
			SetVehicleMod(Spawn,Mods[Index],v[Mode])
		end
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- LSCUSTOMS:APPLY
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("lscustoms:Apply")
AddEventHandler("lscustoms:Apply",function(Spawn,Customize)
	local Spawn = Spawn
	local Customize = Customize
	if Customize then
		SetVehicleModKit(Spawn,0)
		SetVehicleLivery(Spawn,0)

		for Index,v in pairs(Customize) do
			if Index == "Respray" then
				SetVehicleColours(Spawn,v["PrimaryColour"]["Type"],v["SecondaryColour"]["Type"])
				SetVehicleCustomPrimaryColour(Spawn,v["PrimaryColour"]["Color"][1],v["PrimaryColour"]["Color"][2],v["PrimaryColour"]["Color"][3])
				SetVehicleCustomSecondaryColour(Spawn,v["SecondaryColour"]["Color"][1],v["SecondaryColour"]["Color"][2],v["SecondaryColour"]["Color"][3])
				SetVehicleExtraColours(Spawn,v["PearlescentColour"],v["WheelColour"])
				SetVehicleDashboardColor(Spawn,v["DashboardColour"])
				SetVehicleInteriorColor(Spawn,v["InteriorColour"])
			elseif Index == "Wheels" then
				if v["Category"] then
					SetVehicleWheelType(Spawn,Wheels[v["Category"]])
				end

				if v["Value"] then
					SetVehicleMod(Spawn,Mods[Index],v["Value"],v["CustomTyres"])

					if Mods[Index] == 23 and GetVehicleType(Spawn) == "bike" then
						SetVehicleMod(Spawn,24,v["Value"],v["CustomTyres"])
					end
				end

				if v["TyreSmoke"] then
					ToggleVehicleMod(Spawn,Wheels["TyreSmoke"],true)
					SetVehicleTyreSmokeColor(Spawn,v["TyreSmoke"][1],v["TyreSmoke"][2],v["TyreSmoke"][3])
				end
			elseif Index == "PlateHolder" then
				SetVehicleNumberPlateTextIndex(Spawn,v)
			elseif Index == "Turbo" then
				ToggleVehicleMod(Spawn,Mods[Index],v)
			elseif Index == "VehicleExtras" then
				for Number = 1,12 do
					if DoesExtraExist(Spawn,Number) then
						if Customize[Index][tostring(Number)] and Customize[Index][tostring(Number)] == 0 then
							SetVehicleExtra(Spawn,Number,0)
						else
							SetVehicleExtra(Spawn,Number,1)
						end
					end
				end

				SetVehiclePetrolTankHealth(Spawn,4000.0)
			elseif Index == "WindowTint" then
				SetVehicleWindowTint(Spawn,v)
			elseif Index == "Xenons" then
				local Information = v["Enable"]

				ToggleVehicleMod(Spawn,Mods[Index],Information)
				SetVehicleHeadlightsColour(Spawn,v["Color"] or 0)
			elseif Index == "Neons" then
				local Information = v["Enable"]

				SetVehicleNeonLightEnabled(Spawn,0,Information)
				SetVehicleNeonLightEnabled(Spawn,1,Information)
				SetVehicleNeonLightEnabled(Spawn,2,Information)
				SetVehicleNeonLightEnabled(Spawn,3,Information)
				SetVehicleNeonLightsColour(Spawn,v["Color"][1] or 0,v["Color"][2] or 0,v["Color"][3] or 0)
			else
				SetVehicleMod(Spawn,Mods[Index],v)
			end
		end
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- SAVE
-----------------------------------------------------------------------------------------------------------------------------------------
local function CloseMechanicPanel(KeepChanges)
	if not Opened then
		return
	end

	local Vehicle = Information.Vehicle
	if Vehicle and DoesEntityExist(Vehicle) then
		if not KeepChanges then
			Apply(Vehicle,Initial,"Installed")
		end
		SetVehicleUndriveable(Vehicle,false)
		FreezeEntityPosition(Vehicle,false)
	end

	SendNUIMessage({ Action = "Close" })
	SendNUIMessage({ Action = "MechanicState", Payload = { state = "closed" } })
	SetNuiFocus(false,false)
	SetNuiFocusKeepInput(false)
	TriggerEvent("hud:Active",true)
	TriggerServerEvent("lscustoms:Network")
	Information = {}
	Initial = {}
	Opened = false
	Focus = false
end

local function SubmitCurrentQuote()
	if not Opened or not Information.SessionId then
		return { success = false, message = "Nenhum atendimento ativo." }
	end
	if Information.Waiting then
		return { success = false, message = "Ja existe um orcamento aguardando resposta." }
	end

	local Called,Result = pcall(vSERVER.PrepareQuote,Information.SessionId,Initial)
	if not Called or type(Result) ~= "table" then
		print(("[lscustoms] Falha ao enviar orcamento: %s"):format(tostring(Result)))
		return { success = false, message = "Falha de comunicacao ao enviar o orcamento." }
	end

	if Result.success then
		Information.Waiting = true
		SendNUIMessage({
			Action = "MechanicState",
			Payload = {
				state = "waiting",
				message = Result.message,
				total = Result.total
			}
		})
		UpdateMechanicCart()
		if Result.selfOwned then
			SendNUIMessage({
				Action = "MechanicSelfConfirm",
				Payload = {
					vehicle = Result.vehicle,
					summary = Result.summary,
					total = Result.total
				}
			})
		end
	else
		SendNUIMessage({
			Action = "MechanicState",
			Payload = {
				state = "error",
				message = Result.message or "Nao foi possivel enviar o orcamento."
			}
		})
	end

	return Result
end

RegisterNUICallback("Save",function(_,Callback)
	SubmitCurrentQuote()
	Callback("Ok")
end)

RegisterNUICallback("SubmitQuote",function(_,Callback)
	local Result = SubmitCurrentQuote()
	Callback(Result)
end)

RegisterNUICallback("ConfirmSelfQuote",function(Data,Callback)
	if not Opened or not Information.SessionId then
		Callback({ success = false, message = "Sessao inexistente." })
		return
	end

	local Called,Result = pcall(vSERVER.ConfirmSelfQuote,Information.SessionId,type(Data) == "table" and Data.accepted == true)
	if not Called or type(Result) ~= "table" then
		Callback({ success = false, message = "Falha ao confirmar o orcamento." })
		return
	end
	Callback(Result)
end)

RegisterNUICallback("RemoveCartItem",function(Data,Callback)
	if not Opened or Information.Waiting or type(Data) ~= "table" or type(Data.id) ~= "string" or not Initial[Data.id] then
		Callback({ success = false, message = "Item invalido ou orcamento bloqueado." })
		return
	end

	ResetSelected(Initial[Data.id])
	Apply(Information.Vehicle,Initial,"Selected")
	SendNUIMessage({ Action = "Price", Payload = Calculate(Initial,Information.Model) })
	UpdateMechanicCart()
	Callback({ success = true })
end)

RegisterNUICallback("RestorePreview",function(_,Callback)
	if not Opened or Information.Waiting then
		Callback({ success = false, message = "O preview nao pode ser restaurado agora." })
		return
	end

	for _,Entry in pairs(Initial) do
		ResetSelected(Entry)
	end
	Apply(Information.Vehicle,Initial,"Selected")
	SendNUIMessage({ Action = "Price", Payload = 0 })
	UpdateMechanicCart()
	Callback({ success = true })
end)

RegisterNUICallback("CancelService",function(_,Callback)
	if not Opened then
		Callback({ success = true })
		return
	end

	local SessionId = Information.SessionId
	local Called,Result = pcall(vSERVER.CancelSession,SessionId,"Atendimento cancelado pelo mecanico.")
	if Opened then
		CloseMechanicPanel(false)
	end
	if not Called or type(Result) ~= "table" then
		Callback({ success = false, message = "Atendimento fechado localmente." })
		return
	end
	Callback(Result)
end)

local function RequestVehicleControl(Vehicle)
	local Timeout = GetGameTimer() + 650
	NetworkRequestControlOfEntity(Vehicle)
	while not NetworkHasControlOfEntity(Vehicle) and GetGameTimer() < Timeout do
		Wait(0)
		NetworkRequestControlOfEntity(Vehicle)
	end
	return NetworkHasControlOfEntity(Vehicle)
end

local DoorAnimationBusy = false

local function ValidVehicleDoors(Vehicle,Doors)
	local Valid = {}

	for _,Door in ipairs(Doors or {}) do
		Door = tonumber(Door)
		if Door and Door >= 0 and Door <= 5 then
			Door = math.floor(Door)
			if type(GetIsDoorValid) ~= "function" or GetIsDoorValid(Vehicle,Door) then
				Valid[#Valid + 1] = Door
			end
		end
	end

	return Valid
end

local function AnimateVehicleDoors(Vehicle,Doors,Open)
	if DoorAnimationBusy or not Vehicle or not DoesEntityExist(Vehicle) then
		return false
	end

	Doors = ValidVehicleDoors(Vehicle,Doors)
	if #Doors <= 0 then
		return false
	end

	DoorAnimationBusy = true
	local Starts = {}
	for _,Door in ipairs(Doors) do
		Starts[Door] = GetVehicleDoorAngleRatio(Vehicle,Door)
	end

	local Duration = math.max(160,tonumber(MechanicConfig.DoorAnimationDuration) or 320)
	local StartedAt = GetGameTimer()

	while DoesEntityExist(Vehicle) do
		local Progress = math.min(1.0,(GetGameTimer() - StartedAt) / Duration)
		local Eased = Progress * Progress * (3.0 - (2.0 * Progress))

		for _,Door in ipairs(Doors) do
			local Start = Starts[Door] or 0.0
			local Target = Open and 1.0 or 0.0
			SetVehicleDoorControl(Vehicle,Door,1,Start + ((Target - Start) * Eased))
		end

		if Progress >= 1.0 then
			break
		end

		Wait(0)
	end

	if DoesEntityExist(Vehicle) then
		for _,Door in ipairs(Doors) do
			if Open then
				SetVehicleDoorOpen(Vehicle,Door,false,false)
			else
				SetVehicleDoorShut(Vehicle,Door,false)
			end
		end
	end

	DoorAnimationBusy = false
	return true
end

local function ToggleVehicleDoors(Vehicle,Doors)
	local Valid = ValidVehicleDoors(Vehicle,Doors)
	if #Valid <= 0 then
		return false,nil
	end

	local Open = true
	for _,Door in ipairs(Valid) do
		if GetVehicleDoorAngleRatio(Vehicle,Door) > 0.1 then
			Open = false
			break
		end
	end

	return AnimateVehicleDoors(Vehicle,Valid,Open),Open
end

RegisterNUICallback("VehicleDoor",function(Data,Callback)
	if not Opened or type(Data) ~= "table" or not Information.Vehicle or not DoesEntityExist(Information.Vehicle) then
		Callback({ success = false, message = "Veiculo indisponivel." })
		return
	end
	local Validated,Allowed = pcall(vSERVER.ValidateSession,Information.SessionId)
	if not Validated or not Allowed then
		Callback({ success = false, message = "A sessao da oficina nao esta mais valida." })
		return
	end
	if not RequestVehicleControl(Information.Vehicle) then
		Callback({ success = false, message = "Nao foi possivel controlar o veiculo." })
		return
	end

	local Door = tonumber(Data.door)
	if Door == -1 then
		local Doors = ValidVehicleDoors(Information.Vehicle,{ 0,1,2,3,4,5 })
		if not AnimateVehicleDoors(Information.Vehicle,Doors,false) then
			Callback({ success = false, message = "Nao foi possivel fechar os acessos." })
			return
		end
	elseif Door and Door >= 0 and Door <= 5 then
		Door = math.floor(Door)
		if type(GetIsDoorValid) == "function" and not GetIsDoorValid(Information.Vehicle,Door) then
			Callback({ success = false, message = "Este veiculo nao possui esse acesso." })
			return
		end
		if not ToggleVehicleDoors(Information.Vehicle,{ Door }) then
			Callback({ success = false, message = "Nao foi possivel movimentar este acesso." })
			return
		end
	else
		Callback({ success = false, message = "Porta invalida." })
		return
	end
	Callback({ success = true })
end)

RegisterNUICallback("VehicleControl",function(Data,Callback)
	if not Opened or type(Data) ~= "table" or not Information.Vehicle or not DoesEntityExist(Information.Vehicle) then
		Callback({ success = false, message = "Veiculo indisponivel." })
		return
	end
	local Validated,Allowed = pcall(vSERVER.ValidateSession,Information.SessionId)
	if not Validated or not Allowed then
		Callback({ success = false, message = "A sessao da oficina nao esta mais valida." })
		return
	end
	if not RequestVehicleControl(Information.Vehicle) then
		Callback({ success = false, message = "Nao foi possivel controlar o veiculo." })
		return
	end

	local Action = tostring(Data.action or "")
	local Active = false
	local Message = ""

	if Action == "engine" then
		Active = not GetIsVehicleEngineRunning(Information.Vehicle)
		SetVehicleUndriveable(Information.Vehicle,false)
		SetVehicleEngineOn(Information.Vehicle,Active,true,true)
		if not Active then
			SetVehicleUndriveable(Information.Vehicle,true)
		end
		Message = Active and "Motor ligado." or "Motor desligado."
	elseif Action == "lights" then
		local _,LightsOn,HighBeams = GetVehicleLightsState(Information.Vehicle)
		Active = not (NativeStateEnabled(LightsOn) or NativeStateEnabled(HighBeams))
		SetVehicleLights(Information.Vehicle,Active and 2 or 1)
		if not Active then
			SetVehicleFullbeam(Information.Vehicle,false)
		end
		Message = Active and "Farois ligados." or "Farois desligados."
	else
		Callback({ success = false, message = "Controle invalido." })
		return
	end

	UpdateMechanicCart()
	Callback({
		success = true,
		active = Active,
		message = Message
	})
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- CLOSE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("Close",function(_,Callback)
	if not Opened then
		Callback("Ok")
		return
	end

	pcall(vSERVER.CancelSession,Information.SessionId,"Painel da oficina fechado.")
	if Opened then
		CloseMechanicPanel(false)
	end
	Callback("Ok")
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- CAMERA
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("Camera",function(Data,Callback)
	SetNuiFocusKeepInput(Focus)
	Focus = not Focus

	Callback("Ok")
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADOPEN
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	while true do
		local TimeDistance = 999
		local Ped = PlayerPedId()
		if not Opened then
			if IsPedInAnyVehicle(Ped) then
				local Vehicle = GetVehiclePedIsUsing(Ped)
				if GetPedInVehicleSeat(Vehicle,-1) == Ped then
					local Coords = GetEntityCoords(Ped)

					for Index,v in pairs(Locations) do
						if #(Coords - v["Coords"]["xyz"]) <= 2.5 then
							TimeDistance = 1

							if IsControlJustPressed(1,38) and vSERVER.Permission(Index) then
								SetEntityCoordsNoOffset(Vehicle,v["Coords"]["xyz"])
								SetEntityHeading(Vehicle,v["Coords"]["w"])
								Open(Vehicle,v["Logo"])
							end
						end
					end
				end
			end
		end

		Wait(TimeDistance)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- LSCUSTOMS:OPEN
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("lscustoms:Open")
AddEventHandler("lscustoms:Open",function()
	local Ped = PlayerPedId()
	if not Opened and IsPedInAnyVehicle(Ped) then
		local Coords = GetEntityCoords(Ped)
		local Heading = GetEntityCoords(Ped)
		local Vehicle = GetVehiclePedIsUsing(Ped)

		if GetPedInVehicleSeat(Vehicle,-1) == Ped then
			SetEntityCoordsNoOffset(Vehicle,Coords)
			SetEntityHeading(Vehicle,Heading)
			Open(Vehicle,"lscustoms.png")
		end
	end
end)

local function MechanicNotify(Message,Color)
	TriggerEvent("Notify","Mecanica",Message,Color or "amarelo",5000)
end

local function ClosestMechanicVehicle()
	local Ped = PlayerPedId()
	if GetEntityHealth(Ped) <= 100 then
		MechanicNotify("Voce nao pode trabalhar neste estado.","vermelho")
		return nil
	end

	if IsPedInAnyVehicle(Ped,false) then
		MechanicNotify("Saia do veiculo para realizar o atendimento.","amarelo")
		return nil
	end

	local Vehicle,Network,Plate,Model = vRP.VehicleList(MechanicConfig.VehicleDistance)
	if not Vehicle or not DoesEntityExist(Vehicle) then
		MechanicNotify("Nenhum veiculo encontrado nas proximidades.","amarelo")
		return nil
	end

	if GetEntitySpeed(Vehicle) > MechanicConfig.MaximumVehicleSpeed then
		MechanicNotify("O veiculo precisa estar parado.","amarelo")
		return nil
	end

	return Vehicle,Network,Plate,Model
end

RegisterCommand(MechanicConfig.OpenCommand,function()
	if Opened then
		return
	end

	local Vehicle,Network,Plate = ClosestMechanicVehicle()
	if Vehicle and vSERVER.MechanicAccess(Network,Plate) then
		Open(Vehicle,"lscustoms.png")
	end
end)

RegisterCommand(MechanicConfig.DiagnosticCommand,function()
	local Vehicle,Network,Plate = ClosestMechanicVehicle()
	if not Vehicle or not vSERVER.Diagnostic(Network,Plate) then
		return
	end

	local Engine = math.max(0,math.min(100,math.floor(GetVehicleEngineHealth(Vehicle) / 10)))
	local Body = math.max(0,math.min(100,math.floor(GetVehicleBodyHealth(Vehicle) / 10)))
	local Tank = math.max(0,math.min(100,math.floor(GetVehiclePetrolTankHealth(Vehicle) / 10)))
	local Fuel = math.max(0,math.min(100,math.floor(GetVehicleFuelLevel(Vehicle))))
	local BurstTyres = 0
	for Tyre = 0,7 do
		if IsVehicleTyreBurst(Vehicle,Tyre,false) then
			BurstTyres = BurstTyres + 1
		end
	end

	MechanicNotify(("Motor: <b>%s%%</b><br>Lataria: <b>%s%%</b><br>Tanque: <b>%s%%</b><br>Combustivel: <b>%s%%</b><br>Pneus danificados: <b>%s</b>"):format(Engine,Body,Tank,Fuel,BurstTyres),"azul")
end)

RegisterCommand(MechanicConfig.RepairCommand,function()
	local Vehicle,Network,Plate = ClosestMechanicVehicle()
	if Vehicle then
		vSERVER.Repair(Network,Plate)
	end
end)

local function ToggleExternalMechanicDoors(Doors,OpenMessage,CloseMessage)
	local Vehicle,Network,Plate = ClosestMechanicVehicle()
	if not Vehicle or not vSERVER.ExternalDoorAccess(Network,Plate) then
		return
	end

	if not RequestVehicleControl(Vehicle) then
		MechanicNotify("Nao foi possivel controlar o veiculo.","vermelho")
		return
	end

	local Success,OpenedDoors = ToggleVehicleDoors(Vehicle,Doors)
	if not Success then
		MechanicNotify("Este veiculo nao possui o acesso solicitado.","amarelo")
		return
	end

	MechanicNotify(OpenedDoors and OpenMessage or CloseMessage,"verde")
end

RegisterCommand(MechanicConfig.DoorCommands.Doors,function()
	ToggleExternalMechanicDoors({ 0,1,2,3 },"Portas abertas.","Portas fechadas.")
end)

RegisterCommand(MechanicConfig.DoorCommands.Hood,function()
	ToggleExternalMechanicDoors({ 4 },"Capo aberto.","Capo fechado.")
end)

RegisterCommand(MechanicConfig.DoorCommands.Trunk,function()
	ToggleExternalMechanicDoors({ 5 },"Porta-malas aberto.","Porta-malas fechado.")
end)

RegisterNetEvent("lscustoms:RepairStart")
AddEventHandler("lscustoms:RepairStart",function(Duration)
	local Ped = PlayerPedId()
	local Dict = "mini@repair"
	RequestAnimDict(Dict)
	while not HasAnimDictLoaded(Dict) do
		Wait(10)
	end

	TaskPlayAnim(Ped,Dict,"fixing_a_player",3.0,3.0,Duration or MechanicConfig.RepairDuration,49,0.0,false,false,false)
	TriggerEvent("Progress","Reparando",Duration or MechanicConfig.RepairDuration)
end)

RegisterNetEvent("lscustoms:RepairCancel")
AddEventHandler("lscustoms:RepairCancel",function()
	ClearPedTasks(PlayerPedId())
end)

RegisterNetEvent("lscustoms:RepairFinish")
AddEventHandler("lscustoms:RepairFinish",function()
	ClearPedTasks(PlayerPedId())
end)

RegisterNetEvent("lscustoms:RepairVehicle")
AddEventHandler("lscustoms:RepairVehicle",function(Network,Plate)
	if not NetworkDoesNetworkIdExist(Network) then
		return
	end

	local Vehicle = NetToVeh(Network)
	if not DoesEntityExist(Vehicle) or GetVehicleNumberPlateText(Vehicle):gsub("%s+","") ~= tostring(Plate):gsub("%s+","") then
		return
	end

	local Fuel = GetVehicleFuelLevel(Vehicle)
	SetVehicleUndriveable(Vehicle,false)
	SetVehicleFixed(Vehicle)
	SetVehicleDeformationFixed(Vehicle)
	SetVehicleDirtLevel(Vehicle,0.0)
	SetVehicleFuelLevel(Vehicle,Fuel)
end)

RegisterNetEvent("lscustoms:RollbackVehicle")
AddEventHandler("lscustoms:RollbackVehicle",function(Network,Plate,Original)
	if not Network or not NetworkDoesNetworkIdExist(Network) or type(Original) ~= "table" then
		return
	end

	local Vehicle = NetToVeh(Network)
	if not DoesEntityExist(Vehicle) or GetVehicleNumberPlateText(Vehicle):gsub("%s+","") ~= tostring(Plate):gsub("%s+","") then
		return
	end

	RequestVehicleControl(Vehicle)
	Apply(Vehicle,Original,"Installed")
	SetVehicleUndriveable(Vehicle,false)
	FreezeEntityPosition(Vehicle,false)
end)

RegisterNetEvent("lscustoms:SessionCancelled")
AddEventHandler("lscustoms:SessionCancelled",function(Message)
	if Opened then
		CloseMechanicPanel(false)
	end
	if Message and Message ~= "" then
		MechanicNotify(Message,"amarelo")
	end
end)

RegisterNetEvent("lscustoms:QuoteResult")
AddEventHandler("lscustoms:QuoteResult",function(Success,Message)
	if Success then
		if Opened then
			CloseMechanicPanel(true)
		end
	elseif Opened then
		CloseMechanicPanel(false)
	end
	if Message and Message ~= "" then
		MechanicNotify(Message,Success and "verde" or "vermelho")
	end
end)

RegisterNetEvent("lscustoms:ForceClose")
AddEventHandler("lscustoms:ForceClose",function()
	if not Opened then
		return
	end
	CloseMechanicPanel(false)
end)

AddEventHandler("onResourceStop",function(Resource)
	if Resource ~= GetCurrentResourceName() or not Opened then
		return
	end

	if Information["Vehicle"] and DoesEntityExist(Information["Vehicle"]) then
		Apply(Information["Vehicle"],Initial,"Installed")
		SetVehicleUndriveable(Information["Vehicle"],false)
		FreezeEntityPosition(Information["Vehicle"],false)
	end

	SetNuiFocus(false,false)
	SetNuiFocusKeepInput(false)
	TriggerEvent("hud:Active",true)
end)
