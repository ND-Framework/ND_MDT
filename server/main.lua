NDCore = exports["ND_Core"]:GetCoreObject()

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
                profiles[item.character_id] = {first_name = item.first_name, last_name = item.last_name, dob = item.dob, gender = item.gender, phone = item.phone_number, id = playerId}
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
                profiles[item.character_id] = {first_name = item.first_name, last_name = item.last_name, dob = item.dob, gender = item.gender, phone = item.phone_number, id = playerId}
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
        profiles[item.character_id] = {first_name = item.first_name, last_name = item.last_name, dob = item.dob, gender = item.gender, phone = item.phone_number, id = source}
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
                vehicles[item.v_id] = {color = item.color, make = item.make, model = item.model, plate = item.plate, class = item.class, character = character}
            end
        end
    elseif searchBy == "owner" then
        local result = MySQL.query.await("SELECT * FROM characters_vehicles WHERE vehicle_owner = ?", {data})
        if result then
            local character = getVehicleCharacter(data)
            for i=1, #result do
                local item = result[i]
                vehicles[item.v_id] = {color = item.color, make = item.make, model = item.model, plate = item.plate, class = item.class, character = character}
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
lib.callback.register("ND_MDT:weaponSerialSearch", function(source, serial)
    local player = source
    local players = NDCore.Functions.GetPlayers()
    local weapons = {}
    if not config.policeAccess[players[player].job] or not serial then return false end
    
    local result = MySQL.query.await("SELECT * FROM nd_mdt_weapons WHERE serial RLIKE(?)", {serial})
    if result then
        for i=1, #result do
            local item = result[i]
            weapons[#weapons+1] = {characterId = item.character, weapon = item.weapon, serial = item.serial, ownerName = item.owner_name}
        end
    end
    return weapons
end)