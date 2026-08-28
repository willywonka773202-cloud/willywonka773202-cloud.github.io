--!strict
-- Remote plumbing. The server calls `Remotes.build()` once at boot; clients
-- call `Remotes.get(name)` and block until the folder exists.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "PABRemotes"

-- Client -> server requests.
local EVENTS = {
	"Punch",          -- (targetType: string, targetId: string)
	"BuyBrainrot",    -- (slotIndex: number)
	"PlaceCarried",   -- (padIndex: number)
	"SellBrainrot",   -- (padIndex: number)
	"BuyPad",
	"BuyTraining",
	"Rebirth",
	"DropCarried",
}

-- Server -> client pushes.
local PUSHES = {
	"StateChanged",   -- (state: table) full player state snapshot
	"ShopChanged",    -- (slots: table)
	"PunchFeedback",  -- (info: table) damage numbers, hit kind
	"Toast",          -- (message: string, kind: string)
}

local Remotes = {}

function Remotes.build(): Folder
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME

	for _, name in EVENTS do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	for _, name in PUSHES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end

	folder.Parent = ReplicatedStorage
	return folder
end

function Remotes.get(name: string): RemoteEvent
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		if RunService:IsServer() then
			folder = Remotes.build()
		else
			folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, 30)
		end
	end
	assert(folder, "PABRemotes folder never replicated")

	local remote = folder:WaitForChild(name, 30)
	assert(remote and remote:IsA("RemoteEvent"), `remote "{name}" is missing`)
	return remote
end

return Remotes
