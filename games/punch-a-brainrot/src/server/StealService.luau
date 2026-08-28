--!strict
-- Carrying, dropping and depositing stolen brainrots.
--
-- A steal is deliberately not instant: breaking the lock only starts the job.
-- The thief then has to walk the loot home while slowed, and anyone can punch
-- it back out of their hands. That walk is where the shooter-style combat from
-- the raiding half of the design actually happens.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Brainrots = require(Shared.Brainrots)
local Rarities = require(Shared.Rarities)

local PlayerState = require(script.Parent.PlayerState)
local PlotService = require(script.Parent.PlotService)

local StealService = {}

local carryModels: { [Player]: Model } = {}
local droppedFolder: Folder? = nil

local function lootFolder(): Folder
	if droppedFolder and droppedFolder.Parent then
		return droppedFolder
	end
	local folder = Instance.new("Folder")
	folder.Name = "DroppedLoot"
	folder.Parent = workspace
	droppedFolder = folder
	return folder
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function setWalkSpeed(player: Player, speed: number)
	local humanoid = humanoidOf(player)
	if humanoid then
		humanoid.WalkSpeed = speed
	end
end

local function colorFor(brainrot: Brainrots.Brainrot): Color3
	local rarity = Rarities.get(brainrot.rarity)
	return if rarity then rarity.color else Color3.fromRGB(200, 200, 200)
end

-- ── Visuals ───────────────────────────────────────────────────────────────

local function buildCarryModel(brainrot: Brainrots.Brainrot, root: BasePart): Model
	local model = Instance.new("Model")
	model.Name = `Carried_{brainrot.id}`

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(2.6, 3.2, 2)
	body.Color = brainrot.torso
	body.Material = Enum.Material.SmoothPlastic
	body.CanCollide = false
	body.Massless = true
	body.CFrame = root.CFrame * CFrame.new(0, 3.4, 0)
	body.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = root
	weld.Parent = body

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(7, 1.4)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 300

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextStrokeTransparency = 0.3
	label.TextColor3 = colorFor(brainrot)
	label.Text = `STOLEN: {brainrot.name}`
	label.Parent = billboard
	billboard.Parent = body

	model.PrimaryPart = body
	return model
end

local function clearCarryModel(player: Player)
	local model = carryModels[player]
	if model then
		model:Destroy()
		carryModels[player] = nil
	end
end

-- ── Dropped loot ──────────────────────────────────────────────────────────

local function returnHome(brainrotId: string, ownerUserId: number?)
	if not ownerUserId then
		return
	end
	for player, state in PlayerState.all() do
		if player.UserId == ownerUserId then
			local plot = PlotService.forPlayer(player)
			local pad = PlayerState.firstFreePad(state)
			if plot and pad and PlotService.spawnBrainrot(plot, pad, brainrotId) then
				PlayerState.setPlaced(state, pad, brainrotId)
				PlayerState.push(state)
				PlayerState.toast(state, "A stolen brainrot found its way home.", "good")
			end
			return
		end
	end
end

local function spawnDropped(brainrotId: string, position: Vector3, ownerUserId: number?)
	local brainrot = Brainrots.get(brainrotId)
	if not brainrot then
		return
	end

	local part = Instance.new("Part")
	part.Name = `Dropped_{brainrotId}`
	part.Size = Vector3.new(2.6, 2.6, 2.6)
	part.Color = brainrot.torso
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CFrame = CFrame.new(position + Vector3.new(0, 2, 0))
	part.Parent = lootFolder()

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(8, 1.4)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 250
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextStrokeTransparency = 0.3
	label.TextColor3 = colorFor(brainrot)
	label.Text = `DROPPED: {brainrot.name}`
	label.Parent = billboard
	billboard.Parent = part

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Grab"
	prompt.ObjectText = brainrot.name
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	local claimed = false

	prompt.Triggered:Connect(function(claimer: Player)
		if claimed then
			return
		end
		local state = PlayerState.get(claimer)
		if not state then
			return
		end
		if state.carried then
			PlayerState.toast(state, "You are already carrying something.", "warn")
			return
		end
		claimed = true
		part:Destroy()
		StealService.giveCarry(state, brainrotId, ownerUserId)
	end)

	-- Unclaimed loot goes back to whoever lost it, rather than littering the map.
	task.delay(Config.DroppedClaimWindow, function()
		if claimed then
			return
		end
		claimed = true
		if part.Parent then
			part:Destroy()
		end
		returnHome(brainrotId, ownerUserId)
	end)
