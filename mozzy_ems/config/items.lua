Config.Items = {
    bandage       = 'bandage',
    gauze         = 'gauze',
    tourniquet    = 'tourniquet',
    trauma_kit    = 'trauma_kit',
    medical_bag   = 'medical_bag',
    oxygen_mask   = 'oxygen_mask',
    oxygen_tank   = 'oxygen_tank',
    iv_bag        = 'iv_bag',
    narcan        = 'narcan',
    aspirin       = 'aspirin',
    nitroglycerin = 'nitroglycerin',
    epinephrine   = 'epinephrine',
    glucose       = 'glucose_gel',
    splint        = 'splint',
    chest_seal    = 'chest_seal',
    aed           = 'aed',
    stretcher     = 'stretcher',
}

-- Per-item behaviour: does a treatment require the item to be present,
-- and does it get consumed on use? AED/stretcher are equipment (reusable);
-- most consumables are single-use.
Config.ItemBehaviour = {
    bandage       = { required = true,  consume = true  },
    gauze         = { required = true,  consume = true  },
    tourniquet    = { required = true,  consume = true  },
    trauma_kit    = { required = true ,  consume = true  },
    oxygen_mask   = { required = true ,  consume = false },
    oxygen_tank   = { required = true ,  consume = false },
    iv_bag        = { required = true ,  consume = true  },
    narcan        = { required = true ,  consume = true  },
    aspirin       = { required = true ,  consume = true  },
    nitroglycerin = { required = true ,  consume = true  },
    epinephrine   = { required = true ,  consume = true  },
    glucose       = { required = true ,  consume = true  },
    splint        = { required = true ,  consume = true  },
    chest_seal    = { required = true ,  consume = true  },
    aed           = { required = true ,  consume = false },
    stretcher     = { required = false, consume = false },
}

-- Optional ox_inventory item definitions you can paste into
-- ox_inventory/data/items.lua. Not loaded automatically - see README.
Config.OxInventoryItemDefinitions = [[
['bandage'] = {
    label = 'Bandage', weight = 100, stack = true, close = true,
    description = 'Basic wound dressing to control minor bleeding.'
},
['gauze'] = {
    label = 'Gauze', weight = 100, stack = true, close = true,
    description = 'Absorbent dressing for moderate bleeding.'
},
['tourniquet'] = {
    label = 'Tourniquet', weight = 150, stack = true, close = true,
    description = 'Stops severe limb bleeding.'
},
['trauma_kit'] = {
    label = 'Trauma Kit', weight = 1500, stack = true, close = true,
    description = 'Advanced trauma dressing kit.'
},
['medical_bag'] = {
    label = 'Medical Bag', weight = 3000, stack = false, close = true,
    description = 'Deployable EMS equipment bag.'
},
['oxygen_mask'] = {
    label = 'Oxygen Mask', weight = 500, stack = true, close = true,
    description = 'Delivers supplemental oxygen.'
},
['oxygen_tank'] = {
    label = 'Oxygen Tank', weight = 2000, stack = false, close = true,
    description = 'Portable oxygen supply.'
},
['iv_bag'] = {
    label = 'IV Bag', weight = 400, stack = true, close = true,
    description = 'Intravenous fluids.'
},
['narcan'] = {
    label = 'Narcan (Naloxone)', weight = 50, stack = true, close = true,
    description = 'Opioid overdose reversal agent.'
},
['aspirin'] = {
    label = 'Aspirin', weight = 20, stack = true, close = true,
    description = 'Used for suspected cardiac events.'
},
['nitroglycerin'] = {
    label = 'Nitroglycerin', weight = 20, stack = true, close = true,
    description = 'Vasodilator for chest pain.'
},
['epinephrine'] = {
    label = 'Epinephrine', weight = 50, stack = true, close = true,
    description = 'Used for anaphylaxis and cardiac arrest.'
},
['glucose_gel'] = {
    label = 'Glucose Gel', weight = 50, stack = true, close = true,
    description = 'Raises blood sugar rapidly.'
},
['splint'] = {
    label = 'Splint', weight = 300, stack = true, close = true,
    description = 'Immobilizes broken limbs.'
},
['chest_seal'] = {
    label = 'Chest Seal', weight = 100, stack = true, close = true,
    description = 'Seals penetrating chest wounds.'
},
['aed'] = {
    label = 'AED', weight = 2500, stack = false, close = true,
    description = 'Automated External Defibrillator.'
},
['stretcher'] = {
    label = 'Stretcher', weight = 4000, stack = false, close = true,
    description = 'Patient transport stretcher.'
},
]]
