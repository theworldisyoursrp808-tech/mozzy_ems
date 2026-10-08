--[[
    server/database.lua
    All persistence is optional (Config.Database.enabled) and isolated here.
    Every other server file calls MozzyEMS.DB.* and never touches MySQL
    directly, so turning persistence off just makes these into no-ops.
]]

MozzyEMS = MozzyEMS or {}
MozzyEMS.DB = {}

local enabled = Config.Database.enabled

CreateThread(function()
    if not enabled then return end
    if GetResourceState('oxmysql') ~= 'started' then
        print('^1[mozzy_ems]^7 oxmysql is not running - disabling database persistence.')
        enabled = false
        return
    end
end)

--- Gets (creating if necessary) a citizen's simulator profile row.
function MozzyEMS.DB.GetOrCreateProfile(citizenId, cb)
    if not enabled or not citizenId then return cb(nil) end
    MySQL.single('SELECT * FROM mozzy_ems_profiles WHERE citizenid = ?', { citizenId }, function(row)
        if row then return cb(row) end
        MySQL.insert('INSERT INTO mozzy_ems_profiles (citizenid, xp, total_calls, successful_calls, failed_calls, patients_saved, patients_lost) VALUES (?, 0, 0, 0, 0, 0, 0)',
            { citizenId }, function()
                cb({ citizenid = citizenId, xp = 0, total_calls = 0, successful_calls = 0, failed_calls = 0, patients_saved = 0, patients_lost = 0 })
            end)
    end)
end

--- Applies a completed-call delta to a citizen's profile.
function MozzyEMS.DB.ApplyCallResult(citizenId, result)
    if not enabled or not citizenId then return end
    MySQL.update([[
        UPDATE mozzy_ems_profiles SET
            xp = xp + ?,
            total_calls = total_calls + 1,
            successful_calls = successful_calls + ?,
            failed_calls = failed_calls + ?,
            patients_saved = patients_saved + ?,
            patients_lost = patients_lost + ?
        WHERE citizenid = ?
    ]], {
        result.xpGained or 0,
        result.success and 1 or 0,
        result.success and 0 or 1,
        result.patientSaved and 1 or 0,
        result.patientSaved and 0 or 1,
        citizenId,
    })
end

--- Records one row of call history (viewable via /emscall history or the
--- admin menu). Keep this cheap - it's a log, not a hot path.
function MozzyEMS.DB.LogCall(entry)
    if not enabled then return end
    MySQL.insert([[
        INSERT INTO mozzy_ems_call_history
            (call_type, priority, medic_citizenid, medic_name, outcome, response_time, treatments_correct, treatments_incorrect, transported, payment, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
    ]], {
        entry.callType, entry.priority, entry.citizenId, entry.medicName, entry.outcome,
        entry.responseTime, entry.correctTreatments, entry.incorrectTreatments,
        entry.transported and 1 or 0, entry.payment,
    })
end

function MozzyEMS.DB.GetRecentHistory(citizenId, limit, cb)
    if not enabled then return cb({}) end
    limit = limit or 10
    MySQL.query('SELECT * FROM mozzy_ems_call_history WHERE medic_citizenid = ? ORDER BY created_at DESC LIMIT ?',
        { citizenId, limit }, function(rows) cb(rows or {}) end)
end
