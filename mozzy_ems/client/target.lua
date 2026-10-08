--[[
    client/target.lua
    All ox_target option registration lives here. Options only ever appear
    on the specific patient/bystander/vehicle entities they're added to -
    no global always-on target zones running in the background.
]]

MozzyEMS = MozzyEMS or {}
MozzyEMS.Target = {}

local TREATMENT_CATEGORY_ICON = {
    assessment = 'stethoscope',
    bleeding = 'droplet',
    airway = 'lungs',
    medication = 'syringe',
    trauma = 'bone',
    resuscitation = 'heart-pulse',
    transport = 'truck-medical',
}

local function findPatient(callId, patientIndex)
    local activeCall = MozzyEMS.State.activeCalls[callId]
    if not activeCall then return nil end
    return activeCall.patients[patientIndex], activeCall
end

local function openAssessmentMenu(callId, patientIndex)
    TriggerServerEvent(MozzyEMS.Events.RequestVitals, callId, patientIndex)
end

--- Builds the flat treatment option list once - every call type shares the
--- same equipment menu because EMS never knows in advance which items are
--- "correct" (that's the point of the simulator).
local function buildTreatmentOptions(callId, patientIndex)
    local options = {}
    for id, def in pairs(Config.Treatments) do
        options[#options + 1] = {
            title = def.label,
            icon = TREATMENT_CATEGORY_ICON[def.category] or 'kit-medical',
            onSelect = function()
                MozzyEMS.Treatment.Perform(callId, patientIndex, id)
            end,
        }
    end
    table.sort(options, function(a, b) return a.title < b.title end)
    return options
end

function MozzyEMS.Target.AddPatientTarget(ped, callId, patientIndex)
    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'mozzy_ems_assess_' .. callId .. '_' .. patientIndex,
            icon = 'stethoscope',
            label = 'Assess Patient',
            distance = 2.0,
            canInteract = function() return MozzyEMS.Framework.CanWorkEMS() end,
            onSelect = function() openAssessmentMenu(callId, patientIndex) end,
        },
        {
            name = 'mozzy_ems_treat_' .. callId .. '_' .. patientIndex,
            icon = 'kit-medical',
            label = 'Treat Patient',
            distance = 2.0,
            canInteract = function() return MozzyEMS.Framework.CanWorkEMS() end,
            onSelect = function()
                lib.registerContext({
                    id = 'mozzy_ems_treat_menu_' .. callId .. '_' .. patientIndex,
                    title = 'Treatment Options',
                    options = buildTreatmentOptions(callId, patientIndex),
                })
                lib.showContext('mozzy_ems_treat_menu_' .. callId .. '_' .. patientIndex)
            end,
        },
        {
            name = 'mozzy_ems_transport_' .. callId .. '_' .. patientIndex,
            icon = 'truck-medical',
            label = 'Load Patient for Transport',
            distance = 2.0,
            canInteract = function()
                local patient = findPatient(callId, patientIndex)
                return patient and patient.state ~= 'cardiac_arrest' and not MozzyEMS.State.carrying
            end,
            onSelect = function()
                MozzyEMS.Transport.LoadPatient(callId, patientIndex, ped)
            end,
        },
    })
end

function MozzyEMS.Target.AddBystanderTarget(ped, lines)
    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'mozzy_ems_bystander_' .. ped,
            icon = 'comment',
            label = 'Ask "What happened?"',
            distance = 2.0,
            canInteract = function() return MozzyEMS.Framework.CanWorkEMS() end,
            onSelect = function()
                local line = lines and #lines > 0 and lines[math.random(1, #lines)] or 'I... I\'m not sure, I just found them like this.'
                lib.showTextUI(('"%s"'):format(line), { position = 'left-center' })
                SetTimeout(4000, function() lib.hideTextUI() end)
            end,
        },
    })
end
