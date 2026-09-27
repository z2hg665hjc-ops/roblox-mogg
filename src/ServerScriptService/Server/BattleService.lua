--[[
	BattleService.lua
	"Mog Off" player-vs-player duels.

	Flow: challenge (walk up + E, or the Mog Off panel) -> target accepts ->
	both are teleported onto the stage and frozen -> 3s countdown -> 6s FLEX
	phase where both spam click -> power is compared -> winner takes the pot.

	Power = (MogScore + 10) * (1 + clicks * 1%, capped) * luck(±8%)
	So score matters most, but a determined underdog can still pull it off.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local AntiExploit = require(script.Parent:WaitForChild("AntiExploit"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local CreditService = require(script.Parent:WaitForChild("CreditService"))
local PresenceService = require(script.Parent:WaitForChild("PresenceService"))

local BattleService = {}

local B = Constants.BATTLE

local requests = {} -- [requestId] = {Id, From, To, Expires}
local inBattle = {} -- [UserId] = battle
local lastBattle = {} -- [UserId] = os.clock()
local nextRequestId = 0

local function notify(player, kind, title, message)
	if player and player.Parent then
		Remotes.Get("Notify"):FireClient(player, kind, title, message)
	end
end

local function state(player, payload)
	if player and player.Parent then
		Remotes.Get("BattleState"):FireClient(player, payload)
	end
end

local function stageSpots()
	local hub = Workspace:FindFirstChild("Hub")
	local stage = hub and hub:FindFirstChild("Stage")
	local platform = stage and stage:FindFirstChild("Platform")
	local top = Vector3.new(0, 3, -85)
	if platform then
		top = platform.Position + Vector3.new(0, platform.Size.Y / 2, 0)
	end
	return top + Vector3.new(-5, 3.2, 0), top + Vector3.new(5, 3.2, 0)
end

local function setFrozen(player, frozen)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if frozen then
		humanoid:SetAttribute("MogWalkSpeed", humanoid.WalkSpeed)
		humanoid:SetAttribute("MogJumpPower", humanoid.JumpPower)
		humanoid:SetAttribute("MogJumpHeight", humanoid.JumpHeight)
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
	else
		humanoid.WalkSpeed = humanoid:GetAttribute("MogWalkSpeed") or 16
		humanoid.JumpPower = humanoid:GetAttribute("MogJumpPower") or 50
		humanoid.JumpHeight = humanoid:GetAttribute("MogJumpHeight") or 7.2
	end
end

local function teleport(player, position, faceToward)
	local character = player.Character
	if not character then
		return
	end
	local look = Vector3.new(faceToward.X, position.Y, faceToward.Z)
	character:PivotTo(CFrame.lookAt(position, look))
end

local function scoreOf(player)
	local profile = DataService.Get(player)
	return profile and (profile.MogScore or 0) or 0
end

local function power(player, flex)
	local flexBonus = 1 + math.min(flex or 0, B.MaxFlex) * B.FlexPowerPerClick
	local luck = 1 + (math.random() * 2 - 1) * B.LuckRange
	return (scoreOf(player) + 10) * flexBonus * luck
end

local function canBattle(player)
	if not player or not player.Parent then
		return false, "Player left."
	end
	if inBattle[player.UserId] then
		return false, player.DisplayName .. " is already in a Mog Off."
	end
	if os.clock() - (lastBattle[player.UserId] or 0) < B.Cooldown then
		return false, player.DisplayName .. " just finished a battle. Give it a second."
	end
	local profile = DataService.Get(player)
	if not profile then
		return false, player.DisplayName .. "'s data is still loading."
	end
	if profile.Credits < B.Wager then
		return false, ("%s can't cover the %d Credit wager."):format(player.DisplayName, B.Wager)
	end
	return true
end

local function cleanup(battle)
	for _, p in ipairs({ battle.A, battle.B }) do
		if inBattle[p.UserId] == battle then
			inBattle[p.UserId] = nil
		end
		lastBattle[p.UserId] = os.clock()
		setFrozen(p, false)
	end
end

local function finish(battle, forfeiter)
	if battle.Ended then
		return
	end
	battle.Ended = true
	battle.Phase = "Result"

	local a, b = battle.A, battle.B
	local flexA, flexB = battle.Flex[a.UserId] or 0, battle.Flex[b.UserId] or 0
	local powerA, powerB = power(a, flexA), power(b, flexB)

	local winner, loser
	if forfeiter then
		loser = forfeiter
		winner = (forfeiter == a) and b or a
	else
		winner = (powerA >= powerB) and a or b
		loser = (winner == a) and b or a
	end

	local profileW = DataService.Get(winner)
	local bonus = 0
	if profileW then
		profileW.Wins = (profileW.Wins or 0) + 1
		CreditService.AddRaw(winner, battle.Pot)
		bonus = CreditService.Add(winner, B.WinBonus, "BattleWin")
		PresenceService.Refresh(winner)
	end
	local profileL = DataService.Get(loser)
	if profileL then
		profileL.Losses = (profileL.Losses or 0) + 1
		DataService.MarkDirty(loser)
		PresenceService.Refresh(loser)
	end

	local result = {
		Phase = "Result",
		Duration = B.ResultDuration,
		WinnerUserId = winner.UserId,
		WinnerName = winner.DisplayName,
		LoserName = loser.DisplayName,
		Forfeit = forfeiter ~= nil,
		Pot = battle.Pot,
		Bonus = bonus,
		Wager = B.Wager,
		Powers = { [tostring(a.UserId)] = math.floor(powerA), [tostring(b.UserId)] = math.floor(powerB) },
		Flex = { [tostring(a.UserId)] = flexA, [tostring(b.UserId)] = flexB },
	}
	state(a, result)
	state(b, result)

	notify(winner, "success", "You mogged " .. loser.DisplayName, ("+%d Credits from the pot, +%d bonus."):format(battle.Pot, bonus))
	notify(loser, "error", "Mogged", ("%s took the %d Credit pot."):format(winner.DisplayName, battle.Pot))

	task.delay(B.ResultDuration, function()
		cleanup(battle)
	end)
end

local function start(a, b)
	-- Escrow the wager from both sides.
	if not CreditService.Spend(a, B.Wager) then
		notify(a, "error", "Mog Off", "You can't cover the wager.")
		notify(b, "error", "Mog Off", a.DisplayName .. " couldn't cover the wager.")
		return
	end
	if not CreditService.Spend(b, B.Wager) then
		CreditService.AddRaw(a, B.Wager) -- refund
		notify(b, "error", "Mog Off", "You can't cover the wager.")
		notify(a, "error", "Mog Off", b.DisplayName .. " couldn't cover the wager.")
		return
	end

	local battle = {
		A = a,
		B = b,
		Flex = { [a.UserId] = 0, [b.UserId] = 0 },
		Pot = B.Wager * 2,
		Phase = "Countdown",
		Ended = false,
	}
	inBattle[a.UserId] = battle
	inBattle[b.UserId] = battle

	-- Drop any other pending invites involving either player.
	for id, req in pairs(requests) do
		if req.From == a.UserId or req.To == a.UserId or req.From == b.UserId or req.To == b.UserId then
			requests[id] = nil
		end
	end

	local spotA, spotB = stageSpots()
	teleport(a, spotA, spotB)
	teleport(b, spotB, spotA)
	setFrozen(a, true)
	setFrozen(b, true)

	local function payload(me, them)
		return {
			Phase = "Countdown",
			Duration = B.CountdownDuration,
			Opponent = them.DisplayName,
			OpponentScore = scoreOf(them),
			MyScore = scoreOf(me),
			Wager = B.Wager,
			Pot = battle.Pot,
		}
	end
	state(a, payload(a, b))
	state(b, payload(b, a))

	task.spawn(function()
		task.wait(B.CountdownDuration)
		if battle.Ended then
			return
		end
		battle.Phase = "Flex"
		local flexPayload = { Phase = "Flex", Duration = B.FlexDuration, MaxFlex = B.MaxFlex }
		state(a, flexPayload)
		state(b, flexPayload)
		task.wait(B.FlexDuration)
		if not battle.Ended then
			finish(battle)
		end
	end)
end

function BattleService.Request(from, targetUserId)
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == from then
		return false, "Pick another player."
	end
	local ok, reason = canBattle(from)
	if not ok then
		return false, reason
	end
	ok, reason = canBattle(target)
	if not ok then
		return false, reason
	end

	-- Replace any existing invite from this player to this target.
	for id, req in pairs(requests) do
		if req.From == from.UserId and req.To == target.UserId then
			requests[id] = nil
		end
	end

	nextRequestId += 1
	local id = nextRequestId
	requests[id] = { Id = id, From = from.UserId, To = target.UserId, Expires = os.clock() + B.AcceptTimeout }

	state(target, {
		Phase = "Invite",
		RequestId = id,
		From = from.DisplayName,
		FromScore = scoreOf(from),
		Wager = B.Wager,
		Timeout = B.AcceptTimeout,
	})
	notify(from, "info", "Challenge sent", ("Waiting on %s to accept."):format(target.DisplayName))

	task.delay(B.AcceptTimeout, function()
		if requests[id] then
			requests[id] = nil
			notify(from, "error", "No answer", target.DisplayName .. " didn't respond.")
			state(target, { Phase = "InviteExpired", RequestId = id })
		end
	end)
	return true
end

function BattleService.Respond(player, requestId, accept)
	local req = requests[requestId]
	if not req or req.To ~= player.UserId then
		return
	end
	requests[requestId] = nil
	local from = Players:GetPlayerByUserId(req.From)

	if not accept then
		notify(from, "error", "Declined", player.DisplayName .. " declined your Mog Off.")
		return
	end
	if not from then
		notify(player, "error", "Mog Off", "They already left.")
		return
	end

	local ok, reason = canBattle(from)
	if ok then
		ok, reason = canBattle(player)
	end
	if not ok then
		notify(player, "error", "Mog Off", reason)
		notify(from, "error", "Mog Off", reason)
		return
	end
	start(from, player)
end

function BattleService.Flex(player)
	local battle = inBattle[player.UserId]
	if battle and battle.Phase == "Flex" and not battle.Ended then
		battle.Flex[player.UserId] = (battle.Flex[player.UserId] or 0) + 1
	end
end

local function addChallengePrompt(player, character)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root or root:FindFirstChild("ChallengePrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ChallengePrompt"
	prompt.ActionText = "Challenge to a Mog Off"
	prompt.ObjectText = ("%s  |  %d Credit wager"):format(player.DisplayName, B.Wager)
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = root

	prompt.Triggered:Connect(function(challenger)
		if challenger == player then
			return
		end
		if not AntiExploit.Allow(challenger, "BattleRequest") then
			return
		end
		local ok, reason = BattleService.Request(challenger, player.UserId)
		if not ok then
			notify(challenger, "error", "Mog Off", reason)
		end
	end)
end

local function watch(player)
	player.CharacterAdded:Connect(function(character)
		task.spawn(addChallengePrompt, player, character)
	end)
	if player.Character then
		task.spawn(addChallengePrompt, player, player.Character)
	end
end

function BattleService.Init()
	Players.PlayerAdded:Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local battle = inBattle[player.UserId]
		if battle and not battle.Ended then
			finish(battle, player)
		end
		inBattle[player.UserId] = nil
		lastBattle[player.UserId] = nil
		for id, req in pairs(requests) do
			if req.From == player.UserId or req.To == player.UserId then
				requests[id] = nil
			end
		end
	end)

	Remotes.Get("BattleRequest").OnServerEvent:Connect(function(player, targetUserId)
		if not AntiExploit.Allow(player, "BattleRequest") then
			return
		end
		if type(targetUserId) ~= "number" then
			return
		end
		local ok, reason = BattleService.Request(player, targetUserId)
		if not ok then
			notify(player, "error", "Mog Off", reason)
		end
	end)

	Remotes.Get("BattleRespond").OnServerEvent:Connect(function(player, requestId, accept)
		if not AntiExploit.Allow(player, "BattleRespond") then
			return
		end
		if type(requestId) ~= "number" then
			return
		end
		BattleService.Respond(player, requestId, accept == true)
	end)

	Remotes.Get("BattleFlex").OnServerEvent:Connect(function(player)
		if not AntiExploit.Allow(player, "BattleFlex") then
			return
		end
		BattleService.Flex(player)
	end)
end

return BattleService
