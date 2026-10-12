--!strict
-- Income, upgrades and rebirth. The passive side of the loop: what the
-- brainrots you have managed to keep hold of are actually paying you.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Brainrots = require(Shared.Brainrots)

local PlayerState = require(script.Parent.PlayerState)
local PlotService = require(script.Parent.PlotService)

local EconomyService = {}

-- Runs on the income tick: pay everyone for what is standing on their pads.
function EconomyService.tick(deltaTime: number)
	for _, state in PlayerState.all() do
		local income = PlayerState.income(state)
		if income > 0 then
			PlayerState.addCash(state, income * deltaTime)
		end
	end
end

-- Paid once at join, capped so that logging off is never the optimal play.
function EconomyService.grantOfflineEarnings(state: PlayerState.State)
	local elapsed = os.time() - state.profile.lastSeen
	if elapsed <= 60 then
		return
	end

	local capped = math.min(elapsed, Config.OfflineEarningsCapHours * 3600)
	local earned = PlayerState.income(state) * capped
	if earned <= 0 then
		return
	end

	PlayerState.addCash(state, earned)
	PlayerState.toast(state, `Welcome back -- your base earned {Format.cash(earned)}.`, "good")
end

function EconomyService.buyTraining(state: PlayerState.State)
	local cost = PlayerState.trainingCost(state)
	if not cost then
		PlayerState.toast(state, "Training is maxed.", "warn")
		return
	end
	if state.profile.cash < cost then
		PlayerState.toast(state, `Need {Format.cash(cost)} to upgrade training.`, "warn")
		return
	end

	PlayerState.addCash(state, -cost)
	state.profile.trainingLevel += 1
	state.dirty = true
	PlayerState.toast(state, `Training level {state.profile.trainingLevel}.`, "good")
	PlayerState.push(state)
end

function EconomyService.buyPad(state: PlayerState.State)
	local cost = PlayerState.padCost(state)
	if not cost then
		PlayerState.toast(state, "All pads unlocked.", "warn")
		return
	end
	if state.profile.cash < cost then
		PlayerState.toast(state, `Need {Format.cash(cost)} for the next pad.`, "warn")
		return
	end

	PlayerState.addCash(state, -cost)
	state.profile.pads += 1
	state.dirty = true

	local plot = PlotService.forPlayer(state.player)
	if plot then
		PlotService.syncPads(plot, state.profile.pads)
	end

	PlayerState.toast(state, `Pad {state.profile.pads} unlocked.`, "good")
	PlayerState.push(state)
end

function EconomyService.sell(state: PlayerState.State, padIndex: number)
	local plot = PlotService.forPlayer(state.player)
	if not plot then
		return
	end

	local brainrotId = PlayerState.placedAt(state, padIndex)
	if not brainrotId then
		return
	end

	local brainrot = Brainrots.get(brainrotId)
	if not brainrot then
		return
	end

	-- Half price back, so selling is a way to free a pad, not a way to farm.
	local refund = math.floor(Brainrots.price(brainrot) * 0.5)

	PlotService.clearPad(plot, padIndex)
	PlayerState.setPlaced(state, padIndex, nil)
	PlayerState.addCash(state, refund)
	PlayerState.toast(state, `Sold {brainrot.name} for {Format.cash(refund)}.`, "info")
	PlayerState.push(state)
end

function EconomyService.rebirth(state: PlayerState.State)
	local cashNeeded, strengthNeeded = PlayerState.rebirthRequirement(state)

	if state.profile.cash < cashNeeded or state.profile.strength < strengthNeeded then
		PlayerState.toast(
			state,
			`Rebirth needs {Format.cash(cashNeeded)} and {Format.short(strengthNeeded)} strength.`,
			"warn"
		)
		return
	end

	if state.carried then
		PlayerState.toast(state, "Put your loot down first.", "warn")
		return
	end

	local plot = PlotService.forPlayer(state.player)
	if plot then
		for _, pad in plot.pads do
			PlotService.clearPad(plot, pad.index)
		end
	end

	state.profile.rebirths += 1
	state.profile.cash = 0
	state.profile.strength = 0
	state.profile.trainingLevel = 0
	state.profile.pads = Config.StartingPads
	state.profile.brainrots = {}
	state.dirty = true

	if plot then
		PlotService.syncPads(plot, state.profile.pads)
	end

	local multiplier = PlayerState.rebirthMultiplier(state)
	PlayerState.toast(state, `REBIRTH {state.profile.rebirths} -- everything x{string.format("%.1f", multiplier)}.`, "good")
	PlayerState.push(state)
end

return EconomyService
