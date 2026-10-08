# Treatment Reference Guide

Auto-generated from `config/calls.lua` and `config/treatments.lua` - this always matches what the server actually validates, since it's pulled straight from the same config the engine reads. Regenerate it any time you edit a call's `validTreatments`.

Where a call is a **mystery call** (dispatch shows a generic label but the real cause is hidden), the treatments listed are for the underlying condition it can resolve to - EMS never sees this directly in-game and has to work it out from vitals/injuries/scene evidence.

## Item -> what it treats

| Item (ox_inventory name) | Used for treatment | Category |
|---|---|---|
| `aed` | Use AED | resuscitation |
| `aspirin` | Administer Aspirin | medication |
| `bandage` | Apply Direct Pressure | bleeding |
| `bandage` | Apply Bandage | bleeding |
| `chest_seal` | Apply Chest Seal | bleeding |
| `epinephrine` | Administer Epinephrine | medication |
| `gauze` | Pack Wound with Gauze | bleeding |
| `glucose_gel` | Check Blood Glucose | assessment |
| `glucose_gel` | Administer Glucose | medication |
| `iv_bag` | Start IV | medication |
| `narcan` | Administer Narcan | medication |
| `nitroglycerin` | Administer Nitroglycerin | medication |
| `oxygen_mask` | Administer Oxygen | airway |
| `splint` | Apply Splint | trauma |
| `tourniquet` | Apply Tourniquet | bleeding |

## No-item treatments (hands/skills only)

| Treatment | Category |
|---|---|
| Scene Assessment | assessment |
| Check Breathing | assessment |
| Check Pulse | assessment |
| Open Airway | airway |
| Perform CPR | resuscitation |
| Prepare for Transport | transport |
| Trauma Assessment | assessment |

## Scenario -> correct treatments

### Allergic Reaction (`MED-35`)
Needs **2** distinct correct treatments to stabilize.
Requires hospital transport to fully complete.

Correct treatments:
- Administer Epinephrine (needs `epinephrine`)
- Administer Oxygen (needs `oxygen_mask`)
- Start IV (needs `iv_bag`)
- Check Breathing (no item needed)

### Cardiac Arrest (`MED-21`)
Needs **1** distinct correct treatments to stabilize.
Requires hospital transport to fully complete.

Correct treatments:
- Perform CPR (no item needed)
- Use AED (needs `aed`)
- Administer Oxygen (needs `oxygen_mask`)
- Start IV (needs `iv_bag`)
- Open Airway (no item needed)

### Chest Pain (`MED-20`)
Needs **3** distinct correct treatments to stabilize.
Requires hospital transport to fully complete.

Correct treatments:
- Administer Aspirin (needs `aspirin`)
- Administer Nitroglycerin (needs `nitroglycerin`)
- Administer Oxygen (needs `oxygen_mask`)
- Start IV (needs `iv_bag`)
- Check Pulse (no item needed)
- Perform CPR (no item needed)
- Use AED (needs `aed`)

### Diabetic Emergency (`MED-31`)
Needs **2** distinct correct treatments to stabilize.

Correct treatments:
- Check Blood Glucose (needs `glucose_gel`)
- Administer Glucose (needs `glucose_gel`)
- Start IV (needs `iv_bag`)

### Difficulty Breathing (`MED-36`)
Needs **1** distinct correct treatments to stabilize.
Requires hospital transport to fully complete.

Correct treatments:
- Administer Oxygen (needs `oxygen_mask`)
- Check Breathing (no item needed)
- Start IV (needs `iv_bag`)

### Drowning (`MED-50`)
Needs **2** distinct correct treatments to stabilize.
Requires hospital transport to fully complete.

Correct treatments:
- Open Airway (no item needed)
- Administer Oxygen (needs `oxygen_mask`)
- Perform CPR (no item needed)
- Check Breathing (no item needed)

### Fall Injury (`MED-45`)
Needs **2** distinct correct treatments to stabilize.
Requires hospital transport to fully complete.

Correct treatments:
- Trauma Assessment (no item needed)
- Apply Splint (needs `splint`)
- Administer Oxygen (needs `oxygen_mask`)
- Check Pulse (no item needed)

### Gunshot Wound (`MED-1`)
Needs **3** distinct correct treatments to stabilize.
Requires hospital transport to fully complete.

