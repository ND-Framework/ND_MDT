local stolenPlatesCallbacks = {}
local stolenPlatesList = {}

RegisterNetEvent("ND_MDT:vehicleStolenStatus", function(id, stolen, plate)
    local src = source
    local player = Bridge.getPlayerInfo(src)
    if not config.policeAccess[player.job] and not config.fireAccess[player.job] then return end

    Bridge.vehicleStolen(id, stolen, plate)
    if not plate then return end

    stolenPlatesList[plate] = stolen and plate or nil

    for i=1, #stolenPlatesCallbacks do
        stolenPlatesCallbacks[i](plate)
    end
end)

AddEventHandler("onResourceStart", function(name)
    if name ~= cache.resource then return end

    local plates = Bridge.getStolenVehicles()

    for i=1, #plates do
        local plate = plates[i]
        stolenPlatesList[plate] = plate
    end
end)

exports("stolenPlate", function(param)
    local paramType = type(param)
    if paramType == "string" then
        return stolenPlatesList[plate]
    elseif paramType == "function" then
        stolenPlatesCallbacks[#stolenPlatesCallbacks+1] = param
        return stolenPlatesList
    end
end)

RegisterNetEvent("wk:onPlateScanned", function(cam, plate, index)
    local src = source
    if stolenPlatesList[plate] then
        exports["wk_wars2x"]:TogglePlateLock(src, cam, true, true)
    end
end)
