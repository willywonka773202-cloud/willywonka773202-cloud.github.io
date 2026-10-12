--!strict
-- Number formatting shared by every UI surface, so the HUD, the shop and the
-- billboards never disagree about how a value should read.

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- 15400 -> "15.4K". Values below 1000 keep whole-number precision.
function Format.short(value: number): string
	if value < 0 then
		return "-" .. Format.short(-value)
	end
	if value < 1000 then
		return string.format("%d", math.floor(value))
	end

	local tier = math.floor(math.log(value, 1000))
	tier = math.clamp(tier, 1, #SUFFIXES - 1)

	local scaled = value / (1000 ^ tier)
	local suffix = SUFFIXES[tier + 1]

	if scaled >= 100 then
		return string.format("%.0f%s", scaled, suffix)
	elseif scaled >= 10 then
		return string.format("%.1f%s", scaled, suffix)
	end
	return string.format("%.2f%s", scaled, suffix)
end

-- "$15.4K/s"
function Format.rate(value: number): string
	return "$" .. Format.short(value) .. "/s"
end

function Format.cash(value: number): string
	return "$" .. Format.short(value)
end

-- 95 -> "1:35"
function Format.clock(seconds: number): string
	local whole = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

return Format
