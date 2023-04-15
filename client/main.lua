NDCore = exports["ND_Core"]:GetCoreObject()

local display = false
local newPed

local id = 0
local MugshotsCache = {}
local Answers = {}
local selectedCharacter

local myimg = nil
local citizenData = {}
local changedLicences = {}

function GetMugShotBase64(Ped, Tasparent)
	if not Ped then return end
	id = id + 1 
	
	local Handle
	
	if Tasparent then
		Handle = RegisterPedheadshotTransparent(Ped)
	else
		Handle = RegisterPedheadshot(Ped)
	end
	
	local timer = 2000
	while ((not Handle or not IsPedheadshotReady(Handle) or not IsPedheadshotValid(Handle)) and timer > 0) do
		Citizen.Wait(10)
		timer = timer - 10
	end

	local MugShotTxd = "none"
	if (IsPedheadshotReady(Handle) and IsPedheadshotValid(Handle)) then
		MugshotsCache[id] = Handle
		MugShotTxd = GetPedheadshotTxdString(Handle)
	end

	SendNUIMessage({
		type = "convert",
		pMugShotTxd = MugShotTxd,
		id = id,
	})
	
	while not Answers[id] do
		Citizen.Wait(10)
	end
	
	if MugshotsCache[id] then
		UnregisterPedheadshot(MugshotsCache[id])
		MugshotsCache[id] = nil
	end
	
	local CallBack = Answers[id]
	Answers[id] = nil
	
	return CallBack
end

RegisterNUICallback("Answer", function(data)
	Answers[data.Id] = data.Answer
end)

AddEventHandler("onResourceStop", function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
    for k, v in pairs(MugshotsCache) do
	    UnregisterPedheadshot(v)
    end
end)

function getLocalPlayerImage(ped)
    if not myimg or PlayerPedId() ~= ped then
        myimg = GetMugShotBase64(ped, true)
        return myimg
    end
    return myimg
end

function displayUnits(units)
    selectedCharacter = NDCore.Functions.GetSelectedCharacter()
    if not config.policeAccess[selectedCharacter.job] and not config.fireAccess[selectedCharacter.job] then return end
    SendNUIMessage({
        type = "updateUnitStatus",
        action = "clear"
    })
    for _, info in pairs(units) do
        SendNUIMessage({
            type = "updateUnitStatus",
            action = "add",
            unit = info.unit,
            status = info.status
        })
    end
end

function display911Calls(emeregencyCalls)
    selectedCharacter = NDCore.Functions.GetSelectedCharacter()
    if not config.policeAccess[selectedCharacter.job] and not config.fireAccess[selectedCharacter.job] then return end
    local unitIdentifier = ("%s %s %s"):format(selectedCharacter.data.callsign, selectedCharacter.firstName, selectedCharacter.lastName)
    local data = {}
    for callId, info in pairs(emeregencyCalls) do
        local isAttached = false
        local attachedUnits = info.attachedUnits
        if #attachedUnits == 0 then
            attachedUnits = "*No units attached to call*"
        else
            for _, unit in pairs(attachedUnits) do
                if unit == unitIdentifier then
                    isAttached = true
                    break
                end
            end
            attachedUnits = table.concat(info.attachedUnits, ", ")
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

function getRankName(character)
    if not character.data.groups then return "" end
    local job = selectedCharacter.job:lower()
    for name, groupInfo in pairs(character.data.groups) do
        if name:lower() == job then
            return groupInfo.rankName
        end
    end
    return ""
end

-- open the mdt using keymapping.
RegisterCommand("+mdt", function()
    selectedCharacter = NDCore.Functions.GetSelectedCharacter()
    if not config.policeAccess[selectedCharacter.job] and not config.fireAccess[selectedCharacter.job] then return end
    ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped)
    if veh == 0 then return end
    if GetVehicleClass(veh) ~= 18 then return end
    if id == 0 then
        -- returns all active units from the server and updates the status on the ui.
        lib.callback("ND_MDT:getUnitStatus", false, function(units)
            displayUnits(units)
        end)
        lib.callback("ND_MDT:get911Calls", false, function(emeregencyCalls)
            displayUnits(emeregencyCalls)
        end)
    end
    local img = getLocalPlayerImage(ped)
    local veh = GetVehiclePedIsIn(ped)
    display = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        type = "display",
        action = "open",
        img = img,
        department = selectedCharacter.job,
        rank = getRankName(selectedCharacter),
        name = ("%s %s"):format(selectedCharacter.firstName, selectedCharacter.lastName),
        unitNumber = selectedCharacter.data.callsign
    })
    PlaySoundFrontend(-1, "DELETE", "HUD_DEATHMATCH_SOUNDSET", 1)
