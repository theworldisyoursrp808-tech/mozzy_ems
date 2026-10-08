--[[
    bridge/framework.lua
    The ONLY file that should ever call exports.qbx_core directly. If you
    ever swap frameworks, this is the one file to rewrite - nothing in
    client/ or server/ talks to qbx_core directly.
]]

MozzyEMS = MozzyEMS or {}
MozzyEMS.Framework = {}

local isServer = IsDuplicityVersion()

-----------------------------------------------------------------------------
-- SHARED HELPERS
-----------------------------------------------------------------------------

--- Returns true if the given qbx job data (job name + type) counts as EMS
--- per Config.EMSJobs / Config.EMSJobTypes
function MozzyEMS.Framework.IsEMSJob(jobName, jobType)
    if jobName and Config.EMSJobs[jobName] then return true end
    if jobType and Config.EMSJobTypes[jobType] then return true end
    return false
end

-----------------------------------------------------------------------------
-- CLIENT SIDE
-----------------------------------------------------------------------------

if not isServer then
    local playerData = nil

    RegisterNetEvent('QBCore:Player:SetPlayerData', function(data)
        playerData = data
    end)

    --- Client-side cached PlayerData accessor. Falls back to a live export
    --- call the first time in case SetPlayerData hasn't fired yet.
    function MozzyEMS.Framework.GetPlayerData()
        if playerData then return playerData end
        local ok, data = pcall(function() return exports.qbx_core:GetPlayerData() end)
        if ok then playerData = data end
        return playerData
    end

    function MozzyEMS.Framework.IsEMS()
        local pd = MozzyEMS.Framework.GetPlayerData()
        if not pd or not pd.job then return false end
        return MozzyEMS.Framework.IsEMSJob(pd.job.name, pd.job.type)
    end

    function MozzyEMS.Framework.IsOnDuty()
        local pd = MozzyEMS.Framework.GetPlayerData()
        if not pd or not pd.job then return false end
        if not Config.RequireDuty then return true end
        return pd.job.onduty == true
    end

    function MozzyEMS.Framework.CanWorkEMS()
        return MozzyEMS.Framework.IsEMS() and MozzyEMS.Framework.IsOnDuty()
    end

    function MozzyEMS.Framework.GetJobLabel()
        local pd = MozzyEMS.Framework.GetPlayerData()
        return pd and pd.job and pd.job.label or 'EMS'
    end

    function MozzyEMS.Framework.Notify(msg, notifType, duration)
        exports.qbx_core:Notify(msg, notifType or 'primary', duration)
    end
end

-----------------------------------------------------------------------------
-- SERVER SIDE
-----------------------------------------------------------------------------

if isServer then

    --- Returns the qbx player object or nil
    function MozzyEMS.Framework.GetPlayer(source)
        local ok, player = pcall(function() return exports.qbx_core:GetPlayer(source) end)
        if not ok then return nil end
        return player
    end

    function MozzyEMS.Framework.IsEMS(source)
        local player = MozzyEMS.Framework.GetPlayer(source)
        if not player then return false end
        local job = player.PlayerData.job
        return MozzyEMS.Framework.IsEMSJob(job.name, job.type)
    end

    function MozzyEMS.Framework.IsOnDuty(source)
        local player = MozzyEMS.Framework.GetPlayer(source)
        if not player then return false end
        if not Config.RequireDuty then return true end
        return player.PlayerData.job.onduty == true
    end

    --- The one gate every server handler should call before doing anything
    function MozzyEMS.Framework.CanWorkEMS(source)
        return MozzyEMS.Framework.IsEMS(source) and MozzyEMS.Framework.IsOnDuty(source)
    end

    --- Number of on-duty EMS right now, using qbx_core's own duty counter
    --- against every configured EMS job type (avoids maintaining a
    --- duplicate/inaccurate player count).
    function MozzyEMS.Framework.GetOnDutyEMSCount()
        local total, seen = 0, {}
        for jobType in pairs(Config.EMSJobTypes) do
            local ok, count, sources = pcall(function() return exports.qbx_core:GetDutyCountType(jobType) end)
            if ok and sources then
                for _, src in ipairs(sources) do
                    if not seen[src] then
                        seen[src] = true
                        total = total + 1
                    end
                end
            end
        end
        for jobName in pairs(Config.EMSJobs) do
            local ok, count, sources = pcall(function() return exports.qbx_core:GetDutyCountJob(jobName) end)
            if ok and sources then
                for _, src in ipairs(sources) do
                    if not seen[src] then
                        seen[src] = true
                        total = total + 1
                    end
                end
            end
        end
        return total
    end

    --- Source list of every currently on-duty EMS player, deduped across
    --- configured job types/names.
    function MozzyEMS.Framework.GetOnDutyEMSSources()
        local seen, list = {}, {}
        for jobType in pairs(Config.EMSJobTypes) do
            local ok, _, sources = pcall(function() return exports.qbx_core:GetDutyCountType(jobType) end)
            if ok and sources then
                for _, src in ipairs(sources) do
                    if not seen[src] then seen[src] = true; list[#list + 1] = src end
                end
            end
        end
        for jobName in pairs(Config.EMSJobs) do
            local ok, _, sources = pcall(function() return exports.qbx_core:GetDutyCountJob(jobName) end)
            if ok and sources then
                for _, src in ipairs(sources) do
                    if not seen[src] then seen[src] = true; list[#list + 1] = src end
                end
            end
        end
        return list
    end

    function MozzyEMS.Framework.GetCitizenId(source)
        local player = MozzyEMS.Framework.GetPlayer(source)
        return player and player.PlayerData.citizenid or nil
    end

    function MozzyEMS.Framework.GetPlayerName(source)
        local player = MozzyEMS.Framework.GetPlayer(source)
        if not player then return GetPlayerName(source) or ('Unit ' .. source) end
        local info = player.PlayerData.charinfo
        if info then return ('%s %s'):format(info.firstname, info.lastname) end
        return GetPlayerName(source) or ('Unit ' .. source)
    end

    --- Pays a player through the framework money system. ALWAYS server-side.
    function MozzyEMS.Framework.AddMoney(source, amount, reason)
        if amount <= 0 then return false end
        local player = MozzyEMS.Framework.GetPlayer(source)
        if not player then return false end
        local ok = pcall(function()
            player.Functions.AddMoney(Config.Payment.accountType, amount, reason or 'mozzy-ems-simulator')
        end)
        return ok
    end

    function MozzyEMS.Framework.Notify(source, msg, notifType, duration)
        TriggerClientEvent('QBCore:Notify', source, msg, notifType or 'primary', duration)
    end

    --- ACE permission / group based admin check, framework-aware.
    function MozzyEMS.Framework.IsAdmin(source)
        if Config.AdminAcePermission then
            if IsPlayerAceAllowed(source, Config.AdminAcePermission) then return true end
        end
        for group in pairs(Config.AdminGroups) do
            local ok, has = pcall(function() return exports.qbx_core:HasGroup(source, group) end)
            if ok and has then return true end
        end
        return false
    end
end
