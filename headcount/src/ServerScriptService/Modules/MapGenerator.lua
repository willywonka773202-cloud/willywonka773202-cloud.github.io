-- Builds a different underground facility every run: a grid of concrete rooms
-- joined by doorways (a maze with a few loops), with pipes, clutter, puddles
-- and ceiling lights that are mostly dead or flickering.
-- Also builds the lit staging room where the crew waits between runs.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local MapGenerator = {}

local CONCRETE = Color3.fromRGB(62, 64, 62)
local CONCRETE_DARK = Color3.fromRGB(44, 46, 45)
local FLOOR = Color3.fromRGB(38, 39, 38)
local RUST = Color3.fromRGB(84, 52, 38)
local STEEL = Color3.fromRGB(52, 56, 60)
local AMBER = Color3.fromRGB(255, 170, 60)
local WARM = Color3.fromRGB(255, 232, 196)
local COLD = Color3.fromRGB(196, 224, 255)

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.Concrete
	p.Color = CONCRETE
	for key, value in pairs(props) do
		p[key] = value
	end
	p.Parent = parent
	return p
end

-- A wall along the X or Z axis, optionally with a doorway cut in the middle.
local function wall(parent, center, axis, length, hasDoor, rng)
	local cfg = Config.Map
	local height = cfg.Height
	local thick = cfg.Wall
	local color = (rng:NextNumber() < 0.3) and CONCRETE_DARK or CONCRETE

	local function segment(offset, segLength, segHeight, y, material, segColor)
		local size, position
		if axis == "x" then
			size = Vector3.new(segLength, segHeight, thick)
			position = center + Vector3.new(offset, y, 0)
		else
			size = Vector3.new(thick, segHeight, segLength)
			position = center + Vector3.new(0, y, offset)
		end
		return part(parent, {
			Name = "Wall",
			Size = size,
			Position = position,
			Color = segColor or color,
			Material = material or Enum.Material.Concrete,
		})
	end

	if not hasDoor then
		segment(0, length, height, height / 2)
		return
	end

	local side = (length - cfg.DoorWidth) / 2
	local sideOffset = cfg.DoorWidth / 2 + side / 2
	segment(-sideOffset, side, height, height / 2)
	segment(sideOffset, side, height, height / 2)
	local lintel = height - cfg.DoorHeight
	segment(0, cfg.DoorWidth, lintel, cfg.DoorHeight + lintel / 2, Enum.Material.CorrodedMetal, RUST)
	-- Steel door frame posts.
	segment(-cfg.DoorWidth / 2 + 0.25, 0.5, cfg.DoorHeight, cfg.DoorHeight / 2, Enum.Material.Metal, STEEL).Size =
		(axis == "x") and Vector3.new(0.5, cfg.DoorHeight, thick + 0.4) or Vector3.new(thick + 0.4, cfg.DoorHeight, 0.5)
	segment(cfg.DoorWidth / 2 - 0.25, 0.5, cfg.DoorHeight, cfg.DoorHeight / 2, Enum.Material.Metal, STEEL).Size =
		(axis == "x") and Vector3.new(0.5, cfg.DoorHeight, thick + 0.4) or Vector3.new(thick + 0.4, cfg.DoorHeight, 0.5)
end

