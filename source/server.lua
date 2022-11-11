NDCore = exports["ND_Core"]:GetCoreObject()

local callId = 0
local emeregencyCalls = {}
local activeUnits = {}

-- retrive characters from the database based on client searches.
RegisterNetEvent("ND_MDT:nameSearch")
AddEventHandler("ND_MDT:nameSearch", function(first, last)
    local player = source
    local players = NDCore.Functions.GetPlayers()
    local profiles = {}
    if config.policeAccess[players[player].job] then
        if first and first ~= "" then
            exports.oxmysql:query("SELECT * FROM characters WHERE first_name RLIKE(?);", {first}, function(result)
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
                        profiles[item.character_id] = {first_name = item.first_name, last_name = item.last_name, dob = item.dob, gender = item.gender, id = playerId}
                    end
                end
            end)
        end
        if last and last ~= "" then
            exports.oxmysql:query("SELECT * FROM characters WHERE last_name RLIKE(?);", {last}, function(result)
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
                        profiles[item.character_id] = {first_name = item.first_name, last_name = item.last_name, dob = item.dob, gender = item.gender, id = playerId}
                    end
                end
            end)
        end
        Citizen.Wait(200)
        TriggerClientEvent("ND_MDT:returnNameSearch", player, profiles)
    else
        TriggerClientEvent("ND_MDT:returnNameSearch", player, false)
    end
end)

-- get all active units on serer and send it to client.
RegisterNetEvent("ND_MDT:getUnitStatus")
AddEventHandler("ND_MDT:getUnitStatus", function()
    local player = source
    local players = NDCore.Functions.GetPlayers()
    local playerDepartment = players[player].job
    if not config.policeAccess[playerDepartment] and not config.fireAccess[playerDepartment] then return end
    TriggerClientEvent("ND_MDT:updateUnitStatus", player, activeUnits)
end)

-- sets unit status in active units table and sends it to client.
RegisterNetEvent("ND_MDT:setUnitStatus")
AddEventHandler("ND_MDT:setUnitStatus", function(unitNumber, unitStatus)
    local player = source
    local players = NDCore.Functions.GetPlayers()
    local playerDepartment = players[player].job
    if not config.policeAccess[playerDepartment] and not config.fireAccess[playerDepartment] then return end
    if unitStatus == "10-7" then
        activeUnits[player] = nil
    else
        activeUnits[player] = {unit = unitNumber .. " " .. players[player].firstName .. " " .. players[player].lastName .. " [" .. playerDepartment .. "]", status = unitStatus}
    end
    TriggerClientEvent("ND_MDT:updateUnitStatus", -1, activeUnits)
end)

-- remove unit froma activeunits if they leave the server forgeting to go 10-7.
AddEventHandler("playerDropped", function()
    local player = source
    activeUnits[player] = nil
    TriggerClientEvent("ND_MDT:updateUnitStatus", -1, activeUnits)
end)

-- Create 911 call in emeregencyCalls.
RegisterNetEvent("ND_MDT:Create911Call")
AddEventHandler("ND_MDT:Create911Call", function(callInfo)
    callId = callId + 1
    emeregencyCalls[callId] = callInfo
    TriggerClientEvent("ND_MDT:update911Calls", -1, emeregencyCalls)
end)

-- This will just send all the current calls to the client.
RegisterNetEvent("ND_MDT:get911Calls")
AddEventHandler("ND_MDT:get911Calls", function()
    local player = source
    TriggerClientEvent("ND_MDT:update911Calls", source, emeregencyCalls)
end)

-- This will check if the client is already attached to the call if not then it will attach them and send it to the client.
RegisterNetEvent("ND_MDT:unitRespondToCall")
AddEventHandler("ND_MDT:unitRespondToCall", function(id, unitNumber)
    local player = source
    local players = NDCore.Functions.GetPlayers()
    local call = id
    local unitIdentifier = unitNumber .. " " .. players[player].firstName .. " " .. players[player].lastName
    for unit, name in pairs(emeregencyCalls[call].attachedUnits) do
        if name == unitIdentifier then
            emeregencyCalls[call].attachedUnits[unit] = nil
            TriggerClientEvent("ND_MDT:update911Calls", -1, emeregencyCalls)
            return
        end
    end
    table.insert(emeregencyCalls[call].attachedUnits, unitIdentifier)
    TriggerClientEvent("ND_MDT:update911Calls", -1, emeregencyCalls)
end)

-- retrive vehicles from the database based on characterId.
RegisterNetEvent("ND_MDT:viewVehicles")
AddEventHandler("ND_MDT:viewVehicles", function(id)
    local player = source
    local players = NDCore.Functions.GetPlayers()
    local vehicles = {}
    if config.policeAccess[players[player].job] then
        exports.oxmysql:query("SELECT * FROM characters_vehicles WHERE character = ?;", {id}, function(result)
            if result then  
                for i=1, #result do
                    local item = result[i]
                    vehicles[item.v_id] = {color = item.color, make = item.make, model = item.model, plate = item.plate, class = item.class}
                end
            end
        end)
        Citizen.Wait(200)
        TriggerClientEvent("ND_MDT:returnIdVehicles", player, vehicles)
    else
        TriggerClientEvent("ND_MDT:returnIdVehicles", player, false)
    end
end)

RegisterNetEvent("ND_MDT:sendLiveChat")
AddEventHandler("ND_MDT:sendLiveChat", function(liveChatImg, unitIdentifier, messageText)
    local player = source
    local senderInfo = {
        id = player,
        liveChatImg = liveChatImg,
        unit = unitIdentifier,
        text = messageText
    }
    TriggerClientEvent("ND_MDT:receiveLiveChat", -1, senderInfo)
end)