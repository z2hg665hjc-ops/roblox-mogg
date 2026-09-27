--[[
	Constants.lua
	Single source of truth for every tunable number in the game.
	Change balance here, nowhere else.
]]

local Constants = {}

Constants.DATASTORE_NAME = "MoggingData_v3"
Constants.LEADERBOARD_STORE_NAME = "MoggingLeaderboard_v3"

Constants.STARTING_CREDITS = 100

-- How often (seconds) a player's data autosaves while online.
Constants.AUTOSAVE_INTERVAL = 120

-- ---------------------------------------------------------------------------
-- Stats. Each stat costs Credits to level up and contributes to MogScore.
-- Cost grows geometrically: cost(level) = BaseCost * Growth ^ level
-- ---------------------------------------------------------------------------
Constants.STATS = {
	Jawline = {
		DisplayName = "Jawline",
		BaseCost = 25,
		Growth = 1.12,
		ScorePerLevel = 4,
		MaxLevel = 250,
	},
	Hair = {
		DisplayName = "Hair",
		BaseCost = 20,
		Growth = 1.12,
		ScorePerLevel = 3,
		MaxLevel = 250,
	},
	Physique = {
		DisplayName = "Physique",
		BaseCost = 35,
		Growth = 1.13,
		ScorePerLevel = 5,
		MaxLevel = 250,
	},
	Aura = {
		DisplayName = "Aura",
		BaseCost = 50,
		Growth = 1.14,
		ScorePerLevel = 6,
		MaxLevel = 250,
	},
	Fit = {
		DisplayName = "Fit",
		BaseCost = 30,
		Growth = 1.12,
		ScorePerLevel = 4,
		MaxLevel = 250,
	},
}

-- Order stats appear in the shop UI.
Constants.STAT_ORDER = { "Jawline", "Hair", "Physique", "Aura", "Fit" }

-- ---------------------------------------------------------------------------
-- Ranks: purely cosmetic titles based on MogScore. Highest threshold <= score wins.
-- ---------------------------------------------------------------------------
Constants.RANKS = {
	{ Name = "NPC", MinScore = 0, Color = { 150, 150, 150 } },
	{ Name = "Mid", MinScore = 50, Color = { 200, 200, 120 } },
	{ Name = "Decent", MinScore = 150, Color = { 120, 200, 160 } },
	{ Name = "Rizzler", MinScore = 350, Color = { 90, 200, 255 } },
	{ Name = "Chad", MinScore = 700, Color = { 90, 140, 255 } },
	{ Name = "Sigma", MinScore = 1300, Color = { 170, 90, 255 } },
	{ Name = "Alpha", MinScore = 2400, Color = { 255, 120, 90 } },
	{ Name = "Mogger", MinScore = 4200, Color = { 255, 80, 170 } },
	{ Name = "Grand Mogger", MinScore = 7000, Color = { 255, 200, 40 } },
	{ Name = "Living Legend", MinScore = 12000, Color = { 255, 255, 255 } },
}

-- ---------------------------------------------------------------------------
-- Rebirth: resets stats + credits back to the starting point, keeps a
-- permanent multiplier on all future Credit and MogScore gains.
-- ---------------------------------------------------------------------------
Constants.REBIRTH_BASE_REQUIREMENT = 500 -- MogScore needed for 1st rebirth
Constants.REBIRTH_REQUIREMENT_GROWTH = 1.6 -- each rebirth needs this much more
Constants.REBIRTH_MULTIPLIER_PER_REBIRTH = 0.25 -- +25% credits/score per rebirth

-- ---------------------------------------------------------------------------
-- Credit Check kiosk: a server-verified periodic payout so credit gains are
-- always double-checked against the player's real, saved MogScore.
-- ---------------------------------------------------------------------------
Constants.CREDIT_CHECK_COOLDOWN = 180 -- seconds between checks
Constants.CREDIT_CHECK_BASE_PAYOUT = 15
Constants.CREDIT_CHECK_SCORE_FACTOR = 0.08 -- + MogScore * factor

-- ---------------------------------------------------------------------------
-- Gym minigame: quick repeated interaction for a small, frequent trickle.
-- ---------------------------------------------------------------------------
Constants.GYM_REP_COOLDOWN = 4
Constants.GYM_REP_PAYOUT = 3
Constants.GYM_REP_SCORE_GAIN = 0 -- gym is credits-only, stats come from the shop

-- ---------------------------------------------------------------------------
-- Rating booth: one-shot flavor reward, longer cooldown, bigger payout.
-- ---------------------------------------------------------------------------
Constants.RATING_BOOTH_COOLDOWN = 90
Constants.RATING_BOOTH_BASE_PAYOUT = 10
Constants.RATING_BOOTH_SCORE_FACTOR = 0.05

-- ---------------------------------------------------------------------------
-- Anti-exploit: minimum seconds between remote fires per player, per remote.
-- ---------------------------------------------------------------------------
Constants.REMOTE_COOLDOWNS = {
	BuyStat = 0.15,
	Rebirth = 1,
	CreditCheck = 1,
	GymRep = 1,
	RateSelf = 1,
	RequestData = 1,
}

function Constants.GetRank(mogScore)
	local best = Constants.RANKS[1]
	for _, rank in ipairs(Constants.RANKS) do
		if mogScore >= rank.MinScore then
			best = rank
		end
	end
	return best
end

function Constants.GetStatCost(statName, level)
	local def = Constants.STATS[statName]
	if not def then
		return nil
	end
	return math.floor(def.BaseCost * (def.Growth ^ level))
end

function Constants.GetRebirthRequirement(rebirthCount)
	return math.floor(Constants.REBIRTH_BASE_REQUIREMENT * (Constants.REBIRTH_REQUIREMENT_GROWTH ^ rebirthCount))
end

function Constants.GetRebirthMultiplier(rebirthCount)
	return 1 + (rebirthCount * Constants.REBIRTH_MULTIPLIER_PER_REBIRTH)
end

return Constants
