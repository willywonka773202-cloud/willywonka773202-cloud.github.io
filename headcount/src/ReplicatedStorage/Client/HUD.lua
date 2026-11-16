-- All on-screen UI: status readouts, toasts, the headcount result, the
-- upgrade shop, the results card, the death card, and the vignette.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(script.Parent.Theme)

local HUD = {}

local player = Players.LocalPlayer
local state, remotes
local gui, root, scale
local phaseLabel, timerLabel, crewLabel, sampleLabel, creditLabel, hintLabel
local batteryFill, staminaFill, countFill
local toastHolder, bigLabel, bigSub
local shop, shopRows, results, death
local vignette = {}
local onSound = function() end

local function formatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function buildVignette(parent)
	-- Four soft black gradients, one per screen edge. They grow with dread.
	local edges = {
		{ anchor = Vector2.new(0, 0), pos = UDim2.fromScale(0, 0), rotation = 0, horizontal = true },
		{ anchor = Vector2.new(1, 0), pos = UDim2.fromScale(1, 0), rotation = 180, horizontal = true },
		{ anchor = Vector2.new(0, 0), pos = UDim2.fromScale(0, 0), rotation = 90, horizontal = false },
		{ anchor = Vector2.new(0, 1), pos = UDim2.fromScale(0, 1), rotation = 270, horizontal = false },
	}
	for _, edge in ipairs(edges) do
		local frame = Theme.new("Frame", {
			AnchorPoint = edge.anchor,
			Position = edge.pos,
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			ZIndex = 0,
		}, parent)
		Theme.new("UIGradient", {
			Rotation = edge.rotation,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.05),
				NumberSequenceKeypoint.new(0.5, 0.6),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, frame)
		vignette[#vignette + 1] = { frame = frame, horizontal = edge.horizontal }
	end
end

local function setVignette(amount)
	local reach = 0.16 + amount * 0.3
	for _, edge in ipairs(vignette) do
		if edge.horizontal then
			edge.frame.Size = UDim2.fromScale(reach, 1)
		else
			edge.frame.Size = UDim2.fromScale(1, reach)
		end
	end
end

local function buildShop()
	shop = Theme.panel(root, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 300),
		BackgroundTransparency = 0.05,
		Visible = false,
		ZIndex = 20,
	})
	Theme.new("UIPadding", {
		PaddingTop = UDim.new(0, 20),
		PaddingLeft = UDim.new(0, 24),
		PaddingRight = UDim.new(0, 24),
	}, shop)
	Theme.label(shop, { Text = "REQUISITIONS", TextSize = 30, Size = UDim2.new(1, 0, 0, 34), ZIndex = 21 })
	Theme.label(shop, {
		Text = "Spend what you brought back. It comes down with you.",
		TextColor3 = Theme.Dim,
		TextSize = 15,
		Position = UDim2.fromOffset(0, 38),
		ZIndex = 21,
	})
	shopRows = {}
	local order = { "Battery", "Stamina", "Scanner" }
	for index, name in ipairs(order) do
		local def = Config.Upgrades[name]
		local y = 76 + (index - 1) * 64
		local title = Theme.label(shop, {
			Font = Theme.Numbers,
			TextSize = 17,
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(0.6, 0, 0, 22),
			ZIndex = 21,
		})
		Theme.label(shop, {
			Text = def.Blurb,
			TextColor3 = Theme.Dim,
			TextSize = 14,
			Position = UDim2.fromOffset(0, y + 22),
			Size = UDim2.new(0.6, 0, 0, 20),
			ZIndex = 21,
		})
		local button = Theme.button(shop, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, y),
			Size = UDim2.fromOffset(140, 40),
			ZIndex = 21,
			Modal = true, -- frees the mouse while the shop is open (camera is locked first-person)
		}, function()
			onSound("Click")
			remotes.BuyUpgrade:FireServer(name)
		end)
		shopRows[name] = { title = title, button = button, def = def }
	end
end

