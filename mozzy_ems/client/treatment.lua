--[[
    client/treatment.lua
    Executes a treatment attempt (progress bar + anim) and reports the
    attempt to the server. The server alone decides whether it was correct -
    this file never evaluates medical correctness itself.
]]

MozzyEMS = MozzyEMS or {}
MozzyEMS.Treatment = {}

local function findPatient(callId, patientIndex)
    local activeCall = MozzyEMS.State.activeCalls[callId]
    if not activeCall then return nil end
    return activeCall.patients[patientIndex]
end

--- Plays the treatment's anim (if any) without blocking, so it keeps
--- running underneath a skill check or progress bar. When a patient ped
--- handle is available, faces the player toward it first so "kneel down
--- and treat" actually orients toward the patient instead of whatever
--- direction the player happened to be standing.
local function playTreatmentAnim(def, callId, patientIndex)
    if not def.anim then return end
    local ped = PlayerPedId()

    local patientPed = callId and patientIndex and MozzyEMS.State.peds[callId .. '_' .. patientIndex]
    if patientPed and DoesEntityExist(patientPed) then
        TaskTurnPedToFaceEntity(ped, patientPed, 1000)
        Wait(400) -- give the turn a moment to actually happen before the anim starts
    end

    RequestAnimDict(def.anim.dict)
    local timeout = 0
    while not HasAnimDictLoaded(def.anim.dict) and timeout < 3000 do
        Wait(50)
        timeout = timeout + 50
    end
    if HasAnimDictLoaded(def.anim.dict) then
        TaskPlayAnim(ped, def.anim.dict, def.anim.clip, 8.0, -8.0, -1, 1, 0, false, false, false)
    end
end

function MozzyEMS.Treatment.Perform(callId, patientIndex, treatmentId)
    local def = Config.Treatments[treatmentId]
    if not def then return end

    local success

    if def.isCPR or def.isAED then
        -- CPR/AED get the immersive version: play the anim, then run an
        -- ox_lib WASD skill check (a shrinking-circle minigame) instead of
        -- a flat progress bar. Failing it means the compressions/pad
        -- placement botched - no server event fires, same as cancelling a
        -- normal progress bar.
        playTreatmentAnim(def, callId, patientIndex)
        success = lib.skillCheck({ 'easy', 'easy', 'medium' }, { 'w', 'a', 's', 'd' })
        ClearPedTasks(PlayerPedId())

        if not success then
            lib.notify({
                description = def.isAED and 'Pad placement was off - shock not delivered.' or 'Compressions were off rhythm - try again.',
                type = 'error',
            })
            return
        end
    else
        success = lib.progressCircle({
            duration = def.duration,
            label = def.label .. '...',
            useWhileDead = false,
            canCancel = true,
            disable = { move = true, car = true, combat = true },
            anim = def.anim and { dict = def.anim.dict, clip = def.anim.clip } or nil,
        })

        if not success then return end
    end

    TriggerServerEvent(MozzyEMS.Events.PerformTreatment, {
        callId = callId, patientIndex = patientIndex, treatmentId = treatmentId,
    })
end

RegisterNetEvent(MozzyEMS.Events.VitalsResult, function(data)
    local patient = findPatient(data.callId, data.patientIndex)
    if patient then
        patient.vitals = data.vitals
        patient.consciousness = data.consciousness
        patient.injuries = data.injuries
        patient.state = data.state
    end

    local injuryLines = (data.injuries and #data.injuries > 0) and table.concat(data.injuries, '\n') or 'None visibly apparent'
    local v = data.vitals
    local vitalsText = ('Pulse: %s BPM\nBP: %s/%s\nResp: %s\nSpO2: %s%%\nTemp: %.1f C%s\nConsciousness: %s%s'):format(
        v.pulse, v.bpSys, v.bpDia, v.resp, v.spo2, v.temp or 37.0,
        v.glucose and ('\nGlucose: ' .. v.glucose .. ' mg/dL') or '',
        data.consciousness,
        data.triageTag and ('\nTriage: ' .. string.upper(data.triageTag)) or ''
    )

    lib.alertDialog({
        header = 'Patient Assessment',
        content = ('Visible Injuries:\n%s\n\nVitals:\n%s%s'):format(
            injuryLines, vitalsText,
            data.hint and ('\n\nSuggested Treatments:\n' .. data.hint) or ''
        ),
        centered = true,
        cancel = false,
    })
end)

RegisterNetEvent(MozzyEMS.Events.TreatmentResult, function(result)
    if result.rejected then
        local reasons = {
            missing_item = 'You don\'t have the required item.',
            not_ems = 'You are not on-duty EMS.',
            not_responding = 'You are not assigned to this call.',
            invalid_call = 'That call no longer exists.',
            call_closed = 'That call has already closed.',
            patient_already_resolved = 'This patient has already been resolved.',
        }
        lib.notify({ description = reasons[result.reason] or 'Treatment failed.', type = 'error' })
        return
    end

    if result.treatmentId == 'use_aed' then
        lib.notify({
            title = 'AED',
            description = result.shockAdvised and 'Shock advised - stand clear... SHOCK DELIVERED.' or 'No shockable rhythm detected.',
            type = result.shockAdvised and 'success' or 'inform',
        })
        return
    end

    if result.treatmentId == 'perform_cpr' and result.rosc ~= nil then
        lib.notify({
            title = 'CPR Cycle Complete',
            description = result.rosc and 'Return of spontaneous circulation!' or 'No pulse - continue CPR.',
            type = result.rosc and 'success' or 'inform',
        })
    else
        lib.notify({
            description = result.correct and 'Treatment administered.' or 'That doesn\'t seem to have helped.',
            type = result.correct and 'success' or 'error',
        })
    end

    local patient = findPatient(result.callId, result.patientIndex)
    if patient then
        patient.vitals = result.vitals
        patient.state = result.state
        patient.consciousness = result.consciousness
    end
end)
