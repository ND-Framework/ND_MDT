local callId = 0
local emeregencyCalls = {}
local activeUnits = {}

-- retrive characters from the database based on client searches.
lib.callback.register("ND_MDT:nameSearch", function(source, first, last)
    local player = source
    local players = NDCore.Functions.GetPlayers()
    local profiles = {}
    if not config.policeAccess[players[player].job] then return false end

    if first and first ~= "" then
        local result = MySQL.query.await("SELECT * FROM characters WHERE first_name RLIKE(?)", {first})
        if result then  
            for i=1, #result do
                local item = result[i]
                local playerId = false
                for id, info in pairs(players) do
                    if players[id].id == item.character_id then
                        playerId = id
                        break
                    end
                end
                local data = json.decode(item.data)
                profiles[item.character_id] = {first_name = item.first_name, last_name = item.last_name, dob = item.dob, gender = item.gender, phone = item.phone_number, id = playerId, img = data.img, ethnicity = data.ethnicity}
            end
        end
    end
    if last and last ~= "" then
        local result = MySQL.query.await("SELECT * FROM characters WHERE last_name RLIKE(?)", {last})
        if result then
            for i=1, #result do
                local item = result[i]
                local playerId = false
                for id, info in pairs(players) do
                    if players[id].id == item.character_id then
                        playerId = id
                        break
                    end
                end
                local data = json.decode(item.data)
                profiles[item.character_id] = {first_name = item.first_name, last_name = item.last_name, dob = item.dob, gender = item.gender, phone = item.phone_number, id = playerId, img = data.img, ethnicity = data.ethnicity}
            end
        end
    end
    return profiles
end)

lib.callback.register("ND_MDT:nameSearchByCharacter", function(source, characterSearched)
    local player = NDCore.Functions.GetPlayer(source)
    local profiles = {}
    if not config.policeAccess[player.job] then return false end

    local result = MySQL.query.await("SELECT * FROM characters WHERE character_id = ?", {characterSearched})
    if result and result[1] then  
        local item = result[1]
        profiles[item.character_id] = {first_name = item.first_name, last_name = item.last_name, dob = item.dob, gender = item.gender, phone = item.phone_number, id = source, img = json.decode(item.data).img}
    end
    return profiles
end)

-- get all active units on serer and send it to client.
lib.callback.register("ND_MDT:getUnitStatus", function(source)
    local player = NDCore.Functions.GetPlayer(source)
    if not config.policeAccess[player.job] and not config.fireAccess[player.job] then return end
    return activeUnits
end)

-- sets unit status in active units table and sends it to all clients.
RegisterNetEvent("ND_MDT:setUnitStatus", function(unitNumber, unitStatus)
    local src = source
    local player = NDCore.Functions.GetPlayer(src)
    if not config.policeAccess[player.job] and not config.fireAccess[player.job] then return end
    if unitStatus == "10-7" then
        activeUnits[src] = nil
    else
        activeUnits[src] = {unit = unitNumber .. " " .. player.firstName .. " " .. player.lastName .. " [" .. player.job .. "]", status = unitStatus}
    end
    TriggerClientEvent("ND_MDT:updateUnitStatus", -1, activeUnits)
end)

-- remove unit froma activeunits if they leave the server forgeting to go 10-7.
AddEventHandler("playerDropped", function()
    local player = source
    if not activeUnits[player] then return end
    activeUnits[player] = nil
    TriggerClientEvent("ND_MDT:updateUnitStatus", -1, activeUnits)
end)

-- This will just send all the current calls to the client.
lib.callback.register("ND_MDT:getUnitStatus", function(source)
    local src = source
    return emeregencyCalls
end)

-- Create 911 call in emeregencyCalls.
RegisterNetEvent("ND_MDT:Create911Call", function(callInfo)
    callId = callId + 1
    emeregencyCalls[callId] = callInfo
    TriggerClientEvent("ND_MDT:update911Calls", -1, emeregencyCalls)
end)

function isUnitResponding(call, unitIdentifier)
    for unit, name in pairs(emeregencyCalls[call].attachedUnits) do
        if name == unitIdentifier then
            return true, unit
        end
    end
    return false
end

-- This will check if the client is already attached to the call if not then it will attach them and send it to the client.
RegisterNetEvent("ND_MDT:unitRespondToCall", function(call, unitNumber)
    local src = source
    local player = NDCore.Functions.GetPlayer(src)
    local unitIdentifier = unitNumber .. " " .. player.firstName .. " " .. player.lastName
    local responding, unit = isUnitResponding(call, unitIdentifier)
    if responding then
        emeregencyCalls[call].attachedUnits[unit] = nil
    else
        table.insert(emeregencyCalls[call].attachedUnits, unitIdentifier)
    end
    TriggerClientEvent("ND_MDT:update911Calls", -1, emeregencyCalls)
end)