end, false)
RegisterCommand("-mdt", function()end, false)
RegisterKeyMapping("+mdt", "Open the ND MDT", "keyboard", "b")

-- close the ui.
RegisterNUICallback("close", function()
    display = false
    SetNuiFocus(false, false)
    PlaySoundFrontend(-1, "PIN_BUTTON", "ATM_SOUNDS", 1)
end)

-- saves the unit number in kvp so they don't need to set it everytime they log on.
RegisterNUICallback("setUnitNumber", function(data)
    PlaySoundFrontend(-1, "PIN_BUTTON", "ATM_SOUNDS", 1)
    TriggerServerEvent("ND_MDT:updateCallsign", data.number)
end)

-- triggers a server event once unit status has been changed from the mdt.
RegisterNUICallback("unitStatus", function(data)
    PlaySoundFrontend(-1, "PIN_BUTTON", "ATM_SOUNDS", 1)
    TriggerServerEvent("ND_MDT:setUnitStatus", data.status, data.code)
end)

-- sets the unit attached or detached from a call.
RegisterNUICallback("unitRespondToCall", function(data)
    PlaySoundFrontend(-1, "PIN_BUTTON", "ATM_SOUNDS", 1)
    TriggerServerEvent("ND_MDT:unitRespondToCall", tonumber(data.id), unitNumber)
end)

