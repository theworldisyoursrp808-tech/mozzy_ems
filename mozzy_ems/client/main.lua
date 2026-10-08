--[[
    client/main.lua
    Local runtime state cache. Nothing here is authoritative - it exists so
    the UI/target modules have something fast to read. The server is always
    the source of truth and can correct any of this via sync events.
]]

MozzyEMS = MozzyEMS or {}
MozzyEMS.State = {
    offeredCalls = {},   -- [callId] = dispatch card data, not yet accepted
    activeCalls = {},    -- [callId] = { call, patients = { [index] = {...} } }
    peds = {},           -- [callId .. '_' .. index] = ped entity handle
    blips = {},          -- [callId] = blip handle
    carrying = nil,      -- { callId, patientIndex } while a patient is loaded for transport
}

local function debugPrint(...)
    if not Config.Debug then return end
    print('^3[mozzy_ems]^7', ...)
end
MozzyEMS.DebugPrint = debugPrint

RegisterNetEvent(MozzyEMS.Events.CleanupScene, function(callId)
    MozzyEMS.Patients.DespawnAll(callId)
    if MozzyEMS.State.blips[callId] then
        RemoveBlip(MozzyEMS.State.blips[callId])
        MozzyEMS.State.blips[callId] = nil
    end
    MozzyEMS.State.activeCalls[callId] = nil
    MozzyEMS.State.offeredCalls[callId] = nil
    if MozzyEMS.State.carrying and MozzyEMS.State.carrying.callId == callId then
        MozzyEMS.State.carrying = nil
    end
end)

RegisterNetEvent(MozzyEMS.Events.CallRemoved, function(callId)
    MozzyEMS.State.offeredCalls[callId] = nil
    if MozzyEMS.State.blips[callId] and not MozzyEMS.State.activeCalls[callId] then
        RemoveBlip(MozzyEMS.State.blips[callId])
        MozzyEMS.State.blips[callId] = nil
    end
end)

RegisterNetEvent(MozzyEMS.Events.CallComplete, function(result)
    -- Deliberately NOT clearing MozzyEMS.State.activeCalls[result.callId]
    -- here: on a multi-patient call, CallComplete fires once per patient as
    -- each one resolves (server/rewards.lua pays out per-patient), while
    -- other patients on the same call may still be actively being treated.
    -- Tearing down the call's client-side state is CleanupScene's job -
    -- that only fires once every patient on the call is resolved.
    local lines = {
        ('Outcome: **%s**'):format(result.outcome == 'deceased' and 'Patient Deceased' or 'Patient Stabilized'),
        ('Response Time: %s'):format(MozzyEMS.Utils.FormatDuration(result.responseTime or 0)),
        ('Correct Treatments: %d'):format(result.correctTreatments or 0),
        ('Incorrect Treatments: %d'):format(result.incorrectTreatments or 0),
        ('Transported: %s'):format(result.transported and 'Yes' or 'No'),
        ('Payment: $%d'):format(result.money or 0),
        ('XP: +%d'):format(result.xp or 0),
    }

    lib.notify({
        title = 'CALL COMPLETE',
        description = table.concat(lines, '\n'),
        type = result.outcome == 'deceased' and 'error' or 'success',
        duration = 9000,
    })
end)
