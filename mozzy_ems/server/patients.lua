--[[
    server/patients.lua (server-only)
    Generic patient runtime engine. This file has ZERO knowledge of any
    specific medical condition - everything it does is driven by the call's
    config table (config/calls.lua). This is what lets 20+ scenarios exist
    as pure data.
]]

MozzyEMS = MozzyEMS or {}
MozzyEMS.Patients = {}

local Utils = MozzyEMS.Utils
local PatientState = MozzyEMS.PatientState
local Consciousness = MozzyEMS.Consciousness

local function rollRange(range)
    if not range then return nil end
    return Utils.RandomInt(range[1] or range.min, range[2] or range.max)
end

--- Resolves a call type id to its config, following the mystery-pool
--- indirection for calls flagged `mystery = true`. Returns:
---   displayConfig  - what dispatch/UI should show (label, dispatchCode, symptoms)
---   realConfig     - what actually drives vitals/treatment (may be the same table)
---   realType       - resolved underlying call type id
function MozzyEMS.Patients.ResolveCallConfig(callType)
    local cfg = Config.Calls[callType]
    if not cfg then return nil end

    if cfg.mystery and cfg.mysteryPool and #cfg.mysteryPool > 0 then
        local realType = Utils.RandomElement(cfg.mysteryPool)
        local realCfg = Config.Calls[realType]
        if realCfg then
            return cfg, realCfg, realType
        end
    end

    return cfg, cfg, callType
end

