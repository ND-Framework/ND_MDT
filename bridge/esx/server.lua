local ESX = exports["es_extended"]:getSharedObject()
local Bridge = {}

--[[ NEEDS TO BE CREATED ]]
-- SetTimeout(500, function()
--     NDCore:loadSQL({
--         "bridge/nd/database/bolos.sql",
--         "bridge/nd/database/records.sql",
--         "bridge/nd/database/reports.sql",
--         "bridge/nd/database/weapons.sql"
--     })
-- end)

---Convert ESX Job to ND_MDT format
---@param job table ESX Job Array
---@param rank integer|nil Grade number
---@return nil
---@return table
function ConvertJobToJobInfo(job, rank)

    if type(job) == "string" then
        job = ESX.GetJobs()[job]
    end

    local grades = {}

    for k, v in pairs(job.grades) do
        grades[tonumber(k)] = v.label
    end

    return job.name, {
        label = job.label,
        ranks = grades,
        rankName = rank and grades[tonumber(rank)] or nil
    }

end

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
                gender = (item.sex == "m" and "Male") or (item.sex == "f" and "Female") or "Other",
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
    local xPlayer = ESX.GetPlayerFromId(source)
    if not config.policeAccess[xPlayer.job.name] then return nil end

    local profiles = {}

    local result = MySQL.query.await("SELECT * FROM users WHERE identifier = ?", {characterSearched})
    local item = result and result[1]

    if not item then return end

    profiles[item.identifier] = {
        firstName = item.firstname,
        lastName = item.lastname,
        dob = item.dateofbirth,
        gender = (item.sex == "m" and "Male") or (item.sex == "f" and "Female") or "Other",
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
        firstName = xPlayer.get("firstName") or "",
        lastName = xPlayer.get("lastName") or "",
        job = xPlayer.getJob().name or "",
        jobLabel = xPlayer.getJob().label or "",
        callsign = xPlayer.getMeta("callsign") or "",
        img = "user.jpg",
        characterId = xPlayer.getIdentifier()
    }
end

