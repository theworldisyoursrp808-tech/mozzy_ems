--[[
    server/treatment.lua (server-only)
    Every treatment the client requests is validated here before anything
    happens to a patient. Nothing about "did the treatment work" is ever
    decided client-side.
]]

MozzyEMS = MozzyEMS or {}
MozzyEMS.Treatment = {}

local Utils = MozzyEMS.Utils
local PatientState = MozzyEMS.PatientState

local function getCallAndPatient(callId, patientIndex)
    local call = MozzyEMS.Calls.Get(callId)
    if not call then return nil, nil end
    local patient = call.patients[patientIndex]
    if not patient then return nil, nil end
    return call, patient
end

local function isResponderOnCall(call, source)
    return call.responders[source] == true
end

--- Central entry point, bound to MozzyEMS.Events.PerformTreatment
--- payload: { callId, patientIndex, treatmentId }
function MozzyEMS.Treatment.Handle(source, payload)    if type(payload) ~= 'table' then return end
    local callId, patientIndex, treatmentId = payload.callId, payload.patientIndex, payload.treatmentId

    if not MozzyEMS.Framework.CanWorkEMS(source) then
        return MozzyEMS.Treatment.Reject(source, 'not_ems')
    end

    local call, patient = getCallAndPatient(callId, patientIndex)
    if not call or not patient then
        return MozzyEMS.Treatment.Reject(source, 'invalid_call')
    end

    if not isResponderOnCall(call, source) then
        return MozzyEMS.Treatment.Reject(source, 'not_responding')
    end

    if call.state == MozzyEMS.CallState.COMPLETED or call.state == MozzyEMS.CallState.CANCELLED
        or call.state == MozzyEMS.CallState.EXPIRED then
        return MozzyEMS.Treatment.Reject(source, 'call_closed')
    end

    if patient.outcome then
        return MozzyEMS.Treatment.Reject(source, 'patient_already_resolved')
    end

    local treatmentDef = Config.Treatments[treatmentId]
    if not treatmentDef then
        return MozzyEMS.Treatment.Reject(source, 'unknown_treatment', true) -- exploit-worthy
    end

    -- CPR / AED go through the resuscitation-specific path
    if treatmentDef.isCPR then
        return MozzyEMS.Treatment.HandleCPR(source, call, patient)
    end
    if treatmentDef.isAED then
        return MozzyEMS.Treatment.HandleAED(source, call, patient)
    end

    -- item validation (server-side truth, never trusts the client)
    local itemOk, itemErr = MozzyEMS.Inventory.ValidateAndConsume(source, treatmentDef.item)
    if not itemOk then
        return MozzyEMS.Treatment.Reject(source, itemErr or 'missing_item')
    end

    local realConfig = call.realConfig
    local isCorrect = realConfig.validTreatments and realConfig.validTreatments[treatmentId] == true

    if isCorrect then
        MozzyEMS.Patients.ApplyTreatmentEffect(patient, treatmentId, realConfig)
        patient.correctTreatments = patient.correctTreatments + 1
        MozzyEMS.Patients.CheckStabilization(patient, realConfig)
    else
        patient.incorrectTreatments = patient.incorrectTreatments + 1
        local diffSettings = patient.difficultySettings
        if math.random() < (diffSettings.complicationChance or 0.15) then
            -- wrong treatment causes a minor complication rather than doing nothing
            patient.vitals.spo2 = Utils.Clamp(patient.vitals.spo2 - 3, 0, 100)
            patient.vitals.pulse = patient.vitals.pulse + 4
        end
    end

    MozzyEMS.Calls.SyncPatient(call, patient)

    TriggerClientEvent(MozzyEMS.Events.TreatmentResult, source, {
        callId = callId, patientIndex = patientIndex, treatmentId = treatmentId,
        correct = isCorrect, vitals = patient.vitals, state = patient.state,
        consciousness = patient.consciousness,
    })
end

-- This is the missing link that makes MozzyEMS.Treatment.Handle actually
-- run: without it, every treatment attempt from the client silently went
-- nowhere - no vitals change, no feedback, nothing.
RegisterNetEvent(MozzyEMS.Events.PerformTreatment, function(payload)
    MozzyEMS.Treatment.Handle(source, payload)
end)

function MozzyEMS.Treatment.Reject(source, reason, suspicious)
    TriggerClientEvent(MozzyEMS.Events.TreatmentResult, source, { rejected = true, reason = reason })
    if suspicious and Config.Webhook.enabled and Config.Webhook.events.exploitAttempt then
        MozzyEMS.Webhook.Send('exploitAttempt', ('Player %s sent an invalid treatment payload (%s)'):format(source, reason))
    end
