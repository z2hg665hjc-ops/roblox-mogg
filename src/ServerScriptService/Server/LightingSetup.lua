--[[
	LightingSetup.lua
	Clean, soft daylight. Neutral colors, gentle shadows, very little bloom so
	only the few intentionally glowing objects glow.
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
	Lighting.ClockTime = 14.3
	Lighting.GeographicLatitude = 25
	Lighting.Brightness = 2.0
	Lighting.Ambient = Color3.fromRGB(118, 118, 126)
	Lighting.OutdoorAmbient = Color3.fromRGB(138, 140, 150)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 250, 240)
	Lighting.ColorShift_Bottom = Color3.fromRGB(225, 230, 240)
	Lighting.EnvironmentDiffuseScale = 0.8
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.35
	Lighting.FogColor = Color3.fromRGB(215, 220, 232)
	Lighting.FogStart = 350
	Lighting.FogEnd = 1400

	ensure("Sky", "Sky", {
		StarCount = 0,
		SunAngularSize = 14,
		MoonAngularSize = 10,
		CelestialBodiesShown = true,
	})

	ensure("Atmosphere", "Atmosphere", {
		Density = 0.28,
		Offset = 0.2,
		Color = Color3.fromRGB(210, 218, 232),
		Decay = Color3.fromRGB(150, 160, 190),
		Glare = 0.1,
		Haze = 1.0,
	})

	ensure("BloomEffect", "Bloom", {
		Intensity = 0.25,
		Size = 20,
		Threshold = 1.6,
	})

	ensure("ColorCorrectionEffect", "ColorCorrection", {
		Brightness = 0.0,
		Contrast = 0.05,
		Saturation = -0.05,
		TintColor = Color3.fromRGB(255, 255, 255),
	})

	ensure("SunRaysEffect", "SunRays", {
		Intensity = 0.02,
		Spread = 0.6,
	})
end

return LightingSetup
