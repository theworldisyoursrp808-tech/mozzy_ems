--[[
    server/real_calls.lua (server-only)
    Turns a real player going down (via wasabi_ambulance's `laststand`/`dead`
    state) into a Mozzy EMS dispatch call, and pays out through the same
    reward math as simulator calls once they're revived. On a bad enough
    outcome, hands them to wasabi_crutch for a lasting injury.

    This is intentionally a SEPARATE lifecycle from server/calls.lua's NPC
    engine - it never touches Config.Calls, never spawns a scene ped, and
    uses its own event names so it can't collide with or destabilize the
    simulator's existing accept/spawn/treat pipeline. See
    bridge/wasabi_ambulance.lua for why.
]]

MozzyEMS = MozzyEMS or {}
MozzyEMS.RealCalls = { active = {} } -- [callId] = runtime record, see below

local Utils = MozzyEMS.Utils

local REAL_OFFER_EVENT     = 'mozzy_ems:real:offer'
local REAL_ACCEPT_EVENT    = 'mozzy_ems:real:accept'
local REAL_ACCEPTED_EVENT  = 'mozzy_ems:real:accepted'
local REAL_CLOSED_EVENT    = 'mozzy_ems:real:closed'
local REAL_COMPLETE_EVENT  = 'mozzy_ems:real:complete'

local cooldowns = {} -- [serverId] = os.time() they can next trigger a call

--- Builds the synthetic call/patient shape MozzyEMS.Rewards.Calculate()
--- expects, without touching Config.Calls at all.
local function buildRewardInputs(record)
    local call = {
        training = false,
        realConfig = { reward = Config.RealCalls.reward },
        priority = Config.RealCalls.priority,
    }
    local patient = {
        correctTreatments = 0,
        incorrectTreatments = 0,
        transported = false, -- transport, if any, happened inside wasabi_ambulance, not tracked here
        resuscitated = record.wasEverFullyDead == true,
        outcome = 'stabilized',
    }
    return call, patient
end

local function closeCall(callId, reason)
    local record = MozzyEMS.RealCalls.active[callId]
    if not record then return end
    MozzyEMS.RealCalls.active[callId] = nil

    for src in pairs(record.offeredTo or {}) do
        TriggerClientEvent(REAL_CLOSED_EVENT, src, callId)
    end
end

local function completeCall(callId)
    local record = MozzyEMS.RealCalls.active[callId]
    if not record then return end

    local responseTime = os.time() - record.startedAt
    local responderCount = 0
    for _ in pairs(record.responders) do responderCount = responderCount + 1 end

    if responderCount > 0 then
        local call, patient = buildRewardInputs(record)
        for src in pairs(record.responders) do
            local isPrimary = (src == record.primaryResponder)
            local result = MozzyEMS.Rewards.Calculate(call, patient, isPrimary)

            if result.money > 0 then
                MozzyEMS.Framework.AddMoney(src, result.money, 'mozzy-ems-real-call')
            end

            TriggerClientEvent(REAL_COMPLETE_EVENT, src, {
                callId = callId,
                label = Config.RealCalls.label,
                targetName = MozzyEMS.Framework.GetPlayerName(record.target) or ('player ' .. record.target),
                money = result.money,
                xp = result.xp,
                responseTime = responseTime,
            })
        end
    end

    -- Lasting-injury roll: only on a real revive within the timeout, never
    -- on an unresolved/expired call.
    local li = Config.RealCalls.LastingInjury
    if li and li.enabled then
        if li.wheelchairIfFullyDied and record.wasEverFullyDead then
            MozzyEMS.WasabiBridge.GiveWheelchair(record.target, li.wheelchairMinutes)
        elseif li.crutchThresholdSeconds and responseTime >= li.crutchThresholdSeconds then
            MozzyEMS.WasabiBridge.GiveCrutch(record.target, li.crutchMinutes)
        end
    end

    closeCall(callId, 'completed')
end

