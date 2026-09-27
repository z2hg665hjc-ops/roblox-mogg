--[[
	NotificationController.lua
	Toast notifications in the bottom-right. Server fires Notify(kind, title, message).
	Kinds: "success" | "error" | "info"
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local Theme = require(script.Parent:WaitForChild("Theme"))
local UI = require(script.Parent:WaitForChild("UIBuilder"))

local NotificationController = {}

local container = nil
local order = 0

local KIND_COLORS = {
	success = Theme.Colors.Green,
	error = Theme.Colors.Red,
	info = Theme.Colors.Cyan,
}

local LIFETIME = 4.2

function NotificationController.Show(kind, title, message)
	if not container then
		return
	end
	local accent = KIND_COLORS[kind] or Theme.Colors.Accent
	order += 1

	local toast = UI.Box({
		Name = "Toast",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Panel,
		StrokeColor = accent,
		LayoutOrder = order,
		Parent = container,
	})
	local scale = UI.Create("UIScale", { Scale = 0.8, Parent = toast })
	UI.Padding(toast, 14, 12)

	UI.Create("Frame", {
		Name = "Bar",
		Size = UDim2.new(0, 4, 1, 0),
		Position = UDim2.fromOffset(-14, 0),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Parent = toast,
	})

	local body = UI.Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = toast,
	})
	UI.List(body, 4)

	UI.Text({
		Size = UDim2.new(1, 0, 0, 20),
		Font = Theme.FontBlack,
		TextSize = 16,
		Text = tostring(title or ""),
		TextColor3 = accent,
		LayoutOrder = 1,
		Parent = body,
	})
	UI.Text({
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Theme.FontMedium,
		TextSize = 14,
		Text = tostring(message or ""),
		TextWrapped = true,
		TextColor3 = Theme.Colors.Text,
		LayoutOrder = 2,
		Parent = body,
	})

	TweenService:Create(scale, Theme.Tween.Pop, { Scale = 1 }):Play()

	task.delay(LIFETIME, function()
		if not toast.Parent then
			return
		end
		local t = TweenService:Create(scale, Theme.Tween.Normal, { Scale = 0.8 })
		TweenService:Create(toast, Theme.Tween.Normal, { BackgroundTransparency = 1 }):Play()
		for _, d in ipairs(toast:GetDescendants()) do
			if d:IsA("TextLabel") then
				TweenService:Create(d, Theme.Tween.Normal, { TextTransparency = 1 }):Play()
			elseif d:IsA("Frame") then
				TweenService:Create(d, Theme.Tween.Normal, { BackgroundTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, Theme.Tween.Normal, { Transparency = 1 }):Play()
			end
		end
		t:Play()
		t.Completed:Wait()
		toast:Destroy()
	end)
end

function NotificationController.Init(screenGui)
	container = UI.Create("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -20),
		Size = UDim2.fromOffset(340, 420),
		BackgroundTransparency = 1,
		ZIndex = 50,
		Parent = screenGui,
	})
	UI.List(container, 8, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom)

	Remotes.Get("Notify").OnClientEvent:Connect(function(kind, title, message)
		NotificationController.Show(kind, title, message)
	end)
end

return NotificationController
