--[[
	RebirthService.lua
	Prestige loop. Reaching the requirement lets a player reset their stats
	and credits back to the starting 100 in exchange for a permanent
	multiplier on all future gains.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local StatService = require(script.Parent:WaitForChild("StatService"))

local RebirthService = {}

local function notify(player, kind, title, message)
	Remotes.Get("Notify"):FireClient(player, kind, title, message)
end

function RebirthService.GetRequirement(profile)
	return Constants.GetRebirthRequirement(profile.Rebirths or 0)
end

function RebirthService.CanRebirth(player)
	local profile = DataService.Get(player)
	if not profile then
		return false, "Your data is still loading."
	end
	local requirement = RebirthService.GetRequirement(profile)
	if (profile.MogScore or 0) < requirement then
		return false, ("Need %d Mog Score to rebirth (you have %d)."):format(requirement, profile.MogScore or 0)
	end
	return true
end

function RebirthService.Rebirth(player)
	local ok, reason = RebirthService.CanRebirth(player)
	if not ok then
		return false, reason
	end
	local profile = DataService.Get(player)

	for statName in pairs(Constants.STATS) do
		profile.Stats[statName] = 0
	end
	profile.Credits = Constants.STARTING_CREDITS
	profile.Rebirths = (profile.Rebirths or 0) + 1
	StatService.Recalculate(player)
	DataService.MarkDirty(player)
	DataService.Save(player)

	local multiplier = Constants.GetRebirthMultiplier(profile.Rebirths)
	notify(
		player,
		"success",
		("Rebirth %d"):format(profile.Rebirths),
		("Fresh start with %d Credits. Permanent x%.2f multiplier."):format(Constants.STARTING_CREDITS, multiplier)
	)
	return true
end

function RebirthService.Init()
	Remotes.Get("Rebirth").OnServerEvent:Connect(function(player)
		local AntiExploit = require(script.Parent:WaitForChild("AntiExploit"))
		if not AntiExploit.Allow(player, "Rebirth") then
			return
		end
		local ok, reason = RebirthService.Rebirth(player)
		if not ok then
			notify(player, "error", "Rebirth", reason)
		end
	end)
end

return RebirthService
