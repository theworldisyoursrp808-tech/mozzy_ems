--[[
    Config.Calls - the scenario library. Every medical emergency the
    simulator can generate is DATA here, not code. The engine
    (server/patients.lua, server/treatment.lua) is 100% generic and reads
    these fields for every call type. To add a new emergency, copy an
    existing block and change the values - nothing else needs touching.

    FIELD REFERENCE
    ----------------
    label                 display name
    dispatchCode          shown on the dispatch card (e.g. "MED-12")
    priority              1 critical / 2 serious / 3 stable
    enabled               false disables generation without deleting it
    weight                relative chance vs other enabled calls
    minEMS                minimum on-duty EMS required for this to be picked
    locations             list of location categories (config/locations.lua)
                          this scenario is allowed to spawn at
    hidden                true = dispatch/EMS only see generic symptoms,
                          the real condition is not shown anywhere in the UI
    callerText            random dispatch narrative lines (may be vague/wrong)
    bystanderLines        optional witness statement pool
    patientDialogue       lines patient may say if conscious
    ped                   { models, animation, consciousChance (0-100),
                            cardiacArrestChance (0-100) }
    vitals                min/max ranges the engine rolls initial vitals from
    injuries              pool of injury descriptions, `injuryCount` are drawn
    injuryCount           {min,max} how many injuries to draw from the pool
    validTreatments       set of treatment ids that are medically correct
    treatmentEffects      per treatment id, vital deltas applied ONCE per
                          correct administration (diminishing after 2x)
    requiredCorrectTreatments  distinct correct treatments needed to stabilize
    deterioration         { enabled, interval, pulse, bpSys, bpDia, resp,
                            spo2, worsensConsciousness, canArrest }
    resuscitation         only for cardiac-arrest-capable calls:
                          { roscBaseChance, roscPerCPRCycle, aedShockable }
    transportRequired     bool
    reward                { min, max } base $ before severity multiplier
    scene                 { vehicle=bool, bloodProp=bool, drugProp=bool }
]]

Config.Calls = {}

-----------------------------------------------------------------------------
-- PENETRATING TRAUMA
-----------------------------------------------------------------------------

Config.Calls['gunshot_single'] = {
    label = 'Gunshot Wound', dispatchCode = 'MED-1', priority = 1,
    enabled = true, weight = 12, minEMS = 1,
    locations = { 'alley', 'residential', 'industrial', 'parking_lot' },
    hidden = false,
    callerText = {
        'Caller reports hearing a gunshot and finding a man down.',
        'Caller states a person has been shot and is bleeding heavily.',
    },
    bystanderLines = { 'I heard one shot and found him like this.', 'Someone ran off after I heard the bang.' },
    patientDialogue = { "It hurts... I can't feel my leg.", "Please... don't let me die." },
    ped = { models = { 'a_m_m_skidrow_01', 'a_m_y_genstreet_01' }, animation = 'lying_injured', consciousChance = 55, cardiacArrestChance = 5 },
    vitals = { pulse = {100,125}, bpSys = {85,105}, bpDia = {55,70}, resp = {18,26}, spo2 = {88,95}, temp = {36.0,37.2} },
    injuries = { 'Gunshot wound to the abdomen', 'Gunshot wound to the leg', 'Gunshot wound to the arm', 'Severe external bleeding' },
    injuryCount = { min = 1, max = 2 },
    validTreatments = { apply_pressure = true, apply_bandage = true, apply_tourniquet = true, administer_oxygen = true, start_iv = true, trauma_assessment = true },
    treatmentEffects = {
        apply_pressure   = { pulse = -6, bpSys = 3, spo2 = 1 },
        apply_bandage    = { pulse = -5, bpSys = 3, spo2 = 1 },
        apply_tourniquet = { pulse = -10, bpSys = 6, spo2 = 2 },
        administer_oxygen= { spo2 = 5, resp = -2 },
        start_iv         = { bpSys = 5, bpDia = 3 },
    },
    requiredCorrectTreatments = 3,
    deterioration = { enabled = true, interval = 45, pulse = 6, bpSys = -6, bpDia = -4, resp = 2, spo2 = -3, worsensConsciousness = true, canArrest = true },
    resuscitation = { roscBaseChance = 25, roscPerCPRCycle = 9, aedShockable = true },
    transportRequired = true,
    reward = { min = 700, max = 1100 },
    scene = { bloodProp = true },
}

