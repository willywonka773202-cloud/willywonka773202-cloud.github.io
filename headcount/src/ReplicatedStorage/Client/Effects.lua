-- Screen and camera effects driven by one number, dread (0..1):
-- colour drains, the view narrows and shakes, and broken lights stutter faster.
-- Also owns the player's own flashlight beam, which sways behind the camera.
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local Effects = {}

local camera = workspace.CurrentCamera
local grade, blur
local beamPart, beam
local smoothDread = 0
local punch = 0
local flicker = {} -- tube -> next toggle time
local BASE_FOV = 70

function Effects.init()
	grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "DreadGrade"
	grade.Parent = Lighting

	blur = Instance.new("BlurEffect")
	blur.Name = "DreadBlur"
	blur.Size = 0
	blur.Parent = Lighting

	beamPart = Instance.new("Part")
	beamPart.Name = "LocalBeam"
	beamPart.Anchored = true
	beamPart.CanCollide = false
	beamPart.CanQuery = false
	beamPart.CanTouch = false
	beamPart.Transparency = 1
	beamPart.Size = Vector3.new(0.2, 0.2, 0.2)
	beamPart.Parent = camera

	beam = Instance.new("SpotLight")
	beam.Face = Enum.NormalId.Front
	beam.Angle = 52
	beam.Range = 60
	beam.Brightness = 2.6
	beam.Color = Color3.fromRGB(255, 244, 224)
	beam.Shadows = true
	beam.Enabled = false
	beam.Parent = beamPart
end

-- A hit to the view: used for the jumpscare and bad news.
function Effects.punch(amount)
	punch = math.max(punch, amount)
end

function Effects.deathBlur()
	blur.Size = 30
	TweenService:Create(blur, TweenInfo.new(4), { Size = 0 }):Play()
end

-- flashlightOn: is the beam lit. battery: 0..100.
function Effects.update(dt, dread, humanoid, flashlightOn, battery)
	camera = workspace.CurrentCamera
	smoothDread = smoothDread + (dread - smoothDread) * math.min(1, dt * 3)
	punch = math.max(0, punch - dt * 1.8)
	local d = smoothDread
	local now = os.clock()

	grade.Saturation = -0.75 * d
	grade.Contrast = 0.12 * d + punch * 0.3
	grade.TintColor = Color3.new(1, 1 - 0.14 * d - punch * 0.3, 1 - 0.14 * d - punch * 0.3)

	camera.FieldOfView = BASE_FOV - 9 * d - punch * 14

	if humanoid then
		local shake = d * d * 0.16 + punch * 0.6
		humanoid.CameraOffset = Vector3.new(
			(math.noise(now * 9, 0) * 2) * shake,
			(math.noise(0, now * 9) * 2) * shake,
			0
		)
	end

	-- Flashlight beam: follows the camera a beat late so it feels hand-held.
	local goal = camera.CFrame * CFrame.new(0.9, -0.7, 0.4)
	beamPart.CFrame = beamPart.CFrame:Lerp(goal, math.min(1, dt * 14))
	local lit = flashlightOn
	if lit and battery < 15 then
		lit = math.noise(now * 18) > -0.15 -- dying battery stutters
	end
	if lit and d > 0.75 then
		lit = math.noise(now * 30, 5) > -0.25 -- and it stutters when it is right there
	end
	beam.Enabled = lit
	beam.Brightness = 1.4 + 1.2 * math.clamp(battery / 40, 0, 1)

	-- Broken ceiling lights. They stutter faster as dread climbs.
	for _, tube in ipairs(CollectionService:GetTagged("FlickerLight")) do
		local nextAt = flicker[tube]
		if not nextAt or now >= nextAt then
			local lamp = tube:FindFirstChild("Lamp")
			if lamp then
				local on = math.random() > (0.3 + d * 0.4)
				lamp.Enabled = on
				tube.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
			end
			flicker[tube] = now + math.random() * (0.9 - d * 0.7) + 0.04
		end
	end
	for tube in pairs(flicker) do
		if not tube.Parent then
			flicker[tube] = nil
		end
	end
end

return Effects
