local callId = 0
local emeregencyCalls = {}
local activeUnits = {}
local resourceName = cache.resource
local chargesList = json.decode(LoadResourceFile(resourceName, "/config/charges.json"))[1]
local lastPanicTime = 0
require("modules.plates.server")

-- Retrieve characters from the database based on client searches.
lib.callback.register("ND_MDT:nameSearch", function(source, first, last)
    local src = source
    return Bridge.nameSearch(src, first, last)
end)

lib.callback.register("ND_MDT:nameSearchByCharacter", function(source, characterSearched)
    return Bridge.characterSearch(source, characterSearched)
end)

-- Get all active units on the server and send them to the client.
lib.callback.register("ND_MDT:getUnitStatus", function(source)
    local player = Bridge.getPlayerInfo(source)
    if not config.policeAccess[player.job] and not config.fireAccess[player.job] then return end
    return activeUnits
end)

-- Sets unit status in active units table and sends it to all clients.
RegisterNetEvent("ND_MDT:setUnitStatus", function(unitStatus, statusCode)
    local src = source
    local player = Bridge.getPlayerInfo(src)
    if not config.policeAccess[player.job] and not config.fireAccess[player.job] then return end

    if statusCode == "10-7" then
        activeUnits[src] = nil
    else
        activeUnits[src] = {
            status = unitStatus,
            department = player.jobLabel,
            unit = ("%s %s [%s]"):format(player.firstName, player.lastName, player.callsign)
        }
    end

    TriggerClientEvent("ND_MDT:updateUnitStatus", -1, activeUnits)

    if statusCode ~= "10-99" then return end

    local currTime = os.time()

    if currTime - lastPanicTime < config.panicCooldown then
        local remainingTime = config.panicCooldown - (currTime - lastPanicTime)
        TriggerClientEvent("ND_MDT:panicOnCooldown", src, remainingTime)
        return
    end

    local location, postal = lib.callback.await("ND_MDT:getStreet", src)
    if not location then return end

    location = location:gsub("St", "street")
    location = location:gsub("Ave", "avenue")
    TriggerClientEvent("ND_MDT:panic", -1, {
        type = "panic",
        unit = ("%s %s %s"):format(player.callsign, player.firstName, player.lastName),
        location = location,
        postal = postal
    })
    lastPanicTime = currTime
end)

-- Remove unit from activeUnits if they leave the server without going 10-7.
AddEventHandler("playerDropped", function()
    local src = source
    if not activeUnits[src] then return end
    activeUnits[src] = nil
    TriggerClientEvent("ND_MDT:updateUnitStatus", -1, activeUnits)
end)

-- Remove unit from activeUnits if they change character without going 10-7.
AddEventHandler("ND:characterUnloaded", function(src)
    if not activeUnits[src] then return end
    activeUnits[src] = nil
    TriggerClientEvent("ND_MDT:updateUnitStatus", -1, activeUnits)
end)

-- This will just send all the current calls to the client.
lib.callback.register("ND_MDT:getUnitStatus", function(source)
    return emeregencyCalls
end)

local function createDispatch(info)
    callId = callId + 1
    emeregencyCalls[callId] = {
        caller = info.caller,
        location = info.location,
        callDescription = info.callDescription,
        attachedUnits = {},
        timeCreated = os.time(),
        coords = info.coords
    }
    TriggerClientEvent("ND_MDT:update911Calls", -1, emeregencyCalls, nil, {
        title = ("Dispatch: new call (%s)"):format(callId),
        description = info.callDescription
    })
end

exports("createDispatch", createDispatch)

-- Create 911 call in emeregencyCalls.
RegisterNetEvent("ND_MDT:Create911Call", function(callInfo)
    local src = source

    if callInfo.location then
        local ped = GetPlayerPed(src)
        callInfo.coords = GetEntityCoords(ped)
    end

    createDispatch(callInfo)
end)

