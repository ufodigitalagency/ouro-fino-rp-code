local Proxy = module("vrp","lib/Proxy")
local vRP = Proxy.getInterface("vRP")

local Prepared = false

local VALID_STATUS = {
    active = true,
    suspended = true,
    revoked = true
}

local function normalizePassport(Passport)
    Passport = tonumber(Passport)

    if not Passport or Passport <= 0 then
        return nil
    end

    return math.floor(Passport)
end

local function normalizeCategory(Category)
    Category = tostring(Category or Config.DefaultCategory or "B"):upper()

    if not Config.Categories[Category] then
        return nil
    end

    return Category
end

local function prepareDatabase()
    if Prepared then
        return
    end

    vRP.Prepare("ofcnh/create",[[CREATE TABLE IF NOT EXISTS ouro_fino_driver_licenses (
        Passport INT NOT NULL,
        Category CHAR(1) NOT NULL,
        Status VARCHAR(16) NOT NULL DEFAULT 'active',
        IssuedAt INT NOT NULL,
        UpdatedAt INT NOT NULL,
        SuspendedAt INT NULL,
        SuspendedBy INT NULL,
        SuspensionReason VARCHAR(255) NULL,
        PRIMARY KEY (Passport,Category),
        INDEX idx_ouro_fino_driver_licenses_status (Status)
    )]])

    vRP.Prepare("ofcnh/get",[[
        SELECT Passport,Category,Status,IssuedAt,UpdatedAt,SuspendedAt,SuspendedBy,SuspensionReason
        FROM ouro_fino_driver_licenses
        WHERE Passport = @Passport AND Category = @Category
        LIMIT 1
    ]])

    vRP.Prepare("ofcnh/list",[[
        SELECT Passport,Category,Status,IssuedAt,UpdatedAt,SuspendedAt,SuspendedBy,SuspensionReason
        FROM ouro_fino_driver_licenses
        WHERE Passport = @Passport
        ORDER BY Category ASC
    ]])

    vRP.Prepare("ofcnh/grant",[[
        INSERT INTO ouro_fino_driver_licenses
            (Passport,Category,Status,IssuedAt,UpdatedAt,SuspendedAt,SuspendedBy,SuspensionReason)
        VALUES
            (@Passport,@Category,'active',UNIX_TIMESTAMP(),UNIX_TIMESTAMP(),NULL,NULL,NULL)
        ON DUPLICATE KEY UPDATE
            Status = 'active',
            UpdatedAt = UNIX_TIMESTAMP(),
            SuspendedAt = NULL,
            SuspendedBy = NULL,
            SuspensionReason = NULL
    ]])

    vRP.Prepare("ofcnh/suspend",[[
        UPDATE ouro_fino_driver_licenses
        SET
            Status = 'suspended',
            UpdatedAt = UNIX_TIMESTAMP(),
            SuspendedAt = UNIX_TIMESTAMP(),
            SuspendedBy = @SuspendedBy,
            SuspensionReason = @Reason
        WHERE Passport = @Passport AND Category = @Category
    ]])

    vRP.Prepare("ofcnh/revoke",[[
        UPDATE ouro_fino_driver_licenses
        SET
            Status = 'revoked',
            UpdatedAt = UNIX_TIMESTAMP(),
            SuspendedAt = NULL,
            SuspendedBy = @SuspendedBy,
            SuspensionReason = @Reason
        WHERE Passport = @Passport AND Category = @Category
    ]])

    vRP.Execute("ofcnh/create")
    Prepared = true

    print("[of_drivingschool] Banco de CNH preparado.")
end

local function getLicense(Passport,Category)
    Passport = normalizePassport(Passport)
    Category = normalizeCategory(Category)

    if not Passport or not Category then
        return nil
    end

    prepareDatabase()

    return vRP.SingleQuery("ofcnh/get",{
        Passport = Passport,
        Category = Category
    })
end

local function listLicenses(Passport)
    Passport = normalizePassport(Passport)

    if not Passport then
        return {}
    end

    prepareDatabase()

    return vRP.Query("ofcnh/list",{
        Passport = Passport
    }) or {}
