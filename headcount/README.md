# HEADCOUNT

A 1–4 player co-op horror game for Roblox. A crew rides a lift down into a dark facility to bring back samples. Something down there wears one crew member's avatar and name, and walks the exact path that person walked a few seconds ago. Keep counting heads.

**Status: first playable slice, not yet run in Roblox Studio.** Every script passes a syntax check, but nothing here has been executed in the engine. Expect a round of bug fixing on first launch (see "First launch" below).

## Open it

**Easy way (no installs):** open `Headcount.rbxlx` in Roblox Studio, then press Play.

**Rojo way (for ongoing work):** install [Rojo](https://rojo.space), run `rojo serve` in this folder, and connect from the Rojo plugin in Studio.

After editing anything in `src/`, rebuild the place file with `python3 tools/build_place.py`.

### Settings to check in Studio (one time)

| Setting | Where | Why |
|---|---|---|
| Technology = **Future** | Explorer > Lighting > Properties | Real-time shadows from every light. The look depends on it. |
| Enable Studio Access to API Services | Game Settings > Security | Lets credits and upgrades save. The game runs without it. |
| Max players = 4 | Game Settings > Places | The game is tuned for a crew of 1–4. |
| Voice chat on | Game Settings > Communication | "Was that you?" is the game. |

## How it plays

1. **Staging.** Bright metal room. Spend credits on upgrades (`B`). The lift leaves on a timer.
2. **Expedition.** A new facility layout every run. Find glowing samples, carry up to 3, drop them at the lift pad. The pad also recharges your light.
3. **The copy.** After a short delay it spawns as a clone of one crew member and replays that player's recorded movement.
   - With the group, it trails its target and stops a few steps behind them.
   - If its target is **alone** for a few seconds, it starts replaying their path faster than they walked it. The gap closes.
   - A **lit flashlight pointed at it freezes it.**
   - It makes **no footsteps**, and the facility hum **fades to silence** as it gets close.
4. **Headcount (`Q`).** Tells everyone nearby how many bodies are in range. Compare with "Crew alive".
5. **Accuse (hold `E` on a person).** Right: it is banished for a while and the crew is paid. Wrong: your light dies and every copy gets closer.
6. **Leave.** Meet the quota and get everyone alive onto the lift. Each night survived makes the next one worse and pays more.

Controls: `F` light, `Q` headcount, `Shift` sprint, `E` collect / accuse, `B` shop. Touch devices get on-screen buttons.

## Where the quality comes from

Roblox does not support custom shaders. The look is built from the lighting engine, post-processing, materials and sound, all set in code:

| Piece | File | What it does |
|---|---|---|
| Lighting and grade | `src/ServerScriptService/Modules/Atmosphere.lua` | Near-total darkness, thick air, desaturated colour, bloom, depth of field, stone-corridor reverb |
| Dread effects | `src/ReplicatedStorage/Client/Effects.lua` | Colour drains, view narrows and shakes, lights stutter, hand-held flashlight sway |
| Sound | `src/ReplicatedStorage/Client/AudioDirector.lua` | Hum that dies near the copy, rising low layer, heartbeat that speeds up |
| UI | `src/ReplicatedStorage/Client/Theme.lua`, `HUD.lua` | One style for every screen: colours and fonts live in `Theme.lua` |
| Loading screen | `src/ReplicatedFirst/Loading.client.lua` | Replaces the default Roblox loader |
| Level | `src/ServerScriptService/Modules/MapGenerator.lua` | Procedural rooms, pipes, clutter, puddles, broken lights |
| Tuning | `src/ReplicatedStorage/Shared/Config.lua` | Every number in the game |

## What only you can do in Studio

Code cannot supply these, and they are the difference between "works" and "looks expensive":

1. **Replace the placeholder audio.** `Config.Sounds` uses sounds built into the Roblox client, slowed down and run through reverb. Swap each `Id` for a real asset from the Creator Store: a room-tone drone, a heartbeat, a sting, footsteps on concrete. This is the single biggest upgrade.
2. **Add PBR materials.** In Studio's Material Manager, create MaterialVariants for Concrete, Metal and CorrodedMetal with real texture maps. The generated level picks them up automatically.
3. **Replace box props with models.** `clutter()` in `MapGenerator.lua` builds crates, shelves and drums from plain parts. Swap in Creator Store meshes.
4. **Tune by eye.** Play in the dark with headphones and adjust `Atmosphere.lua` and `Config.lua`.
5. **Make an icon and thumbnails.** These decide whether anyone clicks.

## First launch

Things most likely to need a fix, in order:

- **The copy's movement.** It is driven by physics constraints so it looks smooth to other players. If it jitters, floats or sinks, the fix is in `Mimic:spawn` in `Mimic.lua`.
- **The copy's animation.** It reads the run and idle animations from the cloned avatar. If it slides without moving its legs, check `findAnimation` in `Mimic.lua`.
- **Lighting technology.** If the facility looks flat with no shadows, Technology is not set to Future.
- **Placeholder sound names.** If a sound is silent, that built-in file name is wrong; replacing it with a real asset fixes it.

Testing alone works: with one player the copy copies you and hunts whenever it is not being watched. Use Studio's Test tab > "Start" with 2–4 players to test the group behaviour.
