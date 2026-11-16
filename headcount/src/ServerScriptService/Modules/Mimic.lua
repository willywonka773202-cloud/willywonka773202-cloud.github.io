-- The copy. It wears one crew member's avatar and name, and walks the exact
-- path that crew member walked a few seconds ago.
--
--   echo  : trails its target by `lag` seconds and stops just behind them.
--   hunt  : its target has been alone too long, so it replays the path faster
--           than the target walked it, and the gap closes.
--   A lit flashlight pointed at it freezes it. It makes no footsteps.
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Mimic = {}
Mimic.__index = Mimic

local FALLBACK_RUN = "rbxassetid://507767714"
local FALLBACK_IDLE = "rbxassetid://507766388"

local function findAnimation(model, group, fallback)
	local animate = model:FindFirstChild("Animate")
	if animate then
		local folder = animate:FindFirstChild(group)
		if folder then
			local anim = folder:FindFirstChildOfClass("Animation")
			if anim and anim.AnimationId ~= "" then
				return anim.AnimationId
			end
		end
	end
	return fallback
end

-- ctx = { recorder, folder, charOf(player), isIsolated(player), isWatched(position), onKill(mimic, player), attachPrompt(model, mimic) }
function Mimic.new(ctx, target, night)
	local cfg = Config.Mimic
	local self = setmetatable({}, Mimic)
	self.ctx = ctx
	self.target = target
	self.baseLag = math.max(cfg.MinLag, cfg.BaseLag - (night - 1) * cfg.LagPerNight)
	self.lag = self.baseLag
	self.rate = math.min(cfg.MaxHuntRate, cfg.HuntRate + (night - 1) * cfg.HuntRatePerNight)
	self.state = "echo"
	self.isolatedFor = 0
	self.alive = false
	self.moving = false
	return self
end

function Mimic:spawn(now)
	local ctx = self.ctx
	local character = self.target.Character
	if not character or ctx.recorder:span(self.target) < self.lag then
		return false
	end
	local startCf = ctx.recorder:get(self.target, now - self.lag)
	if not startCf then
		return false
	end

	character.Archivable = true
	local ok, clone = pcall(function()
		return character:Clone()
	end)
	character.Archivable = false
	if not ok or not clone then
		return false
	end

	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	local root = clone:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		clone:Destroy()
		return false
	end

	local runId = findAnimation(clone, "run", FALLBACK_RUN)
	local idleId = findAnimation(clone, "idle", FALLBACK_IDLE)

	for _, inst in ipairs(clone:GetDescendants()) do
		if inst:IsA("LuaSourceContainer") or inst:IsA("ProximityPrompt") or inst:IsA("ForceField") then
			inst:Destroy()
		elseif inst:IsA("BasePart") then
			inst.CanCollide = false
			inst.CanTouch = false
			inst.Anchored = false
		end
	end

	clone.Name = self.target.Name
	humanoid.DisplayName = self.target.DisplayName
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.BreakJointsOnDeath = false
	pcall(function()
		humanoid.EvaluateStateMachine = false
	end)

	-- Physics constraints (not anchoring) so other players see smooth motion.
	local attachment = Instance.new("Attachment")
	attachment.Name = "Drive"
	attachment.Parent = root

	local alignPosition = Instance.new("AlignPosition")
	alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
	alignPosition.Attachment0 = attachment
	alignPosition.MaxForce = 1e7
	alignPosition.MaxVelocity = 300
	alignPosition.Responsiveness = 90
	alignPosition.Position = startCf.Position
	alignPosition.Parent = root

	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.Attachment0 = attachment
	alignOrientation.MaxTorque = 1e7
	alignOrientation.Responsiveness = 90
	alignOrientation.CFrame = startCf
	alignOrientation.Parent = root

	root.CFrame = startCf
	clone.Parent = ctx.folder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local runAnim = Instance.new("Animation")
	runAnim.AnimationId = runId
	local idleAnim = Instance.new("Animation")
	idleAnim.AnimationId = idleId
	local okTracks = pcall(function()
		self.runTrack = animator:LoadAnimation(runAnim)
		self.idleTrack = animator:LoadAnimation(idleAnim)
		self.runTrack.Looped = true
		self.idleTrack.Looped = true
		self.idleTrack:Play(0.2)
	end)
	if not okTracks then
		self.runTrack = nil
		self.idleTrack = nil
	end

	local head = clone:FindFirstChild("Head")
	self.light = head and head:FindFirstChild("CrewLight") or nil
	self.model = clone
	self.root = root
	self.alignPosition = alignPosition
	self.alignOrientation = alignOrientation
	self.lastPosition = startCf.Position
	self.alive = true

	ctx.attachPrompt(clone, self)
	return true
