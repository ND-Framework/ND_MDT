local tabletProp = nil

local function removeTablet(ped)
    ClearPedTasks(ped)
    Wait(300)
    DeleteEntity(tabletProp)
end

local function useTablet(ped)
    lib.requestModel(`prop_cs_tablet`)
    lib.requestAnimDict("amb@code_human_in_bus_passenger_idles@female@tablet@base")

    if DoesEntityExist(tabletProp) then
        DeleteEntity(tabletProp)
    end
    
    tabletProp = CreateObject(`prop_cs_tablet`, 0.0, 0.0, 0.0, true, true, false)
    local boneIndex = GetPedBoneIndex(ped, 60309)

    SetCurrentPedWeapon(ped, `weapon_unarmed`, true)
    AttachEntityToEntity(tabletProp, ped, boneIndex, 0.03, 0.002, -0.0, 10.0, 160.0, 0.0, true, false, false, false, 2, true)
    SetModelAsNoLongerNeeded(`prop_cs_tablet`)

    TaskPlayAnim(ped, "amb@code_human_in_bus_passenger_idles@female@tablet@base", "base", 3.0, 3.0, -1, 49, 0, 0, 0, 0)
end

exports("useTablet", function(data, slot)
    local playerInfo = Bridge.getPlayerInfo()
    if not Bridge.hasAccess(playerInfo.job) then
        return lib.notify({
            title = "MDT",
            description = "You don't have access to this device",
            type = "error",
            duration = 5000
        })
    end
    
    useTablet(cache.ped)
    OpenMDT(true)
end)

AddEventHandler("ND:playerEliminated", function()
    OpenMDT(false)
    removeTablet(cache.ped)
end)

AddEventHandler("ND_MDT:closeUI", function()
    removeTablet(cache.ped)
end)