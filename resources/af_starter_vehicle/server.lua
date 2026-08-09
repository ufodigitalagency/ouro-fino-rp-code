local Proxy = module("vrp","lib/Proxy")
local vRP = Proxy.getInterface("vRP")

local StarterVehicle = "panto"
local Prepared = false

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

local function giveStarterVehicle(Passport)
    if not Passport then
        return
    end

    prepareStarterVehicle()

    local alreadyMarked = vRP.SingleQuery("afstarter/get",{ Passport = Passport, Vehicle = StarterVehicle })
    if alreadyMarked then
        return
    end

    if not vRP.SelectVehicle(Passport,StarterVehicle) then
        vRP.Query("vehicles/addVehicles",{
            Passport = Passport,
            Vehicle = StarterVehicle,
            Plate = vRP.GeneratePlate(),
            Weight = vehicleWeight(StarterVehicle),
            Work = 0
        })

        print(("[af_starter_vehicle] Panto entregue ao passaporte %s."):format(Passport))
    end

    vRP.Query("afstarter/set",{ Passport = Passport, Vehicle = StarterVehicle })
end

CreateThread(function()
    Wait(1000)
    prepareStarterVehicle()
end)

AddEventHandler("Connect",function(Passport)
    CreateThread(function()
        Wait(2000)

        local ok,err = pcall(function()
            giveStarterVehicle(Passport)
        end)

        if not ok then
            print(("[af_starter_vehicle] Erro ao entregar panto ao passaporte %s: %s"):format(Passport or "nil",err))
        end
    end)
end)
