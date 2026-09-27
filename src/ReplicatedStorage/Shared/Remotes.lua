--[[
	Remotes.lua
	Single place that defines every RemoteEvent/RemoteFunction the game uses.
	The server creates them on boot; the client just waits for them.
	Require this from both sides and call Remotes.Get("Name").
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENT_NAMES = {
	"BuyStat", -- client -> server: {statName, count}
	"Rebirth", -- client -> server: {}
	"CreditCheck", -- client -> server: {}
	"GymRep", -- client -> server: {}
	"RateSelf", -- client -> server: {}
	"RequestData", -- client -> server: {} (ask for a fresh full snapshot)
	"DataUpdated", -- server -> client: {profileSnapshot}
	"Notify", -- server -> client: {kind, title, message}
	"LeaderboardUpdate", -- server -> client: {entries}
	"OpenPanel", -- server -> client: {panelName, arg}
}

local Remotes = {}
local folder = nil
local cache = {}

local function ensureFolder()
	if folder then
		return folder
	end
	if RunService:IsServer() then
		folder = ReplicatedStorage:FindFirstChild("Remotes")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "Remotes"
			folder.Parent = ReplicatedStorage
		end
		for _, name in ipairs(EVENT_NAMES) do
			if not folder:FindFirstChild(name) then
				local remote = Instance.new("RemoteEvent")
				remote.Name = name
				remote.Parent = folder
			end
		end
	else
		folder = ReplicatedStorage:WaitForChild("Remotes", 30)
	end
	return folder
end

function Remotes.Get(name)
	if cache[name] then
		return cache[name]
	end
	local f = ensureFolder()
	if not f then
		error("[Remotes] Remotes folder never appeared (name=" .. tostring(name) .. ")")
	end
	local remote = f:FindFirstChild(name)
	if not remote and not RunService:IsServer() then
		remote = f:WaitForChild(name, 30)
	end
	if not remote then
		error("[Remotes] Unknown remote: " .. tostring(name))
	end
	cache[name] = remote
	return remote
end

-- Pre-create everything immediately when required on the server.
if RunService:IsServer() then
	ensureFolder()
end

return Remotes
