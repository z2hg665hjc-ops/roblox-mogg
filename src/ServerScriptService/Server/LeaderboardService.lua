--[[
	LeaderboardService.lua
	Global top-10 by MogScore using an OrderedDataStore. Broadcasts to every
	client and paints the physical board in the hub.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local StatService = require(script.Parent:WaitForChild("StatService"))

local LeaderboardService = {}

local REFRESH_INTERVAL = 60
local WRITE_THROTTLE = 30 -- seconds between writes per player
local TOP_N = 10

local orderedStore = nil
local lastWrite = {} -- [UserId] = os.clock()
local pendingWrite = {} -- [UserId] = true
local nameCache = {} -- [UserId] = displayName
local latestEntries = {}

local function getStore()
	if orderedStore then
		return orderedStore
	end
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(Constants.LEADERBOARD_STORE_NAME)
	end)
	if ok then
		orderedStore = result
	else
		warn("[Leaderboard] Could not get OrderedDataStore:", result)
	end
	return orderedStore
end

local function nameFor(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end
	local online = Players:GetPlayerByUserId(userId)
	if online then
		nameCache[userId] = online.DisplayName
		return online.DisplayName
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = ok and name or ("User" .. tostring(userId))
	return nameCache[userId]
end

local function writeScore(userId, score)
	local ds = getStore()
	if not ds then
		return
	end
	local ok, err = pcall(function()
		ds:SetAsync(tostring(userId), math.max(0, math.floor(score)))
	end)
	if not ok then
		warn("[Leaderboard] SetAsync failed:", err)
	end
	lastWrite[userId] = os.clock()
end

function LeaderboardService.QueueUpdate(player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local userId = player.UserId
	local since = os.clock() - (lastWrite[userId] or 0)
	if since >= WRITE_THROTTLE then
		task.spawn(writeScore, userId, profile.MogScore or 0)
	else
		pendingWrite[userId] = true
	end
end

local function flushPending()
	for userId in pairs(pendingWrite) do
		local player = Players:GetPlayerByUserId(userId)
		local profile = player and DataService.Get(player)
		if profile then
			if os.clock() - (lastWrite[userId] or 0) >= WRITE_THROTTLE then
				pendingWrite[userId] = nil
				task.spawn(writeScore, userId, profile.MogScore or 0)
			end
		else
			pendingWrite[userId] = nil
		end
	end
end

function LeaderboardService.FetchTop()
	local ds = getStore()
	if not ds then
		return latestEntries
	end
	local ok, pages = pcall(function()
		return ds:GetSortedAsync(false, TOP_N)
	end)
	if not ok then
		warn("[Leaderboard] GetSortedAsync failed:", pages)
		return latestEntries
	end
	local page = pages:GetCurrentPage()
	local entries = {}
	for rank, item in ipairs(page) do
		local userId = tonumber(item.key)
		entries[#entries + 1] = {
			Rank = rank,
			UserId = userId,
			Name = nameFor(userId),
			Score = item.value,
		}
	end
	latestEntries = entries
	return entries
end

local function paintBoard(entries)
	local hub = Workspace:FindFirstChild("Hub")
	local board = hub and hub:FindFirstChild("LeaderboardBoard", true)
	local gui = board and board:FindFirstChildOfClass("SurfaceGui")
	local list = gui and gui:FindFirstChild("Entries")
	if not list then
		return
	end
	for i = 1, TOP_N do
		local row = list:FindFirstChild("Row" .. i)
		if row then
			local entry = entries[i]
			local nameLabel = row:FindFirstChild("Name")
			local scoreLabel = row:FindFirstChild("Score")
			if entry then
				local rank = Constants.GetRank(entry.Score)
				if nameLabel then
					nameLabel.Text = ("%d.  %s"):format(i, entry.Name)
					nameLabel.TextColor3 = Color3.fromRGB(rank.Color[1], rank.Color[2], rank.Color[3])
				end
				if scoreLabel then
					scoreLabel.Text = tostring(entry.Score)
				end
			else
				if nameLabel then
					nameLabel.Text = ("%d.  ---"):format(i)
					nameLabel.TextColor3 = Color3.fromRGB(120, 120, 140)
				end
				if scoreLabel then
					scoreLabel.Text = ""
				end
			end
		end
	end
end

function LeaderboardService.Refresh()
	local entries = LeaderboardService.FetchTop()
	Remotes.Get("LeaderboardUpdate"):FireAllClients(entries)
	paintBoard(entries)
end

function LeaderboardService.Init()
	StatService.ScoreChanged:Connect(function(player)
		LeaderboardService.QueueUpdate(player)
	end)

	DataService.ProfileLoaded:Connect(function(player)
		LeaderboardService.QueueUpdate(player)
		-- New client wants the current board immediately.
		task.delay(1, function()
			if player.Parent then
				Remotes.Get("LeaderboardUpdate"):FireClient(player, latestEntries)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local profile = DataService.Get(player)
		if profile then
			writeScore(player.UserId, profile.MogScore or 0)
		end
		pendingWrite[player.UserId] = nil
		lastWrite[player.UserId] = nil
	end)

	task.spawn(function()
		task.wait(3)
		LeaderboardService.Refresh()
		while true do
			task.wait(REFRESH_INTERVAL)
			flushPending()
			LeaderboardService.Refresh()
		end
	end)
end

return LeaderboardService
