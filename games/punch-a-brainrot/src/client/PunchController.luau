--!strict
-- Input only. It never decides what was hit -- it just tells the server the
-- player swung, and mirrors the cooldown locally so we do not spam the remote.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Ui = require(script.Parent.Ui)

local PunchController = {}

local player = Players.LocalPlayer
local lastPunch = 0

local function punch()
	local now = os.clock()
	if now - lastPunch < Config.PunchCooldown then
		return
	end
	lastPunch = now
	Remotes.get("Punch"):FireServer()
end

function PunchController.start()
	-- Mouse / keyboard / gamepad.
	ContextActionService:BindAction("PABPunch", function(_, inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.Begin then
			punch()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.UserInputType.MouseButton1, Enum.KeyCode.E, Enum.KeyCode.ButtonR2)

	-- Touch devices get a real button rather than a hidden tap target.
	if UserInputService.TouchEnabled then
		local screen = Ui.new("ScreenGui", {
			Name = "PunchButton",
			ResetOnSpawn = false,
			Parent = player:WaitForChild("PlayerGui"),
		}) :: ScreenGui

		local button = Ui.button({
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -24, 1, -120),
			Size = UDim2.fromOffset(110, 110),
			Text = "PUNCH",
			TextSize = 20,
			BackgroundColor3 = Color3.fromRGB(180, 66, 66),
			Parent = screen,
		})
		local round = button:FindFirstChildOfClass("UICorner")
		if round then
			round.CornerRadius = UDim.new(1, 0)
		end
		button.Activated:Connect(punch)
	end
end

return PunchController