Config.Calls['gunshot_multiple'] = {
    label = 'Multiple Gunshot Wounds', dispatchCode = 'MED-2', priority = 1,
    enabled = true, weight = 6, minEMS = 1,
    locations = { 'alley', 'industrial', 'parking_lot' },
    hidden = false,
    callerText = { 'Caller reports multiple shots fired and one victim down, possibly hit several times.' },
    bystanderLines = { 'It sounded like five or six shots.', 'He went down and hasn\'t moved since.' },
    patientDialogue = { "It's everywhere... it hurts everywhere." },
    ped = { models = { 'a_m_m_skidrow_01' }, animation = 'lying_injured', consciousChance = 35, cardiacArrestChance = 12 },
    vitals = { pulse = {115,140}, bpSys = {75,95}, bpDia = {45,60}, resp = {22,30}, spo2 = {80,90}, temp = {35.8,36.8} },
    injuries = { 'Gunshot wound to the chest', 'Gunshot wound to the abdomen', 'Gunshot wound to the arm', 'Gunshot wound to the leg', 'Collapsed lung suspected' },
    injuryCount = { min = 2, max = 4 },
    validTreatments = { apply_pressure = true, apply_tourniquet = true, apply_chest_seal = true, administer_oxygen = true, start_iv = true, trauma_assessment = true, perform_cpr = true, use_aed = true },
    treatmentEffects = {
        apply_pressure   = { pulse = -6, bpSys = 3 },
        apply_tourniquet = { pulse = -10, bpSys = 6 },
        apply_chest_seal = { spo2 = 6, resp = -3 },
        administer_oxygen= { spo2 = 5, resp = -2 },
        start_iv         = { bpSys = 6, bpDia = 4 },
    },
    requiredCorrectTreatments = 4,
    deterioration = { enabled = true, interval = 35, pulse = 8, bpSys = -8, bpDia = -5, resp = 3, spo2 = -4, worsensConsciousness = true, canArrest = true },
    resuscitation = { roscBaseChance = 25, roscPerCPRCycle = 8, aedShockable = true },
    transportRequired = true,
    reward = { min = 1100, max = 1600 },
    scene = { bloodProp = true },
}

Config.Calls['stabbing'] = {
    label = 'Stabbing', dispatchCode = 'MED-3', priority = 1,
    enabled = true, weight = 10, minEMS = 1,
    locations = { 'alley', 'club', 'bar', 'residential' },
    hidden = false,
    callerText = { 'Caller reports a stabbing victim bleeding on the ground.' },
    bystanderLines = { 'They were arguing and then I saw a knife.', 'He\'s been holding his side since it happened.' },
    patientDialogue = { "I can't feel my leg.", "Make it stop bleeding, please." },
    ped = { models = { 'a_m_y_hipster_01', 'a_f_y_hipster_02' }, animation = 'sitting_injured', consciousChance = 65, cardiacArrestChance = 4 },
    vitals = { pulse = {95,120}, bpSys = {88,108}, bpDia = {58,72}, resp = {18,24}, spo2 = {90,96}, temp = {36.2,37.3} },
    injuries = { 'Chest stab wound', 'Abdomen stab wound', 'Arm laceration', 'Leg laceration', 'Multiple stab wounds' },
    injuryCount = { min = 1, max = 3 },
    validTreatments = { apply_pressure = true, apply_gauze = true, apply_bandage = true, apply_chest_seal = true, administer_oxygen = true, start_iv = true, trauma_assessment = true },
    treatmentEffects = {
        apply_pressure = { pulse = -6, bpSys = 3 },
        apply_gauze    = { pulse = -7, bpSys = 4 },
        apply_bandage  = { pulse = -5, bpSys = 3 },
        apply_chest_seal = { spo2 = 6, resp = -2 },
        administer_oxygen = { spo2 = 4, resp = -1 },
        start_iv = { bpSys = 5, bpDia = 3 },
    },
    requiredCorrectTreatments = 2,
    deterioration = { enabled = true, interval = 50, pulse = 5, bpSys = -5, bpDia = -3, resp = 1, spo2 = -2, worsensConsciousness = true, canArrest = false },
    transportRequired = true,
    reward = { min = 600, max = 950 },
    scene = { bloodProp = true },
}