local function buildCards()
	results = Theme.panel(root, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(520, 230),
		BackgroundTransparency = 0.05,
		Visible = false,
		ZIndex = 30,
	})
	Theme.label(results, {
		Name = "Title",
		TextSize = 44,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 50),
		ZIndex = 31,
	})
	Theme.label(results, {
		Name = "Body",
		Font = Theme.Numbers,
		TextSize = 17,
		TextColor3 = Theme.Dim,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(0, 96),
		Size = UDim2.new(1, 0, 0, 110),
		ZIndex = 31,
	})

	death = Theme.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 50,
	}, gui)
	Theme.label(death, {
		Name = "Line",
		TextSize = 54,
		TextColor3 = Theme.Blood,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.new(0.9, 0, 0, 70),
		ZIndex = 51,
	})
	Theme.label(death, {
		Name = "Sub",
		TextSize = 20,
		TextColor3 = Theme.Dim,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.56),
		Size = UDim2.new(0.9, 0, 0, 30),
		ZIndex = 51,
	})
end

function HUD.init(playerGui, stateFolder, remoteFolder, soundCallback)
	state = stateFolder
	remotes = remoteFolder
	onSound = soundCallback or onSound

	gui = Theme.new("ScreenGui", {
		Name = "HeadcountHUD",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 10,
	}, playerGui)

	buildVignette(gui)
	setVignette(0)

	root = Theme.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, gui)
	scale = Theme.new("UIScale", {}, root)

	-- Top left: where we are in the night.
	local status = Theme.panel(root, { Position = UDim2.fromOffset(24, 24), Size = UDim2.fromOffset(250, 76) })
	Theme.new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingTop = UDim.new(0, 10) }, status)
	phaseLabel = Theme.label(status, { TextSize = 22, Size = UDim2.new(1, 0, 0, 26) })
	timerLabel = Theme.label(status, {
		Font = Theme.Numbers,
		TextSize = 22,
		TextColor3 = Theme.Dim,
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 0, 26),
	})

	-- Top right: the number that matters.
	local crew = Theme.panel(root, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 24),
		Size = UDim2.fromOffset(230, 76),
	})
	Theme.new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingTop = UDim.new(0, 10) }, crew)
	Theme.label(crew, { Text = "CREW ALIVE", TextColor3 = Theme.Dim, TextSize = 15 })
	crewLabel = Theme.label(crew, {
		Font = Theme.Numbers,
		TextSize = 30,
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, 0, 0, 36),
	})

	-- Bottom left: light, lungs, counter.
	local vitals = Theme.panel(root, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 24, 1, -24),
		Size = UDim2.fromOffset(250, 112),
	})
	Theme.new("UIPadding", {
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
		PaddingTop = UDim.new(0, 10),
	}, vitals)
	local function row(text, y, color)
		Theme.label(vitals, { Text = text, TextSize = 14, TextColor3 = Theme.Dim, Position = UDim2.fromOffset(0, y) })
		return Theme.meter(vitals, { Position = UDim2.fromOffset(0, y + 22) }, color)
	end
	batteryFill = row("LIGHT  [F]", 0, Theme.Bone)
	staminaFill = row("LUNGS  [SHIFT]", 32, Theme.Bone)
	countFill = row("HEADCOUNT  [Q]", 64, Theme.Amber)

	-- Bottom right: the job.
	local job = Theme.panel(root, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -24),
		Size = UDim2.fromOffset(230, 92),
	})
	Theme.new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingTop = UDim.new(0, 10) }, job)
	sampleLabel = Theme.label(job, { Font = Theme.Numbers, TextSize = 17 })
	creditLabel = Theme.label(job, {
		Font = Theme.Numbers,
		TextSize = 17,
		TextColor3 = Theme.Dim,
		Position = UDim2.fromOffset(0, 26),
	})
	hintLabel = Theme.label(job, { TextSize = 14, TextColor3 = Theme.Dim, Position = UDim2.fromOffset(0, 52) })

	-- Toasts, top centre.
	toastHolder = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 30),
		Size = UDim2.fromOffset(620, 200),
		BackgroundTransparency = 1,
	}, root)
	Theme.new("UIListLayout", {
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, toastHolder)

	-- The headcount readout, dead centre.
	bigLabel = Theme.label(root, {
		Font = Theme.Numbers,
		TextSize = 64,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.new(1, 0, 0, 80),
		TextTransparency = 1,
	})
	bigSub = Theme.label(root, {
		TextSize = 20,
		TextColor3 = Theme.Dim,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.44),
		Size = UDim2.new(1, 0, 0, 30),
		TextTransparency = 1,
	})

	buildShop()
	buildCards()
