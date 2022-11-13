NDCore = exports["ND_Core"]:GetCoreObject()

local display = false
local unitStatus = "10-7"
local newPed
local unitNumber = GetResourceKvpString("unitNumber")

local id = 0
local MugshotsCache = {}
local Answers = {}
local selectedCharacter

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

-- open the mdt using keymapping.
RegisterCommand("+mdt", function()
    ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped)
    if veh == 0 then return end
    if GetVehicleClass(veh) ~= 18 then return end
    if id == 0 then
        -- returns all active units from the server and updates the status on the ui.
        lib.callback("ND_MDT:getUnitStatus", false, function(units)
            displayUnits(units)
        end)

        TriggerServerEvent("ND_MDT:get911Calls")
    end
    selectedCharacter = NDCore.Functions.GetSelectedCharacter()
    if not config.policeAccess[selectedCharacter.job] and not config.fireAccess[selectedCharacter.job] then return end
    if ped ~= newPed then
        newPed = PlayerPedId()
        img = GetMugShotBase64(newPed, true)
    end
    local veh = GetVehiclePedIsIn(ped)
    display = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        type = "display",
        action = "open",
        img = img,
        department = selectedCharacter.job,
        name = selectedCharacter.firstName .. " " .. selectedCharacter.lastName,
        unitNumber = unitNumber
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
    unitNumber = data.number
    SetResourceKvp("unitNumber", unitNumber)
end)

-- triggers a server event once unit status has been changed from the mdt.
RegisterNUICallback("unitStatus", function(data)
    PlaySoundFrontend(-1, "PIN_BUTTON", "ATM_SOUNDS", 1)
    unitStatus = data.status
    TriggerServerEvent("ND_MDT:setUnitStatus", unitNumber, unitStatus)
end)

-- sets the unit attached or detached from a call.
RegisterNUICallback("unitRespondToCall", function(data)
    PlaySoundFrontend(-1, "PIN_BUTTON", "ATM_SOUNDS", 1)
    local id = data.id
    id = string.gsub(id, "%[", "")
    id = string.gsub(id, "%]", "")
    local i, j = string.find(id, ":")
    id = string.gsub(id, tostring(string.sub(id, 1, j + 1)), "")
    TriggerServerEvent("ND_MDT:unitRespondToCall", tonumber(id), unitNumber)
end)

-- triggers a server event to retrive names based on search.
RegisterNUICallback("nameSearch", function(data)
    PlaySoundFrontend(-1, "PIN_BUTTON", "ATM_SOUNDS", 1)

    -- returns retrived names and character information from the server and adds it on the ui.
    lib.callback("ND_MDT:nameSearch", false, function(result)
        if not result or not next(result) then
            SendNUIMessage({
                type = "nameSearch",
                found = false
            })
            return
        end
        for character, info in pairs(result) do
            local imgFromName = false
            if info.id then
                imgFromName = GetMugShotBase64(GetPlayerPed(GetPlayerFromServerId(info.id)), true)
            else
                imgFromName = "user.jpg"
            end
            SendNUIMessage({
                type = "nameSearch",
                found = true,
                img = imgFromName,
                characterId = character,
                firstName = info.first_name,
                lastName = info.last_name,
                dob = info.dob,
                gender = info.gender
            })
        end
    end, data.first, data.last)
end)

-- triggers a server event to retrive vehicles based on character id.
RegisterNUICallback("viewVehicles", function(data)
    PlaySoundFrontend(-1, "PIN_BUTTON", "ATM_SOUNDS", 1)
    TriggerServerEvent("ND_MDT:viewVehicles", data.id)
end)

RegisterNUICallback("viewRecords", function(data)
    PlaySoundFrontend(-1, "PIN_BUTTON", "ATM_SOUNDS", 1)
    TriggerServerEvent("ND_MDT:viewRecords", data.id)
end)

