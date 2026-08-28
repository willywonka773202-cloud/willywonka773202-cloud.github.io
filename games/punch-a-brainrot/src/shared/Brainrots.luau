--!strict
-- The collectible catalog. Names are original to this project so nothing here
-- depends on another game's characters.
--
-- A brainrot's stats come from its rarity; `mult` is a per-character tweak that
-- lets two Rare brainrots feel different without breaking the rarity ladder.

local Rarities = require(script.Parent.Rarities)

export type Brainrot = {
	id: string,
	name: string,
	rarity: string,
	mult: number,    -- multiplies both income and lock HP
	torso: Color3,
	accent: Color3,
}

local Brainrots = {}

Brainrots.List = {
	-- Common
	{ id = "sock_gremlin",   name = "Sock Gremlin",      rarity = "common",    mult = 0.9, torso = Color3.fromRGB(196, 200, 208), accent = Color3.fromRGB(120, 128, 140) },
	{ id = "spoon_goblin",   name = "Spoon Goblin",      rarity = "common",    mult = 1.0, torso = Color3.fromRGB(178, 190, 200), accent = Color3.fromRGB(96, 110, 124) },
	{ id = "toast_lad",      name = "Toast Lad",         rarity = "common",    mult = 1.1, torso = Color3.fromRGB(214, 176, 118), accent = Color3.fromRGB(150, 112, 62) },
	-- Uncommon
	{ id = "mop_bandito",    name = "Mop Bandito",       rarity = "uncommon",  mult = 0.95, torso = Color3.fromRGB(120, 208, 148), accent = Color3.fromRGB(56, 132, 88) },
	{ id = "kettle_kid",     name = "Kettle Kid",        rarity = "uncommon",  mult = 1.05, torso = Color3.fromRGB(96, 196, 160), accent = Color3.fromRGB(40, 118, 96) },
	{ id = "noodle_nonno",   name = "Noodle Nonno",      rarity = "uncommon",  mult = 1.15, torso = Color3.fromRGB(150, 220, 130), accent = Color3.fromRGB(78, 140, 60) },
	-- Rare
	{ id = "fridge_pharaoh", name = "Fridge Pharaoh",    rarity = "rare",      mult = 0.95, torso = Color3.fromRGB(96, 168, 255), accent = Color3.fromRGB(38, 92, 168) },
	{ id = "blender_baron",  name = "Blender Baron",     rarity = "rare",      mult = 1.1,  torso = Color3.fromRGB(74, 150, 240), accent = Color3.fromRGB(28, 74, 140) },
	{ id = "static_signor",  name = "Static Signor",     rarity = "rare",      mult = 1.2,  torso = Color3.fromRGB(120, 190, 255), accent = Color3.fromRGB(46, 104, 176) },
	-- Epic
	{ id = "vault_vulture",  name = "Vault Vulture",     rarity = "epic",      mult = 1.0,  torso = Color3.fromRGB(176, 120, 255), accent = Color3.fromRGB(96, 52, 164) },
	{ id = "siren_sardina",  name = "Siren Sardina",     rarity = "epic",      mult = 1.15, torso = Color3.fromRGB(158, 96, 240), accent = Color3.fromRGB(82, 40, 148) },
	-- Legendary
	{ id = "obelisk_otto",   name = "Obelisk Otto",      rarity = "legendary", mult = 1.0,  torso = Color3.fromRGB(255, 186, 72), accent = Color3.fromRGB(180, 112, 24) },
	{ id = "magma_maestro",  name = "Magma Maestro",     rarity = "legendary", mult = 1.2,  torso = Color3.fromRGB(255, 148, 48), accent = Color3.fromRGB(172, 78, 16) },
	-- Mythic
	{ id = "chrono_capo",    name = "Chrono Capo",       rarity = "mythic",    mult = 1.0,  torso = Color3.fromRGB(255, 96, 128), accent = Color3.fromRGB(168, 34, 64) },
	{ id = "gravity_gaffer", name = "Gravity Gaffer",    rarity = "mythic",    mult = 1.25, torso = Color3.fromRGB(255, 72, 148), accent = Color3.fromRGB(160, 24, 82) },
	-- Brainrot God
	{ id = "sunfist_solaro", name = "Sunfist Solaro",    rarity = "god",       mult = 1.0,  torso = Color3.fromRGB(255, 240, 140), accent = Color3.fromRGB(206, 168, 40) },
	-- Secret
	{ id = "null_nonentity", name = "Null Nonentity",    rarity = "secret",    mult = 1.0,  torso = Color3.fromRGB(28, 28, 38), accent = Color3.fromRGB(120, 90, 255) },
} :: { Brainrot }

local byId: { [string]: Brainrot } = {}
local byRarity: { [string]: { Brainrot } } = {}

for _, brainrot in Brainrots.List do
	byId[brainrot.id] = brainrot
	local bucket = byRarity[brainrot.rarity]
	if not bucket then
		bucket = {}
		byRarity[brainrot.rarity] = bucket
	end
	table.insert(bucket, brainrot)
end

function Brainrots.get(id: string): Brainrot?
	return byId[id]
end

function Brainrots.ofRarity(rarityId: string): { Brainrot }
	return byRarity[rarityId] or {}
end

-- Income per second for one placed brainrot, before player-level multipliers.
function Brainrots.income(brainrot: Brainrot): number
	local rarity = Rarities.get(brainrot.rarity)
	if not rarity then
		return 0
	end
	return rarity.income * brainrot.mult
end

-- Total damage a thief must land on this brainrot's lock to rip it free.
function Brainrots.lockHP(brainrot: Brainrot): number
	local rarity = Rarities.get(brainrot.rarity)
	if not rarity then
		return math.huge
	end
	return rarity.lockHP * brainrot.mult
end

function Brainrots.price(brainrot: Brainrot): number
	local rarity = Rarities.get(brainrot.rarity)
	if not rarity then
		return math.huge
	end
	return math.floor(rarity.price * brainrot.mult)
end

-- Pick a random character within a rarity tier.
function Brainrots.pick(random: Random, rarityId: string): Brainrot?
	local bucket = byRarity[rarityId]
	if not bucket or #bucket == 0 then
		return nil
	end
	return bucket[random:NextInteger(1, #bucket)]
end

return Brainrots
