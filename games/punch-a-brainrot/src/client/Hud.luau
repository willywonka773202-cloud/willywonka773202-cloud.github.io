--!strict
-- The whole player-facing UI. It is driven entirely by the server snapshot,
-- so there is no local copy of the economy to drift out of sync.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Brainrots = require(Shared.Brainrots)
local Rarities = require(Shared.Rarities)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local Ui = require(script.Parent.Ui)

local Hud = {}

local player = Players.LocalPlayer

type ShopSlotUi = {
	button: TextButton,
	name: TextLabel,
	price: TextLabel,
}

function Hud.mount()
	local screen = Ui.new("ScreenGui", {
		Name = "PunchABrainrotHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	}) :: ScreenGui

	-- ── Stats, top left ───────────────────────────────────────────────────
	local stats = Ui.panel({
		Name = "Stats",
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.fromOffset(268, 132),
		Parent = screen,
	})
	Ui.padding(12).Parent = stats
	Ui.listLayout(Enum.FillDirection.Vertical, 4).Parent = stats

	local cashLabel = Ui.label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 30),
		Font = Enum.Font.GothamBold,
		TextSize = 26,
		TextColor3 = Ui.Palette.cash,
		Text = "$0",
		Parent = stats,
	})
	local incomeLabel = Ui.label({
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 14,
		TextColor3 = Ui.Palette.muted,
		Text = "$0/s",
		Parent = stats,
	})
	local rankLabel = Ui.label({
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 20),
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		Text = "Noodle Arms",
		Parent = stats,
	})
	local rankTrack, setRank = Ui.bar(Ui.Palette.accent)
	rankTrack.LayoutOrder = 4
	rankTrack.Parent = stats

	local detailLabel = Ui.label({
		LayoutOrder = 5,
		Size = UDim2.new(1, 0, 0, 32),
		TextSize = 12,
		TextWrapped = true,
		TextColor3 = Ui.Palette.muted,
		Text = "",
		Parent = stats,
	})

	-- ── Shop, top right ───────────────────────────────────────────────────
	local shop = Ui.panel({
		Name = "Shop",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(250, 220),
		Parent = screen,
	})
	Ui.padding(12).Parent = shop
	Ui.listLayout(Enum.FillDirection.Vertical, 6).Parent = shop

	local shopTitle = Ui.label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 20),
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		Text = "SHOP",
		Parent = shop,
	})

	local shopSlots: { ShopSlotUi } = {}
	for index = 1, 4 do
		local button = Ui.button({
			LayoutOrder = index + 1,
			Size = UDim2.new(1, 0, 0, 38),
			Text = "",
			Parent = shop,
		})
		local name = Ui.label({
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(1, -20, 0, 17),
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			Text = "--",
			Parent = button,
		})
		local price = Ui.label({
			Position = UDim2.fromOffset(10, 19),
			Size = UDim2.new(1, -20, 0, 15),
			TextSize = 12,
			TextColor3 = Ui.Palette.muted,
			Text = "",
			Parent = button,
		})
		button.Activated:Connect(function()
			Remotes.get("BuyBrainrot"):FireServer(index)
		end)
		table.insert(shopSlots, { button = button, name = name, price = price })
	end

	-- ── Base actions, bottom left ─────────────────────────────────────────
	local actions = Ui.panel({
		Name = "Actions",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(268, 150),
		Parent = screen,
	})
	Ui.padding(12).Parent = actions
	Ui.listLayout(Enum.FillDirection.Vertical, 6).Parent = actions

	local trainButton = Ui.button({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 34),
		TextSize = 13,
		Text = "Upgrade Training",
		Parent = actions,
	})
	local padButton = Ui.button({
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 34),
		TextSize = 13,
		Text = "Buy Pad",
		Parent = actions,
	})
	local rebirthButton = Ui.button({
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 34),
		TextSize = 13,
		BackgroundColor3 = Color3.fromRGB(44, 34, 62),
		Text = "Rebirth",
		Parent = actions,
	})

	trainButton.Activated:Connect(function()
		Remotes.get("BuyTraining"):FireServer()
	end)
	padButton.Activated:Connect(function()
		Remotes.get("BuyPad"):FireServer()
	end)
	rebirthButton.Activated:Connect(function()
		Remotes.get("Rebirth"):FireServer()
	end)

	-- ── Carry banner, top centre ──────────────────────────────────────────
	local carry = Ui.panel({
		Name = "Carry",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(360, 84),
		Visible = false,
		BackgroundColor3 = Color3.fromRGB(40, 22, 26),
		Parent = screen,
	})
	Ui.padding(10).Parent = carry

	local carryLabel = Ui.label({
		Size = UDim2.new(1, 0, 0, 20),
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "",
		Parent = carry,
	})
	local gripTrack, setGrip = Ui.bar(Ui.Palette.bad)
	gripTrack.Position = UDim2.fromOffset(0, 26)
	gripTrack.Size = UDim2.new(1, 0, 0, 8)
	gripTrack.Parent = carry

	local placeButton = Ui.button({
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(0.62, -4, 0, 30),
		TextSize = 13,
		BackgroundColor3 = Color3.fromRGB(30, 62, 40),
		Text = "Place At My Base",
		Parent = carry,
	})
	local dropButton = Ui.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 42),
		Size = UDim2.new(0.38, -4, 0, 30),
		TextSize = 13,
		Text = "Drop",
		Parent = carry,
	})
	placeButton.Activated:Connect(function()
		-- 0 means "auto": the server picks the pad.
		Remotes.get("PlaceCarried"):FireServer(0)
	end)
	dropButton.Activated:Connect(function()
		Remotes.get("DropCarried"):FireServer()
	end)

	-- ── Toasts, bottom right ──────────────────────────────────────────────
	local toastHolder = Ui.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(300, 220),
		BackgroundTransparency = 1,
		Parent = screen,
	}) :: Frame
	local toastLayout = Ui.listLayout(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Right)
	toastLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	toastLayout.Parent = toastHolder

	local toastOrder = 0

	local function toast(message: string, kind: string?)
		toastOrder += 1
		local color = Ui.Palette.text
		if kind == "good" then
			color = Ui.Palette.good
		elseif kind == "warn" then
			color = Ui.Palette.warn
		elseif kind == "bad" then
			color = Ui.Palette.bad
		end

		local frame = Ui.panel({
			LayoutOrder = toastOrder,
			Size = UDim2.new(1, 0, 0, 34),
			Parent = toastHolder,
		})
		local label = Ui.label({
			Size = UDim2.fromScale(1, 1),
			TextSize = 13,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = color,
			Text = message,
			Parent = frame,
		})

		task.delay(4, function()
			local fade = TweenService:Create(frame, TweenInfo.new(0.35), { BackgroundTransparency = 1 })
			local fadeText = TweenService:Create(label, TweenInfo.new(0.35), { TextTransparency = 1 })
			fade:Play()
			fadeText:Play()
			fade.Completed:Wait()
			frame:Destroy()
		end)
	end

	-- ── Floating punch numbers ────────────────────────────────────────────
	local function popup(text: string, color: Color3)
		local label = Ui.label({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.random(-60, 60), 0.5, math.random(-20, 20)),
			Size = UDim2.fromOffset(200, 30),
			Font = Enum.Font.GothamBlack,
			TextSize = 24,
			TextStrokeTransparency = 0.4,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = color,
			Text = text,
			Parent = screen,
		})
		local tween = TweenService:Create(label, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = label.Position - UDim2.fromOffset(0, 70),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		})
		tween:Play()
		tween.Completed:Connect(function()
			label:Destroy()
		end)
	end

	-- ── Update entry points ───────────────────────────────────────────────

	local function update(snapshot: { [string]: any })
		cashLabel.Text = Format.cash(snapshot.cash or 0)
		incomeLabel.Text = `{Format.rate(snapshot.income or 0)}  ·  {snapshot.pads or 0} pads`
		rankLabel.Text = `{snapshot.rankName or "--"}  ·  {Format.short(snapshot.strength or 0)} STR`
		setRank(snapshot.rankProgress or 0)

		local breaks = Rarities.get(snapshot.rankBreaks or "")
		local breaksName = if breaks then breaks.name else "--"
		local nextRank = snapshot.nextRankName
		local nextText = if nextRank
			then `Next: {nextRank} at {Format.short(snapshot.nextRankStrength or 0)} STR`
			else "Max rank"
		detailLabel.Text = `Punch {Format.short(snapshot.damage or 0)}  ·  cracks {breaksName}\n{nextText}`

		local trainCost = snapshot.trainingCost
		trainButton.Text = if trainCost
			then `Training Lv{snapshot.trainingLevel or 0}  ·  {Format.cash(trainCost)}`
			else `Training MAXED (Lv{snapshot.trainingLevel or 0})`

		local padCost = snapshot.padCost
		padButton.Text = if padCost then `Buy Pad {(snapshot.pads or 0) + 1}  ·  {Format.cash(padCost)}` else "All Pads Owned"

		rebirthButton.Text = `Rebirth {(snapshot.rebirths or 0) + 1}  ·  {Format.cash(snapshot.rebirthCash or 0)} + {Format.short(snapshot.rebirthStrength or 0)} STR`

		local carriedId = snapshot.carrying
		if carriedId then
			local brainrot = Brainrots.get(carriedId)
			carryLabel.Text = `CARRYING {if brainrot then brainrot.name:upper() else "LOOT"} -- RUN!`
			local maxGrip = snapshot.maxGrip or 1
			setGrip((snapshot.grip or 0) / math.max(maxGrip, 1))
			carry.Visible = true
		else
			carry.Visible = false
		end
	end

	local function updateShop(payload: { [string]: any })
		local slots = payload.slots or {}
		for index, ui in shopSlots do
			local slot = slots[index]
			if not slot then
				ui.button.Visible = false
			else
				ui.button.Visible = true
				local brainrot = Brainrots.get(slot.brainrotId)
				local rarity = if brainrot then Rarities.get(brainrot.rarity) else nil
				ui.name.Text = if brainrot then brainrot.name else slot.brainrotId
				ui.name.TextColor3 = if rarity then rarity.color else Ui.Palette.text
				if slot.sold then
					ui.price.Text = "SOLD"
					ui.price.TextColor3 = Ui.Palette.bad
				else
					ui.price.Text = `{Format.cash(slot.price)}  ·  {if rarity then rarity.name else "?"}`
					ui.price.TextColor3 = Ui.Palette.muted
				end
			end
		end
		shopTitle.Text = `SHOP  ·  rerolls every {Format.clock(payload.rerollSeconds or 0)}`
	end

	local function feedback(payload: { [string]: any })
		local kind = payload.kind
		if kind == "train" then
			popup(`+{Format.short(payload.strength or 0)} STR`, Ui.Palette.accent)
		elseif kind == "lock" then
			popup(`-{Format.short(payload.damage or 0)}`, Ui.Palette.warn)
		elseif kind == "carrier" then
			popup(`-{Format.short(payload.damage or 0)} GRIP`, Ui.Palette.bad)
		elseif kind == "steal" then
			popup("LOCK BROKEN", Ui.Palette.good)
		elseif kind == "blocked" then
			toast(payload.reason or "Blocked", "warn")
		end
	end

	return {
		update = update,
		updateShop = updateShop,
		feedback = feedback,
		toast = toast,
	}
end

return Hud
