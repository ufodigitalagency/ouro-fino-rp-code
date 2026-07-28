-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")
vRP = Proxy.getInterface("vRP")
-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECTION
-----------------------------------------------------------------------------------------------------------------------------------------
vSERVER = Tunnel.getInterface("shops")
-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Opened = false
local OpenedLocation = false
local ShopBlips = {}
local ShopNuiDiagnostic = {
	ModalOpen = false,
	Pending = false,
	LastResponse = "idle"
}

local ShopVisual = {
	Departament = {
		Name = "Mercearia",
		Sprite = 52,
		Colour = 2,
		Scale = 0.55
	},
	Megamall = {
		Name = "Loja",
		Sprite = 52,
		Colour = 5,
		Scale = 0.5
	},
	Eletronics = {
		Name = "Eletrônicos",
		Sprite = 606,
		Colour = 3,
		Scale = 0.5
	},
	Ammunation = {
		Name = "Ammu-Nation",
		Sprite = 110,
		Colour = 1,
		Scale = 0.48
	}
}

local function shopName(mode)
	local Visual = ShopVisual[mode]
	if Visual and Visual.Name then
		return Visual.Name
	end

	if List and List[mode] and List[mode].Name then
		return List[mode].Name
	end

	return "Loja"
end

local function resolveShopReference(Reference)
	if Location[Reference] then return Reference end

	local NumericReference = tonumber(Reference)
	if NumericReference and Location[NumericReference] then return NumericReference end

	local RequestedId = type(Reference) == "string" and Reference or nil
	if RequestedId then
		for Number,Shop in ipairs(Location) do
			if Shop.Id == RequestedId then return Number end
		end
	end

	return Reference
end

local function HelpText(Text)
	BeginTextCommandDisplayHelp("STRING")
	AddTextComponentSubstringPlayerName(Text)
	EndTextCommandDisplayHelp(0,false,true,-1)
end

