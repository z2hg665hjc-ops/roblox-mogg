--[[
	HudController.lua
	Always-on HUD: stat card (credits, score, rank, multiplier, rank progress),
	cooldown pills, menu buttons, and a fading hint bar for new players.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local ClientState = require(script.Parent:WaitForChild("ClientState"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local UI = require(script.Parent:WaitForChild("UIBuilder"))

local HudController = {}

local player = Players.LocalPlayer

local creditsValue = nil -- NumberValue driving the count-up animation
local scoreValue = nil
local creditsLabel, scoreLabel, rankBadge, rankLabel, multLabel, nextRankLabel, recordLabel
local rankBar
local cooldownPills = {}

local function animateNumber(valueObj, target)
	valueObj.Value = valueObj.Value -- ensure exists
	TweenService:Create(valueObj, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Value = target }):Play()
end

local function buildStatCard(parent)
	local card = UI.Box({
		Name = "StatCard",
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.fromOffset(300, 196),
		BackgroundColor3 = Theme.Colors.Panel,
		StrokeColor = Theme.Colors.Accent,
		Parent = parent,
	})
	UI.Padding(card, 16, 14)

	-- Credits
	UI.Text({
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.fromOffset(0, 0),
		Font = Theme.FontMedium,
		TextSize = 11,
		Text = "CREDITS",
		TextColor3 = Theme.Colors.TextDim,
		Parent = card,
	})
	creditsLabel = UI.Text({
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.fromOffset(0, 14),
		Font = Theme.FontBlack,
		TextSize = 30,
		Text = "0",
		TextColor3 = Theme.Colors.Gold,
		Parent = card,
	})

	-- Score
	UI.Text({
		Size = UDim2.new(0.5, 0, 0, 14),
		Position = UDim2.fromOffset(0, 56),
		Font = Theme.FontMedium,
		TextSize = 11,
		Text = "MOG SCORE",
		TextColor3 = Theme.Colors.TextDim,
		Parent = card,
	})
	scoreLabel = UI.Text({
		Size = UDim2.new(0.55, 0, 0, 28),
		Position = UDim2.fromOffset(0, 70),
		Font = Theme.FontBlack,
		TextSize = 24,
		Text = "0",
		TextColor3 = Theme.Colors.Accent,
		Parent = card,
	})

	-- Rank badge
	rankBadge = UI.Box({
		Name = "RankBadge",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 58),
		Size = UDim2.fromOffset(120, 40),
		BackgroundColor3 = Theme.Colors.PanelLight,
		StrokeColor = Theme.Colors.Stroke,
		Corner = 10,
		Parent = card,
	})
	rankLabel = UI.Text({
		Size = UDim2.new(1, 0, 1, 0),
		Font = Theme.FontBlack,
		TextSize = 15,
		Text = "NPC",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextScaled = true,
		Parent = rankBadge,
	})
	UI.Padding(rankBadge, 8, 6)

	-- Multiplier pill
	multLabel = UI.Text({
		Size = UDim2.new(0.45, 0, 0, 14),
		Position = UDim2.new(0.55, 0, 0, 104),
		Font = Theme.Font,
		TextSize = 12,
		Text = "x1.00 bonus",
		TextColor3 = Theme.Colors.TextDim,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = card,
	})

	-- Next rank progress
	nextRankLabel = UI.Text({
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.fromOffset(0, 104),
		Font = Theme.FontMedium,
		TextSize = 11,
		Text = "NEXT: Mid",
		TextColor3 = Theme.Colors.TextDim,
		Parent = card,
	})
	rankBar = UI.ProgressBar({
		Name = "RankBar",
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.fromOffset(0, 122),
		Color = Theme.Colors.Accent,
		Parent = card,
	})

	recordLabel = UI.Text({
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.fromOffset(0, 146),
		Font = Theme.FontMedium,
		TextSize = 11,
		Text = "MOG OFF RECORD  0W - 0L",
		TextColor3 = Theme.Colors.TextDim,
		Parent = card,
	})

	return card
end

local function buildCooldownPills(parent)
	local holder = UI.Create("Frame", {
		Name = "Cooldowns",
		Position = UDim2.fromOffset(16, 224),
		Size = UDim2.fromOffset(300, 32),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	UI.List(holder, 8, Enum.FillDirection.Horizontal)

	local function pill(name, label)
		local frame = UI.Box({
			Name = name,
			Size = UDim2.fromOffset(146, 30),
			BackgroundColor3 = Theme.Colors.Panel,
			StrokeColor = Theme.Colors.Stroke,
			Corner = 15,
			Parent = holder,
		})
		local text = UI.Text({
			Size = UDim2.new(1, 0, 1, 0),
			Font = Theme.Font,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = label,
			Parent = frame,
		})
		local stroke = frame:FindFirstChildOfClass("UIStroke")
		cooldownPills[name] = { Frame = frame, Text = text, Stroke = stroke, Label = label }
	end
	pill("CreditCheck", "CREDIT CHECK")
	pill("Mirror", "MIRROR")
end

local function buildMenuButtons(parent, panels)
	local holder = UI.Create("Frame", {
		Name = "Menu",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(150, 300),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	UI.List(holder, 10, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

	local dark = Color3.fromRGB(20, 20, 26)
	local defs = {
		{ "SHOP", Theme.Colors.Gold, panels.Shop, dark },
		{ "MOG OFF", Theme.Colors.Red, panels.Battle, Theme.Colors.Text },
		{ "PREMIUM", Theme.Colors.Green, panels.Premium, dark },
		{ "LEADERBOARD", Theme.Colors.Cyan, panels.Leaderboard, dark },
		{ "REBIRTH", Theme.Colors.Accent, panels.Rebirth, Theme.Colors.Text },
	}
	for i, def in ipairs(defs) do
		UI.Button({
			Name = def[1],
			Text = def[1],
			Size = UDim2.fromOffset(150, 48),
			Color = def[2],
			TextColor = def[4],
			TextSize = 16,
			LayoutOrder = i,
			Parent = holder,
			OnClick = function()
				for _, p in pairs(panels) do
					if p ~= def[3] and p.IsOpen() then
						p.Close()
					end
				end
				def[3].Toggle()
			end,
		})
	end
end

local function buildHint(parent)
	local hint = UI.Box({
		Name = "Hint",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(620, 40),
		BackgroundColor3 = Theme.Colors.Panel,
		StrokeColor = Theme.Colors.Accent2,
		Corner = 20,
		Parent = parent,
	})
	local text = UI.Text({
		Size = UDim2.new(1, 0, 1, 0),
		Font = Theme.Font,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "Press <b>E</b> at a <b>Shop stall</b>, the <b>Gym</b>, the <b>Mirror</b>, the <b>Credit Check</b> kiosk, or at <b>another player</b> to Mog Off.",
		Parent = hint,
	})
	task.delay(18, function()
		TweenService:Create(hint, Theme.Tween.Slow, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(text, Theme.Tween.Slow, { TextTransparency = 1 }):Play()
		local stroke = hint:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, Theme.Tween.Slow, { Transparency = 1 }):Play()
		end
		task.wait(0.6)
		hint:Destroy()
	end)
end

local function refresh(data)
	if not data then
		return
	end
	animateNumber(creditsValue, data.Credits or 0)
	animateNumber(scoreValue, data.MogScore or 0)

	local rank = Constants.GetRank(data.MogScore or 0)
	local rankColor = Theme.RankColor(rank)
	rankLabel.Text = rank.Name
	rankLabel.TextColor3 = rankColor
	local stroke = rankBadge:FindFirstChildOfClass("UIStroke")
	if stroke then
		TweenService:Create(stroke, Theme.Tween.Normal, { Color = rankColor }):Play()
	end

	local mult = Constants.GetRebirthMultiplier(data.Rebirths or 0)
	if data.Passes and data.Passes.DoubleCredits then
		mult *= 2
	end
	multLabel.Text = ("x%.2f credits  |  R%d"):format(mult, data.Rebirths or 0)
	multLabel.TextColor3 = mult > 1 and Theme.Colors.Accent or Theme.Colors.TextDim
	recordLabel.Text = ("MOG OFF RECORD  %dW - %dL"):format(data.Wins or 0, data.Losses or 0)

	local nextRank = ClientState.NextRank()
	if nextRank then
		local span = nextRank.MinScore - rank.MinScore
		local into = (data.MogScore or 0) - rank.MinScore
		local alpha = span > 0 and (into / span) or 1
		nextRankLabel.Text = ('NEXT RANK: <font color="#%s">%s</font>'):format(Theme.RankColor(nextRank):ToHex(), nextRank.Name)
		rankBar.Set(alpha, ("%s / %s"):format(Theme.Format(data.MogScore or 0), Theme.Format(nextRank.MinScore)))
		rankBar.SetColor(Theme.RankColor(nextRank))
	else
		nextRankLabel.Text = "MAX RANK"
		rankBar.Set(1, "Living Legend")
		rankBar.SetColor(rankColor)
	end
end

local function tickCooldowns()
	local defs = {
		CreditCheck = { "LastCreditCheck", Constants.CREDIT_CHECK_COOLDOWN },
		Mirror = { "LastRating", Constants.RATING_BOOTH_COOLDOWN },
	}
	for name, pill in pairs(cooldownPills) do
		local def = defs[name]
		local remaining = ClientState.CooldownRemaining(def[1], def[2])
		if remaining <= 0 then
			pill.Text.Text = pill.Label .. ": <b>READY</b>"
			pill.Text.TextColor3 = Theme.Colors.Green
			if pill.Stroke then
				pill.Stroke.Color = Theme.Colors.Green
			end
		else
			pill.Text.Text = pill.Label .. ": " .. Theme.FormatTime(remaining)
			pill.Text.TextColor3 = Theme.Colors.TextDim
			if pill.Stroke then
				pill.Stroke.Color = Theme.Colors.Stroke
			end
		end
	end
end

function HudController.Init(screenGui, panels)
	creditsValue = Instance.new("NumberValue")
	scoreValue = Instance.new("NumberValue")

	buildStatCard(screenGui)
	buildCooldownPills(screenGui)
	buildMenuButtons(screenGui, panels)
	buildHint(screenGui)

	creditsValue.Changed:Connect(function(v)
		creditsLabel.Text = Theme.Format(v)
	end)
	scoreValue.Changed:Connect(function(v)
		scoreLabel.Text = Theme.Format(v)
	end)

	ClientState.Changed:Connect(refresh)
	if ClientState.Get() then
		refresh(ClientState.Get())
	end

	-- Cooldown ticker (1 Hz).
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 1 then
			acc = 0
			tickCooldowns()
		end
	end)
	tickCooldowns()

	-- Rank-up flash on the badge.
	local lastRankName = nil
	ClientState.Changed:Connect(function(data)
		local rank = Constants.GetRank(data.MogScore or 0)
		if lastRankName and rank.Name ~= lastRankName then
			local flash = UI.Create("UIScale", { Scale = 1, Parent = rankBadge })
			local t =
				TweenService:Create(flash, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), { Scale = 1.25 })
			t:Play()
			t.Completed:Connect(function()
				flash:Destroy()
			end)
		end
		lastRankName = rank.Name
	end)

	-- Keep the character name visible in the HUD so people know whose stats these are.
	UI.Text({
		Name = "Who",
		Position = UDim2.fromOffset(20, 214),
		Size = UDim2.fromOffset(300, 12),
		Font = Theme.FontMedium,
		TextSize = 10,
		Text = player.DisplayName,
		TextColor3 = Theme.Colors.TextDim,
		Parent = screenGui,
	})
end

return HudController
