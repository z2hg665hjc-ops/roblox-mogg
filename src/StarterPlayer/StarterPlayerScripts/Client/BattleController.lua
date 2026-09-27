--[[
	BattleController.lua
	Client side of Mog Off duels: the invite card, the countdown / flex /
	result overlay, and the "Mog Off" panel that lists players to challenge.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Theme = require(script.Parent:WaitForChild("Theme"))
local UI = require(script.Parent:WaitForChild("UIBuilder"))

local BattleController = {}

local player = Players.LocalPlayer
local B = Constants.BATTLE

local panel = nil
local listFrame = nil
local closeAll = nil

-- Invite card
local invite = nil
local inviteText, inviteTimer
local inviteRequestId = nil
local inviteExpires = 0

-- Overlay
local overlay = nil
local centerCard, centerTitle, centerSub, centerBig
local flexHolder, flexButton, flexCount, flexBar
local phase = nil
local phaseEnds = 0
local myFlex = 0
local lastFlexSend = 0

local function buildInvite(screenGui)
	invite = UI.Box({
		Name = "Invite",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -140),
		Size = UDim2.fromOffset(440, 120),
		BackgroundColor3 = Theme.Colors.Panel,
		StrokeColor = Theme.Colors.Red,
		Visible = false,
		ZIndex = 30,
		Parent = screenGui,
	})
	UI.Padding(invite, 16, 12)
	inviteText = UI.Text({
		Size = UDim2.new(1, 0, 0, 44),
		Font = Theme.Font,
		TextSize = 15,
		TextWrapped = true,
		Text = "",
		ZIndex = 31,
		Parent = invite,
	})
	inviteTimer = UI.Text({
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.fromOffset(0, 46),
		Font = Theme.FontMedium,
		TextSize = 12,
		TextColor3 = Theme.Colors.TextDim,
		Text = "",
		ZIndex = 31,
		Parent = invite,
	})
	UI.Button({
		Text = "ACCEPT",
		Size = UDim2.fromOffset(196, 36),
		Position = UDim2.new(0, 0, 1, -36),
		Color = Theme.Colors.Green,
		TextColor = Color3.fromRGB(14, 30, 20),
		TextSize = 15,
		Corner = 8,
		Parent = invite,
		OnClick = function()
			if inviteRequestId then
				Remotes.Get("BattleRespond"):FireServer(inviteRequestId, true)
			end
			BattleController.HideInvite()
		end,
	}).Instance.ZIndex =
		31
	UI.Button({
		Text = "DECLINE",
		Size = UDim2.fromOffset(196, 36),
		Position = UDim2.new(1, -196, 1, -36),
		Color = Theme.Colors.PanelLight,
		TextSize = 15,
		Corner = 8,
		Parent = invite,
		OnClick = function()
			if inviteRequestId then
				Remotes.Get("BattleRespond"):FireServer(inviteRequestId, false)
			end
			BattleController.HideInvite()
		end,
	}).Instance.ZIndex =
		31
end

function BattleController.HideInvite()
	inviteRequestId = nil
	if invite and invite.Visible then
		local t = TweenService:Create(invite, Theme.Tween.Fast, { Position = UDim2.new(0.5, 0, 0, -140) })
		t:Play()
		t.Completed:Connect(function()
			if not inviteRequestId then
				invite.Visible = false
			end
		end)
	end
end

local function showInvite(payload)
	inviteRequestId = payload.RequestId
	inviteExpires = os.clock() + (payload.Timeout or B.AcceptTimeout)
	inviteText.Text = ("<b>%s</b> (Mog Score %s) challenged you to a Mog Off. Wager <b>%d Credits</b>."):format(
		payload.From or "?",
		Theme.Format(payload.FromScore or 0),
		payload.Wager or B.Wager
	)
	invite.Visible = true
	invite.Position = UDim2.new(0.5, 0, 0, -140)
	TweenService:Create(invite, Theme.Tween.Pop, { Position = UDim2.new(0.5, 0, 0, 20) }):Play()
end

local function buildOverlay(screenGui)
	overlay = UI.Create("Frame", {
		Name = "BattleOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 25,
		Parent = screenGui,
	})

	centerCard = UI.Box({
		Name = "Center",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.12, 0),
		Size = UDim2.fromOffset(520, 170),
		BackgroundColor3 = Theme.Colors.Panel,
		StrokeColor = Theme.Colors.Stroke,
		ZIndex = 26,
		Parent = overlay,
	})
	UI.Padding(centerCard, 20, 14)
	centerTitle = UI.Text({
		Size = UDim2.new(1, 0, 0, 30),
		Font = Theme.FontBlack,
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "MOG OFF",
		ZIndex = 27,
		Parent = centerCard,
	})
	centerSub = UI.Text({
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 32),
		Font = Theme.FontMedium,
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.Colors.TextDim,
		Text = "",
		ZIndex = 27,
		Parent = centerCard,
	})
	centerBig = UI.Text({
		Size = UDim2.new(1, 0, 0, 64),
		Position = UDim2.fromOffset(0, 76),
		Font = Theme.FontBlack,
		TextSize = 52,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "3",
		ZIndex = 27,
		Parent = centerCard,
	})

	flexHolder = UI.Create("Frame", {
		Name = "Flex",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -90),
		Size = UDim2.fromOffset(380, 150),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 26,
		Parent = overlay,
	})
	flexCount = UI.Text({
		Size = UDim2.new(1, 0, 0, 26),
		Font = Theme.FontBlack,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "0 flexes",
		ZIndex = 27,
		Parent = flexHolder,
	})
	flexBar = UI.ProgressBar({
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.fromOffset(0, 32),
		Color = Theme.Colors.Red,
		Parent = flexHolder,
	})
	flexBar.Instance.ZIndex = 27
	flexButton = UI.Button({
		Text = "FLEX",
		Size = UDim2.new(1, 0, 0, 90),
		Position = UDim2.fromOffset(0, 58),
		Color = Theme.Colors.Red,
		TextSize = 34,
		Corner = 16,
		Parent = flexHolder,
		OnClick = function()
			BattleController.Flex()
		end,
	})
	flexButton.Instance.ZIndex = 27
