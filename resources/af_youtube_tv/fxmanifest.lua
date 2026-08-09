fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'af_youtube_tv'
description 'Telao 3D YouTube com audio por proximidade e controle do dono'
version '2.0.0'

-- Pagina NUI invisivel para evitar overlay preto em tela cheia.
-- O DUI usa html/index.html diretamente via https://cfx-nui-af_youtube_tv/html/index.html.
ui_page 'html/overlay.html'

files {
    'html/overlay.html',
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

dependency 'vrp'

shared_scripts {
    '@vrp/lib/Utils.lua',
    'config.lua'
}
client_script 'client.lua'
server_script 'server.lua'