end

function Mimic:setMoving(moving, speed)
	if not self.runTrack or not self.idleTrack then
		return
	end
	if moving ~= self.moving then
		self.moving = moving
		if moving then
			self.idleTrack:Stop(0.2)
			self.runTrack:Play(0.2)
		else
			self.runTrack:Stop(0.2)
			self.idleTrack:Play(0.2)
		end
	end
	if moving then
		self.runTrack:AdjustSpeed(math.clamp(speed / 16, 0.5, 2))
	end
end

function Mimic:step(dt, now)
	if not self.alive then
		return
	end
	local cfg = Config.Mimic
	local ctx = self.ctx
	local target = self.target
	local _, _, targetRoot = ctx.charOf(target)
	if not targetRoot or not target:GetAttribute("Alive") then
		self:destroy()
		return
	end

	local position = self.root.Position
	local distance = (targetRoot.Position - position).Magnitude
	local watched = ctx.isWatched(position)

	if ctx.isIsolated(target) then
		self.isolatedFor = self.isolatedFor + dt
	else
		self.isolatedFor = 0
	end
	local hunting = self.isolatedFor > cfg.IsolateGrace
	self.state = hunting and "hunt" or "echo"

	-- How many seconds of the recording to play this frame.
	local advance
	if watched then
		advance = 0
	elseif hunting then
		advance = dt * self.rate
	elseif distance < cfg.HoverDistance then
		advance = 0
	elseif self.lag < self.baseLag then
		advance = dt * 0.5
	else
		advance = dt
	end
	self.lag = math.clamp(self.lag + dt - advance, 0, ctx.recorder.window - 5)

	local cf, lightOn = ctx.recorder:get(target, now - self.lag)
	if cf then
		self.alignPosition.Position = cf.Position
		self.alignOrientation.CFrame = cf
		local speed = (cf.Position - self.lastPosition).Magnitude / math.max(dt, 0.001)
		self.lastPosition = cf.Position
		self:setMoving(speed > 1.5, speed)
		if self.light then
			self.light.Enabled = lightOn
		end
	end

	if hunting and not watched and distance < cfg.KillDistance then
		ctx.onKill(self, target)
	end
end

-- Pull every copy closer (the penalty for a wrong accusation).
function Mimic:closeIn(seconds)
	self.lag = math.max(0, self.lag - seconds)
end

function Mimic:banish()
	if not self.alive then
		return
	end
	self.alive = false
	local model = self.model
	self.model = nil
	if not model then
		return
	end
	for _, inst in ipairs(model:GetDescendants()) do
		if inst:IsA("BasePart") or inst:IsA("Decal") then
			TweenService:Create(inst, TweenInfo.new(0.7), { Transparency = 1 }):Play()
		elseif inst:IsA("ProximityPrompt") or inst:IsA("Light") then
			inst:Destroy()
		end
	end
	task.delay(0.8, function()
		model:Destroy()
	end)
end

function Mimic:destroy()
	self.alive = false
	if self.model then
		self.model:Destroy()
		self.model = nil
	end
end

return Mimic
