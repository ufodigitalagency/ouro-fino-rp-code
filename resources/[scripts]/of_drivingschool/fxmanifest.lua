fx_version "cerulean"
game "gta5"
lua54 "yes"

author "Ouro Fino RP"
description "Fundacao persistente do sistema de CNH e autoescola"
version "0.1.0"

dependency "vrp"

shared_scripts {
    "@vrp/lib/Utils.lua",
    "config.lua"
}

client_script "client.lua"

server_script "server.lua"
