local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")

local vRP = Proxy.getInterface("vRP")
local API = {}

Tunnel.bindInterface("of_drivingschool",API)

local Prepared = false
local SessionSequence = 0
local PlateSequence = 0
local ExamSessions = {}
local ActivePassports = {}
local SpawnReservations = {}
local RateLimits = {}
local InstructorNpc = 0
local InstructorNetwork = 0
local InstructorNpcCreating = false
local InstructorNpcCreatedAt = 0
local InstructorNpcMissingChecks = 0
local InstructorNpcGeneration = 0
local InstructorOwnerSource = 0
local InstructorSetupRevision = 0
local InstructorOwnerConfigured = false
local InstructorNextConfigureAt = 0
local NextInstructorSpawnAt = 0
local InstructorRespawnReason = "server_start"
local ResourceStopping = false

local VALID_STATUS = {
    active = true,
    suspended = true,
    revoked = true
}

local CHECKLIST_TRANSITIONS = {
    WAITING_FOR_DRIVER = {
        Step = "ENTER_DRIVER_SEAT",
        Next = "WAITING_FOR_SEATBELT"
    },
    WAITING_FOR_SEATBELT = {
        Step = "SEATBELT",
        Next = "WAITING_FOR_ENGINE"
    },
    WAITING_FOR_ENGINE = {
        Step = "ENGINE",
        Next = "WAITING_FOR_LIGHTS"
    },
    WAITING_FOR_LIGHTS = {
        Step = "LIGHTS",
        Next = "READY_FOR_ROUTE"
    }
}

local function response(Success,Code,Message,Data)
    local Result = Data or {}
    Result.success = Success == true
    Result.code = Code or (Result.success and "ok" or "error")
    Result.message = Message or ""
    return Result
end

local function debugLog(Message)
    if Config.Debug then
        print("[of_drivingschool] "..Message)
    end
end

local function instructorValid(Ped)
    Ped = Ped or InstructorNpc
    return Ped ~= 0 and DoesEntityExist(Ped) and GetEntityType(Ped) == 1 and GetEntityModel(Ped) == GetHashKey(Config.Instructor.Model)
end

local function resetInstructorOwner(ResetRevision)
    InstructorOwnerSource = 0
    if ResetRevision then
        InstructorSetupRevision = 0
    end
    InstructorOwnerConfigured = false
    InstructorNextConfigureAt = 0
end

local function deleteInstructor(Ped)
    Ped = Ped or InstructorNpc
    if Ped ~= 0 and DoesEntityExist(Ped) then
        local Success,Error = pcall(DeleteEntity,Ped)
        if not Success then
            debugLog(("instructor_delete_failed entity=%s error=%s"):format(tostring(Ped),tostring(Error)))
        end
    end

    if Ped == InstructorNpc then
        InstructorNpc = 0
        InstructorNetwork = 0
        InstructorNpcCreatedAt = 0
        InstructorNpcMissingChecks = 0
        resetInstructorOwner(true)
    end
end


local function failInstructorCreation(Ped,Reason)
    deleteInstructor(Ped)
    InstructorNpcCreating = false
    NextInstructorSpawnAt = GetGameTimer() + (tonumber(Config.Instructor.RespawnDebounceMs) or 5000)
    InstructorRespawnReason = tostring(Reason or "creation_failed")
    debugLog(("instructor_creation_failed reason=%s retry_in_ms=%s"):format(
        tostring(Reason),
        tostring(tonumber(Config.Instructor.RespawnDebounceMs) or 5000)
    ))
    return false
end

local function createInstructor(Reason)
    if ResourceStopping then
        return false
    end

    if instructorValid() then
        return true
    end

    if InstructorNpc ~= 0 or InstructorNpcCreating or GetGameTimer() < NextInstructorSpawnAt then
        return false
    end

    InstructorNpcCreating = true
    local Coords = Config.Instructor.Coords
    local SpawnZ = Coords.z
    local Model = GetHashKey(Config.Instructor.Model)
    debugLog(("instructor_creation_attempt reason=%s model=%s coords=%.4f,%.4f,%.4f heading=%.2f"):format(
        tostring(Reason or "server_start"),
        tostring(Model),
        Coords.x,
        Coords.y,
        SpawnZ,
        Coords.w
    ))

    local CreateSuccess,Ped = pcall(CreatePed,4,Model,Coords.x,Coords.y,SpawnZ,Coords.w,true,true)
    if not CreateSuccess or not Ped or Ped == 0 then
        return failInstructorCreation(0,CreateSuccess and "create_ped_returned_zero" or "create_ped_failed:"..tostring(Ped))
    end

    local TimeoutAt = GetGameTimer() + (tonumber(Config.Instructor.CreateTimeoutMs) or 5000)
    while not ResourceStopping and not DoesEntityExist(Ped) and GetGameTimer() < TimeoutAt do
        Wait(50)
    end

    if ResourceStopping or not DoesEntityExist(Ped) then
        return failInstructorCreation(Ped,ResourceStopping and "resource_stopping" or "entity_creation_timeout")
    end

    local Network = NetworkGetNetworkIdFromEntity(Ped)
    while not ResourceStopping and DoesEntityExist(Ped) and (not Network or Network == 0) and GetGameTimer() < TimeoutAt do
        Wait(50)
        Network = NetworkGetNetworkIdFromEntity(Ped)
    end

    if ResourceStopping or not Network or Network == 0 then
        return failInstructorCreation(Ped,ResourceStopping and "resource_stopping" or "network_id_timeout")
    end

    local OrphanSuccess,OrphanError = pcall(SetEntityOrphanMode,Ped,2)
    if not OrphanSuccess then
        return failInstructorCreation(Ped,"orphan_mode_failed:"..tostring(OrphanError))
    end

    InstructorNpcGeneration = InstructorNpcGeneration + 1
    local StateSuccess,StateError = pcall(function()
        local State = Entity(Ped).state
        State:set("OFCNHInstructorGeneration",InstructorNpcGeneration,true)
        State:set("OFCNHInstructor",true,true)
    end)
    if not StateSuccess then
        return failInstructorCreation(Ped,"state_bag_failed:"..tostring(StateError))
    end

    InstructorNpc = Ped
    InstructorNetwork = Network
    InstructorNpcCreatedAt = GetGameTimer()
    InstructorNpcMissingChecks = 0
    InstructorNpcCreating = false
    NextInstructorSpawnAt = 0
    InstructorRespawnReason = nil
    resetInstructorOwner(true)
    debugLog(("instructor_created entity=%s network=%s generation=%s orphan_mode=KeepEntity spawn_z=%.4f"):format(
        InstructorNpc,
        InstructorNetwork,
        InstructorNpcGeneration,
        SpawnZ
    ))
    return true
