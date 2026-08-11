fx_version "cerulean"
game "gta5"
lua54 "yes"

author "Ouro Fino RP"
description "Fundacao operacional do sistema de CNH e autoescola"
version "0.2.0"

dependency "vrp"
dependency "target"

shared_scripts {
    "@vrp/lib/Utils.lua",
    "config.lua"
}

client_script "client.lua"

server_script "server.lua"

ui_page "web/index.html"

files {
    "web/index.html",
    "web/style.css",
    "web/script.js"
}
