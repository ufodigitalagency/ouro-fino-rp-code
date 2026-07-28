local VaultZone = "SaoJudas:FinancialVault"
local WorkbenchZone = "SaoJudas:Workbench"
local LaboratoryZone = "SaoJudas:Laboratory"
local ZonesRegistered = false
local SupplierBlip = nil
local SupplierBlipAuthorized = false

local function removeSupplierBlip()
    if SupplierBlip and DoesBlipExist(SupplierBlip) then
        RemoveBlip(SupplierBlip)
    end

    SupplierBlip = nil
end

local function refreshSupplierBlip()
    local supplier = SaoJudasOperations.SulfuricSupplier
    local settings = supplier and supplier.Blip
    local shouldDisplay = SupplierBlipAuthorized and supplier and supplier.Enabled and settings and settings.Enabled

    if not shouldDisplay then
        removeSupplierBlip()
        return
    end

    if SupplierBlip and DoesBlipExist(SupplierBlip) then
        return
    end

    SupplierBlip = AddBlipForCoord(supplier.Coords.x,supplier.Coords.y,supplier.Coords.z)
    SetBlipSprite(SupplierBlip,tonumber(settings.Sprite) or 1)
    SetBlipColour(SupplierBlip,tonumber(settings.Color) or 5)
    SetBlipScale(SupplierBlip,tonumber(settings.Scale) or 0.55)
    SetBlipDisplay(SupplierBlip,tonumber(settings.Display) or 4)
    SetBlipAsShortRange(SupplierBlip,settings.ShortRange ~= false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(tostring(settings.Name or "Contato Químico"))
    EndTextCommandSetBlipName(SupplierBlip)
end

local function registerZones()
    if ZonesRegistered or GetResourceState("target") ~= "started" then
        return
    end

    local vault = SaoJudasOperations.FinancialVault
    if vault.Enabled then
        exports.target:AddCircleZone(VaultZone,vault.Coords,vault.TargetRadius,{
            name = VaultZone,
            heading = vault.Heading,
            useZ = false
        },{
            Distance = vault.InteractionDistance,
            options = {
                { event = "saoJudas:VaultStatus", label = "Consultar cofre financeiro", tunnel = "server" },
                { event = "saoJudas:DepositDirty", label = "Adicionar dinheiro sujo", tunnel = "server" },
                { event = "saoJudas:TransferClean", label = "Transferir saldo limpo para o F9", tunnel = "server" }
            }
        })
    end

    local workbench = SaoJudasOperations.Workbench
    if workbench.Enabled then
        exports.target:AddCircleZone(WorkbenchZone,workbench.TargetCoords,workbench.TargetRadius,{
            name = WorkbenchZone,
            heading = workbench.PlayerCoords.w,
            useZ = false
        },{
            Distance = workbench.InteractionDistance,
            options = {
                { event = "saoJudas:UseWorkbench", label = "Usar bancada de fabricacao", tunnel = "server" }
            }
        })
    end

    local lab = SaoJudasOperations.Laboratory
    if lab.Enabled then
        exports.target:AddCircleZone(LaboratoryZone,lab.Coords,lab.TargetRadius,{
            name = LaboratoryZone,
            useZ = false
        },{
            Distance = lab.InteractionDistance,
            options = {
                { event = "saoJudas:UseLaboratory", label = "Acessar laboratorio", tunnel = "server" }
            }
        })
    end

    ZonesRegistered = true
end

local function removeZones()
    if GetResourceState("target") ~= "started" then
        return
    end

    exports.target:RemCircleZone(VaultZone)
    exports.target:RemCircleZone(WorkbenchZone)
    exports.target:RemCircleZone(LaboratoryZone)
end

CreateThread(function()
    while not ZonesRegistered do
        registerZones()
        Wait(1000)
    end
end)

RegisterNetEvent("saoJudas:SetSupplierBlipAccess",function(Allowed)
    SupplierBlipAuthorized = Allowed == true
    refreshSupplierBlip()
end)

CreateThread(function()
    Wait(1500)

    while true do
        local supplier = SaoJudasOperations.SulfuricSupplier
        local settings = supplier and supplier.Blip

        if supplier and supplier.Enabled and settings and settings.Enabled then
            TriggerServerEvent("saoJudas:RequestSupplierBlipAccess")
            Wait(math.max(5,tonumber(settings.RefreshSeconds) or 10) * 1000)
        else
            SupplierBlipAuthorized = false
            refreshSupplierBlip()
            Wait(30000)
        end
    end
end)

AddEventHandler("onClientResourceStart",function(resourceName)
    if resourceName == "target" then
        ZonesRegistered = false
        registerZones()
    end
end)

AddEventHandler("onResourceStop",function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    if ZonesRegistered then
        removeZones()
    end

    removeSupplierBlip()
end)

RegisterCommand("saojudas_debug",function()
    if not SaoJudasOperations.Debug then
        return
    end

    local coords = GetEntityCoords(PlayerPedId())
    local workbench = SaoJudasOperations.Workbench
    local vault = SaoJudasOperations.FinancialVault

    print(("[saojudas/debug] workbench_distance=%.2f target=%s player_heading=%.2f"):format(
        #(coords - workbench.TargetCoords),tostring(workbench.Enabled),workbench.PlayerCoords.w
    ))
    print(("[saojudas/debug] vault_distance=%.2f target=%s legacy_marker_removed=true"):format(
        #(coords - vault.Coords),tostring(vault.Enabled)
    ))

    local lab = SaoJudasOperations.Laboratory
    print(("[saojudas/debug] laboratory_distance=%.2f target=%s enabled=%s exclusive=%s"):format(
        #(coords - lab.Coords),tostring(lab.Enabled),tostring(lab.Enabled),tostring(lab.ExclusiveSaoJudasLaboratory)
    ))

    TriggerServerEvent("saoJudas:DebugStatus")
end,false)