end

-----------------------------------------------------------------------------
-- CPR
-----------------------------------------------------------------------------

function MozzyEMS.Treatment.HandleCPR(source, call, patient)
    local realConfig = call.realConfig
    local res = realConfig.resuscitation

    if patient.state ~= PatientState.CARDIAC_ARREST then
        -- CPR outside cardiac arrest is a no-op correct-ish action for
        -- calls that list it (e.g. severe trauma) - treat via generic path
        MozzyEMS.Patients.ApplyTreatmentEffect(patient, 'perform_cpr', realConfig)
        patient.correctTreatments = patient.correctTreatments + 1
        MozzyEMS.Patients.CheckStabilization(patient, realConfig)
        MozzyEMS.Calls.SyncPatient(call, patient)
        return TriggerClientEvent(MozzyEMS.Events.TreatmentResult, source, {
            callId = call.id, patientIndex = patient.index, treatmentId = 'perform_cpr',
            correct = true, vitals = patient.vitals, state = patient.state, consciousness = patient.consciousness,
        })
    end

    if not res then
        return MozzyEMS.Treatment.Reject(source, 'no_resuscitation_config')
    end

    patient.cprCycles = patient.cprCycles + 1
    local chance = (res.roscBaseChance or 15) + ((res.roscPerCPRCycle or 8) * (patient.cprCycles - 1))
    if patient.aedShocked and patient.aedShocked > 0 then
        chance = chance + (15 * patient.aedShocked) -- each delivered shock meaningfully boosts the next cycle
        patient.aedShocked = 0
    end
    local rosc = math.random(1, 100) <= chance

    if rosc then
        patient.state = PatientState.UNCONSCIOUS
        patient.consciousness = MozzyEMS.Consciousness.PAIN
        patient.vitals.pulse = Utils.RandomInt(70, 95)
        patient.vitals.resp = Utils.RandomInt(10, 16)
        patient.vitals.bpSys = Utils.RandomInt(85, 105)
        patient.vitals.bpDia = Utils.RandomInt(55, 70)
        patient.vitals.spo2 = Utils.RandomInt(80, 88)
        patient.resuscitated = true
    elseif res.maxCycles and patient.cprCycles >= res.maxCycles then
        patient.state = PatientState.DECEASED
        patient.outcome = 'deceased'
    end

    MozzyEMS.Calls.SyncPatient(call, patient)
    TriggerClientEvent(MozzyEMS.Events.TreatmentResult, source, {
        callId = call.id, patientIndex = patient.index, treatmentId = 'perform_cpr',
        correct = true, rosc = rosc, cprCycles = patient.cprCycles,
        vitals = patient.vitals, state = patient.state, consciousness = patient.consciousness,
    })
end

-----------------------------------------------------------------------------
-- AED
-----------------------------------------------------------------------------

function MozzyEMS.Treatment.HandleAED(source, call, patient)
    local realConfig = call.realConfig
    local res = realConfig.resuscitation

    local itemOk, itemErr = MozzyEMS.Inventory.ValidateAndConsume(source, Config.Treatments.use_aed.item)
    if not itemOk then
        return MozzyEMS.Treatment.Reject(source, itemErr or 'missing_item')
    end

    if patient.state ~= PatientState.CARDIAC_ARREST or not res then
        -- shock advised only in cardiac arrest with a shockable config
        return TriggerClientEvent(MozzyEMS.Events.TreatmentResult, source, {
            callId = call.id, patientIndex = patient.index, treatmentId = 'use_aed',
            correct = false, shockAdvised = false, vitals = patient.vitals, state = patient.state,
        })
    end

    local shockable = res.aedShockable
    if not shockable then
        return TriggerClientEvent(MozzyEMS.Events.TreatmentResult, source, {
            callId = call.id, patientIndex = patient.index, treatmentId = 'use_aed',
            correct = true, shockAdvised = false, vitals = patient.vitals, state = patient.state,
        })
    end

    -- a shock roughly doubles the effective chance of the NEXT CPR cycle's ROSC
    patient.aedShocked = (patient.aedShocked or 0) + 1

    TriggerClientEvent(MozzyEMS.Events.TreatmentResult, source, {
        callId = call.id, patientIndex = patient.index, treatmentId = 'use_aed',
        correct = true, shockAdvised = true, vitals = patient.vitals, state = patient.state,
    })
end
