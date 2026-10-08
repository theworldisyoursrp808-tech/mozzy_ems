--[[
    client/patients.lua
    Spawns/despawns the simulator NPC ped(s) and light scene dressing for an
    accepted call. Kept deliberately simple and low-entity-count per the
    performance requirements - one ped per patient, a handful of props max.
]]

MozzyEMS = MozzyEMS or {}
MozzyEMS.Patients = {}

local ANIM_MAP = {
    -- Switched from named scenarios ('CODE_HUMAN_MEDIC_TIME_OF_DEATH',
    -- 'WORLD_HUMAN_BUM_SLUMPED') to a forced ragdoll collapse. Both of those
    -- scenario names turned out unreliable - a ragdoll can't be "wrong" the
    -- same way, since it's pure physics: SetPedToRagdoll always makes the
    -- ped fall and settle on the ground under gravity, regardless of
    -- location or what's nearby. See collapseToGround() below.
    lying_injured      = { ragdollDown = true },
    lying_unconscious  = { ragdollDown = true },
    sitting_injured    = { ragdollDown = true },
    seizure            = { ragdollLoop = true },
}

--- Loads a model and returns (hash, loaded). Longer timeout and a fast-fail
--- IsModelInCdimage check compared to before - the previous 5s timeout was
--- fine on a quiet local test server but could legitimately not be enough
--- on a live server under real asset-streaming load, and there was no
--- fallback when it wasn't: the patient just silently never spawned.
local function loadModel(model)
    local hash = type(model) == 'string' and joaat(model) or model

    if not IsModelInCdimage(hash) then
        return hash, false
    end

    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 15000 do
        Wait(50)
        timeout = timeout + 50
    end
    return hash, HasModelLoaded(hash)
end

-- Guaranteed-valid fallback model used if a call's configured ped model
-- fails to load at all - better to spawn something than nothing.
local FALLBACK_PED_MODEL = 'a_m_m_business_01'

--- Forces a ragdoll collapse and then KEEPS the ped in ragdoll - a one-shot
--- ragdoll-then-freeze didn't stick: FreezeEntityPosition only locks the
--- root coordinate, not the pose, so once the ragdoll timer ran out the
--- ped's default AI would stand back up in place, still frozen at the same
--- spot but visually upright again. Checking IsPedRagdoll and re-triggering
--- whenever it lapses (the same pattern the seizure loop already uses
--- successfully) keeps it down for good instead.
local function collapseToGround(ped)
    CreateThread(function()
        if not DoesEntityExist(ped) then return end
        SetPedToRagdoll(ped, 3000, 3000, 0, false, false, false)
        while DoesEntityExist(ped) do
            Wait(1000)
            if DoesEntityExist(ped) and not IsPedRagdoll(ped) then
                SetPedToRagdoll(ped, 3000, 3000, 0, false, false, false)
            end
        end
    end)
end

--- Toggling ragdoll on/off in short bursts is a reliable, native-only way
--- to make a ped visibly convulse without depending on a specific anim
--- dict/clip pairing being correct.
local function startSeizureLoop(ped)
    CreateThread(function()
        while DoesEntityExist(ped) do
            SetPedToRagdoll(ped, 400, 600, 0, false, false, false)
            Wait(1200)
            if not DoesEntityExist(ped) then break end
            Wait(900)
        end
    end)
end

local function applyPatientAnimation(ped, animation)
    local def = ANIM_MAP[animation]
    if not def then return end

    if def.ragdollDown then
        collapseToGround(ped)
        return
    end

    if def.ragdollLoop then
        startSeizureLoop(ped)
        return
    end

    if def.scenario then
        TaskStartScenarioInPlace(ped, def.scenario, 0, true)
        SetPedKeepTask(ped, true) -- stops ambient AI from standing the ped back up
        return
    end

    if def.dict then
        RequestAnimDict(def.dict)
        local timeout = 0
        while not HasAnimDictLoaded(def.dict) and timeout < 3000 do
            Wait(50)
            timeout = timeout + 50
        end
        TaskPlayAnim(ped, def.dict, def.clip, 8.0, -8.0, -1, def.flag or 1, 0, false, false, false)
        SetPedKeepTask(ped, true)
    end
end

