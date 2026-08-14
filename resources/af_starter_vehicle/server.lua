local Proxy = module("vrp","lib/Proxy")
local vRP = Proxy.getInterface("vRP")

local StarterVehicle = "panto"
local Prepared = false
local GrantLocks = {}

local function prepareStarterVehicle()
    if Prepared then
        return
    end

    vRP.Prepare("afstarter/create",[[CREATE TABLE IF NOT EXISTS ouro_fino_starter_vehicles (
        Passport INT NOT NULL,
        Vehicle VARCHAR(60) NOT NULL,
        GivenAt INT NOT NULL,
        PRIMARY KEY (Passport,Vehicle)
    )]])
    vRP.Prepare("afstarter/get","SELECT Passport FROM ouro_fino_starter_vehicles WHERE Passport = @Passport AND Vehicle = @Vehicle LIMIT 1")
    vRP.Prepare("afstarter/set","INSERT IGNORE INTO ouro_fino_starter_vehicles (Passport,Vehicle,GivenAt) VALUES (@Passport,@Vehicle,UNIX_TIMESTAMP())")
    vRP.Prepare("afstarter/migrateBrioso","INSERT IGNORE INTO ouro_fino_starter_vehicles (Passport,Vehicle,GivenAt) SELECT Passport,@Vehicle,GivenAt FROM ouro_fino_starter_vehicles WHERE Vehicle = 'brioso'")
    vRP.Execute("afstarter/create")
    vRP.Execute("afstarter/migrateBrioso",{ Vehicle = StarterVehicle })

    Prepared = true
end

local function vehicleWeight(model)
    local ok,weight = pcall(function()
        return exports.vrp:VehicleWeight(model)
    end)

    if ok and weight and weight > 0 then
        return weight
    end

    return 20
end

local function giveStarterVehicle(Passport,Reason)
    Passport = tonumber(Passport)
    if not Passport or Passport <= 0 or Passport ~= math.floor(Passport) then
        return { success = false,status = "invalid_passport",granted = false }
    end

    local IdentitySuccess,Identity = pcall(vRP.Identity,Passport)
    if not IdentitySuccess or not Identity then
        return { success = false,status = IdentitySuccess and "invalid_passport" or "identity_check_failed",granted = false }
    end

    if GrantLocks[Passport] then
        return { success = false,status = "processing",granted = false }
    end

    GrantLocks[Passport] = true
    local Success,Result = pcall(function()
        prepareStarterVehicle()

        Reason = tostring(Reason or "unspecified"):lower()
        local AlreadyMarked = vRP.SingleQuery("afstarter/get",{ Passport = Passport, Vehicle = StarterVehicle })
        local OwnedVehicle = vRP.SelectVehicle(Passport,StarterVehicle)
        if OwnedVehicle then
            if not AlreadyMarked then
                local MarkSuccess,MarkError = pcall(vRP.Query,"afstarter/set",{ Passport = Passport, Vehicle = StarterVehicle })
                if not MarkSuccess then
                    print(("[af_starter_vehicle] WARN marker_write_failed passport=%s status=already_owned error=%s"):format(Passport,tostring(MarkError)))
                end
            end

            print(("[af_starter_vehicle] Panto já disponível para o passaporte %s; nenhuma duplicata criada."):format(Passport))
            return { success = true,status = "already_owned",granted = false,available = true,vehicle = StarterVehicle }
        end

        if AlreadyMarked and Reason ~= "practical_exam_pass" then
            print(("[af_starter_vehicle] Marcador existente para o passaporte %s; nenhuma nova entrega realizada."):format(Passport))
            return { success = true,status = "already_marked",granted = false,available = false,vehicle = StarterVehicle }
        end

        vRP.Query("vehicles/addVehicles",{
            Passport = Passport,
            Vehicle = StarterVehicle,
            Plate = vRP.GeneratePlate(),
            Weight = vehicleWeight(StarterVehicle),
            Work = 0
        })

        if not vRP.SelectVehicle(Passport,StarterVehicle) then
            return { success = false,status = "vehicle_insert_failed",granted = false }
        end

        local MarkSuccess,MarkError = pcall(vRP.Query,"afstarter/set",{ Passport = Passport, Vehicle = StarterVehicle })
        if not MarkSuccess then
            print(("[af_starter_vehicle] WARN marker_write_failed passport=%s status=granted error=%s"):format(Passport,tostring(MarkError)))
        end

        print(("[af_starter_vehicle] Panto entregue ao passaporte %s."):format(Passport))
        return { success = true,status = "granted",granted = true,available = true,vehicle = StarterVehicle }
    end)

    GrantLocks[Passport] = nil
    if not Success then
        print(("[af_starter_vehicle] ERROR grant_failed passport=%s error=%s"):format(Passport,tostring(Result)))
        return { success = false,status = "failure",granted = false }
    end

    return Result
end

CreateThread(function()
    Wait(1000)
    prepareStarterVehicle()
end)

exports("GiveStarterVehicle",function(Passport,Reason)
    local Result = giveStarterVehicle(Passport,Reason)
    print(("[af_starter_vehicle] grant_request passport=%s reason=%s status=%s"):format(
        tostring(Passport),
        tostring(Reason or "unspecified"):gsub("[\r\n]"," "):sub(1,80),
        tostring(Result and Result.status or "failure")
    ))
    return Result
end)
