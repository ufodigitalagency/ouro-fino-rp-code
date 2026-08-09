fx_version "cerulean"
game "gta5"
lua54 "yes"

author "AF"
description "Habilidade de vampiro validada pelo servidor para Ouro Fino Roleplay"
version "1.0.0"

shared_scripts {
	"@vrp/lib/Utils.lua",
	"@vrp/config/Global.lua",
	"config.lua"
}

client_script "client.lua"
server_script "server.lua"

files {
	"html/vampire_hud.html",
	"html/vampire_hud.css",
	"html/vampire_hud.js"
}
