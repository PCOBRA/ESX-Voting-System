fx_version 'cerulean'
game 'gta5'

author 'PinCobra'
description 'ESX Voting System'
version '1.1'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

files {
    'html/index.html',
    'html/sounds/hover.mp3',
    'html/sounds/select.mp3'
}

ui_page 'html/index.html'


lua54 'yes'
