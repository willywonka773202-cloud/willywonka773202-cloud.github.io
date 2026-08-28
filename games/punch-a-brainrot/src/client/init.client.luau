--!strict
-- Client bootstrap: mount the HUD, bind input, render lock bars, then just
-- forward server pushes into the HUD.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Hud = require(script.Hud)
local PunchController = require(script.PunchController)
local LockBars = require(script.LockBars)

local hud = Hud.mount()

PunchController.start()
LockBars.start()

Remotes.get("StateChanged").OnClientEvent:Connect(function(snapshot)
	if type(snapshot) == "table" then
		hud.update(snapshot)
	end
end)

Remotes.get("ShopChanged").OnClientEvent:Connect(function(payload)
	if type(payload) == "table" then
		hud.updateShop(payload)
	end
end)

Remotes.get("PunchFeedback").OnClientEvent:Connect(function(payload)
	if type(payload) == "table" then
		hud.feedback(payload)
	end
end)

Remotes.get("Toast").OnClientEvent:Connect(function(message, kind)
	if type(message) == "string" then
		hud.toast(message, if type(kind) == "string" then kind else nil)
	end
end)
