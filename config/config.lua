-- For support join my discord: https://discord.gg/Z9Mxu72zZ6

config = {
    -- Departments that has access to the police mdt.
    policeAccess = {
        ["SAHP"] = true,
        ["LSPD"] = true,
        ["BCSO"] = true
    },

    -- Departments that has access to the fire mdt.
    fireAccess = {
        ["LSFD"] = true
    },

    -- Set to true if you'd like to use a postal script with 911 calls.
    use911Postal = true,
    postalResourceName = "nearest-postal", -- name of nearest postal script (make sure to have one installed).


}