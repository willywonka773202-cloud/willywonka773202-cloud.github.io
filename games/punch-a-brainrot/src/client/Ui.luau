--!strict
-- Tiny declarative helper so the HUD code reads as structure rather than as
-- two hundred lines of property assignment.

local Ui = {}

Ui.Palette = {
	panel = Color3.fromRGB(18, 19, 26),
	panelSoft = Color3.fromRGB(28, 30, 40),
	stroke = Color3.fromRGB(58, 62, 80),
	text = Color3.fromRGB(236, 238, 244),
	muted = Color3.fromRGB(150, 156, 172),
	good = Color3.fromRGB(96, 220, 140),
	warn = Color3.fromRGB(255, 196, 88),
	bad = Color3.fromRGB(255, 104, 116),
	accent = Color3.fromRGB(126, 148, 255),
	cash = Color3.fromRGB(120, 230, 160),
}

function Ui.new<T>(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	if props then
		for key, value in props do
			if key ~= "Parent" then
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if props and props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

function Ui.corner(radius: number): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	return corner
end

function Ui.stroke(color: Color3?, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Ui.Palette.stroke
	stroke.Thickness = thickness or 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return stroke
end

function Ui.padding(pixels: number): UIPadding
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, pixels)
	padding.PaddingBottom = UDim.new(0, pixels)
	padding.PaddingLeft = UDim.new(0, pixels)
	padding.PaddingRight = UDim.new(0, pixels)
	return padding
end

function Ui.listLayout(direction: Enum.FillDirection, gap: number, align: Enum.HorizontalAlignment?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = direction
	layout.Padding = UDim.new(0, gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = align or Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	return layout
end

function Ui.panel(props: { [string]: any }): Frame
	local frame = Ui.new("Frame", props) :: Frame
	frame.BackgroundColor3 = (props.BackgroundColor3 :: Color3?) or Ui.Palette.panel
	frame.BackgroundTransparency = (props.BackgroundTransparency :: number?) or 0.08
	frame.BorderSizePixel = 0
	Ui.corner(10).Parent = frame
	Ui.stroke().Parent = frame
	return frame
end

function Ui.label(props: { [string]: any }): TextLabel
	local label = Ui.new("TextLabel", props) :: TextLabel
	label.BackgroundTransparency = 1
	label.Font = (props.Font :: Enum.Font?) or Enum.Font.GothamMedium
	label.TextColor3 = (props.TextColor3 :: Color3?) or Ui.Palette.text
	label.TextXAlignment = (props.TextXAlignment :: Enum.TextXAlignment?) or Enum.TextXAlignment.Left
	return label
end

function Ui.button(props: { [string]: any }): TextButton
	local button = Ui.new("TextButton", props) :: TextButton
	button.BackgroundColor3 = (props.BackgroundColor3 :: Color3?) or Ui.Palette.panelSoft
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamBold
	button.TextColor3 = (props.TextColor3 :: Color3?) or Ui.Palette.text
	Ui.corner(8).Parent = button
	Ui.stroke().Parent = button
	return button
end

-- A background track plus a fill you can drive with a 0..1 value.
function Ui.bar(color: Color3): (Frame, (alpha: number) -> ())
	local track = Ui.new("Frame", {
		BackgroundColor3 = Ui.Palette.panelSoft,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 8),
	}) :: Frame
	Ui.corner(4).Parent = track

	local fill = Ui.new("Frame", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = track,
	}) :: Frame
	Ui.corner(4).Parent = fill

	return track, function(alpha: number)
		fill.Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1)
	end
end

return Ui