end

-- ── Carry lifecycle ───────────────────────────────────────────────────────

function StealService.giveCarry(state: PlayerState.State, brainrotId: string, victimUserId: number?)
	local brainrot = Brainrots.get(brainrotId)
	local root = rootOf(state.player)
	if not brainrot or not root then
		-- No character to hang it on; send it back rather than deleting loot.
		returnHome(brainrotId, victimUserId)
		return
	end

	clearCarryModel(state.player)

	state.carried = {
		brainrotId = brainrotId,
		victimUserId = victimUserId,
		pickedUpAt = os.clock(),
	}
	state.grip = PlayerState.maxGrip(state)

	local model = buildCarryModel(brainrot, root)
	model.Parent = state.player.Character
	carryModels[state.player] = model

	setWalkSpeed(state.player, Config.CarryWalkSpeed)
	PlayerState.push(state)
end

-- Called when a defender punches the grip to zero, when the carrier dies, or
-- when they drop it voluntarily.
function StealService.drop(state: PlayerState.State, reason: string)
	local carried = state.carried
	if not carried then
		return
	end

	state.carried = nil
	state.grip = 0
	clearCarryModel(state.player)
	setWalkSpeed(state.player, Config.NormalWalkSpeed)

	local root = rootOf(state.player)
	local position = if root then root.Position else Vector3.new(0, Config.BaseHeight + 3, 0)
	spawnDropped(carried.brainrotId, position, carried.victimUserId)

	PlayerState.toast(state, `You dropped the loot ({reason}).`, "bad")
	PlayerState.push(state)
end

-- Walk it home: the carried brainrot becomes yours and starts printing.
function StealService.deposit(state: PlayerState.State, padIndex: number): boolean
	local carried = state.carried
	if not carried then
		return false
	end

	local plot = PlotService.forPlayer(state.player)
	if not plot then
		return false
	end

	-- padIndex <= 0 means "wherever it fits": the client asks for this so it
	-- never has to mirror the server's pad bookkeeping.
	if padIndex <= 0 then
		local free = PlayerState.firstFreePad(state)
		if not free then
			PlayerState.toast(state, "No free pad -- sell one first.", "warn")
			return false
		end
		padIndex = free
	end

	local pad = plot.pads[padIndex]
	if not pad or not pad.unlocked or pad.brainrotId then
		PlayerState.toast(state, "That pad is not free.", "warn")
		return false
	end

	local root = rootOf(state.player)
	if not root or (root.Position - pad.anchor.Position).Magnitude > 24 then
		PlayerState.toast(state, "Get closer to your pad.", "warn")
		return false
	end

	if not PlotService.spawnBrainrot(plot, padIndex, carried.brainrotId) then
		return false
	end

	PlayerState.setPlaced(state, padIndex, carried.brainrotId)
	state.carried = nil
	state.grip = 0
	clearCarryModel(state.player)
	setWalkSpeed(state.player, Config.NormalWalkSpeed)

	if carried.victimUserId then
		state.profile.steals += 1
	end
	state.dirty = true
	PlayerState.push(state)
	return true
end

-- ── Grip combat ───────────────────────────────────────────────────────────

-- Returns true when the punch knocked the loot loose.
function StealService.damageGrip(carrier: PlayerState.State, damage: number): boolean
	if not carrier.carried then
		return false
	end
	carrier.grip = math.max(0, carrier.grip - damage * Config.GripDamageScale)
	if carrier.grip <= 0 then
		StealService.drop(carrier, "punched loose")
		return true
	end
	PlayerState.push(carrier)
	return false
end

-- ── Lifecycle hooks ───────────────────────────────────────────────────────

function StealService.onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	humanoid.WalkSpeed = Config.NormalWalkSpeed

	humanoid.Died:Connect(function()
		local state = PlayerState.get(player)
		if state and state.carried then
			StealService.drop(state, "you went down")
		end
	end)
end

function StealService.onPlayerRemoving(player: Player)
	local state = PlayerState.get(player)
	if state and state.carried then
		-- Do not let logging out mid-raid delete someone else's brainrot.
		returnHome(state.carried.brainrotId, state.carried.victimUserId)
		state.carried = nil
	end
	clearCarryModel(player)
end

function StealService.init()
	Players.PlayerRemoving:Connect(StealService.onPlayerRemoving)
end

return StealService
