--!strict
-- Rank is the Punch Sim half of the fusion: a strength ladder that visibly
-- gates which rarity of lock you can realistically break. `breaks` is the
-- highest rarity this rank can crack at a sane pace, and is what the HUD
-- advertises as the reward for the next rank.

export type Rank = {
	order: number,
	name: string,
	strength: number,   -- strength required to hold this rank
	damageMult: number,
	breaks: string,     -- rarity id this rank can comfortably steal
}

local Ranks = {}

Ranks.List = {
	{ order = 1, name = "Noodle Arms",      strength = 0,         damageMult = 1.00, breaks = "common" },
	{ order = 2, name = "Gym Rat",          strength = 500,       damageMult = 1.15, breaks = "uncommon" },
	{ order = 3, name = "Bruiser",          strength = 5000,      damageMult = 1.35, breaks = "rare" },
	{ order = 4, name = "Slugger",          strength = 40000,     damageMult = 1.60, breaks = "rare" },
	{ order = 5, name = "Ironfist",         strength = 250000,    damageMult = 2.00, breaks = "epic" },
	{ order = 6, name = "Titan",            strength = 1500000,   damageMult = 2.50, breaks = "legendary" },
	{ order = 7, name = "Brainrot Breaker", strength = 10000000,  damageMult = 3.20, breaks = "mythic" },
	{ order = 8, name = "Mythic Knuckle",   strength = 60000000,  damageMult = 4.00, breaks = "god" },
	{ order = 9, name = "Godhand",          strength = 400000000, damageMult = 5.00, breaks = "secret" },
} :: { Rank }

-- Highest rank whose strength requirement the player meets.
function Ranks.forStrength(strength: number): Rank
	local current = Ranks.List[1]
	for _, rank in Ranks.List do
		if strength >= rank.strength then
			current = rank
		else
			break
		end
	end
	return current
end

function Ranks.next(rank: Rank): Rank?
	return Ranks.List[rank.order + 1]
end

-- 0..1 progress toward the next rank; 1 when already at the cap.
function Ranks.progress(strength: number): number
	local current = Ranks.forStrength(strength)
	local nextRank = Ranks.next(current)
	if not nextRank then
		return 1
	end

	local span = nextRank.strength - current.strength
	if span <= 0 then
		return 1
	end
	return math.clamp((strength - current.strength) / span, 0, 1)
end

return Ranks
