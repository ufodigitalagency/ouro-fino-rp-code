local postesCooldown = {}
local trabalhando = false

function DrawText3Ds(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

CreateThread(function()
    while true do
        local idle = 1000
        if ActiveJob == "eletricista" then
            local ped = PlayerPedId()
            if not IsPedInAnyVehicle(ped, false) then
                local pCoords = GetEntityCoords(ped)
                for _, propName in pairs(Config.Eletricista.props) do
                    local modelHash = GetHashKey(propName)
                    local poste = GetClosestObjectOfType(pCoords.x, pCoords.y, pCoords.z, 5.0, modelHash, false, false, false)

                    if DoesEntityExist(poste) then
                        idle = 5
                        local objCoords = GetEntityCoords(poste)
                        if not postesCooldown[poste] or GetGameTimer() > postesCooldown[poste] then
                            DrawText3Ds(objCoords.x, objCoords.y, objCoords.z + 1.5, "~y~[E]~w~ REPARAR")

                            if IsControlJustPressed(0, 38) and not trabalhando then
                                IniciarReparoEletrico(ped, poste)
                            end
                        else
                            DrawText3Ds(objCoords.x, objCoords.y, objCoords.z + 1.5, "~r~CONSERTADO")
                        end
                        break
                    end
                end
            end
        end
        Wait(idle)
    end
end)

function IniciarReparoEletrico(ped, poste)
    trabalhando = true
    local animDict = "amb@world_human_hammering@male@base"
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do Wait(10) end
    local objCoords = GetEntityCoords(poste)
    TaskTurnPedToFaceCoord(ped, objCoords.x, objCoords.y, objCoords.z, 1000)
    Wait(1000)
    TaskPlayAnim(ped, animDict, "base", 8.0, 8.0, -1, 1, 0, false, false, false)
    TriggerEvent("progress", 5000, "Reparando fiação...")
    Wait(5000)
    ClearPedTasks(ped)
    postesCooldown[poste] = GetGameTimer() + Config.Eletricista.cooldown
    TriggerServerEvent("cfWorks:eletricistaReward")
    trabalhando = false
end
