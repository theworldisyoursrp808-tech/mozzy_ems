# Mozzy EMS Simulator

Advanced dynamic EMS call & patient simulation system for **Qbox / QBX Core**.

Gives EMS/ambulance players realistic, randomized medical emergencies to
respond to when there's no real player who needs help — full dispatch,
assessment, diagnosis, treatment, deterioration, transport, and scoring, not
just "spawn an NPC and press E to revive."

Every medical scenario (gunshot wounds, overdoses, cardiac arrest, strokes,
vehicle accidents, drownings, etc.) is defined as **data** in
`config/calls.lua`. The client/server engine has no per-condition code, so
you can add a new emergency by copying a config block — you never touch
`client/` or `server/` logic to do it.

---

## 1. Dependencies

- [`qbx_core`](https://github.com/Qbox-project/qbx_core) — this resource was built directly against the file set you supplied (ambulance job, type `ems`, `PlayerData.job`, `GetDutyCountType`/`GetDutyCountJob`, `AddMoney`, etc.)
- `ox_lib`
- `ox_inventory`
- `ox_target`
- `oxmysql` (only required if `Config.Database.enabled = true`)

Everything framework-specific lives in `bridge/framework.lua` — if you ever
move off qbx_core, that's the only file to rewrite.

## 2. Installation

1. Drop the `mozzy_ems` folder into your resources directory.
2. Add the item definitions from `config/items.lua`
   (`Config.OxInventoryItemDefinitions`) into your `ox_inventory/data/items.lua`,
   or your own equivalents — then update `Config.Items` if you rename any of them.
3. If you're using persistent stats (`Config.Database.enabled = true`, the
   default), import `sql/mozzy_ems.sql` into your database.
4. Add `ensure mozzy_ems` to your `server.cfg`, **after** `qbx_core`,
   `ox_lib`, `ox_inventory`, and `ox_target`.
5. Grant the admin ACE permission (see [Admin & Training](#5-admin--training) below).
6. Review `config/shared.lua` for the settings you actually want live —
   defaults are sane but generic (see `CONFIGURATION.md`).

That's it — EMS players who go on duty will start receiving simulated calls.

## 3. How a call plays out

```
Dispatch → Respond → Assess → Diagnose → Treat → Stabilize → Transport → Complete
```

1. The server picks a random enabled scenario (respecting cooldowns, minimum
   on-duty EMS, and active-call caps) and announces it to every on-duty EMS
   player as a dispatch card with an **Accept** / **Decline** choice.
2. Accepting sets a GPS waypoint and spawns the scene (patient NPC(s),
   optional bystander, optional blood/vehicle/drug props) once you're close.
3. Target the patient to **Assess** (reveals vitals, visible injuries, and
   consciousness — the *real* diagnosis is never shown, only symptoms) or
   **Treat** (opens the full EMS equipment menu — nothing is filtered by
   "correct" answer, you have to work it out from the vitals/injuries/scene,
   exactly like the source spec asked for).
4. Every treatment attempt round-trips to the server, which is the only
   thing that ever decides whether it helped, did nothing, or made things
   worse. Vitals update live for every responder on the call.
5. If the patient needs transport, load them near a configured ambulance
   (`Config.Ambulances`) and drive to any hospital in `Config.Hospitals` —
   delivery is automatic on arrival.
6. On completion you get a score card: response time, correct/incorrect
   treatment counts, transport status, payment, and XP.

## 4. Adding a new medical emergency

Open `config/calls.lua`, copy any existing `Config.Calls['...']` block, and
change:

- `label` / `dispatchCode` / `priority` / `weight` / `locations`
- `vitals` ranges, `injuries` pool, `ped.models`/`animation`
- `validTreatments` (the correct answer set) and `treatmentEffects` (what
  each correct treatment does to vitals)
- `deterioration` and, if it can go into cardiac arrest, a `resuscitation`
  block
- `reward`

Nothing else needs to change — the generator, dispatch, treatment engine,
and scoring all read this table generically. See the field reference
comment at the top of `config/calls.lua`.

## 5. Admin & Training

- `/emscall [type]` — force-generate a call at your location (any registered
  call id or the short alias list in `Config.CallAliases`, e.g. `overdose`,
  `shooting`, `arrest`).
- `/emstraining [type] [mci]` — same, but flagged as training (no payout/XP,
  doesn't touch stats by default — see `Config.Training`). Add `mci` as the
  second argument for a multi-patient mass-casualty scene
  (`Config.MassCasualty`), with each patient auto-tagged RED/YELLOW/GREEN/BLACK.
- `/emsadmin` — full management menu: toggle the generator on/off, spawn any
  scenario at your position, list active calls, cancel a call, or force-clear
  a stuck patient.

Admin access is gated by `Config.AdminAcePermission` (default
`mozzy_ems.admin`). Grant it in `server.cfg`:

```
add_ace group.admin mozzy_ems.admin allow
```

or set `Config.AdminAcePermission = false` to fall back to the qbx group
allow-list in `Config.AdminGroups`.

## 6. Files

See `CONFIGURATION.md` for every config option and `API.md` for the
exports/events other resources can use to hook in (custom dispatch, external
ambulance/stretcher scripts, or scripting your own calls from another
resource).