local function ceilingLight(parent, position, rng, forceOn, color)
	local cfg = Config.Map
	local alive = forceOn or rng:NextNumber() < cfg.LightAlive
	local housing = part(parent, {
		Name = "LightHousing",
		Size = Vector3.new(5, 0.5, 1.6),
		Position = position + Vector3.new(0, -0.25, 0),
		Material = Enum.Material.Metal,
		Color = STEEL,
		CastShadow = false,
	})
	local tube = part(parent, {
		Name = "LightTube",
		Size = Vector3.new(4.4, 0.25, 1),
		Position = position + Vector3.new(0, -0.6, 0),
		Material = alive and Enum.Material.Neon or Enum.Material.SmoothPlastic,
		Color = alive and (color or ((rng:NextNumber() < 0.5) and WARM or COLD)) or Color3.fromRGB(40, 40, 40),
		CastShadow = false,
	})
	if alive then
		local lamp = Instance.new("SpotLight")
		lamp.Name = "Lamp"
		lamp.Face = Enum.NormalId.Bottom
		lamp.Angle = 130
		lamp.Range = 42
		lamp.Brightness = 1.6
		lamp.Color = tube.Color
		lamp.Shadows = true
		lamp.Parent = tube
		if not forceOn and rng:NextNumber() < cfg.LightFlicker then
			CollectionService:AddTag(tube, "FlickerLight")
		end
	end
	return housing
end

