fx_version "cerulean"
game "gta5"
lua54 "yes"

dependencies {
    "vrp",
    "oxmysql",
    "inventory",
    "keyboard",
    "target",
    "safezone",
    "sao_judas_operations"
}

shared_scripts {
    "@vrp/lib/Utils.lua",
    "@vrp/config/Global.lua",
    "config.lua"
}

client_script "client.lua"
server_script "server.lua"
