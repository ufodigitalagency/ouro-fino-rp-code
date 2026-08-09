fx_version "cerulean"
game "gta5"
lua54 "yes"

author "AF"
description "Vassoura magica exclusiva e sincronizada - Ouro Fino Roleplay"
version "1.0.0"

dependency "vrp"
dependency "of_magic_broom"
dependency "of_broom_proxy"

ui_page "html/index.html"

shared_scripts {
	"@vrp/lib/Utils.lua",
	"@vrp/config/Global.lua",
	"config.lua"
}

client_script "client.lua"
server_script "server.lua"

files {
	"html/index.html",
	"html/style.css",
	"html/app.js"
}
