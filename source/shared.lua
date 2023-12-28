local bridgeResources = {
    ["ND_Core"] = "nd",
    ["es_extended"] = "esx",
    ["qb-core"] = "qb"
}

local function getBridge()
    for resource, framework in pairs(bridgeResources) do
        if GetResourceState(resource):find("start") then
            return ("bridge.%s.%s"):format(framework, lib.context), resource
        end
    end
    return ("bridge.standalone.%s"):format(lib.context), "standalone"
end

local bridge, resource = getBridge()

if lib.context == "server" then
    local resourceName = GetCurrentResourceName()
    local databaseFiles = {
        "bridge/%s/database/bolos.sql",
        "bridge/%s/database/records.sql",
        "bridge/%s/database/reports.sql",
        "bridge/%s/database/weapons.sql"
    }

    for i=1, #databaseFiles do
        local file = LoadResourceFile(resourceName, databaseFiles[i])
        if file then MySQL.query(file) end
    end
end

Bridge = require(bridge)