end

local toastOrder = 0
function HUD.toast(text, kind)
	toastOrder = toastOrder + 1
	local color = Theme.Bone
	if kind == "bad" then
		color = Theme.Blood
	elseif kind == "good" then
		color = Theme.Sick
	end
	local label = Theme.label(toastHolder, {
		Text = text,
		TextSize = 20,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 1,
		TextStrokeTransparency = 0.6,
		LayoutOrder = toastOrder,
		Size = UDim2.new(1, 0, 0, 26),
	})
	TweenService:Create(label, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
	task.delay(4.5, function()
		local out = TweenService:Create(label, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 })
		out:Play()
		out.Completed:Wait()
		label:Destroy()
	end)
end

function HUD.showHeadcount(bodies, caller)
	local crewAlive = state:GetAttribute("CrewAlive") or 0
	bigLabel.Text = "BODIES NEARBY: " .. bodies
	bigLabel.TextColor3 = (bodies > crewAlive) and Theme.Blood or Theme.Bone
	bigSub.Text = caller .. " called a headcount.  Crew alive: " .. crewAlive
	bigLabel.TextTransparency = 0
	bigSub.TextTransparency = 0
	local fade = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 2.6)
	TweenService:Create(bigLabel, fade, { TextTransparency = 1 }):Play()
	TweenService:Create(bigSub, fade, { TextTransparency = 1 }):Play()
end

function HUD.showResults(data)
	local title = results:FindFirstChild("Title")
	local body = results:FindFirstChild("Body")
	if data.success and data.escaped then
		title.Text = "ALL COUNTED"
		title.TextColor3 = Theme.Bone
	elseif data.success then
		title.Text = "THEY LEFT WITHOUT YOU"
		title.TextColor3 = Theme.Amber
	else
		title.Text = "NOBODY CAME BACK UP"
		title.TextColor3 = Theme.Blood
	end
	body.Text = "NIGHT " .. data.night
		.. "\nSAMPLES " .. data.deposited .. " / " .. data.quota
		.. "\nCREDITS +" .. data.earned
	results.Visible = true
	task.delay(Config.ResultsTime, function()
		results.Visible = false
	end)
end

