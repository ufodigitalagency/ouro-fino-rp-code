local ZoneName = "Pombal:FinancialVault"
local ZoneRegistered = false

local function registerVault()
    if ZoneRegistered or GetResourceState("target") ~= "started" then
        return
    end

    local vault = PombalFinance.Vault
    exports.target:AddCircleZone(ZoneName,vault.Coords,0.75,{
        name = ZoneName,
        useZ = false
    },{
        Distance = vault.InteractionDistance,
        options = {
            { event = "pombalFinance:VaultStatus", label = "Consultar cofre da faccao", tunnel = "server" },
            { event = "pombalFinance:DepositDirty", label = "Depositar dinheiro sujo", tunnel = "server" },
            { event = "pombalFinance:TransferClean", label = "Transferir saldo limpo para o F9", tunnel = "server" }
        }
    })

    ZoneRegistered = true
end

CreateThread(function()
    while not ZoneRegistered do
        registerVault()
        Wait(1000)
    end
end)

AddEventHandler("onClientResourceStart",function(resourceName)
    if resourceName == "target" then
        ZoneRegistered = false
        registerVault()
    end
end)

AddEventHandler("onResourceStop",function(resourceName)
    if resourceName == GetCurrentResourceName() and ZoneRegistered and GetResourceState("target") == "started" then
        exports.target:RemCircleZone(ZoneName)
    end
end)