local function removePlayerFromAllCalls(calls, player)
    for i=1, #calls do
        local emerCall = calls[i]
        if emerCall.attachedUnits[player] then
            emerCall.attachedUnits[player] = nil
        end
    end
end

-- This will check if the client is already attached to the call if not then it will attach them and send it to the client.
RegisterNetEvent("ND_MDT:unitRespondToCall", function(call)
    local src = source
    local player = Bridge.getPlayerInfo(src)
    if not config.policeAccess[player.job] and not config.fireAccess[player.job] then return end

    local emeregencyCall = emeregencyCalls[call]
    if not emeregencyCall then return end

    local blipInfo = nil
    local unitIdentifier = ("[%s] %s %s"):format(player.callsign, player.firstName, player.lastName)

    if emeregencyCall.attachedUnits[src] then
        emeregencyCall.attachedUnits[src] = nil
        blipInfo = {
            type = "remove",
            player = src,
            call = call
        }
    else
        removePlayerFromAllCalls(emeregencyCalls, src)
        emeregencyCall.attachedUnits[src] = unitIdentifier
        blipInfo = {
            type = "add",
            player = src,
            call = call,
            coords = emeregencyCall.coords
        }
    end

    TriggerClientEvent("ND_MDT:update911Calls", -1, emeregencyCalls, blipInfo)
end)


lib.callback.register("ND_MDT:viewEmployees", function(source, search)
    return Bridge.viewEmployees(source, search)
end)


-- retrive vehicles from the database based on characterId.
lib.callback.register("ND_MDT:viewVehicles", function(source, searchBy, data)
    return Bridge.viewVehicles(source, searchBy, data)
end)

lib.callback.register("ND_MDT:viewRecords", function(source, characterToSearch)
    local player = Bridge.getPlayerInfo(source)
    if not config.policeAccess[player.job] then return false end
    return {
        properties = Bridge.getProperties(characterToSearch),
        records = Bridge.getRecords(characterToSearch),
        licenses = Bridge.getLicenses(characterToSearch)
    }
end)

RegisterNetEvent("ND_MDT:sendLiveChat", function(info)
    local src = source
    local player = Bridge.getPlayerInfo(src)
    if not config.policeAccess[player.job] and not config.fireAccess[player.job] then return false end
    info.id = src
    info.dept = player.jobLabel
    TriggerClientEvent("ND_MDT:receiveLiveChat", -1, info)
end)

RegisterNetEvent("ND_MDT:saveRecords", function(data)
    local src = source
    local player = Bridge.getPlayerInfo(src)
    if not config.policeAccess[player.job] and not config.fireAccess[player.job] then return end

    for identifier, newStatus in pairs(data.changedLicences) do
        Bridge.editPlayerLicense(data.characterId, identifier, newStatus)
    end

    local records, update = Bridge.getRecords(data.characterId)
    records.notes = data.notes

    local characterCharges = records.charges or {}
    for _, chargeInfo in pairs(data.newCharges) do
        local charge = chargesList[chargeInfo.chargeType][chargeInfo.chargeNum+1]
        local fine = chargeInfo.fine

        if fine then
            fine = tonumber(fine:sub(2))
            if fine > charge.fine then
                fine = charge.fine
            end
            Bridge.createInvoice(data.characterId, fine)
        end

        characterCharges[#characterCharges+1] = {
            crime = charge.crime,
            fine = charge.fine,
            sentence = charge.sentence,
            type = chargeInfo.chargeType,
            timestamp = os.time(),
            id = math.random(10000, 99999)
        }
    end
    records.charges = characterCharges

    if update then
        MySQL.query("UPDATE nd_mdt_records SET records = ? WHERE `character` = ?", {json.encode(records), data.characterId})
        return
    end
    MySQL.insert("INSERT INTO nd_mdt_records (`character`, records) VALUES (?, ?)", {data.characterId, json.encode(records)})
end)

