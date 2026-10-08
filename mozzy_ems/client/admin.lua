--[[
    client/admin.lua
    Renders the admin management menu server/calls.lua's `/emsadmin`
    command opens. All actions round-trip to the server, which re-checks
    permissions itself - this file only builds the UI.
]]

RegisterNetEvent('mozzy_ems:client:openAdminMenu', function(data)
    local options = {
        {
            title = data.generationEnabled and 'Disable Simulator' or 'Enable Simulator',
            description = ('On-duty EMS: %d'):format(data.onDutyCount),
            icon = data.generationEnabled and 'toggle-on' or 'toggle-off',
            onSelect = function()
                TriggerServerEvent('mozzy_ems:server:adminToggleGeneration')
            end,
        },
        {
            title = 'Generate Call Here',
            description = 'Choose a scenario to spawn at your current location.',
            icon = 'truck-medical',
            arrow = true,
            onSelect = function() MozzyEMS.Admin.OpenCallTypeMenu(data.callTypes) end,
        },
        {
            title = 'Active Calls',
            description = ('%d call(s) in progress'):format(#data.activeCalls),
            icon = 'list',
            arrow = true,
            onSelect = function() MozzyEMS.Admin.OpenActiveCallsMenu(data.activeCalls) end,
        },
    }

    lib.registerContext({ id = 'mozzy_ems_admin_root', title = 'EMS Simulator Admin', options = options })
    lib.showContext('mozzy_ems_admin_root')
end)

MozzyEMS.Admin = MozzyEMS.Admin or {}

function MozzyEMS.Admin.OpenCallTypeMenu(callTypes)
    local options = {}
    for _, ct in ipairs(callTypes) do
        options[#options + 1] = {
            title = ct.label,
            icon = 'stethoscope',
            onSelect = function()
                TriggerServerEvent('mozzy_ems:server:adminGenerateCall', ct.id)
            end,
        }
    end

    lib.registerContext({
        id = 'mozzy_ems_admin_calltypes',
        title = 'Select Scenario',
        menu = 'mozzy_ems_admin_root',
        options = options,
    })
    lib.showContext('mozzy_ems_admin_calltypes')
end

function MozzyEMS.Admin.OpenActiveCallsMenu(activeCalls)
    local options = {}
    if #activeCalls == 0 then
        options[1] = { title = 'No active calls', disabled = true }
    end
    for _, call in ipairs(activeCalls) do
        options[#options + 1] = {
            title = ('%s [%s]'):format(call.label, call.dispatchCode),
            description = ('State: %s | Responders: %d'):format(call.state, call.responderCount),
            icon = 'circle-info',
            arrow = true,
            onSelect = function() MozzyEMS.Admin.OpenCallActionsMenu(call) end,
        }
    end

    lib.registerContext({
        id = 'mozzy_ems_admin_active',
        title = 'Active Calls',
        menu = 'mozzy_ems_admin_root',
        options = options,
    })
    lib.showContext('mozzy_ems_admin_active')
end

function MozzyEMS.Admin.OpenCallActionsMenu(call)
    lib.registerContext({
        id = 'mozzy_ems_admin_call_actions',
        title = call.label,
        menu = 'mozzy_ems_admin_active',
        options = {
            {
                title = 'Cancel Call',
                icon = 'xmark',
                onSelect = function()
                    TriggerServerEvent('mozzy_ems:server:adminCancelCall', call.id)
                end,
            },
            {
                title = 'Delete Stuck Patient (#1)',
                description = 'Force-resolves patient 1 without payout - use if a scene is stuck.',
                icon = 'trash',
                onSelect = function()
                    TriggerServerEvent('mozzy_ems:server:adminDeletePatient', call.id, 1)
                end,
            },
        },
    })
    lib.showContext('mozzy_ems_admin_call_actions')
end