local function getVehicleCharacter(owner)
    local item = findCharacterById(owner)
    if not item then
        local result = MySQL.query.await("SELECT * FROM users WHERE identifier = ?", {owner})
        item = result and result[1]
    end
    return item and {
        firstName = item.firstname or item.get("firstName") or "unknown",
        lastName = item.lastname or item.get("lastName") or "unknown",
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
            model = props.model,
            plate = props.plate,
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
            identifier = result[i]?.identifier or result[i].type,
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
            ["@owner"]      = characterId,
            ["@identifier"] = licenseIdentifier,
            ["@status"]     = newLicenseStatus,
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

---@param id string In this case it's the vehicles plate
---@param stolen boolean
---@param plate string Is nil as it doesn't function in the same method
function Bridge.vehicleStolen(id, stolen, plate)
    MySQL.query("UPDATE owned_vehicles SET stolen = ? WHERE plate = ?", {stolen and 1 or 0, id})
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
    return result?[1]?.image or nil
end

---@param characterId number
---@param key any
---@param value any
function Bridge.updatePlayerMetadata(source, characterId, key, value)
    local xPlayer = ESX.GetPlayerFromId(source)
    xPlayer.setMeta(key, value)
end

function Bridge.getRecords(id)
    local result = MySQL.query.await("SELECT records FROM nd_mdt_records WHERE `character` = ? LIMIT 1", {id})
    if not result or not result[1] then
        return {}, false
    end
    return json.decode(result[1].records), true
end

local function filterEmployeeSearch(player, metadata, search)
    local toSearch

    if player.get then
        toSearch = ("%s %s %s"):format(
            (player.get("firstName") or ""):lower(),
            (player.get("lastName") or ""):lower(),
            (player.getMeta("callsign") and tostring(player.getMeta("callsign")) or ""):lower()
        )
    else
        toSearch = ("%s %s %s"):format(
            (player.firstname or ""):lower(),
            (player.lastname or ""):lower(),
            ((json.decode(player.metadata)?.callsign) or ""):lower()
        )
    end

    if toSearch:find(search:lower()) then
        return true
    end
end

function Bridge.viewEmployees(src, search)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not config.policeAccess[xPlayer.job.name] then return end

    local employees = {}
    local result = MySQL.query.await("SELECT * FROM users")

    for i=1, #result do
        local info = result[i]

        local xPly = ESX.GetPlayerFromIdentifier(info.identifier)
        if xPly then
            local job, jobInfo = ConvertJobToJobInfo(ESX.GetJobs()[xPly.job.name], xPly.job.grade)
            if not config.policeAccess[job] then goto next end

            if not filterEmployeeSearch(xPly, nil, search or "") then goto next end

            employees[#employees+1] = {
                source = xPly.playerId,
                charId = xPly.identifier,
                first = xPly.get("firstName"),
                last = xPly.get("lastName"),
                img = nil,
                callsign = xPly.getMeta("callsign"),
                job = job,
                jobInfo = jobInfo,
                dob = xPly.get("dateofbirth"),
                gender = (xPly.get("sex") == "m" and "Male") or (xPly.get("sex") == "f" and "Female") or "Other",
                    --[[ Create a custom function for getting the phone number ]]
                phone = nil
            }
            goto next
        end

        local job, jobInfo = ConvertJobToJobInfo(ESX.GetJobs()[info.job], tostring(info.job_grade))

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
            gender = (info.sex == "m" and "Male") or (info.sex == "f" and "Female") or "Other",
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

    if not charid then
        return false, "Employee not found!"
    end


    local isAdmin = xPlayer?.admin
    local _, jobInfo = ConvertJobToJobInfo(xPlayer.job.name, nil)
    local targetPlayer = findCharacterById(charid)

    if targetPlayer then
        if not isAdmin and not (xPlayer.getIdentifier() == charid or xPlayer.job.grade > targetPlayer?.job?.grade) then
            return false, "You can only update lower rank employees!"
        end

        targetPlayer.setMeta("callsign", callsign)
        print("callsign targetPlayer", targetPlayer.getMeta("callsign"))
        return callsign
    end


    local result = MySQL.query.await("SELECT `metadata`, `job_grade` FROM users WHERE identifier = ?", {charid})
    local metadata, grade = json.decode(result?[1]?.metadata), result?[1]?.grade

    if not metadata then
        return false, "Employee not found"
    end

    if not isAdmin and not xPlayer.job.grade > grade then
        return false, "You can only update lower rank employees!"
    end

    metadata.callsign = callsign

    local rows = MySQL.update.await(
        "UPDATE users SET metadata = @metadata WHERE identifier = @identifier",
        {
            ["@metadata"] = json.encode(metadata),
            ["@identifier"] = charid,
        }
    )

    if rows ~= 1 then
        return false, "An issue occured, try again later."
    end

    return callsign
end

function Bridge.updateEmployeeRank(src, update)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then
        return false, "An issue occured try again later!"
    end

    local isAdmin = xPlayer.admin
    local _, jobInfo = ConvertJobToJobInfo(ESX.GetJobs()[xPlayer.job.name], xPlayer.job.grade)
    if not isAdmin and jobInfo.grade <= update.newRank then
        return false, "You can't set employees higher rank than you!"
    end

    local groups = ESX.GetJobs()
    local groupInfo = groups[update.job]
    local rankLabel = update.newRank and groupInfo and groupInfo.grades?[update.newRank]?.label
    if not rankLabel then
        return false, "Rank not found!"
    end

    if not update.charid then
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

    local rows = MySQL.update.await(
        'UPDATE `users` SET `job_grade` = @grade WHERE `identifier` = @identifier',
        {
            ["@grade"] = update.newRank,
            ["@identifier"] = update.charid,
        }
    )

    if rows == 0 then
        return false, "Employee no found!"
    end

    return rankLabel
end

function Bridge.removeEmployeeJob(src, charid)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then
        return false, "An issue occured try again later!"
    end

    if not charid then
        return false, "Employee not found!"
    end

    local isAdmin = xPlayer.admin
    local _, jobInfo = ConvertJobToJobInfo(ESX.GetJobs()[xPlayer.job.name], xPlayer.job.grade)

    local targetPlayer = findCharacterById(charid)
    if targetPlayer then
        local targetJob = targetPlayer.getJob()
        if not isAdmin and jobInfo.rank <= targetJob.rank then
            return false, "You can only fire lower rank employees!"
        end

        targetPlayer.setJob("unemployed", 0)
        return true
    end

    local result = MySQL.query.await("SELECT `job`, `job_grade` FROM users WHERE identifier = ?", {charid})
    local info = result[1]
    if not info then
        return false, "Employee not found"
    end

    local rows = MySQL.update.await(
        'UPDATE `users` SET `job_grade` = 0, `job` = "unemployed" WHERE `identifier` = @identifier',
        {
            ["@identifier"] = charid,
        }
    )

    if rows == 0 then
        return false, "Employee no found!"
    end

    return true
end

function Bridge.invitePlayerToJob(src, target)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer?.job then return end

    local targetPlayer = ESX.GetPlayerFromId(target)
    targetPlayer.setJob(xPlayer.job.name, 0)
    return true
end

function Bridge.ComparePlates(plate1, plate2)
    return plate1:gsub(" ", "") == plate2:gsub(" ", "")
end

--[[ Xtra Functions ]]
lib.callback.register("ND_MDT:getRanks", function (src, jobName)
    return ESX.GetJobs()[jobName]?.grades
end)

return Bridge