-----------------------------------------------------------------------------
-- OVERDOSE / TOXICOLOGY
-----------------------------------------------------------------------------

Config.Calls['opioid_overdose'] = {
    label = 'Unresponsive Person', dispatchCode = 'MED-12', priority = 1,
    enabled = true, weight = 14, minEMS = 1,
    locations = { 'alley', 'residential', 'apartment', 'parking_lot' },
    hidden = true, -- shown as "unresponsive person", real cause hidden
    callerText = { 'Caller reports a friend is unresponsive and barely breathing.', 'Caller found someone unconscious behind a building, breathing slowly.' },
    bystanderLines = { 'He took something about twenty minutes ago.', 'I found a pill bottle next to him.' },
    patientDialogue = {},
    ped = { models = { 'a_m_m_skidrow_01', 'a_m_y_downtown_01' }, animation = 'lying_unconscious', consciousChance = 5, cardiacArrestChance = 8 },
    vitals = { pulse = {45,58}, bpSys = {85,100}, bpDia = {50,62}, resp = {4,8}, spo2 = {72,82}, temp = {35.2,36.2} },
    injuries = { 'Pinpoint pupils', 'Track marks on arm', 'Shallow breathing' },
    injuryCount = { min = 1, max = 2 },
    validTreatments = { open_airway = true, administer_oxygen = true, give_narcan = true, start_iv = true, check_breathing = true, check_pulse = true },
    treatmentEffects = {
        open_airway       = { resp = 3, spo2 = 3 },
        administer_oxygen = { spo2 = 6, resp = 2 },
        give_narcan       = { resp = 8, spo2 = 8, pulse = 12, consciousnessStep = 1 },
        start_iv          = { bpSys = 3 },
    },
    requiredCorrectTreatments = 2,
    deterioration = { enabled = true, interval = 40, pulse = -4, resp = -1, spo2 = -4, worsensConsciousness = true, canArrest = true },
    resuscitation = { roscBaseChance = 30, roscPerCPRCycle = 10, aedShockable = false },
    transportRequired = true,
    reward = { min = 650, max = 1000 },
    scene = { drugProp = true },
}

Config.Calls['stimulant_overdose'] = {
    label = 'Unresponsive Person', dispatchCode = 'MED-13', priority = 1,
    enabled = true, weight = 6, minEMS = 1,
    locations = { 'club', 'bar', 'apartment', 'residential' },
    hidden = true,
    callerText = { 'Caller reports someone acting erratically who has now collapsed.' },
    bystanderLines = { 'He was really sweaty and his heart was racing before he went down.', 'She said she took something at the party.' },
    patientDialogue = { "My heart... it's going too fast.", "I can't calm down." },
    ped = { models = { 'a_f_y_hipster_02', 'a_m_y_hipster_01' }, animation = 'seizure', consciousChance = 30, cardiacArrestChance = 10 },
    vitals = { pulse = {135,165}, bpSys = {155,180}, bpDia = {95,110}, resp = {24,32}, spo2 = {85,93}, temp = {38.5,40.0} },
    injuries = { 'Profuse sweating', 'Dilated pupils', 'Tremors' },
    injuryCount = { min = 1, max = 2 },
    validTreatments = { administer_oxygen = true, start_iv = true, check_pulse = true, trauma_assessment = true },
    treatmentEffects = {
        administer_oxygen = { spo2 = 5, resp = -2 },
        start_iv = { bpSys = -6, bpDia = -4, pulse = -6 },
    },
    requiredCorrectTreatments = 2,
    deterioration = { enabled = true, interval = 40, pulse = 6, bpSys = 5, resp = 2, spo2 = -3, worsensConsciousness = true, canArrest = true },
    resuscitation = { roscBaseChance = 25, roscPerCPRCycle = 8, aedShockable = true },
    transportRequired = true,
    reward = { min = 650, max = 1000 },
    scene = { drugProp = true },
}

