-- One visual language for every screen: near-black panels, bone-white text,
-- a typewriter face for words and a monospace face for numbers, and exactly
-- one alarm colour. Change the look of the whole UI here.
local Theme = {}

Theme.Ink = Color3.fromRGB(6, 7, 8)
Theme.Panel = Color3.fromRGB(13, 15, 16)
Theme.Line = Color3.fromRGB(58, 56, 52)
Theme.Bone = Color3.fromRGB(222, 214, 196)
Theme.Dim = Color3.fromRGB(122, 118, 108)
Theme.Blood = Color3.fromRGB(190, 34, 34)
Theme.Amber = Color3.fromRGB(232, 168, 56)
Theme.Sick = Color3.fromRGB(140, 255, 170)

Theme.Words = Enum.Font.SpecialElite
Theme.Numbers = Enum.Font.RobotoMono

function Theme.new(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

function Theme.label(parent, props)
	local base = {
		BackgroundTransparency = 1,
		Font = Theme.Words,
		TextSize = 18,
		TextColor3 = Theme.Bone,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Size = UDim2.new(1, 0, 0, 22),
	}
	for key, value in pairs(props) do
		base[key] = value
	end
	return Theme.new("TextLabel", base, parent)
end

-- A flat dark panel with a hairline border.
function Theme.panel(parent, props)
	local base = {
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
	}
	for key, value in pairs(props) do
		base[key] = value
	end
	local frame = Theme.new("Frame", base, parent)
	Theme.new("UIStroke", { Color = Theme.Line, Thickness = 1, Transparency = 0.3 }, frame)
	return frame
end

-- A thin meter: returns the fill frame; set fill.Size = UDim2.fromScale(x, 1).
function Theme.meter(parent, props, color)
	local base = {
		BackgroundColor3 = Color3.fromRGB(30, 30, 30),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 4),
	}
	for key, value in pairs(props) do
		base[key] = value
	end
	local back = Theme.new("Frame", base, parent)
	local fill = Theme.new("Frame", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, back)
	return fill
end

function Theme.button(parent, props, onClick)
	local base = {
		BackgroundColor3 = Theme.Ink,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Theme.Numbers,
		TextSize = 15,
		TextColor3 = Theme.Bone,
		Text = "",
	}
	for key, value in pairs(props) do
		base[key] = value
	end
	local button = Theme.new("TextButton", base, parent)
	local stroke = Theme.new("UIStroke", {
		Color = Theme.Line,
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, button)
	button.MouseEnter:Connect(function()
		stroke.Color = Theme.Bone
	end)
	button.MouseLeave:Connect(function()
		stroke.Color = Theme.Line
	end)
	button.Activated:Connect(onClick)
	return button
end

return Theme
