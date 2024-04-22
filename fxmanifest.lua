-- For support join my discord: https://discord.gg/Z9Mxu72zZ6

author "Andyyy7666"
description "ND Framework MDT For LEO and FIRE"
version "1.1.0"

fx_version "cerulean"
game "gta5"
lua54 "yes"

files {
	"ui/index.html",
	"ui/script.js",
	"ui/style.css",
    "ui/user.jpg",
    "config/translate.json",
    "config/charges.json",
    "bridge/**/client.lua",
    "modules/**/client.lua"
}

ui_page "ui/index.html"

shared_scripts {
    "@ox_lib/init.lua",
    "config/config.lua",
    "config/charges.json",
    "bridge/**/shared.lua",
    "source/shared.lua"
}
server_scripts {
    "@oxmysql/lib/MySQL.lua",
    "source/server.lua"
}
client_scripts {
    "source/client.lua"
}

dependencies {
    "oxmysql",
    "ox_inventory",
    "ox_lib"
}
