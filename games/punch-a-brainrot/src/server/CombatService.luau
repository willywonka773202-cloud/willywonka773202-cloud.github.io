--!strict
-- Punch resolution. The client sends "I punched" and nothing else -- the
-- server picks the target, so a modified client can at best spam the cooldown,
-- never choose what it hits or how hard.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Brainrots = require(Shared.Brainrots)
local Remotes = require(Shared.Remotes)

local PlayerState = require(script.Parent.PlayerState)
local PlotService = require(script.Parent.PlotService)
local StealService = require(script.Parent.StealService)

local CombatService = {}

local ARC_COS = math.cos(math.rad(Config.PunchArcDegrees / 2))

local function rootOf(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Is `position` inside the punch cone in front of `root`?
local function inArc(root: BasePart, position: Vector3): (boolean, number)
	local offset = position - root.Position
	local distance = offset.Magnitude
	if distance > Config.PunchReach then
		return false, distance
	end
	if distance < 0.1 then
		return true, distance
	end
	local dot = offset.Unit:Dot(root.CFrame.LookVector)
	return dot >= ARC_COS, distance
end

local function feedback(state: PlayerState.State, payload: { [string]: any })
	Remotes.get("PunchFeedback"):FireClient(state.player, payload)
end

-- ── Target selection ──────────────────────────────────────────────────────

-- A rival carrying loot is always the most urgent target: hitting them is the
-- only counterplay a defender has once the lock is already broken.
local function findCarrier(state: PlayerState.State, root: BasePart): PlayerState.State?
	local best: PlayerState.State? = nil
	local bestDistance = math.huge

	for player, other in PlayerState.all() do
		if player ~= state.player and other.carried then
			local otherRoot = rootOf(player)
			if otherRoot then
				local hit, distance = inArc(root, otherRoot.Position)
				if hit and distance < bestDistance then
					best = other
					bestDistance = distance
				end
			end
		end
	end
	return best
end

local function findLock(state: PlayerState.State, root: BasePart): ({ plot: PlotService.Plot, pad: PlotService.Pad })?
	local parts = workspace:GetPartBoundsInRadius(root.Position, Config.PunchReach)
	local best: ({ plot: PlotService.Plot, pad: PlotService.Pad })? = nil
	local bestDistance = math.huge

	for _, part in parts do
		if PlotService.isLock(part) then
			local info = PlotService.lockInfo(part)
			-- You cannot punch your own locks; defending is done by punching
			-- the thief, not the loot.
			if info and info.plot.owner ~= state.player then
				local hit, distance = inArc(root, part.Position)
				if hit and distance < bestDistance then
					best = info
					bestDistance = distance
				end
			end
		end
	end
	return best
end

local function findBag(state: PlayerState.State, root: BasePart): PlotService.Plot?
	local parts = workspace:GetPartBoundsInRadius(root.Position, Config.PunchReach)
	for _, part in parts do
		if PlotService.isBag(part) then
			local hit = inArc(root, part.Position)
			if hit then
				return PlotService.bagPlot(part)
			end
		end
	end
	return nil
end

-- ── Resolutions ───────────────────────────────────────────────────────────

local function punchBag(state: PlayerState.State)
	local gain = PlayerState.trainingGain(state)
	local cash = PlayerState.trainingCash(state)
	local beforeRank = PlayerState.rank(state).name

	PlayerState.addStrength(state, gain)
	PlayerState.addCash(state, cash)

	local afterRank = PlayerState.rank(state).name
	if afterRank ~= beforeRank then
		PlayerState.toast(state, `RANK UP: {afterRank}`, "good")
	end

	feedback(state, { kind = "train", strength = gain, cash = cash })
	PlayerState.push(state)
end

local function punchLock(state: PlayerState.State, info: { plot: PlotService.Plot, pad: PlotService.Pad })
	local plot, pad = info.plot, info.pad
	local owner = plot.owner
	if not owner or not pad.brainrotId then
		return
	end

	local now = os.clock()

	if state.carried then
		feedback(state, { kind = "blocked", reason = "Drop your loot first." })
		return
	end
	if now < pad.protectedUntil then
		feedback(state, { kind = "blocked", reason = "This one was just moved." })
		return
	end
	if now - state.lastStealAt < Config.StealCooldownSeconds then
		local remaining = Config.StealCooldownSeconds - (now - state.lastStealAt)
		feedback(state, { kind = "blocked", reason = `Steal cooldown {math.ceil(remaining)}s` })
		return
	end

	local ownerState = PlayerState.get(owner)
	if ownerState and not PlayerState.canBeRobbed(ownerState) then
		feedback(state, { kind = "blocked", reason = "That base is still protected." })
		return
	end

	local damage = PlayerState.punchDamage(state)
	pad.lockHP = math.max(0, pad.lockHP - damage)
	pad.lastHitAt = now

	local lock = pad.lock
	if lock then
		lock:SetAttribute("LockHP", pad.lockHP)
	end

	-- Raiding trains you too, so a failed raid is never wasted time.
	local trainingShare = PlayerState.trainingGain(state) * Config.StealPunchTrainingShare
	PlayerState.addStrength(state, trainingShare)

	feedback(state, {
		kind = "lock",
		damage = damage,
		lockHP = pad.lockHP,
		lockMax = pad.lockMax,
	})

	if pad.lockHP > 0 then
		PlayerState.push(state)
		return
	end

	-- Lock broken: the loot leaves the victim's plot immediately, but the thief
	-- still has to carry it home.
	local brainrotId = PlotService.clearPad(plot, pad.index)
	if not brainrotId then
		return
	end

	if ownerState then
		PlayerState.setPlaced(ownerState, pad.index, nil)
		ownerState.profile.robbed += 1
		ownerState.dirty = true
		local brainrot = Brainrots.get(brainrotId)
		local name = if brainrot then brainrot.name else brainrotId
		PlayerState.toast(ownerState, `{state.player.DisplayName} ripped your {name} loose!`, "bad")
		PlayerState.push(ownerState)
	end

	state.lastStealAt = now
	StealService.giveCarry(state, brainrotId, owner.UserId)
	feedback(state, { kind = "steal", brainrotId = brainrotId })
	PlayerState.toast(state, "Lock broken -- get it back to your base!", "good")
end

local function punchCarrier(state: PlayerState.State, carrier: PlayerState.State)
	local damage = PlayerState.punchDamage(state)
	local knocked = StealService.damageGrip(carrier, damage)

	feedback(state, {
		kind = "carrier",
		damage = damage,
		target = carrier.player.DisplayName,
		knocked = knocked,
	})

	if knocked then
		PlayerState.toast(state, `You knocked the loot out of {carrier.player.DisplayName}!`, "good")
	end
end

-- ── Entry point ───────────────────────────────────────────────────────────

function CombatService.handlePunch(player: Player)
	local state = PlayerState.get(player)
	if not state then
		return
	end

	local now = os.clock()
	if now - state.lastPunchAt < Config.PunchCooldown then
		return
	end
	state.lastPunchAt = now

	local root = rootOf(player)
	if not root then
		return
	end

	state.profile.punches += 1
	state.dirty = true

	local carrier = findCarrier(state, root)
	if carrier then
		punchCarrier(state, carrier)
		return
	end

	local lockInfo = findLock(state, root)
	if lockInfo then
		punchLock(state, lockInfo)
		return
	end

	local bagPlot = findBag(state, root)
	if bagPlot then
		punchBag(state)
		return
	end

	feedback(state, { kind = "miss" })
end

return CombatService
