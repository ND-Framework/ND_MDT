local NDCore = exports["ND_Core"]
local Bridge = {}

SetTimeout(500, function()
    NDCore:loadSQL({
        "bridge/nd/database/bolos.sql",
        "bridge/nd/database/records.sql",
        "bridge/nd/database/reports.sql",
        "bridge/nd/database/weapons.sql"
    })
end)

local function getPlayerSource(id)
    local playerSource = false
    local players = NDCore:getPlayers("id", id)
    for src, info in pairs(players) do
        if info.id == id then
            return src
        end
    end
end

local function queryDatabaseProfiles(first, last)
    local result = MySQL.query.await("SELECT * FROM nd_characters")
    local profiles = {}
    for i=1, #result do
        local item = result[i]
        local metadata = json.decode(item.metadata)
        local firstname = (item.firstname or ""):lower()
        local lastname = (item.lastname or ""):lower()

        if first ~= "" and firstname:find(first) or last ~= "" and lastname:find(last) then            
            profiles[item.charid] = {
                firstName = item.firstname,
                lastName = item.lastname,
                dob = item.dob,
                gender = item.gender,
                phone = metadata.phonenumber,
                id = getPlayerSource(item.charid),
                img = metadata.img,
                ethnicity = metadata.ethnicity
            }
        end
    end
    return profiles
end

---@param src number
---@param first string|nil
---@param last string|nil
---@return table
function Bridge.nameSearch(src, first, last)
    local player = NDCore:getPlayer(src)
    if not config.policeAccess[player.job] then return false end

    local profiles = {}
    local firstname = (first or ""):lower()
    local lastname = (last):lower()
    local data = queryDatabaseProfiles(firstname, lastname)

    for k, v in pairs(data) do
        profiles[k] = v
    end

    return profiles
end

local function findCharacterById(id)
    local players = NDCore:getPlayers()
    for _, info in pairs(players) do
        if info.id == id then
            return info
        end
    end
end

---@param source number
---@param characterSearched number
---@return table
function Bridge.characterSearch(source, characterSearched)
    local player = NDCore:getPlayer(source)
    if not config.policeAccess[player.job] then return false end

    local profiles = {}
    local item = findCharacterById(id)

    if not item then
        local result = MySQL.query.await("SELECT * FROM nd_characters WHERE charid = ?", {characterSearched})
        local item = result and result[1]
        if not item then return end

        local metadata = json.decode(item.metadata)
        profiles[item.charid] = {
            firstName = item.firstname,
            lastName = item.lastname,
            dob = item.dob,
            gender = item.gender,
            phone = metadata.phonenumber,
            id = getPlayerSource(item.charid),
            img = metadata.img,
            ethnicity = metadata.ethnicity
        }
        return profiles
    end

    profiles[item.id] = {
        firstName = item.firstname,
        lastName = item.lastname,
        dob = item.dob,
        gender = item.gender,
        phone = item.metadata.phonenumber,
        id = item.source,
        img = item.metadata.img,
        ethnicity = item.metadata.ethnicity
    }
    return profiles
end

---@param src number
---@return table
function Bridge.getPlayerInfo(src)
    local player = NDCore:getPlayer(src) or {}
    return {
        firstName = player.firstname or "",
        lastName = player.lastname or "",
        job = player.job or "",
        jobLabel = player.jobInfo?.label or player.job or "",
        callsign = player.metadata.callsign or "",
        img = player.metadata.img or "user.jpg",
        characterId = player.id
    }
end

local function getVehicleCharacter(owner)
    local item = findCharacterById(owner)
    if not item then
        local result = MySQL.query.await("SELECT * FROM nd_characters WHERE charid = ?", {owner})
        item = result and result[1]
    end
    return item and {
        firstName = item.firstname,
        lastName = item.lastname,
        characterId = item.charid or item.id
    }
end

