--[[
    client/calls.lua
    Dispatch card UI, accept/decline, blips, and scene spawning trigger.
]]

local function priorityColor(priority)
    return Config.Blips.colorByPriority[priority] or 3
end

local function createCallBlip(call)
    local approximate = Config.Blips.approximateBeforeArrival
    local blip = AddBlipForCoord(call.coords.x, call.coords.y, call.coords.z)
    SetBlipSprite(blip, Config.Blips.sprite)
    SetBlipColour(blip, priorityColor(call.priority))
    SetBlipScale(blip, approximate and 1.1 or 0.9)
    SetBlipAsShortRange(blip, false)
    if approximate then
        SetBlipDisplay(blip, 8)
    end
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(('%s [%s]'):format(call.label, call.dispatchCode))
    EndTextCommandSetBlipName(blip)
    return blip
end

--- Dispatch offer arrives for any on-duty EMS, regardless of whether they end up responding
RegisterNetEvent(MozzyEMS.Events.NewCallOffer, function(call)
    -- No client-side duty re-check here on purpose: the server already
    -- filtered recipients to on-duty EMS via GetOnDutyEMSSources() before
    -- sending this event. Re-checking against the client's cached
    -- PlayerData was a second point of failure - a stale cache (e.g. duty
    -- toggled right before this arrived) could silently eat the offer with
    -- no error shown anywhere.
    MozzyEMS.State.offeredCalls[call.id] = call

    lib.notify({
        title = ('EMS DISPATCH - %s'):format(call.dispatchCode),
        description = ('Priority %d: %s\n%s'):format(call.priority, call.label, call.narrative),
        type = 'inform',
        duration = 12000,
        position = 'top',
    })

    lib.registerContext({
        id = 'mozzy_ems_offer_' .. call.id,
        title = call.label .. ' - ' .. call.dispatchCode,
        options = {
            {
                title = 'Accept Call',
                description = call.narrative,
                icon = 'truck-medical',
                onSelect = function()
                    TriggerServerEvent(MozzyEMS.Events.CallAccepted, call.id)
                end,
            },
            {
                title = 'Decline',
                icon = 'xmark',
                onSelect = function()
                    TriggerServerEvent(MozzyEMS.Events.CallDeclined, call.id)
                    MozzyEMS.State.offeredCalls[call.id] = nil
                end,
            },
        },
    })
    lib.showContext('mozzy_ems_offer_' .. call.id)
end)

--- Server confirms our accept and hands us everything needed to build the scene
RegisterNetEvent(MozzyEMS.Events.SpawnScene, function(data)
    local call = data.call
    MozzyEMS.State.offeredCalls[call.id] = nil
    MozzyEMS.State.activeCalls[call.id] = { call = call, patients = {}, arrived = false, bystanderLines = data.bystanderLines }

    if MozzyEMS.State.blips[call.id] then RemoveBlip(MozzyEMS.State.blips[call.id]) end
    MozzyEMS.State.blips[call.id] = createCallBlip(call)

    SetNewWaypoint(call.coords.x, call.coords.y)

    for _, p in ipairs(data.patients) do
        MozzyEMS.State.activeCalls[call.id].patients[p.index] = p
    end

    MozzyEMS.Patients.SpawnScene(call.id, call.coords, data.patients, data.scene)

    lib.notify({
        title = 'Call Accepted',
        description = 'GPS route set. Head to the scene.',
        type = 'success',
    })
end)

--- Arrival detection: once close enough to scene coords, tell the server
--- (used for response-time scoring) and reveal the exact blip.
CreateThread(function()
    while true do
        Wait(1500)
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)

        for callId, data in pairs(MozzyEMS.State.activeCalls) do
            if not data.arrived then
                local dist = #(coords - vector3(data.call.coords.x, data.call.coords.y, data.call.coords.z))
                if dist <= Config.Blips.revealDistance then
                    data.arrived = true
                    TriggerServerEvent(MozzyEMS.Events.ArrivedOnScene, callId)
                    if MozzyEMS.State.blips[callId] then
                        SetBlipDisplay(MozzyEMS.State.blips[callId], 2)
                        SetBlipScale(MozzyEMS.State.blips[callId], 0.9)
                    end
                end
            end
        end
    end
end)

RegisterNetEvent(MozzyEMS.Events.PatientStateUpdate, function(data)
    local activeCall = MozzyEMS.State.activeCalls[data.callId]
    if not activeCall then return end
    local patient = activeCall.patients[data.patientIndex]
    if not patient then return end
    patient.state = data.state
    patient.consciousness = data.consciousness
    patient.vitals = data.vitals
end)

-- Response to MozzyEMS.Events.RequestActiveCalls (not currently called from
-- anywhere in this build, but kept wired up for any future UI/command that
-- wants a full active-call list without having gone through SpawnScene).
RegisterNetEvent(MozzyEMS.Events.SyncActiveCalls, function(summaries)
    MozzyEMS.State.syncedCalls = summaries
end)
