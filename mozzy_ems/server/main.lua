--[[
    server/main.lua
    Webhook helper + resource lifecycle. Call generation itself lives in
    server/calls.lua - this file is bootstrap/glue only.
]]

MozzyEMS = MozzyEMS or {}
MozzyEMS.Webhook = {}

function MozzyEMS.Webhook.Send(eventKey, message)
    if not Config.Webhook.enabled or Config.Webhook.url == '' then return end
    if Config.Webhook.events[eventKey] == false then return end

    PerformHttpRequest(Config.Webhook.url, function() end, 'POST', json.encode({
        username = Config.Webhook.username,
        embeds = { { description = message, color = 65280 } },
    }), { ['Content-Type'] = 'application/json' })
end

local function debugPrint(...)
    if not Config.Debug then return end
    print('^3[mozzy_ems]^7', ...)
end
MozzyEMS.DebugPrint = debugPrint

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if MozzyEMS.Calls and MozzyEMS.Calls.CleanupAll then
        MozzyEMS.Calls.CleanupAll()
    end
end)

CreateThread(function()
    Wait(1000)
    debugPrint('Mozzy EMS Simulator loaded. Difficulty:', Config.Difficulty, '| Dispatch mode:', Config.Dispatch)
end)

-----------------------------------------------------------------------------
-- ACE PERMISSION REGISTRATION HINT (does not itself grant anything - see README)
-----------------------------------------------------------------------------

CreateThread(function()
    if Config.AdminAcePermission then
        debugPrint(('Admin ACE permission expected: add_ace group.admin %s allow (see README)'):format(Config.AdminAcePermission))
    end
end)
