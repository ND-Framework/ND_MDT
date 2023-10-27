-- For support join my discord: https://discord.gg/Z9Mxu72zZ6

config = {
    -- Jobs that has access to the police version mdt.
    policeAccess = {
        ["sahp"] = true,
        ["lspd"] = true,
        ["bcso"] = true
    },

    -- Jobs that has access to the fire version mdt.
    fireAccess = {
        ["lsfd"] = true
    },

    -- Jobs that has access to the tow version mdt.
    towAccess = {
        ["tow"] = true
    },

    -- Set to true if you'd like to use a postal script with 911 calls.
    use911Postal = true,
    postalResourceName = "nearest-postal" -- name of nearest postal script (make sure to have one installed).

}