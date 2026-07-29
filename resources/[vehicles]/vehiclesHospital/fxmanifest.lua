shared_script "@ThnAC/natives.lua"
fx_version 'bodacious'
games { 'rdr3', 'gta5' }

author 'Cauã#0999'
description 'Viaturas - Para o Servidor CLOUD'

files {

	'handling.meta',
    'vehicles.meta',
    'carcols.meta',
    'carvariations.meta',

}

client_script "tuning.lua"

data_file 'HANDLING_FILE' 'handling.meta'
data_file 'VEHICLE_METADATA_FILE' 'vehicles.meta'
data_file "CARCOLS_FILE" "carcols.meta"
data_file "VEHICLE_VARIATION_FILE" "carvariations.meta"


