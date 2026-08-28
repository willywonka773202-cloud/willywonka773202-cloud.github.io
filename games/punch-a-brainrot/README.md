# Punch a Brainrot

A complete, self-contained Roblox game project that fuses the strength ladder
from a Punch Simulator template with the base/steal/income loop from the
SlimeFlip and BrainrotBazaar lines. See [DESIGN.md](DESIGN.md) for why these
two halves were picked and how they share a single progression variable.

**One sentence:** brainrots on your pads print cash, cash buys training,
training buys strength, and strength is the only thing that breaks the lock on
somebody else's brainrot.

## Build

```bash
rojo build -o PunchABrainrot.rbxlx     # one-off place file
rojo serve                             # live-sync into Studio
```

The world is generated entirely in code at runtime — there is no map asset to
import. `rojo build` on a bare checkout produces a place that boots straight
into a playable server.

## Layout

```
src/shared/          → ReplicatedStorage.Shared
  Config.luau          every tunable number in the game
  Rarities.luau        8 tiers: income, lock HP, price, roll weight
  Brainrots.luau       17 collectibles (original names, no borrowed IP)
  Ranks.luau           9 strength ranks and the rarity each one cracks
  Format.luau          shared number formatting
  Remotes.luau         remote creation (server) / lookup (client)

src/server/          → ServerScriptService.Server
  init.server.luau     boot order, player lifecycle, remote handlers, loops
  DataService.luau     DataStore load/save, autosave, BindToClose flush
  PlayerState.luau     runtime state + every derived stat
  PlotService.luau     world generation, plots, pads, locks, lock regen
  EconomyService.luau  income tick, upgrades, selling, rebirth
  CombatService.luau   server-authoritative punch resolution
  StealService.luau    carry, drop, deposit, grip combat
  ShopService.luau     global rotating shop

src/client/          → StarterPlayer.StarterPlayerScripts.Client
  init.client.luau     wires server pushes into the HUD
  Hud.luau             stats, shop, base actions, carry banner, toasts
  PunchController.luau input only (mouse / E / gamepad / touch button)
  LockBars.luau        lock HP bars, driven by replicated Attributes
  Ui.luau              declarative element helpers
```

## How it plays

1. You are assigned a plot on join (6 plots, ring layout, all facing the middle
   so raids are visible from anywhere).
2. Punch the training bag on any plot to gain strength and a little cash.
3. Buy brainrots from the rotating shop; they land on a free pad and start
   printing `$/sec`.
4. Walk to a rival's plot and punch the **lock** on the brainrot you want. Lock
   HP scales with rarity, so what you can take is set by your rank.
5. Break it and you are **carrying** — slowed, labelled, and punchable. Get home
   and hit *Place At My Base*, or lose it.
6. Defend by punching thieves, not your own locks. Their grip bar drops; at zero
   the loot hits the floor and anyone can grab it.
7. Rebirth resets cash, strength and your base for a permanent multiplier on
   both income and damage.

## Verification status

Every one of the 19 source files compiles clean under `luau-compile`, and
`luau-analyze` reports nothing beyond cross-file `require` resolution and
Roblox globals that a standalone analyzer cannot see.

**It has not been run in Studio.** The balance curve is fitted arithmetic
(the table in DESIGN.md), not measured play. Treat the first Studio session as
the real test.

## Before publishing — checklist

- [ ] **Create your own gamepass and developer-product IDs.** Nothing in this
      project references any, by design. Any ID copied in from a template keeps
      paying whoever created it. This is the exact failure the Punch Sim launch
      audit caught, and it is silent — the game works fine while the money goes
      somewhere else.
- [ ] Add a punch animation. `PunchController` fires the remote but plays no
      animation, because that needs an `Animation` asset published under your
      own account.
- [ ] Enable Studio API access, or `DataService` will run in memory-only mode
      (it detects this and stops trying to write rather than spamming errors).
- [ ] Tune `Config.TrainingCostGrowth` / `TrainingGainGrowth` after the first
      real session — see the balance-status note in DESIGN.md.
- [ ] Consider raising `Config.PlotCount` past 6 if you want fuller servers;
      the ring layout derives its radius from the count, so it just works.

## Design notes worth keeping

- The client never decides what it hit. `Punch` is fired with **no arguments** —
  the server picks the target from position and facing. A modified client can
  spam the cooldown and nothing else.
- Lock HP replicates as **Attributes**, so the HP bars cost no remotes.
- Lock regeneration (6%/sec after 6s idle) is what actually enforces the rank
  gate: below a damage threshold you can never finish a lock, however long you
  stand there.
- Loot is conserved. Dropped, unclaimed, or orphaned-by-logout brainrots all
  return to the player they were taken from.
