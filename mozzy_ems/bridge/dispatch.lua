--[[
    bridge/dispatch.lua
    Config.Dispatch controls which branch runs:
        'standalone' - built-in ox_lib alert + blip, no external resource
        'lb'         - routes through an LB-style dispatch resource export
        'custom'     - stub for you to fill in for your own dispatch script

    server/calls.lua always calls MozzyEMS.Dispatch.Announce(...) - it never
    needs to know which branch is active.
]]

MozzyEMS = MozzyEMS or {}
MozzyEMS.Dispatch = {}

local isServer = IsDuplicityVersion()

-----------------------------------------------------------------------------
-- SERVER: fan the call out to whichever dispatch backend is configured
-----------------------------------------------------------------------------

if isServer then

    --- call = { id, label, dispatchCode, priority, coords, narrative }
    --- recipients = array of source ids (on-duty EMS)
    function MozzyEMS.Dispatch.Announce(call, recipients)
        if Config.Dispatch == 'lb' then
            -- Example LB-style dispatch export call. Adjust the export name
            -- to whatever your LB dispatch resource actually exposes.
            local ok = pcall(function()
                exports['lb-dispatch']:AddCall({
                    job = 'ambulance',
                    title = call.label,
                    message = call.narrative,
                    code = call.dispatchCode,
                    coords = call.coords,
                    priority = call.priority,
                    length = 8,
                })
            end)
            if ok then return end
            -- fall through to standalone if the export failed (e.g. not installed)
        elseif Config.Dispatch == 'custom' then
            -- TODO: wire up your own dispatch resource here. Left as a stub
            -- so integration doesn't require touching any other file.
        end

        -- standalone fallback: direct event to each on-duty EMS client
        for _, src in ipairs(recipients) do
            TriggerClientEvent(MozzyEMS.Events.NewCallOffer, src, call)
        end
    end
end