-- Trigger a server event and send the text and unit number form the live chat message the client sends.
RegisterNUICallback("sendLiveChat", function(data)
    PlaySoundFrontend(-1, "PIN_BUTTON", "ATM_SOUNDS", 1)
    local liveChatImg = GetMugShotBase64(PlayerPedId(), true)
    SendNUIMessage({
        type = "addLiveChatMessage",
        callsign = unitNumber,
        dept = selectedCharacter.job,
        img = liveChatImg,
        name = selectedCharacter.firstName .. " " .. selectedCharacter.lastName,
        text = data.text
    })
    TriggerServerEvent("ND_MDT:sendLiveChat", liveChatImg, unitIdentifier, data.text)
end)

-- If the client didn't send the message then it will add it when this event is triggered.
RegisterNetEvent("ND_MDT:receiveLiveChat")
AddEventHandler("ND_MDT:receiveLiveChat", function(chatInfo)
    selectedCharacter = NDCore.Functions.GetSelectedCharacter()
    if not config.policeAccess[selectedCharacter.job] and not config.fireAccess[selectedCharacter.job] then return end
    local info = chatInfo
    if info.id == GetPlayerServerId(PlayerId()) then return end
    SendNUIMessage({
        type = "addLiveChatMessage",
        img = info.liveChatImg,
        unit = info.unit,
        text = info.text
    })
end)

-- returns all 911 calls from the server and updates them on the ui.
RegisterNetEvent("ND_MDT:update911Calls")
AddEventHandler("ND_MDT:update911Calls", function(emeregencyCalls)
    selectedCharacter = NDCore.Functions.GetSelectedCharacter()
    if not config.policeAccess[selectedCharacter.job] and not config.fireAccess[selectedCharacter.job] then return end
    local isAttached = false
    local unitIdentifier = tostring(unitNumber) .. " " .. selectedCharacter.firstName .. " " .. selectedCharacter.lastName
    SendNUIMessage({
        type = "update911Calls",
        action = "clear"
    })
    for callId, info in pairs(emeregencyCalls) do
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
        SendNUIMessage({
            type = "update911Calls",
            action = "add",
            callId = callId,
            caller = info.caller,
            location = info.location,
            callDescription = info.callDescription,
            attachedUnits = attachedUnits,
            isAttached = isAttached
        })
    end
end)

-- returns all active units from the server and updates the status on the ui.
RegisterNetEvent("ND_MDT:updateUnitStatus", function(units)
    displayUnits(units)
end)

-- returns retrived vehicles from the server and adds it on the ui.
RegisterNetEvent("ND_MDT:returnIdVehicles")
AddEventHandler("ND_MDT:returnIdVehicles", function(result)
    local results = 0
    for _ in pairs(result) do
        results = results + 1
    end
    if not result then
        return
    elseif results == 0 then
        SendNUIMessage({
            type = "viewVehicles",
            found = false
        })
        return
    end
    for vehicle, info in pairs(result) do
        SendNUIMessage({
            type = "viewVehicles",
            found = true,
            vehicleId = vehicle,
            color = info.color,
            make = info.make,
            model = info.model,
            plate = info.plate,
            class = info.class
        })
    end
end)

-- triggers a server event with the 911 call information.
RegisterCommand("911", function(source, args, rawCommand)
    local callDescription = table.concat(args, " ")
    local caller = selectedCharacter.firstName .. " " .. selectedCharacter.lastName
    local coords = GetEntityCoords(PlayerPedId())
    local postal = false
    if config.use911Postal then
       postal = exports[config.postalResourceName]:getPostal()
    end
    local location = GetStreetNameFromHashKey(GetStreetNameAtCoord(coords.x, coords.y, coords.z))
    if postal then
        location = location .. " (" .. postal .. ")"
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
        caller = tostring(args[1]) .. " " .. tostring(args[2])
    end
    local location = tostring(args[3])
    local postal = tostring(args[4])
    if postal ~= "-" then
        location = location .. " (" .. postal .. ")"
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