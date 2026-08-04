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
-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Networked = {}
local Repairing = {}
local RepairNetworks = {}
local Sessions = {}
local SessionByPassport = {}
local SessionCounter = 0

local CategoryLabels = {
	Respray = "Pintura",
	Wheels = "Rodas",
	VehicleExtras = "Extras",
	WindowTint = "Insulfilm",
	Xenons = "Farois xenon",
	Turbo = "Turbo",
	Neons = "Neon",
	PlateHolder = "Placa",
	EngineUpgrade = "Motor",
	BrakeUpgrade = "Freios",
	TransmissionUpgrade = "Transmissao",
	SuspensionUpgrade = "Suspensao",
	ShieldingUpgrade = "Blindagem",
	Horns = "Buzina",
	Lightbar = "Giroflex"
}

local function Debug(Message)
	if MechanicConfig.Debug then
		print(("[lscustoms/mechanic] %s"):format(Message))
	end
end

local function Notify(Source,Message,Color)
	if Source and Source > 0 then
		TriggerClientEvent("Notify",Source,"Mecanica",Message,Color or "amarelo",5000)
	end
end

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

local function NormalizePlate(Plate)
	return tostring(Plate or ""):gsub("%s+",""):upper()
end

local function ValidPlate(Plate)
	return type(Plate) == "string" and #Plate >= 1 and #Plate <= 8 and Plate:match("^[A-Z0-9]+$") ~= nil
end

local function ResolveVehicleProperty(Vehicle,Plate,ExpectedPassport,ExpectedPropertyKey,ExpectedNativeModel)
	local NormalizedPlate = NormalizePlate(Plate)
	if not ValidPlate(NormalizedPlate) or not Vehicle or Vehicle <= 0 or not DoesEntityExist(Vehicle) then
		return false,"Veiculo ou placa invalida."
	end

	local Queried,Property = pcall(vRP.SingleQuery,"vehicles/plateVehicles",{ Plate = NormalizedPlate })
	if not Queried or type(Property) ~= "table" then
		return false,"Propriedade do veiculo nao encontrada."
	end

	local PropertyPassport = tonumber(Property.Passport)
	local PropertyKey = type(Property.Vehicle) == "string" and Property.Vehicle or ""
	if not PropertyPassport or PropertyPassport <= 0 or PropertyKey == "" then
		return false,"Propriedade do veiculo invalida."
	end

	if ExpectedPassport and PropertyPassport ~= ExpectedPassport then
		return false,"A propriedade do veiculo mudou durante o atendimento."
	end

	if ExpectedPropertyKey and PropertyKey ~= ExpectedPropertyKey then
		return false,"O veiculo da propriedade mudou durante o atendimento."
	end

	local NativeModel = exports.vrp:VehicleModel(PropertyKey)
	if type(NativeModel) ~= "string" or NativeModel == "" then
		return false,"Modelo do veiculo nao registrado."
	end

	if ExpectedNativeModel and NativeModel ~= ExpectedNativeModel then
		return false,"O modelo registrado do veiculo mudou durante o atendimento."
	end

	if GetEntityModel(Vehicle) ~= GetHashKey(NativeModel) then
		return false,"O modelo real do veiculo nao corresponde a propriedade."
	end

	return {
		Passport = PropertyPassport,
		PropertyKey = PropertyKey,
		NativeModel = NativeModel,
		Plate = NormalizedPlate
	}
end

local function IsPlayerOnline(Source)
	return Source and Source > 0 and GetPlayerName(Source) ~= nil
end

local function InWorkshop(Coords)
	if not MechanicConfig.RequireWorkshop then
		return true
	end

	for _,Workshop in ipairs(MechanicConfig.Workshops or {}) do
		if Workshop.Coords and #(Coords - Workshop.Coords) <= (Workshop.Radius or 25.0) then
			return true,Workshop
		end
	end

	return false
end

