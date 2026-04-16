fx_version 'cerulean'

file "@SecureServe/secureserve.key"
game 'gta5'

shared_script "@SecureServe/src/module/module.lua"
shared_script "@SecureServe/src/module/module.js"
file           "@SecureServe/secureserve.key"

author      'gc-scripts'
description 'gc-valet — NPC Delivery, Vehicle Tracking, Admin Impound'
version     '2.0.0'

client_scripts {
    'client/client.lua',
    'client/impound.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua',
    'server/impound.lua',
}

dependencies {
    'ox_lib',
    'qb-core',
    'oxmysql',
}
