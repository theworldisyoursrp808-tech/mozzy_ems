fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'Mozzy EMS Simulator'
description 'Advanced Dynamic EMS Call & Patient Simulation System for Qbox'
author 'Mozzy'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/constants.lua',
    'shared/utils.lua',
    'config/shared.lua',
    'config/items.lua',
    'config/hospitals.lua',
    'config/locations.lua',
    'config/treatments.lua',
    'config/calls.lua',
    'config/real_calls.lua',
}

client_scripts {
    'bridge/framework.lua',
    'bridge/dispatch.lua',
    'bridge/medical.lua',
    'bridge/wasabi_ambulance.lua',
    'client/main.lua',
    'client/calls.lua',
    'client/real_calls.lua',
    'client/patients.lua',
    'client/target.lua',
    'client/treatment.lua',
    'client/transport.lua',
    'client/admin.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/framework.lua',
    'bridge/dispatch.lua',
    'bridge/medical.lua',
    'bridge/inventory.lua',
    'bridge/wasabi_ambulance.lua',
    'server/database.lua',
    'server/main.lua',
    'server/patients.lua',
    'server/treatment.lua',
    'server/rewards.lua',
    'server/calls.lua',
    'server/real_calls.lua',
}

files {
    'locales/*.json',
}

dependencies {
    'qbx_core',
    'ox_lib',
    'ox_inventory',
    'ox_target',
    'oxmysql',
}

provide 'mozzy_ems'
