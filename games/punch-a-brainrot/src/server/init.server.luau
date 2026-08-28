--!strict
-- Boot order matters here: remotes exist before any client can ask for one,
-- the world exists before anyone can be assigned a plot, and StealService
-- binds PlayerRemoving before this script does so loot is returned home
-- before the state it references is torn down.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local DataService = require(script.DataService)
local PlayerState = require(script.PlayerState)
local PlotService = require(script.PlotService)
local StealService = require(script.StealService)
local CombatService = require(script.CombatService)
local EconomyService = require(script.EconomyService)
local ShopService = require(script.ShopService)

Remotes.build()
PlotService.init()
StealService.init()
ShopService.start()

DataService.start(function(player: Player)
	local state = PlayerState.get(player)
	return if state then state.profile else nil
end)

-- ── Player lifecycle ──────────────────────────────────────────────────────

local function onPlayerAdded(player: Player)
	local profile = DataService.load(player)
	if not player.Parent then
		return -- left during the yield
	end

	local state = PlayerState.add(player, profile)

	local plot = PlotService.assign(player)
	if plot then
		state.plotIndex = plot.index
		PlotService.syncPads(plot, profile.pads)

		-- Rebuild the base exactly as it was saved, dropping anything that no
		-- longer fits (a pad count reduced by a balance change, say).
		local restored: { { pad: number, id: string } } = {}
		for _, placed in profile.brainrots do
			if PlotService.spawnBrainrot(plot, placed.pad, placed.id) then
				table.insert(restored, placed)
			end
		end
		profile.brainrots = restored
	else
		PlayerState.toast(state, "All plots are taken -- you can still raid.", "warn")
	end

	EconomyService.grantOfflineEarnings(state)

	player.CharacterAdded:Connect(function(character)
		StealService.onCharacterAdded(player, character)
	end)
	if player.Character then
		StealService.onCharacterAdded(player, player.Character)
	end

	PlayerState.push(state)
	ShopService.sendTo(player)
end

local function onPlayerRemoving(player: Player)
	local state = PlayerState.get(player)
	if state then
		DataService.save(player, state.profile)
	end
	PlotService.release(player)
	PlayerState.remove(player)
end

Players.PlayerAdded:Connect(function(player)
	local ok, err = pcall(onPlayerAdded, player)
	if not ok then
		warn(`[Boot] failed to set up {player.Name}: {err}`)
	end
end)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

-- ── Remote handlers ───────────────────────────────────────────────────────

-- Every handler resolves the caller's state first; a request from a player
-- with no state is simply ignored.
local function withState(handler: (PlayerState.State, ...any) -> ()): (Player, ...any) -> ()
	return function(player: Player, ...)
		local state = PlayerState.get(player)
		if state then
			handler(state, ...)
		end
	end
end

Remotes.get("Punch").OnServerEvent:Connect(function(player: Player)
	CombatService.handlePunch(player)
end)

Remotes.get("BuyBrainrot").OnServerEvent:Connect(withState(function(state, slotIndex)
	if type(slotIndex) == "number" then
		ShopService.buy(state, math.floor(slotIndex))
	end
end))

Remotes.get("PlaceCarried").OnServerEvent:Connect(withState(function(state, padIndex)
	if type(padIndex) == "number" then
		StealService.deposit(state, math.floor(padIndex))
	end
end))

Remotes.get("DropCarried").OnServerEvent:Connect(withState(function(state)
	if state.carried then
		StealService.drop(state, "you let go")
	end
end))

Remotes.get("SellBrainrot").OnServerEvent:Connect(withState(function(state, padIndex)
	if type(padIndex) == "number" then
		EconomyService.sell(state, math.floor(padIndex))
	end
end))

Remotes.get("BuyPad").OnServerEvent:Connect(withState(EconomyService.buyPad))
Remotes.get("BuyTraining").OnServerEvent:Connect(withState(EconomyService.buyTraining))
Remotes.get("Rebirth").OnServerEvent:Connect(withState(EconomyService.rebirth))

-- ── Main loops ────────────────────────────────────────────────────────────

local incomeAccumulator = 0
local pushAccumulator = 0

RunService.Heartbeat:Connect(function(deltaTime)
	PlotService.regenerate(deltaTime)

	incomeAccumulator += deltaTime
	if incomeAccumulator >= Config.IncomeTickSeconds then
		EconomyService.tick(incomeAccumulator)
		incomeAccumulator = 0
	end

	-- Cash ticks up every second but the HUD only needs a snapshot twice a
	-- second; pushing per-frame would be pure bandwidth.
	pushAccumulator += deltaTime
	if pushAccumulator >= 0.5 then
		pushAccumulator = 0
		for _, state in PlayerState.all() do
			PlayerState.push(state)
		end
	end
end)
