-- Every tuning knob lives here. Change numbers, not code.
local Config = {}

Config.Intermission = 20 -- seconds in the staging room between runs
Config.DescentTime = 6
Config.ExpeditionTime = 420
Config.ResultsTime = 12

Config.WalkSpeed = 12
Config.SprintSpeed = 20
Config.StaminaDrain = 24 -- per second while sprinting
Config.StaminaRegen = 12
Config.StaminaRegenPerUpgrade = 3

Config.Map = {
	Cols = 5,
	Rows = 5,
	Cell = 44,
	Height = 14,
	Wall = 2,
	DoorWidth = 9,
	DoorHeight = 9,
	ExtraLoops = 0.28, -- chance to knock an extra doorway through, so the maze has loops
	LightAlive = 0.55, -- chance a room's ceiling light works at all
	LightFlicker = 0.4, -- of working lights, chance it flickers
}

Config.Mimic = {
	FirstSpawn = 50, -- seconds into the run on night 1
	FirstSpawnPerNight = 5, -- sooner each night
	MinFirstSpawn = 15,
	RespawnDelay = 40, -- after a banish or a kill
	BaseLag = 24, -- how many seconds behind its target it walks on night 1
	LagPerNight = 2,
	MinLag = 8,
	HuntRate = 1.3, -- playback speed while hunting (1 = same speed as the target)
	HuntRatePerNight = 0.05,
	MaxHuntRate = 1.8,
	IsolateGrace = 6, -- seconds a target must be alone before it starts closing in
	SafeRadius = 30, -- another living crew member within this radius = not alone
	HoverDistance = 6, -- when not hunting it stops this far behind its target
	KillDistance = 4,
	WatchRange = 60, -- a lit flashlight pointed at it within this range freezes it
	WatchDot = 0.75,
	DreadRange = 60,
	MaxCount = 3,
	NightsPerExtra = 3, -- one more copy every N nights
}

Config.Samples = {
	CarryCap = 3,
	CreditEach = 10,
	NightBonus = 0.25, -- +25% credits per night survived
	QuotaBase = 3,
	QuotaPerPlayer = 2,
	QuotaPerNight = 1,
	SpawnMultiplier = 1.7, -- samples on the map = quota * this
}

Config.Flashlight = {
	BaseLife = 150, -- seconds of light on a full battery
	LifePerUpgrade = 30,
	Recharge = 12, -- percent per second while standing on the lift
}

Config.Headcount = {
	Radius = 45,
	Cooldown = 22,
	CooldownPerUpgrade = 3,
}

Config.Accuse = {
	Cooldown = 20,
	HoldTime = 1.5,
	Distance = 14,
	LightsOut = 18, -- seconds your flashlight is dead after accusing a real person
	LagPenalty = 5, -- and every copy gets this much closer
	BanishBonus = 15, -- credits to the whole crew for a correct call
}

Config.Upgrades = {
	Battery = { Max = 5, Cost = 40, Label = "BATTERY", Blurb = "+30s of light per level" },
	Stamina = { Max = 5, Cost = 40, Label = "LUNGS", Blurb = "Stamina recovers faster" },
	Scanner = { Max = 5, Cost = 60, Label = "COUNTER", Blurb = "Headcount recharges 3s sooner" },
}

-- PLACEHOLDER AUDIO. These are sounds that ship inside the Roblox client, slowed
-- down and run through reverb so the game is not silent on first launch.
-- Replace each id with a real asset ("rbxassetid://123") from the Creator Store.
Config.Sounds = {
	Ambience = { Id = "rbxasset://sounds/action_falling.mp3", Speed = 0.28, Volume = 0.55 },
	Dread = { Id = "rbxasset://sounds/HalloweenGhost.wav", Speed = 0.35, Volume = 0.6 },
	Heartbeat = { Id = "rbxasset://sounds/bass.wav", Speed = 0.55, Volume = 0.9 },
	Sting = { Id = "rbxasset://sounds/uuhhh.mp3", Speed = 0.3, Volume = 1.4 },
	Banish = { Id = "rbxasset://sounds/glassbreak.wav", Speed = 0.45, Volume = 0.9 },
	Ping = { Id = "rbxasset://sounds/electronicpingshort.wav", Speed = 0.7, Volume = 0.6 },
	Click = { Id = "rbxasset://sounds/clickfast.wav", Speed = 1, Volume = 0.5 },
	Switch = { Id = "rbxasset://sounds/switch.wav", Speed = 0.9, Volume = 0.6 },
	Collect = { Id = "rbxasset://sounds/snap.mp3", Speed = 0.6, Volume = 0.6 },
	Bad = { Id = "rbxasset://sounds/collide.wav", Speed = 0.4, Volume = 0.8 },
	Lift = { Id = "rbxasset://sounds/Rocket whoosh 01.wav", Speed = 0.25, Volume = 0.7 },
}

return Config
