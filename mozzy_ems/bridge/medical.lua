--[[
    bridge/medical.lua
    Keeps Mozzy EMS Simulator from fighting with whatever ambulance/EMS
    gameplay resource you already run (revive scripts, stretchers, hospital
    beds, etc). Config.ExternalMedicalResource = false means the simulator
    uses its own minimal built-in behaviour for these hooks; set it to a
    resource name and fill in the pcall'd exports below to bridge instead.

    None of these hooks are required for the simulator's own patients (which
    are simulator-owned NPCs, not real downed players) - they exist so a
    server can optionally reuse the same stretcher/hospital-bed resource for
    both real players and simulator patients.
]]

MozzyEMS = MozzyEMS or {}
MozzyEMS.Medical = {}

local isServer = IsDuplicityVersion()

if isServer then

    --- Ask the external resource whether it wants to claim the stretcher /
    --- transport flow for a simulator patient. Returns false by default so
    --- the simulator's own basic stretcher (client/transport.lua) is used.
    function MozzyEMS.Medical.UsesExternalStretcher()
        return Config.ExternalMedicalResource ~= false
    end

    --- Optional: notify an external EMS resource that a simulator patient
    --- was delivered to a hospital zone, in case it wants to log/animate it.
    function MozzyEMS.Medical.NotifyPatientDelivered(callId, hospitalLabel)
        if not Config.ExternalMedicalResource then return end
        pcall(function()
            exports[Config.ExternalMedicalResource]:MozzyEMS_OnPatientDelivered(callId, hospitalLabel)
        end)
    end

    --- Optional: ask an external resource for a valid ambulance vehicle list
    --- instead of the static Config.Ambulances table, if it maintains its own.
    function MozzyEMS.Medical.GetAmbulanceModels()
        if Config.ExternalMedicalResource then
            local ok, models = pcall(function()
                return exports[Config.ExternalMedicalResource]:MozzyEMS_GetAmbulanceModels()
            end)
            if ok and models then return models end
        end
        return Config.Ambulances
    end
end
