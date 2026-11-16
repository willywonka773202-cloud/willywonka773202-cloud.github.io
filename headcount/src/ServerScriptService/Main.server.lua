-- HEADCOUNT server. Runs the loop:
--   Intermission (staging room) -> Descent -> Expedition -> Results -> repeat
-- and owns everything that must not be trusted to a client: the copies,
-- samples, credits, battery, headcounts and accusations.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Modules = script.Parent.Modules
local Atmosphere = require(Modules.Atmosphere)
local MapGenerator = require(Modules.MapGenerator)
local Recorder = require(Modules.Recorder)
local Mimic = require(Modules.Mimic)
local PlayerData = require(Modules.PlayerData)

local STAGING_ORIGIN = Vector3.new(0, 300, 0)
local MAP_ORIGIN = Vector3.new(-110, 0, -110)

---------------------------------------------------------------------------
-- Shared state the clients read
---------------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local function remote(name)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local ToggleFlashlight = remote("ToggleFlashlight")
local HeadcountRequest = remote("Headcount")
local HeadcountResult = remote("HeadcountResult")
local Notify = remote("Notify")
local Jumpscare = remote("Jumpscare")
local BuyUpgrade = remote("BuyUpgrade")
local Results = remote("Results")
remotes.Parent = ReplicatedStorage

local state = Instance.new("Folder")
state.Name = "GameState"
state:SetAttribute("Phase", "Intermission")
state:SetAttribute("Night", 1)
state:SetAttribute("TimeLeft", 0)
state:SetAttribute("Quota", 0)
state:SetAttribute("Deposited", 0)
state:SetAttribute("CrewAlive", 0)
state:SetAttribute("CrewTotal", 0)
state.Parent = ReplicatedStorage

Atmosphere.apply()
local staging = MapGenerator.buildStaging(STAGING_ORIGIN)
staging.model.Parent = workspace

local mimicFolder = Instance.new("Folder")
mimicFolder.Name = "Others"
mimicFolder.Parent = workspace

local night = 1
local run = nil -- the expedition in progress, or nil

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function charOf(player)
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return character, humanoid, root
	end
	return nil
end

local function aliveCrew()
	local list = {}
	if not run then
		return list
	end
	for player in pairs(run.crew) do
		if player.Parent and player:GetAttribute("Alive") and charOf(player) then
			list[#list + 1] = player
		end
	end
	return list
end

local function notifyAll(text, kind, sound)
	Notify:FireAllClients({ text = text, kind = kind or "info", sound = sound })
end

local function notify(player, text, kind, sound)
	Notify:FireClient(player, { text = text, kind = kind or "info", sound = sound })
end

local function setFlashlight(player, on)
	local character = player.Character
	if not character then
		return
	end
	character:SetAttribute("Flashlight", on)
	local head = character:FindFirstChild("Head")
	local light = head and head:FindFirstChild("CrewLight")
	if light then
		light.Enabled = on
	end
end

local function horizontalDistance(a, b)
	return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end

---------------------------------------------------------------------------
-- Accusations
---------------------------------------------------------------------------
local function attachAccusePrompt(model, mimic)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local old = root:FindFirstChild("Accuse")
	if old then
		old:Destroy()
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Accuse"
	prompt.ActionText = "ACCUSE"
	prompt.ObjectText = "This is not one of us"
	prompt.HoldDuration = Config.Accuse.HoldTime
	prompt.MaxActivationDistance = Config.Accuse.Distance
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.Parent = root

	prompt.Triggered:Connect(function(accuser)
		if not run or not run.crew[accuser] or not accuser:GetAttribute("Alive") then
			return
		end
		if accuser.Character == model then
			return
		end
		local now = workspace:GetServerTimeNow()
		if now < (accuser:GetAttribute("AccuseReadyAt") or 0) then
			notify(accuser, "You are not sure enough yet.", "info")
			return
		end
		accuser:SetAttribute("AccuseReadyAt", now + Config.Accuse.Cooldown)

		if mimic and mimic.alive then
			local wornName = mimic.target.DisplayName
			mimic:banish()
			run.nextMimicAt = os.clock() + Config.Mimic.RespawnDelay
			run.bonus = run.bonus + Config.Accuse.BanishBonus
			notifyAll(accuser.DisplayName .. " counted right. That was not " .. wornName .. ".", "good", "Banish")
		elseif not mimic then
			-- They accused a real person.
			accuser:SetAttribute("LightsOutUntil", now + Config.Accuse.LightsOut)
			setFlashlight(accuser, false)
			for _, other in ipairs(run.mimics) do
				other:closeIn(Config.Accuse.LagPenalty)
			end
			notifyAll(accuser.DisplayName .. " miscounted. Something is closer now.", "bad", "Bad")
		end
	end)
end

---------------------------------------------------------------------------
-- Players
---------------------------------------------------------------------------
local function onCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local head = character:WaitForChild("Head", 10)
	if not humanoid or not head then
		return
	end
	humanoid.WalkSpeed = Config.WalkSpeed
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.NameDisplayDistance = 45
	humanoid.NameOcclusion = Enum.NameOcclusion.OccludeAll
	character:SetAttribute("Flashlight", false)

	local light = Instance.new("SpotLight")
	light.Name = "CrewLight"
	light.Face = Enum.NormalId.Front
	light.Angle = 55
	light.Range = 55
	light.Brightness = 2.4
	light.Color = Color3.fromRGB(255, 244, 224)
	light.Shadows = true
	light.Enabled = false
	light.Parent = head

	humanoid.Died:Connect(function()
		if run and run.crew[player] and player:GetAttribute("Alive") then
			player:SetAttribute("Alive", false)
			player:SetAttribute("Samples", 0)
			notifyAll(player.DisplayName .. " is no longer counted.", "bad")
		end
	end)
end

local function onPlayer(player)
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	player:SetAttribute("InRun", false)
	player:SetAttribute("Alive", false)
	player:SetAttribute("Samples", 0)
	player:SetAttribute("Battery", 100)
	player:SetAttribute("Dread", 0)
	player:SetAttribute("HeadcountReadyAt", 0)
	player:SetAttribute("AccuseReadyAt", 0)
	player:SetAttribute("LightsOutUntil", 0)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	PlayerData.load(player)
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	PlayerData.save(player)
	if run then
		run.crew[player] = nil
		run.recorder:forget(player)
	end
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		PlayerData.save(player)
	end
end)