function getVehicleCharacter(owner)
    local result = MySQL.query.await("SELECT * FROM characters WHERE character_id LIMIT 1", {owner})
    if result then
        for i=1, #result do
            local item = result[i]
            return {firstName = item.first_name, lastName = item.last_name, characterId = item.character_id}
        end
    end
end

-- retrive vehicles from the database based on characterId.
lib.callback.register("ND_MDT:viewVehicles", function(source, searchBy, data)
    local src = source
    local player = NDCore.Functions.GetPlayer(src)
    if not config.policeAccess[player.job] then return false end
    local vehicles = {}
    if searchBy == "plate" then
        local result = MySQL.query.await("SELECT * FROM characters_vehicles WHERE plate = ?", {data})
        if result then
            for i=1, #result do
                local item = result[i]
                local character = getVehicleCharacter(item.vehicle_owner)
                vehicles[item.v_id] = {id = item.v_id, color = item.color, make = item.make, model = item.model, plate = item.plate, class = item.class, stolen = item.stolen == 1, character = character}
            end
        end
    elseif searchBy == "owner" then
        local result = MySQL.query.await("SELECT * FROM characters_vehicles WHERE vehicle_owner = ?", {data})
        if result then
            local character = getVehicleCharacter(data)
            for i=1, #result do
                local item = result[i]
                vehicles[item.v_id] = {id = item.v_id, color = item.color, make = item.make, model = item.model, plate = item.plate, class = item.class, stolen = item.stolen == 1, character = character}
            end
        end
    end
    return vehicles
end)

