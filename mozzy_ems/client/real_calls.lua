--[[
    client/real_calls.lua
    Dispatch card + blip/waypoint + outcome toast for real-player calls
    (server/real_calls.lua). Deliberately separate from client/calls.lua's
    NPC dispatch card/event names - see bridge/wasabi_ambulance.lua for why.
    The actual revive/treat work happens in wasabi_ambulance's own UI once
    you reach the patient; this file only handles the dispatch/scoring
    wrapper around it.
]]

local REAL_OFFER_EVENT    = 'mozzy_ems:real:offer'
local REAL_ACCEPT_EVENT   = 'mozzy_ems:real:accept'
local REAL_ACCEPTED_EVENT = 'mozzy_ems:real:accepted'
local REAL_CLOSED_EVENT   = 'mozzy_ems:real:closed'
local REAL_COMPLETE_EVENT = 'mozzy_ems:real:complete'

local realBlips = {} -- [callId] = blip handle

local function clearRealBlip(callId)
    if realBlips[callId] then
        RemoveBlip(realBlips[callId])
        realBlips[callId] = nil
    end
end

RegisterNetEvent(REAL_OFFER_EVENT, function(call)
    lib.notify({
        title = ('EMS DISPATCH - %s'):format(call.dispatchCode),
        description = call.label,
        type = 'inform',
        duration = 12000,
        position = 'top',
    })

    lib.registerContext({
        id = 'mozzy_ems_real_offer_' .. call.id,
        title = call.label .. ' - ' .. call.dispatchCode,
        options = {
            {
                title = 'Respond',
                description = 'Head to the reported location.',
                icon = 'truck-medical',
                onSelect = function()
                    TriggerServerEvent(REAL_ACCEPT_EVENT, call.id)
                end,
            },
            {
                title = 'Ignore',
                icon = 'xmark',
            },
        },
    })
    lib.showContext('mozzy_ems_real_offer_' .. call.id)
end)

RegisterNetEvent(REAL_ACCEPTED_EVENT, function(data)
    clearRealBlip(data.callId)

    local blip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
    SetBlipSprite(blip, Config.Blips and Config.Blips.sprite or 61)
    SetBlipColour(blip, Config.Blips and Config.Blips.colorByPriority and Config.Blips.colorByPriority[1] or 1)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(('%s [%s]'):format(data.label, data.dispatchCode))
    EndTextCommandSetBlipName(blip)
    realBlips[data.callId] = blip

    SetNewWaypoint(data.coords.x, data.coords.y)

    lib.notify({
        title = 'Responding',
        description = 'GPS route set. Treat and revive the patient once you reach them.',
        type = 'success',
    })
end)

RegisterNetEvent(REAL_CLOSED_EVENT, function(callId)
    clearRealBlip(callId)
end)

RegisterNetEvent(REAL_COMPLETE_EVENT, function(data)
    clearRealBlip(data.callId)
    lib.notify({
        title = 'Patient Stabilized',
        description = ('%s - $%d, +%d XP (%s response time)'):format(
            data.targetName, data.money, data.xp, MozzyEMS.Utils.FormatDuration(data.responseTime)),
        type = 'success',
        duration = 8000,
    })
end)
