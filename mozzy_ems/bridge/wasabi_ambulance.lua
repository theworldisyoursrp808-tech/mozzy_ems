--[[
    bridge/wasabi_ambulance.lua
    Wires Mozzy EMS Simulator to wasabi_ambulance (legacy v1) + wasabi_crutch,
    built only against their documented, non-escrowed public surface:

      wasabi_ambulance v1 exports/events:
        https://docs.wasabiscripts.com/advanced-series/wasabi-ambulance-v1/exports
      wasabi_ambulance v1 state bags:
        https://docs.wasabiscripts.com/advanced-series/wasabi-ambulance-v1/state-bags
      wasabi_crutch exports:
        https://docs.wasabiscripts.com/advanced-series/wasabi-crutch/exports

    Two integration points live here:

    1. bridge/medical.lua's existing hooks (Config.ExternalMedicalResource).
       These are deliberately left OFF for wasabi_ambulance - see the note
       below. Don't flip Config.ExternalMedicalResource to 'wasabi_ambulance'
       without reading it.

    2. Helpers used by server/real_calls.lua to hand a real-player call's
       outcome to wasabi_crutch.

    ------------------------------------------------------------------
    Why mozzy_ems's own NPC patients do NOT delegate to wasabi_ambulance's
    stretcher (Config.ExternalMedicalResource is intentionally left unset):

    wasabi_ambulance's stretcher exports (`loadStretcher`, `placeInVehicle`,
    `isPlayerUsingStretcher`) are written to operate on real networked
    players - their own documented example checks `IsPedAPlayer(ped)` /
    `NetworkGetPlayerIndexFromPed(ped)` before doing anything. Mozzy EMS's
    simulator patients are plain scene peds, not players, so those exports
    have nothing to grab onto for them. There's no supported way to route
    NPC-patient carrying through wasabi_ambulance's stretcher system - the
    two are built for different kinds of "patient". mozzy_ems's own
    lightweight built-in transport (client/transport.lua) stays in charge
    of NPC calls.

    Where wasabi_ambulance's tools DO apply cleanly is real players, which
    is exactly what server/real_calls.lua + client/real_calls.lua use them
    for (dispatching Mozzy EMS calls off wasabi_ambulance's own
    laststand/dead state, and letting wasabi_ambulance itself handle the
    actual revive/treat/stretcher work once EMS arrives).
    ------------------------------------------------------------------
]]

MozzyEMS = MozzyEMS or {}
MozzyEMS.WasabiBridge = {}

local isServer = IsDuplicityVersion()

if isServer then

    --- Is wasabi_ambulance actually running on this server?
    function MozzyEMS.WasabiBridge.AmbulanceAvailable()
        return GetResourceState('wasabi_ambulance') == 'started'
    end

    --- Is wasabi_crutch actually running on this server?
    function MozzyEMS.WasabiBridge.CrutchAvailable()
        return GetResourceState('wasabi_crutch') == 'started'
    end

    --- Reads wasabi_ambulance's documented state bag for a player.
    --- Returns 'dead' | 'laststand' | false.
    --- https://docs.wasabiscripts.com/advanced-series/wasabi-ambulance-v1/state-bags
    function MozzyEMS.WasabiBridge.GetDeathState(serverId)
        if not MozzyEMS.WasabiBridge.AmbulanceAvailable() then return false end
        local ok, state = pcall(function()
            return Player(serverId).state.dead
        end)
        if not ok or not state then return false end
        return state -- 'dead' or 'laststand'
    end

    --- Server-side revive via wasabi_ambulance's documented export.
    --- Not used by the normal real_calls flow (players are expected to be
    --- revived properly by responding EMS through wasabi_ambulance's own
    --- UI), but exposed for /emsadmin-style force-resolution.
    --- https://docs.wasabiscripts.com/advanced-series/wasabi-ambulance-v1/exports
    function MozzyEMS.WasabiBridge.ForceRevive(serverId)
        if not MozzyEMS.WasabiBridge.AmbulanceAvailable() then return false end
        local ok = pcall(function()
            exports['wasabi_ambulance']:RevivePlayer(serverId)
        end)
        return ok
    end

    --- Applies wasabi_crutch's documented server exports.
    --- https://docs.wasabiscripts.com/advanced-series/wasabi-crutch/exports
    --- Note: wasabi_crutch's Config.AllowedResources must include
    --- 'mozzy_ems' for these calls to be accepted - see
    --- config/real_calls.lua's header comment.
    function MozzyEMS.WasabiBridge.GiveCrutch(serverId, minutes)
        if not MozzyEMS.WasabiBridge.CrutchAvailable() then return false end
        local ok = pcall(function()
            exports['wasabi_crutch']:GiveCrutchTarget(serverId, minutes)
        end)
        return ok
    end

    function MozzyEMS.WasabiBridge.GiveWheelchair(serverId, minutes)
        if not MozzyEMS.WasabiBridge.CrutchAvailable() then return false end
        local ok = pcall(function()
            exports['wasabi_crutch']:GiveWheelchairTarget(serverId, minutes)
        end)
        return ok
    end
end