function getProperties(id)
    local addresses = {}
    local result = MySQL.query.await("SELECT address FROM nd_properties WHERE owner = ?", {id})
    if not result or not result[1] then return addresses end
    for _, adrs in pairs(result) do
        addresses[#addresses+1] = adrs.address
    end
    return addresses
end

function getRecords(id)
    local result = MySQL.query.await("SELECT records FROM nd_mdt_records WHERE `character` = ? LIMIT 1", {id})
    if not result or not result[1] then
        return {}
    end
    return json.decode(result[1].records), true
end

lib.callback.register("ND_MDT:viewRecords", function(source, characterToSearch)
    local src = source
    local player = NDCore.Functions.GetPlayer(src)
    if not config.policeAccess[player.job] then return false end
    local records = {
        properties = getProperties(characterToSearch),
        records = getRecords(characterToSearch),
        licenses = player.data.licences or {}
    }
    return records
end)

RegisterNetEvent("ND_MDT:sendLiveChat", function(info)
    local src = source
    local player = NDCore.Functions.GetPlayer(src)
    if not config.policeAccess[player.job] then return false end
    info.id = src
    info.dept = player.job
    TriggerClientEvent("ND_MDT:receiveLiveChat", -1, info)
end)

function getChargesJson()
    local chargesJson = LoadResourceFile(GetCurrentResourceName(), "config/penal.json")
    if not chargesJson then return end
    local chargesList = json.decode(chargesJson)[1]
    return chargesList
end

RegisterNetEvent("ND_MDT:saveRecords", function(data)
    local src = source
    local player = NDCore.Functions.GetPlayer(src)
    if not config.policeAccess[player.job] and not config.fireAccess[player.job] then return end

    for identifier, newStatus in pairs(data.changedLicences) do
        print(data.characterId, identifier, newStatus)
        NDCore.Functions.EditPlayerLicense(data.characterId, identifier, {
            status = newStatus
        })
    end

    local records, update = getRecords(data.characterId)
    records.notes = data.notes

    local characterCharges = records.charges or {}
    local chargesList = getChargesJson()
    for _, chargeInfo in pairs(data.newCharges) do
        local charge = chargesList[chargeInfo.chargeType][chargeInfo.chargeNum+1]
        local fine = chargeInfo.fine

        if fine then
            fine = tonumber(fine:sub(2))
            if fine > charge.fine then
                fine = charge.fine
            end

            -- use ND_Banking and charge person here.
        end

        characterCharges[#characterCharges+1] = {
            crime = charge.crime,
            fine = charge.fine,
            sentence = charge.sentence,
            type = chargeInfo.chargeType,
            timestamp = os.time(),
            id = math.random(10000, 99999)
        }

        exports["ND_Banking"]:createInvoice(fine, 7, false, {
            name = "Government",
            account = "0"
        },
        {
            character = data.characterId,
        })
    end
    records.charges = characterCharges

    if update then
        MySQL.query.await("UPDATE nd_mdt_records SET records = ? WHERE `character` = ?", {json.encode(records), data.characterId})
        return
    end
    MySQL.query("INSERT INTO nd_mdt_records (`character`, records) VALUES (?, ?)", {data.characterId, json.encode(records)})
end)

-- store weapons in database when bought legally.
function registerWeapon(characterId, weaponName, serial, citizenName)
    MySQL.insert("INSERT INTO `nd_mdt_weapons` (`character`, `weapon`, `serial`, `owner_name`) VALUES (?, ?, ?, ?)", {characterId, weaponName, serial, citizenName})
end

-- check if ox inventory is started.
exports["ND_Core"]:isResourceStarted("ox_inventory", function(started)
    if not started then return end
    exports.ox_inventory:registerHook("createItem", function(payload)
        local metadata = payload.metadata
        if payload.item.weapon then
            local character = NDCore.Functions.GetPlayer(payload.inventoryId)
            registerWeapon(character.id, payload.item.label, metadata.serial, metadata.registered)
        end
        return metadata
    end)
end)

-- retrive weapons based on serial number.
lib.callback.register("ND_MDT:weaponSerialSearch", function(source, searchBy, search)
    local player = source
    local players = NDCore.Functions.GetPlayers()
    local weapons = {}
    if not config.policeAccess[players[player].job] or not search then return false end
    
    local query = "SELECT * FROM nd_mdt_weapons WHERE serial RLIKE(?)"
    if searchBy == "owner" then
        query = "SELECT * FROM nd_mdt_weapons WHERE `character` = ?"
    end

    local result = MySQL.query.await(query, {search})
    if result then
        for i=1, #result do
            local item = result[i]
            weapons[#weapons+1] = {characterId = item.character, weapon = item.weapon, serial = item.serial, ownerName = item.owner_name, stolen = item.stolen}
        end
    end

    return weapons
end)

RegisterNetEvent("ND_MDT:weaponStolenStatus", function(serial, stolen)
    local src = source
    local player = NDCore.Functions.GetPlayer(src)
    if not config.policeAccess[player.job] and not config.fireAccess[player.job] then return end
    MySQL.query("UPDATE nd_mdt_weapons SET stolen = ? WHERE serial = ?", {stolen and 1 or 0, serial})
end)

local stolenPlatesCallbacks = {}
local stolenPlatesList = {}

RegisterNetEvent("ND_MDT:vehicleStolenStatus", function(id, stolen, plate)
    local src = source
    local player = NDCore.Functions.GetPlayer(src)
    if not config.policeAccess[player.job] and not config.fireAccess[player.job] then return end
    MySQL.query("UPDATE characters_vehicles SET stolen = ? WHERE v_id = ?", {stolen and 1 or 0, id})
    if not plate then return end
    stolenPlatesList[plate] = stolen and plate or nil
    for i = 1, #stolenPlatesCallbacks do
        stolenPlatesCallbacks[i](plate)
    end
end)

AddEventHandler("onResourceStart", function(resourceName)
    local result = MySQL.query.await("SELECT `plate` FROM `characters_vehicles` WHERE `stolen` = 1")
    if not result then return end
    for _, plate in pairs(result) do
        stolenPlatesList[plate.plate] = plate.plate
    end
end)
exports("stolenPlate", function(param)
    local dataType = type(param)
    if dataType == "string" then
        return stolenPlatesList[plate]
    elseif dataType == "function" then
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


-- retrive all bolos.
lib.callback.register("ND_MDT:getBolos", function(src)
    local player = NDCore.Functions.GetPlayer(src)
    if not config.policeAccess[player.job] and not config.fireAccess[player.job] then return end

    local bolos = {}
    local result = MySQL.query.await("SELECT * FROM nd_mdt_bolos")
    if not result then return bolos end

    for i=1, #result do
        local item = result[i]
        bolos[#bolos+1] = {
            id = item.id,
            type = item.type,
            data = item.data,
            timestamp = item.timestamp
        }
    end

    table.sort(bolos, function(a, b)
        return a.timestamp < b.timestamp
    end)

    return bolos
end)

-- register a bolo in db
RegisterNetEvent("ND_MDT:createBolo", function(data)
    local src = source
    local player = NDCore.Functions.GetPlayer(src)
    if not config.policeAccess[player.job] and not config.fireAccess[player.job] then return end
    if data.type == "person" and data.character then
        local character = NDCore.Functions.GetPlayerByCharacterId(data.character)
        if character and character.data and character.data.img then
            data.img = character.data.img
        end
    end
    local jsonData = json.encode(data)
    local id = MySQL.insert.await("INSERT INTO `nd_mdt_bolos` (`type`, `data`) VALUES (?, ?)", {data.type, jsonData})
    TriggerClientEvent("ND_MDT:newBolo", -1, {
        id = id,
        type = data.type,
        data = jsonData,
        timestamp = os.time()
    })
end)

-- delete bolo from db
RegisterNetEvent("ND_MDT:removeBolo", function(id)
    local src = source
    local player = NDCore.Functions.GetPlayer(src)
    if not config.policeAccess[player.job] and not config.fireAccess[player.job] then return end

    local boloType = MySQL.query.await("SELECT `type` FROM `nd_mdt_bolos` WHERE `id` = ?", {id})
    if not boloType[1] then return end
    boloType = boloType[1].type

    MySQL.query("DELETE FROM `nd_mdt_bolos` WHERE id = ?", {id})
    TriggerClientEvent("ND_MDT:removeBolo", -1, id, boloType)
end)

end)