local function HasMechanicAccess(Source,Passport,Silent)
	if not Passport or not vRP.HasPermission(Passport,MechanicConfig.Permission) then
		if not Silent then
			Notify(Source,"Voce nao possui o cargo de mecanico.","vermelho")
		end

		return false
	end

	if MechanicConfig.RequireDuty and not vRP.HasService(Passport,MechanicConfig.Permission) then
		if not Silent then
			Notify(Source,"Entre em servico com /"..MechanicConfig.DutyCommand..".","amarelo")
		end

		return false
	end

	return true
end

local function ValidateVehicle(Source,Passport,Network,Plate,AllowInside,Silent,RequireWorkshop)
	if not IsPlayerOnline(Source) or vRP.Passport(Source) ~= Passport or not HasMechanicAccess(Source,Passport,Silent) or not Network or Network <= 0 then
		return false,"Acesso negado."
	end

	local Ped = GetPlayerPed(Source)
	local Vehicle = NetworkGetEntityFromNetworkId(Network)
	if not Ped or Ped <= 0 or not DoesEntityExist(Ped) or GetEntityHealth(Ped) <= 100 or not Vehicle or Vehicle <= 0 or not DoesEntityExist(Vehicle) then
		if not Silent then
			Notify(Source,"Veiculo invalido ou indisponivel.","vermelho")
		end
		return false,"Veiculo invalido ou indisponivel."
	end

	if not AllowInside and GetVehiclePedIsIn(Ped,false) ~= 0 then
		if not Silent then
			Notify(Source,"Saia do veiculo para realizar o atendimento.","amarelo")
		end
		return false,"Saia do veiculo para realizar o atendimento."
	end

	local PedCoords = GetEntityCoords(Ped)
	local VehicleCoords = GetEntityCoords(Vehicle)
	if RequireWorkshop ~= false and (not InWorkshop(PedCoords) or not InWorkshop(VehicleCoords)) then
		if not Silent then
			Notify(Source,"Este atendimento so pode ser realizado dentro da Bennys.","amarelo")
		end
		return false,"Fora da oficina Bennys."
	end

	if #(PedCoords - VehicleCoords) > (MechanicConfig.VehicleDistance + 0.75) then
		if not Silent then
			Notify(Source,"Aproxime-se do veiculo.","amarelo")
		end
		return false,"Mecanico distante do veiculo."
	end

	if GetEntitySpeed(Vehicle) > MechanicConfig.MaximumVehicleSpeed then
		if not Silent then
			Notify(Source,"O veiculo precisa estar parado.","amarelo")
		end
		return false,"O veiculo precisa estar parado."
	end

	if Plate and Plate ~= "" then
		local VehiclePlate = GetVehicleNumberPlateText(Vehicle)
		if NormalizePlate(VehiclePlate) ~= NormalizePlate(Plate) then
			if not Silent then
				Notify(Source,"A placa do veiculo nao confere.","vermelho")
			end
			return false,"A placa do veiculo nao confere."
		end
	end

	return Vehicle
end

local function CustomerNearVehicle(Session)
	local Source = vRP.Source(Session.CustomerPassport)
	if not IsPlayerOnline(Source) or Source ~= Session.CustomerSource or vRP.Passport(Source) ~= Session.CustomerPassport then
		return false,"O proprietario precisa estar online."
	end

	local Ped = GetPlayerPed(Source)
	local Vehicle = NetworkGetEntityFromNetworkId(Session.Network)
	if not Ped or Ped <= 0 or not DoesEntityExist(Ped) or not Vehicle or Vehicle <= 0 or not DoesEntityExist(Vehicle) then
		return false,"O proprietario ou o veiculo nao esta disponivel."
	end

	if #(GetEntityCoords(Ped) - GetEntityCoords(Vehicle)) > MechanicConfig.CustomerDistance then
		return false,"O proprietario se afastou do veiculo."
	end

	return true,Source
end

