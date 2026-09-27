--[[
	ShopController.lua
	Upgrade shop: one card per stat with level, next cost, and Buy 1 / Buy 10.
	Everything shown is derived from the server snapshot; the server re-checks.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ClientState = require(script.Parent:WaitForChild("ClientState"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local UI = require(script.Parent:WaitForChild("UIBuilder"))

local ShopController = {}

local panel = nil
local balanceLabel = nil
local cards = {} -- [statName] = {Level=, Cost=, Cost10=, Buy1=, Buy10=, Stroke=}

local function costForN(statName, level, n)
	local def = Constants.STATS[statName]
	local total = 0
	for i = 0, n - 1 do
		if level + i >= def.MaxLevel then
			break
		end
		total += Constants.GetStatCost(statName, level + i)
	end
	return total
end

local function buildCard(parent, statName, order)
	local def = Constants.STATS[statName]
	local color = Theme.StatColors[statName] or Theme.Colors.Accent

	local card = UI.Box({
		Name = statName,
		Size = UDim2.new(1, -8, 0, 130),
		BackgroundColor3 = Theme.Colors.Row,
		StrokeColor = Theme.Colors.Stroke,
		LayoutOrder = order,
		Parent = parent,
	})
	UI.Padding(card, 14, 12)

	UI.Create("Frame", {
		Name = "Accent",
		Size = UDim2.new(0, 4, 1, 0),
		Position = UDim2.fromOffset(-14, 0),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = card,
	})

	UI.Text({
		Size = UDim2.new(0.6, 0, 0, 24),
		Font = Theme.FontBlack,
		TextSize = 20,
		Text = def.DisplayName,
		TextColor3 = color,
		Parent = card,
	})
	local levelLabel = UI.Text({
		Size = UDim2.new(0.4, 0, 0, 24),
		Position = UDim2.new(0.6, 0, 0, 0),
		Font = Theme.Font,
		TextSize = 14,
		Text = "Lv. 0",
		TextColor3 = Theme.Colors.TextDim,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = card,
	})
	UI.Text({
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.fromOffset(0, 26),
		Font = Theme.FontMedium,
		TextSize = 12,
		Text = Theme.StatBlurbs[statName] or "",
		TextColor3 = Theme.Colors.TextDim,
		Parent = card,
	})
	UI.Text({
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.fromOffset(0, 44),
		Font = Theme.Font,
		TextSize = 12,
		Text = ("+%d Mog Score per level"):format(def.ScorePerLevel),
		TextColor3 = Theme.Colors.Text,
		Parent = card,
	})

	local buy1 = UI.Button({
		Name = "Buy1",
		Text = "BUY 1",
		Size = UDim2.fromOffset(150, 34),
		Position = UDim2.new(0, 0, 1, -34),
		Color = color,
		TextColor = Color3.fromRGB(18, 18, 24),
		TextSize = 14,
		Corner = 8,
		Parent = card,
		OnClick = function()
			Remotes.Get("BuyStat"):FireServer(statName, 1)
		end,
	})
	local buy10 = UI.Button({
		Name = "Buy10",
		Text = "BUY 10",
		Size = UDim2.fromOffset(150, 34),
		Position = UDim2.new(0, 162, 1, -34),
		Color = Theme.Colors.PanelLight,
		TextColor = Theme.Colors.Text,
		TextSize = 14,
		Corner = 8,
		Parent = card,
		OnClick = function()
			Remotes.Get("BuyStat"):FireServer(statName, 10)
		end,
	})

	cards[statName] = {
		Frame = card,
		Level = levelLabel,
		Buy1 = buy1,
		Buy10 = buy10,
		Stroke = card:FindFirstChildOfClass("UIStroke"),
		Color = color,
	}
end

local function refresh(data)
	if not data or not panel then
		return
	end
	balanceLabel.Text = ('Balance: <font color="#%s"><b>%s</b></font> Credits'):format(
		Theme.Colors.Gold:ToHex(),
		Theme.Format(data.Credits or 0)
	)
	for statName, card in pairs(cards) do
		local def = Constants.STATS[statName]
		local level = tonumber(data.Stats and data.Stats[statName]) or 0
		local maxed = level >= def.MaxLevel
		card.Level.Text = maxed and ("Lv. %d  MAX"):format(level) or ("Lv. %d / %d"):format(level, def.MaxLevel)

		local cost1 = Constants.GetStatCost(statName, level) or 0
		local cost10 = costForN(statName, level, 10)
		local canOne = not maxed and (data.Credits or 0) >= cost1
		local canTen = not maxed and cost10 > 0 and (data.Credits or 0) >= cost10

		card.Buy1.SetText(maxed and "MAXED" or ("BUY 1  -  " .. Theme.Format(cost1)))
		card.Buy10.SetText(maxed and "MAXED" or ("BUY 10  -  " .. Theme.Format(cost10)))
		card.Buy1.SetEnabled(canOne)
		card.Buy10.SetEnabled(canTen)
	end
end

function ShopController.Init(screenGui)
	panel = UI.Panel({
		Name = "Shop",
		Title = "UPGRADE SHOP",
		Subtitle = "Spend Credits. Raise your Mog Score. Climb the ranks.",
		Accent = Theme.Colors.Gold,
		Width = 560,
		Height = 620,
		Parent = screenGui,
		OnOpen = function()
			refresh(ClientState.Get())
		end,
	})

	balanceLabel = UI.Text({
		Size = UDim2.new(1, 0, 0, 22),
		Font = Theme.Font,
		TextSize = 15,
		Text = "Balance: 0 Credits",
		Parent = panel.Content,
	})

	local scroll = UI.Create("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 1, -30),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Theme.Colors.Gold,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 12,
		Parent = panel.Content,
	})
	UI.List(scroll, 10)

	for i, statName in ipairs(Constants.STAT_ORDER) do
		buildCard(scroll, statName, i)
	end

	ClientState.Changed:Connect(refresh)
	refresh(ClientState.Get())
end

-- Open, optionally spotlighting a stat.
function ShopController.Open(statName)
	if not panel then
		return
	end
	panel.Open()
	local card = statName and cards[statName]
	if card and card.Stroke then
		card.Stroke.Color = card.Color
		card.Stroke.Thickness = 3
		TweenService:Create(card.Stroke, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = Theme.Colors.Stroke,
			Thickness = 1.5,
		}):Play()
	end
end

function ShopController.Panel()
	return panel
end

return ShopController