Config.Calls['alcohol_poisoning'] = {
    label = 'Intoxicated Unresponsive Person', dispatchCode = 'MED-14', priority = 2,
    enabled = true, weight = 8, minEMS = 1,
    locations = { 'bar', 'club', 'beach', 'residential' },
    hidden = false,
    callerText = { 'Caller reports a heavily intoxicated person who won\'t wake up.' },
    bystanderLines = { 'She\'s been drinking all night.', 'He threw up and then passed out.' },
    patientDialogue = {},
    ped = { models = { 'a_f_y_hipster_02', 'a_m_y_hipster_01' }, animation = 'lying_unconscious', consciousChance = 20, cardiacArrestChance = 2 },
    vitals = { pulse = {58,75}, bpSys = {90,105}, bpDia = {55,68}, resp = {9,13}, spo2 = {88,94}, temp = {35.5,36.5} },
    injuries = { 'Vomit present', 'Smell of alcohol' },
    injuryCount = { min = 1, max = 1 },
    validTreatments = { open_airway = true, administer_oxygen = true, check_breathing = true, start_iv = true },
    treatmentEffects = {
        open_airway = { resp = 2, spo2 = 3 },
        administer_oxygen = { spo2 = 5, resp = 1 },
        start_iv = { bpSys = 3 },
    },
    requiredCorrectTreatments = 2,
    deterioration = { enabled = true, interval = 60, resp = -1, spo2 = -3, worsensConsciousness = true, canArrest = false },
    transportRequired = true,
    reward = { min = 400, max = 650 },
    scene = { drugProp = false },
}

-----------------------------------------------------------------------------
-- CARDIAC / STROKE
-----------------------------------------------------------------------------

Config.Calls['heart_attack'] = {
    label = 'Chest Pain', dispatchCode = 'MED-20', priority = 1,
    enabled = true, weight = 12, minEMS = 1,
    locations = { 'residential', 'commercial', 'apartment', 'rural' },
    hidden = false,
    callerText = { 'Caller reports an adult with severe chest pain and shortness of breath.' },
    bystanderLines = { 'He grabbed his chest and sat down suddenly.', 'She said it feels like an elephant on her chest.' },
    patientDialogue = { "My chest feels like someone is sitting on it.", "It started about ten minutes ago.", "I can't catch my breath." },
    ped = { models = { 'a_m_m_business_01', 'a_f_m_business_02' }, animation = 'sitting_injured', consciousChance = 80, cardiacArrestChance = 10 },
    vitals = { pulse = {105,130}, bpSys = {150,175}, bpDia = {95,110}, resp = {20,26}, spo2 = {89,95}, temp = {36.5,37.3} },
    injuries = { 'Diaphoresis (sweating)', 'Radiating arm pain', 'Pale skin' },
    injuryCount = { min = 1, max = 2 },
    validTreatments = { give_aspirin = true, give_nitro = true, administer_oxygen = true, start_iv = true, check_pulse = true, perform_cpr = true, use_aed = true },
    treatmentEffects = {
        give_aspirin = { pulse = -4 },
        give_nitro = { bpSys = -10, bpDia = -6 },
        administer_oxygen = { spo2 = 5, resp = -2 },
        start_iv = { bpSys = -2 },
    },
    requiredCorrectTreatments = 3,
    deterioration = { enabled = true, interval = 45, pulse = 6, bpSys = 5, resp = 2, spo2 = -3, worsensConsciousness = true, canArrest = true },
    resuscitation = { roscBaseChance = 20, roscPerCPRCycle = 8, aedShockable = true },
    transportRequired = true,
    reward = { min = 750, max = 1150 },
    scene = {},
}

Config.Calls['cardiac_arrest'] = {
    label = 'Cardiac Arrest', dispatchCode = 'MED-21', priority = 1,
    enabled = true, weight = 7, minEMS = 1,
    locations = { 'residential', 'commercial', 'apartment', 'gas_station' },
    hidden = false,
    callerText = { 'Caller reports a person collapsed, not breathing.' },
    bystanderLines = { 'He just collapsed, no warning at all.', 'I tried to check but I don\'t think he\'s breathing.' },
    patientDialogue = {},
    ped = { models = { 'a_m_m_business_01', 'a_m_m_bevhills_01' }, animation = 'lying_unconscious', consciousChance = 0, cardiacArrestChance = 100 },
    vitals = { pulse = {0,0}, bpSys = {0,0}, bpDia = {0,0}, resp = {0,0}, spo2 = {0,40}, temp = {35.0,36.0} },
    injuries = { 'No pulse', 'Not breathing' },
    injuryCount = { min = 1, max = 1 },
    validTreatments = { perform_cpr = true, use_aed = true, administer_oxygen = true, start_iv = true, open_airway = true },
    treatmentEffects = {
        administer_oxygen = {},
        start_iv = {},
        open_airway = {},
    },
    requiredCorrectTreatments = 1, -- ROSC handled by resuscitation block, not generic vitals math
    deterioration = { enabled = false },
    resuscitation = { roscBaseChance = 15, roscPerCPRCycle = 12, aedShockable = true, maxCycles = 6 },
    transportRequired = true,
    reward = { min = 1200, max = 1800 },
    scene = {},
}

