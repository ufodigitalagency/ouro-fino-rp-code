local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")
local vRP = Proxy.getInterface("vRP")
local vKEYBOARD = Tunnel.getInterface("keyboard")

local Prepared = false
local VaultLock = false
local RateLimits = {}
local DistributionRoleCache = {}
local LaboratoryRoleCache = {}
local SulfuricPassportLocks = {}
local SulfuricOrganizationLock = nil
local SulfuricLockSequence = 0
local SulfuricCooldownUntil = 0

local function log(message)
    print("[saojudas/operations] "..message)
end

local function notify(source,message,color)
    TriggerClientEvent("Notify",source,"Sao Judas",message,color or "amarelo",5000)
end

local function strictInteger(value)
    local raw = tostring(value or "")
    if not raw:match("^%d+$") then return nil end

    local amount = tonumber(raw)
    if not amount or amount <= 0 or amount ~= math.floor(amount) or amount > 2147483647 then
        return nil
    end

    return amount
end

local function prepareDatabase()
    if Prepared then return end

    exports.oxmysql:query_async([[CREATE TABLE IF NOT EXISTS sao_judas_vault_transactions (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        ReferenceKey VARCHAR(128) NOT NULL,
        Type VARCHAR(32) NOT NULL,
        Passport BIGINT NOT NULL,
        Activity VARCHAR(48) DEFAULT NULL,
        GrossAmount BIGINT NOT NULL DEFAULT 0,
        DirtyDelta BIGINT NOT NULL DEFAULT 0,
        CleanDelta BIGINT NOT NULL DEFAULT 0,
        Metadata LONGTEXT DEFAULT NULL,
        CreatedAt BIGINT NOT NULL,
        PRIMARY KEY (id),
        UNIQUE KEY uq_sao_judas_vault_reference (ReferenceKey),
        KEY idx_sao_judas_vault_created (CreatedAt),
        KEY idx_sao_judas_vault_passport (Passport)
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

local function isMember(Passport)
    return Passport and vRP.HasGroup(Passport,SaoJudasOperations.Group) and true or false
end

local function isLeader(Passport)
    return Passport and tonumber(vRP.HasPermission(Passport,SaoJudasOperations.Group)) == SaoJudasOperations.LeaderLevel or false
end

local function currentRole(Passport)
    local level = Passport and tonumber(vRP.HasPermission(Passport,SaoJudasOperations.Group))
    local hierarchy = level and vRP.Hierarchy(SaoJudasOperations.Group)
    return hierarchy and hierarchy[level] or nil
end

local function canUseWorkbench(Passport)
    if not isMember(Passport) then return false end
    return isLeader(Passport) or currentRole(Passport) == SaoJudasOperations.WorkbenchRole
end

local function ensureDistributionRole()
    local role = SaoJudasOperations.DistributionRole
    if not role or not role.TagName then return end

    exports.oxmysql:insert_async([[INSERT INTO painel_creative_tags (Image,Name,Members,Permission)
        SELECT '',?,'[]',?
        WHERE NOT EXISTS (
            SELECT 1 FROM painel_creative_tags
            WHERE LOWER(Permission) = LOWER(?) AND LOWER(Name) = LOWER(?)
        )]],{ role.TagName,SaoJudasOperations.Group,SaoJudasOperations.Group,role.TagName })
end

local function hasDistributionRole(Passport,skipCache)
    Passport = tonumber(Passport)
    if not Passport then return false end

    local now = os.time()
    local cached = DistributionRoleCache[Passport]
    if not skipCache and cached and cached.ExpiresAt >= now then
        return cached.Allowed
    end

    local role = SaoJudasOperations.DistributionRole
    local row = exports.oxmysql:single_async([[SELECT Members FROM painel_creative_tags
        WHERE LOWER(Permission) = LOWER(?) AND LOWER(Name) = LOWER(?) LIMIT 1]],{
        SaoJudasOperations.Group,role.TagName
    })

    local allowed = false
    if row and row.Members then
        local ok,members = pcall(json.decode,row.Members)
        if ok and type(members) == "table" then
            for _,member in ipairs(members) do
                if tonumber(member) == Passport then
                    allowed = true
                    break
                end
            end
        end
    end

    DistributionRoleCache[Passport] = { Allowed = allowed, ExpiresAt = now + 5 }
    return allowed
end

local function canUseDistribution(Passport,skipCache)
    if not isMember(Passport) then return false end
    return isLeader(Passport) or hasDistributionRole(Passport,skipCache)
end

local function ensureLaboratoryRole()
    local role = SaoJudasOperations.LaboratoryRole
    if not role or not role.TagName then return end

    exports.oxmysql:insert_async([[INSERT INTO painel_creative_tags (Image,Name,Members,Permission)
        SELECT '',?,'[]',?
        WHERE NOT EXISTS (
            SELECT 1 FROM painel_creative_tags
            WHERE LOWER(Permission) = LOWER(?) AND LOWER(Name) = LOWER(?)
        )]],{ role.TagName,SaoJudasOperations.Group,SaoJudasOperations.Group,role.TagName })
end

local function hasLaboratoryRole(Passport,skipCache)
    Passport = tonumber(Passport)
    if not Passport then return false end

    local now = os.time()
    local cached = LaboratoryRoleCache[Passport]
    if not skipCache and cached and cached.ExpiresAt >= now then
        return cached.Allowed
    end

    local role = SaoJudasOperations.LaboratoryRole
    local row = exports.oxmysql:single_async([[SELECT Members FROM painel_creative_tags
        WHERE LOWER(Permission) = LOWER(?) AND LOWER(Name) = LOWER(?) LIMIT 1]],{
        SaoJudasOperations.Group,role.TagName
    })

    local allowed = false
    if row and row.Members then
        local ok,members = pcall(json.decode,row.Members)
        if ok and type(members) == "table" then
            for _,member in ipairs(members) do
                if tonumber(member) == Passport then
                    allowed = true
                    break
                end
            end
        end
    end

    LaboratoryRoleCache[Passport] = { Allowed = allowed, ExpiresAt = now + 5 }
    return allowed
end

local function canUseLaboratory(Passport,skipCache)
    if not isMember(Passport) then return false end
    return isLeader(Passport) or hasLaboratoryRole(Passport,skipCache)
end

local function atLocation(source,coords,maximumDistance)
    if GetPlayerRoutingBucket(source) ~= 0 then return false end
    return #(vRP.GetEntityCoords(source) - coords) <= maximumDistance
end

local function atLaboratory(source)
    local lab = SaoJudasOperations.Laboratory
    return lab.Enabled and atLocation(source,lab.Coords,lab.ServerDistance) or false
end

local function labLog(message)
    print("[saojudas/laboratory] "..message)
end

local function validateLaboratoryPlayerState(source)
    local lab = SaoJudasOperations.Laboratory
    if not lab.Enabled then return false,"laboratory_disabled" end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false,"player_not_found" end
    if GetEntityHealth(ped) <= 100 then return false,"player_dead" end
    if vRP.InsideVehicle(source) then return false,"player_in_vehicle" end
    if Player(source).state.Safezone then return false,"safezone" end
    if Player(source).state.Handcuff then return false,"player_handcuffed" end
    if Player(source).state.Buttons then return false,"player_busy" end
    if GetPlayerRoutingBucket(source) ~= 0 then return false,"routing_bucket_blocked" end

    return true
end

local function canAccessLaboratory(source)
    local Passport = vRP.Passport(source)
    if not Passport then return false,"invalid_passport" end

    local stateValid,stateReason = validateLaboratoryPlayerState(source)
    if not stateValid then return false,stateReason end
    if not isMember(Passport) then return false,"not_member" end
    if not canUseLaboratory(Passport) then return false,"role_missing" end
    if not atLaboratory(source) then return false,"too_far" end

    return true,"ok"
end

local function suppliesLog(message)
    print("[saojudas/supplies] "..message)
end

local function supplierCooldownRemaining()
    return math.max(0,SulfuricCooldownUntil - os.time())
end

local function friendlyDuration(seconds)
    seconds = math.max(0,tonumber(seconds) or 0)
    local minutes = math.floor(seconds / 60)
    local remainingSeconds = math.floor(seconds % 60)
    if minutes > 0 and remainingSeconds > 0 then
        return ("%s min e %s s"):format(minutes,remainingSeconds)
    elseif minutes > 0 then
        return ("%s min"):format(minutes)
    end
    return ("%s s"):format(remainingSeconds)
end

local function validateSulfuricSupplierAccess(source,skipRoleCache)
    local supplier = SaoJudasOperations.SulfuricSupplier
    if not supplier or not supplier.Enabled then return nil,"supplier_disabled" end

    local Passport = vRP.Passport(source)
    if not Passport then return nil,"invalid_passport" end
    if not isMember(Passport) then return nil,"not_member" end
    if not canUseLaboratory(Passport,skipRoleCache == true) then return nil,"role_missing" end
    if GetPlayerRoutingBucket(source) ~= 0 then return nil,"routing_bucket_blocked" end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil,"player_not_found" end
    if GetEntityHealth(ped) <= 100 then return nil,"player_dead" end
    if vRP.InsideVehicle(source) then return nil,"player_in_vehicle" end
    if Player(source).state.Safezone then return nil,"safezone" end
    if Player(source).state.Handcuff then return nil,"player_handcuffed" end
    if not atLocation(source,supplier.Coords,supplier.ServerDistance) then return nil,"too_far" end

    return Passport,"ok"
end

local function clearExpiredSulfuricLock()
    local lock = SulfuricOrganizationLock
    if lock and lock.ExpiresAt < os.time() then
        if SulfuricPassportLocks[lock.Passport] == lock then
            SulfuricPassportLocks[lock.Passport] = nil
        end
        SulfuricOrganizationLock = nil
    end
end

local function acquireSulfuricLock(source,Passport)
    clearExpiredSulfuricLock()
    if SulfuricPassportLocks[Passport] then return nil,"purchase_in_progress" end
    if SulfuricOrganizationLock then return nil,"supplier_busy" end

    SulfuricLockSequence = SulfuricLockSequence + 1
    local lock = {
        Token = ("%s:%s:%s"):format(Passport,GetGameTimer(),SulfuricLockSequence),
        Source = source,
        Passport = Passport,
        ExpiresAt = os.time() + (tonumber(SaoJudasOperations.SulfuricSupplier.LockTimeoutSeconds) or 90)
    }
    SulfuricPassportLocks[Passport] = lock
    SulfuricOrganizationLock = lock
    return lock
end

local function sulfuricLockActive(lock)
    clearExpiredSulfuricLock()
    return lock and SulfuricOrganizationLock == lock and SulfuricPassportLocks[lock.Passport] == lock
end

local function releaseSulfuricLock(lock)
    if not lock then return end
    if SulfuricPassportLocks[lock.Passport] == lock then SulfuricPassportLocks[lock.Passport] = nil end
    if SulfuricOrganizationLock == lock then SulfuricOrganizationLock = nil end
end

local function inventoryExactAmount(Passport,Item)
    local amount = 0
    for _,entry in pairs(vRP.Inventory(Passport)) do
        if entry.item == Item then amount = amount + entry.amount end
    end
    return amount
end

local function inventorySlotAmount(Passport,Item,Slot)
    local entry = vRP.Inventory(Passport)[tostring(Slot)]
    return entry and entry.item == Item and entry.amount or 0
end

local function sulfuricOutputSlot(Passport,Item)
    local inventory = vRP.Inventory(Passport)
    for slot,entry in pairs(inventory) do
        if entry.item == Item then return tostring(slot) end
    end

    for number = 5,vRP.InventorySlots(Passport) do
        local slot = tostring(number)
        if not inventory[slot] then return slot end
    end
end

local function takeCleanPayment(Passport,amount)
    local cash = vRP.ConsultItem(Passport,"dollar",amount)
    if cash and vRP.TakeItem(Passport,cash.Item,amount,false,cash.Slot) then
        return { Type = "cash", Item = cash.Item, Slot = tostring(cash.Slot), Amount = amount }
    end

    if vRP.PaymentBank(Passport,amount,false) then
        return { Type = "bank", Amount = amount }
    end
end

local function refundCleanPayment(Passport,payment)
    if not payment then return false end
    if payment.Type == "cash" then
        local before = inventoryExactAmount(Passport,payment.Item)
        vRP.GiveItem(Passport,payment.Item,payment.Amount,false,payment.Slot)
        return inventoryExactAmount(Passport,payment.Item) - before == payment.Amount
    elseif payment.Type == "bank" then
        local before = vRP.GetBank(Passport)
        vRP.GiveBank(Passport,payment.Amount,false)
        return vRP.GetBank(Passport) - before == payment.Amount
    end
    return false
end

local function safeRefundCleanPayment(Passport,payment)
    local ok,refunded = pcall(refundCleanPayment,Passport,payment)
    if not ok then return false,refunded end
    return refunded == true,nil
end

local function balances()
    prepareDatabase()
    local row = exports.oxmysql:single_async([[SELECT
        COALESCE(SUM(DirtyDelta),0) AS DirtyBalance,
        COALESCE(SUM(CleanDelta),0) AS CleanPending
        FROM sao_judas_vault_transactions]]) or {}

    return math.max(0,tonumber(row.DirtyBalance) or 0),math.max(0,tonumber(row.CleanPending) or 0)
end

local function insertLedger(referenceKey,entryType,Passport,activity,grossAmount,dirtyDelta,cleanDelta,metadata)
    prepareDatabase()
    local inserted = exports.oxmysql:insert_async([[INSERT IGNORE INTO sao_judas_vault_transactions
        (ReferenceKey,Type,Passport,Activity,GrossAmount,DirtyDelta,CleanDelta,Metadata,CreatedAt)
        VALUES (?,?,?,?,?,?,?,?,?)]],{
        tostring(referenceKey),tostring(entryType),tonumber(Passport) or 0,activity,
        tonumber(grossAmount) or 0,tonumber(dirtyDelta) or 0,tonumber(cleanDelta) or 0,
        metadata and json.encode(metadata) or nil,os.time()
    })

    return inserted and tonumber(inserted) and tonumber(inserted) > 0 or false
end

local function creditDirty(Passport,amount,referenceKey,activity,metadata)
    amount = strictInteger(amount)
    if not Passport or not amount or not referenceKey then return false,"invalid_credit" end

    local inserted = insertLedger(
        "dirty-credit:"..tostring(referenceKey),"activity_credit",Passport,
        tostring(activity or "unknown"),amount,amount,0,metadata
    )

    return inserted,inserted and "ok" or "duplicate_or_database_error"
end

local function creditCleanPending(Passport,amount,referenceKey,activity,metadata)
    amount = strictInteger(amount)
    if not Passport or not amount or not referenceKey then return false,"invalid_credit" end

    local inserted = insertLedger(
        "clean-credit:"..tostring(referenceKey),"clean_pending_credit",Passport,
        tostring(activity or "external_wash"),amount,0,amount,metadata
    )

    return inserted,inserted and "ok" or "duplicate_or_database_error"
end

local function atWorkbench(source)
    local workbench = SaoJudasOperations.Workbench
    return workbench.Enabled and atLocation(source,workbench.TargetCoords,workbench.ServerDistance) or false
end

local function leaderAtVault(source)
    local Passport = vRP.Passport(source)
    if not isMember(Passport) then return nil,"Somente membros de Sao Judas podem acessar este ponto." end
    if not isLeader(Passport) then return nil,"Somente o chefe de Sao Judas pode acessar o cofre financeiro." end

    local vault = SaoJudasOperations.FinancialVault
    if not atLocation(source,vault.Coords,vault.ServerDistance) then
        return nil,"Aproxime-se do cofre financeiro."
    end

    return Passport
end

RegisterNetEvent("saoJudas:VaultStatus",function()
    local source = source
    if not rateAllowed(source,"vault_status",750) then return end

    local Passport,message = leaderAtVault(source)
    if not Passport then notify(source,message,"vermelho") return end

    local dirty,clean = balances()
    notify(source,("Saldo sujo: <b>$%s</b><br>Saldo limpo pendente: <b>$%s</b>."):format(Dotted(dirty),Dotted(clean)),"verde")
end)

RegisterNetEvent("saoJudas:DepositDirty",function()
    local source = source
    local settings = SaoJudasOperations.FinancialVault.ManualDirtyDeposit
    if not settings.Enabled or not rateAllowed(source,"dirty_deposit",settings.CooldownSeconds * 1000) then return end

    local Passport,message = leaderAtVault(source)
    if not Passport then
        notify(source,message or "Somente a lideranca de Sao Judas pode realizar este deposito.","vermelho")
        return
    end

    local input = vKEYBOARD.Primary(source,"Quantidade de dinheiro sujo")
    local amount = input and strictInteger(input[1]) or nil
    if not amount or amount < settings.MinimumAmount or amount > settings.MaximumPerTransaction then
        notify(source,("Informe um valor entre $%s e $%s."):format(Dotted(settings.MinimumAmount),Dotted(settings.MaximumPerTransaction)),"vermelho")
        return
    end

    local CurrentPassport,currentMessage = leaderAtVault(source)
    if CurrentPassport ~= Passport then
        notify(source,currentMessage or "A autorizacao para o cofre mudou.","vermelho")
        return
    end

    local item = "dirtydollar"
    local Consult = vRP.ConsultItem(Passport,item,amount)
    if not Consult then
        notify(source,"Voce nao possui essa quantidade de dinheiro sujo.","vermelho")
        return
    end

    if not vRP.Request(source,"Cofre de Sao Judas",("Adicionar <b>$%s</b> em dinheiro sujo ao cofre da faccao?"):format(Dotted(amount))) then
        return
    end

    CurrentPassport,currentMessage = leaderAtVault(source)
    if CurrentPassport ~= Passport then
        notify(source,currentMessage or "A autorizacao para o cofre mudou.","vermelho")
        return
    end

    Consult = vRP.ConsultItem(Passport,item,amount)
    if not Consult then
        notify(source,"Voce nao possui mais essa quantidade de dinheiro sujo.","vermelho")
        return
    end

    if VaultLock then
        notify(source,"O cofre esta processando outra operacao.","vermelho")
        return
    end

    VaultLock = true
    local Before = balances()
    local Reference = ("saojudas:manual-dirty-deposit:%s:%s:%s"):format(Passport,os.time(),GenerateString("DDLLDD"))
    local Removed = vRP.TakeItem(Passport,Consult.Item,amount,true,Consult.Slot)

    if not Removed then
        VaultLock = false
        notify(source,"Nao foi possivel concluir o deposito. Nenhum valor foi perdido.","vermelho")
        return
    end

    local Credited,Reason = creditDirty(Passport,amount,Reference,"manual_dirty_deposit",{
        OperationId = Reference,
        Source = "personal_inventory",
        Destination = "faction_dirty_balance",
        BalanceBefore = Before,
        BalanceAfter = Before + amount,
        Status = "completed"
    })

    if not Credited then
        vRP.GiveItem(Passport,Consult.Item,amount,true,Consult.Slot)
        VaultLock = false
        notify(source,"Nao foi possivel concluir o deposito. Nenhum valor foi perdido.","vermelho")
        log(("type=manual_dirty_deposit passport=%s amount=%s status=refunded reason=%s reference=%s"):format(Passport,amount,tostring(Reason),Reference))
        return
    end

    local After = balances()
    VaultLock = false
    notify(source,("Voce adicionou <b>$%s</b> em dinheiro sujo ao cofre de Sao Judas.<br>Saldo sujo atual: <b>$%s</b>."):format(Dotted(amount),Dotted(After)),"verde")
    log(("type=manual_dirty_deposit passport=%s amount=%s before=%s after=%s status=completed reference=%s"):format(Passport,amount,Before,After,Reference))
end)

RegisterNetEvent("saoJudas:TransferClean",function()
    local source = source
    if not rateAllowed(source,"transfer_clean",1500) then return end

    local Passport,message = leaderAtVault(source)
    if not Passport then notify(source,message,"vermelho") return end

    local _,available = balances()
    if available <= 0 then
        notify(source,"Nao existe saldo limpo pendente.")
        return
    end

    local input = vKEYBOARD.Primary(source,"Valor para o banco do F9")
    local amount = input and strictInteger(input[1]) or nil
    if not amount or amount > available then
        notify(source,("Informe um valor entre $1 e $%s."):format(Dotted(available)),"vermelho")
        return
    end

    if not vRP.Request(source,"Cofre de Sao Judas",("Transferir <b>$%s</b> para o banco oficial da organizacao no F9?"):format(Dotted(amount))) then
        return
    end

    local CurrentPassport,currentMessage = leaderAtVault(source)
    if CurrentPassport ~= Passport then
        notify(source,currentMessage or "A autorizacao para o cofre mudou.","vermelho")
        return
    end

    if VaultLock then
        notify(source,"O cofre esta processando outra operacao.","vermelho")
        return
    end

    VaultLock = true
    local _,currentAvailable = balances()
    if currentAvailable < amount then
        VaultLock = false
        notify(source,"O saldo limpo pendente foi alterado. Consulte o cofre novamente.","vermelho")
        return
    end

    local reference = ("%s:%s:%s"):format(Passport,os.time(),GenerateString("DDLL"))
    local reserved = insertLedger(
        "clean-debit:"..reference,"bank_transfer",Passport,"f9_bank",amount,0,-amount
    )

    if not reserved then
        VaultLock = false
        notify(source,"Nao foi possivel reservar o saldo para transferencia.","vermelho")
        return
    end

    local ok,err = pcall(function()
        vRP.PermissionsUpdate(SaoJudasOperations.Group,"Bank","+",amount)
        exports.oxmysql:insert_async([[INSERT INTO painel_creative_transactions
            (Type,Passport,Value,Timestamp,Transfer,Permission) VALUES (?,?,?,?,?,?)]],{
            "VaultDeposit",Passport,amount,os.time(),nil,SaoJudasOperations.Group
        })
    end)

    if not ok then
        insertLedger("clean-rollback:"..reference,"bank_transfer_rollback",Passport,"f9_bank",amount,0,amount,{ Error = tostring(err) })
        VaultLock = false
        notify(source,"A transferencia falhou e o saldo foi devolvido ao cofre.","vermelho")
        log(("type=bank_transfer passport=%s amount=%s status=failed reason=%s"):format(Passport,amount,tostring(err)))
        return
    end

    VaultLock = false
    notify(source,("$%s foram enviados ao banco oficial de Sao Judas no F9."):format(Dotted(amount)),"verde")
    log(("type=bank_transfer passport=%s amount=%s status=completed reference=%s"):format(Passport,amount,reference))
end)

RegisterNetEvent("saoJudas:UseWorkbench",function()
    local source = source
    if not rateAllowed(source,"workbench",1000) then return end

    local Passport = vRP.Passport(source)
    local workbench = SaoJudasOperations.Workbench
    if not canUseWorkbench(Passport) then
        notify(source,"Voce nao esta autorizado a operar a bancada.","vermelho")
        return
    end

    if not atLocation(source,workbench.TargetCoords,workbench.ServerDistance) then
        notify(source,"Aproxime-se da bancada.","vermelho")
        return
    end

    if not workbench.RecipesEnabled then
        notify(source,"A bancada esta instalada, mas as receitas ainda nao foram liberadas.","amarelo")
        return
    end

    TriggerClientEvent("crafting:OpenSaoJudas",source)
end)

RegisterNetEvent("saoJudas:DebugStatus",function()
    if not SaoJudasOperations.Debug then return end

    local source = source
    local Passport = vRP.Passport(source)
    if not isLeader(Passport) then return end

    local dirty,clean = balances()
    log(("debug passport=%s member=%s leader=%s role=%s can_workbench=%s dirty=%s clean=%s"):format(
        tostring(Passport),tostring(isMember(Passport)),tostring(isLeader(Passport)),
        tostring(currentRole(Passport)),tostring(canUseWorkbench(Passport)),dirty,clean
    ))
end)

exports("IsLeader",isLeader)
exports("IsMember",isMember)
exports("CanUseWorkbench",canUseWorkbench)
exports("HasDistributionRole",hasDistributionRole)
exports("CanUseDistribution",canUseDistribution)
exports("HasLaboratoryRole",hasLaboratoryRole)
exports("CanUseLaboratory",canUseLaboratory)
exports("CanAccessLaboratory",canAccessLaboratory)
exports("AtWorkbench",atWorkbench)
exports("AtLaboratory",atLaboratory)
exports("Balances",balances)
exports("CreditDirty",creditDirty)
exports("CreditCleanPending",creditCleanPending)

CreateThread(function()
    Wait(1000)
    local ok,err = pcall(prepareDatabase)
    if not ok then log("database_prepare_failed reason="..tostring(err)) end

    local roleOk,roleErr = pcall(ensureDistributionRole)
    if not roleOk then log("distribution_role_prepare_failed reason="..tostring(roleErr)) end

    local labRoleOk,labRoleErr = pcall(ensureLaboratoryRole)
    if not labRoleOk then log("laboratory_role_prepare_failed reason="..tostring(labRoleErr)) end
end)

local LabStateMessages = {
    laboratory_disabled = "O laboratorio esta temporariamente desabilitado.",
    player_not_found    = "Voce nao pode acessar o laboratorio neste momento.",
    player_dead         = "Voce nao pode utilizar o laboratorio neste estado.",
    player_in_vehicle   = "Saia do veiculo para utilizar o laboratorio.",
    safezone            = "Nao e possivel utilizar o laboratorio nesta area.",
    player_handcuffed   = "Voce nao pode utilizar o laboratorio algemado.",
    player_busy         = "Voce ja esta realizando outra acao.",
    routing_bucket_blocked = "O laboratorio nao esta disponivel nesta dimensao."
}

RegisterNetEvent("saoJudas:UseLaboratory",function()
    local source = source
    if not rateAllowed(source,"laboratory",1000) then return end

    local Passport = vRP.Passport(source)
    local lab = SaoJudasOperations.Laboratory

    if not Passport then
        labLog(("source=%s status=access_denied reason=invalid_passport"):format(source))
        return
    end

    local stateValid,stateReason = validateLaboratoryPlayerState(source)
    if not stateValid then
        notify(source,LabStateMessages[stateReason] or "Voce nao pode acessar o laboratorio neste momento.","vermelho")
        labLog(("passport=%s source=%s status=access_denied reason=%s"):format(Passport,source,stateReason))
        return
    end

    if not isMember(Passport) then
        notify(source,"Voce nao esta autorizado a utilizar o laboratorio de Sao Judas.","vermelho")
        labLog(("passport=%s source=%s status=access_denied reason=not_member"):format(Passport,source))
        return
    end

    if not canUseLaboratory(Passport) then
        notify(source,"Voce nao esta autorizado a utilizar o laboratorio de Sao Judas.","vermelho")
        labLog(("passport=%s source=%s status=access_denied reason=role_missing"):format(Passport,source))
        return
    end

    if not atLaboratory(source) then
        notify(source,"Aproxime-se do laboratorio.","vermelho")
        labLog(("passport=%s source=%s status=access_denied reason=too_far distance=%.2f"):format(
            Passport,source,#(vRP.GetEntityCoords(source) - lab.Coords)
        ))
        return
    end

    TriggerClientEvent("crafting:OpenSaoJudasLaboratory",source)
    labLog(("passport=%s source=%s status=access_granted reason=interface_opened"):format(Passport,source))
end)

local SupplyAccessMessages = {
    supplier_disabled = "O fornecedor esta temporariamente indisponivel.",
    invalid_passport = "Seu personagem nao esta disponivel neste momento.",
    not_member = "Este fornecedor atende somente membros de Sao Judas.",
    role_missing = "Somente a lideranca ou Operadores de Laboratorio podem comprar este produto.",
    routing_bucket_blocked = "O fornecedor nao esta disponivel nesta dimensao.",
    player_not_found = "Seu personagem nao esta disponivel neste momento.",
    player_dead = "Voce nao pode realizar esta compra neste estado.",
    player_in_vehicle = "Saia do veiculo para falar com o fornecedor.",
    safezone = "Esta compra nao pode ser realizada em uma safezone.",
    player_handcuffed = "Voce nao pode realizar esta compra algemado.",
    too_far = "Aproxime-se do fornecedor."
}

RegisterNetEvent("saoJudas:BuySulfuric",function()
    local source = source
    local supplier = SaoJudasOperations.SulfuricSupplier
    local Passport,accessReason = validateSulfuricSupplierAccess(source,true)
    if not Passport then
        local CurrentPassport = vRP.Passport(source)
        notify(source,SupplyAccessMessages[accessReason] or "Voce nao pode acessar este fornecedor.","vermelho")
        suppliesLog(("passport=%s source=%s status=denied reason=%s"):format(
            tostring(CurrentPassport),source,tostring(accessReason)
        ))
        return
    end

    local remaining = supplierCooldownRemaining()
    if remaining > 0 then
        notify(source,("O fornecedor estara disponivel novamente em <b>%s</b>."):format(friendlyDuration(remaining)),"amarelo")
        suppliesLog(("passport=%s status=denied reason=cooldown remaining=%s"):format(Passport,remaining))
        return
    end

    local lock,lockReason = acquireSulfuricLock(source,Passport)
    if not lock then
        notify(source,"O fornecedor esta atendendo outra solicitacao. Tente novamente em instantes.","amarelo")
        suppliesLog(("passport=%s status=denied reason=%s"):format(Passport,tostring(lockReason)))
        return
    end

    local function finish()
        releaseSulfuricLock(lock)
    end

    local recoveryPayment = nil
    local recoveryRefundAttempted = false
    local deliveryAttempted = false
    local transactionCompleted = false
    local processOk,processError = xpcall(function()
    local item = supplier and supplier.Item
    local unitPrice = supplier and strictInteger(supplier.UnitPrice)
    local minimum = supplier and strictInteger(supplier.MinimumAmount)
    local maximum = supplier and strictInteger(supplier.MaximumAmount)
    if type(item) ~= "string" or not exports.vrp:ItemExist(item) or not unitPrice or not minimum or not maximum or minimum > maximum then
        finish()
        notify(source,"O fornecedor esta temporariamente indisponivel.","vermelho")
        suppliesLog(("passport=%s status=failed reason=invalid_server_config"):format(Passport))
        return
    end

    local input = vKEYBOARD.Primary(source,("Quantidade de %s (%s a %s)"):format(supplier.Label,minimum,maximum))
    if not sulfuricLockActive(lock) then
        finish()
        notify(source,"A solicitacao expirou. Tente novamente.","amarelo")
        suppliesLog(("passport=%s status=denied reason=lock_expired"):format(Passport))
        return
    end

    local quantity = input and strictInteger(input[1]) or nil
    if not quantity or quantity < minimum or quantity > maximum then
        finish()
        notify(source,("Informe uma quantidade inteira entre %s e %s."):format(minimum,maximum),"vermelho")
        suppliesLog(("passport=%s status=denied reason=invalid_quantity supplied=%s"):format(
            Passport,tostring(input and input[1])
        ))
        return
    end

    remaining = supplierCooldownRemaining()
    if remaining > 0 then
        finish()
        notify(source,("O fornecedor estara disponivel novamente em <b>%s</b>."):format(friendlyDuration(remaining)),"amarelo")
        suppliesLog(("passport=%s status=denied reason=cooldown remaining=%s"):format(Passport,remaining))
        return
    end

    local total = unitPrice * quantity
    if not vRP.Request(source,"Fornecedor de Sao Judas",("Comprar <b>%sx %s</b> por <b>$%s</b>?"):format(
        quantity,supplier.Label,Dotted(total)
    )) then
        finish()
        suppliesLog(("passport=%s status=denied reason=player_cancelled"):format(Passport))
        return
    end

    local CurrentPassport,currentReason = validateSulfuricSupplierAccess(source,true)
    if CurrentPassport ~= Passport or not sulfuricLockActive(lock) then
        finish()
        notify(source,SupplyAccessMessages[currentReason] or "A autorizacao para esta compra mudou.","vermelho")
        suppliesLog(("passport=%s status=denied reason=%s"):format(Passport,tostring(currentReason or "lock_expired")))
        return
    end

    if vRP.MaxItens(Passport,item,quantity) or not vRP.CheckWeight(Passport,item,quantity) then
        finish()
        notify(source,"Voce nao possui limite ou peso disponivel para esta compra.","vermelho")
        suppliesLog(("passport=%s item=%s quantity=%s status=denied reason=inventory_limit"):format(Passport,item,quantity))
        return
    end

    local outputSlot = sulfuricOutputSlot(Passport,item)
    if not outputSlot then
        finish()
        notify(source,"Voce nao possui um slot livre para receber o produto.","vermelho")
        suppliesLog(("passport=%s item=%s quantity=%s status=denied reason=no_output_slot"):format(Passport,item,quantity))
        return
    end

    local payment = takeCleanPayment(Passport,total)
    if not payment then
        finish()
        notify(source,"Dinheiro limpo insuficiente.","vermelho")
        suppliesLog(("passport=%s item=%s quantity=%s total=%s status=denied reason=insufficient_funds"):format(
            Passport,item,quantity,total
        ))
        return
    end
    recoveryPayment = payment

    local function refundAfterPayment(reason)
        recoveryRefundAttempted = true
        local refunded,refundError = safeRefundCleanPayment(Passport,payment)
        recoveryPayment = nil
        local status = refunded and "refunded" or "recovery_required"
        finish()
        notify(source,refunded and "A compra foi cancelada e o valor cobrado foi devolvido integralmente." or
            "A compra entrou em recuperacao segura. Avise a administracao.","vermelho")
        suppliesLog(("passport=%s item=%s quantity=%s total=%s payment=%s status=%s reason=%s refundError=%s"):format(
            Passport,item,quantity,total,payment.Type,status,reason,tostring(refundError)
        ))
        return refunded
    end

    CurrentPassport,currentReason = validateSulfuricSupplierAccess(source,true)
    if CurrentPassport ~= Passport or not sulfuricLockActive(lock) then
        refundAfterPayment(currentReason or "lock_expired_after_payment")
        return
    end

    if vRP.MaxItens(Passport,item,quantity) or not vRP.CheckWeight(Passport,item,quantity) then
        refundAfterPayment("inventory_changed_after_payment")
        return
    end

    outputSlot = sulfuricOutputSlot(Passport,item)
    if not outputSlot then
        refundAfterPayment("output_slot_changed_after_payment")
        return
    end

    local beforeOutput = inventorySlotAmount(Passport,item,outputSlot)
    deliveryAttempted = true
    local deliveryOk,deliveryError = pcall(function()
        vRP.GiveItem(Passport,item,quantity,false,outputSlot)
    end)
    local delivered = inventorySlotAmount(Passport,item,outputSlot) - beforeOutput
    if not deliveryOk or delivered ~= quantity then
        local outputRolledBack = delivered <= 0
        if delivered > 0 then
            outputRolledBack = vRP.TakeItem(Passport,item,delivered,false,outputSlot) and
                inventorySlotAmount(Passport,item,outputSlot) == beforeOutput
        end

        recoveryRefundAttempted = outputRolledBack
        local refunded,refundError = false,nil
        if outputRolledBack then
            refunded,refundError = safeRefundCleanPayment(Passport,payment)
        end
        recoveryPayment = nil
        local status = refunded and "refunded" or "recovery_required"
        local reason = refunded and "delivery_failed" or "delivery_rollback_failed"
        finish()
        TriggerClientEvent("inventory:Update",source)
        notify(source,refunded and "A entrega falhou e o valor cobrado foi devolvido integralmente." or
            "A compra entrou em recuperacao segura. Avise a administracao.","vermelho")
        suppliesLog(("passport=%s item=%s quantity=%s total=%s payment=%s status=%s reason=%s deliveryError=%s refundError=%s delivered=%s outputRolledBack=%s"):format(
            Passport,item,quantity,total,payment.Type,status,reason,tostring(deliveryError),tostring(refundError),delivered,tostring(outputRolledBack)
        ))
        return
    end

    recoveryPayment = nil
    SulfuricCooldownUntil = os.time() + (tonumber(supplier.CooldownSeconds) or 1800)
    transactionCompleted = true
    finish()
    TriggerClientEvent("inventory:Update",source)
    notify(source,("Compra concluida: <b>%sx %s</b> por <b>$%s</b>."):format(quantity,supplier.Label,Dotted(total)),"verde")
    suppliesLog(("passport=%s item=%s quantity=%s total=%s payment=%s status=completed cooldownUntil=%s"):format(
        Passport,item,quantity,total,payment.Type,SulfuricCooldownUntil
    ))
    end,debug.traceback)

    finish()
    if not processOk then
        local cleanError = tostring(processError):gsub("%s+"," ")
        if transactionCompleted then
            suppliesLog(("passport=%s status=completed reason=post_completion_error error=%s"):format(Passport,cleanError))
        else
            local hadPayment = recoveryPayment ~= nil
            local refunded = false
            local refundError = nil
            if hadPayment and not deliveryAttempted and not recoveryRefundAttempted then
                recoveryRefundAttempted = true
                refunded,refundError = safeRefundCleanPayment(Passport,recoveryPayment)
                recoveryPayment = nil
            end

            local status = hadPayment and (refunded and "refunded" or "recovery_required") or "failed"
            notify(source,refunded and "A operacao falhou e o valor cobrado foi devolvido integralmente." or
                "A operacao falhou de forma segura. Avise a administracao.","vermelho")
            suppliesLog(("passport=%s status=%s reason=unexpected_error error=%s refundError=%s"):format(
                Passport,status,cleanError,tostring(refundError)
            ))
        end
    end
end)

RegisterCommand("saojudas_vault_debug",function(source)
    if not SaoJudasOperations.Debug then return end

    local Passport = source > 0 and vRP.Passport(source) or 0
    if source > 0 and Passport ~= 1 then return end

    local dirty,clean = balances()
    local last = exports.oxmysql:single_async([[SELECT ReferenceKey,Type,Passport,Activity,GrossAmount,
        DirtyDelta,CleanDelta,CreatedAt FROM sao_judas_vault_transactions ORDER BY id DESC LIMIT 1]])

    log(("vault_debug source=%s passport=%s dirty=%s clean=%s distance_ok=%s leader=%s lock=%s last=%s"):format(
        source,tostring(Passport),dirty,clean,
        tostring(source > 0 and atLocation(source,SaoJudasOperations.FinancialVault.Coords,SaoJudasOperations.FinancialVault.ServerDistance) or false),
        tostring(Passport and isLeader(Passport) or false),tostring(VaultLock),json.encode(last or {})
    ))
end,false)

RegisterCommand("saojudas_lab_debug",function(source)
    if not SaoJudasOperations.Debug then return end

    local Passport = source > 0 and vRP.Passport(source) or 0
    if source > 0 and Passport ~= 1 then return end

    local lab = SaoJudasOperations.Laboratory
    local coords = source > 0 and vRP.GetEntityCoords(source) or vector3(0,0,0)
    local distance = #(coords - lab.Coords)
    local bucket = source > 0 and GetPlayerRoutingBucket(source) or -1

    local inVehicle = source > 0 and vRP.InsideVehicle(source) == true or false
    local safezone = source > 0 and Player(source).state.Safezone == true or false
    local handcuff = source > 0 and Player(source).state.Handcuff == true or false
    local buttons = source > 0 and Player(source).state.Buttons == true or false
    local ped = source > 0 and GetPlayerPed(source) or 0
    local alive = ped > 0 and GetEntityHealth(ped) > 100 or false
    local stateValid,stateReason = false,"console"
    if source > 0 then stateValid,stateReason = validateLaboratoryPlayerState(source) end

    labLog(("lab_debug source=%s passport=%s member=%s leader=%s has_lab_role=%s can_use_lab=%s distance=%.2f at_lab=%s bucket=%s enabled=%s exclusive=%s in_vehicle=%s safezone=%s handcuff=%s buttons=%s alive=%s player_state_valid=%s player_state_reason=%s"):format(
        source,tostring(Passport),
        tostring(Passport and isMember(Passport) or false),
        tostring(Passport and isLeader(Passport) or false),
        tostring(Passport and hasLaboratoryRole(Passport,true) or false),
        tostring(Passport and canUseLaboratory(Passport,true) or false),
        distance,
        tostring(source > 0 and atLaboratory(source) or false),
        tostring(bucket),
        tostring(lab.Enabled),
        tostring(lab.ExclusiveSaoJudasLaboratory),
        tostring(inVehicle),
        tostring(safezone),
        tostring(handcuff),
        tostring(buttons),
        tostring(alive),
        tostring(stateValid),
        tostring(stateReason or "ok")
    ))
end,false)

AddEventHandler("playerDropped",function()
    local droppedSource = source
    local Passport = vRP.Passport(source)
    if Passport then
        DistributionRoleCache[Passport] = nil
        LaboratoryRoleCache[Passport] = nil
    end

    local prefix = tostring(source)..":"
    for key in pairs(RateLimits) do
        if key:sub(1,#prefix) == prefix then
            RateLimits[key] = nil
        end
    end

    for lockedPassport,lock in pairs(SulfuricPassportLocks) do
        if lock.Source == droppedSource then
            SulfuricPassportLocks[lockedPassport] = nil
            if SulfuricOrganizationLock == lock then SulfuricOrganizationLock = nil end
        end
    end
end)
