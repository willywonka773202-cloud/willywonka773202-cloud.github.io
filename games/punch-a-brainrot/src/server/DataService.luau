--!strict
-- Persistence. Deliberately small: retrying GetAsync/SetAsync, an autosave
-- loop, and a BindToClose flush. It is not a full session-lock library --
-- if this game ever runs on more than one server per player, swap this module
-- for ProfileService and nothing else has to change, because every other
-- service only ever touches the profile table it is handed.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

export type PlacedBrainrot = { pad: number, id: string }

export type Profile = {
	version: number,
	cash: number,
	strength: number,
	rebirths: number,
	trainingLevel: number,
	pads: number,
	brainrots: { PlacedBrainrot },
	steals: number,
	robbed: number,
	punches: number,
	firstJoin: number,
	lastSeen: number,
}

local PROFILE_VERSION = 1
local MAX_ATTEMPTS = 4

local DataService = {}

local store: DataStore? = nil
-- Set when the DataStore is unreachable (Studio without API access, or an
-- outage). Play continues on in-memory profiles; we just stop trying to write.
local persistenceAvailable = true

local function key(player: Player): string
	return `player_{player.UserId}`
end

function DataService.defaultProfile(): Profile
	local now = os.time()
	return {
		version = PROFILE_VERSION,
		cash = 0,
		strength = 0,
		rebirths = 0,
		trainingLevel = 0,
		pads = Config.StartingPads,
		brainrots = {},
		steals = 0,
		robbed = 0,
		punches = 0,
		firstJoin = now,
		lastSeen = now,
	}
end

-- Fill in anything a older save is missing rather than rejecting it.
local function reconcile(raw: any): Profile
	local profile = DataService.defaultProfile()
	if type(raw) ~= "table" then
		return profile
	end

	for field, default in profile :: any do
		local value = (raw :: any)[field]
		if type(value) == type(default) then
			(profile :: any)[field] = value
		end
	end

	-- Defensive clamps: a corrupt or tampered save must not brick the session.
	profile.cash = math.max(0, profile.cash)
	profile.strength = math.max(0, profile.strength)
	profile.rebirths = math.max(0, math.floor(profile.rebirths))
	profile.trainingLevel = math.clamp(math.floor(profile.trainingLevel), 0, Config.MaxTrainingLevel)
	profile.pads = math.clamp(math.floor(profile.pads), Config.StartingPads, Config.MaxPads)
	profile.version = PROFILE_VERSION

	local cleaned: { PlacedBrainrot } = {}
	local seenPads: { [number]: boolean } = {}
	for _, entry in profile.brainrots do
		if type(entry) == "table" and type(entry.pad) == "number" and type(entry.id) == "string" then
			local pad = math.floor(entry.pad)
			if pad >= 1 and pad <= profile.pads and not seenPads[pad] then
				seenPads[pad] = true
				table.insert(cleaned, { pad = pad, id = entry.id })
			end
		end
	end
	profile.brainrots = cleaned

	return profile
end

local function getStore(): DataStore?
	if store then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("PunchABrainrot_v1")
	end)
	if ok then
		store = result
		return result
	end
	persistenceAvailable = false
	return nil
end

-- Retry with backoff. Returns nil when the store is unreachable, which the
-- caller treats as "fresh profile" rather than an error.
local function retry<T>(label: string, fn: () -> T): (boolean, T?)
	local delay = 1
	for attempt = 1, MAX_ATTEMPTS do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(`[DataService] {label} attempt {attempt}/{MAX_ATTEMPTS} failed: {result}`)
		if attempt < MAX_ATTEMPTS then
			task.wait(delay)
			delay *= 2
		end
	end
	return false, nil
end

function DataService.load(player: Player): Profile
	local activeStore = getStore()
	if not activeStore then
		return DataService.defaultProfile()
	end

	local ok, raw = retry(`load {player.Name}`, function()
		return (activeStore :: DataStore):GetAsync(key(player))
	end)

	if not ok then
		-- Do not hand the player a blank save we might then overwrite a real
		-- one with; mark them unsaveable for this session instead.
		player:SetAttribute("PABPersistenceBlocked", true)
		return DataService.defaultProfile()
	end

	return reconcile(raw)
end

function DataService.save(player: Player, profile: Profile): boolean
	if not persistenceAvailable then
		return false
	end
	if player:GetAttribute("PABPersistenceBlocked") then
		return false
	end

	local activeStore = getStore()
	if not activeStore then
		return false
	end

	profile.lastSeen = os.time()
	local snapshot = table.clone(profile)
	snapshot.brainrots = table.clone(profile.brainrots)

	local ok = retry(`save {player.Name}`, function()
		return (activeStore :: DataStore):SetAsync(key(player), snapshot)
	end)
	return ok
end

-- Starts the autosave loop and the shutdown flush. `getProfile` returns nil
-- for players whose profile is not loaded yet.
function DataService.start(getProfile: (Player) -> Profile?)
	task.spawn(function()
		while true do
			task.wait(Config.AutosaveSeconds)
			for _, player in Players:GetPlayers() do
				local profile = getProfile(player)
				if profile then
					task.spawn(DataService.save, player, profile)
				end
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end
		local pending = 0
		for _, player in Players:GetPlayers() do
			local profile = getProfile(player)
			if profile then
				pending += 1
				task.spawn(function()
					DataService.save(player, profile)
					pending -= 1
				end)
			end
		end
		local deadline = os.clock() + 20
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
