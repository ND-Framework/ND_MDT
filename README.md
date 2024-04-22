<p align="center"><b><a href="https://ndcore.dev/">Documentation</a></b>

<div align="center">
    <a href="https://discord.gg/Z9Mxu72zZ6" target="_blank">
        <img src="https://discordapp.com/api/guilds/857672921912836116/widget.png?style=banner2" alt="Andyyy Development Server" height="60px" />
    </a>
</div>

# ND_MDT

This is a police MDT with many useful features, I plan on making a dispatch panel to go with this sometime and probably another MDT more specific for EMS.

I started this project over two years ago and didn't complete it for different reasons, I've now went back and completed it. Most of the code is still ~2 years old but I did rewrite some parts to make it better and right now it should be good to use with a couple rare minor bugs that I probably didn't find during testing which I'll fix if there's issues created about them.

This resource is created for [ND_Core](https://forum.cfx.re/t/wip-nd-core/4792200?u=andyyy7666) but I might integrate it with ESX and QB in the future if there's any interest.


## Future plans
* Flash officer status if panic button is on
* Create Keybind for panic button, needs to be clicked twice to prevent accidental click
* Create call when panic button is pressed and attach all available officers to the call
* Dismiss calls that are old
* Dispatch panel
* EMS Version

## Create call
```lua
exports["ND_MDT"]:createDispatch({
    caller = "John Doe",
    location = "Sandy shores", -- not required
    callDescription = "Whiteness bank robbery",
    coords = vec3(x, y, z) -- if this is used and location isn't used then it will still display the location from these coords.
})
```

## Inventory item:
```lua
["mdt"] = {
    label = "MDT",
    weight = 800,
    client = {
        export = "ND_MDT.useTablet"
    }
}
```
![mdt](https://github.com/ND-Framework/ND_MDT/assets/86536434/1dcb38e5-4609-401f-97bf-77371fb55466)

## Features:
* General
  * Tablet item with ox_inventory.
  * Create dispatch calls from export in other scripts
  * Officer Live chat
  * Minimize page leaves MDT on same page when reopen
  * Close page resets MDT UI.
* Dashboard
  * Officer status
  * Dispatch calls
  * Auto status change when responding to calls
  * Auto status change when arriving on scene
  * Attaching and detaching from calls
  * Waypoints to calls
  * Panic button with tts
* Name searching
  * View person info
  * View person weapons
  * View person vehicles
  * Create person bolo
  * Create person record (charges & fines)
  * Add notes to person
  * Manage person licenses (driver, weapon, etc)
  * View player properties (ND_Properties needs update soon)
* Plate searching
  * View vehicle info with plate
  * Search owner of vehicle
  * Mark vehicle as stolen
  * Stolen plates integrated with [Wraith ARS 2X](https://github.com/WolfKnight98/wk_wars2x/releases/latest) plate reader.
* Weapon searching
  * Auto registers legal weapons bought from ox_inventory shops
  * Search by serial number
  * Search weapon owner
  * Mark weapon as stolen
* Reports
  * Crime, Traffic, Arrest, Incident, Use of Force reports.
  * Each report has a unique case id, this is so evidence can be placed in ox_inventory evidence lockers.
* Employee management
    * Restricted to boss ranks only
    * Manage employees ranks
    * Manage employees callsigns
    * Fire & hire new employees


## ESX Support by [Maximus7474](https://github.com/Maximus7474)
**IMPORTANT** use the SQL files in `bridge/esx/database` if not the resource will not work.
Still to do:
  * Custom Phone Functions
  * Custom Property Functions
  * Custom Billing Functions
  * Adding a user profile picture to the DB
-> For the time being there is no Default billing system integrated, it is present but commented as esx_billing requires a destination for the money. You can activate it in: `bridge/esx/server.lua:288`


## Video preview:
[![mdt-thumbnail-youtube](https://github.com/ND-Framework/ND_MDT/assets/86536434/7b3df9ad-c205-4fa9-bbe1-9353cfc7c0ca)](https://youtu.be/NcTIdCN4VR0?si=k6OPmumDNQ27_LjO)


