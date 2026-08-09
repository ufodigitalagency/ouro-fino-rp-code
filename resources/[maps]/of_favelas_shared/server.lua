local Proxy = module("vrp","lib/Proxy")
local vRP = Proxy.getInterface("vRP")

if Config.Debug then
    RegisterCommand("favela_test",function(Source,Args)
        if Source <= 0 or tonumber(vRP.Passport(Source)) ~= tonumber(Config.AdminPassport) then
            return
        end

        local Name = string.lower(tostring(Args[1] or ""))
        if Name == "coords" then
            TriggerClientEvent("of_favelas:PrintCoords",Source)
            return
        end

        local Coords = Config.TestLocations[Name]
        if not Coords then
            TriggerClientEvent("Notify",Source,"Mapas","Use /favela_test pombal, saojudas ou coords.","amarelo",5000)
            return
        end

        TriggerClientEvent("of_favelas:Teleport",Source,{
            x = Coords.x,
            y = Coords.y,
            z = Coords.z
        })
    end)
end
