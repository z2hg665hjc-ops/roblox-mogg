--[[
	LightingSetup.lua
	Dusk "neon city" mood: warm horizon, cool shadows, heavy bloom on neon.
]]

local Lighting = game:GetService("Lighting")

local LightingSetup = {}

local function ensure(className, name, props)
	local inst = Lighting:FindFirstChild(name)
	if not inst then
		inst = Instance.new(className)
		inst.Name = name
		inst.Parent = Lighting
	end
	for key, value in pairs(props) do
		inst[key] = value
	end
	return inst
end

function LightingSetup.Apply()
	Lighting.ClockTime = 19.1
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(38, 32, 56)
	Lighting.OutdoorAmbient = Color3.fromRGB(70, 62, 100)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 205, 175)
	Lighting.ColorShift_Bottom = Color3.fromRGB(130, 95, 170)
	Lighting.EnvironmentDiffuseScale = 0.65
	Lighting.EnvironmentSpecularScale = 0.7
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25
	Lighting.FogColor = Color3.fromRGB(28, 20, 46)
	Lighting.FogStart = 180
	Lighting.FogEnd = 900

	ensure("Sky", "Sky", {
		StarCount = 3500,
		SunAngularSize = 16,
		MoonAngularSize = 12,
		CelestialBodiesShown = true,
	})

	ensure("Atmosphere", "Atmosphere", {
		Density = 0.33,
		Offset = 0.3,
		Color = Color3.fromRGB(185, 165, 225),
		Decay = Color3.fromRGB(70, 45, 110),
		Glare = 0.45,
		Haze = 1.9,
	})

	ensure("BloomEffect", "Bloom", {
		Intensity = 0.85,
		Size = 32,
		Threshold = 1.0,
	})

	ensure("ColorCorrectionEffect", "ColorCorrection", {
		Brightness = 0.02,
		Contrast = 0.14,
		Saturation = 0.22,
		TintColor = Color3.fromRGB(255, 246, 252),
	})

	ensure("SunRaysEffect", "SunRays", {
		Intensity = 0.06,
		Spread = 0.8,
	})
end

return LightingSetup