end

local function configureInstructorOwner()
    if not instructorValid() then
        return
    end

    local Owner = tonumber(NetworkGetEntityOwner(InstructorNpc)) or -1
    if Owner <= 0 then
        if InstructorOwnerSource ~= 0 then
            debugLog(("instructor_owner_released entity=%s previous_owner=%s"):format(InstructorNpc,InstructorOwnerSource))
            resetInstructorOwner(false)
        end
        return
    end

    if Owner ~= InstructorOwnerSource then
        InstructorOwnerSource = Owner
        InstructorSetupRevision = InstructorSetupRevision + 1
        InstructorOwnerConfigured = false
        InstructorNextConfigureAt = 0
        debugLog(("instructor_owner_changed entity=%s network=%s owner=%s revision=%s"):format(
            InstructorNpc,
            InstructorNetwork,
            InstructorOwnerSource,
            InstructorSetupRevision
        ))
    end

    if not InstructorOwnerConfigured and GetGameTimer() >= InstructorNextConfigureAt then
        local StatePublished,StateError = pcall(function()
            Entity(InstructorNpc).state:set("OFCNHInstructorSetupRevision",InstructorSetupRevision,true)
        end)
        if StatePublished then
            TriggerClientEvent("of_drivingschool:ConfigureInstructor",InstructorOwnerSource,InstructorNetwork,InstructorNpcGeneration,InstructorSetupRevision)
        else
            debugLog(("instructor_setup_state_failed entity=%s owner=%s revision=%s error=%s"):format(
                InstructorNpc,
                InstructorOwnerSource,
                InstructorSetupRevision,
                tostring(StateError)
            ))
        end
        InstructorNextConfigureAt = GetGameTimer() + (tonumber(Config.Instructor.ConfigureRetryMs) or 5000)
    end
end

RegisterNetEvent("of_drivingschool:InstructorConfigured",function(Network,Generation,Revision)
    local PlayerSource = source
    if not instructorValid() or PlayerSource ~= InstructorOwnerSource then
        return
    end

    if tonumber(Network) ~= InstructorNetwork or tonumber(Generation) ~= InstructorNpcGeneration or tonumber(Revision) ~= InstructorSetupRevision then
        return
    end

    if tonumber(NetworkGetEntityOwner(InstructorNpc)) ~= PlayerSource then
        return
    end

    InstructorOwnerConfigured = true
    debugLog(("instructor_owner_configured entity=%s network=%s owner=%s generation=%s revision=%s"):format(
        InstructorNpc,
        InstructorNetwork,
        PlayerSource,
        InstructorNpcGeneration,
        InstructorSetupRevision
    ))
end)

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

