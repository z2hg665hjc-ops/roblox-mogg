--[[
	PremiumController.lua
	Robux shop: game passes and credit packs. Prices are fetched live from
	MarketplaceService when the panel opens. Items with Id = 0 explain that the
	owner hasn't linked them yet instead of failing.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local ClientState = require(script.Parent:WaitForChild("ClientState"))
local NotificationController = require(script.Parent:WaitForChild("NotificationController"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local UI = require(script.Parent:WaitForChild("UIBuilder"))

local PremiumController = {}

local player = Players.LocalPlayer
local panel = nil
local cards = {} -- [key] = {Price=label, Button=api, Kind=, Def=}
local priceCache = {} -- [id] = string

local function priceText(id, infoType)
	if id == 0 then
		return "Not linked"
	end
	if priceCache[id] then
		return priceCache[id]
	end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(id, infoType)
	end)
	if ok and info and info.PriceInRobux then
		priceCache[id] = ("R$ %d"):format(info.PriceInRobux)
	else
		priceCache[id] = "R$ --"
	end
	return priceCache[id]
end

local function notLinked(name)
	NotificationController.Show(
		"error",
		name .. " isn't linked yet",
		"Create it in the Creator Dashboard under Monetization, then paste its ID into Constants.lua."
	)
end

local function buildCard(parent, kind, def, order)
	local isPass = kind == "pass"
	local color = isPass and Theme.Colors.Accent or Theme.Colors.Gold
	local card = UI.Box({
		Name = def.Key,
		Size = UDim2.new(1, -8, 0, isPass and 96 or 72),
		BackgroundColor3 = Theme.Colors.Row,
		StrokeColor = Theme.Colors.Stroke,
		LayoutOrder = order,
		Parent = parent,
	})
	UI.Padding(card, 14, 12)
	UI.Create("Frame", {
		Size = UDim2.new(0, 4, 1, 0),
		Position = UDim2.fromOffset(-14, 0),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = card,
	})
	UI.Text({
		Size = UDim2.new(1, -170, 0, 22),
		Font = Theme.FontBlack,
		TextSize = 18,
		Text = def.Name,
		TextColor3 = color,
		Parent = card,
	})
	UI.Text({
		Size = UDim2.new(1, -170, 0, isPass and 44 or 20),
		Position = UDim2.fromOffset(0, 24),
		Font = Theme.FontMedium,
		TextSize = 12,
		TextWrapped = true,
		TextColor3 = Theme.Colors.TextDim,
		Text = isPass and def.Description or ("%s Credits, added instantly."):format(Theme.Format(def.Credits)),
		Parent = card,
	})
	local price = UI.Text({
		Size = UDim2.fromOffset(150, 18),
		Position = UDim2.new(1, -150, 0, 0),
		Font = Theme.Font,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.Colors.Text,
		Text = "",
		Parent = card,
	})
	local button = UI.Button({
		Text = "BUY",
		Size = UDim2.fromOffset(150, 34),
		Position = UDim2.new(1, -150, 1, -34),
		Color = color,
		TextColor = Color3.fromRGB(18, 18, 24),
		TextSize = 14,
		Corner = 8,
		Parent = card,
		OnClick = function()
			if def.Id == 0 then
				notLinked(def.Name)
				return
			end
			if isPass then
				MarketplaceService:PromptGamePassPurchase(player, def.Id)
			else
				MarketplaceService:PromptProductPurchase(player, def.Id)
			end
		end,
	})
	cards[def.Key] = { Price = price, Button = button, Kind = kind, Def = def }
end

local function header(parent, text, order)
	UI.Text({
		Size = UDim2.new(1, 0, 0, 22),
		Font = Theme.FontBlack,
		TextSize = 14,
		Text = text,
		TextColor3 = Theme.Colors.TextDim,
		LayoutOrder = order,
		Parent = parent,
	})
end

local function refresh()
	local data = ClientState.Get()
	local passes = data and data.Passes or {}
	for _, card in pairs(cards) do
		if card.Kind == "pass" then
			local owned = passes[card.Def.Key] == true
			card.Button.SetText(owned and "OWNED" or "BUY")
			card.Button.SetEnabled(not owned)
		end
	end
	task.spawn(function()
		for _, card in pairs(cards) do
			local infoType = card.Kind == "pass" and Enum.InfoType.GamePass or Enum.InfoType.Product
			card.Price.Text = priceText(card.Def.Id, infoType)
		end
	end)
end

function PremiumController.Init(screenGui)
	panel = UI.Panel({
		Name = "Premium",
		Title = "PREMIUM",
		Subtitle = "Support the game. Get ahead faster.",
		Accent = Theme.Colors.Green,
		Width = 560,
		Height = 640,
		Parent = screenGui,
		OnOpen = refresh,
	})

	local scroll = UI.Create("ScrollingFrame", {
		Name = "List",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Theme.Colors.Green,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 12,
		Parent = panel.Content,
	})
	UI.List(scroll, 8)

	local order = 0
	order += 1
	header(scroll, "GAME PASSES  |  permanent", order)
	for _, pass in ipairs(Constants.GAMEPASSES) do
		order += 1
		buildCard(scroll, "pass", pass, order)
	end
	order += 1
	local spacer = UI.Create("Frame", { Size = UDim2.new(1, 0, 0, 8), BackgroundTransparency = 1, LayoutOrder = order, Parent = scroll })
	spacer.Name = "Spacer"
	order += 1
	header(scroll, "CREDIT PACKS  |  one time", order)
	for _, product in ipairs(Constants.PRODUCTS) do
		order += 1
		buildCard(scroll, "product", product, order)
	end

	ClientState.Changed:Connect(function()
		if panel.IsOpen() then
			refresh()
		end
	end)
end

function PremiumController.Panel()
	return panel
end

return PremiumController
