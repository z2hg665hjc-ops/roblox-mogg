--[[
	CreditService.lua
	The only module allowed to change a player's Credits. Everything is
	server-authoritative; the client never tells the server how many credits
	it has, only which action it wants to take.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local DataService = require(script.Parent:WaitForChild("DataService"))

local CreditService = {}

local MAX_CREDITS = 1e15

local function notify(player, kind, title, message)
	Remotes.Get("Notify"):FireClient(player, kind, title, message)
end

function CreditService.GetMultiplier(profile)
	return Constants.GetRebirthMultiplier(profile.Rebirths or 0)
end

-- Adds raw credits after applying the player's rebirth multiplier.
-- Returns the actual amount added.
function CreditService.Add(player, amount, reason)
	local profile = DataService.Get(player)
	if not profile or type(amount) ~= "number" or amount <= 0 then
		return 0
	end
	local final = math.floor(amount * CreditService.GetMultiplier(profile))
	if final <= 0 then
		final = 1
	end
	profile.Credits = math.clamp(profile.Credits + final, 0, MAX_CREDITS)
	profile.LifetimeCredits = math.clamp((profile.LifetimeCredits or 0) + final, 0, MAX_CREDITS)
	DataService.MarkDirty(player)
	return final, reason
end

-- Spends credits only if the player can afford it. Returns true on success.
function CreditService.Spend(player, amount)
	local profile = DataService.Get(player)
	if not profile or type(amount) ~= "number" or amount < 0 then
		return false
	end
	if profile.Credits < amount then
		return false
	end
	profile.Credits -= amount
	DataService.MarkDirty(player)
	return true
end

function CreditService.CanAfford(player, amount)
	local profile = DataService.Get(player)
	return profile ~= nil and profile.Credits >= amount
end

-- Credit Check: verify the player's saved MogScore and pay out based on it.
-- Returns payout (number) on success, or nil + reason string.
function CreditService.CreditCheck(player)
	local profile = DataService.Get(player)
	if not profile then
		return nil, "Your data is still loading."
	end

	local now = os.time()
	local remaining = (profile.LastCreditCheck or 0) + Constants.CREDIT_CHECK_COOLDOWN - now
	if remaining > 0 then
		return nil, ("Credit Check is cooling down. %ds left."):format(remaining)
	end

	-- Recompute MogScore from saved stats so the payout can never be inflated
	-- by a tampered in-memory value.
	local verifiedScore = 0
	for statName, def in pairs(Constants.STATS) do
		local level = tonumber(profile.Stats[statName]) or 0
		verifiedScore += level * def.ScorePerLevel
	end
	verifiedScore = math.floor(verifiedScore * CreditService.GetMultiplier(profile))
	profile.MogScore = verifiedScore

	local payout = Constants.CREDIT_CHECK_BASE_PAYOUT + math.floor(verifiedScore * Constants.CREDIT_CHECK_SCORE_FACTOR)
	profile.LastCreditCheck = now
	profile.CreditChecks = (profile.CreditChecks or 0) + 1

	local actual = CreditService.Add(player, payout, "CreditCheck")
	notify(player, "success", "Credit Check Passed", ("Verified Mog Score %d. +%d Credits."):format(verifiedScore, actual))
	return actual
end

-- Gym rep: small frequent trickle.
function CreditService.GymRep(player)
	local profile = DataService.Get(player)
	if not profile then
		return nil, "Your data is still loading."
	end
	local now = os.time()
	if (profile.LastGymRep or 0) + Constants.GYM_REP_COOLDOWN > now then
		return nil, "Catch your breath first."
	end
	profile.LastGymRep = now
	local actual = CreditService.Add(player, Constants.GYM_REP_PAYOUT, "GymRep")
	notify(player, "info", "Rep Complete", ("+%d Credits. Keep going."):format(actual))
	return actual
end

-- Rating booth: bigger payout on a longer cooldown, scales with score.
function CreditService.RateSelf(player)
	local profile = DataService.Get(player)
	if not profile then
		return nil, "Your data is still loading."
	end
	local now = os.time()
	local remaining = (profile.LastRating or 0) + Constants.RATING_BOOTH_COOLDOWN - now
	if remaining > 0 then
		return nil, ("The mirror needs %ds to reset."):format(remaining)
	end
	profile.LastRating = now
	local payout = Constants.RATING_BOOTH_BASE_PAYOUT + math.floor((profile.MogScore or 0) * Constants.RATING_BOOTH_SCORE_FACTOR)
	local actual = CreditService.Add(player, payout, "RateSelf")
	local rank = Constants.GetRank(profile.MogScore or 0)
	notify(player, "success", "Mirror Verdict: " .. rank.Name, ("The mirror approves. +%d Credits."):format(actual))
	return actual
end

function CreditService.Init()
	Remotes.Get("CreditCheck").OnServerEvent:Connect(function(player)
		local AntiExploit = require(script.Parent:WaitForChild("AntiExploit"))
		if not AntiExploit.Allow(player, "CreditCheck") then
			return
		end
		local payout, reason = CreditService.CreditCheck(player)
		if not payout then
			notify(player, "error", "Credit Check", reason)
		end
	end)

	Remotes.Get("GymRep").OnServerEvent:Connect(function(player)
		local AntiExploit = require(script.Parent:WaitForChild("AntiExploit"))
		if not AntiExploit.Allow(player, "GymRep") then
			return
		end
		local payout, reason = CreditService.GymRep(player)
		if not payout then
			notify(player, "error", "Gym", reason)
		end
	end)

	Remotes.Get("RateSelf").OnServerEvent:Connect(function(player)
		local AntiExploit = require(script.Parent:WaitForChild("AntiExploit"))
		if not AntiExploit.Allow(player, "RateSelf") then
			return
		end
		local payout, reason = CreditService.RateSelf(player)
		if not payout then
			notify(player, "error", "Mirror", reason)
		end
	end)
end

return CreditService
