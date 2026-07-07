fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'all-sulli'
description 'Vehicle Browser & Tuner - Version Complète'
version '1.5.0'

ui_page 'html/index.html'

shared_script 'config.lua'

-- Dépendances
dependencies {
    'oxmysql',
}

-- Scripts serveur
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

-- Scripts client
client_scripts {
    'client/colors.lua',
    'client/main.lua'
}

-- Fichiers UI
files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}