--- Spawns every patient ped for a call and reports their network ids back
--- to the server so the call registry can validate distance/ownership.
function MozzyEMS.Patients.SpawnScene(callId, coords, patientsData, scene)
    for _, p in ipairs(patientsData) do
        local hash, loaded = loadModel(p.model)

        if not loaded then
            print(('^1[mozzy_ems]^7 Patient model "%s" failed to load for call %s - falling back to %s.'):format(p.model, callId, FALLBACK_PED_MODEL))
            hash, loaded = loadModel(FALLBACK_PED_MODEL)
        end

        if not loaded then
            -- Even the guaranteed-safe fallback failed to load - something
            -- is genuinely wrong (streaming, disk, or a resource conflict),
            -- not just an unlucky model name. Make this loud instead of a
            -- silently missing patient.
            print(('^1[mozzy_ems]^7 Could not spawn a patient ped for call %s (index %d) - even the fallback model failed to load. Skipping this patient.'):format(callId, p.index))
            lib.notify({
                description = 'A patient failed to spawn for this call - check the F8 console.',
                type = 'error',
            })
        else
            local offsetX = (p.index - 1) * 1.2
            local ped = CreatePed(4, hash, coords.x + offsetX, coords.y, coords.z, coords.w or 0.0, true, true)

            if not DoesEntityExist(ped) then
                -- CreatePed can fail even with a loaded model (entity limits,
                -- OneSync scope issues, etc.) - retry once before giving up.
                Wait(500)
                ped = CreatePed(4, hash, coords.x + offsetX, coords.y, coords.z, coords.w or 0.0, true, true)
            end

            if not DoesEntityExist(ped) then
                print(('^1[mozzy_ems]^7 CreatePed failed for call %s (index %d) after retrying - patient will not appear.'):format(callId, p.index))
                lib.notify({
                    description = 'A patient failed to spawn for this call - check the F8 console.',
                    type = 'error',
                })
            else
                SetEntityAsMissionEntity(ped, true, true)
                SetBlockingOfNonTemporaryEvents(ped, true)
                SetPedCanRagdoll(ped, true)
                SetPedDiesWhenInjured(ped, false)
                SetEntityInvincible(ped, true) -- the "patient" isn't meant to be shootable/killable by players
                FreezeEntityPosition(ped, false)

                applyPatientAnimation(ped, p.animation)
                SetModelAsNoLongerNeeded(hash)

                local key = callId .. '_' .. p.index
                MozzyEMS.State.peds[key] = ped

                local netId = NetworkGetNetworkIdFromEntity(ped)
                TriggerServerEvent(MozzyEMS.Events.RegisterPatientPed, callId, p.index, netId)

                MozzyEMS.Target.AddPatientTarget(ped, callId, p.index)
            end
        end
    end

    MozzyEMS.Patients.SpawnSceneProps(callId, coords, scene or {})
end

local sceneProps = {} -- [callId] = { propHandle, ... }

function MozzyEMS.Patients.SpawnSceneProps(callId, coords, scene)
    sceneProps[callId] = sceneProps[callId] or {}
    local created = 0
    local maxProps = Config.Scene.maxSceneProps

    local function tryProp(chance, model, offset)
        if created >= maxProps then return end
        if math.random() > chance then return end
        local hash, loaded = loadModel(model)
        if not loaded then return end
        local prop = CreateObject(hash, coords.x + offset.x, coords.y + offset.y, coords.z, true, true, false)
        PlaceObjectOnGroundProperly(prop)
        SetModelAsNoLongerNeeded(hash)
        table.insert(sceneProps[callId], prop)
        created = created + 1
    end

    if scene.bloodProp ~= false then
        tryProp(Config.Scene.bloodPropChance, `prop_blood_pool_01`, { x = 0.3, y = 0.2 })
    end
    if scene.vehicle then
        tryProp(Config.Scene.vehicleDebrisChance, `prop_roadcone02a`, { x = -1.5, y = 0.5 })
        tryProp(Config.Scene.vehicleDebrisChance, `prop_roadcone02a`, { x = 1.5, y = -0.5 })
    end
    if scene.drugProp then
        tryProp(Config.Scene.drugPropChance, `prop_drug_package`, { x = -0.4, y = 0.4 })
    end

    if math.random() <= Config.Scene.bystanderChance and #Config.CallLocations > 0 then
        MozzyEMS.Patients.SpawnBystander(callId, coords)
    end
end

function MozzyEMS.Patients.SpawnBystander(callId, coords)
    local hash, loaded = loadModel('a_m_y_business_01')
    if not loaded then return end
    local ped = CreatePed(4, hash, coords.x - 1.5, coords.y - 1.5, coords.z, 0.0, true, true)
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityInvincible(ped, true)
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
    SetModelAsNoLongerNeeded(hash)

    sceneProps[callId] = sceneProps[callId] or {}
    table.insert(sceneProps[callId], ped)

    local activeCall = MozzyEMS.State.activeCalls[callId]
    local lines = activeCall and activeCall.bystanderLines
    MozzyEMS.Target.AddBystanderTarget(ped, lines)
end

function MozzyEMS.Patients.DespawnAll(callId)
    for key, ped in pairs(MozzyEMS.State.peds) do
        if key:sub(1, #callId + 1) == callId .. '_' then
            if DoesEntityExist(ped) then DeleteEntity(ped) end
            MozzyEMS.State.peds[key] = nil
        end
    end

    if sceneProps[callId] then
        for _, ent in ipairs(sceneProps[callId]) do
            if DoesEntityExist(ent) then DeleteEntity(ent) end
        end
        sceneProps[callId] = nil
    end
end