Config.Calls['stroke'] = {
    label = 'Possible Stroke', dispatchCode = 'MED-25', priority = 1,
    enabled = true, weight = 8, minEMS = 1,
    locations = { 'residential', 'apartment', 'commercial', 'rural' },
    hidden = false,
    callerText = { 'Caller reports a person with slurred speech and one-sided weakness.' },
    bystanderLines = { 'Her face suddenly drooped on one side.', 'He couldn\'t get his words out right.' },
    patientDialogue = { "I... cant... move my..." },
    ped = { models = { 'a_f_m_prolhost_01', 'a_m_m_eastsa_01' }, animation = 'sitting_injured', consciousChance = 70, cardiacArrestChance = 3 },
    vitals = { pulse = {80,100}, bpSys = {170,200}, bpDia = {100,120}, resp = {16,22}, spo2 = {90,96}, temp = {36.5,37.2} },
    injuries = { 'Facial droop', 'Slurred speech', 'One-sided weakness' },
    injuryCount = { min = 2, max = 3 },
    validTreatments = { administer_oxygen = true, check_pulse = true, trauma_assessment = true, start_iv = true },
    treatmentEffects = {
        administer_oxygen = { spo2 = 4 },
        start_iv = {},
    },
    requiredCorrectTreatments = 2,
    deterioration = { enabled = true, interval = 60, bpSys = 4, worsensConsciousness = true, canArrest = false },
    transportRequired = true,
    reward = { min = 700, max = 1050 },
    scene = {},
}

-----------------------------------------------------------------------------
-- METABOLIC / NEUROLOGICAL
-----------------------------------------------------------------------------

Config.Calls['seizure'] = {
    label = 'Seizure', dispatchCode = 'MED-30', priority = 2,
    enabled = true, weight = 9, minEMS = 1,
    locations = { 'residential', 'commercial', 'apartment', 'club' },
    hidden = false,
    callerText = { 'Caller reports a person having a seizure.' },
    bystanderLines = { 'He just started shaking on the ground.', 'This has happened once before I think.' },
    patientDialogue = { "What... what happened?", "My head hurts." },
    ped = { models = { 'a_m_y_business_01', 'a_f_y_business_02' }, animation = 'seizure', consciousChance = 40, cardiacArrestChance = 2 },
    vitals = { pulse = {100,120}, bpSys = {130,150}, bpDia = {80,95}, resp = {20,26}, spo2 = {90,95}, temp = {37.0,38.0} },
    injuries = { 'Postictal confusion', 'Tongue laceration', 'Incontinence' },
    injuryCount = { min = 1, max = 2 },
    validTreatments = { check_glucose = true, administer_oxygen = true, trauma_assessment = true, check_pulse = true },
    treatmentEffects = {
        administer_oxygen = { spo2 = 4 },
    },
    requiredCorrectTreatments = 2,
    deterioration = { enabled = true, interval = 60, resp = 1, spo2 = -2, worsensConsciousness = false, canArrest = false },
    transportRequired = true,
    reward = { min = 500, max = 800 },
    scene = {},
}

Config.Calls['diabetic_low'] = {
    label = 'Diabetic Emergency', dispatchCode = 'MED-31', priority = 2,
    enabled = true, weight = 8, minEMS = 1,
    locations = { 'residential', 'commercial', 'apartment' },
    hidden = false,
    callerText = { 'Caller reports a diabetic who is confused and shaking.' },
    bystanderLines = { 'She said she hasn\'t eaten today.', 'He takes insulin, I think he took too much.' },
    patientDialogue = { "I feel... shaky... confused." },
    ped = { models = { 'a_f_m_prolhost_01', 'a_m_m_eastsa_01' }, animation = 'sitting_injured', consciousChance = 60, cardiacArrestChance = 2 },
    vitals = { pulse = {105,125}, bpSys = {95,115}, bpDia = {60,75}, resp = {16,20}, spo2 = {93,97}, glucose = {35,60}, temp = {36.0,36.8} },
    injuries = { 'Diaphoresis (sweating)', 'Tremors', 'Confusion' },
    injuryCount = { min = 1, max = 2 },
    validTreatments = { check_glucose = true, give_glucose = true, start_iv = true },
    treatmentEffects = {
        give_glucose = { glucose = 40, pulse = -6, consciousnessStep = 1 },
        start_iv = {},
    },
    requiredCorrectTreatments = 2,
    deterioration = { enabled = true, interval = 45, glucose = -6, worsensConsciousness = true, canArrest = false },
    transportRequired = false,
    reward = { min = 450, max = 700 },
    scene = {},
}

