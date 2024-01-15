local display = false
local citizenData = {}
local changedLicences = {}
local neverOpened = true

local function openMDT(status)
    local playerInfo = Bridge.getPlayerInfo()
    if not Bridge.hasAccess(playerInfo.job) then return end

    if neverOpened then
        neverOpened = false
        -- returns all active units from the server and updates the status on the ui.
        lib.callback("ND_MDT:getUnitStatus", false, function(units)
            displayUnits(units)
        end)
        lib.callback("ND_MDT:get911Calls", false, function(emeregencyCalls)
            displayUnits(emeregencyCalls)
        end)
    end

    display = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        type = "display",
        action = "open",
        img = playerInfo.img,
        department = playerInfo.jobLabel,
        rank = Bridge.rankName(),
        name = ("%s %s"):format(playerInfo.firstName, playerInfo.lastName),
        unitNumber = playerInfo.callsign,
        boss = playerInfo.isBoss
    })

    PlaySoundFrontend(-1, "DELETE", "HUD_DEATHMATCH_SOUNDSET", 1)
end

function displayUnits(units)
    local playerInfo = Bridge.getPlayerInfo()
    if not Bridge.hasAccess(playerInfo.job) then return end
    SendNUIMessage({
        type = "updateUnitStatus",
        action = "clear"
    })
    for _, info in pairs(units) do
        SendNUIMessage({
            type = "updateUnitStatus",
            action = "add",
            unit = info.unit,
            status = info.status,
            department = info.department
        })
    end
end

function display911Calls(emeregencyCalls)
    local playerInfo = Bridge.getPlayerInfo()
    if not Bridge.hasAccess(playerInfo.job) then return end

    local unitIdentifier = ("[%s] %s %s"):format(playerInfo.callsign, playerInfo.firstName, playerInfo.lastName)
    local data = {}

    for callId, info in pairs(emeregencyCalls) do
        local isAttached = false
        local attachedUnits = info.attachedUnits

        if #attachedUnits == 0 then
            attachedUnits = "none"
        else
            for _, unit in pairs(attachedUnits) do
                if unit == unitIdentifier then
                    isAttached = true
                    break
                end
            end
            -- attachedUnits = table.concat(info.attachedUnits, ", ")
        end

        data[#data+1] = {
            callId = callId,
            caller = info.caller,
            location = info.location,
            callDescription = info.callDescription,
            attachedUnits = attachedUnits,
            isAttached = isAttached
        }
    end

    SendNUIMessage({
        type = "update911Calls",
        callData = json.encode(data)
    })
end

-- open the mdt using keymapping.
RegisterCommand("+mdt", function()
    local veh = GetVehiclePedIsIn(cache.ped)
    if not DoesEntityExist(veh) or GetVehicleClass(veh) ~= 18 then return end
    openMDT(true)
end, false)
RegisterCommand("-mdt", function()end, false)
RegisterKeyMapping("+mdt", "Open the ND MDT", "keyboard", "b")

-- close the ui.
RegisterNUICallback("close", function()
    display = false
    SetNuiFocus(false, false)
    PlaySoundFrontend(-1, "PIN_BUTTON", "ATM_SOUNDS", 1)
end)

-- VERY OLD CODE
-- saves the unit number in kvp so they don't need to set it everytime they log on.
-- RegisterNUICallback("setUnitNumber", function(data)
--     PlaySoundFrontend(-1, "PIN_BUTTON", "ATM_SOUNDS", 1)
-- end)

-- triggers a server event once unit status has been changed from the mdt.
RegisterNUICallback("unitStatus", function(data)
    PlaySoundFrontend(-1, "PIN_BUTTON", "ATM_SOUNDS", 1)
    TriggerServerEvent("ND_MDT:setUnitStatus", data.status, data.code)
end)

-- sets the unit attached or detached from a call.
RegisterNUICallback("unitRespondToCall", function(data)
    PlaySoundFrontend(-1, "PIN_BUTTON", "ATM_SOUNDS", 1)
    TriggerServerEvent("ND_MDT:unitRespondToCall", tonumber(data.id))
end)

function weaponSearch(searchBy, search)
    local weaponPage = false
    if searchBy == "owner" then weaponPage = true end

    -- returns retrived names and character information from the server and adds it on the ui.
    lib.callback("ND_MDT:weaponSerialSearch", false, function(result)
        -- print(json.encode(result,{indent=true}))
        if not result or not next(result) then
            if weaponPage then
                SendNUIMessage({
                    type = "weaponSerialSearch",
                    found = "No weapons found registered to this citizen.",
                    weaponPage = true
                })
            else
                SendNUIMessage({
                    type = "weaponSerialSearch",
                    found = "No weapons found matching this serial number."
                })
            end

            return
        end
        SendNUIMessage({
            type = "weaponSerialSearch",
            found = true,
            weaponPage = weaponPage,
            data = json.encode(result)
        })
    end, searchBy, search)
