--!strict
-- The rotating shop. This is the honest way into the economy: buying is how
-- you seed a base, stealing is how you scale one. Shop stock is global and
-- rerolls on a timer so everybody on the server is chasing the same slots.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Brainrots = require(Shared.Brainrots)
local Rarities = require(Shared.Rarities)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)

local PlayerState = require(script.Parent.PlayerState)
local PlotService = require(script.Parent.PlotService)

export type Slot = {
	brainrotId: string,
	price: number,
	sold: boolean,
}

local ShopService = {}

local random = Random.new()
local slots: { Slot } = {}
local nextRerollAt = 0

local function broadcast()
	local payload = {
		slots = slots,
		rerollAt = nextRerollAt,
		rerollSeconds = Config.ShopRerollSeconds,
	}
	Remotes.get("ShopChanged"):FireAllClients(payload)
end

function ShopService.reroll()
	slots = {}
	for _ = 1, Config.ShopSlots do
		local rarity = Rarities.roll(random)
		local brainrot = Brainrots.pick(random, rarity.id)
		if brainrot then
			table.insert(slots, {
				brainrotId = brainrot.id,
				price = Brainrots.price(brainrot),
				sold = false,
			})
		end
	end
	nextRerollAt = os.time() + Config.ShopRerollSeconds
	broadcast()
end

function ShopService.sendTo(player: Player)
	Remotes.get("ShopChanged"):FireClient(player, {
		slots = slots,
		rerollAt = nextRerollAt,
		rerollSeconds = Config.ShopRerollSeconds,
	})
end

function ShopService.buy(state: PlayerState.State, slotIndex: number)
	local slot = slots[slotIndex]
	if not slot then
		return
	end
	if slot.sold then
		PlayerState.toast(state, "Someone beat you to it.", "warn")
		return
	end

	local brainrot = Brainrots.get(slot.brainrotId)
	if not brainrot then
		return
	end

	if state.profile.cash < slot.price then
		PlayerState.toast(state, `Need {Format.cash(slot.price)}.`, "warn")
		return
	end

	local plot = PlotService.forPlayer(state.player)
	if not plot then
		PlayerState.toast(state, "You do not have a base yet.", "warn")
		return
	end

	local pad = PlayerState.firstFreePad(state)
	if not pad then
		PlayerState.toast(state, "No free pads -- sell one or buy another.", "warn")
		return
	end

	if not PlotService.spawnBrainrot(plot, pad, slot.brainrotId) then
		return
	end

	PlayerState.addCash(state, -slot.price)
	PlayerState.setPlaced(state, pad, slot.brainrotId)
	slot.sold = true

	PlayerState.toast(state, `Bought {brainrot.name}.`, "good")
	PlayerState.push(state)
	broadcast()
end

function ShopService.start()
	ShopService.reroll()

	task.spawn(function()
		while true do
			task.wait(Config.ShopRerollSeconds)
			ShopService.reroll()
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		task.defer(ShopService.sendTo, player)
	end)
end

return ShopService
