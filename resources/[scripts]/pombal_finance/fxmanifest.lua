fx_version "cerulean"
game "gta5"
lua54 "yes"

dependency "vrp"
dependency "oxmysql"
dependency "target"

shared_scripts {
    "@vrp/lib/Utils.lua",
    "@vrp/config/Global.lua",
    "config.lua"
}

client_script "client.lua"
server_script "server.lua"
