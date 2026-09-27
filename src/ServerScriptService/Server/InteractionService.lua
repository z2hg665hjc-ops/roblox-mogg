--[[
	InteractionService.lua
	Wires the ProximityPrompts that MapBuilder creates to gameplay. Parts are
	found by CollectionService tag so the map can be rearranged freely.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local AntiExploit = require(script.Parent:WaitForChild("AntiExploit"))
local CreditService = require(script.Parent:WaitForChild("CreditService"))

local InteractionService = {}

local function notify(player, kind, title, message)
	Remotes.Get("Notify"):FireClient(player, kind, title, message)
end

local function promptOf(part)
	return part:FindFirstChildOfClass("ProximityPrompt")
end

local function bind(tag, handler)
	local function hook(part)
		local prompt = promptOf(part)
		if not prompt then
			return
		end
		prompt.Triggered:Connect(function(player)
			handler(player, part)
		end)
	end
	for _, part in ipairs(CollectionService:GetTagged(tag)) do
		hook(part)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(hook)
end

function InteractionService.Init()
	bind("GymBar", function(player)
		if not AntiExploit.Allow(player, "GymRep") then
			return
		end
		local payout, reason = CreditService.GymRep(player)
		if not payout then
			notify(player, "error", "Gym", reason)
		end
	end)

	bind("RatingMirror", function(player)
		if not AntiExploit.Allow(player, "RateSelf") then
			return
		end
		local payout, reason = CreditService.RateSelf(player)
		if not payout then
			notify(player, "error", "Mirror", reason)
		end
	end)

	bind("CreditCheckKiosk", function(player)
		if not AntiExploit.Allow(player, "CreditCheck") then
			return
		end
		local payout, reason = CreditService.CreditCheck(player)
		if not payout then
			notify(player, "error", "Credit Check", reason)
		end
	end)

	bind("ShopStall", function(player, part)
		local statName = part:GetAttribute("StatName")
		Remotes.Get("OpenPanel"):FireClient(player, "Shop", statName)
	end)

	bind("RebirthAltar", function(player)
		Remotes.Get("OpenPanel"):FireClient(player, "Rebirth")
	end)

	bind("LeaderboardBoard", function(player)
		Remotes.Get("OpenPanel"):FireClient(player, "Leaderboard")
	end)
end

return InteractionService
