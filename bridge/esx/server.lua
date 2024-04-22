local ESX = exports["es_extended"]:getSharedObject()
local Bridge = {}

--[[ NEEDS TO BE ]]
-- SetTimeout(500, function()
--     NDCore:loadSQL({
--         "bridge/nd/database/bolos.sql",
--         "bridge/nd/database/records.sql",
--         "bridge/nd/database/reports.sql",
--         "bridge/nd/database/weapons.sql"
--     })
-- end)

local function getPlayerSource(id)
    local xPlayer = ESX.GetPlayerFromIdentifier(id)
    return xPlayer?.playerId or nil
end

local function queryDatabaseProfiles(first, last)
    local result = MySQL.query.await("SELECT * FROM users")
    local profiles = {}
    for i=1, #result do
        local item = result[i]
        local firstname = (item.firstname or ""):lower()
        local lastname = (item.lastname or ""):lower()

        if first ~= "" and firstname:find(first) or last ~= "" and lastname:find(last) then
            profiles[item.identifier] = {
                firstName = item.firstname,
                lastName = item.lastname,
                dob = item.dateofbirth,
                gender = item.sex,
                phone = item?.phonenumber or nil,
                id = getPlayerSource(item.identifier),
                img = item?.image or nil,
                ethnicity = item?.nationality or "N/A"
            }
        end
    end
    return profiles
end

---@param src number
---@param first string|nil
---@param last string|nil
---@return table|boolean
function Bridge.nameSearch(src, first, last)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not config.policeAccess[xPlayer.job.name] then return false end

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
    return ESX.GetPlayerFromIdentifier(id) or nil
end

---@param source number
---@param characterSearched number
---@return table|nil
function Bridge.characterSearch(source, characterSearched)
    local player = NDCore:getPlayer(source)
    if not config.policeAccess[player.job] then return false end

    local profiles = {}

    local result = MySQL.query.await("SELECT * FROM users WHERE identifier = ?", {characterSearched})
    local item = result and result[1]

    if not item then return end

    profiles[item.identifier] = {
        firstName = item.firstname,
        lastName = item.lastname,
        dob = item.dateofbirth,
        gender = item.sex,
        phone = item?.phonenumber or nil,
        id = getPlayerSource(item.identifier),
        img = item?.image or nil,
        ethnicity = item?.nationality or "N/A"
    }

    return profiles
end

---@param src number
---@return table
function Bridge.getPlayerInfo(src)
    local xPlayer = ESX.GetPlayerFromId(src) or {}
    return {
        firstName = xPlayer.get("firstname") or "",
        lastName = xPlayer.get("lastname") or "",
        job = xPlayer.getJob().name or "",
        jobLabel = xPlayer.getJob().label or "",
        callsign = xPlayer.get("callsign") or "",
        img = "user.jpg",
        characterId = xPlayer.getIdentifier()
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
        characterId = item.identifier
    }
end