local function sanitizeReason(Reason)
    Reason = tostring(Reason or ""):gsub("[%c<>]"," "):gsub("%s+"," ")
    Reason = Reason:match("^%s*(.-)%s*$") or ""

    if Reason == "" then
        Reason = "Sem motivo informado."
    end

    return Reason:sub(1,255)
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

    vRP.Prepare("ofcnh/createAudit",[[CREATE TABLE IF NOT EXISTS ouro_fino_driver_license_audit (
        Id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        TargetPassport INT NOT NULL,
        Category CHAR(1) NOT NULL,
        `Action` VARCHAR(32) NOT NULL,
        ActorPassport INT NULL,
        `Source` VARCHAR(32) NOT NULL,
        Reason VARCHAR(255) NOT NULL,
        CreatedAt INT NOT NULL,
        PRIMARY KEY (Id),
        INDEX idx_ofcnh_audit_target (TargetPassport,Category),
        INDEX idx_ofcnh_audit_created (CreatedAt)
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

    vRP.Prepare("ofcnh/audit",[[
        INSERT INTO ouro_fino_driver_license_audit
            (TargetPassport,Category,`Action`,ActorPassport,`Source`,Reason,CreatedAt)
        VALUES
            (@TargetPassport,@Category,@Action,NULLIF(@ActorPassport,0),@Source,@Reason,UNIX_TIMESTAMP())
    ]])

    vRP.Execute("ofcnh/create")
    vRP.Execute("ofcnh/createAudit")
    Prepared = true

    print("[of_drivingschool] Banco de CNH e auditoria preparados.")
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
        Reason = sanitizeReason(Reason)
    })

    local License = getLicense(Passport,Category)

    return License ~= nil and tostring(License.Status) == Status
end

local function writeAudit(TargetPassport,Category,Action,ActorPassport,ActionSource,Reason)
    prepareDatabase()

    vRP.Query("ofcnh/audit",{
        TargetPassport = normalizePassport(TargetPassport),
        Category = normalizeCategory(Category),
        Action = tostring(Action or "unknown"):sub(1,32),
        ActorPassport = normalizePassport(ActorPassport) or 0,
        Source = tostring(ActionSource or "unknown"):sub(1,32),
        Reason = sanitizeReason(Reason)
    })
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

local function passport(PlayerSource)
    return PlayerSource and PlayerSource > 0 and vRP.Passport(PlayerSource) or nil
end

local function validPlayer(PlayerSource)
    return PlayerSource and PlayerSource > 0 and GetPlayerName(PlayerSource) ~= nil
end

local function playerPed(PlayerSource)
    if not validPlayer(PlayerSource) then
        return 0
    end

    local Ped = GetPlayerPed(PlayerSource)
    if not Ped or Ped <= 0 or not DoesEntityExist(Ped) then
        return 0
    end

    return Ped
end

local function isAlive(PlayerSource)
    local Ped = playerPed(PlayerSource)
    return Ped ~= 0 and GetEntityHealth(Ped) > 100
end

local function playerDistance(PlayerSource,Coords)
    local Ped = playerPed(PlayerSource)
    if Ped == 0 or not Coords then
        return math.huge
    end

    return #(GetEntityCoords(Ped) - vector3(Coords.x,Coords.y,Coords.z))
end

local function isAdmin(Passport)
    return Passport and vRP.HasPermission(Passport,Config.Admin.Permission) and true or false
end

local function notify(PlayerSource,Message,Color,Duration)
    if validPlayer(PlayerSource) then
        TriggerClientEvent("Notify",PlayerSource,"Autoescola",Message,Color or "amarelo",Duration or 5000)
    end
end

local function rateAllowed(PlayerSource,Key,IntervalMs)
    local Now = GetGameTimer()
    local Identifier = tostring(PlayerSource)..":"..Key
    local ExpiresAt = RateLimits[Identifier] or 0

    if Now < ExpiresAt then
        return false
    end

    RateLimits[Identifier] = Now + IntervalMs
    return true
end

local function generateSessionToken(PlayerSource,Passport)
    SessionSequence = (SessionSequence % 999999) + 1
    return ("%s:%s:%s:%06d:%06d"):format(
        tostring(PlayerSource),
        tostring(Passport),
        tostring(os.time()),
        SessionSequence,
        math.random(0,999999)
    )
end

local function generateExamPlate()
    PlateSequence = (PlateSequence % 999) + 1
    return ("AUTO%03d"):format(PlateSequence)
end

local function releaseSlot(Session)
    if not Session or not Session.SpawnSlot then
        return
    end

    local Reservation = SpawnReservations[Session.SpawnSlot]
    if Reservation and Reservation.Source == Session.Source and Reservation.Token == Session.Token then
        SpawnReservations[Session.SpawnSlot] = nil
    end

    Session.SpawnSlot = nil
    Session.ReservationExpiresAt = nil
end

local function registeredVehicle(Session)
    if not Session or not Session.VehicleNetId then
        return 0
    end

    local Vehicle = NetworkGetEntityFromNetworkId(tonumber(Session.VehicleNetId) or 0)
    if not Vehicle or Vehicle == 0 or not DoesEntityExist(Vehicle) or GetEntityType(Vehicle) ~= 2 then
        return 0
    end

    if GetEntityModel(Vehicle) ~= GetHashKey(Config.Exam.VehicleModel) then
        return 0
    end

    local State = Entity(Vehicle).state
    if State.OFCNHExam ~= true or tonumber(State.OFCNHExamPassport) ~= tonumber(Session.Passport) then
        return 0
    end

    return Vehicle
end

local function deleteSessionVehicle(Session)
    local Vehicle = registeredVehicle(Session)
    if Vehicle ~= 0 then
        DeleteEntity(Vehicle)
    end
end

local function cleanupSession(PlayerSource,Reason,NotifyClient,Message)
    local Session = ExamSessions[PlayerSource]
    if not Session then
        return nil
    end

    releaseSlot(Session)
    ActivePassports[tostring(Session.Passport)] = nil
    ExamSessions[PlayerSource] = nil
    deleteSessionVehicle(Session)

    debugLog(("session_cleared source=%s passport=%s reason=%s"):format(
        tostring(PlayerSource),
        tostring(Session.Passport),
        tostring(Reason)
    ))

    if NotifyClient and validPlayer(PlayerSource) then
        TriggerClientEvent("of_drivingschool:ForceCleanup",PlayerSource,Session.Token,Reason,Message or "")
    end

    return Session
end


local function reserveSlot(Session)
    local Now = os.time()

    for Index in ipairs(Config.Exam.SpawnSlots) do
        if not Session.RejectedSlots[Index] then
            local Reservation = SpawnReservations[Index]
            if Reservation then
                local OwnerSession = ExamSessions[Reservation.Source]
                local Stale = not OwnerSession or OwnerSession.Token ~= Reservation.Token or Reservation.ExpiresAt < Now
                if Stale then
                    SpawnReservations[Index] = nil
                    Reservation = nil
                end
            end

            if not Reservation then
                Session.SpawnSlot = Index
                Session.ReservationExpiresAt = Now + Config.Exam.SpawnReservationSeconds
                SpawnReservations[Index] = {
                    Source = Session.Source,
                    Passport = Session.Passport,
                    Token = Session.Token,
                    ExpiresAt = Session.ReservationExpiresAt
                }
                return Index
            end
        end
    end

    return nil
end

local function sessionFor(PlayerSource,Token)
    local Session = ExamSessions[PlayerSource]
    local Passport = passport(PlayerSource)

    if not Session or not Passport or Session.Passport ~= Passport or Session.Token ~= tostring(Token or "") then
        return nil
    end

    return Session
end

local function waitVehicle(Network)
    Network = tonumber(Network)
    if not Network or Network <= 0 then
        return 0
    end

    local Timeout = GetGameTimer() + Config.Exam.ServerVehicleTimeoutMs
    local Vehicle = NetworkGetEntityFromNetworkId(Network)

    while (not Vehicle or Vehicle == 0 or not DoesEntityExist(Vehicle)) and GetGameTimer() < Timeout do
        Wait(100)
        Vehicle = NetworkGetEntityFromNetworkId(Network)
    end

    if not Vehicle or Vehicle == 0 or not DoesEntityExist(Vehicle) or GetEntityType(Vehicle) ~= 2 then
        return 0
    end

    return Vehicle
end

local function normalizePlate(Plate)
    return tostring(Plate or ""):gsub("%s+",""):upper()
end

local function waitVehicleOwner(Vehicle)
    local Timeout = GetGameTimer() + Config.Exam.ServerVehicleTimeoutMs
    local Owner = tonumber(NetworkGetEntityOwner(Vehicle)) or 0

    while Owner == 0 and DoesEntityExist(Vehicle) and GetGameTimer() < Timeout do
        Wait(100)
        Owner = tonumber(NetworkGetEntityOwner(Vehicle)) or 0
    end

    return Owner
end

local function waitVehiclePlate(Vehicle,ExpectedPlate)
    local Timeout = GetGameTimer() + Config.Exam.ServerVehicleTimeoutMs
    local Plate = normalizePlate(GetVehicleNumberPlateText(Vehicle))

    while Plate ~= ExpectedPlate and DoesEntityExist(Vehicle) and GetGameTimer() < Timeout do
        Wait(100)
        Plate = normalizePlate(GetVehicleNumberPlateText(Vehicle))
    end

    return Plate
end

local function spawnPhysicallyOccupied(Spawn,CandidateVehicle)
    local Center = vector3(Spawn.x,Spawn.y,Spawn.z)
    for _,Vehicle in ipairs(GetAllVehicles()) do
        if Vehicle ~= CandidateVehicle and DoesEntityExist(Vehicle) and #(GetEntityCoords(Vehicle) - Center) <= Config.Exam.SpawnOccupancyRadius then
            return true
        end
    end

    return false
end


function API.StartExam(RequestedCategory)
    local PlayerSource = source
    if not rateAllowed(PlayerSource,"start_exam",1000) then
        return response(false,"rate_limited","Aguarde um instante.")
    end

    local Passport = passport(PlayerSource)
    local Category = normalizeCategory(RequestedCategory)
    if not Passport then
        return response(false,"invalid_passport","Personagem nao encontrado.")
    end

    if not Category or Category ~= Config.Exam.Category then
        return response(false,"unsupported_category","Nesta fase somente a prova da Categoria B esta disponivel.")
    end

    if not isAlive(PlayerSource) then
        return response(false,"player_dead","Voce nao pode iniciar a prova neste estado.")
    end

    if playerDistance(PlayerSource,Config.Instructor.Coords) > Config.Exam.StartServerDistance then
        return response(false,"too_far","Aproxime-se do instrutor da Autoescola.")
    end

    if ExamSessions[PlayerSource] then
        return response(false,"source_active","Voce ja possui uma prova pratica ativa.")
    end

    local ExistingSource = ActivePassports[tostring(Passport)]
    if ExistingSource and ExamSessions[ExistingSource] then
        return response(false,"passport_active","Este personagem ja possui uma prova pratica ativa.")
    elseif ExistingSource then
        ActivePassports[tostring(Passport)] = nil
    end

    local LicenseCheckSuccess,AlreadyLicensed = pcall(hasLicense,Passport,Category)
    if not LicenseCheckSuccess then
        return response(false,"license_check_failed","Nao foi possivel verificar sua CNH agora.")
    end

    if AlreadyLicensed then
        return response(false,"license_active","Você já possui CNH Categoria B ativa.")
    end

    local Token = generateSessionToken(PlayerSource,Passport)
    local Session = {
        Source = PlayerSource,
        Passport = Passport,
        Category = Category,
        Token = Token,
        Plate = generateExamPlate(),
        State = "RESERVED",
        RejectedSlots = {},
        VehicleNetId = nil,
        CreatedAt = os.time(),
        LastActivityAt = os.time(),
        ExpiresAt = os.time() + Config.Exam.SessionTimeoutSeconds
    }

    ExamSessions[PlayerSource] = Session
    ActivePassports[tostring(Passport)] = PlayerSource

    local Slot = reserveSlot(Session)
    if not Slot then
        cleanupSession(PlayerSource,"no_spawn_slots",false)
        return response(false,"no_spawn_slots","Nao ha veiculos de prova disponiveis. Aguarde uma vaga.")
    end

    debugLog(("session_started source=%s passport=%s token=%s slot=%s"):format(PlayerSource,Passport,Token,Slot))
    return response(true,"reserved","Vaga reservada para a prova pratica.",{
        token = Token,
        slot = Slot,
        plate = Session.Plate,
        state = Session.State
    })
end

function API.RequestNextSlot(Token,CurrentSlot,Reason)
    local PlayerSource = source
    local Session = sessionFor(PlayerSource,Token)
    local Slot = tonumber(CurrentSlot)

    if not Session or Session.State ~= "RESERVED" then
        return response(false,"invalid_session","A sessao da prova nao esta mais disponivel.",{ terminate = true })
    end

    if not Slot or Session.SpawnSlot ~= Slot then
        return response(false,"invalid_slot","A reserva da vaga nao corresponde a sessao.")
    end

    Session.RejectedSlots[Slot] = true
    Session.LastActivityAt = os.time()
    releaseSlot(Session)

    local NextSlot = reserveSlot(Session)
    if not NextSlot then
        cleanupSession(PlayerSource,"no_spawn_slots",false)
        return response(false,"no_spawn_slots","Nao ha veiculos de prova disponiveis. Aguarde uma vaga.",{ terminate = true })
    end

    debugLog(("slot_changed source=%s passport=%s old=%s new=%s reason=%s"):format(
        PlayerSource,
        Session.Passport,
        Slot,
        NextSlot,
        sanitizeReason(Reason)
    ))

    return response(true,"slot_reserved","Nova vaga reservada.",{
        token = Session.Token,
        slot = NextSlot,
        plate = Session.Plate,
        state = Session.State
    })
end

function API.RegisterVehicle(Token,Slot,Network)
    local PlayerSource = source
    local Session = sessionFor(PlayerSource,Token)
    local SlotIndex = tonumber(Slot)
    local NetworkId = tonumber(Network)

    if not Session or Session.State ~= "RESERVED" then
        return response(false,"invalid_session","A sessao da prova nao esta mais disponivel.")
    end

    local Reservation = SlotIndex and SpawnReservations[SlotIndex]
    if Session.SpawnSlot ~= SlotIndex or not Reservation or Reservation.Source ~= PlayerSource or Reservation.Token ~= Session.Token then
        return response(false,"invalid_reservation","A vaga do veiculo nao esta reservada para esta prova.")
    end

    if Reservation.ExpiresAt < os.time() then
        cleanupSession(PlayerSource,"reservation_expired",false)
        return response(false,"reservation_expired","A reserva da vaga expirou.",{ terminate = true })
    end

    local Vehicle = waitVehicle(NetworkId)
    local Owner = Vehicle ~= 0 and waitVehicleOwner(Vehicle) or 0

    -- Entity and owner resolution yield while OneSync publishes the vehicle.
    -- Revalidate the authoritative session and reservation before accepting it.
    Session = sessionFor(PlayerSource,Token)
    Reservation = SlotIndex and SpawnReservations[SlotIndex]
    if not Session or Session.State ~= "RESERVED" or Session.SpawnSlot ~= SlotIndex or not Reservation or Reservation.Source ~= PlayerSource or Reservation.Token ~= tostring(Token or "") then
        return response(false,"invalid_session","A sessao ou a reserva expirou durante o registro do veiculo.",{ terminate = true })
    end

    if Vehicle == 0 or GetEntityModel(Vehicle) ~= GetHashKey(Config.Exam.VehicleModel) then
        cleanupSession(PlayerSource,"invalid_vehicle",false)
        return response(false,"invalid_vehicle","O veiculo criado nao corresponde ao modelo da Autoescola.",{ terminate = true })
    end

    Owner = tonumber(NetworkGetEntityOwner(Vehicle)) or 0
    if Owner ~= PlayerSource then
        cleanupSession(PlayerSource,"invalid_vehicle_owner",false)
        return response(false,"invalid_owner","Nao foi possivel confirmar o proprietario de rede do veiculo da prova.",{ terminate = true })
    end

    local ExpectedPlate = normalizePlate(Session.Plate)
    waitVehiclePlate(Vehicle,ExpectedPlate)

    -- Plate replication may also yield. Do not trust the previous context or
    -- owner after waiting; both must still match before any state bag is set.
    Session = sessionFor(PlayerSource,Token)
    Reservation = SlotIndex and SpawnReservations[SlotIndex]
    if not Session or Session.State ~= "RESERVED" or Session.SpawnSlot ~= SlotIndex or not Reservation or Reservation.Source ~= PlayerSource or Reservation.Token ~= tostring(Token or "") then
        return response(false,"invalid_session","A sessao ou a reserva expirou durante a validacao do veiculo.",{ terminate = true })
    end

    if not DoesEntityExist(Vehicle) or GetEntityType(Vehicle) ~= 2 or GetEntityModel(Vehicle) ~= GetHashKey(Config.Exam.VehicleModel) then
        cleanupSession(PlayerSource,"invalid_vehicle",false)
        return response(false,"invalid_vehicle","O veiculo de prova ficou indisponivel durante o registro.",{ terminate = true })
    end

    Owner = tonumber(NetworkGetEntityOwner(Vehicle)) or 0
    if Owner ~= PlayerSource then
        cleanupSession(PlayerSource,"invalid_vehicle_owner",false)
        return response(false,"invalid_owner","Nao foi possivel confirmar o proprietario de rede do veiculo da prova.",{ terminate = true })
    end

    local ActualPlate = normalizePlate(GetVehicleNumberPlateText(Vehicle))
    if ActualPlate ~= normalizePlate(Session.Plate) then
        cleanupSession(PlayerSource,"invalid_vehicle_plate",false)
        return response(false,"invalid_plate","A placa do veiculo de prova nao corresponde a sessao reservada.",{ terminate = true })
    end

    local Spawn = Config.Exam.SpawnSlots[SlotIndex]
    if not Spawn or #(GetEntityCoords(Vehicle) - vector3(Spawn.x,Spawn.y,Spawn.z)) > Config.Exam.VehicleRegistrationDistance then
        cleanupSession(PlayerSource,"invalid_vehicle_position",false)
        return response(false,"invalid_vehicle_position","O veiculo nao foi criado na vaga reservada.",{ terminate = true })
    end

    if spawnPhysicallyOccupied(Spawn,Vehicle) then
        cleanupSession(PlayerSource,"spawn_physically_occupied",false)
        return response(false,"spawn_physically_occupied","A vaga foi ocupada antes da confirmacao do veiculo.",{ terminate = true })
    end

    Session.VehicleNetId = NetworkId
    Session.State = "WAITING_FOR_DRIVER"
    Session.LastActivityAt = os.time()
    Reservation.ExpiresAt = Session.ExpiresAt

    Entity(Vehicle).state:set("OFCNHExam",true,true)
    Entity(Vehicle).state:set("OFCNHExamPassport",Session.Passport,true)
    Entity(Vehicle).state:set("Lockpick",Session.Passport,true)
    Entity(Vehicle).state:set("Fuel",100,true)
    SetVehicleDoorsLocked(Vehicle,1)

    debugLog(("vehicle_registered source=%s passport=%s network=%s slot=%s"):format(
        PlayerSource,
        Session.Passport,
        NetworkId,
        SlotIndex
    ))

    return response(true,"vehicle_registered",Config.Checklist.WAITING_FOR_DRIVER,{
        state = Session.State
    })
end

-- Seatbelt, engine and light observations originate client-side. This endpoint
-- only accepts them in order for the server-owned session and registered vehicle.
-- READY_FOR_ROUTE is readiness, not authorization: any future result or license
-- grant must be decided server-side, and this checklist must never call GrantLicense.
function API.AdvanceChecklist(Token,Step,Network)
    local PlayerSource = source
    if not rateAllowed(PlayerSource,"advance_checklist",150) then
        return response(false,"rate_limited","")
    end

    local Session = sessionFor(PlayerSource,Token)
    if not Session then
        return response(false,"invalid_session","A sessao da prova nao esta mais disponivel.",{ terminate = true })
    end

    if tonumber(Network) ~= tonumber(Session.VehicleNetId) then
        return response(false,"invalid_vehicle","Este nao e o veiculo registrado para a prova.")
    end

    local Transition = CHECKLIST_TRANSITIONS[Session.State]
    if not Transition or Transition.Step ~= tostring(Step or "") then
        return response(false,"invalid_transition","A etapa informada nao corresponde ao estado atual da prova.")
    end

    local Vehicle = registeredVehicle(Session)
    local Ped = playerPed(PlayerSource)
    if Vehicle == 0 or Ped == 0 or GetVehiclePedIsIn(Ped,false) ~= Vehicle or GetPedInVehicleSeat(Vehicle,-1) ~= Ped then
        return response(false,"driver_required","Permaneça no banco do motorista do veiculo da Autoescola.")
    end

    Session.State = Transition.Next
    Session.LastActivityAt = os.time()
    if Session.State == "READY_FOR_ROUTE" then
        Session.ReadyAt = os.time()
    end

    debugLog(("checklist_advanced source=%s passport=%s step=%s state=%s"):format(
        PlayerSource,
        Session.Passport,
        Transition.Step,
        Session.State
    ))

    return response(true,"checklist_advanced",Config.Checklist[Session.State],{
        state = Session.State
    })
end

function API.CancelExam(Token,Reason)
    local PlayerSource = source
    local Session = sessionFor(PlayerSource,Token)
    if not Session then
        return false
    end

    cleanupSession(PlayerSource,Reason or "client_cancel",false)
    return true
end

local function commandReason(Args,StartIndex)
    local Parts = {}
    for Index = StartIndex,#Args do
        Parts[#Parts + 1] = tostring(Args[Index])
    end

    return sanitizeReason(table.concat(Parts," "))
end

local function validTargetPassport(Value)
    local TargetPassport = normalizePassport(Value)
    if not TargetPassport or not vRP.Identity(TargetPassport) then
        return nil
    end

    return TargetPassport
end

local function performLicenseAction(PlayerSource,Args,Action,ActionSource,ActorPassport)
    local TargetPassport = validTargetPassport(Args[1])
    local Category = normalizeCategory(Args[2] or Config.DefaultCategory)
    local Reason = commandReason(Args,3)

    if not TargetPassport then
        return false,"Passaporte invalido."
    end

    if not Category then
        return false,"Categoria invalida. Use A, B, C ou D."
    end

    local Success,Changed
    if Action == "grant" then
        Success,Changed = pcall(grantLicense,TargetPassport,Category)
    else
        Success,Changed = pcall(changeLicenseStatus,TargetPassport,Category,"revoked",ActorPassport,Reason)
    end

    if not Success or not Changed then
        return false,Action == "grant" and "Nao foi possivel conceder a CNH." or "A CNH informada nao existe ou nao pode ser revogada."
    end

    local AuditSuccess,AuditError = pcall(writeAudit,TargetPassport,Category,Action,ActorPassport,ActionSource,Reason)
    if not AuditSuccess then
        print(("[of_drivingschool] CRITICAL audit_failed action=%s target=%s category=%s error=%s"):format(
            Action,
            TargetPassport,
            Category,
            tostring(AuditError)
        ))
    end

    local TargetSource = vRP.Source(TargetPassport)
    if TargetSource then
        local TargetMessage = Action == "grant"
            and ("Sua CNH Categoria %s foi concedida/reativada."):format(Category)
            or ("Sua CNH Categoria %s foi revogada. Motivo: %s"):format(Category,Reason)
        notify(TargetSource,TargetMessage,Action == "grant" and "verde" or "vermelho",8000)
    end

    local Message = Action == "grant"
        and ("CNH Categoria %s concedida/reativada para o passaporte %s."):format(Category,TargetPassport)
        or ("CNH Categoria %s revogada do passaporte %s."):format(Category,TargetPassport)

    return true,Message,{
        Passport = TargetPassport,
        Category = Category,
        Reason = Reason,
        AuditWritten = AuditSuccess
    }
end

RegisterCommand("cnhdar",function(PlayerSource,Args)
    if PlayerSource <= 0 then
        print("[of_drivingschool] Use ofcnhgrant no console do FXServer.")
        return
    end

    local ActorPassport = passport(PlayerSource)
    if not ActorPassport or not isAdmin(ActorPassport) then
        notify(PlayerSource,"Acesso negado.","vermelho")
        return
    end

    local Success,Message,Data = performLicenseAction(PlayerSource,Args,"grant","admin_command",ActorPassport)
    notify(PlayerSource,Message,Success and "verde" or "vermelho",7000)
    if Success and Data and not Data.AuditWritten then
        notify(PlayerSource,"A CNH foi alterada, mas o log persistente falhou. Avise a administracao.","amarelo",9000)
    end
end,false)

RegisterCommand("cnhremover",function(PlayerSource,Args)
    if PlayerSource <= 0 then
        print("[of_drivingschool] Use ofcnhrevoke no console do FXServer.")
        return
    end

    local ActorPassport = passport(PlayerSource)
    if not ActorPassport or not isAdmin(ActorPassport) then
        notify(PlayerSource,"Acesso negado.","vermelho")
        return
    end

    local Success,Message,Data = performLicenseAction(PlayerSource,Args,"revoke","admin_command",ActorPassport)
    notify(PlayerSource,Message,Success and "verde" or "vermelho",7000)
    if Success and Data and not Data.AuditWritten then
        notify(PlayerSource,"A CNH foi alterada, mas o log persistente falhou. Avise a administracao.","amarelo",9000)
    end
end,false)

RegisterCommand("cnhconsultar",function(PlayerSource,Args)
    if PlayerSource <= 0 then
        print("[of_drivingschool] Use ofcnhstatus no console do FXServer.")
        return
    end

    local ActorPassport = passport(PlayerSource)
    if not ActorPassport or not isAdmin(ActorPassport) then
        notify(PlayerSource,"Acesso negado.","vermelho")
        return
    end

    local TargetPassport = validTargetPassport(Args[1])
    if not TargetPassport then
        notify(PlayerSource,"Passaporte invalido.","vermelho")
        return
    end

    local Category = Args[2] and normalizeCategory(Args[2]) or nil
    if Args[2] and not Category then
        notify(PlayerSource,"Categoria invalida. Use A, B, C ou D.","vermelho")
        return
    end

    if Category then
        local License = getLicense(TargetPassport,Category)
        local Message = License
            and ("Passaporte %s | Categoria %s | Status: %s"):format(TargetPassport,Category,tostring(License.Status))
            or ("Passaporte %s nao possui registro da Categoria %s."):format(TargetPassport,Category)
        notify(PlayerSource,Message,License and "verde" or "amarelo",8000)
        return
    end

    local Licenses = listLicenses(TargetPassport)
    if #Licenses == 0 then
        notify(PlayerSource,("Passaporte %s nao possui CNH cadastrada."):format(TargetPassport),"amarelo")
        return
    end

    local Lines = {}
    for _,License in ipairs(Licenses) do
        Lines[#Lines + 1] = ("Categoria %s: %s"):format(tostring(License.Category),tostring(License.Status))
    end
    notify(PlayerSource,("Passaporte %s<br>%s"):format(TargetPassport,table.concat(Lines,"<br>")),"verde",10000)
end,false)

RegisterCommand("ofcnhcds",function(PlayerSource)
    if PlayerSource <= 0 then
        print("[of_drivingschool] O comando ofcnhcds deve ser usado por um Admin dentro do jogo.")
        return
    end

    local ActorPassport = passport(PlayerSource)
    if not ActorPassport or not isAdmin(ActorPassport) then
        notify(PlayerSource,"Acesso negado.","vermelho")
        return
    end

    TriggerClientEvent("of_drivingschool:PrintCoords",PlayerSource)
end,false)

-- Diagnostico visual: mostra somente a NUI para o Admin que executou.
-- Nao altera sessao, persistencia ou status de CNH.
RegisterCommand("ofcnhuitest",function(PlayerSource,Args)
    if PlayerSource <= 0 then
        print("[of_drivingschool] O comando ofcnhuitest deve ser usado por um Admin dentro do jogo.")
        return
    end

    local ActorPassport = passport(PlayerSource)
    if not ActorPassport or not isAdmin(ActorPassport) then
        notify(PlayerSource,"Acesso negado.","vermelho")
        return
    end

    local Result = tostring(Args[1] or ""):lower()
    local Reason = table.concat(Args," ",2)
    if Result == "aprovado" or Result == "approved" then
        TriggerClientEvent("of_drivingschool:ShowApproved",PlayerSource,Reason ~= "" and Reason or "Voce foi aprovado na prova pratica.",Config.Exam.Category)
    elseif Result == "reprovado" or Result == "failed" then
        TriggerClientEvent("of_drivingschool:ShowFailed",PlayerSource,Reason ~= "" and Reason or "A prova pratica nao foi concluida.",Config.Exam.Category)
    else
        notify(PlayerSource,"Uso: /ofcnhuitest <aprovado|reprovado> [motivo]","amarelo",7000)
    end
end,false)

RegisterCommand("ofcnhstatus",function(PlayerSource,Args)
    if PlayerSource ~= 0 then
        return
    end

    local TargetPassport = normalizePassport(Args[1])
    if not TargetPassport then
        print("[of_drivingschool] Uso: ofcnhstatus <passaporte> [categoria]")
        return
    end

    local Category = Args[2] and normalizeCategory(Args[2]) or nil
    if Args[2] and not Category then
        print("[of_drivingschool] Categoria invalida. Use A, B, C ou D.")
        return
    end

    if Category then
        local License = getLicense(TargetPassport,Category)
        if not License then
            print(("[of_drivingschool] Passaporte %s nao possui CNH %s."):format(TargetPassport,Category))
            return
        end

        print(("[of_drivingschool] Passaporte %s | Categoria %s | Status %s | Emissao %s | Atualizacao %s"):format(
            TargetPassport,
            tostring(License.Category),
            tostring(License.Status),
            tostring(License.IssuedAt),
            tostring(License.UpdatedAt)
        ))
        return
    end

    local Licenses = listLicenses(TargetPassport)
    if #Licenses == 0 then
        print(("[of_drivingschool] Passaporte %s nao possui CNH cadastrada."):format(TargetPassport))
        return
    end

    print(("[of_drivingschool] CNHs do passaporte %s:"):format(TargetPassport))
    for _,License in ipairs(Licenses) do
        print(("  Categoria %s | Status %s | Emissao %s | Atualizacao %s"):format(
            tostring(License.Category),
            tostring(License.Status),
            tostring(License.IssuedAt),
            tostring(License.UpdatedAt)
        ))
    end
end,false)

RegisterCommand("ofcnhgrant",function(PlayerSource,Args)
    if PlayerSource ~= 0 then
        return
    end

    local Success,Message,Data = performLicenseAction(0,Args,"grant","server_console",nil)
    print(("[of_drivingschool] %s"):format(Message))
    if Success and Data and not Data.AuditWritten then
        print("[of_drivingschool] CRITICAL A CNH foi alterada, mas o log persistente falhou.")
    end
end,false)

RegisterCommand("ofcnhrevoke",function(PlayerSource,Args)
    if PlayerSource ~= 0 then
        return
    end

    local Success,Message,Data = performLicenseAction(0,Args,"revoke","server_console",nil)
    print(("[of_drivingschool] %s"):format(Message))
    if Success and Data and not Data.AuditWritten then
        print("[of_drivingschool] CRITICAL A CNH foi alterada, mas o log persistente falhou.")
    end
end,false)

CreateThread(function()
    Wait(1000)

    local Success,Error = pcall(prepareDatabase)
    if not Success then
        print(("[of_drivingschool] Falha ao preparar banco de CNH: %s"):format(tostring(Error)))
    end
end)

CreateThread(function()
    while not ResourceStopping do
        if instructorValid() then
            if InstructorNpcMissingChecks > 0 then
                debugLog(("instructor_watchdog_recovered entity=%s after_missing_checks=%s"):format(InstructorNpc,InstructorNpcMissingChecks))
            end

            InstructorNpcMissingChecks = 0
            configureInstructorOwner()
        elseif InstructorNpc ~= 0 then
            local MissingThreshold = math.max(3,tonumber(Config.Instructor.MissingChecksBeforeRespawn) or 3)
            InstructorNpcMissingChecks = InstructorNpcMissingChecks + 1
            local ElapsedMs = InstructorNpcCreatedAt > 0 and math.max(0,GetGameTimer() - InstructorNpcCreatedAt) or 0
            debugLog(("instructor_watchdog_missing entity=%s network=%s check=%s/%s elapsed_since_creation_ms=%s"):format(
                tostring(InstructorNpc),
                tostring(InstructorNetwork),
                InstructorNpcMissingChecks,
                MissingThreshold,
                ElapsedMs
            ))

            if InstructorNpcMissingChecks >= MissingThreshold then
                if instructorValid() then
                    InstructorNpcMissingChecks = 0
                    debugLog(("instructor_watchdog_recovered entity=%s during_confirmation=true"):format(InstructorNpc))
                else
                    debugLog(("instructor_watchdog_lost_confirmed entity=%s network=%s elapsed_since_creation_ms=%s recreation_reason=consecutive_missing_checks"):format(
                        tostring(InstructorNpc),
                        tostring(InstructorNetwork),
                        ElapsedMs
                    ))
                    InstructorNpc = 0
                    InstructorNetwork = 0
                    InstructorNpcCreatedAt = 0
                    InstructorNpcMissingChecks = 0
                    InstructorRespawnReason = "watchdog_consecutive_missing_checks"
                    NextInstructorSpawnAt = GetGameTimer() + (tonumber(Config.Instructor.RespawnDebounceMs) or 5000)
                    resetInstructorOwner(true)
                end
            end
        elseif not InstructorNpcCreating and GetGameTimer() >= NextInstructorSpawnAt then
            createInstructor(InstructorRespawnReason)
        end

        Wait(math.max(500,tonumber(Config.Instructor.HealthCheckMs) or 2000))
    end
end)

CreateThread(function()
    while true do
        Wait(Config.Exam.ServerWatchdogMs)

        local Now = os.time()
        local Terminate = {}
        for PlayerSource,Session in pairs(ExamSessions) do
            local CurrentPassport = passport(PlayerSource)
            if not CurrentPassport or CurrentPassport ~= Session.Passport then
                Terminate[#Terminate + 1] = { Source = PlayerSource, Reason = "passport_lost", Message = "A prova pratica foi encerrada." }
            elseif not isAlive(PlayerSource) then
                Terminate[#Terminate + 1] = { Source = PlayerSource, Reason = "death", Message = "A prova pratica foi encerrada." }
            elseif Now >= Session.ExpiresAt then
                Terminate[#Terminate + 1] = { Source = PlayerSource, Reason = "timeout", Message = "O tempo da sessao da prova pratica expirou." }
            elseif Session.State == "RESERVED" and (not Session.ReservationExpiresAt or Now >= Session.ReservationExpiresAt) then
                Terminate[#Terminate + 1] = { Source = PlayerSource, Reason = "reservation_timeout", Message = "A reserva do veiculo de prova expirou." }
            elseif Session.VehicleNetId and registeredVehicle(Session) == 0 then
                Terminate[#Terminate + 1] = { Source = PlayerSource, Reason = "vehicle_missing", Message = "O veiculo da prova nao esta mais disponivel." }
            end
        end

        for _,Entry in ipairs(Terminate) do
            cleanupSession(Entry.Source,Entry.Reason,true,Entry.Message)
        end
    end
end)

AddEventHandler("playerDropped",function()
    local PlayerSource = source
    cleanupSession(PlayerSource,"player_dropped",false)

    local Prefix = tostring(PlayerSource)..":"
    for Key in pairs(RateLimits) do
        if Key:sub(1,#Prefix) == Prefix then
            RateLimits[Key] = nil
        end
    end
end)

AddEventHandler("onResourceStop",function(ResourceName)
    if ResourceName ~= GetCurrentResourceName() then
        return
    end

    ResourceStopping = true
    deleteInstructor(InstructorNpc)

    local Sources = {}
    for PlayerSource in pairs(ExamSessions) do
        Sources[#Sources + 1] = PlayerSource
    end

    for _,PlayerSource in ipairs(Sources) do
        cleanupSession(PlayerSource,"resource_stop",false)
    end

    ExamSessions = {}
    ActivePassports = {}
    SpawnReservations = {}
    RateLimits = {}
end)
