fx_version "cerulean"
game "gta5"
lua54 "yes"

author "Ouro Fino RP"
description "Rota de aviaozinho exclusiva da faccao Pombal"
version "1.0.0"

dependency "vrp"
dependency "target"
dependency "pombal_finance"

shared_scripts {
    "@vrp/lib/Utils.lua",
    "config.lua"
}

client_script "client.lua"
server_script "server.lua"