Correct treatments:
- Apply Direct Pressure (needs `bandage`)
- Apply Bandage (needs `bandage`)
- Apply Tourniquet (needs `tourniquet`)
- Administer Oxygen (needs `oxygen_mask`)
- Start IV (needs `iv_bag`)
- Trauma Assessment (no item needed)

### Intoxicated Unresponsive Person (`MED-14`)
Needs **2** distinct correct treatments to stabilize.
Requires hospital transport to fully complete.

Correct treatments:
- Open Airway (no item needed)
- Administer Oxygen (needs `oxygen_mask`)
- Check Breathing (no item needed)
- Start IV (needs `iv_bag`)

### Multiple Gunshot Wounds (`MED-2`)
Needs **4** distinct correct treatments to stabilize.
Requires hospital transport to fully complete.

Correct treatments:
- Apply Direct Pressure (needs `bandage`)
- Apply Tourniquet (needs `tourniquet`)
- Apply Chest Seal (needs `chest_seal`)
- Administer Oxygen (needs `oxygen_mask`)
- Start IV (needs `iv_bag`)
- Trauma Assessment (no item needed)
- Perform CPR (no item needed)
- Use AED (needs `aed`)

### Pedestrian Struck (`MED-40`)
Needs **3** distinct correct treatments to stabilize.
Requires hospital transport to fully complete.

Correct treatments:
- Trauma Assessment (no item needed)
- Apply Splint (needs `splint`)
- Administer Oxygen (needs `oxygen_mask`)
- Start IV (needs `iv_bag`)
- Apply Direct Pressure (needs `bandage`)

### Possible Stroke (`MED-25`)
Needs **2** distinct correct treatments to stabilize.
Requires hospital transport to fully complete.

Correct treatments:
- Administer Oxygen (needs `oxygen_mask`)
- Check Pulse (no item needed)
- Trauma Assessment (no item needed)
- Start IV (needs `iv_bag`)

### Seizure (`MED-30`)
Needs **2** distinct correct treatments to stabilize.
Requires hospital transport to fully complete.

Correct treatments:
- Check Blood Glucose (needs `glucose_gel`)
- Administer Oxygen (needs `oxygen_mask`)
- Trauma Assessment (no item needed)
- Check Pulse (no item needed)

### Single-Vehicle Accident (`MED-41`)
Needs **3** distinct correct treatments to stabilize.
Requires hospital transport to fully complete.

Correct treatments:
- Trauma Assessment (no item needed)
- Apply Splint (needs `splint`)
- Administer Oxygen (needs `oxygen_mask`)
- Start IV (needs `iv_bag`)
- Apply Chest Seal (needs `chest_seal`)

### Stabbing (`MED-3`)
Needs **2** distinct correct treatments to stabilize.
Requires hospital transport to fully complete.

Correct treatments:
- Apply Direct Pressure (needs `bandage`)
- Pack Wound with Gauze (needs `gauze`)
- Apply Bandage (needs `bandage`)
- Apply Chest Seal (needs `chest_seal`)
- Administer Oxygen (needs `oxygen_mask`)
- Start IV (needs `iv_bag`)
- Trauma Assessment (no item needed)

### Unresponsive Person (`MED-12`)
*Dispatch shows this generically - real condition is hidden from EMS.*
Needs **2** distinct correct treatments to stabilize.
Requires hospital transport to fully complete.

Correct treatments:
- Open Airway (no item needed)
- Administer Oxygen (needs `oxygen_mask`)
- Administer Narcan (needs `narcan`)
- Start IV (needs `iv_bag`)
- Check Breathing (no item needed)
- Check Pulse (no item needed)

### Unresponsive Person (`MED-13`)
*Dispatch shows this generically - real condition is hidden from EMS.*
Needs **2** distinct correct treatments to stabilize.
Requires hospital transport to fully complete.

Correct treatments:
- Administer Oxygen (needs `oxygen_mask`)
- Start IV (needs `iv_bag`)
- Check Pulse (no item needed)
- Trauma Assessment (no item needed)

### Unresponsive Person (`MED-99`)
*Dispatch shows this generically - real condition is hidden from EMS.*
*Mystery call - resolves randomly to one of: opioid_overdose, diabetic_low, stroke, heart_attack, alcohol_poisoning, cardiac_arrest. Treatments below are shown per underlying condition further down this doc.*
