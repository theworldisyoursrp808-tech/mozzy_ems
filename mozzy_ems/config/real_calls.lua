--[[
    config/real_calls.lua
    Settings for the "real player down" bridge (server/real_calls.lua,
    client/real_calls.lua). This is a SEPARATE, additive call type from
    Config.Calls (which are simulator-owned NPCs) - it turns an actual
    player going into last-stand/death (via wasabi_ambulance) into a
    dispatched call that flows through Mozzy EMS's own scoring/payout math,
    and hands the outcome back to wasabi_crutch when it's bad enough to
    leave a lasting injury.

    Requires:
      - wasabi_ambulance (legacy v1) running, with Config.LastStand enabled
        on its side so players actually pass through a `laststand` state
        instead of dying outright.
      - wasabi_crutch running, and 'mozzy_ems' added to its
        Config.AllowedResources if Config.RealCalls.LastingInjury.enabled
        is true (see bridge/wasabi_ambulance.lua for the exact line).

    This module never touches wasabi_ambulance's or wasabi_crutch's own
    files - it only calls their documented exports
    (docs.wasabiscripts.com/advanced-series/wasabi-ambulance-v1/exports and
    .../wasabi-crutch/exports) and reads their documented state bag
    (`Player(id).state.dead`). Their internal logic is escrow-protected and
    was never read to build this.
]]

Config = Config or {}

Config.RealCalls = {
    enabled = true,

    -- How often (ms) the server scans for players who have gone down.
    -- Cheap: it's one state-bag read per connected player, no natives.
    pollInterval = 3000,

    -- Same duty gate as simulator calls.
    minimumEMS = 1,

    -- How long (seconds) a downed player has to be revived before the
    -- call auto-closes as unresolved (no payout, no lasting-injury roll -
    -- assume someone off-duty or a non-EMS player handled it).
    responseTimeout = 900,

    -- Once a given player has generated a real call, ignore further
    -- laststand/dead transitions from them for this many seconds. Stops a
    -- player who's repeatedly knocked out in a firefight from spamming
    -- dispatch with a new call every few seconds.
    cooldownPerPlayer = 180,

    dispatchCode = '10-52D',
    label = 'Person Down',
    priority = 1, -- indexes Config.Payment.severityMultiplier / Config.Experience.severityMultiplier same as simulator calls

    -- Reward math reuses MozzyEMS.Rewards.Calculate(), which reads these
    -- two fields off the synthetic call it's handed.
    reward = { min = 150, max = 300 },

    -- If true, calls generate for ANY player going down, not just ones on
    -- an EMS job (so EMS can be dispatched to treat civilians/each other,
    -- same as wasabi_ambulance's own distress system). Set false if you'd
    -- rather leave civilian-on-civilian revives entirely to
    -- wasabi_ambulance and only use this for a narrower use case.
    anyPlayer = true,

    -- What happens to the real patient once they're back on their feet,
    -- via wasabi_crutch. Only fires on a successful revive within
    -- responseTimeout - a call that times out unresolved never rolls this.
    LastingInjury = {
        enabled = true,

        -- If the player's state ever reached the full `dead` stage
        -- (not just `laststand`) before being revived, they're assumed to
        -- have gone into cardiac arrest / bled out fully - give them a
        -- wheelchair rather than just a limp.
        wheelchairIfFullyDied = true,
        wheelchairMinutes = 15,

        -- Otherwise, if EMS took longer than this to get them stabilized,
        -- leave them on crutches for a while as a lingering consequence.
        crutchThresholdSeconds = 240,
        crutchMinutes = 10,
    },
}