exports.ox_inventory:registerHook("createItem", function(payload)
    local metadata = payload.metadata
    if payload.item.weapon and metadata.registered then
        local player = Bridge.getPlayerInfo(payload.inventoryId)
        MySQL.insert("INSERT INTO `nd_mdt_weapons` (`character`, `weapon`, `serial`, `owner_name`) VALUES (?, ?, ?, ?)", {player.characterId, payload.item.label, metadata.serial, metadata.registered})
    end
    return metadata
end)

---Save a weapon to the MDT weapons DB
---@param playerID number Player Server ID
---@param weaponLabel string Name of the weapon eg: Combat Pistol
---@param serialNumber string Serial Number of the weapon
local function registerWeapon(playerID, weaponLabel, serialNumber)
    if playerID == nil or weaponLabel == nil or serialNumber == nil then
        print('[^4WARNING^7] Missing parameters for ^8registerWeapon()^8', string.format("ID: %s, Label: %s, Serial: %s", tostring(playerID) or "nil", weaponLabel or "nil", serialNumber or "nil"))
        return
    end
    local player = Bridge.getPlayerInfo(playerID)
    MySQL.insert(
        "INSERT INTO `nd_mdt_weapons` (`character`, `weapon`, `serial`, `owner_name`) VALUES (?, ?, ?, ?)",
        {
            player.characterId,
            weaponLabel,
            serialNumber,
            player.firstName .. " " .. player.lastName
        }
    )
end

exports("registerWeapon", registerWeapon)

