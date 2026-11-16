-- HEADCOUNT client. Wires input to the server and drives the HUD, audio and
-- screen effects every frame from one replicated number: Dread.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local ClientModules = ReplicatedStorage:WaitForChild("Client")
local Theme = require(ClientModules:WaitForChild("Theme"))
local HUD = require(ClientModules:WaitForChild("HUD"))
local AudioDirector = require(ClientModules:WaitForChild("AudioDirector"))
local Effects = require(ClientModules:WaitForChild("Effects"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local state = ReplicatedStorage:WaitForChild("GameState")

-- Hide the default Roblox HUD pieces that break the mood. Chat stays.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, false)
end)

AudioDirector.init()
Effects.init()
HUD.init(playerGui, state, remotes, AudioDirector.play)

---------------------------------------------------------------------------
-- Input (keyboard, gamepad, and on-screen buttons on touch devices)
---------------------------------------------------------------------------
local sprinting = false
local exhausted = false -- ran dry; must recover before sprinting again
local stamina = 100

local function began(inputState)
	return inputState == Enum.UserInputState.Begin
end

ContextActionService:BindAction("Flashlight", function(_, inputState)
	if began(inputState) then
		AudioDirector.play("Switch")
		remotes.ToggleFlashlight:FireServer()
	end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
ContextActionService:SetTitle("Flashlight", "Light")
ContextActionService:SetPosition("Flashlight", UDim2.new(1, -150, 1, -210))

ContextActionService:BindAction("Headcount", function(_, inputState)
	if began(inputState) then
		local ready = workspace:GetServerTimeNow() >= (player:GetAttribute("HeadcountReadyAt") or 0)
		if ready and player:GetAttribute("Alive") then
			remotes.Headcount:FireServer()
		else
			AudioDirector.play("Click")
		end
	end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonX)
ContextActionService:SetTitle("Headcount", "Count")
ContextActionService:SetPosition("Headcount", UDim2.new(1, -220, 1, -150))

ContextActionService:BindAction("Sprint", function(_, inputState)
	sprinting = began(inputState)
	return Enum.ContextActionResult.Pass
end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
ContextActionService:SetTitle("Sprint", "Run")
ContextActionService:SetPosition("Sprint", UDim2.new(1, -80, 1, -250))

ContextActionService:BindAction("Shop", function(_, inputState)
	if began(inputState) then
		AudioDirector.play("Click")
		HUD.toggleShop()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.B, Enum.KeyCode.ButtonSelect)

---------------------------------------------------------------------------
-- Server messages
---------------------------------------------------------------------------
remotes.Notify.OnClientEvent:Connect(function(data)
	HUD.toast(data.text, data.kind)
	if data.sound then
		AudioDirector.play(data.sound)
	end
	if data.kind == "bad" then
		Effects.punch(0.25)
	end
end)

remotes.HeadcountResult.OnClientEvent:Connect(function(data)
	AudioDirector.play("Ping")
	HUD.showHeadcount(data.bodies, data.caller)
	if data.bodies > (state:GetAttribute("CrewAlive") or 0) then
		task.delay(0.5, function()
			AudioDirector.play("Bad")
			Effects.punch(0.4)
		end)
	end
end)

remotes.Jumpscare.OnClientEvent:Connect(function(data)
	AudioDirector.play("Sting")
	Effects.punch(1)
	Effects.deathBlur()
	HUD.jumpscare(data.name)
end)

remotes.Results.OnClientEvent:Connect(function(data)
	HUD.showResults(data)
end)

---------------------------------------------------------------------------
-- Custom prompts (ACCUSE / COLLECT), drawn in the game's own style
---------------------------------------------------------------------------
ProximityPromptService.PromptShown:Connect(function(prompt)
	if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
		return
	end
	local character = player.Character
	if character and prompt:IsDescendantOf(character) then
		return -- never offer to accuse yourself
	end

	local board = Theme.new("BillboardGui", {
		Name = "Prompt",
		Adornee = prompt.Parent,
		Size = UDim2.fromOffset(190, 54),
		StudsOffset = Vector3.new(0, 1.5, 0),
		AlwaysOnTop = true,
		ResetOnSpawn = false,
	}, playerGui)
	local button = Theme.new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Ink,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
	}, board)
	Theme.new("UIStroke", {
		Color = (prompt.Name == "Accuse") and Theme.Blood or Theme.Line,
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, button)
	Theme.label(button, {
		Text = "[E]  " .. prompt.ActionText,
		Font = Theme.Numbers,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 6),
	})
	Theme.label(button, {
		Text = prompt.ObjectText,
		TextSize = 13,
		TextColor3 = Theme.Dim,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 27),
	})
	local fill = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(0, 0, 0, 3),
		BackgroundColor3 = (prompt.Name == "Accuse") and Theme.Blood or Theme.Sick,
		BorderSizePixel = 0,
	}, button)

	local tween = nil
	local connections = {}
	connections[#connections + 1] = prompt.PromptButtonHoldBegan:Connect(function()
		tween = TweenService:Create(fill, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), {
			Size = UDim2.new(1, 0, 0, 3),
		})
		tween:Play()
	end)
	connections[#connections + 1] = prompt.PromptButtonHoldEnded:Connect(function()
		if tween then
			tween:Cancel()
		end
		fill.Size = UDim2.new(0, 0, 0, 3)
	end)
	-- Touch and mouse: hold the card itself.
	connections[#connections + 1] = button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			prompt:InputHoldBegin()
		end
	end)
	connections[#connections + 1] = button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			prompt:InputHoldEnd()
		end
	end)

	prompt.PromptHidden:Wait()
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	board:Destroy()
end)

---------------------------------------------------------------------------
-- Every frame
---------------------------------------------------------------------------
RunService.RenderStepped:Connect(function(dt)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local inFacility = player:GetAttribute("InRun") == true and player:GetAttribute("Alive") == true
	local dread = inFacility and (player:GetAttribute("Dread") or 0) or 0
	local flashlightOn = character ~= nil and character:GetAttribute("Flashlight") == true

	-- Other players see the light on our head. We use the hand-held beam instead.
	if character then
		local head = character:FindFirstChild("Head")
		local crewLight = head and head:FindFirstChild("CrewLight")
		if crewLight and crewLight.Enabled then
			crewLight.Enabled = false
		end
	end

	-- Sprint and stamina.
	if humanoid and humanoid.Health > 0 then
		local moving = humanoid.MoveDirection.Magnitude > 0.1
		if stamina > 25 then
			exhausted = false
		end
		if sprinting and moving and not exhausted then
			stamina = math.max(0, stamina - Config.StaminaDrain * dt)
			humanoid.WalkSpeed = Config.SprintSpeed
			if stamina <= 0 then
				exhausted = true
			end
		else
			local regen = Config.StaminaRegen + (player:GetAttribute("UpStamina") or 0) * Config.StaminaRegenPerUpgrade
			stamina = math.min(100, stamina + regen * dt)
			humanoid.WalkSpeed = Config.WalkSpeed
		end
	end

	Effects.update(dt, dread, humanoid, flashlightOn, player:GetAttribute("Battery") or 0)
	AudioDirector.update(dt, dread, inFacility)
	HUD.update(dread, stamina)
end)