--- Builds a fresh patient runtime object from a resolved config.
function MozzyEMS.Patients.Create(index, displayConfig, realConfig, realType, difficulty)
    local diffSettings = Config.DifficultySettings[difficulty] or Config.DifficultySettings.normal

    local vitals = {
        pulse = rollRange(realConfig.vitals.pulse) or 80,
        bpSys = rollRange(realConfig.vitals.bpSys) or 120,
        bpDia = rollRange(realConfig.vitals.bpDia) or 80,
        resp  = rollRange(realConfig.vitals.resp) or 16,
        spo2  = rollRange(realConfig.vitals.spo2) or 97,
        temp  = realConfig.vitals.temp and Utils.RandomFloat(realConfig.vitals.temp[1], realConfig.vitals.temp[2], 1) or 37.0,
        glucose = realConfig.vitals.glucose and rollRange(realConfig.vitals.glucose) or nil,
    }

    local injuries = {}
    if realConfig.injuries and #realConfig.injuries > 0 then
        local count = Utils.Clamp(Utils.RandomInt(realConfig.injuryCount.min, realConfig.injuryCount.max), 1, #realConfig.injuries)
        local pool = Utils.ShallowCopy(realConfig.injuries)
        for _ = 1, count do
            if #pool == 0 then break end
            local i = math.random(1, #pool)
            table.insert(injuries, pool[i])
            table.remove(pool, i)
        end
    end

    local consciousRoll = math.random(1, 100)
    local consciousness = Consciousness.UNRESPONSIVE
    local state = PatientState.UNCONSCIOUS
    local isCardiacArrest = false

    if realConfig.ped.cardiacArrestChance and math.random(1, 100) <= realConfig.ped.cardiacArrestChance then
        isCardiacArrest = true
        state = PatientState.CARDIAC_ARREST
        consciousness = Consciousness.UNRESPONSIVE
        vitals.pulse, vitals.resp, vitals.bpSys, vitals.bpDia = 0, 0, 0, 0
    elseif consciousRoll <= (realConfig.ped.consciousChance or 50) then
        consciousness = Consciousness.ALERT
        state = PatientState.CONSCIOUS
    else
        consciousness = Consciousness.PAIN
        state = PatientState.UNCONSCIOUS
    end

    return {
        index = index,
        realType = realType,
        displayLabel = displayConfig.label,
        hidden = displayConfig.hidden or false,
        model = Utils.RandomElement(realConfig.ped.models),
        animation = realConfig.ped.animation,
        netId = nil, -- set once the client reports the spawned ped
        state = state,
        consciousness = consciousness,
        vitals = vitals,
        injuries = injuries,
        treatmentsGiven = {},
        correctTreatments = 0,
        incorrectTreatments = 0,
        cprCycles = 0,
        lastDeterioration = os.time(),
        transportRequired = realConfig.transportRequired,
        transportState = 'not_ready',
        outcome = nil,
        difficultySettings = diffSettings,
        dialogueUsed = false,
        triageTag = nil, -- computed on demand via ComputeTriageTag (kept live, not cached, so it always reflects current vitals)
    }
end

--- Assigns a START-style triage tag based on current state/vitals. Used
--- primarily for mass-casualty/training scenes where EMS has to prioritize
--- multiple patients at once.
function MozzyEMS.Patients.ComputeTriageTag(patient)
    if patient.state == PatientState.DECEASED then
        return MozzyEMS.TriageTag.BLACK
    end
    if patient.state == PatientState.CARDIAC_ARREST then
        return MozzyEMS.TriageTag.RED
    end
    local v = patient.vitals
    if (v.spo2 or 100) <= 75 or (v.pulse or 80) >= 130 or (v.pulse or 80) > 0 and (v.pulse or 80) <= 45 then
        return MozzyEMS.TriageTag.RED
    end
    if patient.consciousness == Consciousness.UNRESPONSIVE or patient.consciousness == Consciousness.PAIN then
        return MozzyEMS.TriageTag.YELLOW
    end
    if (v.spo2 or 100) <= 90 then
        return MozzyEMS.TriageTag.YELLOW
    end
    return MozzyEMS.TriageTag.GREEN
end

--- Ticks deterioration for a single patient against its real config.
--- Called on an interval from server/calls.lua's main loop.
--- Returns true if the patient's state changed enough to need a client sync.
function MozzyEMS.Patients.Deteriorate(patient, realConfig)
    if patient.outcome then return false end
    if patient.state == PatientState.STABILIZED or patient.state == PatientState.TRANSPORT_READY
        or patient.state == PatientState.TRANSPORTING or patient.state == PatientState.HOSPITALIZED then
        return false
    end

    local det = realConfig.deterioration
    if not det or not det.enabled then return false end

    local now = os.time()
    if now - patient.lastDeterioration < det.interval then return false end
    patient.lastDeterioration = now

    -- enough correct treatment already applied outweighs raw deterioration
    if patient.correctTreatments >= (realConfig.requiredCorrectTreatments or 99) then
        return false
    end

    local mult = patient.difficultySettings.deteriorationMultiplier or 1.0
    local v = patient.vitals

    if det.pulse then v.pulse = math.max(0, v.pulse + math.floor(det.pulse * mult)) end
    if det.bpSys then v.bpSys = math.max(0, v.bpSys + math.floor(det.bpSys * mult)) end
    if det.bpDia then v.bpDia = math.max(0, v.bpDia + math.floor(det.bpDia * mult)) end
    if det.resp then v.resp = math.max(0, v.resp + math.floor(det.resp * mult)) end
    if det.spo2 then v.spo2 = Utils.Clamp(v.spo2 + math.floor(det.spo2 * mult), 0, 100) end
    if det.glucose then v.glucose = math.max(0, (v.glucose or 80) + math.floor(det.glucose * mult)) end

    if det.worsensConsciousness then
        if patient.consciousness == Consciousness.ALERT then
            patient.consciousness = Consciousness.VERBAL
        elseif patient.consciousness == Consciousness.VERBAL then
            patient.consciousness = Consciousness.PAIN
            patient.state = PatientState.UNCONSCIOUS
        elseif patient.consciousness == Consciousness.PAIN then
            patient.consciousness = Consciousness.UNRESPONSIVE
        end
    end

    if det.canArrest and v.spo2 <= 55 and patient.state ~= PatientState.CARDIAC_ARREST then
        if math.random(1, 100) <= 20 then
            patient.state = PatientState.CARDIAC_ARREST
            patient.consciousness = Consciousness.UNRESPONSIVE
            v.pulse, v.resp = 0, 0
        end
    end

    return true
end

--- Applies a single correct-treatment vital delta. Diminishing returns after
--- the same treatment has already been given twice.
function MozzyEMS.Patients.ApplyTreatmentEffect(patient, treatmentId, realConfig)
    local effect = realConfig.treatmentEffects and realConfig.treatmentEffects[treatmentId]
    if not effect then return end

    local timesGiven = patient.treatmentsGiven[treatmentId] or 0
    local falloff = timesGiven >= 2 and 0.35 or (timesGiven == 1 and 0.65 or 1.0)

    local v = patient.vitals
    if effect.pulse then v.pulse = math.max(0, v.pulse + math.floor(effect.pulse * falloff)) end
    if effect.bpSys then v.bpSys = math.max(0, v.bpSys + math.floor(effect.bpSys * falloff)) end
    if effect.bpDia then v.bpDia = math.max(0, v.bpDia + math.floor(effect.bpDia * falloff)) end
    if effect.resp then v.resp = math.max(0, v.resp + math.floor(effect.resp * falloff)) end
    if effect.spo2 then v.spo2 = Utils.Clamp(v.spo2 + math.floor(effect.spo2 * falloff), 0, 100) end
    if effect.glucose then v.glucose = math.max(0, (v.glucose or 80) + math.floor(effect.glucose * falloff)) end

    if effect.consciousnessStep and effect.consciousnessStep > 0 then
        if patient.consciousness == Consciousness.UNRESPONSIVE then
            patient.consciousness = Consciousness.PAIN
        elseif patient.consciousness == Consciousness.PAIN then
            patient.consciousness = Consciousness.VERBAL
            patient.state = PatientState.CONSCIOUS
        elseif patient.consciousness == Consciousness.VERBAL then
            patient.consciousness = Consciousness.ALERT
        end
    end

    patient.treatmentsGiven[treatmentId] = timesGiven + 1
end

--- Checks whether a patient has crossed the stabilization threshold and
--- flips its state accordingly. Called after every treatment application.
function MozzyEMS.Patients.CheckStabilization(patient, realConfig)
    if patient.outcome or patient.state == PatientState.CARDIAC_ARREST then return end
    local required = realConfig.requiredCorrectTreatments or 1
    if patient.correctTreatments >= required and patient.state ~= PatientState.STABILIZED then
        patient.state = PatientState.STABILIZED
        if not realConfig.transportRequired then
            patient.outcome = 'stabilized'
        end
    end
end
