--[[
	MonetizationService.lua
	Robux: game passes (permanent perks) and developer products (credit packs).

	IDs live in Constants.GAMEPASSES / Constants.PRODUCTS. An Id of 0 means the
	owner hasn't created that item in the Creator Dashboard yet; the client
	explains that instead of prompting a purchase.

	Purchases are idempotent: every granted receipt's PurchaseId is stored in
	the profile so Roblox retrying ProcessReceipt can never double-grant.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Signal = require(Shared:WaitForChild("Signal"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local CreditService = require(script.Parent:WaitForChild("CreditService"))

local MonetizationService = {}

MonetizationService.PassesChanged = Signal.new() -- fires (player)

local owned = {} -- [UserId] = { [passKey] = true }
local productsById = {} -- [ProductId] = product def
local passesById = {} -- [GamePassId] = pass def

for _, product in ipairs(Constants.PRODUCTS) do
	if product.Id ~= 0 then
		productsById[product.Id] = product
	end
end
for _, pass in ipairs(Constants.GAMEPASSES) do
	if pass.Id ~= 0 then
		passesById[pass.Id] = pass
	end
end

local function notify(player, kind, title, message)
	if player and player.Parent then
		Remotes.Get("Notify"):FireClient(player, kind, title, message)
	end
end

function MonetizationService.Owns(player, passKey)
	local set = player and owned[player.UserId]
	return set ~= nil and set[passKey] == true
end

local function refreshPasses(player)
	local set = {}
	for _, pass in ipairs(Constants.GAMEPASSES) do
		if pass.Id ~= 0 then
			local ok, result = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
			end)
			set[pass.Key] = ok and result == true
		else
			set[pass.Key] = false
		end
	end
	owned[player.UserId] = set
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = DataService.WaitFor(player, 10)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	profile.Purchases = profile.Purchases or {}
	if profile.Purchases[receipt.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local product = productsById[receipt.ProductId]
	if not product then
		warn(("[Monetization] Receipt for unknown ProductId %s"):format(tostring(receipt.ProductId)))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	CreditService.AddRaw(player, product.Credits)
	profile.Purchases[receipt.PurchaseId] = os.time()
	profile.RobuxSpent = (profile.RobuxSpent or 0) + (receipt.CurrencySpent or 0)

	-- Persist before telling Roblox it's granted. If the save fails outside
	-- Studio, roll back and let Roblox retry later.
	local saved = DataService.Save(player)
	if not saved and not RunService:IsStudio() then
		profile.Credits = math.max(0, profile.Credits - product.Credits)
		profile.Purchases[receipt.PurchaseId] = nil
		DataService.MarkDirty(player)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	notify(player, "success", "Purchase complete", ("+%d Credits. Thank you for the support."):format(product.Credits))
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.Init()
	DataService.AddSnapshotExtra(function(player, snapshot)
		snapshot.Passes = owned[player.UserId] or {}
	end)

	DataService.ProfileLoaded:Connect(function(player)
		refreshPasses(player)
		DataService.MarkDirty(player)
		MonetizationService.PassesChanged:Fire(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		owned[player.UserId] = nil
	end)

	-- Perks.
	table.insert(CreditService.MultiplierProviders, function(player)
		return MonetizationService.Owns(player, "DoubleCredits") and 2 or 1
	end)
	CreditService.DailyMultiplierProvider = function(player)
		return MonetizationService.Owns(player, "VIP") and 2 or 1
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local pass = passesById[passId]
		if not pass then
			return
		end
		owned[player.UserId] = owned[player.UserId] or {}
		owned[player.UserId][pass.Key] = true
		DataService.MarkDirty(player)
		MonetizationService.PassesChanged:Fire(player)
		notify(player, "success", pass.Name .. " unlocked", pass.Description)
	end)

	MarketplaceService.ProcessReceipt = processReceipt
end

return MonetizationService
