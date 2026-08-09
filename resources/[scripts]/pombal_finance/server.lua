local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")
local vRP = Proxy.getInterface("vRP")
local vKEYBOARD = Tunnel.getInterface("keyboard")

local Prepared = false
local VaultLock = false
local RateLimits = {}

local function log(message)
    print("[pombal/finance] "..message)
end

local function notify(source,message,color)
    TriggerClientEvent("Notify",source,"Cofre do Pombal",message,color or "amarelo",5000)
end

local function strictInteger(value)
    local raw = tostring(value or "")
    if not raw:match("^%d+$") then return nil end
    local amount = tonumber(raw)
    if not amount or amount <= 0 or amount ~= math.floor(amount) or amount > 2147483647 then return nil end
    return amount
end

local function prepareDatabase()
    if Prepared then return end

    exports.oxmysql:query_async([[CREATE TABLE IF NOT EXISTS pombal_vault_transactions (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        ReferenceKey VARCHAR(128) NOT NULL,
        Type VARCHAR(32) NOT NULL,
        Passport BIGINT NOT NULL,
        Service VARCHAR(48) DEFAULT NULL,
        GrossAmount BIGINT NOT NULL DEFAULT 0,
        DirtyDelta BIGINT NOT NULL DEFAULT 0,
        CleanDelta BIGINT NOT NULL DEFAULT 0,
        Metadata LONGTEXT DEFAULT NULL,
        CreatedAt BIGINT NOT NULL,
        PRIMARY KEY (id),
        UNIQUE KEY uq_pombal_vault_reference (ReferenceKey),
        KEY idx_pombal_vault_created (CreatedAt),
        KEY idx_pombal_vault_passport (Passport)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci]])

    Prepared = true
end

local function rateAllowed(source,key,interval)
    local id = tostring(source)..":"..key
    local now = GetGameTimer()
    if now < (RateLimits[id] or 0) then return false end
    RateLimits[id] = now + interval
    return true
end

local function IsPombalLeader(Passport)
    return Passport and tonumber(vRP.HasPermission(Passport,PombalFinance.Group)) == PombalFinance.LeaderLevel or false
end

local function IsPombalMember(Passport)
    return Passport and vRP.HasGroup(Passport,PombalFinance.Group) and true or false
end

local function HasServicePermission(Passport,service)
    if not IsPombalMember(Passport) then return false end
    if IsPombalLeader(Passport) then return true end

    local level = tonumber(vRP.HasPermission(Passport,PombalFinance.Group))
    if not level then return false end

    local hierarchy = vRP.Hierarchy(PombalFinance.Group)
    local currentRole = hierarchy and hierarchy[level]
    local requiredRole = PombalFinance.ServiceRoles[service]

    return requiredRole and currentRole == requiredRole or false
end

local function CanUseChopshop(Passport)
    return HasServicePermission(Passport,"Chopshop")
end

local function CanUseMoneyWash(Passport)
    return HasServicePermission(Passport,"MoneyWash")
end

local function balances()
    prepareDatabase()
    local row = exports.oxmysql:single_async([[SELECT
        COALESCE(SUM(DirtyDelta),0) AS DirtyBalance,
        COALESCE(SUM(CleanDelta),0) AS CleanPending
        FROM pombal_vault_transactions]]) or {}

    return math.max(0,tonumber(row.DirtyBalance) or 0),math.max(0,tonumber(row.CleanPending) or 0)
end

local function insertLedger(referenceKey,entryType,Passport,service,grossAmount,dirtyDelta,cleanDelta,metadata)
    prepareDatabase()
    local inserted = exports.oxmysql:insert_async([[INSERT IGNORE INTO pombal_vault_transactions
        (ReferenceKey,Type,Passport,Service,GrossAmount,DirtyDelta,CleanDelta,Metadata,CreatedAt)
        VALUES (?,?,?,?,?,?,?,?,?)]],{
        tostring(referenceKey),tostring(entryType),tonumber(Passport) or 0,service,
        tonumber(grossAmount) or 0,tonumber(dirtyDelta) or 0,tonumber(cleanDelta) or 0,
        metadata and json.encode(metadata) or nil,os.time()
    })

    return inserted and tonumber(inserted) and tonumber(inserted) > 0 or false
end

local function ledgerReferenceExists(referenceKey)
    prepareDatabase()
    return exports.oxmysql:scalar_async("SELECT id FROM pombal_vault_transactions WHERE ReferenceKey = ? LIMIT 1",{ tostring(referenceKey) }) ~= nil
end

local function SplitRevenue(service,Passport,grossAmount,referenceKey)
    local settings = PombalFinance.Services[tostring(service or "")]
    local gross = strictInteger(grossAmount)
    if not settings or not Passport or not gross or not referenceKey then
        return { Success = false, Code = "invalid_split" }
    end

    local percentage = math.max(0,math.min(100,tonumber(settings.FactionPercentage) or 0))
    local faction = math.floor(gross * percentage / 100)
    local worker = gross - faction
    local inserted = insertLedger(
        "service:"..tostring(referenceKey),"service_share",Passport,tostring(service),gross,faction,0,
        { WorkerAmount = worker, FactionPercentage = percentage }
    )

    if not inserted then
        return { Success = false, Code = "duplicate_or_database_error" }
    end

    log(("type=service_share service=%s passport=%s gross=%s worker=%s faction=%s reference=%s"):format(service,Passport,gross,worker,faction,referenceKey))
    return { Success = true, WorkerAmount = worker, FactionAmount = faction, GrossAmount = gross }
end

local function ReserveDirty(Passport,amount,referenceKey,metadata)
    amount = strictInteger(amount)
    if not Passport or not amount or not referenceKey or VaultLock then return false,"busy" end
    VaultLock = true

    local ok,result,reason = pcall(function()
        local dirty = balances()
        if dirty < amount then return false,"insufficient_dirty" end
        if not insertLedger("dirty-debit:"..tostring(referenceKey),"wash_debit",Passport,"moneywash",amount,-amount,0,metadata) then
            return false,"duplicate_or_database_error"
        end
        return true,"ok"
    end)

    VaultLock = false
    if not ok then
        log("reserve_dirty_failed reason="..tostring(result))
        return false,"database_error"
    end
    return result,reason
end

local function RefundDirty(Passport,amount,referenceKey,metadata)
    amount = strictInteger(amount)
    return amount and insertLedger("dirty-refund:"..tostring(referenceKey),"wash_refund",Passport,"moneywash",amount,amount,0,metadata) or false
end

local function CreditCleanPending(Passport,amount,referenceKey,metadata)
    amount = strictInteger(amount)
    if not amount then return false end
    local reference = "clean-credit:"..tostring(referenceKey)
    return insertLedger(reference,"wash_complete",Passport,"moneywash",amount,0,amount,metadata) or ledgerReferenceExists(reference)
end

local function DebitCleanPending(Passport,amount,referenceKey)
    amount = strictInteger(amount)
    if not Passport or not amount or not referenceKey or VaultLock then return false,"busy" end
    VaultLock = true

    local ok,result,reason = pcall(function()
        local _,clean = balances()
        if clean < amount then return false,"insufficient_clean" end
        if not insertLedger("clean-debit:"..tostring(referenceKey),"bank_transfer",Passport,"f9_bank",amount,0,-amount) then
            return false,"duplicate_or_database_error"
        end
        return true,"ok"
    end)

    VaultLock = false
    if not ok then
        log("debit_clean_failed reason="..tostring(result))
        return false,"database_error"
    end
    return result,reason
end

local function memberAtVault(source)
    local Passport = vRP.Passport(source)
    if not IsPombalMember(Passport) then return nil,"Somente membros do Pombal podem acessar este cofre." end
    if GetPlayerRoutingBucket(source) ~= 0 then return nil,"O cofre nao esta disponivel nesta instancia." end

    local coords = vRP.GetEntityCoords(source)
    if #(coords - PombalFinance.Vault.Coords) > PombalFinance.Vault.ServerDistance then
        return nil,"Aproxime-se do cofre."
    end
    return Passport
end

local function leaderAtVault(source)
    local Passport,message = memberAtVault(source)
    if not Passport then return nil,message end
    if not IsPombalLeader(Passport) then return nil,"Somente o chefe do Pombal pode acessar este cofre." end
    return Passport
end

RegisterNetEvent("pombalFinance:VaultStatus",function()
    local source = source
    if not rateAllowed(source,"status",750) then return end
    local Passport,message = leaderAtVault(source)
    if not Passport then notify(source,message,"vermelho") return end
    local dirty,clean = balances()
    notify(source,("Saldo sujo: <b>$%s</b><br>Saldo limpo pendente: <b>$%s</b>."):format(Dotted(dirty),Dotted(clean)),"verde")
end)

RegisterNetEvent("pombalFinance:DepositDirty",function()
    local source = source
    if not rateAllowed(source,"dirty_deposit",1500) then return end

    local Passport,message = memberAtVault(source)
    if not Passport then notify(source,message,"vermelho") return end

    local item = PombalFinance.Vault.DirtyItem or "dirtydollar"
    local available = vRP.ItemAmount(Passport,item)
    if available <= 0 then
        notify(source,"Voce nao possui dinheiro sujo no inventario.")
        return
    end

    local input = vKEYBOARD.Primary(source,"Valor em dinheiro sujo")
    local amount = input and strictInteger(input[1]) or nil
    if not amount or amount > available then
        notify(source,("Informe um valor entre $1 e $%s."):format(Dotted(available)),"vermelho")
        return
    end

    if not vRP.Request(source,"Cofre do Pombal",("Depositar <b>$%s</b> em dinheiro sujo no cofre da faccao?"):format(Dotted(amount))) then return end
    if VaultLock then notify(source,"O cofre esta processando outra operacao.") return end

    VaultLock = true
    local removed = false
    local reference = ("%s:%s:%s"):format(Passport,os.time(),GenerateString("DDLLDD"))
    local Success,Error = pcall(function()
        local CurrentPassport,contextMessage = memberAtVault(source)
        if CurrentPassport ~= Passport then error(contextMessage or "context_changed") end
        if vRP.ItemAmount(Passport,item) < amount then error("insufficient_dirty_item") end
        if not vRP.TakeItem(Passport,item,amount,true) then error("take_failed") end
        removed = true

        if not insertLedger("manual-dirty:"..reference,"manual_dirty_deposit",Passport,"vault",amount,amount,0,{ Item = item }) then
            error("ledger_failed")
        end
    end)

    if not Success and removed then
        vRP.GenerateItem(Passport,item,amount,true)
    end
    VaultLock = false

    if not Success then
        notify(source,"Nao foi possivel concluir o deposito. O valor foi preservado.","vermelho")
        log(("type=manual_dirty_deposit passport=%s amount=%s status=failed reason=%s refunded=%s"):format(Passport,amount,tostring(Error),tostring(removed)))
        return
    end

    local dirty = balances()
    notify(source,("$%s em dinheiro sujo foram guardados. Saldo sujo do cofre: <b>$%s</b>."):format(Dotted(amount),Dotted(dirty)),"verde")
    log(("type=manual_dirty_deposit passport=%s amount=%s status=completed reference=%s"):format(Passport,amount,reference))
end)

RegisterNetEvent("pombalFinance:TransferClean",function()
    local source = source
    if not rateAllowed(source,"transfer",1500) then return end
    local Passport,message = leaderAtVault(source)
    if not Passport then notify(source,message,"vermelho") return end

    local _,available = balances()
    if available <= 0 then notify(source,"Nao existe saldo limpo pendente.") return end
    local input = vKEYBOARD.Primary(source,"Valor para o banco do F9")
    local amount = input and strictInteger(input[1]) or nil
    if not amount or amount > available then
        notify(source,("Informe um valor entre $1 e $%s."):format(Dotted(available)),"vermelho")
        return
    end
    if not vRP.Request(source,"Cofre do Pombal",("Transferir <b>$%s</b> para o banco oficial da organizacao no F9?"):format(Dotted(amount))) then return end

    local reference = ("%s:%s:%s"):format(Passport,os.time(),GenerateString("DDLL"))
    local reserved,reason = DebitCleanPending(Passport,amount,reference)
    if not reserved then
        notify(source,reason == "insufficient_clean" and "Saldo limpo pendente insuficiente." or "O cofre esta processando outra operacao.","vermelho")
        return
    end

    local ok,err = pcall(function()
        vRP.PermissionsUpdate(PombalFinance.Group,"Bank","+",amount)
        exports.oxmysql:insert_async([[INSERT INTO painel_creative_transactions
            (Type,Passport,Value,Timestamp,Transfer,Permission) VALUES (?,?,?,?,?,?)]],{
            "VaultDeposit",Passport,amount,os.time(),nil,PombalFinance.Group
        })
    end)

    if not ok then
        insertLedger("clean-rollback:"..reference,"bank_transfer_rollback",Passport,"f9_bank",amount,0,amount,{ Error = tostring(err) })
        notify(source,"A transferencia falhou e o saldo foi devolvido ao cofre.","vermelho")
        log(("type=bank_transfer passport=%s amount=%s status=failed reason=%s"):format(Passport,amount,tostring(err)))
        return
    end

    notify(source,("$%s foram enviados ao banco oficial do Pombal no F9."):format(Dotted(amount)),"verde")
    log(("type=bank_transfer passport=%s amount=%s status=completed reference=%s"):format(Passport,amount,reference))
end)

exports("IsLeader",IsPombalLeader)
exports("CanChopshop",CanUseChopshop)
exports("CanMoneyWash",CanUseMoneyWash)
exports("Balances",balances)
exports("SplitRevenue",SplitRevenue)
exports("ReserveDirty",ReserveDirty)
exports("RefundDirty",RefundDirty)
exports("CreditCleanPending",CreditCleanPending)

CreateThread(function()
    Wait(1000)
    local ok,err = pcall(prepareDatabase)
    if not ok then log("database_prepare_failed reason="..tostring(err)) end
end)

AddEventHandler("playerDropped",function()
    local prefix = tostring(source)..":"
    for key in pairs(RateLimits) do
        if key:sub(1,#prefix) == prefix then RateLimits[key] = nil end
    end
end)
