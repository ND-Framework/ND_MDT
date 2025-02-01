-- For support join my discord: https://discord.gg/Z9Mxu72zZ6

config = {
    -- Jobs that has access to the police version mdt.
    policeAccess = {
        ["police"] = true, --[[ DEFAULT ESX JOB NAME ]]
        ["sahp"] = true,
        ["lspd"] = true,
        ["bcso"] = true
    },

    -- Jobs that has access to the fire version mdt.
    fireAccess = { -- this is not used yet, leave it as it is.
        ["lsfd"] = true
    },

    
    -- blip colors.
    vehicleBlips = {
        ["police"] = 3,
        ["sahp"] = 3,
        ["lspd"] = 3,
        ["bcso"] = 3,
        ["lsfd"] = 1
    },

    -- the length, in seconds, that you want people to wait before being able to panic again
    panicCooldown = 30,

    getPoliceVehicleBlip = function(vehicle)
        local class = GetVehicleClass(vehicle)
        if GetVehicleNumberOfWheels(vehicle) == 2 then
            return 348
        elseif class == 18 then
            return 825
        elseif class == 15 then
            return 422
        end
    end,


    getFireVehicleBlip = function(vehicle)
        local class = GetVehicleClass(vehicle)
        if GetVehicleNumberOfWheels(vehicle) == 2 then
            return 348
        elseif class == 18 then
            return 800
        elseif class == 15 then
            return 422
        end
    end
    
}
