-- Sound is a game mechanic here, not decoration:
--   * the facility hum is always there, and it FADES OUT as a copy gets near.
--     Silence is the warning.
--   * a low layer and a heartbeat rise with dread.
-- Sound ids come from Config.Sounds so they can be swapped without code.
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local AudioDirector = {}

local sounds = {}
local heartbeatTimer = 0
local started = false

local function make(name, looped)
	local def = Config.Sounds[name]
	local sound = Instance.new("Sound")
	sound.Name = "Headcount_" .. name
	sound.SoundId = def.Id
	sound.PlaybackSpeed = def.Speed
	sound.Volume = looped and 0 or def.Volume
	sound.Looped = looped
	sound.Parent = SoundService

	-- Everything is pushed through reverb and has its top end rolled off, so
	-- even placeholder sounds feel like they are coming down a long corridor.
	local reverb = Instance.new("ReverbSoundEffect")
	reverb.DecayTime = 6
	reverb.Density = 1
	reverb.Diffusion = 1
	reverb.DryLevel = -4
	reverb.WetLevel = -2
	reverb.Parent = sound

	local eq = Instance.new("EqualizerSoundEffect")
	eq.HighGain = -18
	eq.MidGain = -4
	eq.LowGain = 4
	eq.Parent = sound

	sounds[name] = sound
	return sound
end

function AudioDirector.init()
	if started then
		return
	end
	started = true
	for name in pairs(Config.Sounds) do
		make(name, name == "Ambience" or name == "Dread")
	end
	sounds.Ambience:Play()
	sounds.Dread:Play()
end

-- One-shot sound by Config name.
function AudioDirector.play(name)
	local sound = sounds[name]
	if sound then
		SoundService:PlayLocalSound(sound)
	end
end

-- Call every frame. dread is 0..1, inFacility is false in the staging room.
function AudioDirector.update(dt, dread, inFacility)
	if not started then
		return
	end
	local ambience = sounds.Ambience
	local layer = sounds.Dread
	local blend = math.min(1, dt * 2.5)

	local ambienceTarget = Config.Sounds.Ambience.Volume
	if inFacility then
		-- The hum dies as it gets close.
		ambienceTarget = ambienceTarget * math.clamp(1 - dread * 1.6, 0, 1)
	else
		ambienceTarget = ambienceTarget * 0.35
	end
	ambience.Volume = ambience.Volume + (ambienceTarget - ambience.Volume) * blend

	local layerTarget = inFacility and (Config.Sounds.Dread.Volume * math.clamp((dread - 0.25) / 0.75, 0, 1)) or 0
	layer.Volume = layer.Volume + (layerTarget - layer.Volume) * blend
	layer.PlaybackSpeed = Config.Sounds.Dread.Speed * (1 + dread * 0.25)

	if inFacility and dread > 0.3 then
		heartbeatTimer = heartbeatTimer - dt
		if heartbeatTimer <= 0 then
			-- Faster the closer it is: about 50 bpm rising to about 170.
			heartbeatTimer = 1.2 - dread * 0.85
			local beat = sounds.Heartbeat
			beat.Volume = Config.Sounds.Heartbeat.Volume * dread
			SoundService:PlayLocalSound(beat)
			task.delay(0.16, function()
				SoundService:PlayLocalSound(beat)
			end)
		end
	else
		heartbeatTimer = 0
	end
end

return AudioDirector
