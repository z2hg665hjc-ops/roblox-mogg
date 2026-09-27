--[[
	LeaderboardController.lua
	Global top-10 panel. Highlights the local player if they're on it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local ClientState = require(script.Parent:WaitForChild("ClientState"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local UI = require(script.Parent:WaitForChild("UIBuilder"))

local LeaderboardController = {}

local player = Players.LocalPlayer
local panel = nil
local rows = {}
local footer = nil

local MEDALS = { Theme.Colors.Gold, Color3.fromRGB(200, 200, 215), Color3.fromRGB(205, 130, 80) }

local function buildRow(parent, i)
	local row = UI.Box({
		Name = "Row" .. i,
		Size = UDim2.new(1, -8, 0, 40),
		BackgroundColor3 = (i % 2 == 0) and Theme.Colors.Panel or Theme.Colors.Row,
		StrokeColor = Theme.Colors.Stroke,
		Corner = 8,
		LayoutOrder = i,
		Parent = parent,
	})
	UI.Padding(row, 12, 6)
	local rankLabel = UI.Text({
		Size = UDim2.fromOffset(34, 28),
		Font = Theme.FontBlack,
		TextSize = 16,
		Text = tostring(i),
		TextColor3 = MEDALS[i] or Theme.Colors.TextDim,
		Parent = row,
	})
	local nameLabel = UI.Text({
		Size = UDim2.new(1, -150, 0, 28),
		Position = UDim2.fromOffset(38, 0),
		Font = Theme.Font,
		TextSize = 15,
		Text = "---",
		Parent = row,
	})
	local scoreLabel = UI.Text({
		Size = UDim2.fromOffset(110, 28),
		Position = UDim2.new(1, -110, 0, 0),
		Font = Theme.FontBlack,
		TextSize = 15,
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.Colors.Accent,
		Parent = row,
	})
	rows[i] = { Frame = row, Rank = rankLabel, Name = nameLabel, Score = scoreLabel, Stroke = row:FindFirstChildOfClass("UIStroke") }
end

local function refresh(entries)
	if not panel then
		return
	end
	local mine = nil
	for i = 1, 10 do
		local row = rows[i]
		local entry = entries and entries[i]
		if entry then
			local rank = Constants.GetRank(entry.Score or 0)
			row.Name.Text = ('%s  <font color="#%s" size="12">%s</font>'):format(
				entry.Name or "?",
				Theme.RankColor(rank):ToHex(),
				rank.Name
			)
			row.Name.TextColor3 = Theme.Colors.Text
			row.Score.Text = Theme.Format(entry.Score or 0)
			local isMe = entry.UserId == player.UserId
			if isMe then
				mine = i
			end
			row.Stroke.Color = isMe and Theme.Colors.Cyan or Theme.Colors.Stroke
			row.Stroke.Thickness = isMe and 2.5 or 1.5
		else
			row.Name.Text = "---"
			row.Name.TextColor3 = Theme.Colors.TextDim
			row.Score.Text = ""
			row.Stroke.Color = Theme.Colors.Stroke
			row.Stroke.Thickness = 1.5
		end
	end
	local data = ClientState.Get()
	if mine then
		footer.Text = ("You are <b>#%d</b> in the world. Updates every minute."):format(mine)
	else
		footer.Text = ("Your Mog Score: <b>%s</b>. Not on the board yet. Updates every minute."):format(
			Theme.Format(data and data.MogScore or 0)
		)
	end
end

function LeaderboardController.Init(screenGui)
	panel = UI.Panel({
		Name = "Leaderboard",
		Title = "TOP MOGGERS",
		Subtitle = "Global top 10 by Mog Score.",
		Accent = Theme.Colors.Cyan,
		Width = 520,
		Height = 600,
		Parent = screenGui,
		OnOpen = function()
			refresh(ClientState.Leaderboard)
		end,
	})

	local list = UI.Create("Frame", {
		Name = "List",
		Size = UDim2.new(1, 0, 1, -36),
		BackgroundTransparency = 1,
		ZIndex = 12,
		Parent = panel.Content,
	})
	UI.List(list, 6)
	for i = 1, 10 do
		buildRow(list, i)
	end

	footer = UI.Text({
		Name = "Footer",
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.new(0, 0, 1, -24),
		Font = Theme.FontMedium,
		TextSize = 12,
		Text = "",
		TextColor3 = Theme.Colors.TextDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = panel.Content,
	})

	ClientState.LeaderboardChanged:Connect(refresh)
	ClientState.Changed:Connect(function()
		if panel.IsOpen() then
			refresh(ClientState.Leaderboard)
		end
	end)
	refresh(ClientState.Leaderboard)
end

function LeaderboardController.Panel()
	return panel
end

return LeaderboardController
