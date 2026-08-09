fx_version "cerulean"
game "gta5"

author "Ouro Fino RP - selective extraction from Quebrada SHOP package"
description "Assets compartilhados pelos mapas das favelas Pombal e São Judas."

dependency "vrp"

shared_script "config.lua"

client_script "client.lua"

server_scripts {
    "@vrp/lib/utils.lua",
    "server.lua"
}

files {
    "stream/**/*.ytyp"
}

data_file "DLC_ITYP_REQUEST" "stream/**/*.ytyp"
