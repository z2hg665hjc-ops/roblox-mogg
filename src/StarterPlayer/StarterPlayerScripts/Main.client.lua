--[[
	Client bootstrap. Builds the ScreenGui, wires state -> UI, and listens for
	server requests to open panels (from the hub's proximity prompts).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local Client = script.Parent:WaitForChild("Client")
local ClientState = require(Client:WaitForChild("ClientState"))
local NotificationController = require(Client:WaitForChild("NotificationController"))
local ShopController = require(Client:WaitForChild("ShopController"))
local LeaderboardController = require(Client:WaitForChild("LeaderboardController"))
local RebirthController = require(Client:WaitForChild("RebirthController"))
local HudController = require(Client:WaitForChild("HudController"))

-- No tools in this game, so hide the backpack.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MogHud"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 5
screenGui.IgnoreGuiInset = false
screenGui.Parent = playerGui

-- Scale the whole HUD down on small screens.
local uiScale = Instance.new("UIScale")
uiScale.Parent = screenGui
local function updateScale()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local vp = camera.ViewportSize
	local s = math.min(vp.X / 1500, vp.Y / 850)
	uiScale.Scale = math.clamp(s, 0.6, 1)
end
updateScale()
if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	updateScale()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
end)

ClientState.Init()
NotificationController.Init(screenGui)
ShopController.Init(screenGui)
LeaderboardController.Init(screenGui)
RebirthController.Init(screenGui)

local panels = {
	Shop = ShopController.Panel(),
	Leaderboard = LeaderboardController.Panel(),
	Rebirth = RebirthController.Panel(),
}
HudController.Init(screenGui, panels)

local function closeOthers(keep)
	for name, p in pairs(panels) do
		if name ~= keep and p.IsOpen() then
			p.Close()
		end
	end
end

Remotes.Get("OpenPanel").OnClientEvent:Connect(function(panelName, arg)
	if panelName == "Shop" then
		closeOthers("Shop")
		ShopController.Open(arg)
	elseif panelName == "Rebirth" then
		closeOthers("Rebirth")
		panels.Rebirth.Open()
	elseif panelName == "Leaderboard" then
		closeOthers("Leaderboard")
		panels.Leaderboard.Open()
	end
end)

-- Welcome message once data arrives the first time.
local welcomed = false
ClientState.Changed:Connect(function(data)
	if welcomed then
		return
	end
	welcomed = true
	local rank = ClientState.Rank()
	if (data.LifetimeCredits or 0) <= (data.Credits or 0) and (data.Rebirths or 0) == 0 and (data.MogScore or 0) == 0 then
		NotificationController.Show(
			"success",
			"Welcome to the city",
			("You start with %d Credits. Hit the shops."):format(data.Credits or 0)
		)
	else
		NotificationController.Show(
			"info",
			"Welcome back, " .. rank.Name,
			("%s Credits ready to spend."):format(tostring(data.Credits or 0))
		)
	end
end)