Config.Calls['allergic_reaction'] = {
    label = 'Allergic Reaction', dispatchCode = 'MED-35', priority = 1,
    enabled = true, weight = 7, minEMS = 1,
    locations = { 'residential', 'commercial', 'bar', 'club' },
    hidden = false,
    callerText = { 'Caller reports someone having a severe allergic reaction, face swelling.' },
    bystanderLines = { 'She ate something with peanuts.', 'His face and throat started swelling fast.' },
    patientDialogue = { "I can't... breathe right...", "My throat feels tight." },
    ped = { models = { 'a_f_y_business_02', 'a_m_y_business_01' }, animation = 'sitting_injured', consciousChance = 70, cardiacArrestChance = 5 },
    vitals = { pulse = {110,135}, bpSys = {80,100}, bpDia = {50,65}, resp = {24,32}, spo2 = {84,92}, temp = {36.8,37.5} },
    injuries = { 'Facial swelling', 'Hives', 'Wheezing' },
    injuryCount = { min = 1, max = 2 },
    validTreatments = { give_epinephrine = true, administer_oxygen = true, start_iv = true, check_breathing = true },
    treatmentEffects = {
        give_epinephrine = { spo2 = 8, resp = -4, bpSys = 10, pulse = 6 },
        administer_oxygen = { spo2 = 4 },
        start_iv = { bpSys = 3 },
    },
    requiredCorrectTreatments = 2,
    deterioration = { enabled = true, interval = 35, spo2 = -5, resp = 3, worsensConsciousness = true, canArrest = true },
    resuscitation = { roscBaseChance = 25, roscPerCPRCycle = 8, aedShockable = true },
    transportRequired = true,
    reward = { min = 650, max = 1000 },
    scene = {},
}

Config.Calls['respiratory_distress'] = {
    label = 'Difficulty Breathing', dispatchCode = 'MED-36', priority = 2,
    enabled = true, weight = 9, minEMS = 1,
    locations = { 'residential', 'apartment', 'commercial' },
    hidden = false,
    callerText = { 'Caller reports someone struggling to breathe, possible asthma attack.' },
    bystanderLines = { 'He forgot his inhaler.', 'She\'s been wheezing for a few minutes.' },
    patientDialogue = { "Can't... get air...", "It's like breathing through a straw." },
    ped = { models = { 'a_m_y_business_01', 'a_f_y_business_02' }, animation = 'sitting_injured', consciousChance = 85, cardiacArrestChance = 2 },
    vitals = { pulse = {110,130}, bpSys = {125,145}, bpDia = {80,92}, resp = {28,36}, spo2 = {84,90}, temp = {36.8,37.3} },
    injuries = { 'Audible wheezing', 'Accessory muscle use' },
    injuryCount = { min = 1, max = 2 },
    validTreatments = { administer_oxygen = true, check_breathing = true, start_iv = true },
    treatmentEffects = {
        administer_oxygen = { spo2 = 7, resp = -4 },
    },
    requiredCorrectTreatments = 1,
    deterioration = { enabled = true, interval = 50, spo2 = -3, resp = 2, worsensConsciousness = true, canArrest = false },
    transportRequired = true,
    reward = { min = 450, max = 700 },
    scene = {},
}

-----------------------------------------------------------------------------
-- TRAUMA / VEHICLE / ENVIRONMENTAL
-----------------------------------------------------------------------------

