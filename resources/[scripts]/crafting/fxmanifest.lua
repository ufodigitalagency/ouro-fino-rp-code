fx_version "bodacious"
game "gta5"
lua54 "yes"

dependency "oxmysql"
dependency "sao_judas_operations"

client_scripts {
	"@vrp/config/Native.lua",
	"@PolyZone/client.lua",
	"client-side/*"
}

server_scripts {
	"server-side/*"
}

shared_scripts {
	"@vrp/lib/Utils.lua",
	"@vrp/config/Global.lua",
	"@sao_judas_operations/config.lua",
	"shared-side/*"
}
