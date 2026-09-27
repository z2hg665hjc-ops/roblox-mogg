--[[
	RebirthController.lua
	Rebirth panel with progress toward the requirement, before/after
	multiplier, and a two-click confirm so nobody rebirths by accident.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ClientState = require(script.Parent:WaitForChild("ClientState"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local UI = require(script.Parent:WaitForChild("UIBuilder"))

local RebirthController = {}

local panel = nil
local bar = nil
local statusLabel, currentLabel, nextLabel, resetLabel
local confirmButton = nil
local armed = false
local armToken = 0

local function refresh(data)
	if not panel or not data then
		return
	end
	local rebirths = data.Rebirths or 0
	local requirement = Constants.GetRebirthRequirement(rebirths)
	local score = data.MogScore or 0
	local alpha = requirement > 0 and math.clamp(score / requirement, 0, 1) or 1
	bar.Set(alpha, ("%s / %s Mog Score"):format(Theme.Format(score), Theme.Format(requirement)))

	local currentMult = Constants.GetRebirthMultiplier(rebirths)
	local nextMult = Constants.GetRebirthMultiplier(rebirths + 1)
	currentLabel.Text = ("Rebirths: <b>%d</b>    Current bonus: <b>x%.2f</b>"):format(rebirths, currentMult)
	nextLabel.Text = ('After rebirth: <font color="#%s"><b>x%.2f</b></font> on all Credits and Mog Score, forever.'):format(
		Theme.Colors.Accent:ToHex(),
		nextMult
	)
	resetLabel.Text = ("Resets all 5 stats to 0 and Credits back to <b>%d</b>."):format(Constants.STARTING_CREDITS)

	local ready = score >= requirement
	statusLabel.Text = ready and "<b>READY.</b> The altar is calling."
		or ("Need <b>%s</b> more Mog Score."):format(Theme.Format(requirement - score))
	statusLabel.TextColor3 = ready and Theme.Colors.Green or Theme.Colors.TextDim
	confirmButton.SetEnabled(ready)
	if not ready then
		armed = false
		confirmButton.SetText("REBIRTH")
	end
end

function RebirthController.Init(screenGui)
	panel = UI.Panel({
		Name = "Rebirth",
		Title = "REBIRTH",
		Subtitle = "Start over. Come back stronger.",
		Accent = Theme.Colors.Accent,
		Width = 500,
		Height = 400,
		Parent = screenGui,
		OnOpen = function()
			armed = false
			if confirmButton then
				confirmButton.SetText("REBIRTH")
			end
			refresh(ClientState.Get())
		end,
	})

	local content = panel.Content
	UI.List(content, 12)

	statusLabel = UI.Text({
		Size = UDim2.new(1, 0, 0, 24),
		Font = Theme.FontBlack,
		TextSize = 18,
		Text = "",
		LayoutOrder = 1,
		Parent = content,
	})
	bar = UI.ProgressBar({
		Size = UDim2.new(1, 0, 0, 22),
		Color = Theme.Colors.Accent,
		LayoutOrder = 2,
		Parent = content,
	})
	currentLabel = UI.Text({
		Size = UDim2.new(1, 0, 0, 20),
		Font = Theme.Font,
		TextSize = 14,
		LayoutOrder = 3,
		Parent = content,
	})
	nextLabel = UI.Text({
		Size = UDim2.new(1, 0, 0, 40),
		Font = Theme.Font,
		TextSize = 14,
		TextWrapped = true,
		LayoutOrder = 4,
		Parent = content,
	})
	resetLabel = UI.Text({
		Size = UDim2.new(1, 0, 0, 20),
		Font = Theme.FontMedium,
		TextSize = 13,
		TextColor3 = Theme.Colors.Red,
		LayoutOrder = 5,
		Parent = content,
	})

	local spacer = UI.Create("Frame", { Size = UDim2.new(1, 0, 0, 6), BackgroundTransparency = 1, LayoutOrder = 6, Parent = content })
	spacer.Name = "Spacer"

	confirmButton = UI.Button({
		Name = "Confirm",
		Text = "REBIRTH",
		Size = UDim2.new(1, 0, 0, 52),
		Color = Theme.Colors.Accent,
		TextSize = 18,
		LayoutOrder = 7,
		Parent = content,
		OnClick = function()
			if not armed then
				armed = true
				armToken += 1
				local token = armToken
				confirmButton.SetText("CLICK AGAIN TO CONFIRM")
				task.delay(4, function()
					if armToken == token and armed then
						armed = false
						confirmButton.SetText("REBIRTH")
					end
				end)
				return
			end
			armed = false
			confirmButton.SetText("REBIRTH")
			Remotes.Get("Rebirth"):FireServer()
			panel.Close()
		end,
	})

	ClientState.Changed:Connect(refresh)
	refresh(ClientState.Get())
end

function RebirthController.Panel()
	return panel
end

return RebirthController