end

local function hasLicense(Passport,Category)
    local License = getLicense(Passport,Category)

    return License ~= nil and tostring(License.Status) == "active"
end

local function grantLicense(Passport,Category)
    Passport = normalizePassport(Passport)
    Category = normalizeCategory(Category)

    if not Passport or not Category then
        return false
    end

    prepareDatabase()

    vRP.Query("ofcnh/grant",{
        Passport = Passport,
        Category = Category
    })

    return hasLicense(Passport,Category)
end

local function changeLicenseStatus(Passport,Category,Status,ResponsiblePassport,Reason)
    Passport = normalizePassport(Passport)
    Category = normalizeCategory(Category)
    Status = tostring(Status or ""):lower()

    if not Passport or not Category or not VALID_STATUS[Status] then
        return false
    end

    if Status == "active" then
        return grantLicense(Passport,Category)
    end

    prepareDatabase()

    local Statement = Status == "suspended" and "ofcnh/suspend" or "ofcnh/revoke"

    vRP.Query(Statement,{
        Passport = Passport,
        Category = Category,
        SuspendedBy = normalizePassport(ResponsiblePassport),
        Reason = tostring(Reason or ""):sub(1,255)
    })

    local License = getLicense(Passport,Category)

    return License ~= nil and tostring(License.Status) == Status
end

exports("GetLicense",getLicense)
exports("ListLicenses",listLicenses)
exports("HasLicense",hasLicense)
exports("GrantLicense",grantLicense)

exports("SuspendLicense",function(Passport,Category,ResponsiblePassport,Reason)
    return changeLicenseStatus(Passport,Category,"suspended",ResponsiblePassport,Reason)
end)

exports("RevokeLicense",function(Passport,Category,ResponsiblePassport,Reason)
    return changeLicenseStatus(Passport,Category,"revoked",ResponsiblePassport,Reason)
end)

exports("ActivateLicense",function(Passport,Category)
    return changeLicenseStatus(Passport,Category,"active")
end)

CreateThread(function()
    Wait(1000)

    local Success,Error = pcall(prepareDatabase)

    if not Success then
        print(("[of_drivingschool] Falha ao preparar banco de CNH: %s"):format(tostring(Error)))
    end
end)

-- Leitura de diagnostico exclusivamente pelo console do FXServer.
-- Nao concede, suspende ou revoga CNH.
RegisterCommand("ofcnhstatus",function(source,Args)
    if source ~= 0 then
        return
    end

    local Passport = normalizePassport(Args[1])

    if not Passport then
        print("[of_drivingschool] Uso: ofcnhstatus <passaporte> [categoria]")
        return
    end

    local Category = Args[2] and normalizeCategory(Args[2]) or nil

    if Args[2] and not Category then
        print("[of_drivingschool] Categoria invalida. Use A, B, C ou D.")
        return
    end

    if Category then
        local License = getLicense(Passport,Category)

        if not License then
            print(("[of_drivingschool] Passaporte %s nao possui CNH %s."):format(Passport,Category))
            return
        end

        print(("[of_drivingschool] Passaporte %s | Categoria %s | Status %s | Emissao %s | Atualizacao %s"):format(
            Passport,
            tostring(License.Category),
            tostring(License.Status),
            tostring(License.IssuedAt),
            tostring(License.UpdatedAt)
        ))

        return
    end

    local Licenses = listLicenses(Passport)

    if #Licenses == 0 then
        print(("[of_drivingschool] Passaporte %s nao possui CNH cadastrada."):format(Passport))
        return
    end

    print(("[of_drivingschool] CNHs do passaporte %s:"):format(Passport))

    for _,License in ipairs(Licenses) do
        print(("  Categoria %s | Status %s | Emissao %s | Atualizacao %s"):format(
            tostring(License.Category),
            tostring(License.Status),
            tostring(License.IssuedAt),
            tostring(License.UpdatedAt)
        ))
    end
end,false)