end

function nameSearched(result)
    -- print(json.encode(result, {indent = true}))
    if not result or not next(result) then
        SendNUIMessage({
            type = "nameSearch",
            found = false
        })
        return
    end
    local data = {}
    for character, info in pairs(result) do
        local citizen = Bridge.getCitizenInfo(character, info)
        citizenData[character] = citizen
        data[#data+1] = citizen
    end
    SendNUIMessage({
        type = "nameSearch",
        found = true,
        data = json.encode(data)
    })
end

RegisterNUICallback("viewEmployees", function(data)
    PlaySoundFrontend(-1, "PIN_BUTTON", "ATM_SOUNDS", 1)

    lib.callback("ND_MDT:viewEmployees", false, function(result)
        -- print(json.encode(result, {indent=true}))
        SendNUIMessage({
            type = "viewEmployees",
            data = json.encode(result or {})
        })
    end, data.search)
end)

RegisterNuiCallback("empoyeeAction", function(data, cb)
    local charid, action, data = data.character, data.action, data.data

    if action == "rank" then
        local options, job = Bridge.getRanks(data)
        if not options then
            return --openMDT(true)
        end

        local input = lib.inputDialog("Change employee rank", {
            {
                type = "select",
                label = "Rank name",
                description = "Select the rank you want to set the employee to",
                required = true,
                options = options,
            }
        })

        if not input or not input[1] then
            return --openMDT(true)
        end

        local success, errorMessage = lib.callback.await("ND_MDT:employeeUpdateRank", false, {
            charid = charid,
            newRank = input[1],
            job = job
        })
        
        if success then
            cb(success)
        else
            lib.notify({
                title = "MDT",
                description = errorMessage,
                type = "error"
            })
        end
    elseif action == "callsign" then
        local input = lib.inputDialog("Change employee callsign", {
            {
                type = "input",
                label = "Input a callsign",
                description = "Callsign pattern: 001-999",
                required = true,
                min = 3,
                max = 3
            }
        })

        if not input or not input[1] then
            return --openMDT(true)
        end
        
        local success, errorMessage = lib.callback.await("ND_MDT:employeeUpdateCallsign", false, charid, input[1])
        if success then
            cb(tostring(success))
        else
            lib.notify({
                title = "MDT",
                description = errorMessage,
                type = "error"
            })
        end
    elseif action == "fire" then
        local success, errorMessage = lib.callback.await("ND_MDT:employeeFire", false, charid)
        if success then
            cb(1)
        else
            lib.notify({
                title = "MDT",
                description = errorMessage,
                type = "error"
            })
        end
    end
    --openMDT(true)
end)

local function getNearbyPlayers()
    local list = {}
    local coords = GetEntityCoords(cache.ped)
    local players = lib.getNearbyPlayers(coords, 5, false)

    for i=1, #players do
        local ply = players[i]
        list[#list+1] = {
            value = GetPlayerServerId(ply.id),
            label = GetPlayerName(ply.id)
        }
    end

    if #list == 0 then
        list[#list+1] = {
            value = 0,
            label = "No players found nearby!",
            disabled = true
        }
    end
    
    return list
end

RegisterNUICallback("newEmployee", function(data)
    local input = lib.inputDialog("Select employee to hire.", {
        {
            type = "select",
            label = "Nearby players",
            placeholder = "Select a player",
            required = true,
            options = getNearbyPlayers()
        }
    })

    local player = input and tonumber(input[1])
    if not player then return end

    local accepted, message = lib.callback.await("ND_MDT:inviteEmployee", false, player)
    lib.notify({
        title = "MDT",
        description = message,
        type = accepted and "success" or "error"
    })
end)

lib.callback.register("ND_MDT:employeeRequestInvite", function(playerInviting, department)
    if not ClockedIn then return end
    local alert = lib.alertDialog({
        header = ("You've been invited by %s"):format(playerInviting),
        content = ("%s is inviting you to work at %s would you like to accept the invite?"):format(playerInviting, department),
        centered = true,
        cancel = true
    })
    return alert == "confirm"
end)

-- triggers a server event to retrive names based on search.
RegisterNUICallback("nameSearch", function(data)
    PlaySoundFrontend(-1, "PIN_BUTTON", "ATM_SOUNDS", 1)

    -- returns retrived names and character information from the server and adds it on the ui.
    if not data.id then
        lib.callback("ND_MDT:nameSearch", false, function(result)
            nameSearched(result)
        end, data.first, data.last)
        return
    end
    lib.callback("ND_MDT:nameSearchByCharacter", false, function(result)
        nameSearched(result)
    end, data.id)
end)

RegisterNUICallback("viewWeapons", function(data)
    PlaySoundFrontend(-1, "PIN_BUTTON", "ATM_SOUNDS", 1)
    weaponSearch(data.searchBy, data.search)
end)

RegisterNUICallback("viewVehicles", function(data)
    PlaySoundFrontend(-1, "PIN_BUTTON", "ATM_SOUNDS", 1)
    local vehPage = false
    if data.searchBy == "owner" then vehPage = true end

    -- retrived vehicles from the server and adds it on the ui.
    lib.callback("ND_MDT:viewVehicles", false, function(result)
        -- print(json.encode(result, {indent = true}))
        if not result or not next(result) then
            if vehPage then
                SendNUIMessage({
                    type = "viewVehicles",
                    found = "No vehicles found registered to this citizen.",
                    vehPage = true
                })
            else
                SendNUIMessage({
                    type = "viewVehicles",
                    found = "No vehicles found with this plate."
                })
            end
            return
        end
        SendNUIMessage({
            type = "viewVehicles",
            found = true,
            vehPage = vehPage,
            data = json.encode(result)
        })
    end, data.searchBy, data.search)
end)

RegisterNUICallback("viewRecords", function(data)
    PlaySoundFrontend(-1, "PIN_BUTTON", "ATM_SOUNDS", 1)
    changedLicences = {}

    -- retrive records from the server and adds it on the ui.
    lib.callback("ND_MDT:viewRecords", false, function(result)
        result.citizen = citizenData[data.id]
        if not result.citizen then
            local result2 = lib.callback.await("ND_MDT:nameSearchByCharacter", false, data.id)
            if not result2 or not next(result2) then return end
            for character, info in pairs(result2) do
                local citizen = Bridge.getCitizenInfo(character, info)
                citizenData[character] = citizen
            end
            result.citizen = citizenData[data.id]
        end
        SendNUIMessage({
            type = "viewRecords",
            data = json.encode(result)
        })
    end, data.id)
end)
RegisterNUICallback("licenseDropDownChange", function(data)
    PlaySoundFrontend(-1, "PIN_BUTTON", "ATM_SOUNDS", 1)
    changedLicences[data.identifier] = data.value
end)

RegisterNUICallback("saveRecords", function(data)
    PlaySoundFrontend(-1, "PIN_BUTTON", "ATM_SOUNDS", 1)
    
    local data = {
        characterId = data.character,
        notes = data.notes,
        changedLicences = changedLicences,
        newCharges = data.newCharges
    }

    TriggerServerEvent("ND_MDT:saveRecords", data)
    changedLicences = {}
end)

-- Trigger a server event and send the text and unit number form the live chat message the client sends.
RegisterNUICallback("sendLiveChat", function(data)
    PlaySoundFrontend(-1, "PIN_BUTTON", "ATM_SOUNDS", 1)
    local playerInfo = Bridge.getPlayerInfo()
    local chatInfo = {
        type = "addLiveChatMessage",
        callsign = playerInfo.callsign,
        dept = playerInfo.jobLabel,
        img = playerInfo.img,
        name = ("%s %s"):format(playerInfo.firstName, playerInfo.lastName),
        text = data.text
    }
    SendNUIMessage(chatInfo)
    TriggerServerEvent("ND_MDT:sendLiveChat", chatInfo)
end)

-- If the client didn't send the message then it will add it when this event is triggered.
RegisterNetEvent("ND_MDT:receiveLiveChat", function(chatInfo)
    if chatInfo.id == cache.serverId then return end
    local playerInfo = Bridge.getPlayerInfo()
    if not Bridge.hasAccess(playerInfo.job) then return end
    SendNUIMessage(chatInfo)
end)

-- returns all 911 calls from the server and updates them on the ui.
RegisterNetEvent("ND_MDT:update911Calls", function(emeregencyCalls)
    display911Calls(emeregencyCalls)
end)

-- returns all active units from the server and updates the status on the ui.
RegisterNetEvent("ND_MDT:updateUnitStatus", function(units)
    displayUnits(units)
end)

RegisterNUICallback("vehicleStatus", function(data)
    PlaySoundFrontend(-1, "PIN_BUTTON", "ATM_SOUNDS", 1)
    TriggerServerEvent("ND_MDT:vehicleStolenStatus", data.id, data.stolen, data.plate)
end)

RegisterNUICallback("weaponStatus", function(data)
    PlaySoundFrontend(-1, "PIN_BUTTON", "ATM_SOUNDS", 1)
    TriggerServerEvent("ND_MDT:weaponStolenStatus", data.serial, data.stolen)
end)

RegisterNUICallback("weaponSerialSearch", function(data)
    PlaySoundFrontend(-1, "PIN_BUTTON", "ATM_SOUNDS", 1)
    weaponSearch(data.searchBy, data.search)
end)

RegisterNUICallback("createBolo", function(data)
    TriggerServerEvent("ND_MDT:createBolo", data)
end)

RegisterNUICallback("getBolos", function(data)
    local bolos = lib.callback.await("ND_MDT:getBolos")
    SendNUIMessage({
        type = "showBolos",
        bolos = bolos
    })
end)

RegisterNUICallback("removeBolo", function(data)
    TriggerServerEvent("ND_MDT:removeBolo", data.id)
end)

RegisterNetEvent("ND_MDT:newBolo", function(bolo)
    local playerInfo = Bridge.getPlayerInfo()
    if not Bridge.hasAccess(playerInfo.job) then return end
    SendNUIMessage({
        type = "newBolo",
        bolo = bolo
    })
end)

RegisterNetEvent("ND_MDT:removeBolo", function(id, boloType)
    local playerInfo = Bridge.getPlayerInfo()
    if not Bridge.hasAccess(playerInfo.job) then return end
    SendNUIMessage({
        type = "removeBolo",
        id = id,
        boloType = boloType
    })
end)


RegisterNUICallback("createReport", function(data)
    TriggerServerEvent("ND_MDT:createReport", data)
end)

RegisterNUICallback("getReports", function(data)
    local reports = lib.callback.await("ND_MDT:getReports")
    SendNUIMessage({
        type = "showReports",
        reports = reports
    })
end)

RegisterNUICallback("removeReport", function(data)
    TriggerServerEvent("ND_MDT:removeReport", data.id)
end)

RegisterNetEvent("ND_MDT:newReport", function(report)
    local playerInfo = Bridge.getPlayerInfo()
    if not Bridge.hasAccess(playerInfo.job) then return end
    SendNUIMessage({
        type = "newReport",
        report = report
    })
end)

RegisterNetEvent("ND_MDT:removeReport", function(id, reportType)
    local playerInfo = Bridge.getPlayerInfo()
    if not Bridge.hasAccess(playerInfo.job) then return end
    SendNUIMessage({
        type = "removeReport",
        id = id,
        reportType = reportType
    })
end)

RegisterNetEvent("ND_MDT:panic", function(info)
    SendNUIMessage(info)
end)

local function getPlayerPostal()
    local postal = false
    if GetResourceState("nearest-postal") == "started" then
        postal = exports["nearest-postal"]:getPostal()
    elseif GetResourceState("ModernHUD") == "started" then
        postal = exports["ModernHUD"]:getPostal()
    end
    return postal
end

lib.callback.register("ND_MDT:getStreet", function(radius)
    local postal = getPlayerPostal()
    local coords = GetEntityCoords(cache.ped)
    local location = GetStreetNameFromHashKey(GetStreetNameAtCoord(coords.x, coords.y, coords.z))
    return location, postal
end)

local function isInputValid(input)
    if not input or input:gsub("[%.%-_ ]", "") == "" then return end
    return true
end

-- triggers a server event with the 911 call information.
RegisterCommand("911", function(source, args, rawCommand)
    local input = lib.inputDialog("Create a 911 call", {
        {type = "textarea", label = "Message", required = true},
        {type = "checkbox", label = "Share location"},
        {type = "checkbox", label = "Share your name"},
    })

    if not input or not isInputValid(input[1]) then
        return lib.notify({
            title = "911",
            description = "invalid input!",
            type = "error"
        })
    end

    local caller = nil
    if input[2] then
        local playerInfo = Bridge.getPlayerInfo()
        caller = ("%s %s"):format(playerInfo.firstName, playerInfo.lastName)
    end

    local location = nil
    if input[3] then
        local coords = GetEntityCoords(cache.ped)
        location = GetStreetNameFromHashKey(GetStreetNameAtCoord(coords.x, coords.y, coords.z))

        local postal = getPlayerPostal()
        if postal then
            location = ("%s (%s)"):format(location, postal)
        end
    end

    TriggerServerEvent("ND_MDT:Create911Call", {
        caller = caller,
        location = location,
        callDescription = input[1]
    })

    lib.notify({
        title = "911",
        description = "Your call has been successfully submitted!",
        type = "success"
    })
end, false)

print("^1[^4ND_MDT^1] ^0for support join the discord server: ^4https://discord.gg/Z9Mxu72zZ6^0.")