local function queryDatabaseVehicles(find, findData)
    local query = ("SELECT * FROM owned_vehicles WHERE %s = ?"):format(find)
    local result = MySQL.query.await(query, {findData})
    local vehicles = {}
    local character = find == "owner" and getVehicleCharacter(findData)

    for i=1, #result do
        local item = result[i]
        if find == "plate" then character = getVehicleCharacter(item.owner) end
        local props = json.decode(item.vehicle)
        vehicles[item.plate] = {
            id = item.plate,
                --[[ Needs a custom function to determine name from color index ]]
            color = props.color1,
                --[[ Isn't available as default ESX ]]
            make = nil,
                --[[ Needs a custom function to determine name from hash ]]
            model = item.model,
            plate = item.plate,
                --[[ Isn't available as default ESX ]]
            class = nil,
                --[[ Depends on DB & Vehicle Scripts but isn't available as default ]]
            stolen = item.stolen == 1 or item.owner == 'STOLEN',
            character = character
        }
    end
    return vehicles
end

---@param src number
---@param searchBy string
---@param data number|string
---@return table|boolean
function Bridge.viewVehicles(src, searchBy, data)
    local player = ESX.GetPlayerFromId(src)
    if not config.policeAccess[player.job.name] then return false end

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
    local addresses = {}

    if GetResourceState("ND_Properties") ~= "started" then
        return {} -- todo: udate ND_Properties for ND V2
    end
    if GetResourceState("esx_property") == "started" then
        local properties = exports.esx_property:GetPlayerProperties(id)
        if not properties then return {} end
        for _, adrs in pairs(properties) do
            addresses[#addresses+1] = adrs.setName --[[ There isn't an address saved in esx_property ]]
        end
        return addresses
    end
    if GetResourceState("qs-housing") == "started" then
        local results = MySQL.query.await(
            'SELECT * FROM `player_houses` WHERE `owner` = ?', {id}
        )
        for i=1, #results do
            local item = results[i]
            addresses[#addresses+1] = item.house
        end
        return addresses
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

    local result = MySQL.query.await("SELECT * FROM user_licenses WHERE owner = ?", {id})
    local licenses = {}

    for i=1,#result do
        licenses[#licenses+1] = {
            type = result[i]?.type or result[i],
            status = result[i]?.status,
            issued = result[i]?.issued,
            expires = nil,
            identifier = result[i]?.type or result[i],
        }
    end

    return licenses
end

---@param characterId number
---@param licenseIdentifier string
---@param newLicenseStatus string
function Bridge.editPlayerLicense(characterId, licenseIdentifier, newLicenseStatus)

    MySQL.update.await(
        "UPDATE user_licenses SET status = @status WHERE identifier = @identifier AND owner = @owner",
        {
            ["@owner"] = characterId,
            ["@identifier"] = licenseIdentifier,
            ["@status"] = newLicenseStatus,
        }
    )
end

---@param characterId number
---@param fine number
function Bridge.createInvoice(characterId, fine)
    if GetResourceState("ND_Banking") == "started" then
        exports["ND_Banking"]:createInvoice(fine, 7, false, {
            name = "Government",
            account = "0"
        }, {character = characterId})
    end

    print("[^8WARNING^7] No Billing system setup !")
    print("[^8WARNING^7] Go to: ^4@ND_MDT/bridge/esx:250^7 !")

    --[[ Adapt Receiving society ]]
    -- if GetResourceState("loaf_billing") == "started" or GetResourceState("esx_billing") == "started" then
    --     local serverID = getPlayerSource(characterId)
    --     TriggerEvent('esx_billing:sendBill', serverID, 'Governement', "fine", fine)
    -- end
end

---@param id number
---@param stolen boolean
---@param plate string
function Bridge.vehicleStolen(id, stolen, plate)
    MySQL.query("UPDATE owned_vehicles SET stolen = ? WHERE plate = ?", {stolen and 1 or 0, plate})
end

---@return table
function Bridge.getStolenVehicles()
    local plates = {}
    local result = MySQL.query.await("SELECT `plate` FROM `owned_vehicles` WHERE `stolen` = 1")
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
    local result = MySQL.query.await(
        "SELECT `image` FROM `users` WHERE identifier = ?", {characterId}
    )
    local player = findCharacterById(characterId) or NDCore:fetchCharacter(characterId)
    return result?[1]?.image or nil
end

---@param characterId number
---@param key any
---@param value any
function Bridge.updatePlayerMetadata(source, characterId, key, value)
    local xPlayer = ESX.GetPlayerFromId(source)
    xPlayer.set(key, value)
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
        (player.get("firstname") or ""):lower(),
        (player.get("lastname") or ""):lower(),
        (player.get("callsign") and tostring(player.get("callsign")) or ""):lower()
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
    local xPlayer = ESX.GetPlayerFromId(src)
    if not config.policeAccess[xPlayer.job.name] then return end

    local employees = {}
    local result = MySQL.query.await("SELECT * FROM users")

    for i=1, #result do
        local info = result[i]

        local xPly = ESX.GetPlayerFromIdentifier(info.identifier)
        if xPly then
            local job, jobInfo = xPly.job.name, xPly.job
            if not config.policeAccess[job] then goto next end

            if not filterEmployeeSearch(xPly, nil, search or "") then goto next end

            employees[#employees+1] = {
                source = xPly.playerId,
                charId = xPly.identifier,
                first = xPly.get("firstname"),
                last = xPly.get("lastname"),
                img = nil,
                callsign = xPly.get("callsign"),
                job = job,
                jobInfo = jobInfo,
                dob = xPly.get("dateofbirth"),
                gender = xPly.get("sex"),
                    --[[ Create a custom function for getting the phone number ]]
                phone = nil
            }
            goto next
        end

        local jobObject, gradeObject = ESX.Jobs[info.job], ESX.Jobs[info.job].grades[info.job_grade]

        local job, jobInfo = jobObject.name, {
            id = jobObject.id,
            name = jobObject.name,
            label = jobObject.label,

            grade = tonumber(info.job_grade),
            grade_name = gradeObject.name,
            grade_label = gradeObject.label,
            grade_salary = gradeObject.salary,

            skin_male = gradeObject.skin_male and json.decode(gradeObject.skin_male) or {},
            skin_female = gradeObject.skin_female and json.decode(gradeObject.skin_female) or {},
        }

        if not config.policeAccess[job] then goto next end

        if not filterEmployeeSearch(info, nil, search or "") then goto next end

        employees[#employees+1] = {
            charId = info.identifier,
            first = info.firstname,
            last = info.lastname,
            img = info.image,
            callsign = json.decode(info.metadata)?.callsign,
            job = job,
            jobInfo = jobInfo,
            dob = info.dateofbirth,
            gender = info.sex,
            phone = info.phonenumber
        }

        ::next::
    end

    return employees
end

function Bridge.employeeUpdateCallsign(src, charid, callsign)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then
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
    local result = MySQL.query.await("SELECT * FROM users")
    for i=1, #result do
        local info = result[i]
        local metadata = json.decode(info.metadata) or {}
        if metadata.callsign == callsign then
            return false, "This callsign is already used."
        end
        if info.identifier == charid then
            characterMetadata = metadata
            characterGroups = json.decode(info.groups) or {}
        end
    end

    local isAdmin = xPlayer?.admin
    local jobInfo = xPlayer.job
    local targetPlayer = findCharacterById(charid)
    if targetPlayer then
        local targetJob = targetPlayer.job
        if not isAdmin and jobInfo.job.grade <= targetJob.job.grade then
            return false, "You can only update lower rank employees!"
        end

        targetPlayer.set("callsign", callsign)
        return callsign
    elseif not characterMetadata then
        return false, "Employee not found"
    end

    local jobRank = xPlayer?.job?.grade_label

    if not jobRank then
        return false, "An issue occured, try again later."
    end

    if not isAdmin and jobInfo.rank <= jobRank then
        return false, "You can only update lower rank employees!"
    end

    return callsign
end

--[[ /\ Already Converted BUT untested  /\ ]]
--[[ \/ Needs to be Converted           \/ ]]

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

return Bridge