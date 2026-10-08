--[[
    server/rewards.lua (server-only)
    All payment math happens here, server-side, based only on server-known
    state (call config + patient outcome). Never trust a client-supplied
    reward value.
]]

MozzyEMS = MozzyEMS or {}
MozzyEMS.Rewards = {}

local Utils = MozzyEMS.Utils

--- Computes { money, xp } for one responder on a completed call.
--- outcome fields expected on `patient`: correctTreatments, incorrectTreatments,
--- resuscitated (bool|nil), transported (bool), outcome ('stabilized'|'deceased')
function MozzyEMS.Rewards.Calculate(call, patient, isPrimary)
    if call.training then
        return { money = 0, xp = 0 }
    end

    local cfg = call.realConfig
    local severityMult = Config.Payment.severityMultiplier[call.priority] or 1.0
    local xpSeverityMult = Config.Experience.severityMultiplier[call.priority] or 1.0

    local baseReward = cfg.reward and Utils.RandomInt(cfg.reward.min, cfg.reward.max) or Config.Payment.base
    local money = 0
    local xp = 0

    if Config.Payment.enabled then
        money = math.floor(baseReward * severityMult)
        money = money + (patient.correctTreatments * Config.Payment.correctTreatmentBonus)
        money = money - (patient.incorrectTreatments * Config.Payment.incorrectTreatmentPenalty)
        if patient.transported then money = money + Config.Payment.transportBonus end
        if patient.resuscitated then money = money + Config.Payment.successfulResuscitationBonus end
        money = math.max(0, money)
        -- non-primary responders (assisted but didn't lead) receive a reduced share
        if not isPrimary then money = math.floor(money * 0.6) end
    end

    if Config.Experience.enabled then
        xp = math.floor(Config.Experience.baseXP * xpSeverityMult)
        if patient.transported then xp = xp + Config.Experience.transportBonus end
        if patient.resuscitated then xp = xp + Config.Experience.resuscitationBonus end
        if not isPrimary then xp = math.floor(xp * 0.6) end
    end

    return { money = money, xp = xp }
end

--- Resolves an XP total to a simulator rank label.
function MozzyEMS.Rewards.GetLevel(xp)
    local levels = Config.Experience.levels
    local current = levels[1]
    for _, lvl in ipairs(levels) do
        if xp >= lvl.xp then current = lvl end
    end
    return current.name
end

--- Pays out and applies DB/XP for every responder on a call once it's done.
--- `patient` is the single patient this reward pass concerns (call one per
--- patient on multi-patient calls).
function MozzyEMS.Rewards.Payout(call, patient)
    for source in pairs(call.responders) do
        local isPrimary = (source == call.primaryResponder)
        local result = MozzyEMS.Rewards.Calculate(call, patient, isPrimary)

        if result.money > 0 then
            MozzyEMS.Framework.AddMoney(source, result.money, 'mozzy-ems-simulator')
        end

        local citizenId = MozzyEMS.Framework.GetCitizenId(source)
        if citizenId and Config.Database.enabled then
            MozzyEMS.DB.ApplyCallResult(citizenId, {
                xpGained = result.xp,
                success = patient.outcome ~= 'deceased',
                patientSaved = patient.outcome ~= 'deceased',
            })
            MozzyEMS.DB.LogCall({
                callType = call.realType,
                priority = call.priority,
                citizenId = citizenId,
                medicName = MozzyEMS.Framework.GetPlayerName(source),
                outcome = patient.outcome or 'unresolved',
                responseTime = call.responseTime,
                correctTreatments = patient.correctTreatments,
                incorrectTreatments = patient.incorrectTreatments,
                transported = patient.transported or false,
                payment = result.money,
            })
        end

        TriggerClientEvent(MozzyEMS.Events.CallComplete, source, {
            callId = call.id,
            outcome = patient.outcome,
            money = result.money,
            xp = result.xp,
            responseTime = call.responseTime,
            correctTreatments = patient.correctTreatments,
            incorrectTreatments = patient.incorrectTreatments,
            transported = patient.transported or false,
            resuscitated = patient.resuscitated or false,
        })
    end

    if Config.Webhook.enabled and Config.Webhook.events.callCompleted then
        MozzyEMS.Webhook.Send('callCompleted', ('Call `%s` (%s) completed - outcome: **%s**'):format(call.id, call.realType, patient.outcome or 'unresolved'))
    end
    if patient.outcome == 'deceased' and Config.Webhook.enabled and Config.Webhook.events.patientDied then
        MozzyEMS.Webhook.Send('patientDied', ('Patient died on call `%s` (%s)'):format(call.id, call.realType))
    end
end