local function queryDatabaseVehicles(find, findData)
    local query = ("SELECT * FROM nd_vehicles WHERE %s = ?"):format(find)
    local result = MySQL.query.await(query, {findData})
    local vehicles = {}
    local character = find == "owner" and getVehicleCharacter(findData)

    for i=1, #result do
        local item = result[i]
        if find == "plate" then character = getVehicleCharacter(item.owner) end
        local props = json.decode(item.properties)
        vehicles[item.id] = {
            id = item.id,
            color = props.colorName,
            make = item.makeName,
            model = item.modelName,
            plate = item.plate,
            class = item.className,
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
    local player = NDCore:getPlayer(src)
    if not config.policeAccess[player.job] then return false end

    local vehicles = {}
    if searchBy == "plate" then
        local data = queryDatabaseVehicles("plate", data)
        for k, v in pairs(data) do
            vehicles[k] = v
        end
    elseif searchBy == "owner" then
        local data = queryDatabaseVehicles("owner", data)
        for k, v in pairs(data) do
            vehicles[k] = v
        end
    end
    return vehicles
end

---@param id number
---@return table
function Bridge.getProperties(id)
    if GetResourceState("ND_Properties") ~= "started" then
        return {} -- todo: udate ND_Properties for ND V2
    end

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

    local result = MySQL.query.await("SELECT `metadata` FROM nd_characters WHERE charid = ?", {id})
    local metadata = result and result[1] and json.decode(result[1].metadata) or {}
    return metadata.licenses or {}
end

---@param characterId number
---@param licenseIdentifier string
---@param newLicenseStatus string
function Bridge.editPlayerLicense(characterId, licenseIdentifier, newLicenseStatus)
    local player = NDCore:fetchCharacter(characterId)
    player.updateLicense(licenseIdentifier, {
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
    MySQL.query("UPDATE nd_vehicles SET stolen = ? WHERE id = ?", {stolen and 1 or 0, id})
end

---@return table
function Bridge.getStolenVehicles()
    local plates = {}
    local result = MySQL.query.await("SELECT `plate` FROM `nd_vehicles` WHERE `stolen` = 1")
    for i=1, #result do
        local veh = result[i]
        plates[#plates+1] = veh.plate
    end

    local bolos = MySQL.query.await("SELECT `data` FROM `nd_mdt_bolos` WHERE `type` = 'vehicle'")
    for i=1, #bolos do
        local veh = bolos[i]
        local info = json.decode(veh.data) or {}
        if info.plate then
            plates[#plates+1] = info.plate
        end
    end

    return plates
end

---@param characterId number
function Bridge.getPlayerImage(characterId)
    local player = findCharacterById(characterId) or NDCore:fetchCharacter(characterId)
    return player and player.metadata and player.metadata.img -- img in metadata from a character.
end

---@param characterId number
---@param key any
---@param value any
function Bridge.updatePlayerMetadata(source, characterId, key, value)
    local player = NDCore:getPlayer(source)
    player.setMetadata(key, value)
end

function Bridge.getRecords(id)
    local result = MySQL.query.await("SELECT records FROM nd_mdt_records WHERE `character` = ? LIMIT 1", {id})
    if not result or not result[1] then
        return {}, false
    end
    return json.decode(result[1].records), true
end

local function getPermsFromGroups(groups)
    for name, group in pairs(groups) do
        if group.isJob then
            return name, group
        end
    end
end

local function filterEmployeeSearch(player, metadata, search)
    local toSearch = ("%s %s %s"):format(
        (player.firstname or ""):lower(),
        (player.lastname or ""):lower(),
        (metadata.callsign and tostring(metadata.callsign) or ""):lower()
    )

    if toSearch:find(search:lower()) then
        return true
    end
end

-- local function getPlayerSourceFromPlayers(players, id)
--     for src, info in pairs(players) do
--         if info.id == id then
--             return src
--         end
--     end
-- end

function Bridge.viewEmployees(src, search)
    local player = NDCore:getPlayer(src)
    if not config.policeAccess[player.job] then return end

    local employees = {}
    local onlinePlayers = NDCore:getPlayers(nil, nil, true)
    local result = MySQL.query.await("SELECT * FROM nd_characters")

    for i=1, #result do
        local info = result[i]
        for j=1, #onlinePlayers do
            local ply = onlinePlayers[j]
            if ply.id == info.charid then
                local job, jobInfo = getPermsFromGroups(ply.groups)
                if not config.policeAccess[job] then goto next end
                
                local metadata = ply.metadata
                if not filterEmployeeSearch(ply, metadata, search or "") then goto next end
                
                employees[#employees+1] = {
                    source = ply.source,
                    charId = ply.id,
                    first = ply.firstname,
                    last = ply.lastname,
                    img = metadata.img,
                    callsign = metadata.callsign,
                    job = job,
                    jobInfo = jobInfo,
                    dob = ply.dob,
                    gender = ply.gender,
                    phone = metadata.phonenumber
                }
                goto next
            end
        end
        
        local groups = info.groups and json.decode(info.groups) or {}
        local job, jobInfo = getPermsFromGroups(groups)

        if not config.policeAccess[job] then goto next end

        local metadata = info.metadata and json.decode(info.metadata) or {}
        if not filterEmployeeSearch(info, metadata, search or "") then goto next end
        
        employees[#employees+1] = {
            charId = info.charid,
            first = info.firstname,
            last = info.lastname,
            img = metadata.img,
            callsign = metadata.callsign,
            job = job,
            jobInfo = jobInfo,
            dob = info.dob,
            gender = info.gender,
            phone = metadata.phonenumber
        }

        ::next::
    end

    return employees
end

function Bridge.employeeUpdateCallsign(src, charid, callsign)
    local player = NDCore:getPlayer(src)
    if not player then
        return false, "An issue occured try again later!"
    end
    
    if not tonumber(callsign) then
        return false, "Callsign must be a number!"
    end

    callsign = tostring(callsign)
    if not callsign then
        return false, "Incorrect callsign"
    end

    charid = tonumber(charid)
    if not charid then
        return false, "Employee not found!"
    end

    local characterMetadata = nil
    local characterGroups = nil
    local result = MySQL.query.await("SELECT * FROM nd_characters")
    for i=1, #result do
        local info = result[i]
        local metadata = json.decode(info.metadata) or {}
        if metadata.callsign == callsign then
            return false, "This callsign is already used."
        end
        if info.charid == charid then
            characterMetadata = metadata
            characterGroups = json.decode(info.groups) or {}
        end
    end

    local isAdmin = player.getGroup("admin") ~= nil
    local _, jobInfo = player.getJob()
    local targetPlayer = findCharacterById(charid)
    if targetPlayer then
        local _, targetJob = targetPlayer.getJob()
        if not isAdmin and jobInfo.rank <= targetJob.rank then
            return false, "You can only update lower rank employees!"
        end

        targetPlayer.setMetadata("callsign", callsign)
        targetPlayer.save("metadata")
        return callsign
    elseif not characterMetadata then
        return false, "Employee not found"
    end

    local jobRank = nil
    for _, group in pairs(characterGroups) do
        if group.isJob then
            jobRank = group.rank
            break
        end
    end

    if not jobRank then
        return false, "An issue occured, try again later."
    end

    if not isAdmin and jobInfo.rank <= jobRank then
        return false, "You can only update lower rank employees!"
    end

    characterMetadata.callsign = callsign
    
    MySQL.update.await("UPDATE nd_characters SET `metadata` = ? WHERE charid = ?", {
        json.encode(characterMetadata),
        charid
    })
    return callsign
end

function Bridge.updateEmployeeRank(src, update)
    local player = NDCore:getPlayer(src)
    if not player then
        return false, "An issue occured try again later!"
    end

    local isAdmin = player.getGroup("admin") ~= nil
    local _, jobInfo = player.getJob()
    if not isAdmin and jobInfo.rank <= update.newRank then
        return false, "You can't set employees higher rank than you!"
    end

    local groups = NDCore:getConfig("groups")
    local groupRank = tonumber(update.newRank)
    local groupInfo = groups[update.job]
    local rankLabel = groupRank and groupInfo and groupInfo.ranks?[groupRank]
    if not rankLabel then
        return false, "Rank not found!"
    end

    if not tonumber(update.charid) then
        return false, "Employee no found!"
    end

    local targetPlayer = findCharacterById(update.charid)
    if targetPlayer then
        local _, targetJob = targetPlayer.getJob()
        if not isAdmin and jobInfo.rank <= targetJob.rank then
            return false, "You can only update lower rank employees!"
        end

        targetPlayer.setJob(update.job, update.newRank)
        return rankLabel
    end

    local result = MySQL.query.await("SELECT `groups` FROM nd_characters WHERE charid = ?", {update.charid})
    local info = result[1]
    if not info then
        return false, "Employee no found!"
    end

    local playerGroups = json.decode(info.groups) or {}
    local bossRank = groupInfo and groupInfo.minimumBossRank
    local groupName = update.job
    local jobRank = nil

    for name, group in pairs(playerGroups) do
        if group.isJob and groupName == name then
            jobRank = group.rank
            group.label = groupInfo and groupInfo.label or name
            group.rankName = rankLabel
            group.rank = groupRank
            group.isBoss = bossRank and groupRank >= bossRank
            break
        end
    end

    if not jobRank then
        return false, "An issue occured, try again later."
    end

    if not isAdmin and jobInfo.rank <= jobRank then
        return false, "You can only update lower rank employees!"
    end

    MySQL.update.await("UPDATE nd_characters SET `groups` = ? WHERE charid = ?", {
        json.encode(playerGroups),
        update.charid
    })

    return rankLabel
end

function Bridge.removeEmployeeJob(src, charid)
    local player = NDCore:getPlayer(src)
    if not player then
        return false, "An issue occured try again later!"
    end

    charid = tonumber(charid)
    if not charid then
        return false, "Employee not found!"
    end

    local isAdmin = player.getGroup("admin") ~= nil
    local _, jobInfo = player.getJob()

    local targetPlayer = findCharacterById(charid)
    if targetPlayer then
        local _, targetJob = targetPlayer.getJob()
        if not isAdmin and jobInfo.rank <= targetJob.rank then
            return false, "You can only update lower rank employees!"
        end

        targetPlayer.setJob("unemployed")
        return true
    end

    local result = MySQL.query.await("SELECT `groups` FROM nd_characters WHERE charid = ?", {charid})
    local info = result[1]
    if not info then
        return false, "Employee not found"
    end

    local groupName = nil
    local playerGroups = json.decode(info.groups) or {}
    local jobRank = nil

    for name, group in pairs(playerGroups) do
        if group.isJob then
            groupName = name
            jobRank = group.rank
            break
        end
    end

    if not groupName then
        return false, "An issue occured, try again later."
    end

    if not jobRank then
        return false, "An issue occured, try again later."
    end

    if not isAdmin and jobInfo.rank <= jobRank then
        return false, "You can only update lower rank employees!"
    end

    playerGroups[groupName] = nil

    MySQL.update.await("UPDATE nd_characters SET `groups` = ? WHERE charid = ?", {
        json.encode(playerGroups),
        charid
    })
    return true
end

function Bridge.invitePlayerToJob(src, target)
    local player = NDCore:getPlayer(src)
    if not player.job then return end

    local targetPlayer = NDCore:getPlayer(target)
    targetPlayer.setJob(player.job)
    return true
end

function Bridge.ComparePlates(plate1, plate2)
    return plate1:gsub("0", "O") == plate2:gsub("0", "O")
end

return Bridge
