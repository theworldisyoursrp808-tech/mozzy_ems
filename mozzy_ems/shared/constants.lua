--[[
    Mozzy EMS Simulator - shared/constants.lua
    Central enums. Never hardcode these strings elsewhere - reference this table.
]]

MozzyEMS = MozzyEMS or {}

MozzyEMS.CallState = {
    UNASSIGNED = 'unassigned',
    ASSIGNED = 'assigned',
    EN_ROUTE = 'en_route',
    ON_SCENE = 'on_scene',
    TRANSPORTING = 'transporting',
    COMPLETED = 'completed',
    EXPIRED = 'expired',
    CANCELLED = 'cancelled',
}

MozzyEMS.PatientState = {
    WAITING = 'waiting',
    CONSCIOUS = 'conscious',
    UNCONSCIOUS = 'unconscious',
    CRITICAL = 'critical',
    CARDIAC_ARREST = 'cardiac_arrest',
    STABILIZED = 'stabilized',
    TRANSPORT_READY = 'transport_ready',
    TRANSPORTING = 'transporting',
    HOSPITALIZED = 'hospitalized',
    DECEASED = 'deceased',
}

MozzyEMS.Consciousness = {
    ALERT = 'alert',
    VERBAL = 'responsive_verbal',
    PAIN = 'responsive_pain',
    UNRESPONSIVE = 'unresponsive',
}

MozzyEMS.Priority = {
    CRITICAL = 1,
    SERIOUS = 2,
    STABLE = 3,
}

MozzyEMS.TriageTag = {
    RED = 'red',
    YELLOW = 'yellow',
    GREEN = 'green',
    BLACK = 'black',
}

-- server -> client / client -> server event names, kept in one place so bridges & modules agree
MozzyEMS.Events = {
    -- dispatch
    NewCallOffer = 'mozzy_ems:client:newCallOffer',
    CallAccepted = 'mozzy_ems:server:acceptCall',
    CallDeclined = 'mozzy_ems:server:declineCall',
    CallUpdated = 'mozzy_ems:client:callUpdated',
    CallRemoved = 'mozzy_ems:client:callRemoved',
    RequestActiveCalls = 'mozzy_ems:server:requestActiveCalls',
    ArrivedOnScene = 'mozzy_ems:server:arrivedOnScene',
    SyncActiveCalls = 'mozzy_ems:client:syncActiveCalls',

    -- patient / scene
    SpawnScene = 'mozzy_ems:client:spawnScene',
    RegisterPatientPed = 'mozzy_ems:server:registerPatientPed',
    PatientStateUpdate = 'mozzy_ems:client:patientStateUpdate',
    RequestVitals = 'mozzy_ems:server:requestVitals',
    VitalsResult = 'mozzy_ems:client:vitalsResult',
    CleanupScene = 'mozzy_ems:client:cleanupScene',

    -- treatment
    PerformTreatment = 'mozzy_ems:server:performTreatment',
    TreatmentResult = 'mozzy_ems:client:treatmentResult',
    PerformCPRCycle = 'mozzy_ems:server:performCPRCycle',
    UseAED = 'mozzy_ems:server:useAED',

    -- transport
    LoadPatient = 'mozzy_ems:server:loadPatient',
    DeliverPatient = 'mozzy_ems:server:deliverPatient',

    -- completion
    CallComplete = 'mozzy_ems:client:callComplete',

    -- admin / training
    AdminForceCall = 'mozzy_ems:server:adminForceCall',
}
