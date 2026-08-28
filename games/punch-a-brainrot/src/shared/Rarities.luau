--!strict
-- Rarity is the spine of the whole design: it sets what a brainrot earns AND
-- how much lock HP a thief has to punch through to take it. Income and lock HP
-- climb together, so "can I steal this?" is always a pure strength question.

export type Rarity = {
	id: string,
	name: string,
	order: number,
	income: number,      -- cash per second while placed on a pad
	lockHP: number,      -- damage required to rip it off a rival's pad
	price: number,       -- shop cost
	weight: number,      -- relative shop roll weight
	color: Color3,
}

local Rarities = {}

Rarities.List = {
	{ id = "common",    name = "Common",        order = 1, income = 5,     lockHP = 150,      price = 250,      weight = 45,   color = Color3.fromRGB(170, 178, 189) },
	{ id = "uncommon",  name = "Uncommon",      order = 2, income = 18,    lockHP = 600,      price = 1200,     weight = 25,   color = Color3.fromRGB(88, 204, 122) },
	{ id = "rare",      name = "Rare",          order = 3, income = 65,    lockHP = 2400,     price = 6000,     weight = 15,   color = Color3.fromRGB(74, 158, 255) },
	{ id = "epic",      name = "Epic",          order = 4, income = 240,   lockHP = 9500,     price = 32000,    weight = 8,    color = Color3.fromRGB(168, 106, 255) },
	{ id = "legendary", name = "Legendary",     order = 5, income = 900,   lockHP = 38000,    price = 180000,   weight = 4.5,  color = Color3.fromRGB(255, 176, 46) },
	{ id = "mythic",    name = "Mythic",        order = 6, income = 3400,  lockHP = 150000,   price = 1000000,  weight = 2,    color = Color3.fromRGB(255, 78, 110) },
	{ id = "god",       name = "Brainrot God",  order = 7, income = 13000, lockHP = 600000,   price = 6000000,  weight = 0.45, color = Color3.fromRGB(255, 238, 120) },
	{ id = "secret",    name = "Secret",        order = 8, income = 50000, lockHP = 2500000,  price = 40000000, weight = 0.05, color = Color3.fromRGB(24, 24, 32) },
} :: { Rarity }

local byId: { [string]: Rarity } = {}
for _, rarity in Rarities.List do
	byId[rarity.id] = rarity
end

function Rarities.get(id: string): Rarity?
	return byId[id]
end

-- Weighted roll, optionally floored at a minimum tier so late-game shops stop
-- offering commons.
function Rarities.roll(random: Random, minOrder: number?): Rarity
	local floorOrder = minOrder or 1

	local total = 0
	for _, rarity in Rarities.List do
		if rarity.order >= floorOrder then
			total += rarity.weight
		end
	end

	local target = random:NextNumber() * total
	for _, rarity in Rarities.List do
		if rarity.order >= floorOrder then
			target -= rarity.weight
			if target <= 0 then
				return rarity
			end
		end
	end

	return Rarities.List[1]
end

return Rarities
