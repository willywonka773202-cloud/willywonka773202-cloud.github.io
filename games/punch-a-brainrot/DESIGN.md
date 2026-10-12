# Punch a Brainrot — design

A fusion of three things already in the Build Ledger — **Punch Sim** (strength
progression), **Steal a Slime** (base + steal loop) and **BrainrotBazaar**
(creatures that print income) — plus one bought template to supply the half
nobody has written twice.

## The template pick

**[FREE Punch Simulator](https://builtbybit.com/resources/free-punch-simulator.96536/)**
(BuiltByBit resource 96536) — free, unobfuscated, and it ships exactly the spine
this fusion needs: a strength progression system, a rank ladder tied to strength
milestones, training zones, and a pet system that multiplies punch power.

Why this one over the paid Steal-a-Brainrot kits:

- **The steal half is already in-house.** SlimeFlip and BrainrotBazaar already
  have base plots, collectors that generate passive income, and a steal loop.
  Buying a [Steal a Brainrot template](https://builtbybit.com/resources/steal-a-brainrot-template.93392/)
  would be paying for systems that already exist in the archive.
- **It costs nothing to evaluate.** The strength/rank spine is the piece worth
  copying, and it can be read before committing.
- **Licence surface.** The Punch Sim launch-ops audit found gamepass and
  developer-product IDs still paying the template's original seller. A free,
  DRM-free resource removes that whole class of problem — and the checklist in
  the README exists so it cannot happen again regardless.

If the monetization scaffolding is wanted later rather than the mechanics, the
upgrade path is [Steal a Brainrot Retro Template](https://builtbybit.com/resources/steal-a-brainrot-retro-template.91358/)
— it advertises the gamepass/dev-product/leaderboard/spin-wheel layer rather
than the core loop.

## The fusion thesis

Most "combined" Roblox games bolt two loops side by side: a simulator grind in
one corner, a tycoon in another, sharing nothing but a cash counter. That gives
players two half-games.

Here the loops share **one variable: strength**.

```
        ┌──────────── punch the bag ────────────┐
        │                                       ▼
   brainrots on pads ──► cash ──► training ──► STRENGTH
        ▲                 │                     │
        │                 │                     ▼
        │                 │            damage per punch
        │                 │                     │
        │                 ▼                     ▼
        └──── deposit ◄── carry home ◄── break a rival's lock
```

- Every brainrot on your plot prints `$/sec`.
- Cash buys **training upgrades**, which raise strength per punch.
- Strength sets **punch damage**.
- Punch damage is what breaks the **lock** on a rival's brainrot — and lock HP
  scales with rarity, so strength is literally the gate on what tier of loot you
  can take.
- Stolen loot is not instant: you carry it home slowed, and defenders punch your
  **grip** to knock it loose. Grip also scales with strength.
- Better loot prints more cash, which buys more training, which breaks bigger
  locks.

Nothing in that graph is optional decoration. Remove the punching and the steal
loop has no skill gate; remove the brainrots and the punching has no purpose.

## The balance fit

The gate only works if damage tracks rarity. Lock HP rises ~4x per rarity tier,
while the strength needed for the next rank rises ~8–10x. So damage must grow
roughly as `strength^0.61` for a rank to keep unlocking exactly one tier.

The rank damage multipliers (1.0 → 5.0 across nine ranks) already supply about
`0.11` of that exponent, which leaves `~0.5` for the raw strength term:

```
damage = 1.2 * sqrt(strength) * rankMult * rebirthMult
```

Checked against every rank, "punches to break your own tier's lock":

| Rank | Strength | Damage | Tier | Punches |
|---|---|---|---|---|
| Gym Rat | 500 | 31 | Uncommon (600) | 19 |
| Bruiser | 5K | 115 | Rare (2.4K) | 21 |
| Slugger | 40K | 384 | Rare (2.4K) | 6 |
| Ironfist | 250K | 1.2K | Epic (9.5K) | 8 |
| Titan | 1.5M | 3.7K | Legendary (38K) | 10 |
| Brainrot Breaker | 10M | 12.1K | Mythic (150K) | 12 |
| Mythic Knuckle | 60M | 37.2K | Brainrot God (600K) | 16 |
| Godhand | 400M | 120K | Secret (2.5M) | 21 |

Roughly 6–21 punches — about 2–8 seconds of sustained hitting — at every stage
of a 400-million-strength curve.

### Lock regeneration is the real gate

Locks heal 6%/sec after 6 seconds without a hit. To finish a lock at all you
need `damage / punchCooldown > 0.06 * lockHP`, i.e. roughly `lockHP < 48x` your
damage. That means punching above your weight is *possible but tight* — a Titan
can just barely take a Mythic — and punching two tiers up is arithmetically
impossible no matter how long you stand there. The gate enforces itself without
a single "you are not strong enough" message.

## Anti-grief rules

These exist because a pure steal loop drives new players off the server:

- **5 minute join grace** — a new base cannot be robbed at all.
- **45s steal cooldown** per thief.
- **30s protection** on any brainrot that just changed hands, so two players
  cannot ping-pong the same loot.
- **Carrying is loud and slow** — reduced walk speed, a name tag over your head,
  and a grip bar anyone can punch down.
- **Dropped loot returns home** after 20 seconds unclaimed, and logging out mid
  raid returns it immediately. Loot never disappears from the economy.
- **Raiding still trains you** (50% of a bag punch), so a failed raid is not
  wasted time — this is what stops players from refusing to ever engage.

## What is deliberately simple

- **The shop places directly onto a free pad** rather than making you carry
  purchases home. Buying is the safe on-ramp; stealing is the risky scaling
  path. Keeping the carry mechanic exclusive to steals is what makes a carried
  brainrot *read* as stolen goods.
- **Global shop stock.** Everyone on the server sees the same four slots and the
  same reroll timer, so a good roll is a race.
- **One snapshot remote.** The client rebuilds its whole HUD from a single
  server push twice a second instead of a dozen value objects, so there is no
  partial-update skew to debug.

## Balance status

The numbers are a **fitted first pass, not playtested**. The fit above proves
the curve is self-consistent; it does not prove it is fun. Every value lives in
`src/shared/Config.luau` precisely so the tuning pass is a one-file edit.

The two most likely to need moving after the first session:

1. `TrainingCostGrowth` (1.75) vs `TrainingGainGrowth` (1.32) — this decides
   whether the mid-game feels like a wall.
2. `NewPlayerGraceSeconds` (300) — too short and new players quit, too long and
   the server has no targets.
