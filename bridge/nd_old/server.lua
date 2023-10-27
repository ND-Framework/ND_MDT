NDCore = exports["ND_Core"]:GetCoreObject()

local function getPlayerSource(id)
    local playerSource = false
    local players = NDCore.Functions.GetPlayers()
    for src, info in pairs(players) do
        if players[src].id == id then
            playerSource = src
            break
        end
    end
    return playerSource
end

local function queryDatabaseProfiles(find, findData)
    local query = ("SELECT * FROM characters WHERE %s RLIKE(?)"):format(find)
    local result = MySQL.query.await(query, {findData})
    local profiles = {}
    for i=1, #result do
        local item = result[i]
        local playerSource = false
        local data = json.decode(item.data)
        profiles[item.character_id] = {
            firstName = item.first_name,
            lastName = item.last_name,
            dob = item.dob,
            gender = item.gender,
            phone = item.phone_number,
            id = getPlayerSource(item.character_id),
            img = data.img,
            ethnicity = data.ethnicity
        }
    end
    return profiles
end

---@param src number
---@param first string|nil
---@param last string|nil
---@return table
function Bridge.nameSearch(src, first, last)
    local player = NDCore.Functions.GetPlayer(src)
    if not config.policeAccess[player.job] then return false end

    local profiles = {}
    if first and first ~= "" then
        local data = queryDatabaseProfiles("first_name", first)
        for k, v in pairs(data) do
            profiles[k] = v
        end
    end
    if last and last ~= "" then
        local data = queryDatabaseProfiles("last_name", last)
        for k, v in pairs(data) do
            profiles[k] = v
        end
    end
    return profiles
end

---@param source number
---@param characterSearched number
---@return table
function Bridge.characterSearch(source, characterSearched)
    local player = NDCore.Functions.GetPlayer(source)
    if not config.policeAccess[player.job] then return false end

    local players = NDCore.Functions.GetPlayers()
    local profiles = {}
    local result = MySQL.query.await("SELECT * FROM characters WHERE character_id = ?", {characterSearched})
    local item = result and result[1]

    if item then        
        local data = json.decode(item.data)
        profiles[item.character_id] = {
            firstName = item.first_name,
            lastName = item.last_name,
            dob = item.dob,
            gender = item.gender,
            phone = item.phone_number,
            id = getPlayerSource(item.character_id),
            img = data.img,
            ethnicity = data.ethnicity
        }
    end
    return profiles
end

---@param src number
---@return table
function Bridge.getPlayerInfo(src)
    local player = NDCore.Functions.GetPlayer(src)
    return {
        firstName = player.firstName,
        lastName = player.lastName,
        job = player.job,
        callsign = player.data.callsign,
        img = player.data.img or "user.jpg",
        characterId = player.id
    }
end

local function getVehicleCharacter(owner)
    local result = MySQL.query.await("SELECT * FROM characters WHERE character_id = ?", {owner})
    if result then
        for i=1, #result do
            local item = result[i]
            return {firstName = item.first_name, lastName = item.last_name, characterId = item.character_id}
        end
    end
end

local function queryDatabaseVehicles(find, findData)
    local query = ("SELECT * FROM characters_vehicles WHERE %s = ?"):format(find)
    local result = MySQL.query.await(query, {findData})
    local vehicles = {}
    local character
    if find == "owner" then character = getVehicleCharacter(findData) end

    for i=1, #result do
        local item = result[i]
        if find == "plate" then character = getVehicleCharacter(item.vehicle_owner) end
        vehicles[item.v_id] = {
            id = item.v_id,
            color = item.color,
            make = item.make,
            model = item.model,
            plate = item.plate,
            class = item.class,
            stolen = item.stolen == 1,
            character = character
        }
    end
    return vehicles
end

---@param src number
---@param searchBy string
---@param data number|string
---@return table
function Bridge.viewVehicles(src, searchBy, data)
    local player = NDCore.Functions.GetPlayer(src)
    if not config.policeAccess[player.job] then return false end

    local vehicles = {}
    if searchBy == "plate" then
        local data = queryDatabaseVehicles("plate", findData)
        for k, v in pairs(data) do
            vehicles[k] = v
        end
    elseif searchBy == "owner" then
        local data = queryDatabaseVehicles("vehicle_owner", findData)
        for k, v in pairs(data) do
            vehicles[k] = v
        end
    end
    return vehicles
end

---@param id number
---@return table
function Bridge.getProperties(id)
    local addresses = {}
    local result = MySQL.query.await("SELECT address FROM nd_properties WHERE owner = ?", {id})
    if not result or not result[1] then return addresses end
    for _, adrs in pairs(result) do
        addresses[#addresses+1] = adrs.address
    end
    return addresses
end

---@param id number
---@return table
function Bridge.getLicenses(id)
    --[[ info in a license.
        {
            type = string (driver, weapon, hunting, etc),
            status = string (valid, expired, suspended, etc),
            issued = timestamp,
            expires = timestamp,
            identifier = in ND it's a 16 character identifier including letters and numbers.
        }
    ]]

    local result = MySQL.query.await("SELECT `data` FROM characters WHERE character_id = ?", {id})
    local data = result and result[1] and result[1].data
    return data.licenses or {}
end

---@param characterId number
---@param licenseIdentifier string
---@param newLicenseStatus string
function Bridge.editPlayerLicense(characterId, licenseIdentifier, newLicenseStatus)
    NDCore.Functions.EditPlayerLicense(data.characterId, licenseIdentifier, {
        status = newLicenseStatus
    })
end

---@param characterId number
---@param fine number
function Bridge.createInvoice(characterId, fine)
    exports["ND_Banking"]:createInvoice(fine, 7, false, {
        name = "Government",
        account = "0"
    }, {character = characterId})
end

---@param id number
---@param stolen boolean
---@param plate string
function Bridge.vehicleStolen(id, stolen, plate)
    MySQL.query("UPDATE characters_vehicles SET stolen = ? WHERE v_id = ?", {stolen and 1 or 0, id})
end

---@return table
function Bridge.getStolenVehicles()
    local plates = {}
    local result = MySQL.query.await("SELECT `plate` FROM `characters_vehicles` WHERE `stolen` = 1")
    for _, veh in pairs(result) do
        plates[#plates+1] = veh.plate
    end
    return plates
end

---@param characterId number
function Bridge.getPlayerImage(characterId)
    local character = NDCore.Functions.GetPlayerByCharacterId(characterId)
    return character and character.data and character.data.img -- img in metadata from a character.
end

---@param characterId number
---@param key any
---@param value any
function Bridge.updatePlayerMetadata(characterId, key, value)
    NDCore.Functions.SetPlayerData(characterId, key, value)
end
