--[[
	StatService.lua
	Stat upgrades and MogScore calculation. MogScore is always derived from
	saved stat levels, never stored independently as the source of truth.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Signal = require(Shared:WaitForChild("Signal"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local CreditService = require(script.Parent:WaitForChild("CreditService"))

local StatService = {}

StatService.ScoreChanged = Signal.new() -- fires (player, newScore)

local function notify(player, kind, title, message)
	Remotes.Get("Notify"):FireClient(player, kind, title, message)
end

function StatService.ComputeScore(profile)
	local score = 0
	for statName, def in pairs(Constants.STATS) do
		local level = tonumber(profile.Stats[statName]) or 0
		score += level * def.ScorePerLevel
	end
	return math.floor(score * Constants.GetRebirthMultiplier(profile.Rebirths or 0))
end

function StatService.Recalculate(player)
	local profile = DataService.Get(player)
	if not profile then
		return 0
	end
	local newScore = StatService.ComputeScore(profile)
	if newScore ~= profile.MogScore then
		profile.MogScore = newScore
		StatService.ScoreChanged:Fire(player, newScore)
	end
	return newScore
end

-- Buys `count` levels (default 1). Stops early if credits run out.
-- Returns bought (number), or 0 + reason.
function StatService.BuyStat(player, statName, count)
	local profile = DataService.Get(player)
	if not profile then
		return 0, "Your data is still loading."
	end
	local def = Constants.STATS[statName]
	if not def then
		return 0, "Unknown stat."
	end
	count = math.clamp(math.floor(tonumber(count) or 1), 1, 50)

	local startLevel = tonumber(profile.Stats[statName]) or 0
	local level = startLevel
	local bought = 0
	local failReason = nil

	for _ = 1, count do
		if level >= def.MaxLevel then
			failReason = def.DisplayName .. " is already maxed."
			break
		end
		local cost = Constants.GetStatCost(statName, level)
		if not CreditService.Spend(player, cost) then
			failReason = ("Need %d Credits for %s."):format(cost, def.DisplayName)
			break
		end
		level += 1
		bought += 1
	end

	if bought == 0 then
		return 0, failReason
	end

	profile.Stats[statName] = level
	local rankBefore = Constants.GetRank(StatService.ComputeScoreAtLevel(profile, statName, startLevel))
	StatService.Recalculate(player)
	DataService.MarkDirty(player)

	local rankAfter = Constants.GetRank(profile.MogScore)
	if rankBefore.Name ~= rankAfter.Name then
		notify(player, "success", "Rank Up!", "You are now " .. rankAfter.Name .. ".")
	end
	return bought
end

-- Helper: what would MogScore be if `statName` were at `level`? Used to detect rank ups.
function StatService.ComputeScoreAtLevel(profile, statName, level)
	local score = 0
	for name, def in pairs(Constants.STATS) do
		local lvl = (name == statName) and level or (tonumber(profile.Stats[name]) or 0)
		score += lvl * def.ScorePerLevel
	end
	return math.floor(score * Constants.GetRebirthMultiplier(profile.Rebirths or 0))
end

function StatService.Init()
	Remotes.Get("BuyStat").OnServerEvent:Connect(function(player, statName, count)
		local AntiExploit = require(script.Parent:WaitForChild("AntiExploit"))
		if not AntiExploit.Allow(player, "BuyStat") then
			return
		end
		if type(statName) ~= "string" then
			return
		end
		local bought, reason = StatService.BuyStat(player, statName, count)
		if bought == 0 then
			notify(player, "error", "Shop", reason)
		end
	end)

	-- Make sure MogScore is correct the moment data loads.
	DataService.ProfileLoaded:Connect(function(player)
		StatService.Recalculate(player)
		DataService.MarkDirty(player)
	end)
end

return StatService
