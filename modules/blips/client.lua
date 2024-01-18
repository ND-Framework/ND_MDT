local blips = {}

function blips.enable(status)
    local veh = cache.vehicle
    if not veh or cache.seat ~= -1 then return end

    local playerInfo = Bridge.getPlayerInfo()
    if not Bridge.hasAccess(playerInfo.job) then return end

    local blipColor = config.vehicleBlips[playerInfo.job]
    if not blipColor then return end

    local state = Entity(veh).state
    state.emergencyBlip = {
        player = cache.serverId,
        label = ("[%s] %s"):format(playerInfo.callsign, status),
        color = blipColor,
        sprite = config.policeAccess[playerInfo.job] and config.getPoliceVehicleBlip(veh) or config.fireAccess[playerInfo.job] and config.getFireVehicleBlip(veh) or 1
    }
end

function blips.disable()
    local veh = cache.vehicle
    if not veh then return end

    local state = Entity(veh).state
    if state.emergencyBlip then
        state.emergencyBlip = nil
    end
end

AddStateBagChangeHandler("emergencyBlip", nil, function(bagName, _, value)
    local playerInfo = Bridge.getPlayerInfo()
    if not Bridge.hasAccess(playerInfo.job) then return end

    local entity = GetEntityFromStateBagName(bagName)
    local time = GetCloudTimeAsInt()

    while not DoesEntityExist(entity) and GetCloudTimeAsInt()-time < 5 do Wait(100) end
    if not entity then return end

    if not value then
        local blip = GetBlipFromEntity(entity)
        return DoesBlipExist(blip) and RemoveBlip(blip)
    end

    local blip = AddBlipForEntity(entity)
    SetBlipSprite(blip, value.sprite)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    SetBlipColour(blip, value.color)
    AddTextComponentString(value.label)
    EndTextCommandSetBlipName(blip)
    SetBlipCategory(blip, 7)
    ShowHeadingIndicatorOnBlip(blip, true)

    if value.player == cache.serverId and cache.vehicle == entity then
        SetBlipAlpha(blip, 0)
    end
end)

return blips
