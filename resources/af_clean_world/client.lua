local function clearAmbientArea()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then
        return
    end

    local coords = GetEntityCoords(ped)

    ClearAreaOfPeds(coords.x,coords.y,coords.z,Config.CleanupRadius,1)
end

CreateThread(function()
    while true do
        SetPedDensityMultiplierThisFrame(Config.PedDensity)
        SetScenarioPedDensityMultiplierThisFrame(Config.ScenarioPedDensity,Config.ScenarioPedDensity)
        SetVehicleDensityMultiplierThisFrame(Config.VehicleDensity)
        SetRandomVehicleDensityMultiplierThisFrame(Config.RandomVehicleDensity)
        SetParkedVehicleDensityMultiplierThisFrame(Config.ParkedVehicleDensity)
        SetGarbageTrucks(false)
        SetRandomBoats(false)
        SetCreateRandomCops(false)
        SetCreateRandomCopsNotOnScenarios(false)
        SetCreateRandomCopsOnScenarios(false)

        Wait(0)
    end
end)

CreateThread(function()
    if Config.ClearExistingPopulation then
        Wait(1000)
        clearAmbientArea()
    end
end)
