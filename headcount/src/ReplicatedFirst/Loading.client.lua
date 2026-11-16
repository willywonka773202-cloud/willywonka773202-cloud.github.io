-- Custom loading screen. Runs before anything else, replaces the default
-- Roblox loading screen, and plays the game's one joke: the count goes wrong.
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local INK = Color3.fromRGB(5, 6, 7)
local BONE = Color3.fromRGB(222, 214, 196)
local DIM = Color3.fromRGB(110, 106, 98)
local BLOOD = Color3.fromRGB(176, 28, 28)

local TIPS = {
	"It walks where you walked.",
	"It makes no footsteps. Listen for who does.",
	"When the hum stops, it is close.",
	"A light pointed at it holds it still.",
	"Alone is when it closes the gap.",
	"Accuse the wrong person and your light dies.",
	"Count before you leave. Count again when you get back.",
}

local gui = Instance.new("ScreenGui")
gui.Name = "Loading"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
gui.Parent = playerGui

local back = Instance.new("Frame")
back.Size = UDim2.fromScale(1, 1)
back.BackgroundColor3 = INK
back.BorderSizePixel = 0
back.Parent = gui

local function label(text, font, size, color, position, anchor)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = font
	l.TextSize = size
	l.TextColor3 = color
	l.Text = text
	l.AnchorPoint = anchor or Vector2.new(0.5, 0.5)
	l.Position = position
	l.Size = UDim2.new(0.9, 0, 0, size + 12)
	l.Parent = back
	return l
end

local title = label("", Enum.Font.SpecialElite, 84, BONE, UDim2.fromScale(0.5, 0.4))
local count = label("", Enum.Font.RobotoMono, 22, DIM, UDim2.fromScale(0.5, 0.52))
local tip = label("", Enum.Font.SpecialElite, 20, DIM, UDim2.fromScale(0.5, 0.86))

local scale = Instance.new("UIScale")
scale.Parent = back
local camera = workspace.CurrentCamera
if camera then
	scale.Scale = math.clamp(camera.ViewportSize.Y / 800, 0.55, 1.4)
end

local barBack = Instance.new("Frame")
barBack.AnchorPoint = Vector2.new(0.5, 0.5)
barBack.Position = UDim2.fromScale(0.5, 0.6)
barBack.Size = UDim2.new(0, 360, 0, 2)
barBack.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
barBack.BorderSizePixel = 0
barBack.Parent = back
local bar = Instance.new("Frame")
bar.Size = UDim2.fromScale(0, 1)
bar.BackgroundColor3 = BONE
bar.BorderSizePixel = 0
bar.Parent = barBack

local running = true

-- Type the title out one letter at a time.
task.spawn(function()
	local word = "HEADCOUNT"
	for i = 1, #word do
		title.Text = string.sub(word, 1, i)
		task.wait(0.09)
	end
end)

-- The count: 1, 2, 3, 4 ... then one too many.
task.spawn(function()
	while running do
		for n = 1, 4 do
			count.TextColor3 = DIM
			count.Text = "CREW ACCOUNTED FOR: " .. n
			task.wait(0.55)
			if not running then
				return
			end
		end
		task.wait(0.7)
		count.TextColor3 = BLOOD
		count.Text = "CREW ACCOUNTED FOR: 5"
		title.TextTransparency = 0.6
		task.wait(0.08)
		title.TextTransparency = 0
		task.wait(1.1)
	end
end)

task.spawn(function()
	local index = math.random(1, #TIPS)
	while running do
		tip.Text = TIPS[index]
		tip.TextTransparency = 1
		TweenService:Create(tip, TweenInfo.new(0.6), { TextTransparency = 0 }):Play()
		task.wait(3.2)
		TweenService:Create(tip, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		task.wait(0.6)
		index = index % #TIPS + 1
	end
end)

local started = os.clock()
if not game:IsLoaded() then
	game.Loaded:Wait()
end
local total = math.max(ContentProvider.RequestQueueSize, 1)
while os.clock() - started < 5 or ContentProvider.RequestQueueSize > 0 do
	local done = 1 - math.clamp(ContentProvider.RequestQueueSize / total, 0, 1)
	local timed = math.clamp((os.clock() - started) / 5, 0, 1)
	bar.Size = UDim2.fromScale(math.min(done, timed), 1)
	if os.clock() - started > 20 then
		break
	end
	task.wait(0.05)
end
bar.Size = UDim2.fromScale(1, 1)
task.wait(0.4)

running = false
local fade = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
for _, inst in ipairs(back:GetDescendants()) do
	if inst:IsA("TextLabel") then
		TweenService:Create(inst, fade, { TextTransparency = 1 }):Play()
	elseif inst:IsA("Frame") then
		TweenService:Create(inst, fade, { BackgroundTransparency = 1 }):Play()
	end
end
TweenService:Create(back, fade, { BackgroundTransparency = 1 }):Play()
task.wait(1.3)
gui:Destroy()