local function clutter(parent, center, rng)
	local cfg = Config.Map
	local reach = cfg.Cell / 2 - 6
	local kind = rng:NextInteger(1, 4)
	local spot = center + Vector3.new(rng:NextNumber(-reach, reach), 0, rng:NextNumber(-reach, reach))
	if kind == 1 then
		-- A stack of crates.
		for i = 1, rng:NextInteger(2, 4) do
			local s = rng:NextNumber(2.5, 4)
			part(parent, {
				Name = "Crate",
				Size = Vector3.new(s, s, s),
				CFrame = CFrame.new(spot + Vector3.new(rng:NextNumber(-3, 3), s / 2, rng:NextNumber(-3, 3)))
					* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
				Material = Enum.Material.WoodPlanks,
				Color = Color3.fromRGB(70, 56, 40),
			})
		end
	elseif kind == 2 then
		-- A steel shelving unit: something person-shaped to hide behind.
		local turn = CFrame.new(spot) * CFrame.Angles(0, rng:NextInteger(0, 1) * math.pi / 2, 0)
		for level = 0, 3 do
			part(parent, {
				Name = "Shelf",
				Size = Vector3.new(10, 0.3, 3),
				CFrame = turn * CFrame.new(0, 0.6 + level * 2.6, 0),
				Material = Enum.Material.Metal,
				Color = STEEL,
			})
		end
		for _, x in ipairs({ -4.8, 4.8 }) do
			part(parent, {
				Name = "ShelfPost",
				Size = Vector3.new(0.4, 9, 3),
				CFrame = turn * CFrame.new(x, 4.5, 0),
				Material = Enum.Material.Metal,
				Color = STEEL,
			})
		end
	elseif kind == 3 then
		part(parent, {
			Name = "Pillar",
			Size = Vector3.new(3.5, cfg.Height, 3.5),
			Position = spot + Vector3.new(0, cfg.Height / 2, 0),
			Color = CONCRETE_DARK,
		})
	else
		-- An overturned drum.
		part(parent, {
			Name = "Drum",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(4, 2.6, 2.6),
			CFrame = CFrame.new(spot + Vector3.new(0, 1.3, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			Material = Enum.Material.CorrodedMetal,
			Color = RUST,
		})
	end
	if rng:NextNumber() < 0.5 then
		part(parent, {
			Name = "Puddle",
			Size = Vector3.new(rng:NextNumber(6, 13), 0.06, rng:NextNumber(6, 13)),
			Position = center + Vector3.new(rng:NextNumber(-reach, reach), 0.03, rng:NextNumber(-reach, reach)),
			Material = Enum.Material.SmoothPlastic,
			Color = Color3.fromRGB(10, 12, 12),
			Reflectance = 0.4,
			Transparency = 0.25,
			CanCollide = false,
			CastShadow = false,
		})
	end
end

-- Returns { model, startCFrame, padPosition, sampleSpots }.
function MapGenerator.build(origin, seed)
	local cfg = Config.Map
	local rng = Random.new(seed)
	local cols, rows, cell, height = cfg.Cols, cfg.Rows, cfg.Cell, cfg.Height
	local width, depth = cols * cell, rows * cell

	local model = Instance.new("Model")
	model.Name = "Facility"

	local function cellCenter(c, r)
		return origin + Vector3.new((c - 0.5) * cell, 0, (r - 0.5) * cell)
	end

	part(model, {
		Name = "Floor",
		Size = Vector3.new(width + 8, 2, depth + 8),
		Position = origin + Vector3.new(width / 2, -1, depth / 2),
		Color = FLOOR,
	})
	part(model, {
		Name = "Ceiling",
		Size = Vector3.new(width + 8, 2, depth + 8),
		Position = origin + Vector3.new(width / 2, height + 1, depth / 2),
		Color = CONCRETE_DARK,
	})

	-- Outer shell.
	wall(model, origin + Vector3.new(width / 2, 0, 0), "x", width + 4, false, rng)
	wall(model, origin + Vector3.new(width / 2, 0, depth), "x", width + 4, false, rng)
	wall(model, origin + Vector3.new(0, 0, depth / 2), "z", depth + 4, false, rng)
	wall(model, origin + Vector3.new(width, 0, depth / 2), "z", depth + 4, false, rng)

	-- Carve a maze with a depth-first walk, then knock through a few extra doors.
	local visited = {}
	local open = {}
	local function key(c, r)
		return c .. "," .. r
	end
	local function link(c1, r1, c2, r2)
		open[key(c1, r1) .. "|" .. key(c2, r2)] = true
		open[key(c2, r2) .. "|" .. key(c1, r1)] = true
	end
	local startC, startR = 1, math.ceil(rows / 2)
	local stack = { { startC, startR } }
	visited[key(startC, startR)] = true
	while #stack > 0 do
		local c, r = stack[#stack][1], stack[#stack][2]
		local options = {}
		for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
			local nc, nr = c + d[1], r + d[2]
			if nc >= 1 and nc <= cols and nr >= 1 and nr <= rows and not visited[key(nc, nr)] then
				options[#options + 1] = { nc, nr }
			end
		end
		if #options == 0 then
			table.remove(stack)
		else
			local pick = options[rng:NextInteger(1, #options)]
			link(c, r, pick[1], pick[2])
			visited[key(pick[1], pick[2])] = true
			stack[#stack + 1] = pick
		end
	end

	for c = 1, cols do
		for r = 1, rows do
			local center = cellCenter(c, r)
			if c < cols then
				local connected = open[key(c, r) .. "|" .. key(c + 1, r)] or rng:NextNumber() < cfg.ExtraLoops
				wall(model, center + Vector3.new(cell / 2, 0, 0), "z", cell, connected, rng)
			end
			if r < rows then
				local connected = open[key(c, r) .. "|" .. key(c, r + 1)] or rng:NextNumber() < cfg.ExtraLoops
				wall(model, center + Vector3.new(0, 0, cell / 2), "x", cell, connected, rng)
			end
		end
	end

	-- Pipes running the length of the facility, just under the ceiling.
	for r = 1, rows do
		for _, offset in ipairs({ -9, -7.4 }) do
			part(model, {
				Name = "Pipe",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(width, 1.1, 1.1),
				Position = origin + Vector3.new(width / 2, height - 1.2, (r - 0.5) * cell + offset),
				Material = Enum.Material.CorrodedMetal,
				Color = RUST,
				CanCollide = false,
			})
		end
	end

	-- Rooms.
	local sampleSpots = {}
	local startCenter = cellCenter(startC, startR)
	for c = 1, cols do
		for r = 1, rows do
			local center = cellCenter(c, r)
			local isStart = (c == startC and r == startR)
			if isStart then
				ceilingLight(model, center + Vector3.new(0, height, 0), rng, true, AMBER)
			else
				ceilingLight(model, center + Vector3.new(0, height, 0), rng, false, nil)
				for _ = 1, rng:NextInteger(1, 3) do
					clutter(model, center, rng)
				end
				local reach = cell / 2 - 5
				for _ = 1, 2 do
					sampleSpots[#sampleSpots + 1] = center
						+ Vector3.new(rng:NextNumber(-reach, reach), 1.2, rng:NextNumber(-reach, reach))
				end
			end
		end
	end

	-- The lift pad: the only way out, and the only place to recharge.
	local pad = part(model, {
		Name = "LiftPad",
		Size = Vector3.new(16, 0.4, 16),
		Position = startCenter + Vector3.new(0, 0.2, 0),
		Material = Enum.Material.DiamondPlate,
		Color = STEEL,
	})
	for _, offset in ipairs({ Vector3.new(0, 0.25, 8.2), Vector3.new(0, 0.25, -8.2) }) do
		part(model, {
			Name = "PadTrim",
			Size = Vector3.new(16.8, 0.3, 0.4),
			Position = pad.Position + offset,
			Material = Enum.Material.Neon,
			Color = AMBER,
			CanCollide = false,
			CastShadow = false,
		})
	end
	for _, offset in ipairs({ Vector3.new(8.2, 0.25, 0), Vector3.new(-8.2, 0.25, 0) }) do
		part(model, {
			Name = "PadTrim",
			Size = Vector3.new(0.4, 0.3, 16.8),
			Position = pad.Position + offset,
			Material = Enum.Material.Neon,
			Color = AMBER,
			CanCollide = false,
			CastShadow = false,
		})
	end

	return {
		model = model,
		startCFrame = CFrame.new(startCenter + Vector3.new(0, 4, 0)),
		padPosition = pad.Position,
		sampleSpots = sampleSpots,
	}
end

-- The staging room: bright, metal, safe. The contrast makes the dark worse.
function MapGenerator.buildStaging(origin)
	local model = Instance.new("Model")
	model.Name = "Staging"
	local size, height = 44, 14

	part(model, {
		Name = "Floor",
		Size = Vector3.new(size, 2, size),
		Position = origin + Vector3.new(0, -1, 0),
		Material = Enum.Material.DiamondPlate,
		Color = STEEL,
	})
	part(model, {
		Name = "Ceiling",
		Size = Vector3.new(size, 2, size),
		Position = origin + Vector3.new(0, height + 1, 0),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(36, 38, 40),
	})
	local sign = nil
	for i, d in ipairs({ Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) }) do
		local w = part(model, {
			Name = "Wall",
			Size = (d.X ~= 0) and Vector3.new(2, height, size) or Vector3.new(size, height, 2),
			Position = origin + d * (size / 2) + Vector3.new(0, height / 2, 0),
			Material = Enum.Material.CorrodedMetal,
			Color = Color3.fromRGB(58, 60, 62),
		})
		if i == 4 then
			sign = w
		end
	end

	local rng = Random.new(7)
	ceilingLight(model, origin + Vector3.new(-9, height, 0), rng, true, COLD)
	ceilingLight(model, origin + Vector3.new(9, height, 0), rng, true, COLD)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "StagingSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = origin + Vector3.new(0, 0.5, 0)
	spawn.Parent = model
	for _, child in ipairs(spawn:GetChildren()) do
		child:Destroy() -- remove the default spawn decal
	end

	-- Stencilled manifest on the wall.
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 1
	gui.Parent = sign
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.SpecialElite
	text.TextColor3 = Color3.fromRGB(214, 204, 180)
	text.TextTransparency = 0.25
	text.TextSize = 54
	text.TextWrapped = true
	text.Text = "COUNT YOURSELVES BEFORE DESCENT.\nCOUNT AGAIN ON THE WAY UP.\n\nIF THE NUMBERS DIFFER, DO NOT BRING IT WITH YOU."
	text.Parent = gui

	return {
		model = model,
		spawnCFrame = CFrame.new(origin + Vector3.new(0, 4, 0)),
	}
end

return MapGenerator
