fx_version "cerulean"
game "gta5"
lua54 "yes"

author "Ouro Fino Roleplay"
description "Fundacao visual segura do Ouro Fight Club"
version "1.0.0"

dependencies {
	"vrp",
	"target"
}

shared_scripts {
	"@vrp/lib/Utils.lua",
	"config.lua"
}

client_script "client/main.lua"

server_scripts {
	"server/security.lua",
	"server/main.lua"
}

ui_page "html/index.html"

files {
	"html/index.html",
	"html/style.css",
	"html/script.js"
}
