RegisterNetEvent("of_favelas:Teleport",function(Coords)
    if not Config.Debug or type(Coords) ~= "table" then
        return
    end

    local Ped = PlayerPedId()
    local Entity = Ped
    local Vehicle = GetVehiclePedIsIn(Ped,false)
    if Vehicle ~= 0 and GetPedInVehicleSeat(Vehicle,-1) == Ped then
        Entity = Vehicle
    end

    DoScreenFadeOut(300)
    while not IsScreenFadedOut() do
        Wait(0)
    end

    SetEntityCoordsNoOffset(Entity,Coords.x + 0.0,Coords.y + 0.0,Coords.z + 0.0,false,false,false)
    RequestCollisionAtCoord(Coords.x + 0.0,Coords.y + 0.0,Coords.z + 0.0)
    Wait(500)
    DoScreenFadeIn(300)
end)

RegisterNetEvent("of_favelas:PrintCoords",function()
    if not Config.Debug then
        return
    end

    local Coords = GetEntityCoords(PlayerPedId())
    local Heading = GetEntityHeading(PlayerPedId())
    print(("[of_favelas] coords=%.2f,%.2f,%.2f heading=%.2f"):format(Coords.x,Coords.y,Coords.z,Heading))
    TriggerEvent("Notify","Mapas",("Coordenadas enviadas ao F8: %.2f, %.2f, %.2f"):format(Coords.x,Coords.y,Coords.z),"azul",5000)
end)
