--[[
    Paste the contents of this table INTO your existing ox_inventory
    resource at: ox_inventory/data/items.lua

    That file is a single `return { ... }` table of every item on your
    server - you are adding these key/value entries alongside whatever is
    already there, NOT replacing the file. e.g.:

        return {
            ['some_existing_item'] = { ... },
            ['another_existing_item'] = { ... },

            -- paste the entries below in here --
            ['bandage'] = { ... },
            ['gauze'] = { ... },
            ...
        }

    If any of these keys (bandage, gauze, tourniquet, etc.) already exist in
    your items.lua from another script, skip that entry here - don't
    duplicate a key in the same table, Lua will just silently keep whichever
    one loads last.

    The names on the left (bandage, gauze, ...) must match Config.Items in
    config/items.lua. If you rename anything here, update Config.Items to
    match, or treatments referencing it will always report "missing item".
]]

['bandage'] = {
    label = 'Bandage',
    weight = 100,
    stack = true,
    close = true,
    description = 'Basic wound dressing to control minor bleeding.'
},

['gauze'] = {
    label = 'Gauze',
    weight = 100,
    stack = true,
    close = true,
    description = 'Absorbent dressing for moderate bleeding.'
},

['tourniquet'] = {
    label = 'Tourniquet',
    weight = 150,
    stack = true,
    close = true,
    description = 'Stops severe limb bleeding.'
},

['trauma_kit'] = {
    label = 'Trauma Kit',
    weight = 1500,
    stack = true,
    close = true,
    description = 'Advanced trauma dressing kit.'
},

['medical_bag'] = {
    label = 'Medical Bag',
    weight = 3000,
    stack = false,
    close = true,
    description = 'Deployable EMS equipment bag.'
},

['oxygen_mask'] = {
    label = 'Oxygen Mask',
    weight = 500,
    stack = true,
    close = true,
    description = 'Delivers supplemental oxygen.'
},

['oxygen_tank'] = {
    label = 'Oxygen Tank',
    weight = 2000,
    stack = false,
    close = true,
    description = 'Portable oxygen supply.'
},

['iv_bag'] = {
    label = 'IV Bag',
    weight = 400,
    stack = true,
    close = true,
    description = 'Intravenous fluids.'
},

['narcan'] = {
    label = 'Narcan (Naloxone)',
    weight = 50,
    stack = true,
    close = true,
    description = 'Opioid overdose reversal agent.'
},

['aspirin'] = {
    label = 'Aspirin',
    weight = 20,
    stack = true,
    close = true,
    description = 'Used for suspected cardiac events.'
},

['nitroglycerin'] = {
    label = 'Nitroglycerin',
    weight = 20,
    stack = true,
    close = true,
    description = 'Vasodilator for chest pain.'
},

['epinephrine'] = {
    label = 'Epinephrine',
    weight = 50,
    stack = true,
    close = true,
    description = 'Used for anaphylaxis and cardiac arrest.'
},

['glucose_gel'] = {
    label = 'Glucose Gel',
    weight = 50,
    stack = true,
    close = true,
    description = 'Raises blood sugar rapidly.'
},

['splint'] = {
    label = 'Splint',
    weight = 300,
    stack = true,
    close = true,
    description = 'Immobilizes broken limbs.'
},

['chest_seal'] = {
    label = 'Chest Seal',
    weight = 100,
    stack = true,
    close = true,
    description = 'Seals penetrating chest wounds.'
},

['aed'] = {
    label = 'AED',
    weight = 2500,
    stack = false,
    close = true,
    description = 'Automated External Defibrillator.'
},

['stretcher'] = {
    label = 'Stretcher',
    weight = 4000,
    stack = false,
    close = true,
    description = 'Patient transport stretcher.'
},
