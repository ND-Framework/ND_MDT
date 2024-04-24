local stolenPlatesList = {}

RegisterNetEvent("ND_MDT:vehicleStolenStatus", function(id, stolen, plate)
    local src = source
    local player = Bridge.getPlayerInfo(src)
    if not config.policeAccess[player.job] and not config.fireAccess[player.job] then return end

    Bridge.vehicleStolen(id, stolen, plate)
    if not plate then return end

    plate = plate:upper()
    stolenPlatesList[plate] = stolen and plate or nil
end)

AddEventHandler("ND_MDT:newBolo", function(info)
    if info.type ~= "vehicle" then return end

    local data = json.decode(info.data) or {}
    local plate = data.plate
    if not plate then return end

    plate = plate:upper()
    stolenPlatesList[plate] = plate
end)

AddEventHandler("onResourceStart", function(name)
    if name ~= cache.resource then return end

    local plates = Bridge.getStolenVehicles()

    for i=1, #plates do
        local plate = plates[i]:upper()
        stolenPlatesList[plate] = plate
    end
end)

local function plateCheck(plate)
    plate = plate:upper()

    if stolenPlatesList[plate] then return true end

    for k, v in pairs(stolenPlatesList) do
        if k:gsub(" ", "") == plate:gsub(" ", "") then
            return true
        end
    end
end

RegisterNetEvent("wk:onPlateScanned", function(cam, plate, index)
    local src = source
    TriggerClientEvent("esx:showNotification", src, "Scanned Plate: "..plate, 'info')
    if plateCheck(plate) then
        exports["wk_wars2x"]:TogglePlateLock(src, cam, true, true)
    end
end)
