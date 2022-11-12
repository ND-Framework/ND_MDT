-- For support join my discord: https://discord.gg/Z9Mxu72zZ6

author "Andyyy#7666"
description "ND Framework MDT For LEO and FIRE"
version "1.0"

fx_version "cerulean"
game "gta5"
lua54 "yes"

files {
	"source/index.html",
	"source/script.js",
	"source/style.css",
    "source/user.jpg"
}

ui_page "source/index.html"

shared_scripts {
    "@ox_lib/init.lua",
    "config.lua"
}
server_scripts {
    "@oxmysql/lib/MySQL.lua",
    "source/server.lua"
}
client_scripts {
    "source/client.lua"
}