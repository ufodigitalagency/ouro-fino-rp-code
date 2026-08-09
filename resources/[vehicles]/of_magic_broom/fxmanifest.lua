fx_version "cerulean"
game "gta5"
lua54 "yes"

author "Sg_Mods / Ouro Fino RP integration"
description "Nimbus 2016 v1.2 converted to a private FiveM add-on"
version "1.0.0"

files {
	"data/vehicles.meta",
	"data/carvariations.meta"
}

data_file "VEHICLE_METADATA_FILE" "data/vehicles.meta"
data_file "VEHICLE_VARIATION_FILE" "data/carvariations.meta"

client_script "vehicle_names.lua"