local function CopySelectedShape(Installed,Candidate)
	if type(Installed) ~= type(Candidate) then
		return DeepCopy(Installed)
	end

	if type(Installed) == "number" then
		local Number = tonumber(Candidate)
		if not Number then
			return Installed
		end
		return math.max(-1,math.min(1000,math.floor(Number)))
	elseif type(Installed) == "boolean" then
		return Candidate == true
	elseif type(Installed) ~= "table" then
		return Installed
	end

	local Result = {}
	for Key,Value in pairs(Installed) do
		Result[Key] = CopySelectedShape(Value,Candidate[Key])
	end
	return Result
end

local function SanitizeProposal(Session,Proposal)
	if type(Proposal) ~= "table" then
		return false,"Proposta de tunagem invalida."
	end

	local Result = DeepCopy(Session.Original)
	for Index,Entry in pairs(Result) do
		local ProposedEntry = Proposal[Index]
		if type(Entry) == "table" and type(ProposedEntry) == "table" then
			if Entry.Selected ~= nil and ProposedEntry.Selected ~= nil then
				Entry.Selected = CopySelectedShape(Entry.Installed,ProposedEntry.Selected)
				if type(Entry.Amount) == "number" and type(Entry.Selected) == "number" then
					Entry.Selected = math.max(-1,math.min(Entry.Selected,math.max(-1,Entry.Amount - 1)))
				end
			else
				for Category,SubEntry in pairs(Entry) do
					local ProposedSub = ProposedEntry[Category]
					if type(SubEntry) == "table" and SubEntry.Selected ~= nil and type(ProposedSub) == "table" and ProposedSub.Selected ~= nil then
						SubEntry.Selected = CopySelectedShape(SubEntry.Installed,ProposedSub.Selected)
						if type(SubEntry.Amount) == "number" and type(SubEntry.Selected) == "number" then
							SubEntry.Selected = math.max(-1,math.min(SubEntry.Selected,math.max(-1,SubEntry.Amount - 1)))
						end
					end
				end
			end
		end
	end

	return Result
end

