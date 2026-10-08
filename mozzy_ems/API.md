# Mozzy EMS Simulator — API Reference

Everything below is **server-side** unless noted. All exports are on the
resource name `mozzy_ems`.

## Exports

### `exports.mozzy_ems:AddCall(opts)`

Programmatically create a simulator call from another resource.

```lua
local callId = exports.mozzy_ems:AddCall({
    type = 'shooting',        -- a Config.Calls key OR a Config.CallAliases shorthand
    coords = vec3(120.0, -800.0, 30.0), -- optional; omit to let the generator pick a location
    heading = 90.0,            -- optional, used with `coords` if it isn't already a vec4
    patientCount = 1,          -- optional, clamped to Config.MaxPatientsPerCall
})

if not callId then
    -- second return value is an error string: 'invalid_call_type' | 'no_valid_location' | 'no_call_types_available'
end
```

### `exports.mozzy_ems:GetActiveCalls()`

Returns an array of call summaries currently in progress:

```lua
{
    { id, label, dispatchCode, priority, coords, state, narrative, responderCount },
    ...
}
```

### `exports.mozzy_ems:GetPatientState(callId, patientIndex)`

Returns `{ state, consciousness, vitals, outcome }` for one patient, or
`nil` if the call/patient doesn't exist. `patientIndex` defaults to `1`.

### `exports.mozzy_ems:CompleteCall(callId)`

Force-resolves every unresolved patient on a call as `'stabilized'`
(triggers normal payout/XP/DB logging for whoever responded). Returns
`true`/`false`.

### `exports.mozzy_ems:CancelCall(callId)`

Cancels a call with no payout and cleans up client-side scenes for every
responder. Returns `true`/`false`.

---

## Bridging an external dispatch resource

Edit `bridge/dispatch.lua`. `server/calls.lua` always calls
`MozzyEMS.Dispatch.Announce(call, recipients)` — it never needs to know
which backend is active. Set `Config.Dispatch = 'lb'` and adjust the export
call in the `'lb'` branch to match your dispatch resource's real API, or use
`'custom'` and fill in the stub. If your backend call fails (e.g. the
resource isn't running), it silently falls back to the built-in standalone
notification so EMS always gets the call either way.

## Bridging an external ambulance/EMS gameplay resource

Edit `bridge/medical.lua`. Three hooks are provided:

- `MozzyEMS.Medical.UsesExternalStretcher()` — return `true` if your
  external resource should own the stretcher/transport flow instead of the
  built-in one in `client/transport.lua`
- `MozzyEMS.Medical.NotifyPatientDelivered(callId, hospitalLabel)` — fired
  when a simulator patient is delivered, in case your resource wants to
  log/animate it
- `MozzyEMS.Medical.GetAmbulanceModels()` — override the static
  `Config.Ambulances` list with one your resource maintains dynamically

Set `Config.ExternalMedicalResource = 'your_resource_name'` and implement
`MozzyEMS_OnPatientDelivered` / `MozzyEMS_GetAmbulanceModels` exports on
that resource for the pcall'd hooks to reach it.

## Bridging a different framework

Everything qbx-specific is isolated in `bridge/framework.lua`. The rest of
the resource only ever calls:

- `MozzyEMS.Framework.IsEMS(source)` / `.IsOnDuty(source)` / `.CanWorkEMS(source)`
- `MozzyEMS.Framework.GetOnDutyEMSSources()` / `.GetOnDutyEMSCount()`
- `MozzyEMS.Framework.GetPlayer(source)` / `.GetCitizenId(source)` / `.GetPlayerName(source)`
- `MozzyEMS.Framework.AddMoney(source, amount, reason)`
- `MozzyEMS.Framework.Notify(source, msg, type, duration)`
- `MozzyEMS.Framework.IsAdmin(source)`
- Client-side equivalents: `GetPlayerData()`, `IsEMS()`, `IsOnDuty()`,
  `CanWorkEMS()`, `GetJobLabel()`, `Notify(msg, type, duration)`

Reimplement these against your framework of choice and nothing else in the
resource needs to change.

## Key internal events (for reference — not a stable public API)

These are what `client/`↔`server/` use internally
(`shared/constants.lua` → `MozzyEMS.Events`). They're documented here in
case you need to hook into them from a custom UI, but they aren't
guaranteed stable across versions the way the exports above are.

| Event | Direction | Payload |
|---|---|---|
| `NewCallOffer` | S→C | dispatch card data |
| `acceptCall` / `declineCall` | C→S | `callId` |
| `SpawnScene` | S→C | full scene data for an accepted call |
| `PatientStateUpdate` | S→C | live vitals/state push |
| `PerformTreatment` | C→S | `{ callId, patientIndex, treatmentId }` |
| `TreatmentResult` | S→C | correctness + updated vitals, or a rejection reason |
| `RequestVitals` / `VitalsResult` | C→S / S→C | on-demand patient assessment |
| `LoadPatient` / `DeliverPatient` | C→S | transport lifecycle |
| `CallComplete` | S→C | final score card |
| `CleanupScene` | S→C | tells every responder's client to despawn a finished/cancelled call |

## Database schema

See `sql/mozzy_ems.sql`. Three tables:

- `mozzy_ems_profiles` — per-citizen XP/stat totals
- `mozzy_ems_call_history` — one row per completed call, per responder
- `mozzy_ems_stats` — reserved for future per-scenario completion counts
  (not currently written to — add a call in `server/rewards.lua` if you
  want to start populating it)