function weaponSearch(searchBy, search)
    local weaponPage = false
    if searchBy == "owner" then weaponPage = true end

    -- returns retrived names and character information from the server and adds it on the ui.
    lib.callback("ND_MDT:weaponSerialSearch", false, function(result)
        print(json.encode(result,{indent=true}))
        if not result or not next(result) then
            if weaponPage then
                SendNUIMessage({
                    type = "weaponSerialSearch",
                    found = "No weapons found registered to this citizen."
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
    print(json.encode(result, {indent = true}))
    if not result or not next(result) then
        SendNUIMessage({
            type = "nameSearch",
            found = false
        })
        return
    end
    local data = {}
    for character, info in pairs(result) do
        local imgFromName = info.img or "user.jpg"
        -- if info.id then
        --     imgFromName = GetMugShotBase64(GetPlayerPed(GetPlayerFromServerId(info.id)), true)
        -- end
        local citizen = {
            img = imgFromName,
            characterId = character,
            firstName = info.first_name,
            lastName = info.last_name,
            dob = info.dob,
            gender = info.gender,
            phone = info.phone,
            ethnicity = info.ethnicity
        }
        citizenData[character] = citizen
        data[#data+1] = citizen
    end
    SendNUIMessage({
        type = "nameSearch",
        found = true,
        data = json.encode(data)
    })
end

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
        print(json.encode(result, {indent = true}))
        if not result or not next(result) then
            if vehPage then
                SendNUIMessage({
                    type = "viewVehicles",
                    found = "No vehicles found registered to this citizen."
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
    selectedCharacter = NDCore.Functions.GetSelectedCharacter()
    local liveChatImg = getLocalPlayerImage(PlayerPedId())
    local chatInfo = {
        type = "addLiveChatMessage",
        callsign = selectedCharacter.data.callsign,
        dept = selectedCharacter.job,
        img = liveChatImg,
        name = ("%s %s"):format(selectedCharacter.firstName, selectedCharacter.lastName),
        text = data.text
    }
    SendNUIMessage(chatInfo)
    TriggerServerEvent("ND_MDT:sendLiveChat", chatInfo)
end)

-- If the client didn't send the message then it will add it when this event is triggered.
RegisterNetEvent("ND_MDT:receiveLiveChat")
AddEventHandler("ND_MDT:receiveLiveChat", function(chatInfo)
    if chatInfo.id == GetPlayerServerId(PlayerId()) then return end
    selectedCharacter = NDCore.Functions.GetSelectedCharacter()
    if not config.policeAccess[selectedCharacter.job] and not config.fireAccess[selectedCharacter.job] then return end
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
    if (not selectedCharacter) or not config.policeAccess[selectedCharacter.job] and not config.fireAccess[selectedCharacter.job] then return end
    SendNUIMessage({
        type = "newBolo",
        bolo = bolo
    })
end)

RegisterNetEvent("ND_MDT:removeBolo", function(id, boloType)
    if (not selectedCharacter) or not config.policeAccess[selectedCharacter.job] and not config.fireAccess[selectedCharacter.job] then return end
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
    if (not selectedCharacter) or not config.policeAccess[selectedCharacter.job] and not config.fireAccess[selectedCharacter.job] then return end
    SendNUIMessage({
        type = "newReport",
        report = report
    })
end)

RegisterNetEvent("ND_MDT:removeReport", function(id, reportType)
    if (not selectedCharacter) or not config.policeAccess[selectedCharacter.job] and not config.fireAccess[selectedCharacter.job] then return end
    SendNUIMessage({
        type = "removeReport",
        id = id,
        reportType = reportType
    })
end)

RegisterNetEvent("ND_MDT:panic", function(info)
    SendNUIMessage(info)
end)

lib.callback.register("ND_MDT:getStreet", function(radius)
    local coords = GetEntityCoords(PlayerPedId())
    local postal = false
    if config.use911Postal then
       postal = exports[config.postalResourceName]:getPostal()
    end
    local location = GetStreetNameFromHashKey(GetStreetNameAtCoord(coords.x, coords.y, coords.z))
    return location, postal
end)

-- triggers a server event with the 911 call information.
RegisterCommand("911", function(source, args, rawCommand)
    local callDescription = table.concat(args, " ")
    local caller = ("%s %s"):format(selectedCharacter.firstName, selectedCharacter.lastName)
    local coords = GetEntityCoords(PlayerPedId())
    local postal = false
    if config.use911Postal then
       postal = exports[config.postalResourceName]:getPostal()
    end
    local location = GetStreetNameFromHashKey(GetStreetNameAtCoord(coords.x, coords.y, coords.z))
    if postal then
        location = ("%s (%s)"):format(location, postal)
    end
    local info = {
        caller = caller,
        location = location,
        callDescription = callDescription,
        attachedUnits = {}
    }
    TriggerServerEvent("ND_MDT:Create911Call", info)
end, false)

RegisterCommand("911-", function(source, args, rawCommand)
    local callDescription = "test"
    local first = tostring(args[1])
    local last = tostring(args[2])
    local caller
    if first == "-" then
        caller = "*Anonymous caller*"
    else
        caller = ("%s %s"):format(args[1], args[2])
    end
    local location = tostring(args[3])
    local postal = tostring(args[4])
    if postal ~= "-" then
        location = ("%s (%s)"):format(location, postal)
    end
    local info = {
        caller = caller,
        location = location,
        callDescription = callDescription,
        attachedUnits = {}
    }
    TriggerServerEvent("ND_MDT:Create911Call", info)
end, false)

TriggerEvent("chat:addSuggestion", "/test", "Make a quick 911 call.", {{name="Description", help="Describe your situation."}})
TriggerEvent("chat:addSuggestion", "/911-", "Make a detailed 911 call.", {
    {name="What's your first name?", help="To skip write -"},
    {name="What's your last name?", help="To skip write -"},
    {name="What street are you on?", help="To skip write -"},
    {name="What's your nearest postal?", help="To skip write -"},
    {name="Describe your situation.", help="What's happening, do you need Police, Ambulance?"}
})
print("^1[^4ND_MDT^1] ^0for support join the discord server: ^4https://discord.gg/Z9Mxu72zZ6^0.")


RegisterCommand("mdt", function(source, args, rawCommand)
    selectedCharacter = NDCore.Functions.GetSelectedCharacter()
    if not config.policeAccess[selectedCharacter.job] and not config.fireAccess[selectedCharacter.job] then return end
    ped = PlayerPedId()
    if id == 0 then
        -- returns all active units from the server and updates the status on the ui.
        lib.callback("ND_MDT:getUnitStatus", false, function(units)
            displayUnits(units)
        end)
        lib.callback("ND_MDT:get911Calls", false, function(emeregencyCalls)
            displayUnits(emeregencyCalls)
        end)
    end
    local img = getLocalPlayerImage(ped)
    local veh = GetVehiclePedIsIn(ped)
    display = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        type = "display",
        action = "open",
        img = img,
        department = selectedCharacter.job,
        rank = getRankName(selectedCharacter),
        name = ("%s %s"):format(selectedCharacter.firstName, selectedCharacter.lastName),
        unitNumber = selectedCharacter.data.callsign
    })
    PlaySoundFrontend(-1, "DELETE", "HUD_DEATHMATCH_SOUNDSET", 1)
end, false)