--- EMS accepts a real-player call offer.
RegisterNetEvent(REAL_ACCEPT_EVENT, function(callId)
    local src = source
    local record = MozzyEMS.RealCalls.active[callId]
    if not record then return end -- already closed/timed out
    if not MozzyEMS.Framework.CanWorkEMS(src) or not MozzyEMS.Framework.IsOnDuty(src) then return end

    record.responders[src] = true
    record.primaryResponder = record.primaryResponder or src

    local targetPed = GetPlayerPed(record.target)
    local coords = targetPed and targetPed ~= 0 and GetEntityCoords(targetPed) or record.coords

    TriggerClientEvent(REAL_ACCEPTED_EVENT, src, {
        callId = callId,
        label = Config.RealCalls.label,
        dispatchCode = Config.RealCalls.dispatchCode,
        coords = coords,
    })
end)

--- Main poll loop: scan connected players' wasabi_ambulance death state,
--- open/track/resolve real calls off it.
CreateThread(function()
    if not Config.RealCalls.enabled then return end

    while true do
        Wait(Config.RealCalls.pollInterval)

        if MozzyEMS.WasabiBridge.AmbulanceAvailable()
            and MozzyEMS.Framework.GetOnDutyEMSCount() >= (Config.RealCalls.minimumEMS or 1) then

            local now = os.time()

            -- 1) Look for new distress: any connected player currently
            --    down who isn't already the target of an active call and
            --    isn't on cooldown.
            local alreadyTargeted = {}
            for _, record in pairs(MozzyEMS.RealCalls.active) do
                alreadyTargeted[record.target] = true
            end

            for _, playerIdStr in ipairs(GetPlayers()) do
                local playerId = tonumber(playerIdStr)
                if playerId and not alreadyTargeted[playerId] then
                    local onCooldown = cooldowns[playerId] and cooldowns[playerId] > now
                    local eligible = Config.RealCalls.anyPlayer or MozzyEMS.Framework.CanWorkEMS(playerId)

                    if not onCooldown and eligible then
                        local state = MozzyEMS.WasabiBridge.GetDeathState(playerId)
                        if state == 'dead' or state == 'laststand' then
                            local ped = GetPlayerPed(playerId)
                            if ped and ped ~= 0 then
                                local callId = Utils.GenerateCallId()
                                local coords = GetEntityCoords(ped)

                                local call = {
                                    id = callId,
                                    label = Config.RealCalls.label,
                                    dispatchCode = Config.RealCalls.dispatchCode,
                                    priority = Config.RealCalls.priority,
                                    coords = coords,
                                    narrative = ('Reported unresponsive player near your position.'),
                                }

                                local recipients = MozzyEMS.Framework.GetOnDutyEMSSources()
                                local offeredTo = {}
                                for _, r in ipairs(recipients) do offeredTo[r] = true end

                                MozzyEMS.RealCalls.active[callId] = {
                                    target = playerId,
                                    coords = coords,
                                    startedAt = now,
                                    wasEverFullyDead = (state == 'dead'),
                                    responders = {},
                                    primaryResponder = nil,
                                    offeredTo = offeredTo,
                                }
                                cooldowns[playerId] = now + (Config.RealCalls.cooldownPerPlayer or 180)

                                for _, r in ipairs(recipients) do
                                    TriggerClientEvent(REAL_OFFER_EVENT, r, call)
                                end
                            end
                        end
                    end
                end
            end

            -- 2) Resolve every currently-active real call: revived, still
            --    down (escalate to fully-dead tracking), or timed out.
            for callId, record in pairs(MozzyEMS.RealCalls.active) do
                local state = MozzyEMS.WasabiBridge.GetDeathState(record.target)

                if state == 'dead' then
                    record.wasEverFullyDead = true
                end

                if not state then
                    -- back on their feet
                    completeCall(callId)
                elseif (now - record.startedAt) >= (Config.RealCalls.responseTimeout or 900) then
                    closeCall(callId, 'timeout')
                end
            end
        end
    end
end)

--- Clean up any call targeting a player who disconnects mid-call.
AddEventHandler('playerDropped', function()
    local src = source
    for callId, record in pairs(MozzyEMS.RealCalls.active) do
        if record.target == src then
            closeCall(callId, 'target_dropped')
        end
    end
end)