Config.Calls['pedestrian_struck'] = {
    label = 'Pedestrian Struck', dispatchCode = 'MED-40', priority = 1,
    enabled = true, weight = 7, minEMS = 1,
    locations = { 'highway', 'commercial', 'residential' },
    hidden = false,
    callerText = { 'Caller reports a pedestrian was hit by a vehicle and is down in the road.' },
    bystanderLines = { 'The car didn\'t even stop.', 'He flew a few feet after being hit.' },
    patientDialogue = { "My leg... I think it's broken." },
    ped = { models = { 'a_m_y_downtown_01', 'a_f_y_genstreet_01' }, animation = 'lying_injured', consciousChance = 45, cardiacArrestChance = 8 },
    vitals = { pulse = {105,130}, bpSys = {85,105}, bpDia = {55,70}, resp = {20,28}, spo2 = {86,93}, temp = {36.0,37.0} },
    injuries = { 'Broken leg', 'Head injury', 'Internal bleeding suspected', 'Severe bruising' },
    injuryCount = { min = 2, max = 3 },
    validTreatments = { trauma_assessment = true, apply_splint = true, administer_oxygen = true, start_iv = true, apply_pressure = true },
    treatmentEffects = {
        apply_splint = { pulse = -3 },
        administer_oxygen = { spo2 = 5 },
        start_iv = { bpSys = 5, bpDia = 3 },
        apply_pressure = { pulse = -4, bpSys = 2 },
    },
    requiredCorrectTreatments = 3,
    deterioration = { enabled = true, interval = 45, pulse = 6, bpSys = -6, spo2 = -3, worsensConsciousness = true, canArrest = true },
    resuscitation = { roscBaseChance = 20, roscPerCPRCycle = 7, aedShockable = false },
    transportRequired = true,
    reward = { min = 800, max = 1200 },
    scene = { vehicle = true, bloodProp = true },
}

Config.Calls['vehicle_accident'] = {
    label = 'Single-Vehicle Accident', dispatchCode = 'MED-41', priority = 1,
    enabled = true, weight = 8, minEMS = 1,
    locations = { 'highway', 'rural', 'mountain' },
    hidden = false,
    callerText = { 'Caller reports a single-vehicle crash, driver trapped/injured.' },
    bystanderLines = { 'The car just lost control and hit the barrier.', 'He was still in the driver\'s seat when I got there.' },
    patientDialogue = { "I can't move my legs.", "What happened?" },
    ped = { models = { 'a_m_m_business_01', 'a_f_m_business_02' }, animation = 'lying_injured', consciousChance = 50, cardiacArrestChance = 8 },
    vitals = { pulse = {100,125}, bpSys = {80,100}, bpDia = {52,68}, resp = {20,28}, spo2 = {85,92}, temp = {36.0,37.0} },
    injuries = { 'Broken arm', 'Head injury', 'Internal bleeding suspected', 'Chest trauma' },
    injuryCount = { min = 2, max = 4 },
    validTreatments = { trauma_assessment = true, apply_splint = true, administer_oxygen = true, start_iv = true, apply_chest_seal = true },
    treatmentEffects = {
        apply_splint = { pulse = -3 },
        administer_oxygen = { spo2 = 5 },
        start_iv = { bpSys = 5, bpDia = 3 },
        apply_chest_seal = { spo2 = 5, resp = -2 },
    },
    requiredCorrectTreatments = 3,
    deterioration = { enabled = true, interval = 40, pulse = 7, bpSys = -7, spo2 = -3, worsensConsciousness = true, canArrest = true },
    resuscitation = { roscBaseChance = 20, roscPerCPRCycle = 7, aedShockable = false },
    transportRequired = true,
    reward = { min = 900, max = 1350 },
    scene = { vehicle = true, bloodProp = true },
}

Config.Calls['fall_injury'] = {
    label = 'Fall Injury', dispatchCode = 'MED-45', priority = 2,
    enabled = true, weight = 8, minEMS = 1,
    locations = { 'industrial', 'residential', 'mountain', 'rural' },
    hidden = false,
    callerText = { 'Caller reports a person fell and is injured.' },
    bystanderLines = { 'He fell off the ladder, about ten feet.', 'She slipped and fell down the stairs.' },
    patientDialogue = { "My back hurts really bad.", "I heard something crack when I landed." },
    ped = { models = { 'a_m_m_construct_01', 'a_f_m_fembarber_01' }, animation = 'lying_injured', consciousChance = 65, cardiacArrestChance = 3 },
    vitals = { pulse = {95,115}, bpSys = {95,115}, bpDia = {60,75}, resp = {18,24}, spo2 = {90,96}, temp = {36.3,37.0} },
    injuries = { 'Broken arm', 'Broken leg', 'Head trauma', 'Suspected spinal injury' },
    injuryCount = { min = 1, max = 3 },
    validTreatments = { trauma_assessment = true, apply_splint = true, administer_oxygen = true, check_pulse = true },
    treatmentEffects = {
        apply_splint = { pulse = -3 },
        administer_oxygen = { spo2 = 3 },
    },
    requiredCorrectTreatments = 2,
    deterioration = { enabled = true, interval = 60, pulse = 3, spo2 = -2, worsensConsciousness = true, canArrest = false },
    transportRequired = true,
    reward = { min = 550, max = 850 },
    scene = { bloodProp = true },
}