-- The last thing a victim sees.
function HUD.jumpscare(name)
	local line = death:FindFirstChild("Line")
	local sub = death:FindFirstChild("Sub")
	line.Text = "YOU WERE COUNTED TWICE"
	sub.Text = "The crew will not notice. " .. string.upper(name) .. " is still walking with them."
	line.TextTransparency = 0
	sub.TextTransparency = 1
	death.BackgroundTransparency = 0
	death.Visible = true
	-- Three hard black flashes, then hold.
	task.spawn(function()
		for _ = 1, 3 do
			death.BackgroundTransparency = 0
			task.wait(0.07)
			death.BackgroundTransparency = 0.7
			task.wait(0.05)
		end
		death.BackgroundTransparency = 0
		TweenService:Create(sub, TweenInfo.new(1.5), { TextTransparency = 0 }):Play()
		task.wait(4)
		local fade = TweenInfo.new(2)
		TweenService:Create(death, fade, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(line, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(sub, fade, { TextTransparency = 1 }):Play()
		task.wait(2.1)
		death.Visible = false
	end)
end

function HUD.toggleShop()
	if state:GetAttribute("Phase") ~= "Intermission" then
		shop.Visible = false
		return
	end
	shop.Visible = not shop.Visible
end

-- Call every frame.
function HUD.update(dread, stamina)
	local camera = workspace.CurrentCamera
	if camera then
		scale.Scale = math.clamp(camera.ViewportSize.Y / 900, 0.55, 1.3)
	end
	setVignette(dread)

	local phase = state:GetAttribute("Phase")
	local night = state:GetAttribute("Night") or 1
	local timeLeft = state:GetAttribute("TimeLeft") or 0
	local inRun = player:GetAttribute("InRun")
	local alive = player:GetAttribute("Alive")

	if phase == "Intermission" then
		phaseLabel.Text = "STAGING"
		timerLabel.Text = (timeLeft > 0) and ("DESCENT IN " .. formatTime(timeLeft)) or "WAITING FOR CREW"
	elseif phase == "Descent" then
		phaseLabel.Text = "GOING DOWN"
		timerLabel.Text = formatTime(timeLeft)
	elseif phase == "Expedition" then
		phaseLabel.Text = "NIGHT " .. string.format("%02d", night)
		timerLabel.Text = "LIFT LEAVES " .. formatTime(timeLeft)
		timerLabel.TextColor3 = (timeLeft <= 60) and Theme.Blood or Theme.Dim
	else
		phaseLabel.Text = "COUNTING"
		timerLabel.Text = ""
	end
	if phase ~= "Expedition" then
		timerLabel.TextColor3 = Theme.Dim
		shop.Visible = shop.Visible and phase == "Intermission"
	end

	crewLabel.Text = (state:GetAttribute("CrewAlive") or 0) .. " / " .. (state:GetAttribute("CrewTotal") or 0)

	batteryFill.Size = UDim2.fromScale(math.clamp((player:GetAttribute("Battery") or 0) / 100, 0, 1), 1)
	batteryFill.BackgroundColor3 = ((player:GetAttribute("Battery") or 0) < 20) and Theme.Blood or Theme.Bone
	staminaFill.Size = UDim2.fromScale(math.clamp(stamina / 100, 0, 1), 1)

	local now = workspace:GetServerTimeNow()
	local readyAt = player:GetAttribute("HeadcountReadyAt") or 0
	local cooldown = math.max(4, Config.Headcount.Cooldown - (player:GetAttribute("UpScanner") or 0) * Config.Headcount.CooldownPerUpgrade)
	countFill.Size = UDim2.fromScale(math.clamp(1 - (readyAt - now) / cooldown, 0, 1), 1)

	sampleLabel.Text = "SAMPLES  " .. (state:GetAttribute("Deposited") or 0) .. " / " .. (state:GetAttribute("Quota") or 0)
	creditLabel.Text = "CREDITS  " .. (player:GetAttribute("Credits") or 0)
	if phase == "Expedition" and inRun and alive then
		hintLabel.Text = "Carrying " .. (player:GetAttribute("Samples") or 0) .. " of " .. Config.Samples.CarryCap
	elseif phase == "Expedition" and inRun then
		hintLabel.Text = "You are no longer counted."
	elseif phase == "Expedition" then
		hintLabel.Text = "The crew is below. Wait."
	elseif phase == "Intermission" then
		hintLabel.Text = "[B] Requisitions"
	else
		hintLabel.Text = ""
	end

	if shop.Visible then
		local credits = player:GetAttribute("Credits") or 0
		for name, rowData in pairs(shopRows) do
			local level = player:GetAttribute("Up" .. name) or 0
			rowData.title.Text = rowData.def.Label .. "  " .. string.rep("|", level) .. string.rep(".", rowData.def.Max - level)
			if level >= rowData.def.Max then
				rowData.button.Text = "MAXED"
				rowData.button.TextColor3 = Theme.Dim
			else
				local cost = rowData.def.Cost * (level + 1)
				rowData.button.Text = cost .. " CR"
				rowData.button.TextColor3 = (credits >= cost) and Theme.Bone or Theme.Dim
			end
		end
	end
end

return HUD
