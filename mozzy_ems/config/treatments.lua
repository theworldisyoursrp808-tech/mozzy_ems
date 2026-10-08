--[[
    Config.Treatments - every treatment action EMS can perform. Call configs
    (config/calls.lua) reference these ids in `validTreatments` /
    `treatmentEffects`. Adding a brand new treatment here makes it available
    to any call config that lists it - no client/server code changes needed.

    item = key into Config.Items, or nil if no item is required (e.g. CPR).
    duration = progress bar length in ms.

    anim = optional { dict, clip }. Most treatments below use
    'mp_common'/'givetake1_a' - the animation the base game itself uses for
    handing an item to another character, and one of the most heavily reused
    anim pairs in the whole FiveM ecosystem, so confidence here is
    meaningfully higher than a one-off guess. CPR uses its own dedicated
    animation instead. Still worth confirming in-game: if lib.progressCircle
    ever throws "attempted to load invalid animDict" again, just delete that
    treatment's `anim` line - everything still works with no anim at all,
    it just won't force a pose while the progress bar runs.
]]

Config.Treatments = {
    assess_scene = {
        label = 'Scene Assessment', category = 'assessment',
        item = nil, duration = 2000,
        anim = { dict = 'mp_common', clip = 'givetake1_a' },
    },
    check_pulse = {
        label = 'Check Pulse', category = 'assessment',
        item = nil, duration = 2500,
        anim = { dict = 'mp_common', clip = 'givetake1_a' },
    },
    check_breathing = {
        label = 'Check Breathing', category = 'assessment',
        item = nil, duration = 2500,
        anim = { dict = 'mp_common', clip = 'givetake1_a' },
    },
    trauma_assessment = {
        label = 'Trauma Assessment', category = 'assessment',
        item = nil, duration = 3500,
        anim = { dict = 'mp_common', clip = 'givetake1_a' },
    },
    check_glucose = {
        label = 'Check Blood Glucose', category = 'assessment',
        item = 'glucose', duration = 3000,
        anim = { dict = 'mp_common', clip = 'givetake1_a' },
    },

    apply_pressure = {
        label = 'Apply Direct Pressure', category = 'bleeding',
        item = 'bandage', duration = 4000,
        anim = { dict = 'mp_common', clip = 'givetake1_a' },
    },
    apply_bandage = {
        label = 'Apply Bandage', category = 'bleeding',
        item = 'bandage', duration = 4000,
        anim = { dict = 'mp_common', clip = 'givetake1_a' },
    },
    apply_gauze = {
        label = 'Pack Wound with Gauze', category = 'bleeding',
        item = 'gauze', duration = 4500,
        anim = { dict = 'mp_common', clip = 'givetake1_a' },
    },
    apply_tourniquet = {
        label = 'Apply Tourniquet', category = 'bleeding',
        item = 'tourniquet', duration = 5000,
        anim = { dict = 'mp_common', clip = 'givetake1_a' },
    },
    apply_chest_seal = {
        label = 'Apply Chest Seal', category = 'bleeding',
        item = 'chest_seal', duration = 4500,
        anim = { dict = 'mp_common', clip = 'givetake1_a' },
    },

    administer_oxygen = {
        label = 'Administer Oxygen', category = 'airway',
        item = 'oxygen_mask', duration = 3500,
        anim = { dict = 'mp_common', clip = 'givetake1_a' },
    },
    open_airway = {
        label = 'Open Airway', category = 'airway',
        item = nil, duration = 3000,
        anim = { dict = 'mp_common', clip = 'givetake1_a' },
    },

    start_iv = {
        label = 'Start IV', category = 'medication',
        item = 'iv_bag', duration = 5000,
        anim = { dict = 'mp_common', clip = 'givetake1_a' },
    },
    give_narcan = {
        label = 'Administer Narcan', category = 'medication',
        item = 'narcan', duration = 3000,
        anim = { dict = 'mp_common', clip = 'givetake1_a' },
    },
    give_aspirin = {
        label = 'Administer Aspirin', category = 'medication',
        item = 'aspirin', duration = 2500,
        anim = { dict = 'mp_common', clip = 'givetake1_a' },
    },
    give_nitro = {
        label = 'Administer Nitroglycerin', category = 'medication',
        item = 'nitroglycerin', duration = 2500,
        anim = { dict = 'mp_common', clip = 'givetake1_a' },
    },
    give_epinephrine = {
        label = 'Administer Epinephrine', category = 'medication',
        item = 'epinephrine', duration = 3000,
        anim = { dict = 'mp_common', clip = 'givetake1_a' },
    },
    give_glucose = {
        label = 'Administer Glucose', category = 'medication',
        item = 'glucose', duration = 3000,
        anim = { dict = 'mp_common', clip = 'givetake1_a' },
    },
    apply_splint = {
        label = 'Apply Splint', category = 'trauma',
        item = 'splint', duration = 4500,
        anim = { dict = 'mp_common', clip = 'givetake1_a' },
    },

    perform_cpr = {
        label = 'Perform CPR', category = 'resuscitation',
        item = nil, duration = 8000,
        -- Correcting a guess I'm still not fully certain of: GTA's mini@
        -- scene dicts almost always name their actual loop clip 'idle_a'
        -- rather than repeating the dict's own tail name - 'cpr_str' as a
        -- clip name was very likely wrong, which is probably why nothing
        -- visibly played. If 'idle_a' still doesn't look right, the
        -- reliable way to nail this down for good is a community animation
        -- browser (search "cpr" on vespura.com/fivem/animations, or use an
        -- in-game anim-list resource) to find the exact verified dict/clip
        -- pair and drop it in here - I can't verify GTA animation assets
        -- from here, only pattern-match plausible names.
        anim = { dict = 'mini@cpr@char_a@cpr_str', clip = 'idle_a' },
        isCPR = true,
    },
    use_aed = {
        label = 'Use AED', category = 'resuscitation',
        item = 'aed', duration = 9000,
        anim = { dict = 'mp_common', clip = 'givetake1_a' },
        isAED = true,
    },

    prepare_transport = {
        label = 'Prepare for Transport', category = 'transport',
        item = nil, duration = 3000,
        anim = { dict = 'mp_common', clip = 'givetake1_a' },
    },
}