local function BuildChangedCategories(Proposal)
	local Changes = {}
	for Index,Entry in pairs(Proposal) do
		local Changed = false
		if type(Entry) == "table" and Entry.Selected ~= nil then
			Changed = not SameValue(Entry.Installed,Entry.Selected)
		elseif type(Entry) == "table" then
			for _,SubEntry in pairs(Entry) do
				if type(SubEntry) == "table" and SubEntry.Selected ~= nil and not SameValue(SubEntry.Installed,SubEntry.Selected) then
					Changed = true
					break
				end
			end
		end

		if Changed then
			Changes[#Changes + 1] = CategoryLabels[Index] or Index
		end
	end

	table.sort(Changes)
	return Changes
end

local function MergeCustomization(Passport,Model,Proposal)
	local Name = Passport..":"..Model
	local Loaded,Consult = pcall(vRP.GetSrvData,"LsCustoms:"..Name,true)
	if not Loaded or type(Consult) ~= "table" then
		Consult = {}
	end

	for Index,Entry in pairs(Proposal) do
		if Index == "VehicleExtras" then
			for Type,Data in pairs(Entry) do
				if Data.Installed ~= Data.Selected then
					Consult.VehicleExtras = Consult.VehicleExtras or {}
					Consult.VehicleExtras[Type] = Data.Selected
				end
			end
		elseif Index == "Respray" then
			Consult.Respray = {
				PrimaryColour = { Type = Entry.PrimaryColour.Selected.Type, Color = Entry.PrimaryColour.Selected.Color },
				SecondaryColour = { Type = Entry.SecondaryColour.Selected.Type, Color = Entry.SecondaryColour.Selected.Color },
				PearlescentColour = Entry.PearlescentColour.Selected,
				WheelColour = Entry.WheelColour.Selected,
				DashboardColour = Entry.DashboardColour.Selected,
				InteriorColour = Entry.InteriorColour.Selected
			}
		elseif Index == "Wheels" then
			for Type,Data in pairs(Entry) do
				if not SameValue(Data.Installed,Data.Selected) then
					Consult.Wheels = Consult.Wheels or {}
					if Type == "TyreSmoke" then
						Consult.Wheels.TyreSmoke = Data.Selected
					elseif Type == "CustomTyres" then
						Consult.Wheels.CustomTyres = Data.Selected
					else
						Consult.Wheels.Category = Type
						Consult.Wheels.Value = Data.Selected
					end
				end
			end
		elseif Entry.Installed ~= nil and not SameValue(Entry.Installed,Entry.Selected) then
			Consult[Index] = Entry.Selected
		end
	end

	return "LsCustoms:"..Name,Consult
end

local function ClearSession(Session)
	if not Session then
		return
	end

	Sessions[Session.Id] = nil
	if SessionByPassport[Session.MechanicPassport] == Session.Id then
		SessionByPassport[Session.MechanicPassport] = nil
	end
	if Session.CustomerPassport ~= Session.MechanicPassport and SessionByPassport[Session.CustomerPassport] == Session.Id then
		SessionByPassport[Session.CustomerPassport] = nil
	end
	Networked[Session.MechanicPassport] = nil
end

local function RollbackSession(Session,Reason)
	local Sent = {}
	for _,Source in ipairs({ Session.MechanicSource,vRP.Source(Session.CustomerPassport) }) do
		if IsPlayerOnline(Source) and not Sent[Source] then
			Sent[Source] = true
			TriggerClientEvent("lscustoms:RollbackVehicle",Source,Session.Network,Session.Plate,Session.Original)
		end
	end

	if IsPlayerOnline(Session.MechanicSource) then
		TriggerClientEvent("lscustoms:SessionCancelled",Session.MechanicSource,Reason or "Atendimento cancelado.")
	end
end

local function CancelSession(Session,Reason,Rollback)
	if not Session or not Sessions[Session.Id] then
		return
	end

	Debug(("sessao cancelada: id=%s reason=%s"):format(Session.Id,tostring(Reason)))
	if Rollback ~= false then
		RollbackSession(Session,Reason)
	end
	ClearSession(Session)
end

local function SessionForSource(Source,SessionId)
	local Passport = vRP.Passport(Source)
	local Session = Sessions[tostring(SessionId or "")]
	if not Passport or not Session or Session.MechanicPassport ~= Passport or Session.MechanicSource ~= Source then
		return false
	end
	return Session,Passport
end

local function CompleteQuote(Session,Accepted)
	if not Session or not Sessions[Session.Id] or Session.State ~= "waiting" then
		return
	end

	if not Accepted then
		Notify(Session.MechanicSource,"O cliente recusou ou cancelou o orcamento.","amarelo")
		CancelSession(Session,"Orcamento recusado pelo cliente.",true)
		return
	end

	Session.State = "processing"
	local MechanicSource = Session.MechanicSource
	local Vehicle,Reason = ValidateVehicle(MechanicSource,Session.MechanicPassport,Session.Network,Session.Plate,true,true)
	if not Vehicle then
		CancelSession(Session,Reason or "O veiculo nao esta mais disponivel.",true)
		return
	end

	local CustomerNear,OwnerSource = CustomerNearVehicle(Session)
	if not CustomerNear then
		CancelSession(Session,OwnerSource,true)
		return
	end

	local Property,PropertyReason = ResolveVehicleProperty(Vehicle,Session.Plate,Session.CustomerPassport,Session.PropertyKey,Session.NativeModel)
	if not Property then
		CancelSession(Session,PropertyReason,true)
		return
	end

	if Session.Total > 0 and not vRP.PaymentFull(Session.CustomerPassport,Session.Total,true) then
		Notify(MechanicSource,"O cliente nao possui saldo suficiente.","vermelho")
		Notify(OwnerSource,"Saldo insuficiente para concluir a tunagem.","vermelho")
		CancelSession(Session,"Pagamento recusado por saldo insuficiente.",true)
		return
	end

	local Key,Data = MergeCustomization(Session.CustomerPassport,Session.PropertyKey,Session.Preview)
	local Persisted,PersistenceError = pcall(function()
		vRP.Query("entitydata/SetData",{ Name = Key, Information = json.encode(Data) })
		vRP.SetSrvData(Key,Data,true)
	end)

	if not Persisted then
		if Session.Total > 0 then
			vRP.GiveBank(Session.CustomerPassport,Session.Total,true)
		end
		Debug(("falha de persistencia: id=%s error=%s"):format(Session.Id,tostring(PersistenceError)))
		CancelSession(Session,"Falha ao salvar a tunagem. O pagamento foi devolvido.",true)
		return
	end

	local Commission = math.floor(Session.Total * (MechanicConfig.Commission or 0.0))
	if Commission > 0 then
		vRP.GiveBank(Session.MechanicPassport,Commission,true)
	end

	Notify(MechanicSource,("Tunagem salva. Comissao recebida: <b>$%s</b>."):format(Dotted(Commission)),"verde")
	if OwnerSource ~= MechanicSource then
		Notify(OwnerSource,"Tunagem concluida e salva na garagem.","verde")
	end
	Debug(("orcamento concluido: id=%s mechanic=%s owner=%s total=%s commission=%s"):format(Session.Id,Session.MechanicPassport,Session.CustomerPassport,Session.Total,Commission))
	TriggerClientEvent("lscustoms:QuoteResult",MechanicSource,true,"Servico concluido e salvo.")
	ClearSession(Session)
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- PERMISSION
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Permission(Index)
	local Source = source
	local Passport = vRP.Passport(Source)
	if not Passport or exports.bank:CheckTaxes(Passport) or exports.bank:CheckFines(Passport) then
		return false
	end

	local Location = Locations[Index]
	if not Location or not InWorkshop(GetEntityCoords(GetPlayerPed(Source))) then
		return false
	end

	if Location.Permission and not vRP.HasService(Passport,Location.Permission) then
		return false
	end

	return true
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- MECHANIC ACCESS
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.MechanicAccess(Network,Plate)
	local Source = source
	local Passport = vRP.Passport(Source)
	local Vehicle = ValidateVehicle(Source,Passport,parseInt(Network),Plate,false)
	if Vehicle then
		Debug(("painel autorizado: passport=%s network=%s"):format(Passport,Network))
		return true
	end
	return false
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- SESSION
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.StartSession(Network,Plate,_,Original)
	local Source = tonumber(source)
	Network = parseInt(Network)
	Plate = NormalizePlate(Plate)

	if not IsPlayerOnline(Source) then
		return { success = false, message = "Dados do atendimento invalidos." }
	end

	local Passport = vRP.Passport(Source)
	if not Passport or not ValidPlate(Plate) or type(Original) ~= "table" then
		return { success = false, message = "Dados do atendimento invalidos." }
	end

	local Vehicle,Reason = ValidateVehicle(Source,Passport,Network,Plate,true)
	if not Vehicle then
		return { success = false, message = Reason or "Veiculo indisponivel." }
	end

	if SessionByPassport[Passport] then
		return { success = false, message = "Voce ja possui um atendimento em andamento." }
	end

	for _,Existing in pairs(Sessions) do
		if Existing.Network == Network then
			return { success = false, message = "Este veiculo ja esta em atendimento." }
		end
	end

	local Property,PropertyReason = ResolveVehicleProperty(Vehicle,Plate)
	if not Property then
		return { success = false, message = PropertyReason }
	end

	local CustomerPassport = Property.Passport
	local CustomerSource = CustomerPassport and vRP.Source(CustomerPassport)
	if not CustomerPassport or not IsPlayerOnline(CustomerSource) or vRP.Passport(CustomerSource) ~= CustomerPassport then
		return { success = false, message = "O proprietario do veiculo precisa estar online." }
	end

	if SessionByPassport[CustomerPassport] and CustomerPassport ~= Passport then
		return { success = false, message = "O proprietario ja participa de outro atendimento." }
	end

	local CustomerPed = GetPlayerPed(CustomerSource)
	if not CustomerPed or CustomerPed <= 0 or #(GetEntityCoords(CustomerPed) - GetEntityCoords(Vehicle)) > MechanicConfig.CustomerDistance then
		return { success = false, message = "O proprietario precisa permanecer proximo ao veiculo." }
	end

	SessionCounter = SessionCounter + 1
	local SessionId = ("%s:%s:%s"):format(Passport,os.time(),SessionCounter)
	local Session = {
		Id = SessionId,
		MechanicSource = Source,
		MechanicPassport = Passport,
		CustomerSource = CustomerSource,
		CustomerPassport = CustomerPassport,
		Network = Network,
		Plate = Property.Plate,
		PropertyKey = Property.PropertyKey,
		NativeModel = Property.NativeModel,
		Original = DeepCopy(Original),
		Preview = DeepCopy(Original),
		Total = 0,
		State = "editing",
		CreatedAt = os.time(),
		ExpiresAt = os.time() + MechanicConfig.SessionTimeout
	}

	Sessions[SessionId] = Session
	SessionByPassport[Passport] = SessionId
	if CustomerPassport ~= Passport then
		SessionByPassport[CustomerPassport] = SessionId
	end
	Networked[Passport] = { Network,Session.Plate }
	Debug(("sessao criada: id=%s mechanic=%s owner=%s property=%s native=%s network=%s"):format(SessionId,Passport,CustomerPassport,Session.PropertyKey,Session.NativeModel,Network))

	return {
		success = true,
		sessionId = SessionId,
		selfOwned = CustomerPassport == Passport,
		owner = vRP.FullName(CustomerPassport),
		message = "Atendimento iniciado."
	}
end

function Lil.PrepareQuote(SessionId,Proposal)
	local Source = source
	local Session = SessionForSource(Source,SessionId)
	if not Session then
		return { success = false, message = "Sessao de atendimento invalida ou expirada." }
	end

	if Session.State ~= "editing" then
		return { success = false, message = "Ja existe um orcamento aguardando resposta." }
	end

	local Vehicle,Reason = ValidateVehicle(Source,Session.MechanicPassport,Session.Network,Session.Plate,true,true)
	if not Vehicle then
		CancelSession(Session,Reason or "Veiculo indisponivel.",true)
		return { success = false, message = Reason or "Veiculo indisponivel." }
	end

	local CustomerNear,OwnerSource = CustomerNearVehicle(Session)
	if not CustomerNear then
		CancelSession(Session,OwnerSource,true)
		return { success = false, message = OwnerSource }
	end

	local Property,PropertyReason = ResolveVehicleProperty(Vehicle,Session.Plate,Session.CustomerPassport,Session.PropertyKey,Session.NativeModel)
	if not Property then
		CancelSession(Session,PropertyReason,true)
		return { success = false, message = PropertyReason }
	end

	local Sanitized,SanitizeError = SanitizeProposal(Session,Proposal)
	if not Sanitized then
		return { success = false, message = SanitizeError }
	end

	local Changes = BuildChangedCategories(Sanitized)
	if #Changes <= 0 then
		return { success = false, message = "Adicione ao menos uma modificacao ao orcamento." }
	end

	local Calculated,Total = pcall(Calculate,Sanitized,Session.NativeModel)
	if not Calculated or type(Total) ~= "number" or Total < 0 then
		Debug(("calculo negado: id=%s error=%s"):format(Session.Id,tostring(Total)))
		return { success = false, message = "Nao foi possivel calcular o orcamento." }
	end

	Session.Preview = Sanitized
	Session.Total = parseInt(Total)
	Session.Changes = Changes
	Session.State = "waiting"
	Session.QuoteExpiresAt = os.time() + MechanicConfig.QuoteTimeout
	local Summary = table.concat(Changes,", ")
	local VehicleName = exports.vrp:VehicleName(Session.PropertyKey) or Session.PropertyKey
	local SelfOwned = Session.CustomerPassport == Session.MechanicPassport
	Debug(("orcamento enviado: id=%s total=%s items=%s self=%s"):format(Session.Id,Session.Total,#Changes,tostring(SelfOwned)))

	if not SelfOwned then
		CreateThread(function()
			local Current = Sessions[Session.Id]
			if not Current or Current.State ~= "waiting" then
				return
			end

			local Message = ("Autorizar o orcamento da <b>%s</b>?<br>%s<br>Total: <b>$%s</b>"):format(VehicleName,Summary,Dotted(Current.Total))
			local Requested,Accepted = pcall(vRP.Request,OwnerSource,"Bennys - Orcamento",Message)
			if not Requested then
				Debug(("erro ao solicitar aprovacao: id=%s error=%s"):format(Current.Id,tostring(Accepted)))
				CompleteQuote(Current,false)
				return
			end
			CompleteQuote(Current,Accepted == true)
		end)
	end

	return {
		success = true,
		selfOwned = SelfOwned,
		total = Session.Total,
		summary = Summary,
		vehicle = VehicleName,
		message = SelfOwned and "Confirme o orcamento no painel." or "Orcamento enviado ao proprietario."
	}
end

function Lil.ConfirmSelfQuote(SessionId,Accepted)
	local Source = source
	local Session = SessionForSource(Source,SessionId)
	if not Session or Session.CustomerPassport ~= Session.MechanicPassport or Session.State ~= "waiting" then
		return { success = false, message = "Orcamento proprio invalido ou expirado." }
	end

	if Accepted ~= true then
		CompleteQuote(Session,false)
		return { success = true, accepted = false, message = "Orcamento cancelado." }
	end

	CreateThread(function()
		CompleteQuote(Session,true)
	end)
	return { success = true, accepted = true, message = "Processando pagamento e salvamento." }
end

function Lil.CancelSession(SessionId,Reason)
	local Session = SessionForSource(source,SessionId)
	if not Session then
		return { success = false, message = "Sessao inexistente." }
	end

	CancelSession(Session,tostring(Reason or "Atendimento cancelado pelo mecanico."),true)
	return { success = true, message = "Atendimento cancelado." }
end

function Lil.ValidateSession(SessionId)
	local Source = source
	local Session = SessionForSource(Source,SessionId)
	if not Session or Session.State == "processing" then
		return false
	end
	return ValidateVehicle(Source,Session.MechanicPassport,Session.Network,Session.Plate,true,true) and true or false
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- DIAGNOSTIC
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Diagnostic(Network,Plate)
	local Source = source
	local Passport = vRP.Passport(Source)
	return ValidateVehicle(Source,Passport,parseInt(Network),Plate,false) and true or false
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- EXTERNAL DOOR ACCESS
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.ExternalDoorAccess(Network,Plate)
	local Source = source
	local Passport = vRP.Passport(Source)
	return ValidateVehicle(Source,Passport,parseInt(Network),Plate,false,false,false) and true or false
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- REPAIR
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Repair(Network,Plate)
	local Source = source
	local Passport = vRP.Passport(Source)
	Network = parseInt(Network)

	if not Passport then
		return false
	end

	if Repairing[Passport] or RepairNetworks[Network] then
		Notify(Source,"Este reparo ja esta em andamento.","amarelo")
		return false
	end

	if not ValidateVehicle(Source,Passport,Network,Plate,false,false,false) then
		return false
	end

	Repairing[Passport] = Network
	RepairNetworks[Network] = Passport
	Debug(("reparo iniciado: passport=%s network=%s"):format(Passport,Network))
	TriggerClientEvent("lscustoms:RepairStart",Source,MechanicConfig.RepairDuration)
	Wait(MechanicConfig.RepairDuration)

	if not ValidateVehicle(Source,Passport,Network,Plate,false,false,false) then
		Repairing[Passport] = nil
		RepairNetworks[Network] = nil
		TriggerClientEvent("lscustoms:RepairCancel",Source)
		return false
	end

	Repairing[Passport] = nil
	RepairNetworks[Network] = nil
	TriggerClientEvent("lscustoms:RepairVehicle",-1,Network,Plate)
	TriggerClientEvent("lscustoms:RepairFinish",Source)
	Notify(Source,"Veiculo reparado com sucesso.","verde")
	Debug(("reparo concluido: passport=%s network=%s"):format(Passport,Network))
	return true
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- LEGACY SAVE GUARD
-----------------------------------------------------------------------------------------------------------------------------------------
function Lil.Save()
	return false
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- NETWORK
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("lscustoms:Network")
AddEventHandler("lscustoms:Network",function(Network,Plate)
	local Source = source
	local Passport = vRP.Passport(Source)
	if not Passport then
		return
	end

	if Network then
		Networked[Passport] = { Network,Plate }
	else
		Networked[Passport] = nil
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- DUTY COMMAND
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand(MechanicConfig.DutyCommand,function(Source)
	local Passport = vRP.Passport(Source)
	if not Passport or not vRP.HasPermission(Passport,MechanicConfig.Permission) then
		Notify(Source,"Voce nao possui o cargo de mecanico.","vermelho")
		return
	end

	vRP.ServiceToggle(Source,Passport,MechanicConfig.Permission)
	if not vRP.HasService(Passport,MechanicConfig.Permission) then
		local SessionId = SessionByPassport[Passport]
		if SessionId and Sessions[SessionId] then
			CancelSession(Sessions[SessionId],"O mecanico saiu de servico.",true)
		end
		TriggerClientEvent("lscustoms:ForceClose",Source)
	end
	Debug(("servico alternado: passport=%s"):format(Passport))
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- SESSION WATCHDOG
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	while true do
		Wait(5000)
		local Now = os.time()
		local Cancel = {}
		for _,Session in pairs(Sessions) do
			local Reason
			if Now >= Session.ExpiresAt then
				Reason = "A sessao da oficina expirou."
			elseif Session.State == "waiting" and Session.QuoteExpiresAt and Now >= Session.QuoteExpiresAt then
				Reason = "O orcamento expirou sem resposta."
			elseif not IsPlayerOnline(Session.MechanicSource) or not HasMechanicAccess(Session.MechanicSource,Session.MechanicPassport,true) then
				Reason = "O mecanico nao esta mais disponivel."
			else
				local Vehicle = NetworkGetEntityFromNetworkId(Session.Network)
				if not Vehicle or Vehicle <= 0 or not DoesEntityExist(Vehicle) then
					Reason = "O veiculo foi removido."
				elseif not InWorkshop(GetEntityCoords(Vehicle)) then
					Reason = "O veiculo saiu da oficina."
				else
					local CustomerNear,CustomerReason = CustomerNearVehicle(Session)
					if not CustomerNear then
						Reason = CustomerReason
					end
				end
			end

			if Reason then
				Cancel[#Cancel + 1] = { Session,Reason }
			end
		end

		for _,Entry in ipairs(Cancel) do
			CancelSession(Entry[1],Entry[2],true)
		end
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- DISCONNECT
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("Disconnect",function(Passport)
	local RepairNetwork = Repairing[Passport]
	if RepairNetwork then
		RepairNetworks[RepairNetwork] = nil
		Repairing[Passport] = nil
	end

	local SessionId = SessionByPassport[Passport]
	if SessionId and Sessions[SessionId] then
		CancelSession(Sessions[SessionId],"Atendimento cancelado por desconexao.",true)
	end
	Networked[Passport] = nil
end)
