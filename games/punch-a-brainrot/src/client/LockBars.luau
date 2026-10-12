--!strict
-- Renders the HP bar above every brainrot lock in the world.
--
-- The server writes LockHP/LockMax as Attributes and those replicate on their
-- own, so this whole file is presentation with no networking of its own.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Ui = require(script.Parent.Ui)

local TAG = "PABLock"

local LockBars = {}

local connections: { [BasePart]: { RBXScriptConnection } } = {}

local function attach(lock: BasePart)
	if connections[lock] then
		return
	end

	local billboard = Ui.new("BillboardGui", {
		Name = "LockBar",
		Size = UDim2.fromScale(6, 1.4),
		StudsOffsetWorldSpace = Vector3.new(0, 2, 0),
		AlwaysOnTop = false,
		MaxDistance = 120,
		LightInfluence = 0,
		Parent = lock,
	}) :: BillboardGui

	local label = Ui.label({
		Size = UDim2.new(1, 0, 0.55, 0),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.4,
		Font = Enum.Font.GothamBold,
		Text = "",
		Parent = billboard,
	})

	local track, setFill = Ui.bar(Ui.Palette.bad)
	track.Position = UDim2.fromScale(0, 0.62)
	track.Size = UDim2.new(1, 0, 0.28, 0)
	track.Parent = billboard

	local function refresh()
		local hp = lock:GetAttribute("LockHP")
		local max = lock:GetAttribute("LockMax")
		if type(hp) ~= "number" or type(max) ~= "number" or max <= 0 then
			billboard.Enabled = false
			return
		end

		local alpha = hp / max
		setFill(alpha)
		-- A full lock is the resting state; only show the bar once it is damaged.
		billboard.Enabled = alpha < 0.999
		label.Text = `LOCK {Format.short(hp)}`
		label.TextColor3 = if alpha > 0.5 then Ui.Palette.warn else Ui.Palette.bad
	end

	connections[lock] = {
		lock:GetAttributeChangedSignal("LockHP"):Connect(refresh),
		lock:GetAttributeChangedSignal("LockMax"):Connect(refresh),
	}
	refresh()
end

local function detach(lock: BasePart)
	local bound = connections[lock]
	if not bound then
		return
	end
	for _, connection in bound do
		connection:Disconnect()
	end
	connections[lock] = nil
end

function LockBars.start()
	for _, instance in CollectionService:GetTagged(TAG) do
		if instance:IsA("BasePart") then
			attach(instance)
		end
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(instance)
		if instance:IsA("BasePart") then
			attach(instance)
		end
	end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(instance)
		if instance:IsA("BasePart") then
			detach(instance)
		end
	end)
end

return LockBars
