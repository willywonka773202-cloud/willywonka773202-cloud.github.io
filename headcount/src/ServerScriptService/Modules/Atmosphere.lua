-- The whole look of the game is set here: near-total darkness, thick air,
-- desaturated colour, and bloom so the few lights that work feel harsh.
-- Lighting.Technology cannot be set from a script; it is set to Future in the
-- place file / Rojo project. Check it in Studio: Lighting > Technology.
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

local Atmosphere = {}

local function ensure(className, name)
	local inst = Lighting:FindFirstChild(name)
	if not inst then
		inst = Instance.new(className)
		inst.Name = name
		inst.Parent = Lighting
	end
	return inst
end

function Atmosphere.apply()
	Lighting.Brightness = 0
	Lighting.Ambient = Color3.fromRGB(5, 6, 8)
	Lighting.OutdoorAmbient = Color3.fromRGB(0, 0, 0)
	Lighting.ClockTime = 0
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.ExposureCompensation = -0.15
	Lighting.FogEnd = 100000

	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Sky") or child:IsA("SunRaysEffect") then
			child:Destroy()
		end
	end

	local air = ensure("Atmosphere", "Air")
	air.Density = 0.44
	air.Offset = 0
	air.Color = Color3.fromRGB(22, 26, 28)
	air.Decay = Color3.fromRGB(8, 10, 10)
	air.Glare = 0
	air.Haze = 1.6

	local grade = ensure("ColorCorrectionEffect", "Grade")
	grade.Saturation = -0.3
	grade.Contrast = 0.18
	grade.Brightness = -0.02
	grade.TintColor = Color3.fromRGB(226, 240, 232)

	local bloom = ensure("BloomEffect", "Bloom")
	bloom.Intensity = 0.7
	bloom.Size = 32
	bloom.Threshold = 1.05

	local dof = ensure("DepthOfFieldEffect", "Lens")
	dof.FocusDistance = 18
	dof.InFocusRadius = 28
	dof.NearIntensity = 0
	dof.FarIntensity = 0.22

	-- Every 3D sound in the facility echoes like bare concrete.
	SoundService.AmbientReverb = Enum.ReverbType.StoneCorridor
	SoundService.DistanceFactor = 3.33
	SoundService.RolloffScale = 1.2
end

return Atmosphere
