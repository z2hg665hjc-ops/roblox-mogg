--[[
	DataService.lua
	Owns every player's saved profile. Loads on join, autosaves on a timer,
	saves on leave and on server shutdown. Every other service reads/writes
	through DataService.Get(player) and calls DataService.MarkDirty(player)
	after a change so the client gets a fresh snapshot.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Signal = require(Shared:WaitForChild("Signal"))

local DataService = {}

DataService.ProfileLoaded = Signal.new() -- fires (player, profile)

-- Other services can decorate the client snapshot: fn(player, snapshot).
DataService.SnapshotExtras = {}

function DataService.AddSnapshotExtra(fn)
	table.insert(DataService.SnapshotExtras, fn)
end

local store = nil
local profiles = {} -- [UserId] = profile
local loadedFlags = {} -- [UserId] = true once loaded

-- In Studio (where API access is often off) fail fast so Play mode is instant.
local SAVE_RETRIES = RunService:IsStudio() and 1 or 3

local function buildTemplate()
	local stats = {}
	for statName in pairs(Constants.STATS) do
		stats[statName] = 0
	end
	return {
		Version = 1,
		Credits = Constants.STARTING_CREDITS,
		WelcomeGranted = true,
		Stats = stats,
		MogScore = 0,
		Rebirths = 0,
		LifetimeCredits = Constants.STARTING_CREDITS,
		CreditChecks = 0,
		LastCreditCheck = 0,
		LastGymRep = 0,
		LastRating = 0,
		FirstJoin = os.time(),
		LastJoin = os.time(),
		PlayTime = 0,
		Wins = 0,
		Losses = 0,
		LastDailyDay = 0,
		DailyStreak = 0,
		Purchases = {},
		RobuxSpent = 0,
	}
end

-- Recursively fill in any keys missing from an older save so schema changes
-- never wipe a player.
local function reconcile(target, template)
	for key, value in pairs(template) do
		if target[key] == nil then
			if type(value) == "table" then
				target[key] = reconcile({}, value)
			else
				target[key] = value
			end
		elseif type(value) == "table" and type(target[key]) == "table" then
			reconcile(target[key], value)
		end
	end
	return target
end

local function getStore()
	if store then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Constants.DATASTORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[DataService] Could not get DataStore:", result)
	end
	return store
end

local function keyFor(userId)
	return "player_" .. tostring(userId)
end

function DataService.Get(player)
	if not player then
		return nil
	end
	return profiles[player.UserId]
end

function DataService.IsLoaded(player)
	return player ~= nil and loadedFlags[player.UserId] == true
end

-- Yields until the player's profile is loaded (or they leave).
function DataService.WaitFor(player, timeout)
	local deadline = os.clock() + (timeout or 15)
	while not DataService.IsLoaded(player) do
		if not player.Parent or os.clock() > deadline then
			return nil
		end
		task.wait(0.1)
	end
	return profiles[player.UserId]
end

function DataService.Snapshot(player)
	local profile = profiles[player.UserId]
	if not profile then
		return nil
	end
	local stats = {}
	for statName, level in pairs(profile.Stats) do
		stats[statName] = level
	end
	local snapshot = {
		Credits = profile.Credits,
		Stats = stats,
		MogScore = profile.MogScore,
		Rebirths = profile.Rebirths,
		LifetimeCredits = profile.LifetimeCredits,
		CreditChecks = profile.CreditChecks,
		LastCreditCheck = profile.LastCreditCheck,
		LastGymRep = profile.LastGymRep,
		LastRating = profile.LastRating,
		PlayTime = profile.PlayTime,
		Wins = profile.Wins or 0,
		Losses = profile.Losses or 0,
		DailyStreak = profile.DailyStreak or 0,
		ServerTime = os.time(),
	}
	for _, fn in ipairs(DataService.SnapshotExtras) do
		pcall(fn, player, snapshot)
	end
	return snapshot
end

-- Push a fresh snapshot to the client. Call after any mutation.
function DataService.MarkDirty(player)
	if not player or not player.Parent then
		return
	end
	local snapshot = DataService.Snapshot(player)
	if snapshot then
		Remotes.Get("DataUpdated"):FireClient(player, snapshot)
	end
end

local function load(player)
	local userId = player.UserId
	local template = buildTemplate()
	local data = nil

	local ds = getStore()
	if ds then
		for attempt = 1, SAVE_RETRIES do
			local ok, result = pcall(function()
				return ds:GetAsync(keyFor(userId))
			end)
			if ok then
				data = result
				break
			end
			warn(("[DataService] GetAsync failed for %d (attempt %d): %s"):format(userId, attempt, tostring(result)))
			if attempt < SAVE_RETRIES then
				task.wait(2 ^ attempt)
			end
		end
	end

	if type(data) ~= "table" then
		data = template
	else
		reconcile(data, template)
	end

	data.LastJoin = os.time()
	data._sessionStart = os.clock()

	-- Player may have left while we were loading.
	if not player.Parent then
		return
	end

	profiles[userId] = data
	loadedFlags[userId] = true
	DataService.ProfileLoaded:Fire(player, data)
	DataService.MarkDirty(player)
end

local function save(userId, profile)
	if not profile then
		return false
	end
	local ds = getStore()
	if not ds then
		return false
	end

	-- Bank session playtime into the saved total.
	if profile._sessionStart then
		profile.PlayTime = (profile.PlayTime or 0) + math.floor(os.clock() - profile._sessionStart)
		profile._sessionStart = os.clock()
	end

	-- Strip transient fields before writing.
	local toSave = {}
	for key, value in pairs(profile) do
		if type(key) == "string" and key:sub(1, 1) ~= "_" then
			toSave[key] = value
		end
	end

	for attempt = 1, SAVE_RETRIES do
		local ok, err = pcall(function()
			ds:UpdateAsync(keyFor(userId), function()
				return toSave
			end)
		end)
		if ok then
			return true
		end
		warn(("[DataService] Save failed for %d (attempt %d): %s"):format(userId, attempt, tostring(err)))
		if attempt < SAVE_RETRIES then
			task.wait(2 ^ attempt)
		end
	end
	return false
end

function DataService.Save(player)
	local profile = profiles[player.UserId]
	return save(player.UserId, profile)
end

local function onPlayerAdded(player)
	task.spawn(load, player)
end

local function onPlayerRemoving(player)
	local userId = player.UserId
	local profile = profiles[userId]
	if profile then
		save(userId, profile)
	end
	profiles[userId] = nil
	loadedFlags[userId] = nil
end

function DataService.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end

	-- Client can explicitly ask for a snapshot (e.g. after its UI finishes building).
	Remotes.Get("RequestData").OnServerEvent:Connect(function(player)
		if DataService.IsLoaded(player) then
			DataService.MarkDirty(player)
		end
	end)

	-- Autosave loop.
	task.spawn(function()
		while true do
			task.wait(Constants.AUTOSAVE_INTERVAL)
			for userId, profile in pairs(profiles) do
				task.spawn(save, userId, profile)
			end
		end
	end)

	-- Flush everyone when the server shuts down.
	game:BindToClose(function()
		local pending = 0
		for userId, profile in pairs(profiles) do
			pending += 1
			task.spawn(function()
				save(userId, profile)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
