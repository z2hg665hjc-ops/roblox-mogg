--[[
	Server bootstrap. Order matters: data first, then gameplay, then world.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")

local function boot(name, fn)
	local ok, err = pcall(fn)
	if ok then
		print(("[Boot] %s ready"):format(name))
	else
		warn(("[Boot] %s FAILED: %s"):format(name, tostring(err)))
	end
end

local AntiExploit = require(Server:WaitForChild("AntiExploit"))
local DataService = require(Server:WaitForChild("DataService"))
local CreditService = require(Server:WaitForChild("CreditService"))
local StatService = require(Server:WaitForChild("StatService"))
local RebirthService = require(Server:WaitForChild("RebirthService"))
local PresenceService = require(Server:WaitForChild("PresenceService"))
local LeaderboardService = require(Server:WaitForChild("LeaderboardService"))
local LightingSetup = require(Server:WaitForChild("LightingSetup"))
local MapBuilder = require(Server:WaitForChild("MapBuilder"))
local InteractionService = require(Server:WaitForChild("InteractionService"))

boot("AntiExploit", AntiExploit.Init)
boot("DataService", DataService.Init)
boot("CreditService", CreditService.Init)
boot("StatService", StatService.Init)
boot("RebirthService", RebirthService.Init)
boot("PresenceService", PresenceService.Init)
boot("Lighting", LightingSetup.Apply)
boot("Map", MapBuilder.Build)
boot("LeaderboardService", LeaderboardService.Init)
boot("InteractionService", InteractionService.Init)

print("[Boot] Mogging Simulator server online.")
