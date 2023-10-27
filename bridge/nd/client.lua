local NDCore = exports["ND_Core"]:GetCoreObject()

---@return table
function Bridge.getPlayerInfo()
    local player = NDCore.getPlayer()
    return {
        firstName = player.firstname,
        lastName = player.lastname,
        job = player.job,
        callsign = player.metadata.callsign,
        img = player.metadata.img or "user.jpg"
    }
end

---@param job string
---@return boolean
function Bridge.hasAccess(job)
    return config.policeAccess[job] or config.fireAccess[job]
end

---@return string
function Bridge.rankName()
    local player = NDCore.getPlayer()
    for _, group in pairs(player.groups) do
        if group.isJob then
            return group.rankName or ""
        end
    end
    return ""
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