-- retrive weapons based on serial number.
lib.callback.register("ND_MDT:weaponSerialSearch", function(source, searchBy, search)
    local player = Bridge.getPlayerInfo(source)
    if not config.policeAccess[player.job] or not search then return false end
    
    local query = "SELECT * FROM nd_mdt_weapons WHERE serial RLIKE(?)"
    if searchBy == "owner" then
        query = "SELECT * FROM nd_mdt_weapons WHERE `character` = ?"
    end
    
    local weapons = {}
    local result = MySQL.query.await(query, {search})
    for i=1, #result do
        local item = result[i]
        weapons[#weapons+1] = {characterId = item.character, weapon = item.weapon, serial = item.serial, ownerName = item.owner_name, stolen = item.stolen}
    end

    return weapons
end)

RegisterNetEvent("ND_MDT:weaponStolenStatus", function(serial, stolen)
    local src = source
    local player = Bridge.getPlayerInfo(src)
    if not config.policeAccess[player.job] and not config.fireAccess[player.job] then return end
    MySQL.query("UPDATE nd_mdt_weapons SET stolen = ? WHERE serial = ?", {stolen and 1 or 0, serial})
end)


-- retrive all bolos.
lib.callback.register("ND_MDT:getBolos", function(src)
    local player = Bridge.getPlayerInfo(src)
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
    local player = Bridge.getPlayerInfo(src)
    if not config.policeAccess[player.job] and not config.fireAccess[player.job] then return end
    
    if data.type == "person" and data.character then
        data.img = Bridge.getPlayerImage(data.character)
    end

    local jsonData = json.encode(data)
    local id = MySQL.insert.await("INSERT INTO `nd_mdt_bolos` (`type`, `data`) VALUES (?, ?)", {data.type, jsonData})

    local info = {
        id = id,
        type = data.type,
        data = jsonData,
        timestamp = os.time()
    }

    TriggerEvent("ND_MDT:newBolo", info)
    TriggerClientEvent("ND_MDT:newBolo", -1, info)
end)

-- delete bolo from db
RegisterNetEvent("ND_MDT:removeBolo", function(id)
    local src = source
    local player = Bridge.getPlayerInfo(src)
    if not config.policeAccess[player.job] and not config.fireAccess[player.job] then return end
    if not id then return end

    local boloType = MySQL.query.await("SELECT `type` FROM `nd_mdt_bolos` WHERE `id` = ?", {id})
    if not boloType[1] then return end
    boloType = boloType[1].type

    MySQL.query("DELETE FROM `nd_mdt_bolos` WHERE id = ?", {id})
    TriggerClientEvent("ND_MDT:removeBolo", -1, id, boloType)
end)

-- retrive all reports.
lib.callback.register("ND_MDT:getReports", function(src)
    local player = Bridge.getPlayerInfo(src)
    if not config.policeAccess[player.job] and not config.fireAccess[player.job] then return end

    local reports = {}
    local result = MySQL.query.await("SELECT * FROM nd_mdt_reports")
    if not result then return reports end

    for i=1, #result do
        local item = result[i]
        reports[#reports+1] = {
            id = item.id,
            type = item.type,
            data = item.data,
            timestamp = item.timestamp
        }
    end

    table.sort(reports, function(a, b)
        return a.timestamp < b.timestamp
    end)

    return reports
end)

-- register a report in db
RegisterNetEvent("ND_MDT:createReport", function(data)
    local src = source
    local player = Bridge.getPlayerInfo(src)
    if not config.policeAccess[player.job] and not config.fireAccess[player.job] then return end

    data.officer = ("%s %s %s [%s]"):format(player.callsign, player.firstName, player.lastName, player.job)
    local jsonData = json.encode(data)
    local id = MySQL.insert.await("INSERT INTO `nd_mdt_reports` (`type`, `data`) VALUES (?, ?)", {data.type, jsonData})
    TriggerClientEvent("ND_MDT:newReport", -1, {
        id = id,
        type = data.type,
        data = jsonData,
        timestamp = os.time()
    })
end)

-- delete report from db
RegisterNetEvent("ND_MDT:removeReport", function(id)
    local src = source
    local player = Bridge.getPlayerInfo(src)
    if not config.policeAccess[player.job] and not config.fireAccess[player.job] then return end

    local reportType = MySQL.query.await("SELECT `type` FROM `nd_mdt_reports` WHERE `id` = ?", {id})
    if not reportType[1] then return end
    reportType = reportType[1].type

    MySQL.query("DELETE FROM `nd_mdt_reports` WHERE id = ?", {id})
    TriggerClientEvent("ND_MDT:removeReport", -1, id, reportType)
end)

lib.callback.register("ND_MDT:employeeUpdateRank", function(src, info)
    local player = Bridge.getPlayerInfo(src)
    if not config.policeAccess[player.job] and not config.fireAccess[player.job] then return end
    return Bridge.updateEmployeeRank(src, info)
end)

lib.callback.register("ND_MDT:employeeUpdateCallsign", function(src, character, callsign)
    local player = Bridge.getPlayerInfo(src)
    if not config.policeAccess[player.job] and not config.fireAccess[player.job] then return end
    return Bridge.employeeUpdateCallsign(src, character, callsign)
end)

lib.callback.register("ND_MDT:employeeFire", function(src, character)
    local player = Bridge.getPlayerInfo(src)
    if not config.policeAccess[player.job] and not config.fireAccess[player.job] then return end
    return Bridge.removeEmployeeJob(src, character)
end)

lib.callback.register("ND_MDT:inviteEmployee", function(src, target)
    target = tonumber(target)
    if not target then
        return false, "Player not found!"
    end

    local player = Bridge.getPlayerInfo(src)
    if not config.policeAccess[player.job] and not config.fireAccess[player.job] then return end

    local accepted = lib.callback.await("ND_MDT:employeeRequestInvite", target, GetPlayerName(src), player.jobLabel)
    if accepted and not Bridge.invitePlayerToJob(src, target) then
        return false, "Couldn't set player's job, try again later!"
    end

    local playerName = GetPlayerName(target)
    return accepted, accepted and ("%s accepted invite."):format(playerName) or ("%s didn't accept invite."):format(playerName)
end)