local function createShopBlips()
	for _,Blip in pairs(ShopBlips) do
		if DoesBlipExist(Blip) then
			RemoveBlip(Blip)
		end
	end

	ShopBlips = {}

	for _,v in pairs(Location) do
		local Visual = ShopVisual[v.Mode]
		if Visual and not v.Route then
			local Coords = v.Coords
			local Blip = AddBlipForCoord(Coords.x,Coords.y,Coords.z)

			SetBlipSprite(Blip,Visual.Sprite or 52)
			SetBlipDisplay(Blip,4)
			SetBlipColour(Blip,Visual.Colour or 0)
			SetBlipScale(Blip,Visual.Scale or 0.5)
			SetBlipAsShortRange(Blip,true)

			BeginTextCommandSetBlipName("STRING")
			AddTextComponentString(v.Name or Visual.Name or "Loja")
			EndTextCommandSetBlipName(Blip)

			ShopBlips[#ShopBlips + 1] = Blip
		end
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- INVENTORY:CLOSE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("inventory:Close")
AddEventHandler("inventory:Close",function()
	if Opened then
		Opened = false
		OpenedLocation = false
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- MOUNT
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("Mount",function(Data,Callback)
	-- The list is rebuilt at the opening moment to avoid a stale client catalog.
	if RefreshShopItemList then
		RefreshShopItemList()
	end

	local Primary,PrimaryWeight,PrimarySlots = vSERVER.Mount(Opened)
	if not Primary then
		Callback({ success = false, message = "Nao foi possivel carregar a loja." })
		return
	end

	Callback({
		Primary = {
			Data = Primary,
			MaxWeight = PrimaryWeight,
			Slots = PrimarySlots or Theme.inventory.slots.default
		},
		Secondary = {
			Data = ItemList[Opened],
			Slots = math.max(CountTable(ItemList[Opened]),25)
		}
	})
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- TAKE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("Take",function(Data,Callback)
	local Success = false
	if MumbleIsConnected() then
		Success = vSERVER.Take(Data.Item,Data.Amount,Data.Target,Opened)
	end

	Callback(Success)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- SHOP QUOTES
-----------------------------------------------------------------------------------------------------------------------------------------
local function quoteResponse(Callback,Method,...)
	if not MumbleIsConnected() or not Opened then
		Callback({ success = false, message = "A loja nao esta disponivel." })
		return
	end

	ShopNuiDiagnostic.Pending = true
	local Worked,Result = pcall(Method,...)
	ShopNuiDiagnostic.Pending = false

	if not Worked then
		print(("[shops] Falha no fluxo de cotacao: %s"):format(tostring(Result)))
		ShopNuiDiagnostic.LastResponse = "tunnel_error"
		Callback({ success = false, message = "Nao foi possivel consultar a loja." })
		return
	end

	if type(Result) ~= "table" then
		ShopNuiDiagnostic.LastResponse = "invalid_response"
		Callback({ success = false, message = "A loja retornou uma resposta invalida." })
		return
	end

	ShopNuiDiagnostic.LastResponse = Result.success and "success" or (Result.code or "rejected")
	Callback(Result)
end

RegisterNUICallback("CreateQuote",function(Data,Callback)
	Data = type(Data) == "table" and Data or {}
	quoteResponse(Callback,vSERVER.CreateQuote,Data.Item,Data.Amount,Opened,OpenedLocation)
end)

RegisterNUICallback("ConfirmQuote",function(Data,Callback)
	Data = type(Data) == "table" and Data or {}
	quoteResponse(Callback,vSERVER.ConfirmQuote,Data.Token)
end)

RegisterNUICallback("CancelQuote",function(Data,Callback)
	Data = type(Data) == "table" and Data or {}
	if not MumbleIsConnected() then
		Callback({ success = false, message = "Sem conexao com o servidor." })
		return
	end

	local Worked,Result = pcall(vSERVER.CancelQuote,Data.Token)
	if not Worked or type(Result) ~= "table" then
		Callback({ success = false, message = "Nao foi possivel cancelar a cotacao." })
		return
	end

	Callback(Result)
end)

RegisterNUICallback("ShopDiagnosticState",function(Data,Callback)
	ShopNuiDiagnostic.ModalOpen = Data and Data.ModalOpen == true
	ShopNuiDiagnostic.Pending = Data and Data.Pending == true
	ShopNuiDiagnostic.LastResponse = Data and tostring(Data.LastResponse or ShopNuiDiagnostic.LastResponse) or ShopNuiDiagnostic.LastResponse
	Callback({ success = true })
end)

exports("MultiplayerDiagnosticState",function()
	return {
		Opened = Opened or false,
		Location = OpenedLocation or false,
		ModalOpen = ShopNuiDiagnostic.ModalOpen,
		Pending = ShopNuiDiagnostic.Pending,
		LastResponse = ShopNuiDiagnostic.LastResponse
	}
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- STORE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("Store",function(Data,Callback)
	local Success = false
	if MumbleIsConnected() then
		Success = vSERVER.Store(Data.Item,Data.Amount,Data.Target,Opened)
	end

	Callback(Success)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- SHOPS:OPEN
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("shops:Open",function(Number)
	Number = resolveShopReference(Number)
	local RequestedShop = Location[Number] and Location[Number].Mode or Number
	if RequestedShop == "Pombal" or RequestedShop == "SaoJudas" then
		print(("[shops] faction_arsenal_open_requested shop=%s location=%s"):format(tostring(RequestedShop),tostring(Number)))
	end

	if exports.hud:Wanted() then
		if RequestedShop == "Pombal" or RequestedShop == "SaoJudas" then
			TriggerEvent("Notify","Atenção","O arsenal não pode ser acessado enquanto você estiver procurado.","amarelo",5000)
		end

		return
	end

	local Shop = Location[Number]
	if not Shop then
		if vSERVER.Permission(Number) and List[Number] then
			Opened = Number
			OpenedLocation = false

			TriggerEvent("inventory:Open",{
				Type = "Shops",
				Mode = List[Opened].Mode,
				Free = List[Opened].Type == "Free",
				Item = List[Opened].Item or "dollar",
				Resource = "shops",
				Right = shopName(Opened)
			})
		end

		return
	end

	local RouteMatch = not Shop.Route or Shop.Route == LocalPlayer.state.Route
	if not RouteMatch or not vSERVER.Permission(Shop.Mode,Number) then
		return
	end

	Opened = Shop.Mode
	OpenedLocation = Number

	TriggerEvent("inventory:Open",{
		Type = "Shops",
		Mode = List[Opened].Mode,
		Free = List[Opened].Type == "Free",
		Item = List[Opened].Item or "dollar",
		Resource = "shops",
		Right = Shop.Name or shopName(Opened)
	})

	if Shop.Sound then
		TriggerEvent("sounds:Private","shop",0.5)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADSERVERSTART
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	createShopBlips()

	while GetResourceState("target") ~= "started" do
		Wait(500)
	end

	Wait(1000)

	local RegisteredTargetZones = 0
	for Number,v in pairs(Location) do
		if v.RegisterTarget ~= false then
			local Label = v.Name or shopName(v.Mode)
			local Radius = math.max(tonumber(v.Circle) or 0.0,1.35)
			local Options = {}

			if v.DefaultTargetOption ~= false then
				Options[#Options + 1] = {
					event = "shops:Open",
					label = Label,
					tunnel = "client"
				}
			end

			for _,Option in ipairs(v.AdditionalTargetOptions or {}) do
				Options[#Options + 1] = Option
			end

			-- CircleZone com useZ = false deixa a mira do target bem mais tolerante em balcões e prateleiras.
			exports.target:AddCircleZone("Shops:"..Number,v.Coords,Radius,{
				name = "Shops:"..Number,
				heading = 0.0,
				useZ = false
			},{
				shop = Number,
				Distance = 2.35,
				options = Options
			})
			RegisteredTargetZones = RegisteredTargetZones + 1
		end
	end

	print(("[shops] %s zonas de lojas registradas no target e %s blips criados no mapa."):format(RegisteredTargetZones,#ShopBlips))
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADINTERACTION
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	while true do
		local TimeDistance = 1000
		local Ped = PlayerPedId()

		if not IsPedInAnyVehicle(Ped,false) then
			local Coords = GetEntityCoords(Ped)

			for Number,v in pairs(Location) do
				local Visual = ShopVisual[v.Mode]
				local DirectInteraction = v.DirectInteraction == true

				if ((Visual and LocalPlayer.state.Active) or DirectInteraction) and not v.Route then
					local Distance = #(Coords - v.Coords)
					local InteractionDistance = tonumber(v.InteractionDistance) or 1.35
					local PromptDistance = math.max(InteractionDistance,2.0)

					if Distance <= 8.0 then
						TimeDistance = 1

						if v.DrawInteractionMarker ~= false then
							DrawMarker(23,v.Coords.x,v.Coords.y,v.Coords.z - 0.95,0.0,0.0,0.0,0.0,0.0,0.0,0.85,0.85,0.0,255,215,0,135,false,false,2,false,nil,nil,false)
						end

						if Distance <= PromptDistance then
							HelpText("Pressione ~INPUT_CONTEXT~ para acessar ~y~"..(v.Name or shopName(v.Mode)))
						end

						local InteractionPressed = IsControlJustPressed(0,38) or IsDisabledControlJustPressed(0,38)
						if Distance <= InteractionDistance and InteractionPressed then
							if DirectInteraction then
								print(("[shops] direct_interaction shop=%s location=%s distance=%.2f"):format(tostring(v.Mode),tostring(Number),Distance))
							end

							TriggerEvent("shops:Open",Number)
						end
					end
				end
			end
		end

		Wait(TimeDistance)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- ONRESOURCESTOP
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("onResourceStop",function(Resource)
	if Resource ~= GetCurrentResourceName() then
		return
	end

	for _,Blip in pairs(ShopBlips) do
		if DoesBlipExist(Blip) then
			RemoveBlip(Blip)
		end
	end
end)
