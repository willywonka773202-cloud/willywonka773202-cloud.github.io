--!strict
-- Runtime state + every derived stat in the game.
--
-- This is the single place that answers "how hard does this player punch",
-- "how much do they earn", "what does the next upgrade cost". Services ask
-- here instead of re-deriving, so a balance change in Config lands everywhere
-- at once.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Ranks = require(Shared.Ranks)
local Remotes = require(Shared.Remotes)
local Brainrots = require(Shared.Brainrots)

local DataService = require(script.Parent.DataService)

export type Carried = {
	brainrotId: string,
	victimUserId: number?, -- nil when it came from the shop rather than a raid
	pickedUpAt: number,
}

export type State = {
	player: Player,
	profile: DataService.Profile,
	plotIndex: number?,
	carried: Carried?,
	grip: number,
	lastPunchAt: number,
	lastStealAt: number,
	joinedAt: number,
	dirty: boolean,
}

local PlayerState = {}

local states: { [Player]: State } = {}

function PlayerState.add(player: Player, profile: DataService.Profile): State
	local state: State = {
		player = player,
		profile = profile,
		plotIndex = nil,
		carried = nil,
		grip = 0,
		lastPunchAt = 0,
		lastStealAt = 0,
		joinedAt = os.clock(),
		dirty = true,
	}
	states[player] = state
	return state
end

function PlayerState.get(player: Player): State?
	return states[player]
end

function PlayerState.remove(player: Player)
	states[player] = nil
end

function PlayerState.all(): { [Player]: State }
	return states
end

-- ── Derived stats ─────────────────────────────────────────────────────────

-- Rebirths buff income and damage on the same curve, so a rebirth is never a
-- pure economy play or a pure combat play.
function PlayerState.rebirthMultiplier(state: State): number
	return 1 + state.profile.rebirths * Config.RebirthMultiplierStep
end

function PlayerState.rank(state: State): Ranks.Rank
	return Ranks.forStrength(state.profile.strength)
end

-- Damage one punch lands on a lock or a carrier's grip.
function PlayerState.punchDamage(state: State): number
	local strength = math.max(state.profile.strength, 0)
	local raw = Config.DamageBase * (strength ^ Config.DamageStrengthExponent)
	return raw * PlayerState.rank(state).damageMult * PlayerState.rebirthMultiplier(state)
end

-- Strength gained from one training-bag punch.
function PlayerState.trainingGain(state: State): number
	local growth = Config.TrainingGainGrowth ^ state.profile.trainingLevel
	return Config.BaseTrainingGain * growth * PlayerState.rebirthMultiplier(state)
end

function PlayerState.trainingCash(state: State): number
	local growth = Config.TrainingGainGrowth ^ state.profile.trainingLevel
	return Config.BaseTrainingCash * growth * PlayerState.rebirthMultiplier(state)
end

function PlayerState.trainingCost(state: State): number?
	if state.profile.trainingLevel >= Config.MaxTrainingLevel then
		return nil
	end
	return math.floor(Config.TrainingCostBase * (Config.TrainingCostGrowth ^ state.profile.trainingLevel))
end

function PlayerState.padCost(state: State): number?
	if state.profile.pads >= Config.MaxPads then
		return nil
	end
	local bought = state.profile.pads - Config.StartingPads
	return math.floor(Config.PadCostBase * (Config.PadCostGrowth ^ bought))
end

-- How much punishment the player can absorb before dropping stolen loot.
function PlayerState.maxGrip(state: State): number
	local strength = math.max(state.profile.strength, 0)
	return Config.GripBase + (strength ^ Config.DamageStrengthExponent) * Config.GripPerStrength
end

function PlayerState.income(state: State): number
	local total = 0
	for _, placed in state.profile.brainrots do
		local brainrot = Brainrots.get(placed.id)
		if brainrot then
			total += Brainrots.income(brainrot)
		end
	end
	return total * PlayerState.rebirthMultiplier(state)
end

function PlayerState.rebirthRequirement(state: State): (number, number)
	local n = state.profile.rebirths
	local cash = Config.RebirthCashBase * (Config.RebirthCashGrowth ^ n)
	local strength = Config.RebirthStrengthBase * (Config.RebirthStrengthGrowth ^ n)
	return math.floor(cash), math.floor(strength)
end

function PlayerState.canBeRobbed(state: State): boolean
	return os.clock() - state.joinedAt >= Config.NewPlayerGraceSeconds
end

-- ── Mutations ─────────────────────────────────────────────────────────────

function PlayerState.addCash(state: State, amount: number)
	state.profile.cash = math.max(0, state.profile.cash + amount)
	state.dirty = true
end

function PlayerState.addStrength(state: State, amount: number)
	state.profile.strength = math.max(0, state.profile.strength + amount)
	state.dirty = true
end

function PlayerState.placedAt(state: State, pad: number): string?
	for _, placed in state.profile.brainrots do
		if placed.pad == pad then
			return placed.id
		end
	end
	return nil
end

function PlayerState.setPlaced(state: State, pad: number, brainrotId: string?)
	for index, placed in state.profile.brainrots do
		if placed.pad == pad then
			if brainrotId then
				placed.id = brainrotId
			else
				table.remove(state.profile.brainrots, index)
			end
			state.dirty = true
			return
		end
	end
	if brainrotId then
		table.insert(state.profile.brainrots, { pad = pad, id = brainrotId })
		state.dirty = true
	end
end

function PlayerState.firstFreePad(state: State): number?
	for pad = 1, state.profile.pads do
		if not PlayerState.placedAt(state, pad) then
			return pad
		end
	end
	return nil
end

-- ── Replication ───────────────────────────────────────────────────────────

-- One snapshot remote instead of a dozen value objects: the client rebuilds
-- its whole HUD from this, so there is no partial-update skew to debug.
function PlayerState.snapshot(state: State): { [string]: any }
	local rank = PlayerState.rank(state)
	local nextRank = Ranks.next(rank)
	local rebirthCash, rebirthStrength = PlayerState.rebirthRequirement(state)

	return {
		cash = state.profile.cash,
		strength = state.profile.strength,
		rebirths = state.profile.rebirths,
		income = PlayerState.income(state),
		damage = PlayerState.punchDamage(state),
		rankName = rank.name,
		rankBreaks = rank.breaks,
		rankProgress = Ranks.progress(state.profile.strength),
		nextRankName = if nextRank then nextRank.name else nil,
		nextRankStrength = if nextRank then nextRank.strength else nil,
		pads = state.profile.pads,
		padCost = PlayerState.padCost(state),
		trainingLevel = state.profile.trainingLevel,
		trainingCost = PlayerState.trainingCost(state),
		trainingGain = PlayerState.trainingGain(state),
		rebirthCash = rebirthCash,
		rebirthStrength = rebirthStrength,
		carrying = if state.carried then state.carried.brainrotId else nil,
		grip = state.grip,
		maxGrip = PlayerState.maxGrip(state),
		steals = state.profile.steals,
		robbed = state.profile.robbed,
		plotIndex = state.plotIndex,
		graceRemaining = math.max(0, Config.NewPlayerGraceSeconds - (os.clock() - state.joinedAt)),
	}
end

function PlayerState.push(state: State)
	Remotes.get("StateChanged"):FireClient(state.player, PlayerState.snapshot(state))
end

function PlayerState.toast(state: State, message: string, kind: string?)
	Remotes.get("Toast"):FireClient(state.player, message, kind or "info")
end

return PlayerState
