--[[
	Theme.lua
	Colors, fonts, tween presets and number formatting shared by all UI.
]]

local Theme = {}

Theme.Colors = {
	Background = Color3.fromRGB(14, 14, 22),
	Panel = Color3.fromRGB(22, 22, 33),
	PanelLight = Color3.fromRGB(32, 32, 46),
	Row = Color3.fromRGB(27, 27, 40),
	Stroke = Color3.fromRGB(64, 64, 92),
	Text = Color3.fromRGB(242, 242, 252),
	TextDim = Color3.fromRGB(150, 150, 178),
	Accent = Color3.fromRGB(175, 95, 255),
	Accent2 = Color3.fromRGB(255, 70, 190),
	Cyan = Color3.fromRGB(80, 220, 255),
	Gold = Color3.fromRGB(255, 200, 60),
	Green = Color3.fromRGB(90, 255, 150),
	Red = Color3.fromRGB(255, 85, 95),
	Orange = Color3.fromRGB(255, 120, 90),
	Disabled = Color3.fromRGB(70, 70, 88),
}

Theme.StatColors = {
	Jawline = Theme.Colors.Orange,
	Hair = Theme.Colors.Gold,
	Physique = Theme.Colors.Cyan,
	Aura = Theme.Colors.Accent,
	Fit = Theme.Colors.Accent2,
}

Theme.StatBlurbs = {
	Jawline = "Sharpen the angles. Mog from any camera.",
	Hair = "Volume, flow, and zero bad hair days.",
	Physique = "Built, not born. Gym payout stays the same, score does not.",
	Aura = "The thing people cannot explain but definitely notice.",
	Fit = "Dress like the main character.",
}

Theme.Font = Enum.Font.GothamBold
Theme.FontBlack = Enum.Font.GothamBlack
Theme.FontMedium = Enum.Font.GothamMedium

Theme.Corner = 12
Theme.SmallCorner = 8

Theme.Tween = {
	Fast = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Normal = TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
	Pop = TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	Slow = TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
}

Theme.Sounds = {
	Click = "rbxasset://sounds/electronicpingshort.wav",
}

function Theme.RankColor(rank)
	return Color3.fromRGB(rank.Color[1], rank.Color[2], rank.Color[3])
end

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

function Theme.Format(n)
	n = tonumber(n) or 0
	if n < 1000 then
		return tostring(math.floor(n))
	end
	local idx = 1
	while n >= 1000 and idx < #SUFFIXES do
		n /= 1000
		idx += 1
	end
	local text
	if n >= 100 then
		text = ("%d"):format(math.floor(n))
	else
		text = ("%.1f"):format(n)
		if text:sub(-2) == ".0" then
			text = text:sub(1, -3)
		end
	end
	return text .. SUFFIXES[idx]
end

function Theme.FormatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	if seconds < 60 then
		return seconds .. "s"
	end
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	return ("%dm %02ds"):format(m, s)
end

return Theme