end

function BattleController.Flex()
	if phase ~= "Flex" then
		return
	end
	myFlex += 1
	flexCount.Text = ("%d flexes"):format(myFlex)
	local now = os.clock()
	if now - lastFlexSend >= 0.06 then
		lastFlexSend = now
		Remotes.Get("BattleFlex"):FireServer()
	end
	-- Little punch on the button.
	local s = flexButton.Instance:FindFirstChildOfClass("UIScale")
	if not s then
		s = UI.Create("UIScale", { Scale = 1, Parent = flexButton.Instance })
	end
	s.Scale = 0.94
	TweenService:Create(s, Theme.Tween.Fast, { Scale = 1 }):Play()
end

local function setOverlay(visible)
	overlay.Visible = visible
	if not visible then
		flexHolder.Visible = false
		phase = nil
	end
end

local function onState(payload)
	if type(payload) ~= "table" then
		return
	end
	local p = payload.Phase

	if p == "Invite" then
		showInvite(payload)
		return
	elseif p == "InviteExpired" then
		if inviteRequestId == payload.RequestId then
			BattleController.HideInvite()
		end
		return
	end

	if p == "Countdown" then
		if closeAll then
			closeAll()
		end
		BattleController.HideInvite()
		phase = "Countdown"
		phaseEnds = os.clock() + (payload.Duration or B.CountdownDuration)
		myFlex = 0
		centerTitle.Text = "MOG OFF"
		centerTitle.TextColor3 = Theme.Colors.Text
		centerSub.Text = ("<b>You</b> (%s)   vs   <b>%s</b> (%s)\nPot: %d Credits. Get ready to flex."):format(
			Theme.Format(payload.MyScore or 0),
			payload.Opponent or "?",
			Theme.Format(payload.OpponentScore or 0),
			payload.Pot or B.Wager * 2
		)
		centerBig.Text = tostring(payload.Duration or 3)
		centerBig.TextColor3 = Theme.Colors.Text
		flexHolder.Visible = false
		setOverlay(true)
	elseif p == "Flex" then
		phase = "Flex"
		phaseEnds = os.clock() + (payload.Duration or B.FlexDuration)
		centerTitle.Text = "FLEX"
		centerTitle.TextColor3 = Theme.Colors.Red
		centerSub.Text = "Click or tap the button, or hammer SPACE. Every flex adds power."
		centerBig.Text = ""
		flexCount.Text = "0 flexes"
		flexBar.Set(1, "")
		flexHolder.Visible = true
		setOverlay(true)
	elseif p == "Result" then
		phase = "Result"
		phaseEnds = os.clock() + (payload.Duration or B.ResultDuration)
		flexHolder.Visible = false
		local won = payload.WinnerUserId == player.UserId
		local me = tostring(player.UserId)
		local myPower = payload.Powers and payload.Powers[me] or 0
		local theirPower = 0
		if payload.Powers then
			for id, val in pairs(payload.Powers) do
				if id ~= me then
					theirPower = val
				end
			end
		end
		if won then
			centerTitle.Text = payload.Forfeit and "THEY RAN" or "YOU MOGGED THEM"
			centerTitle.TextColor3 = Theme.Colors.Green
			centerBig.Text = ("+%d"):format((payload.Pot or 0) + (payload.Bonus or 0))
			centerBig.TextColor3 = Theme.Colors.Gold
		else
			centerTitle.Text = "YOU GOT MOGGED"
			centerTitle.TextColor3 = Theme.Colors.Red
			centerBig.Text = ("-%d"):format(payload.Wager or B.Wager)
			centerBig.TextColor3 = Theme.Colors.Red
		end
		centerSub.Text = ("Your power %s  vs  %s's power %s"):format(
			Theme.Format(myPower),
			won and (payload.LoserName or "them") or (payload.WinnerName or "them"),
			Theme.Format(theirPower)
		)
		setOverlay(true)
		task.delay(payload.Duration or B.ResultDuration, function()
			if phase == "Result" then
				setOverlay(false)
			end
		end)
	end
