fx_version "cerulean"
game "gta5"

author "AF / Nation adaptado para Ouro Fino"
description "Concessionaria com painel /conce adaptada para Creative vRP"
version "1.0.0"

ui_page "nui/index.html"

client_scripts {
	"@vrp/lib/utils.lua",
	"client_config.lua",
	"client.lua"
}

server_scripts {
	"@vrp/lib/utils.lua",
	"config.lua",
	"server.lua"
}

files {
	"nui/index.html",
	"nui/script.js",
	"nui/close-fix.js",
	"nui/style.css",
	"nui/images/*.png",
	"nui/fonts/*.ttf",
	"nui/fonts/*.otf",
	"vrp_images/*.png",
	"vrp_images/*.jpg",
	"vrp_images/*.jpeg",
	"vrp_images/*.gif",
	"vrp_images/*.webp"
}
