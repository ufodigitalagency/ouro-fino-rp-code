fx_version "bodacious"
game "gta5"
lua54 "yes"

dependency "pombal_finance"

ui_page "web-side/index.html"

client_scripts {
	"@vrp/config/Native.lua",
	"@PolyZone/client.lua",
	"client-side/*.lua"
}

server_scripts {
	"server-side/*.lua",
	"lockpick-server/core.lua"
}

files {
	"web-side/*"
}

shared_scripts {
	"@vrp/lib/Utils.lua",
	"@vrp/config/Global.lua",
	"shared-side/*.lua"
}
