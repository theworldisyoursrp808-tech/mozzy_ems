# Configuration Reference

All config lives under `config/`. Nothing here requires touching client or
server logic.

## config/shared.lua

| Section | Key | What it does |
|---|---|---|
| Jobs | `Config.EMSJobs` | Job **names** allowed to work calls (e.g. `ambulance`) |
| Jobs | `Config.EMSJobTypes` | Job **types** allowed to work calls (qbx's `ambulance` job ships as type `ems`) |
| Jobs | `Config.RequireDuty` | Require `job.onduty` to receive/accept calls or treat patients |
| Generation | `Config.CallGeneration.enabled` | Master on/off (also toggleable live via `/emsadmin`) |
| Generation | `minInterval` / `maxInterval` | Random seconds between auto-generated calls |
| Generation | `minimumEMS` | On-duty EMS required before calls generate |
| Generation | `maximumActiveCalls` | Hard concurrent call cap |
| Generation | `callExpiration` | Seconds an unassigned call stays open before expiring |
| Generation | `locationCooldown` / `scenarioCooldown` | Prevents the same spot/scenario firing back-to-back |
| Generation | `allowImmediateRepeat` | If false, actively avoids repeating the last scenario type |
| Admin | `Config.AdminCommand` / `AdminMenuCommand` / `TrainingCommand` | Command names |
| Admin | `Config.AdminAcePermission` / `Config.AdminGroups` | Permission gating (see README §5) |
| Difficulty | `Config.Difficulty` | `easy` / `normal` / `hard` |
| Difficulty | `Config.DifficultySettings[...]` | Deterioration speed, complication chance, vitals precision per difficulty |
| Claiming | `Config.CallClaimMode` | `'open'` (anyone can join) or `'claim'` (first accept becomes primary) |
| Claiming | `Config.AllowMultipleResponders` / `MaxRespondersPerCall` | Multi-medic calls |
| Claiming | `Config.MaxPatientsPerCall` | Hard cap on patients spawned per call |
| Payment | `Config.Payment.*` | Base pay, severity multiplier, transport/resuscitation bonuses, per-treatment bonus/penalty, account type |
| XP | `Config.Experience.*` | XP amounts and the simulator rank ladder (does **not** touch the player's real qbx job grade) |
| Training | `Config.Training.*` | Whether training calls pay/grant XP/count toward stats |
| Mass Casualty | `Config.MassCasualty.*` | Patient count range for `mci` training calls, admin-only flag |
| Scene | `Config.Scene.*` | Bystander/prop spawn chances, prop cap |
| Blips | `Config.Blips.*` | Approximate-then-reveal blip behaviour, colors by priority |
| Debug/Logging | `Config.Debug` / `Config.Webhook.*` | Console debug output and Discord webhook events |
| Database | `Config.Database.enabled` | Turns all persistence on/off |
| Vehicles | `Config.Ambulances` | Model hashes counted as valid transport vehicles |
| Bridges | `Config.Dispatch` | `'standalone'` / `'lb'` / `'custom'` — see `bridge/dispatch.lua` |
| Bridges | `Config.ExternalMedicalResource` | Resource name to bridge stretcher/hospital hooks into, or `false` for the built-in flow |

## config/items.lua

`Config.Items` maps internal item keys (used throughout the config/engine)
to your actual `ox_inventory` item names — rename the values, not the keys.

`Config.ItemBehaviour` controls, per item key, whether it's `required` to
attempt the treatment and whether it's `consume`d on use (equipment like
`aed`/`oxygen_tank` are reusable by default; dressings/medication are
consumed).

`Config.OxInventoryItemDefinitions` is a ready-to-paste block for
`ox_inventory/data/items.lua` — it is **not** loaded automatically.

## config/hospitals.lua

`Config.Hospitals` is an unlimited array of `{ label, coords, radius, blip }`.
Any listed hospital is a valid delivery zone; the first in the list is used
as the default GPS suggestion after loading a patient.

## config/locations.lua

`Config.CallLocations` is an unlimited array of
`{ id, coords (vec4), category, radius }`. `Config.LocationCategories`
lists the valid category strings. A call type's `locations` field is a list
of these categories — the generator only picks locations whose category is
in that list (or whose `id` is explicitly whitelisted via the call's
`allowedCalls`, if you set one).

## config/treatments.lua

`Config.Treatments` is the master equipment/action list EMS always sees
regardless of call type (a real medic doesn't know in advance which item is
correct). Each entry: `label`, `category` (drives the ox_target icon),
`item` (key into `Config.Items`, or `nil` for no-item actions like CPR),
`duration` (progress bar ms), `anim`. `isCPR` / `isAED` flag the two
treatments that run through the dedicated resuscitation path in
`server/treatment.lua` instead of the generic vitals-delta path.

## config/calls.lua — the scenario library

This is the file you'll spend the most time in. Full field reference is in
the comment block at the top of the file; summary:

- `label`, `dispatchCode`, `priority` (1 critical / 2 serious / 3 stable),
  `enabled`, `weight`, `minEMS`, `locations`
- `hidden` — if true, dispatch/UI only ever show the generic label (used for
  "unresponsive person" style calls where EMS has to work out the real cause)
- `mystery` / `mysteryPool` — special case for `unconscious_unknown`: the
  *real* underlying condition is randomly drawn from `mysteryPool` at
  generation time and drives all the actual vitals/treatment logic, while
  dispatch/UI only ever show this block's generic fields
- `callerText`, `bystanderLines`, `patientDialogue` — flavor text pools
- `ped` — `{ models, animation, consciousChance, cardiacArrestChance }`
- `vitals` — min/max ranges the engine rolls initial values from
- `injuries` / `injuryCount` — pool + how many to draw
- `validTreatments` — the set of treatment ids that are medically correct
  for this condition
- `treatmentEffects` — per treatment id, the vital deltas applied on a
  *correct* administration (diminishing returns after the 2nd application)
- `requiredCorrectTreatments` — distinct correct treatments needed to reach
  the `stabilized` patient state
- `deterioration` — `{ enabled, interval, pulse, bpSys, bpDia, resp, spo2,
  glucose, worsensConsciousness, canArrest }`, applied every `interval`
  seconds while the patient hasn't yet been stabilized
- `resuscitation` — only for scenarios that can hit cardiac arrest:
  `{ roscBaseChance, roscPerCPRCycle, aedShockable, maxCycles }`
- `transportRequired`, `reward = { min, max }`, `scene = { vehicle,
  bloodProp, drugProp }`

`Config.CallAliases` maps short admin-command words (`overdose`, `shooting`,
`arrest`, ...) to the real call type ids for `/emscall` and `/emstraining`.

## Difficulty behaviour

| | Easy | Normal | Hard |
|---|---|---|---|
| Deterioration speed | 0.5x | 1x | 1.5x |
| Wrong-treatment complication chance | 5% | 15% | 30% |
| Vitals precision | exact | exact | rounded to nearest 5 |

`revealDiagnosisHint` exists in `Config.DifficultySettings.easy` as a hook
for a future "soft hint" UI — the engine doesn't currently surface it
anywhere, so treat it as a placeholder if you want to build that.
