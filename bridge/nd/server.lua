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

local function queryDatabase(find, findData)
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

function BridgeNameSearch(src, first, last)
    local player = NDCore.Functions.GetPlayer(src)
    if not config.policeAccess[player.job] then return false end

    local profiles = {}
    if first and first ~= "" then
        for k, v in pairs(queryDatabase("first_name", first)) do
            profiles[k] = v
        end
    end
    if last and last ~= "" then
        for k, v in pairs(queryDatabase("last_name", last)) do
            profiles[k] = v
        end
    end
    return profiles
end

function BridgeCharacterSearch(source, characterSearched)
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