end

-- ---------------------------------------------------------------------------
-- Mog Off panel: list of players to challenge
-- ---------------------------------------------------------------------------

local function refreshList()
	if not listFrame then
		return
	end
	for _, child in ipairs(listFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local others = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			others[#others + 1] = p
		end
	end
	if #others == 0 then
		local empty = UI.Box({
			Size = UDim2.new(1, -8, 0, 60),
			BackgroundColor3 = Theme.Colors.Row,
			NoStroke = true,
			Parent = listFrame,
		})
		UI.Text({
			Size = UDim2.new(1, 0, 1, 0),
			Font = Theme.FontMedium,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Theme.Colors.TextDim,
			Text = "Nobody else is here yet. Invite a friend, or walk up to someone and press E.",
			TextWrapped = true,
			Parent = empty,
		})
		return
	end
	for i, other in ipairs(others) do
		local row = UI.Box({
			Name = other.Name,
			Size = UDim2.new(1, -8, 0, 52),
			BackgroundColor3 = Theme.Colors.Row,
			StrokeColor = Theme.Colors.Stroke,
			Corner = 8,
			LayoutOrder = i,
			Parent = listFrame,
		})
		UI.Padding(row, 12, 8)
		UI.Text({
			Size = UDim2.new(1, -150, 0, 20),
			Font = Theme.Font,
			TextSize = 15,
			Text = other.DisplayName,
			Parent = row,
		})
		UI.Text({
			Size = UDim2.new(1, -150, 0, 14),
			Position = UDim2.fromOffset(0, 20),
			Font = Theme.FontMedium,
			TextSize = 11,
			TextColor3 = Theme.Colors.TextDim,
			Text = "@" .. other.Name,
			Parent = row,
		})
		UI.Button({
			Text = "CHALLENGE",
			Size = UDim2.fromOffset(130, 34),
			Position = UDim2.new(1, -130, 0.5, -17),
			Color = Theme.Colors.Red,
			TextSize = 13,
			Corner = 8,
			Parent = row,
			OnClick = function()
				Remotes.Get("BattleRequest"):FireServer(other.UserId)
				panel.Close()
			end,
		})
	end
end

local function buildPanel(screenGui)
	panel = UI.Panel({
		Name = "Battle",
		Title = "MOG OFF",
		Subtitle = ("Wager %d Credits. Higher Mog Score and more flexing wins the pot."):format(B.Wager),
		Accent = Theme.Colors.Red,
		Width = 520,
		Height = 520,
		Parent = screenGui,
		OnOpen = refreshList,
	})
	local rules = UI.Text({
		Size = UDim2.new(1, 0, 0, 40),
		Font = Theme.FontMedium,
		TextSize = 13,
		TextWrapped = true,
		TextColor3 = Theme.Colors.TextDim,
		Text = "Both players put up the wager. On the stage, a 3 second countdown, then 6 seconds of flexing. Power = your Mog Score, boosted up to +80% by flexing, with a little luck. Winner takes the pot plus a bonus.",
		ZIndex = 12,
		Parent = panel.Content,
	})
	rules.Name = "Rules"
	listFrame = UI.Create("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 1, -48),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Theme.Colors.Red,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 12,
		Parent = panel.Content,
	})
	UI.List(listFrame, 8)

	Players.PlayerAdded:Connect(function()
		if panel.IsOpen() then
			refreshList()
		end
	end)
	Players.PlayerRemoving:Connect(function()
		if panel.IsOpen() then
			refreshList()
		end
	end)
end

-- Hide the "challenge me" prompt on my own character.
local function hideOwnPrompt(character)
	task.spawn(function()
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if not root then
			return
		end
		local pp = root:WaitForChild("ChallengePrompt", 15)
		if pp then
			pp.Enabled = false
		end
	end)
end

function BattleController.Init(screenGui, closeAllPanels)
	closeAll = closeAllPanels
	buildInvite(screenGui)
	buildOverlay(screenGui)
	buildPanel(screenGui)

	Remotes.Get("BattleState").OnClientEvent:Connect(onState)

	if player.Character then
		hideOwnPrompt(player.Character)
	end
	player.CharacterAdded:Connect(hideOwnPrompt)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
			BattleController.Flex()
		end
	end)

	-- Timers.
	RunService.Heartbeat:Connect(function()
		if invite and invite.Visible and inviteRequestId then
			local left = math.max(0, inviteExpires - os.clock())
			inviteTimer.Text = ("Expires in %ds"):format(math.ceil(left))
			if left <= 0 then
				BattleController.HideInvite()
			end
		end
		if not overlay or not overlay.Visible then
			return
		end
		local left = math.max(0, phaseEnds - os.clock())
		if phase == "Countdown" then
			centerBig.Text = tostring(math.max(1, math.ceil(left)))
		elseif phase == "Flex" then
			centerBig.Text = ("%.1f"):format(left)
			local total = B.FlexDuration
			flexBar.Set(left / total, "")
		end
	end)
end

function BattleController.Panel()
	return panel
end

return BattleController
