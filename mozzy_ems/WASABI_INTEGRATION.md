# wasabi_ambulance / wasabi_crutch integration

## What this adds

A new, separate call type: `config/real_calls.lua`, `server/real_calls.lua`,
`client/real_calls.lua`. It does not touch the existing NPC simulator engine
(`config/calls.lua`, `server/patients.lua`, `server/calls.lua`,
`client/calls.lua`, etc.) at all.

- The server polls `Player(id).state.dead` (wasabi_ambulance's own
  documented state bag) every few seconds.
- When a player goes into `laststand` or `dead`, on-duty EMS get a Mozzy EMS
  dispatch card ("Person Down") with a waypoint, same UX pattern as a
  simulator call.
- The actual revive/treatment happens in wasabi_ambulance's own UI, as
  normal - Mozzy EMS doesn't reimplement it.
- When the player's state clears (they're revived), the call auto-completes
  and pays out through `MozzyEMS.Rewards.Calculate()` — the same money/XP
  math simulator calls use.
- If the player was ever in the full `dead` state before revival, or the
  response took longer than `crutchThresholdSeconds`, they're handed to
  wasabi_crutch afterward via its documented server exports
  (`GiveWheelchairTarget` / `GiveCrutchTarget`).

## Why NPC patients still use mozzy_ems's own basic transport

wasabi_ambulance's stretcher exports operate on real networked players
(their own docs' example checks `IsPedAPlayer`/`NetworkGetPlayerIndexFromPed`
before doing anything). Mozzy EMS's simulator patients are plain scene peds,
not players, so there's nothing there for wasabi_ambulance's stretcher to
grab. `bridge/medical.lua`'s `Config.ExternalMedicalResource` hook is left
off for that reason — flipping it on would just make every NPC call
silently fail to load. Full explanation in `bridge/wasabi_ambulance.lua`.

## Setup

1. Both `wasabi_ambulance` and `wasabi_crutch` are optional at runtime —
   everything here checks `GetResourceState(...)` first and no-ops if either
   isn't running. Nothing is added to `dependencies {}` in the manifest.
2. In `wasabi_crutch/configuration/config.lua`, add `'mozzy_ems'` to
   `Config.AllowedResources`, or its `GiveCrutchTarget`/`GiveWheelchairTarget`
   exports will silently refuse the calls from `server/real_calls.lua`:
   ```lua
   Config.AllowedResources = {
       'wasabi_ambulance',
       'mozzy_ems',
   }
   ```
3. Tune `config/real_calls.lua` — in particular `anyPlayer` (whether calls
   fire for any downed player or only ones on an EMS-type job) and the
   `LastingInjury` thresholds.
4. Nothing to change in wasabi_ambulance's own config for this to work — it
   only reads state bags and calls exports it already exposes.

## What wasn't reused

Both scripts' actual gameplay code (`wasabi_ambulance/game/server/server.lua`,
`game/client/knockout.lua`, `game/client/stretcher.lua`,
`wasabi_crutch/server/*.lua`, etc.) is Cfx.re escrow-encrypted (`FXAP`
binary) — standard for paid Tebex scripts. None of it was or could be read;
everything above is built strictly against their published docs at
docs.wasabiscripts.com.