---------------------------------------------------------------------------
-- Client requests
---------------------------------------------------------------------------
ToggleFlashlight.OnServerEvent:Connect(function(player)
	local character = charOf(player)
	if not character then
		return
	end
	local on = not character:GetAttribute("Flashlight")
	if on then
		if (player:GetAttribute("Battery") or 0) <= 0 then
			notify(player, "Battery dead. Get back to the lift.", "bad")
			return
		end
		if workspace:GetServerTimeNow() < (player:GetAttribute("LightsOutUntil") or 0) then
			notify(player, "Your light will not come on.", "bad")
			return
		end
	end
	setFlashlight(player, on)
end)

HeadcountRequest.OnServerEvent:Connect(function(player)
	if not run or not run.crew[player] or not player:GetAttribute("Alive") then
		return
	end
	local _, _, root = charOf(player)
	if not root then
		return
	end
	local now = workspace:GetServerTimeNow()
	if now < (player:GetAttribute("HeadcountReadyAt") or 0) then
		return
	end
	local cooldown = Config.Headcount.Cooldown - (player:GetAttribute("UpScanner") or 0) * Config.Headcount.CooldownPerUpgrade
	player:SetAttribute("HeadcountReadyAt", now + math.max(4, cooldown))

	local radius = Config.Headcount.Radius
	local bodies = 0
	local listeners = {}
	for _, other in ipairs(aliveCrew()) do
		local _, _, otherRoot = charOf(other)
		if otherRoot and (otherRoot.Position - root.Position).Magnitude <= radius then
			bodies = bodies + 1
			listeners[#listeners + 1] = other
		end
	end
	for _, mimic in ipairs(run.mimics) do
		if mimic.alive and (mimic.root.Position - root.Position).Magnitude <= radius then
			bodies = bodies + 1
		end
	end
	for _, listener in ipairs(listeners) do
		HeadcountResult:FireClient(listener, { bodies = bodies, caller = player.DisplayName })
	end
end)

BuyUpgrade.OnServerEvent:Connect(function(player, name)
	if type(name) ~= "string" then
		return
	end
	local def = Config.Upgrades[name]
	if not def or state:GetAttribute("Phase") ~= "Intermission" then
		return
	end
	local field = "Up" .. name
	local level = player:GetAttribute(field) or 0
	local cost = def.Cost * (level + 1)
	local credits = player:GetAttribute("Credits") or 0
	if level >= def.Max then
		notify(player, def.Label .. " is fully upgraded.", "info")
	elseif credits < cost then
		notify(player, "Not enough credits.", "bad", "Bad")
	else
		player:SetAttribute("Credits", credits - cost)
		player:SetAttribute(field, level + 1)
		notify(player, def.Label .. " upgraded to level " .. (level + 1) .. ".", "good", "Collect")
	end
end)

---------------------------------------------------------------------------
-- Expedition pieces
---------------------------------------------------------------------------
local function spawnSamples(spots, count, parent)
	local rng = Random.new()
	local pool = table.clone(spots)
	for _ = 1, math.min(count, #pool) do
		local index = rng:NextInteger(1, #pool)
		local position = pool[index]
		table.remove(pool, index)

		local canister = Instance.new("Part")
		canister.Name = "Sample"
		canister.Shape = Enum.PartType.Cylinder
		canister.Size = Vector3.new(2, 1.1, 1.1)
		canister.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2)
		canister.Anchored = true
		canister.CanCollide = false
		canister.Material = Enum.Material.Neon
		canister.Color = Color3.fromRGB(140, 255, 170)
		canister.Parent = parent

		local glow = Instance.new("PointLight")
		glow.Color = canister.Color
		glow.Range = 9
		glow.Brightness = 0.7
		glow.Parent = canister

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Collect"
		prompt.ActionText = "COLLECT"
		prompt.ObjectText = "Sample"
		prompt.HoldDuration = 0.6
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.Style = Enum.ProximityPromptStyle.Custom
		prompt.Parent = canister
		prompt.Triggered:Connect(function(player)
			if not run or not run.crew[player] or not player:GetAttribute("Alive") then
				return
			end
			local carrying = player:GetAttribute("Samples") or 0
			if carrying >= Config.Samples.CarryCap then
				notify(player, "Hands full. Take them to the lift.", "info")
				return
			end
			player:SetAttribute("Samples", carrying + 1)
			notify(player, "Sample secured.", "good", "Collect")
			canister:Destroy()
		end)
	end
end

local function makeMimicContext()
	local wallParams = RaycastParams.new()
	wallParams.FilterType = Enum.RaycastFilterType.Include
	wallParams.FilterDescendantsInstances = { run.map.model }

	return {
		recorder = run.recorder,
		folder = mimicFolder,
		charOf = charOf,
		attachPrompt = attachAccusePrompt,

		-- Alone = no other living crew member close by. A solo player is always alone.
		isIsolated = function(player)
			local _, _, root = charOf(player)
			if not root then
				return false
			end
			for _, other in ipairs(aliveCrew()) do
				if other ~= player then
					local _, _, otherRoot = charOf(other)
					if otherRoot and (otherRoot.Position - root.Position).Magnitude < Config.Mimic.SafeRadius then
						return false
					end
				end
			end
			return true
		end,

		-- Watched = someone is pointing a lit flashlight at it with no wall between.
		isWatched = function(position)
			for _, player in ipairs(aliveCrew()) do
				local character, _, root = charOf(player)
				if character and character:GetAttribute("Flashlight") then
					local offset = position - root.Position
					local distance = offset.Magnitude
					if distance < Config.Mimic.WatchRange and distance > 0.5 then
						if root.CFrame.LookVector:Dot(offset.Unit) > Config.Mimic.WatchDot then
							if not workspace:Raycast(root.Position, offset, wallParams) then
								return true
							end
						end
					end
				end
			end
			return false
		end,

		onKill = function(mimic, victim)
			local _, humanoid = charOf(victim)
			Jumpscare:FireClient(victim, { name = victim.DisplayName })
			if humanoid then
				humanoid.Health = 0
			end
			mimic:destroy()
			run.nextMimicAt = os.clock() + Config.Mimic.RespawnDelay
		end,
	}
end

local function updateMimics(now)
	-- Clear out copies that are gone.
	for index = #run.mimics, 1, -1 do
		if not run.mimics[index].alive then
			table.remove(run.mimics, index)
		end
	end
	local wanted = math.min(Config.Mimic.MaxCount, 1 + math.floor((night - 1) / Config.Mimic.NightsPerExtra))
	if #run.mimics >= wanted or os.clock() < run.nextMimicAt then
		return
	end
	local crew = aliveCrew()
	if #crew == 0 then
		return
	end
	-- Prefer someone who is not already being copied.
	local copied = {}
	for _, mimic in ipairs(run.mimics) do
		copied[mimic.target] = true
	end
	local candidates = {}
	for _, player in ipairs(crew) do
		if not copied[player] then
			candidates[#candidates + 1] = player
		end
	end
	if #candidates == 0 then
		return
	end
	local target = candidates[math.random(1, #candidates)]
	local mimic = Mimic.new(run.context, target, night)
	if mimic:spawn(now) then
		run.mimics[#run.mimics + 1] = mimic
		run.nextMimicAt = os.clock() + 12
	else
		run.nextMimicAt = os.clock() + 3
	end
end

local function updateDread()
	for _, player in ipairs(Players:GetPlayers()) do
		local dread = 0
		local _, _, root = charOf(player)
		if run and root and run.crew[player] and player:GetAttribute("Alive") then
			for _, mimic in ipairs(run.mimics) do
				if mimic.alive then
					local distance = (mimic.root.Position - root.Position).Magnitude
					local value = math.clamp(1 - distance / Config.Mimic.DreadRange, 0, 1)
					if mimic.target == player and mimic.state == "hunt" then
						value = math.min(1, value * 1.5 + 0.15)
					end
					dread = math.max(dread, value)
				end
			end
		end
		player:SetAttribute("Dread", math.floor(dread * 100) / 100)
	end
end

local function updateCrew(dt)
	local onPad = 0
	local crew = aliveCrew()
	for _, player in ipairs(crew) do
		local character, _, root = charOf(player)
		local battery = player:GetAttribute("Battery") or 0
		local atLift = horizontalDistance(root.Position, run.map.padPosition) < 8.5
		if atLift then
			onPad = onPad + 1
			battery = math.min(100, battery + Config.Flashlight.Recharge * dt)
			local carrying = player:GetAttribute("Samples") or 0
			if carrying > 0 then
				player:SetAttribute("Samples", 0)
				run.deposited = run.deposited + carrying
				state:SetAttribute("Deposited", run.deposited)
				notifyAll(player.DisplayName .. " loaded " .. carrying .. " onto the lift.", "good", "Collect")
			end
		elseif character:GetAttribute("Flashlight") then
			local life = Config.Flashlight.BaseLife + (player:GetAttribute("UpBattery") or 0) * Config.Flashlight.LifePerUpgrade
			battery = math.max(0, battery - 100 / life * dt)
			if battery <= 0 then
				setFlashlight(player, false)
				notify(player, "Your light is dead.", "bad", "Switch")
			end
		end
		player:SetAttribute("Battery", battery)
	end
	state:SetAttribute("CrewAlive", #crew)
	return #crew, onPad
end

---------------------------------------------------------------------------
-- The loop
---------------------------------------------------------------------------
local function countdown(phase, seconds)
	state:SetAttribute("Phase", phase)
	for remaining = seconds, 1, -1 do
		state:SetAttribute("TimeLeft", remaining)
		task.wait(1)
	end
	state:SetAttribute("TimeLeft", 0)
end

local function readyPlayers()
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if charOf(player) and player:GetAttribute("DataLoaded") then
			list[#list + 1] = player
		end
	end
	return list
end

local function runExpedition()
	local crewList = readyPlayers()
	if #crewList == 0 then
		return
	end

	local map = MapGenerator.build(MAP_ORIGIN, math.random(1, 1e6))
	map.model.Parent = workspace

	local quota = Config.Samples.QuotaBase + Config.Samples.QuotaPerPlayer * #crewList + Config.Samples.QuotaPerNight * (night - 1)
	quota = math.min(quota, #map.sampleSpots)
	run = {
		map = map,
		crew = {},
		mimics = {},
		recorder = Recorder.new(90),
		deposited = 0,
		bonus = 0,
		quota = quota,
		nextMimicAt = 0,
	}
	run.context = makeMimicContext()
	spawnSamples(map.sampleSpots, math.ceil(quota * Config.Samples.SpawnMultiplier), map.model)

	state:SetAttribute("Night", night)
	state:SetAttribute("Quota", quota)
	state:SetAttribute("Deposited", 0)
	state:SetAttribute("CrewTotal", #crewList)
	state:SetAttribute("CrewAlive", #crewList)

	notifyAll("The lift is going down.", "info", "Lift")
	countdown("Descent", Config.DescentTime)

	for index, player in ipairs(crewList) do
		local character, _, root = charOf(player)
		if character and player.Parent then
			run.crew[player] = true
			player:SetAttribute("InRun", true)
			player:SetAttribute("Alive", true)
			player:SetAttribute("Samples", 0)
			player:SetAttribute("Battery", 100)
			player:SetAttribute("LightsOutUntil", 0)
			local angle = (index / #crewList) * math.pi * 2
			root.CFrame = map.startCFrame * CFrame.new(math.cos(angle) * 4, 0, math.sin(angle) * 4)
			attachAccusePrompt(character, nil)
		end
	end

	local firstSpawn = math.max(Config.Mimic.MinFirstSpawn, Config.Mimic.FirstSpawn - (night - 1) * Config.Mimic.FirstSpawnPerNight)
	run.nextMimicAt = os.clock() + firstSpawn

	state:SetAttribute("Phase", "Expedition")
	notifyAll("Night " .. night .. ". Bring back " .. quota .. " samples. Stay counted.", "info")

	local recordTimer, slowTimer = 0, 0
	local heartbeat = RunService.Heartbeat:Connect(function(dt)
		if not run then
			return
		end
		local now = os.clock()
		recordTimer = recordTimer + dt
		if recordTimer >= 0.1 then
			recordTimer = 0
			for _, player in ipairs(aliveCrew()) do
				local character, _, root = charOf(player)
				run.recorder:sample(player, now, root.CFrame, character:GetAttribute("Flashlight") == true)
			end
		end
		for _, mimic in ipairs(run.mimics) do
			mimic:step(dt, now)
		end
		slowTimer = slowTimer + dt
		if slowTimer >= 0.2 then
			slowTimer = 0
			updateMimics(now)
			updateDread()
		end
	end)

	local deadline = os.clock() + Config.ExpeditionTime
	local success = false
	local warned = false
	while true do
		task.wait(0.25)
		local alive, onPad = updateCrew(0.25)
		local left = math.max(0, math.ceil(deadline - os.clock()))
		state:SetAttribute("TimeLeft", left)
		if left <= 60 and not warned then
			warned = true
			notifyAll("The lift leaves in one minute.", "bad", "Bad")
		end
		if alive == 0 then
			break
		end
		if run.deposited >= run.quota and onPad == alive then
			success = true
			break
		end
		if left <= 0 then
			success = run.deposited >= run.quota and onPad > 0
			break
		end
	end
	heartbeat:Disconnect()

	-- Pay out. Anyone not on the lift when it leaves is left behind.
	local multiplier = 1 + Config.Samples.NightBonus * (night - 1)
	local pot = math.floor(run.deposited * Config.Samples.CreditEach * multiplier) + run.bonus
	local survivors = 0
	for player in pairs(run.crew) do
		if player.Parent then
			local _, humanoid, root = charOf(player)
			local escaped = player:GetAttribute("Alive")
				and root ~= nil
				and horizontalDistance(root.Position, run.map.padPosition) < 8.5
			local earned = 0
			if success and escaped then
				survivors = survivors + 1
				earned = pot
				if night > (player:GetAttribute("BestNight") or 0) then
					player:SetAttribute("BestNight", night)
				end
			elseif success then
				earned = math.floor(pot / 2)
			end
			player:SetAttribute("Credits", (player:GetAttribute("Credits") or 0) + earned)
			Results:FireClient(player, {
				success = success,
				escaped = escaped == true,
				night = night,
				deposited = run.deposited,
				quota = run.quota,
				earned = earned,
			})
			if humanoid and not (success and escaped) then
				humanoid.Health = 0
			end
		end
	end

	state:SetAttribute("Phase", "Results")
	task.wait(1.5)

	-- Tear down and send the survivors back up.
	for _, mimic in ipairs(run.mimics) do
		mimic:destroy()
	end
	mimicFolder:ClearAllChildren()
	for player in pairs(run.crew) do
		if player.Parent then
			player:SetAttribute("InRun", false)
			player:SetAttribute("Alive", false)
			player:SetAttribute("Samples", 0)
			player:SetAttribute("Dread", 0)
			setFlashlight(player, false)
			local character, _, root = charOf(player)
			if character then
				local prompt = root:FindFirstChild("Accuse")
				if prompt then
					prompt:Destroy()
				end
				root.CFrame = staging.spawnCFrame
			end
			task.spawn(PlayerData.save, player)
		end
	end
	map.model:Destroy()
	run = nil

	if success and survivors > 0 then
		night = night + 1
	else
		night = 1
	end
	state:SetAttribute("Night", night)
	countdown("Results", Config.ResultsTime)
end

while true do
	state:SetAttribute("Phase", "Intermission")
	state:SetAttribute("TimeLeft", 0)
	while #readyPlayers() == 0 do
		task.wait(1)
	end
	countdown("Intermission", Config.Intermission)
	local ok, err = pcall(runExpedition)
	if not ok then
		warn("[Headcount] expedition failed: " .. tostring(err))
		if run then
			if run.map and run.map.model then
				run.map.model:Destroy()
			end
			run = nil
		end
		mimicFolder:ClearAllChildren()
		task.wait(3)
	end
end
