fx_version "cerulean"
game "gta5"
lua54 "yes"

author "Ouro Fino RP"
description "Emprego de motorista de onibus integrado ao vRP Creative"
version "1.0.0"

dependency "vrp"
dependency "target"

shared_scripts {
    "@vrp/lib/Utils.lua",
    "config.lua"
}

client_script "client.lua"
server_script "server.lua"
