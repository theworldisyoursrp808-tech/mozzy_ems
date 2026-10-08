Config = Config or {}

-----------------------------------------------------------------------------
-- FRAMEWORK / JOBS
-----------------------------------------------------------------------------

-- Job names that are allowed to work Mozzy EMS Simulator calls.
-- Checked in addition to / instead of job type below, whichever the
-- server-side check finds first. Keep both configurable so servers with
-- multiple EMS departments (ambulance, county_ems, ...) all work.
Config.EMSJobs = {
    ambulance = true,
}

-- Job "type" (qbx_core shared/jobs.lua job.type field) that counts as EMS.
-- The reference qbx_core defines `ambulance` with type = 'ems'.
Config.EMSJobTypes = {
    ems = true,
}

-- If true, a player must be on-duty (PlayerData.job.onduty) to receive
-- calls, accept calls, or use medical treatment options.
Config.RequireDuty = true

-----------------------------------------------------------------------------
-- DYNAMIC CALL GENERATION
-----------------------------------------------------------------------------

Config.CallGeneration = {
    enabled = true,
    minInterval = 300,          -- seconds, minimum time between auto-generated calls
    maxInterval = 900,          -- seconds, maximum time between auto-generated calls
    minimumEMS = 1,             -- minimum on-duty EMS required before calls generate
    maximumActiveCalls = 3,     -- hard cap on concurrent simulator calls
    callExpiration = 900,       -- seconds an unassigned call stays open before it expires
    -- once a location has hosted a call, it won't be picked again for this long
    locationCooldown = 600,
    -- once a scenario type has fired, it won't be picked again for this long
    -- (0 = no cooldown). Prevents "3 overdoses in a row".
    scenarioCooldown = 240,
    -- if true, dispatch may pick the same scenario back-to-back once cooldowns
    -- above expire; if false, the generator actively avoids repeating the
    -- previous call's exact type where any other option is available
    allowImmediateRepeat = false,
}

-----------------------------------------------------------------------------
-- MANUAL / ADMIN CALL GENERATION
-----------------------------------------------------------------------------

Config.AdminCommand = 'emscall'          -- /emscall [callType]
Config.TrainingCommand = 'emstraining'   -- /emstraining
Config.AdminMenuCommand = 'emsadmin'     -- /emsadmin

-- ACE permission required for admin commands / admin menu. Set to false to
-- instead fall back to qbx_core group check (Config.AdminGroups below).
Config.AdminAcePermission = 'mozzy_ems.admin'

-- Used only if Config.AdminAcePermission is false, or as an additional
-- allow-list checked via exports.qbx_core:HasGroup / HasPermission.
Config.AdminGroups = {
    admin = true,
    god = true,
}

-----------------------------------------------------------------------------
-- DIFFICULTY
-----------------------------------------------------------------------------

-- 'easy' | 'normal' | 'hard'
Config.Difficulty = 'normal'

-- When true, the Patient Assessment screen includes a "Suggested
-- Treatments" line listing the actually-correct treatments for whatever
-- this patient's real condition is (computed server-side from
-- validTreatments - the client is never told the answer key directly,
-- only shown this hint text when it asks to assess the patient).
-- Turn this off once you want EMS to work it out from vitals/injuries
-- alone instead of being told outright.
Config.ShowTreatmentHints = true

Config.DifficultySettings = {
    easy = {
        revealDiagnosisHint = true,   -- show a soft hint of the likely condition
        deteriorationMultiplier = 0.5,
        complicationChance = 0.05,
        vitalsPrecision = 'exact',     -- exact vs rounded/vague
    },
    normal = {
        revealDiagnosisHint = false,
        deteriorationMultiplier = 1.0,
        complicationChance = 0.15,
        vitalsPrecision = 'exact',
    },
    hard = {
        revealDiagnosisHint = false,
        deteriorationMultiplier = 1.5,
        complicationChance = 0.30,
        vitalsPrecision = 'rounded',
    },
}

-----------------------------------------------------------------------------
-- MULTIPLE RESPONDERS / CLAIMING
-----------------------------------------------------------------------------

-- 'open'   -> any EMS can respond to any unassigned call, multiple allowed
-- 'claim'  -> first EMS to accept becomes primary; others may still join
Config.CallClaimMode = 'claim'
Config.AllowMultipleResponders = true
Config.MaxRespondersPerCall = 4
Config.MaxPatientsPerCall = 5

-----------------------------------------------------------------------------
-- PAYMENT
-----------------------------------------------------------------------------

