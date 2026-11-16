-- Saves credits, upgrades and best night. Saving only works in a published
-- game, or in Studio with "Enable Studio Access to API Services" switched on.
-- If saving is unavailable the game still runs; progress just is not kept.
local DataStoreService = game:GetService("DataStoreService")

local PlayerData = {}

local DEFAULTS = { Credits = 0, BestNight = 0, UpBattery = 0, UpStamina = 0, UpScanner = 0 }
local FIELDS = { "Credits", "BestNight", "UpBattery", "UpStamina", "UpScanner" }

local store = nil
pcall(function()
	store = DataStoreService:GetDataStore("HeadcountV1")
end)

function PlayerData.load(player)
	local data = nil
	if store then
		pcall(function()
			data = store:GetAsync("p_" .. player.UserId)
		end)
	end
	if type(data) ~= "table" then
		data = {}
	end
	for _, field in ipairs(FIELDS) do
		local value = data[field]
		if type(value) ~= "number" then
			value = DEFAULTS[field]
		end
		player:SetAttribute(field, value)
	end
	player:SetAttribute("DataLoaded", true)
end

function PlayerData.save(player)
	if not store or not player:GetAttribute("DataLoaded") then
		return
	end
	local data = {}
	for _, field in ipairs(FIELDS) do
		data[field] = player:GetAttribute(field) or DEFAULTS[field]
	end
	pcall(function()
		store:SetAsync("p_" .. player.UserId, data)
	end)
end

return PlayerData
