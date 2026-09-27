--[[
	ClientState.lua
	Read-only mirror of the server's snapshot for this player, plus the latest
	leaderboard. UI subscribes to Changed / LeaderboardChanged.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Signal = require(Shared:WaitForChild("Signal"))

local ClientState = {}

ClientState.Data = nil
ClientState.Leaderboard = {}
ClientState.Changed = Signal.new()
ClientState.LeaderboardChanged = Signal.new()

-- Offset between server os.time() and local os.time(), for cooldown display.
local serverOffset = 0

function ClientState.Get()
	return ClientState.Data
end

function ClientState.ServerNow()
	return os.time() + serverOffset
end

function ClientState.Rank()
	local data = ClientState.Data
	return Constants.GetRank(data and data.MogScore or 0)
end

function ClientState.NextRank()
	local score = ClientState.Data and ClientState.Data.MogScore or 0
	for _, rank in ipairs(Constants.RANKS) do
		if rank.MinScore > score then
			return rank
		end
	end
	return nil
end

function ClientState.Multiplier()
	local data = ClientState.Data
	return Constants.GetRebirthMultiplier(data and data.Rebirths or 0)
end

-- Seconds remaining on a cooldown, given the profile timestamp field and duration.
function ClientState.CooldownRemaining(field, duration)
	local data = ClientState.Data
	if not data then
		return 0
	end
	local last = tonumber(data[field]) or 0
	return math.max(0, (last + duration) - ClientState.ServerNow())
end

function ClientState.Init()
	Remotes.Get("DataUpdated").OnClientEvent:Connect(function(snapshot)
		if type(snapshot) ~= "table" then
			return
		end
		if snapshot.ServerTime then
			serverOffset = snapshot.ServerTime - os.time()
		end
		ClientState.Data = snapshot
		ClientState.Changed:Fire(snapshot)
	end)

	Remotes.Get("LeaderboardUpdate").OnClientEvent:Connect(function(entries)
		ClientState.Leaderboard = type(entries) == "table" and entries or {}
		ClientState.LeaderboardChanged:Fire(ClientState.Leaderboard)
	end)

	Remotes.Get("RequestData"):FireServer()
end

return ClientState
