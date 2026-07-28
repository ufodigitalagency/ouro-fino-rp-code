fx_version "bodacious"
game "gta5"
lua54 "yes"

client_scripts {
    "@vrp/lib/Utils.lua",
    "eleven.lua",
    "jobs/lixeiro/client.lua",
    "jobs/minerador/client.lua",
    "jobs/eletricista/client.lua",
    "jobs/rotas/client.lua"
}

server_scripts {
    "@vrp/lib/Utils.lua",
    "dustin.lua",
    "jobs/lixeiro/server.lua",
    "jobs/minerador/server.lua",
    "jobs/eletricista/server.lua",
    "jobs/rotas/server.lua"
}

shared_scripts {
    "config.lua"
}

files {
    "web-side/*",
    "web-side/**/*"
}

ui_page "web-side/index.html"