Config.Payment = {
    enabled = true,
    base = 500,
    severityMultiplier = {
        [1] = 2.0, -- critical
        [2] = 1.5, -- serious
        [3] = 1.0, -- stable
    },
    transportBonus = 250,
    successfulResuscitationBonus = 500,
    correctTreatmentBonus = 25,      -- per correct treatment, capped by call config
    incorrectTreatmentPenalty = 25,  -- deducted per wrong treatment, floor 0
    -- money type given via bridge/framework.lua AddMoney(source, type, amount)
    accountType = 'bank',
}

-----------------------------------------------------------------------------
-- XP / REPUTATION
-----------------------------------------------------------------------------

Config.Experience = {
    enabled = true,
    baseXP = 25,
    severityMultiplier = {
        [1] = 2.0,
        [2] = 1.5,
        [3] = 1.0,
    },
    transportBonus = 10,
    resuscitationBonus = 20,
    -- simulator progression only - never touches the player's actual QBX
    -- job grade unless you explicitly wire that up in bridge/framework.lua
    levels = {
        { name = 'EMT',                  xp = 0 },
        { name = 'EMT Advanced',         xp = 500 },
        { name = 'Paramedic',            xp = 1500 },
        { name = 'Senior Paramedic',     xp = 3500 },
        { name = 'Critical Care Medic',  xp = 7000 },
    },
}

-----------------------------------------------------------------------------
-- TRAINING MODE
-----------------------------------------------------------------------------

Config.Training = {
    payout = false,       -- training calls pay nothing by default
    grantXP = false,      -- and grant no XP
    countsInStats = false,
}

-----------------------------------------------------------------------------
-- MASS CASUALTY / TRIAGE (training-oriented, off by default)
-----------------------------------------------------------------------------

Config.MassCasualty = {
    enabled = true,
    minPatients = 3,
    maxPatients = 10,
    adminOnly = true, -- mass casualty events are only ever admin/training-triggered
}

-----------------------------------------------------------------------------
-- SCENE / PROPS
-----------------------------------------------------------------------------

Config.Scene = {
    bystanderChance = 0.5,
    bloodPropChance = 0.6,
    drugPropChance = 0.4,     -- only rolled for drug-related call types
    vehicleDebrisChance = 0.5, -- only rolled for vehicle-related call types
    maxSceneProps = 6,
}

-----------------------------------------------------------------------------
-- BLIPS / DISPATCH DISPLAY
-----------------------------------------------------------------------------

Config.Blips = {
    approximateBeforeArrival = true,
    approximateRadius = 60.0,     -- meters, fuzzy blip radius shown pre-arrival
    revealDistance = 25.0,        -- meters from real coords before exact blip shows
    sprite = 61,
    colorByPriority = {
        [1] = 1, -- red
        [2] = 5, -- yellow
        [3] = 3, -- blue
    },
}

-----------------------------------------------------------------------------
-- DEBUG / LOGGING
-----------------------------------------------------------------------------

Config.Debug = false

Config.Webhook = {
    enabled = true,
    url = 'https://ptb.discord.com/api/webhooks/1545287089615142953/eXwc4K-wBdRFM6DzFThbfEREV-BkxQHqDob7_arCEbd5dO4C8uXseUqKM8v9OGaJEfZW', -- Discord webhook URL
    events = {
        callGenerated = true,
        callAccepted = true,
        callCompleted = true,
        patientDied = true,
        rewardIssued = true,
        adminCreatedCall = true,
        exploitAttempt = true,
    },
    username = 'Mozzy EMS Simulator',
}

-----------------------------------------------------------------------------
-- DATABASE
-----------------------------------------------------------------------------

Config.Database = {
    enabled = true, -- set false to run fully in-memory with no persistence
}

-----------------------------------------------------------------------------
-- VEHICLES
-----------------------------------------------------------------------------

-- Only these vehicle models/spawn names count as valid transport for
-- "patient delivered by ambulance" logic in bridge/medical.lua
Config.Ambulances = {
    `ambulance`,
    `ambulance2`,
    `emsnspeedo`,
}

-----------------------------------------------------------------------------
-- DISPATCH / MEDICAL BRIDGE SELECTION
-----------------------------------------------------------------------------

-- 'standalone' | 'lb' | 'custom'  (see bridge/dispatch.lua)
Config.Dispatch = 'lb'

-- name of an external ambulance/EMS gameplay resource to bridge treatment /
-- revive / stretcher hooks into, or false to use the built-in basic system.
-- see bridge/medical.lua
Config.ExternalMedicalResource = false
