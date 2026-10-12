--!strict
-- World generation and plot ownership.
--
-- Everything here is built in code -- there is no map asset to import, so the
-- plot count, pad grid and brainrot models all follow from Config. Locks carry
-- their HP as Attributes so the client can render bars without another remote.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Brainrots = require(Shared.Brainrots)
local Rarities = require(Shared.Rarities)
local Format = require(Shared.Format)

export type Pad = {
	index: number,
	anchor: BasePart,
	brainrotId: string?,
	model: Model?,
	lock: BasePart?,
	lockHP: number,
	lockMax: number,
	lastHitAt: number,
	unlocked: boolean,
	protectedUntil: number,
}

export type Plot = {
	index: number,
	owner: Player?,
	origin: CFrame,
	model: Model,
	pads: { Pad },
	bag: BasePart,
	sign: BillboardGui,
}

local TAG_LOCK = "PABLock"
local TAG_BAG = "PABTrainingBag"

local PlotService = {}

local plots: { Plot } = {}
local plotByPlayer: { [Player]: Plot } = {}
local padByLock: { [BasePart]: { plot: Plot, pad: Pad } } = {}
local plotByBag: { [BasePart]: Plot } = {}

-- ── Build helpers ─────────────────────────────────────────────────────────

local function makePart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(part :: any)[key] = value
	end
	return part
end

local function makeLabel(parent: Instance, size: UDim2, offset: Vector3, maxDistance: number): (BillboardGui, TextLabel)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = size
	billboard.StudsOffsetWorldSpace = offset
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = maxDistance
	billboard.LightInfluence = 0

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.4
	label.Text = ""
	label.Parent = billboard

	billboard.Parent = parent
	return billboard, label
end

-- ── Brainrot model ────────────────────────────────────────────────────────

local function buildBrainrotModel(brainrot: Brainrots.Brainrot, anchor: BasePart): (Model, BasePart)
	local rarity = Rarities.get(brainrot.rarity)
	local rarityColor = if rarity then rarity.color else Color3.fromRGB(200, 200, 200)

	local model = Instance.new("Model")
	model.Name = brainrot.id

	local basePosition = anchor.Position + Vector3.new(0, anchor.Size.Y / 2, 0)

	local body = makePart({
		Name = "Body",
		Size = Vector3.new(3.4, 4.2, 2.6),
		Color = brainrot.torso,
		CFrame = CFrame.new(basePosition + Vector3.new(0, 2.1, 0)) * anchor.CFrame.Rotation,
		Parent = model,
	})

	local head = makePart({
		Name = "Head",
		Size = Vector3.new(2.6, 2.2, 2.2),
		Color = brainrot.accent,
		CFrame = body.CFrame * CFrame.new(0, 3.2, 0),
		Parent = model,
	})
	local headMesh = Instance.new("SpecialMesh")
	headMesh.MeshType = Enum.MeshType.Sphere
	headMesh.Parent = head

	for _, side in { -0.6, 0.6 } do
		makePart({
			Name = "Eye",
			Size = Vector3.new(0.45, 0.45, 0.2),
			Color = Color3.fromRGB(20, 20, 24),
			CanCollide = false,
			CFrame = head.CFrame * CFrame.new(side, 0.25, -1.05),
			Parent = model,
		})
	end

	-- The lock is the entire steal interaction: punching this is how loot
	-- changes hands, so it sits proud of the model and faces the walkway.
	local lock = makePart({
		Name = "Lock",
		Size = Vector3.new(2.2, 2.2, 1),
		Color = rarityColor,
		Material = Enum.Material.Metal,
		CanCollide = false,
		CFrame = body.CFrame * CFrame.new(0, -0.6, -1.9),
		Parent = model,
	})

	local _, nameLabel = makeLabel(body, UDim2.fromScale(7, 1.5), Vector3.new(0, 4.4, 0), 220)
	nameLabel.Text = brainrot.name
	nameLabel.TextColor3 = rarityColor

	local _, incomeLabel = makeLabel(body, UDim2.fromScale(6, 1.1), Vector3.new(0, 3.4, 0), 180)
	incomeLabel.Text = Format.rate(Brainrots.income(brainrot))
	incomeLabel.TextColor3 = Color3.fromRGB(150, 235, 160)

	model.PrimaryPart = body
	return model, lock
end

-- ── Plot construction ─────────────────────────────────────────────────────

local function buildPad(plot: Plot, index: number, parent: Model): Pad
	-- 3x3 grid centred on the plot, laid out behind the training bag.
	local column = (index - 1) % 3
	local row = (index - 1) // 3
	local offset = Vector3.new(
		(column - 1) * Config.PadSpacing,
		0.6,
		(row - 1) * Config.PadSpacing - 6
	)

	local anchor = makePart({
		Name = `Pad{index}`,
		Size = Vector3.new(9, 1.2, 9),
		Color = Color3.fromRGB(58, 62, 74),
		Material = Enum.Material.Concrete,
		CFrame = plot.origin * CFrame.new(offset),
		Parent = parent,
	})

	local _, label = makeLabel(anchor, UDim2.fromScale(6, 1.2), Vector3.new(0, 1.6, 0), 140)
	label.Name = "PadLabel"
	label.Text = "LOCKED"
	label.TextColor3 = Color3.fromRGB(150, 150, 160)

	return {
		index = index,
		anchor = anchor,
		brainrotId = nil,
		model = nil,
		lock = nil,
		lockHP = 0,
		lockMax = 0,
		lastHitAt = 0,
		unlocked = false,
		protectedUntil = 0,
	}
