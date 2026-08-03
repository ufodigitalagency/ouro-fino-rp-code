fx_version "cerulean"
game "gta5"
lua54 "yes"

author "AF"
description "Painel administrativo do dono - Ouro Fino Roleplay"
version "1.0.0"

ui_page "html/index.html"

files {
    "html/index.html",
    "html/style.css",
    "html/script.js"
}

shared_script "@vrp/lib/Utils.lua"

client_scripts {
    "client.lua"
}

server_scripts {
    "@vrp/config/Global.lua",
    "@oxmysql/lib/MySQL.lua",
    "server.lua"
}
