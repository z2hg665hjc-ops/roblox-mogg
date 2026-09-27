--[[
	PresenceService.lua
	Everything other players can *see* about your progress: an overhead tag
	with rank + Mog Score, and an aura particle effect that grows with rank.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local StatService = require(script.Parent:WaitForChild("StatService"))
local MonetizationService = require(script.Parent:WaitForChild("MonetizationService"))

local GOLD = Color3.fromRGB(235, 195, 95)

local PresenceService = {}

local function rankIndex(rank)
	for i, r in ipairs(Constants.RANKS) do
		if r.Name == rank.Name then
			return i
		end
	end
	return 1
end

local function ensureTag(character)
	local head = character:FindFirstChild("Head")
	if not head then
		return nil
	end
	local gui = head:FindFirstChild("MogTag")
	if gui then
		return gui
	end

	gui = Instance.new("BillboardGui")
	gui.Name = "MogTag"
	gui.Size = UDim2.fromOffset(220, 60)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false

	local rankLabel = Instance.new("TextLabel")
	rankLabel.Name = "Rank"
	rankLabel.BackgroundTransparency = 1
	rankLabel.Size = UDim2.new(1, 0, 0.55, 0)
	rankLabel.Position = UDim2.new(0, 0, 0, 0)
	rankLabel.Font = Enum.Font.GothamBlack
	rankLabel.TextScaled = true
	rankLabel.TextStrokeTransparency = 0.2
	rankLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	rankLabel.Text = "NPC"
	rankLabel.Parent = gui

	local scoreLabel = Instance.new("TextLabel")
	scoreLabel.Name = "Score"
	scoreLabel.BackgroundTransparency = 1
	scoreLabel.Size = UDim2.new(1, 0, 0.45, 0)
	scoreLabel.Position = UDim2.new(0, 0, 0.55, 0)
	scoreLabel.Font = Enum.Font.GothamBold
	scoreLabel.TextScaled = true
	scoreLabel.TextColor3 = Color3.fromRGB(230, 230, 240)
	scoreLabel.TextStrokeTransparency = 0.3
	scoreLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	scoreLabel.Text = "0 Mog"
	scoreLabel.Parent = gui

	gui.Parent = head
	return gui
end

local function ensureAura(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local emitter = root:FindFirstChild("Aura")
	if emitter then
		return emitter
	end
	emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Aura"
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Speed = NumberRange.new(0.6, 1.2)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.LightEmission = 0.3
	emitter.LightInfluence = 0
	emitter.Acceleration = Vector3.new(0, 3, 0)
	emitter.Parent = root
	return emitter
end

local function refresh(player)
	local character = player.Character
	local profile = DataService.Get(player)
	if not character or not profile then
		return
	end
	local score = profile.MogScore or 0
	local rank = Constants.GetRank(score)
	local color = Color3.fromRGB(rank.Color[1], rank.Color[2], rank.Color[3])
	local isVip = MonetizationService.Owns(player, "VIP")

	local gui = ensureTag(character)
	if gui then
		local rankLabel = gui:FindFirstChild("Rank")
		local scoreLabel = gui:FindFirstChild("Score")
		if rankLabel then
			rankLabel.Text = isVip and ("VIP  " .. rank.Name) or rank.Name
			rankLabel.TextColor3 = isVip and GOLD or color
		end
		if scoreLabel then
			local rebirths = profile.Rebirths or 0
			local wins = profile.Wins or 0
			local text = ("%d Mog"):format(score)
			if wins > 0 then
				text ..= ("  |  %dW"):format(wins)
			end
			if rebirths > 0 then
				text ..= ("  |  R%d"):format(rebirths)
			end
			scoreLabel.Text = text
		end
	end

	local emitter = ensureAura(character)
	if emitter then
		local idx = rankIndex(rank)
		-- Subtle: nothing until Chad, then a slow drift of particles. VIP is gold.
		local rate = math.max(0, (idx - 4) * 2.5)
		if isVip then
			rate = math.max(rate, 5)
		end
		emitter.Rate = rate
		emitter.Color = ColorSequence.new(isVip and GOLD or color)
	end
end

local function watch(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		refresh(player)
	end)
	if player.Character then
		refresh(player)
	end
end

function PresenceService.Init()
	Players.PlayerAdded:Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end

	DataService.ProfileLoaded:Connect(function(player)
		refresh(player)
	end)

	StatService.ScoreChanged:Connect(function(player)
		refresh(player)
	end)

	MonetizationService.PassesChanged:Connect(function(player)
		refresh(player)
	end)
end

-- Battles change W/L without touching the score.
function PresenceService.Refresh(player)
	refresh(player)
end

return PresenceService
