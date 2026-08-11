-----------------------------------------------------------------------------------------------------------------------------------------
-- HELPERS
-----------------------------------------------------------------------------------------------------------------------------------------
local function boolText(Value)
    return Value and "true" or "false"
end


local function nativeBool(Value)
    if Value == true then
        return true
    end

    if type(Value) == "number" then
        return Value ~= 0
    end

    return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- READSEATBELT
-----------------------------------------------------------------------------------------------------------------------------------------
local function readSeatbelt()
    local Success,State = pcall(function()
        return exports["hud"]:IsSeatbeltOn()
    end)

    if not Success then
        return nil,"hud_export_unavailable"
    end

    return State == true,nil
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- READVEHICLESTATE
-----------------------------------------------------------------------------------------------------------------------------------------
local function readVehicleState()
    local Ped = PlayerPedId()
    local Vehicle = GetVehiclePedIsIn(Ped,false)

    if Vehicle == 0 then
        return {
            InVehicle = false
        }
    end

    local _,LightsOn,HighBeamsOn = GetVehicleLightsState(Vehicle)
    local Seatbelt,SeatbeltError = readSeatbelt()

    return {
        InVehicle = true,
        Vehicle = Vehicle,
        IsDriver = GetPedInVehicleSeat(Vehicle,-1) == Ped,
        Seatbelt = Seatbelt,
        SeatbeltError = SeatbeltError,

        EngineOn = nativeBool(GetIsVehicleEngineRunning(Vehicle)),
        LightsOn = nativeBool(LightsOn) or nativeBool(HighBeamsOn),
        HighBeamsOn = nativeBool(HighBeamsOn),
        SpeedKmh = math.floor((GetEntitySpeed(Vehicle) * 3.6) + 0.5)
    }
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- OFCNHDIAG
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("ofcnhdiag",function()
    local State = readVehicleState()

    if not State.InVehicle then
        print("[of_drivingschool] DIAG | inVehicle=false")
        return
    end

    local SeatbeltText = State.Seatbelt == nil and ("unavailable:"..tostring(State.SeatbeltError)) or boolText(State.Seatbelt)

    print(("[of_drivingschool] DIAG | inVehicle=true driver=%s seatbelt=%s engine=%s lights=%s highbeams=%s speed=%dkm/h"):format(
        boolText(State.IsDriver),
        SeatbeltText,
        boolText(State.EngineOn),
        boolText(State.LightsOn),
        boolText(State.HighBeamsOn),
        State.SpeedKmh
    ))

end,false)
