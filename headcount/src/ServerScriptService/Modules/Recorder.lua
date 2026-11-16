-- Records where every crew member has been, ten times a second.
-- The copy replays these recordings, which is why it moves like a real player.
local Recorder = {}
Recorder.__index = Recorder

function Recorder.new(windowSeconds)
	local self = setmetatable({}, Recorder)
	self.window = windowSeconds
	self.buffers = {}
	return self
end

function Recorder:sample(player, t, cf, light)
	local buf = self.buffers[player]
	if not buf then
		buf = {}
		self.buffers[player] = buf
	end
	buf[#buf + 1] = { t = t, cf = cf, light = light }
	while #buf > 2 and buf[1].t < t - self.window do
		table.remove(buf, 1)
	end
end

-- Seconds of history held for this player.
function Recorder:span(player)
	local buf = self.buffers[player]
	if not buf or #buf < 2 then
		return 0
	end
	return buf[#buf].t - buf[1].t
end

-- Where the player was at time t (interpolated), and whether their light was on.
function Recorder:get(player, t)
	local buf = self.buffers[player]
	if not buf or #buf == 0 then
		return nil, false
	end
	local n = #buf
	if t <= buf[1].t then
		return buf[1].cf, buf[1].light
	end
	if t >= buf[n].t then
		return buf[n].cf, buf[n].light
	end
	local lo, hi = 1, n
	while hi - lo > 1 do
		local mid = math.floor((lo + hi) / 2)
		if buf[mid].t <= t then
			lo = mid
		else
			hi = mid
		end
	end
	local a, b = buf[lo], buf[hi]
	local alpha = (t - a.t) / math.max(b.t - a.t, 0.0001)
	return a.cf:Lerp(b.cf, alpha), a.light
end

function Recorder:forget(player)
	self.buffers[player] = nil
end

return Recorder
