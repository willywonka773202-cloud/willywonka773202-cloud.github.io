--!strict
-- Central tuning table. Every balance number in the game lives here so the
-- whole economy can be retuned without touching a service.

local Config = {}

-- ── Core loop ─────────────────────────────────────────────────────────────
Config.IncomeTickSeconds = 1
Config.AutosaveSeconds = 90
Config.OfflineEarningsCapHours = 4

-- ── Punching ──────────────────────────────────────────────────────────────
Config.PunchCooldown = 0.35
Config.PunchReach = 12
Config.PunchArcDegrees = 70

-- Strength gained per successful training punch, before multipliers.
Config.BaseTrainingGain = 1
-- Cash granted per successful training punch, before multipliers.
Config.BaseTrainingCash = 2

-- ── Strength → damage ─────────────────────────────────────────────────────
-- damage = DamageBase * strength^Exponent * rankMult * rebirthMult
--
-- Exponent and base are fitted, not guessed: lock HP rises ~4x per rarity tier
-- while the strength needed for the next rank rises ~8x, and the rank damage
-- multipliers cover the rest. A square root lands each rank at roughly 20
-- punches to break its own tier's lock. See DESIGN.md for the fit.
Config.DamageStrengthExponent = 0.5
Config.DamageBase = 1.2

-- ── Stealing ──────────────────────────────────────────────────────────────
Config.StealCooldownSeconds = 45
-- How long a brainrot cannot be stolen again after changing hands.
Config.StolenProtectionSeconds = 30
-- Locks heal back if the attacker gives up, so chip damage cannot bank progress.
Config.LockRegenDelay = 6
Config.LockRegenPercentPerSecond = 0.06
-- New players cannot be robbed while they find their feet.
Config.NewPlayerGraceSeconds = 300

-- ── Carrying stolen loot ──────────────────────────────────────────────────
Config.CarryWalkSpeed = 12
Config.NormalWalkSpeed = 16
-- Grip is the carrier's health bar while holding loot. Defenders punch it down.
Config.GripBase = 100
Config.GripPerStrength = 0.35
-- Fraction of a defender's punch damage that applies to grip.
Config.GripDamageScale = 0.02
-- A dropped brainrot is claimable by anyone for this long, then it goes home.
Config.DroppedClaimWindow = 20

-- ── Plots ─────────────────────────────────────────────────────────────────
Config.PlotCount = 6
Config.StartingPads = 3
Config.MaxPads = 9
-- Cost of the Nth extra pad = PadCostBase * PadCostGrowth ^ (n - 1)
Config.PadCostBase = 5000
Config.PadCostGrowth = 3.4

-- ── Upgrades ──────────────────────────────────────────────────────────────
-- Training upgrades are the strength faucet.
--   gain at level n = BaseTrainingGain * TrainingGainGrowth ^ n
--   cost of level n = TrainingCostBase  * TrainingCostGrowth ^ n
-- Cost grows faster than gain on purpose, so an upgrade is always a real
-- decision against buying another brainrot.
Config.TrainingCostBase = 150
Config.TrainingCostGrowth = 1.75
Config.TrainingGainGrowth = 1.32
Config.MaxTrainingLevel = 45

-- Punching a rival lock also trains you, at this fraction of a bag punch, so
-- raiding is never a detour away from progression.
Config.StealPunchTrainingShare = 0.5

-- ── Rebirth ───────────────────────────────────────────────────────────────
-- Requirement for rebirth n = RebirthCashBase * RebirthCashGrowth ^ n
Config.RebirthCashBase = 1000000
Config.RebirthCashGrowth = 8
Config.RebirthStrengthBase = 25000
Config.RebirthStrengthGrowth = 10
-- Each rebirth adds this much to every income and damage multiplier.
Config.RebirthMultiplierStep = 0.5

-- ── Shop ──────────────────────────────────────────────────────────────────
Config.ShopRerollSeconds = 120
Config.ShopSlots = 4

-- ── World generation ──────────────────────────────────────────────────────
Config.PlotSize = Vector3.new(64, 1, 64)
Config.PlotSpacing = 90
Config.PadSpacing = 14
Config.BaseHeight = 0

return Config
