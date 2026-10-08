--[[
    Config.CallLocations - unlimited configurable spawn points for simulator
    calls. Each entry:
        id             unique string
        coords         vec4 (x, y, z, heading)
        category       one of Config.LocationCategories below - used to
                        restrict scenario types to realistic places
        allowedCalls   optional explicit whitelist of call type ids. If
                        omitted, any call type whose `locations` list
                        contains this entry's `category` may spawn here.
        radius         optional wander/prop scatter radius (meters)

    This is a starter set spread across Los Santos / Blaine County using
    the categories referenced by config/calls.lua. Add as many as you like -
    nothing else needs to change.
]]

Config.LocationCategories = {
    'residential', 'commercial', 'alley', 'highway', 'beach', 'mountain',
    'bar', 'club', 'gas_station', 'industrial', 'rural', 'apartment',
    'parking_lot', 'water',
}

Config.CallLocations = {
    { id = 'strawberry_alley_01', coords = vec4(101.8, -1946.6, 20.8, 210.0), category = 'alley', radius = 6.0 },
    { id = 'legion_square_01',    coords = vector4(47.71, -607.52, 31.63, 43.29), category = 'commercial', radius = 8.0 },
    { id = 'davis_residential_01',coords = vector4(325.34, -2025.94, 20.97, 192.09), category = 'residential', radius = 6.0 },
    { id = 'vespucci_beach_01',   coords = vec4(-1194.9, -1531.8, 4.3, 300.0), category = 'beach', radius = 10.0 },
    { id = 'vinewood_apts_01',    coords = vector4(-774.64, 304.86, 85.71, 9.58), category = 'apartment', radius = 5.0 },
    { id = 'lsia_parking_01',     coords = vector4(-1030.23, -2733.49, 13.76, 357.36), category = 'parking_lot', radius = 8.0 },
    { id = 'del_perro_freeway_01',coords = vec4(-1350.0, -450.0, 35.0, 45.0), category = 'highway', radius = 12.0 },
    { id = 'rancho_industrial_01',coords = vector4(789.59, -822.74, 26.29, 148.24), category = 'industrial', radius = 8.0 },
    { id = 'sandy_gas_01',        coords = vector4(1822.0, 3831.84, 33.5, 16.01), category = 'gas_station', radius = 6.0 },
    { id = 'grapeseed_rural_01',  coords = vec4(2427.9, 4610.9, 38.1, 40.0), category = 'rural', radius = 10.0 },
    { id = 'chiliad_mountain_01', coords = vec4(501.98, 5604.4, 796.7, 300.0), category = 'mountain', radius = 15.0 },
    { id = 'tequila_club_01',     coords = vector4(138.25, -1301.81, 29.18, 129.11), category = 'club', radius = 6.0 },
    { id = 'yellowjack_bar_01',   coords = vec4(1996.9, 3050.8, 47.2, 210.0), category = 'bar', radius = 6.0 },
    { id = 'alamo_sea_01',        coords = vector4(1736.35, 3283.16, 41.12, 315.52), category = 'water', radius = 10.0 },
    { id = 'paleto_residential_01',coords = vector4(-184.73, 6325.24, 31.48, 144.05), category = 'residential', radius = 6.0 },
    { id = 'mirror_park_01',      coords = vec4(1120.3, -469.9, 66.0, 210.0), category = 'residential', radius = 6.0 },
}