Config.Calls['drowning'] = {
    label = 'Drowning', dispatchCode = 'MED-50', priority = 1,
    enabled = true, weight = 5, minEMS = 1,
    locations = { 'beach', 'water' },
    hidden = false,
    callerText = { 'Caller reports someone pulled from the water, not breathing well.' },
    bystanderLines = { 'We pulled him out but he\'s barely breathing.', 'She was under for what felt like a minute.' },
    patientDialogue = { "*coughing* ...water...", },
    ped = { models = { 'a_m_y_beach_01', 'a_f_y_beach_01' }, animation = 'lying_unconscious', consciousChance = 20, cardiacArrestChance = 15 },
    vitals = { pulse = {50,70}, bpSys = {85,100}, bpDia = {52,65}, resp = {6,12}, spo2 = {70,82}, temp = {34.5,35.8} },
    injuries = { 'Water in airway', 'Cyanosis (bluish skin)' },
    injuryCount = { min = 1, max = 2 },
    validTreatments = { open_airway = true, administer_oxygen = true, perform_cpr = true, check_breathing = true },
    treatmentEffects = {
        open_airway = { resp = 3, spo2 = 3 },
        administer_oxygen = { spo2 = 6, resp = 2 },
    },
    requiredCorrectTreatments = 2,
    deterioration = { enabled = true, interval = 35, resp = -1, spo2 = -4, worsensConsciousness = true, canArrest = true },
    resuscitation = { roscBaseChance = 20, roscPerCPRCycle = 9, aedShockable = false },
    transportRequired = true,
    reward = { min = 700, max = 1050 },
    scene = {},
}

-----------------------------------------------------------------------------
-- MYSTERY CALL
-----------------------------------------------------------------------------

-- 'unconscious_unknown' does not directly define vitals/treatments - it
-- randomly borrows one of the pool below as the REAL underlying cause, but
-- dispatch and the on-scene UI only ever show the generic label/symptoms
-- from this block. This is what makes "unresponsive person reported" calls
-- unpredictable. See server/calls.lua -> GenerateCall for the resolution.
Config.Calls['unconscious_unknown'] = {
    label = 'Unresponsive Person', dispatchCode = 'MED-99', priority = 1,
    enabled = true, weight = 10, minEMS = 1,
    locations = { 'residential', 'commercial', 'apartment', 'alley', 'parking_lot' },
    hidden = true,
    mystery = true,
    mysteryPool = { 'opioid_overdose', 'diabetic_low', 'stroke', 'heart_attack', 'alcohol_poisoning', 'cardiac_arrest' },
    callerText = { 'Caller reports an unresponsive person, cause unknown.' },
    bystanderLines = { 'I just found him like this, I don\'t know what happened.', 'She was fine a few minutes ago and then collapsed.' },
    -- vitals/injuries/treatments are pulled from whichever call the mystery
    -- pool resolves to at generation time
}

-----------------------------------------------------------------------------
-- ADMIN COMMAND ALIASES (shorthand accepted by /emscall)
-----------------------------------------------------------------------------

Config.CallAliases = {
    overdose = 'opioid_overdose',
    shooting = 'gunshot_single',
    stabbing = 'stabbing',
    heart = 'heart_attack',
    arrest = 'cardiac_arrest',
    stroke = 'stroke',
    seizure = 'seizure',
    diabetic = 'diabetic_low',
    allergic = 'allergic_reaction',
    asthma = 'respiratory_distress',
    pedestrian = 'pedestrian_struck',
    crash = 'vehicle_accident',
    fall = 'fall_injury',
    drowning = 'drowning',
    unknown = 'unconscious_unknown',
}