end

local function buildPlot(index: number): Plot
	local angle = ((index - 1) / Config.PlotCount) * math.pi * 2
	local radius = (Config.PlotSpacing * Config.PlotCount) / (math.pi * 2)
	local position = Vector3.new(math.cos(angle) * radius, Config.BaseHeight, math.sin(angle) * radius)
	-- Every plot faces the shared middle of the map, so raids are visible.
	local origin = CFrame.lookAt(position, Vector3.new(0, Config.BaseHeight, 0))

	local model = Instance.new("Model")
	model.Name = `Plot{index}`

	local floor = makePart({
		Name = "Floor",
		Size = Config.PlotSize,
		Color = Color3.fromRGB(38, 40, 50),
		Material = Enum.Material.Slate,
		CFrame = origin * CFrame.new(0, -0.5, 0),
		Parent = model,
	})

	local plot: Plot = {
		index = index,
		owner = nil,
		origin = origin,
		model = model,
		pads = {},
		bag = floor, -- replaced immediately below
		sign = (nil :: any),
	}

	for padIndex = 1, Config.MaxPads do
		table.insert(plot.pads, buildPad(plot, padIndex, model))
	end

	-- Training bag: the strength faucet, parked at the front of the plot where
	-- the owner can watch the walkway while grinding.
	local bag = makePart({
		Name = "TrainingBag",
		Size = Vector3.new(4, 7, 4),
		Color = Color3.fromRGB(184, 84, 60),
		Material = Enum.Material.Fabric,
		CFrame = origin * CFrame.new(0, 3.5, -22),
		Parent = model,
	})
	local bagMesh = Instance.new("SpecialMesh")
	bagMesh.MeshType = Enum.MeshType.Cylinder
	bagMesh.Scale = Vector3.new(1, 1, 1)
	bagMesh.Parent = bag

	local _, bagLabel = makeLabel(bag, UDim2.fromScale(6, 1.4), Vector3.new(0, 5, 0), 200)
	bagLabel.Text = "PUNCH TO TRAIN"
	bagLabel.TextColor3 = Color3.fromRGB(255, 205, 120)

	CollectionService:AddTag(bag, TAG_BAG)
	plot.bag = bag
	plotByBag[bag] = plot

	local signAnchor = makePart({
		Name = "Sign",
		Size = Vector3.new(10, 0.4, 0.4),
		Color = Color3.fromRGB(70, 74, 90),
		CanCollide = false,
		CFrame = origin * CFrame.new(0, 9, -30),
		Parent = model,
	})
	local sign, signLabel = makeLabel(signAnchor, UDim2.fromScale(9, 2), Vector3.new(0, 2.4, 0), 400)
	signLabel.Name = "OwnerLabel"
	signLabel.Text = "OPEN PLOT"
	plot.sign = sign

	return plot
end

function PlotService.init(): { Plot }
	local container = Instance.new("Folder")
	container.Name = "Plots"

	for index = 1, Config.PlotCount do
		local plot = buildPlot(index)
		plot.model.Parent = container
		table.insert(plots, plot)
	end

	-- Middle of the map: a spawn island so nobody spawns inside a base.
	local spawnPad = makePart({
		Name = "SpawnIsland",
		Size = Vector3.new(40, 1, 40),
		Color = Color3.fromRGB(48, 52, 66),
		Material = Enum.Material.Concrete,
		CFrame = CFrame.new(0, Config.BaseHeight - 0.5, 0),
		Parent = container,
	})
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Size = Vector3.new(12, 1, 12)
	spawnLocation.Transparency = 1
	spawnLocation.CanCollide = false
	spawnLocation.Anchored = true
	spawnLocation.Neutral = true
	spawnLocation.CFrame = CFrame.new(0, Config.BaseHeight + 0.6, 0)
	spawnLocation.Parent = spawnPad

	container.Parent = workspace
	return plots
end

-- ── Ownership ─────────────────────────────────────────────────────────────

local function setSignText(plot: Plot, text: string)
	local label = plot.sign:FindFirstChild("OwnerLabel")
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

function PlotService.assign(player: Player): Plot?
	for _, plot in plots do
		if not plot.owner then
			plot.owner = player
			plotByPlayer[player] = plot
			plot.model:SetAttribute("OwnerUserId", player.UserId)
			setSignText(plot, `{player.DisplayName}'s Base`)
			return plot
		end
	end
	return nil
end

