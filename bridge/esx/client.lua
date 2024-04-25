local ESX = exports["es_extended"]:getSharedObject()
local Bridge = {}

---@return table
function Bridge.getPlayerInfo()
    local xPlayer = ESX.GetPlayerData() or {}

    local isBoss
    if xPlayer?.job?.name then
        ESX.TriggerServerCallback("esx_society:isBoss", function (bool)
            isBoss = bool
        end, xPlayer?.job?.name)
    end

    while isBoss == nil do
        Citizen.Wait(50)
    end

    return {
        firstName = xPlayer.firstName or "",
        lastName = xPlayer.lastName or "",
        job = xPlayer?.job?.name or "",
        jobLabel = xPlayer.job?.label or "",
        callsign = xPlayer?.metadata?.callsign or "",
        img = "user.jpg",
        isBoss = isBoss,
    }
end

---@param job string|table
---@return boolean
function Bridge.hasAccess(job)
    return config.policeAccess[job?.name or job] or config.fireAccess[job?.name or job]
end

---@return string
function Bridge.rankName()
    return ESX.GetPlayerData().job.grade_label
end

---@param id number
---@param info table
---@return table
--- info is from returned profiles in server.lua
function Bridge.getCitizenInfo(id, info)
    return {
        img = info.img or "user.jpg",
        characterId = id,
        firstName = info.firstName,
        lastName = info.lastName,
        dob = info.dob,
        gender = info.gender,
        phone = info.phone,
        ethnicity = info.ethnicity
    }
end

function Bridge.getRanks(job)
    print("Bridge.getRanks", json.encode(job, {indent=4}))
    local ranks = lib.callback.await("ND_MDT:getRanks", false, job)

    if not ranks then return end

    local options = {}
    for k, v in pairs(ranks) do
        options[#options+1] = {
            value = k,
            label = v.label
        }
    end

    return options, job
end

---comment
---@param table any
---@return table
function Bridge.FillInVehData(table)
    for k, v in pairs(table) do
        table[k].model = GetDisplayNameFromVehicleModel(v.model)
        table[k].make = GetMakeNameFromVehicleModel(v.model)
        table[k].class = VehicleClasses?[GetVehicleClassFromName(v.model)]
    end
    return table
end

return Bridge
