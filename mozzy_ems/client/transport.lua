--[[
    client/transport.lua
    Minimal built-in stretcher/transport flow: load the patient near a
    configured ambulance, drive to any configured hospital, auto-deliver on
    arrival. bridge/medical.lua lets you swap this for an external
    stretcher/ambulance resource without touching this file's callers.
]]

MozzyEMS = MozzyEMS or {}
MozzyEMS.Transport = {}

local function nearestAmbulance(coords, maxDist)
    local vehicles = GetGamePool('CVehicle')
    local closest, closestDist = nil, maxDist
    local validModels = Config.Ambulances

    for _, veh in ipairs(vehicles) do
        local model = GetEntityModel(veh)
        local isAmbulance = false
        for _, m in ipairs(validModels) do
            if m == model then isAmbulance = true break end
        end
        if isAmbulance then
            local dist = #(coords - GetEntityCoords(veh))
            if dist < closestDist then
                closest, closestDist = veh, dist
            end
        end
    end
    return closest
end

local function nearestHospital(coords)
    local closest, closestDist = Config.Hospitals[1], nil
    for _, hospital in ipairs(Config.Hospitals) do
        local dist = #(coords - hospital.coords)
        if not closestDist or dist < closestDist then
            closest, closestDist = hospital, dist
        end
    end
    return closest
end

function MozzyEMS.Transport.LoadPatient(callId, patientIndex, patientPed)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    local ambulance = nearestAmbulance(coords, 8.0)
    if not ambulance then
        lib.notify({ description = 'You need to be near a configured ambulance to load the patient.', type = 'error' })
        return
    end

    local success = lib.progressCircle({
        duration = 3000,
        label = 'Loading patient...',
        disable = { move = true, car = true, combat = true },
    })
    if not success then return end

    TriggerServerEvent(MozzyEMS.Events.LoadPatient, callId, patientIndex)

    -- despawn the scene ped and remember we're carrying this patient
    local key = callId .. '_' .. patientIndex
    local pedHandle = MozzyEMS.State.peds[key]
    if pedHandle and DoesEntityExist(pedHandle) then DeleteEntity(pedHandle) end
    MozzyEMS.State.peds[key] = nil

    MozzyEMS.State.carrying = { callId = callId, patientIndex = patientIndex }

    lib.notify({ description = 'Patient loaded. Head to a hospital.', type = 'success' })
    local hospital = nearestHospital(coords)
    SetNewWaypoint(hospital.coords.x, hospital.coords.y)
end

--- Watches for the player entering a hospital delivery radius while carrying
--- a loaded patient, and auto-delivers.
CreateThread(function()
    while true do
        Wait(1000)
        local carrying = MozzyEMS.State.carrying
        if carrying then
            local coords = GetEntityCoords(PlayerPedId())
            for _, hospital in ipairs(Config.Hospitals) do
                local dist = #(coords - hospital.coords)
                if dist <= hospital.radius then
                    TriggerServerEvent(MozzyEMS.Events.DeliverPatient, carrying.callId, carrying.patientIndex, hospital.label)
                    lib.notify({ description = ('Patient delivered to %s.'):format(hospital.label), type = 'success' })
                    MozzyEMS.State.carrying = nil
                    break
                end
            end
        end
    end
end)