function PlotService.release(player: Player)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end

	for _, pad in plot.pads do
		PlotService.clearPad(plot, pad.index)
		PlotService.setPadUnlocked(plot, pad.index, false)
	end

	plot.owner = nil
	plot.model:SetAttribute("OwnerUserId", nil)
	setSignText(plot, "OPEN PLOT")
	plotByPlayer[player] = nil
end

function PlotService.forPlayer(player: Player): Plot?
	return plotByPlayer[player]
end

function PlotService.byIndex(index: number): Plot?
	return plots[index]
end

function PlotService.all(): { Plot }
	return plots
end

-- ── Pads ──────────────────────────────────────────────────────────────────

function PlotService.setPadUnlocked(plot: Plot, padIndex: number, unlocked: boolean)
	local pad = plot.pads[padIndex]
	if not pad then
		return
	end
	pad.unlocked = unlocked
	pad.anchor.Color = if unlocked then Color3.fromRGB(84, 92, 112) else Color3.fromRGB(48, 50, 60)

	local label = pad.anchor:FindFirstChild("PadLabel", true)
	if label and label:IsA("TextLabel") then
		if not unlocked then
			label.Text = "LOCKED"
			label.TextColor3 = Color3.fromRGB(150, 150, 160)
		elseif pad.brainrotId then
			label.Text = ""
		else
			label.Text = "EMPTY"
			label.TextColor3 = Color3.fromRGB(190, 196, 210)
		end
	end
end

function PlotService.syncPads(plot: Plot, unlockedCount: number)
	for index = 1, Config.MaxPads do
		PlotService.setPadUnlocked(plot, index, index <= unlockedCount)
	end
end

function PlotService.spawnBrainrot(plot: Plot, padIndex: number, brainrotId: string): boolean
	local pad = plot.pads[padIndex]
	if not pad or not pad.unlocked or pad.brainrotId then
		return false
	end
	local brainrot = Brainrots.get(brainrotId)
	if not brainrot then
		return false
	end

	local model, lock = buildBrainrotModel(brainrot, pad.anchor)
	model.Parent = plot.model

	local lockMax = Brainrots.lockHP(brainrot)
	pad.brainrotId = brainrotId
	pad.model = model
	pad.lock = lock
	pad.lockMax = lockMax
	pad.lockHP = lockMax
	pad.lastHitAt = 0
	pad.protectedUntil = os.clock() + Config.StolenProtectionSeconds

	-- Attributes replicate on their own, so the lock bar needs no remote.
	lock:SetAttribute("LockHP", lockMax)
	lock:SetAttribute("LockMax", lockMax)
	lock:SetAttribute("PlotIndex", plot.index)
	lock:SetAttribute("PadIndex", padIndex)
	CollectionService:AddTag(lock, TAG_LOCK)
	padByLock[lock] = { plot = plot, pad = pad }

	local label = pad.anchor:FindFirstChild("PadLabel", true)
	if label and label:IsA("TextLabel") then
		label.Text = ""
	end
	return true
end

function PlotService.clearPad(plot: Plot, padIndex: number): string?
	local pad = plot.pads[padIndex]
	if not pad or not pad.brainrotId then
		return nil
	end

	local removedId = pad.brainrotId
	if pad.lock then
		padByLock[pad.lock] = nil
	end
	if pad.model then
		pad.model:Destroy()
	end

	pad.brainrotId = nil
	pad.model = nil
	pad.lock = nil
	pad.lockHP = 0
	pad.lockMax = 0

	local label = pad.anchor:FindFirstChild("PadLabel", true)
	if label and label:IsA("TextLabel") and pad.unlocked then
		label.Text = "EMPTY"
		label.TextColor3 = Color3.fromRGB(190, 196, 210)
	end
	return removedId
end

-- ── Lookups used by hit detection ─────────────────────────────────────────

function PlotService.lockInfo(part: BasePart): ({ plot: Plot, pad: Pad })?
	return padByLock[part]
end

function PlotService.bagPlot(part: BasePart): Plot?
	return plotByBag[part]
end

function PlotService.isLock(part: BasePart): boolean
	return CollectionService:HasTag(part, TAG_LOCK)
end

function PlotService.isBag(part: BasePart): boolean
	return CollectionService:HasTag(part, TAG_BAG)
end

-- ── Lock regeneration ─────────────────────────────────────────────────────

-- Locks heal after the attacker stops. This is what actually enforces the
-- rank gate: if your damage-per-second is below the regen rate you can never
-- finish a lock, no matter how long you stand there.
function PlotService.regenerate(deltaTime: number)
	local now = os.clock()
	for _, plot in plots do
		for _, pad in plot.pads do
			local lock = pad.lock
			if lock and pad.lockHP < pad.lockMax and now - pad.lastHitAt >= Config.LockRegenDelay then
				local healed = pad.lockMax * Config.LockRegenPercentPerSecond * deltaTime
				pad.lockHP = math.min(pad.lockMax, pad.lockHP + healed)
				lock:SetAttribute("LockHP", pad.lockHP)
			end
		end
	end
end

return PlotService
