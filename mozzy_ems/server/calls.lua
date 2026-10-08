--[[
    server/calls.lua (server-only)
    The call generator + ActiveCalls registry + lifecycle state machine.
    This is the file that ties patients.lua, treatment.lua, rewards.lua and
    the dispatch/framework bridges together.
]]

MozzyEMS = MozzyEMS or {}
MozzyEMS.Calls = {}

local Utils = MozzyEMS.Utils
local CallState = MozzyEMS.CallState
local PatientState = MozzyEMS.PatientState

local ActiveCalls = {}
local locationCooldowns = {}   -- [locationId] = expireTimestamp
local scenarioCooldowns = {}   -- [callType] = expireTimestamp
local lastGeneratedType = nil

-----------------------------------------------------------------------------
-- INTERNAL HELPERS
-----------------------------------------------------------------------------

local function activeCallCount()
    local n = 0
    for _ in pairs(ActiveCalls) do n = n + 1 end
    return n
end

local function pickLocation(cfg)
    local now = os.time()
    local candidates = {}
    for _, loc in ipairs(Config.CallLocations) do
        local onCooldown = locationCooldowns[loc.id] and locationCooldowns[loc.id] > now
        local categoryOk = Utils.Contains(cfg.locations or {}, loc.category)
        local explicitOk = cfg.allowedCalls and Utils.Contains(cfg.allowedCalls, loc.id)
        if not onCooldown and (categoryOk or explicitOk) then
            candidates[#candidates + 1] = loc
        end
    end
    if #candidates == 0 then
        -- cooldowns exhausted every option - ignore cooldown rather than fail to generate
        for _, loc in ipairs(Config.CallLocations) do
            if Utils.Contains(cfg.locations or {}, loc.category) then
                candidates[#candidates + 1] = loc
            end
        end
    end
    return Utils.RandomElement(candidates)
end

local function pickCallType()
    local now = os.time()
    local weighted = {}
    for callType, cfg in pairs(Config.Calls) do
        if cfg.enabled then
            local onCooldown = scenarioCooldowns[callType] and scenarioCooldowns[callType] > now
            local repeatBlocked = (not Config.CallGeneration.allowImmediateRepeat) and callType == lastGeneratedType
            if not onCooldown and not repeatBlocked then
                weighted[#weighted + 1] = { value = callType, weight = cfg.weight or 1 }
            end
        end
    end

    if #weighted == 0 then
        -- everything on cooldown / only the last type available - fall back to any enabled type
        for callType, cfg in pairs(Config.Calls) do
            if cfg.enabled then weighted[#weighted + 1] = { value = callType, weight = cfg.weight or 1 } end
        end
    end

    return Utils.WeightedRandom(weighted)
end

-----------------------------------------------------------------------------
-- CALL CREATION
-----------------------------------------------------------------------------

--- opts: { training=bool, admin=bool, coordsOverride=vec4, patientCount=int }
function MozzyEMS.Calls.Generate(callType, opts)
    opts = opts or {}
    callType = callType or pickCallType()
    if not callType then return nil, 'no_call_types_available' end

    local displayConfig, realConfig, realType = MozzyEMS.Patients.ResolveCallConfig(callType)
    if not displayConfig then return nil, 'invalid_call_type' end

    local location
    local coords
    if opts.coordsOverride then
        coords = opts.coordsOverride
    else
        location = pickLocation(displayConfig)
        if not location then return nil, 'no_valid_location' end
        coords = location.coords
    end

    local callId = Utils.GenerateCallId()
    local patientCount = Utils.Clamp(opts.patientCount or 1, 1, Config.MaxPatientsPerCall)

    local patients = {}
    for i = 1, patientCount do
        patients[i] = MozzyEMS.Patients.Create(i, displayConfig, realConfig, realType, Config.Difficulty)
    end

    local call = {
        id = callId,
        type = callType,
        realType = realType,
        displayConfig = displayConfig,
        realConfig = realConfig,
        label = displayConfig.label,
        dispatchCode = displayConfig.dispatchCode,
        priority = displayConfig.priority,
        narrative = Utils.RandomElement(displayConfig.callerText) or 'No further details available.',
        coords = coords,
        locationId = location and location.id or nil,
        state = CallState.UNASSIGNED,
        responders = {},
        primaryResponder = nil,
        patients = patients,
        createdAt = os.time(),
        arrivedAt = nil,
        expireAt = os.time() + Config.CallGeneration.callExpiration,
        training = opts.training or false,
        adminCreated = opts.admin or false,
        responseTime = nil,
    }

    ActiveCalls[callId] = call

    if location then
        locationCooldowns[location.id] = os.time() + Config.CallGeneration.locationCooldown
    end
    scenarioCooldowns[callType] = os.time() + Config.CallGeneration.scenarioCooldown
    lastGeneratedType = callType

    local recipients = MozzyEMS.Framework.GetOnDutyEMSSources()
    MozzyEMS.Dispatch.Announce({
        id = call.id, label = call.label, dispatchCode = call.dispatchCode,
        priority = call.priority, coords = call.coords, narrative = call.narrative,
    }, recipients)

    if Config.Debug then
        if #recipients == 0 then
            print(('^1[mozzy_ems]^7 Call %s generated but 0 on-duty EMS were found to notify - check that Config.EMSJobs/Config.EMSJobTypes match your job, and that someone is actually clocked on duty.'):format(call.id))
        else
            print(('^3[mozzy_ems]^7 Call %s dispatched to %d on-duty EMS: %s'):format(call.id, #recipients, table.concat(recipients, ', ')))
        end
    end

    if Config.Webhook.enabled and Config.Webhook.events.callGenerated then
        MozzyEMS.Webhook.Send('callGenerated', ('New call `%s`: %s (priority %d)'):format(call.id, call.label, call.priority))
    end
    if opts.admin and Config.Webhook.enabled and Config.Webhook.events.adminCreatedCall then
        MozzyEMS.Webhook.Send('adminCreatedCall', ('Admin-generated call `%s`: %s'):format(call.id, call.label))
    end

    MozzyEMS.DebugPrint(('Generated call %s (%s) at %s'):format(call.id, realType, call.locationId or 'custom coords'))
    return call
end

-----------------------------------------------------------------------------
-- ACCESSORS
-----------------------------------------------------------------------------

function MozzyEMS.Calls.Get(callId)
    return ActiveCalls[callId]
end

function MozzyEMS.Calls.GetAll()
    return ActiveCalls
end

local function summarize(call)
    return {
        id = call.id, label = call.label, dispatchCode = call.dispatchCode,
        priority = call.priority, coords = call.coords, state = call.state,
        narrative = call.narrative, responderCount = (function()
            local n = 0 for _ in pairs(call.responders) do n = n + 1 end return n
        end)(),
    }
end

function MozzyEMS.Calls.GetActiveSummaries()
    local out = {}
    for _, call in pairs(ActiveCalls) do out[#out + 1] = summarize(call) end
    return out
end

-----------------------------------------------------------------------------
-- ACCEPT / DECLINE / SYNC
-----------------------------------------------------------------------------

RegisterNetEvent(MozzyEMS.Events.CallAccepted, function(callId)
    local source = source
    if not MozzyEMS.Framework.CanWorkEMS(source) then return end
    local call = ActiveCalls[callId]
    if not call then return end
    if call.state == CallState.COMPLETED or call.state == CallState.CANCELLED or call.state == CallState.EXPIRED then return end

    if Config.CallClaimMode == 'claim' and call.primaryResponder and not call.responders[source] then
        if not Config.AllowMultipleResponders then return end
        local count = 0
        for _ in pairs(call.responders) do count = count + 1 end
        if count >= Config.MaxRespondersPerCall then return end
    end

    local isFirst = not call.primaryResponder
    call.responders[source] = true
    if isFirst then
        call.primaryResponder = source
        call.state = CallState.ASSIGNED
    end

    TriggerClientEvent(MozzyEMS.Events.SpawnScene, source, {
        call = summarize(call),
        realTypeHidden = call.displayConfig.hidden,
        narrative = call.narrative,
        bystanderLines = call.displayConfig.bystanderLines,
        patients = (function()
            local out = {}
            for i, p in ipairs(call.patients) do
                out[i] = {
                    index = p.index, model = p.model, animation = p.animation,
                    label = p.displayLabel, consciousness = p.consciousness, state = p.state,
                }
            end
            return out
        end)(),
        scene = call.realConfig.scene or {},
        hospitals = Config.Hospitals,
    })
end)

RegisterNetEvent(MozzyEMS.Events.CallDeclined, function(callId)
    -- purely informational client-side (removes the dispatch card) - no
    -- server state change needed since the responder never joined
end)

RegisterNetEvent(MozzyEMS.Events.RequestActiveCalls, function()
    local source = source
    TriggerClientEvent(MozzyEMS.Events.SyncActiveCalls, source, MozzyEMS.Calls.GetActiveSummaries())
end)

--- Called by client once it's within arrival distance of the scene coords.
RegisterNetEvent(MozzyEMS.Events.ArrivedOnScene, function(callId)
    local source = source
    local call = ActiveCalls[callId]
    if not call or not call.responders[source] then return end
    if not call.arrivedAt then
        call.arrivedAt = os.time()
        call.responseTime = call.arrivedAt - call.createdAt
    end
    if call.state == CallState.ASSIGNED or call.state == CallState.EN_ROUTE then
        call.state = CallState.ON_SCENE
    end
end)

RegisterNetEvent(MozzyEMS.Events.RegisterPatientPed, function(callId, patientIndex, netId)
    local source = source
    local call = ActiveCalls[callId]
    if not call or not call.responders[source] then return end
    local patient = call.patients[patientIndex]
    if not patient then return end
    patient.netId = netId
end)

RegisterNetEvent(MozzyEMS.Events.RequestVitals, function(callId, patientIndex)
    local source = source
    local call = ActiveCalls[callId]
    if not call or not call.responders[source] then return end
    local patient = call.patients[patientIndex]
    if not patient then return end

    local vitals = Utils.DeepCopy(patient.vitals)
    if patient.difficultySettings.vitalsPrecision == 'rounded' then
        for k, v in pairs(vitals) do
            if type(v) == 'number' then vitals[k] = math.floor(v / 5 + 0.5) * 5 end
        end
    end

    local hint = nil
    if Config.ShowTreatmentHints then
        local labels = {}
        for treatmentId in pairs(call.realConfig.validTreatments or {}) do
            local def = Config.Treatments[treatmentId]
            if def then labels[#labels + 1] = def.label end
        end
        table.sort(labels)
        if #labels > 0 then hint = table.concat(labels, ', ') end
    end

    TriggerClientEvent(MozzyEMS.Events.VitalsResult, source, {
        callId = callId, patientIndex = patientIndex, vitals = vitals,
        consciousness = patient.consciousness, injuries = patient.injuries, state = patient.state,
        triageTag = (#call.patients > 1) and MozzyEMS.Patients.ComputeTriageTag(patient) or nil,
        hint = hint,
    })
end)

--- Broadcasts a patient's current state to every responder on the call, and
--- checks whether that update resolves the call (stabilized-no-transport,
--- deceased, etc).
function MozzyEMS.Calls.SyncPatient(call, patient)
    for src in pairs(call.responders) do
        TriggerClientEvent(MozzyEMS.Events.PatientStateUpdate, src, {
            callId = call.id, patientIndex = patient.index,
            vitals = patient.vitals, state = patient.state, consciousness = patient.consciousness,
        })
    end
    MozzyEMS.Calls.CheckCompletion(call, patient)
end

-----------------------------------------------------------------------------
-- TRANSPORT
-----------------------------------------------------------------------------

RegisterNetEvent(MozzyEMS.Events.LoadPatient, function(callId, patientIndex)
    local source = source
    local call = ActiveCalls[callId]
    if not call or not call.responders[source] then return end
    local patient = call.patients[patientIndex]
    if not patient or patient.outcome then return end
    if patient.state == PatientState.CARDIAC_ARREST then return end -- must resuscitate first
    patient.transportState = 'loaded'
    call.state = CallState.TRANSPORTING
end)

RegisterNetEvent(MozzyEMS.Events.DeliverPatient, function(callId, patientIndex, hospitalLabel)
    local source = source
    local call = ActiveCalls[callId]
    if not call or not call.responders[source] then return end
    local patient = call.patients[patientIndex]
    if not patient or patient.outcome then return end
    if patient.transportState ~= 'loaded' then return end

    local validHospital = false
    for _, h in ipairs(Config.Hospitals) do
        if h.label == hospitalLabel then validHospital = true break end
    end
    if not validHospital then return end

    patient.transportState = 'delivered'
    patient.transported = true
    patient.state = PatientState.HOSPITALIZED
    patient.outcome = patient.outcome or 'stabilized'

    MozzyEMS.Medical.NotifyPatientDelivered(callId, hospitalLabel)
    MozzyEMS.Calls.SyncPatient(call, patient)
end)

-----------------------------------------------------------------------------
-- COMPLETION / CLEANUP
-----------------------------------------------------------------------------

function MozzyEMS.Calls.CheckCompletion(call, patient)
    if not patient.outcome then return end
    if patient.rewarded then return end
    patient.rewarded = true

    MozzyEMS.Rewards.Payout(call, patient)

    -- is every patient on this call resolved?
    local allResolved = true
    for _, p in ipairs(call.patients) do
        if not p.outcome then allResolved = false break end
    end

    if allResolved then
        call.state = CallState.COMPLETED
        for src in pairs(call.responders) do
            TriggerClientEvent(MozzyEMS.Events.CleanupScene, src, call.id)
        end
        SetTimeout(2000, function() ActiveCalls[call.id] = nil end)
    end
end

function MozzyEMS.Calls.Cancel(callId, reason)
    local call = ActiveCalls[callId]
    if not call then return false end
    call.state = CallState.CANCELLED
    for src in pairs(call.responders) do
        TriggerClientEvent(MozzyEMS.Events.CallRemoved, src, callId)
        TriggerClientEvent(MozzyEMS.Events.CleanupScene, src, callId)
    end
    ActiveCalls[callId] = nil
    return true
end

function MozzyEMS.Calls.CleanupAll()
    for callId, call in pairs(ActiveCalls) do
        for src in pairs(call.responders) do
            TriggerClientEvent(MozzyEMS.Events.CleanupScene, src, callId)
        end
    end
    ActiveCalls = {}
end

-----------------------------------------------------------------------------
-- RUNTIME TOGGLE (admin menu "Enable/Disable Simulator")
-----------------------------------------------------------------------------

local generationEnabled = Config.CallGeneration.enabled

function MozzyEMS.Calls.SetGenerationEnabled(state)
    generationEnabled = state
end

function MozzyEMS.Calls.IsGenerationEnabled()
    return generationEnabled
end

-----------------------------------------------------------------------------
-- GENERATOR LOOP
-----------------------------------------------------------------------------

CreateThread(function()
    while true do
        local waitSeconds = Utils.RandomInt(Config.CallGeneration.minInterval, Config.CallGeneration.maxInterval)
        Wait(waitSeconds * 1000)

        if generationEnabled then
            local onDuty = MozzyEMS.Framework.GetOnDutyEMSCount()
            if onDuty >= Config.CallGeneration.minimumEMS and activeCallCount() < Config.CallGeneration.maximumActiveCalls then
                MozzyEMS.Calls.Generate(nil, {})
            end
        end
    end
end)

-- expiration + deterioration tick loop
CreateThread(function()
    while true do
        Wait(5000)
        local now = os.time()
        for callId, call in pairs(ActiveCalls) do
            if call.state == CallState.UNASSIGNED and now > call.expireAt then
                call.state = CallState.EXPIRED
                for src in pairs(call.responders) do
                    TriggerClientEvent(MozzyEMS.Events.CallRemoved, src, callId)
                end
                ActiveCalls[callId] = nil
            elseif call.state ~= CallState.COMPLETED and call.state ~= CallState.CANCELLED then
                for _, patient in ipairs(call.patients) do
                    if MozzyEMS.Patients.Deteriorate(patient, call.realConfig) then
                        MozzyEMS.Calls.SyncPatient(call, patient)
                    end
                end
            end
        end
    end
end)

-----------------------------------------------------------------------------
-- ADMIN / TRAINING COMMANDS
-----------------------------------------------------------------------------

local function resolveAdminCallType(arg)
    if not arg then return nil end
    arg = string.lower(arg)
    if Config.Calls[arg] then return arg end
    if Config.CallAliases[arg] then return Config.CallAliases[arg] end
    return nil
end

RegisterCommand(Config.AdminCommand, function(source, args)
    if source == 0 then return end -- console: use exports.mozzy_ems:AddCall instead
    if not MozzyEMS.Framework.IsAdmin(source) then
        return MozzyEMS.Framework.Notify(source, 'You do not have permission to do that.', 'error')
    end

    local requested = args[1] and resolveAdminCallType(args[1]) or nil
    if args[1] and not requested then
        return MozzyEMS.Framework.Notify(source, 'Unknown call type: ' .. args[1], 'error')
    end

    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    local call, err = MozzyEMS.Calls.Generate(requested, {
        admin = true,
        coordsOverride = vec4(coords.x, coords.y, coords.z, heading),
    })

    if not call then
        return MozzyEMS.Framework.Notify(source, 'Failed to generate call: ' .. tostring(err), 'error')
    end
    MozzyEMS.Framework.Notify(source, ('Generated call %s: %s'):format(call.id, call.label), 'success')
end, false)

RegisterCommand(Config.TrainingCommand, function(source, args)
    if source == 0 then return end
    if not MozzyEMS.Framework.IsAdmin(source) then
        return MozzyEMS.Framework.Notify(source, 'You do not have permission to do that.', 'error')
    end

    local requested = args[1] and resolveAdminCallType(args[1]) or nil
    if args[1] and not requested then
        return MozzyEMS.Framework.Notify(source, 'Unknown call type: ' .. args[1], 'error')
    end

    local patientCount = 1
    if args[2] == 'mci' and Config.MassCasualty.enabled then
        patientCount = Utils.RandomInt(Config.MassCasualty.minPatients, Config.MassCasualty.maxPatients)
    end

    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    local call, err = MozzyEMS.Calls.Generate(requested, {
        training = true, admin = true, patientCount = patientCount,
        coordsOverride = vec4(coords.x, coords.y, coords.z, heading),
    })

    if not call then
        return MozzyEMS.Framework.Notify(source, 'Failed to generate training call: ' .. tostring(err), 'error')
    end
    MozzyEMS.Framework.Notify(source, ('Training call %s generated (%d patient(s), no payout).'):format(call.id, patientCount), 'success')
end, false)

-----------------------------------------------------------------------------
-- ADMIN MENU (server side: command entry point + action handlers)
-----------------------------------------------------------------------------

RegisterCommand(Config.AdminMenuCommand, function(source)
    if source == 0 then return end
    if not MozzyEMS.Framework.IsAdmin(source) then
        return MozzyEMS.Framework.Notify(source, 'You do not have permission to do that.', 'error')
    end

    local callTypes = {}
    for id, cfg in pairs(Config.Calls) do
        if cfg.enabled then callTypes[#callTypes + 1] = { id = id, label = cfg.label } end
    end
    table.sort(callTypes, function(a, b) return a.label < b.label end)

    TriggerClientEvent('mozzy_ems:client:openAdminMenu', source, {
        callTypes = callTypes,
        activeCalls = MozzyEMS.Calls.GetActiveSummaries(),
        generationEnabled = generationEnabled,
        onDutyCount = MozzyEMS.Framework.GetOnDutyEMSCount(),
    })
end, false)

RegisterNetEvent('mozzy_ems:server:adminToggleGeneration', function()
    local source = source
    if not MozzyEMS.Framework.IsAdmin(source) then return end
    generationEnabled = not generationEnabled
    MozzyEMS.Framework.Notify(source, 'Simulator call generation is now ' .. (generationEnabled and 'ENABLED' or 'DISABLED'), 'success')
end)

RegisterNetEvent('mozzy_ems:server:adminCancelCall', function(callId)
    local source = source
    if not MozzyEMS.Framework.IsAdmin(source) then return end
    local ok = MozzyEMS.Calls.Cancel(callId, 'admin_cancelled')
    MozzyEMS.Framework.Notify(source, ok and ('Call ' .. callId .. ' cancelled.') or 'Call not found.', ok and 'success' or 'error')
end)

RegisterNetEvent('mozzy_ems:server:adminDeletePatient', function(callId, patientIndex)
    local source = source
    if not MozzyEMS.Framework.IsAdmin(source) then return end
    local call = ActiveCalls[callId]
    if not call or not call.patients[patientIndex] then
        return MozzyEMS.Framework.Notify(source, 'Patient not found.', 'error')
    end
    local patient = call.patients[patientIndex]
    patient.outcome = patient.outcome or 'admin_deleted'
    patient.rewarded = true -- skip payout for an admin-deleted stuck patient
    for src in pairs(call.responders) do
        TriggerClientEvent(MozzyEMS.Events.CleanupScene, src, callId)
    end
    local allResolved = true
    for _, p in ipairs(call.patients) do
        if not p.outcome then allResolved = false break end
    end
    if allResolved then
        call.state = CallState.CANCELLED
        ActiveCalls[callId] = nil
    end
    MozzyEMS.Framework.Notify(source, 'Stuck patient removed.', 'success')
end)

RegisterNetEvent('mozzy_ems:server:adminGenerateCall', function(callType, coords)
    local source = source
    if not MozzyEMS.Framework.IsAdmin(source) then return end
    local coordsOverride = coords and vec4(coords.x, coords.y, coords.z, coords.w or 0.0) or nil
    if not coordsOverride then
        local ped = GetPlayerPed(source)
        local c = GetEntityCoords(ped)
        coordsOverride = vec4(c.x, c.y, c.z, GetEntityHeading(ped))
    end
    local call, err = MozzyEMS.Calls.Generate(callType, { admin = true, coordsOverride = coordsOverride })
    if not call then
        return MozzyEMS.Framework.Notify(source, 'Failed to generate call: ' .. tostring(err), 'error')
    end
    MozzyEMS.Framework.Notify(source, ('Generated call %s: %s'):format(call.id, call.label), 'success')
end)

-----------------------------------------------------------------------------
-- PUBLIC EXPORTS API
-----------------------------------------------------------------------------

--- exports.mozzy_ems:AddCall({ type = 'shooting', coords = vec4(...), severity = 1 })
--- `type` may be a Config.Calls key or one of Config.CallAliases.
--- Returns the created call's id, or nil + error string.
exports('AddCall', function(opts)
    opts = opts or {}
    local callType = opts.type and resolveAdminCallType(opts.type) or nil
    local coordsOverride = opts.coords
    if coordsOverride and not coordsOverride.w then
        coordsOverride = vec4(coordsOverride.x, coordsOverride.y, coordsOverride.z, opts.heading or 0.0)
    end
    local call, err = MozzyEMS.Calls.Generate(callType, {
        coordsOverride = coordsOverride,
        patientCount = opts.patientCount,
    })
    if not call then return nil, err end
    return call.id
end)

exports('GetActiveCalls', function()
    return MozzyEMS.Calls.GetActiveSummaries()
end)

exports('GetPatientState', function(callId, patientIndex)
    local call = ActiveCalls[callId]
    if not call then return nil end
    local patient = call.patients[patientIndex or 1]
    if not patient then return nil end
    return {
        state = patient.state, consciousness = patient.consciousness,
        vitals = Utils.DeepCopy(patient.vitals), outcome = patient.outcome,
    }
end)

exports('CompleteCall', function(callId)
    local call = ActiveCalls[callId]
    if not call then return false end
    for _, patient in ipairs(call.patients) do
        if not patient.outcome then
            patient.outcome = 'stabilized'
            MozzyEMS.Calls.SyncPatient(call, patient)
        end
    end
    return true
end)

exports('CancelCall', function(callId)
    return MozzyEMS.Calls.Cancel(callId, 'export_cancelled')
end)
