--[[
	MapBuilder.lua
	Procedurally builds the hub on server start. Clean showroom look: white
	marble, light concrete, charcoal trims, one mint accent used sparingly,
	warm white lamps. The only glowing object is the rebirth orb.

	Layout (top-down, +Z is "south"):
	          [MOG STAGE]        [LEADERBOARD]
	  [GYM]     ( plaza + fountain )     [UPGRADE SHOPS x5]
	      [MIRROR]                  [CREDIT CHECK]
	                 [REBIRTH ALTAR]
	Ringed by a quiet light-gray skyline.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local MapBuilder = {}

local C = {
	Ground = Color3.fromRGB(190, 190, 196),
	Plaza = Color3.fromRGB(232, 232, 236),
	PlazaMid = Color3.fromRGB(205, 205, 212),
	Path = Color3.fromRGB(172, 172, 180),
	Stone = Color3.fromRGB(98, 98, 108),
	Charcoal = Color3.fromRGB(46, 46, 54),
	White = Color3.fromRGB(246, 246, 249),
	Steel = Color3.fromRGB(150, 154, 166),
	Wood = Color3.fromRGB(148, 108, 70),
	Accent = Color3.fromRGB(86, 186, 172),
	Gold = Color3.fromRGB(205, 170, 92),
	Purple = Color3.fromRGB(150, 112, 220),
	Green = Color3.fromRGB(88, 180, 122),
	Glass = Color3.fromRGB(200, 220, 236),
	Water = Color3.fromRGB(118, 178, 220),
	Grass = Color3.fromRGB(98, 150, 86),
	Screen = Color3.fromRGB(18, 20, 24),
}

local STAT_COLORS = {
	Jawline = Color3.fromRGB(226, 130, 104),
	Hair = Color3.fromRGB(214, 176, 84),
	Physique = Color3.fromRGB(104, 176, 220),
	Aura = Color3.fromRGB(158, 122, 226),
	Fit = Color3.fromRGB(226, 116, 156),
}

local WARM_LIGHT = Color3.fromRGB(255, 238, 210)
local ORIGIN = Vector3.new(0, 0, 0)

-- ---------------------------------------------------------------------------
-- Primitive helpers
-- ---------------------------------------------------------------------------

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide = true
	if props.Shape then
		p.Shape = props.Shape
	end
	for key, value in pairs(props) do
		if key ~= "Parent" and key ~= "Tag" and key ~= "Attributes" and key ~= "Shape" then
			p[key] = value
		end
	end
	if props.Tag then
		CollectionService:AddTag(p, props.Tag)
	end
	if props.Attributes then
		for k, v in pairs(props.Attributes) do
			p:SetAttribute(k, v)
		end
	end
	p.Parent = props.Parent
	return p
end

-- Vertical cylinder (Roblox cylinders point along X by default).
local function cylinder(height, diameter, position, props)
	props = props or {}
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(height, diameter, diameter)
	props.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	return part(props)
end

local function disc(thickness, diameter, position, color, material, parent, extra)
	local props = { Color = color, Material = material or Enum.Material.SmoothPlastic, Parent = parent }
	for k, v in pairs(extra or {}) do
		props[k] = v
	end
	return cylinder(thickness, diameter, position, props)
end

local function ball(diameter, position, props)
	props = props or {}
	props.Shape = Enum.PartType.Ball
	props.Size = Vector3.new(diameter, diameter, diameter)
	props.CFrame = CFrame.new(position)
	return part(props)
end

local function pointLight(parent, color, range, brightness)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range or 20
	light.Brightness = brightness or 0.8
	light.Shadows = false
	light.Parent = parent
	return light
end

-- Board with dark-on-light (or custom) text. Clean signage.
local function board(size, cframe, parent, title, subtitle, titleColor, boardColor, ppStud)
	local b = part({
		Name = "Board",
		Size = size,
		CFrame = cframe,
		Color = boardColor or C.White,
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = ppStud or 40
	gui.LightInfluence = 0.6
	gui.Brightness = 1
	gui.Parent = b

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = subtitle and UDim2.new(0.9, 0, 0.5, 0) or UDim2.new(0.9, 0, 0.7, 0)
	titleLabel.Position = subtitle and UDim2.new(0.05, 0, 0.1, 0) or UDim2.new(0.05, 0, 0.15, 0)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Text = title
	titleLabel.TextScaled = true
	titleLabel.TextColor3 = titleColor or C.Charcoal
	titleLabel.Parent = gui

	if subtitle then
		local subLabel = Instance.new("TextLabel")
		subLabel.Name = "Subtitle"
		subLabel.BackgroundTransparency = 1
		subLabel.Size = UDim2.new(0.86, 0, 0.2, 0)
		subLabel.Position = UDim2.new(0.07, 0, 0.66, 0)
		subLabel.Font = Enum.Font.GothamMedium
		subLabel.Text = subtitle
		subLabel.TextScaled = true
		subLabel.TextColor3 = C.Stone
		subLabel.Parent = gui
	end
	return b
end

local function prompt(target, actionText, objectText, holdDuration, distance)
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = actionText
	pp.ObjectText = objectText or ""
	pp.HoldDuration = holdDuration or 0
	pp.MaxActivationDistance = distance or 10
	pp.RequiresLineOfSight = false
	pp.KeyboardKeyCode = Enum.KeyCode.E
	pp.Parent = target
	return pp
end

local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function lookAtGround(pos, target)
	return CFrame.lookAt(Vector3.new(pos.X, 0, pos.Z), Vector3.new(target.X, 0, target.Z))
end

local function bob(inst, height, seconds)
	TweenService:Create(
		inst,
		TweenInfo.new(seconds or 3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = inst.Position + Vector3.new(0, height or 0.6, 0) }
	):Play()
end

-- Thin flat trim line (replaces neon strips).
local function trim(size, cframe, color, parent)
	return part({
		Name = "Trim",
		Size = size,
		CFrame = cframe,
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		Parent = parent,
	})
end

-- ---------------------------------------------------------------------------
-- Sections
-- ---------------------------------------------------------------------------

local function buildGround(root)
	local g = folder("Ground", root)
	part({
		Name = "Baseplate",
		Size = Vector3.new(560, 4, 560),
		Position = Vector3.new(0, -2, 0),
		Color = C.Ground,
		Material = Enum.Material.Concrete,
		Parent = g,
	})
	for _, def in ipairs({
		{ Vector3.new(4, 120, 560), Vector3.new(280, 60, 0) },
		{ Vector3.new(4, 120, 560), Vector3.new(-280, 60, 0) },
		{ Vector3.new(560, 120, 4), Vector3.new(0, 60, 280) },
		{ Vector3.new(560, 120, 4), Vector3.new(0, 60, -280) },
	}) do
		part({ Name = "Barrier", Size = def[1], Position = def[2], Transparency = 1, CastShadow = false, Parent = g })
	end
end

local function buildPlaza(root)
	local f = folder("Plaza", root)
	disc(0.5, 124, Vector3.new(0, 0.25, 0), C.Stone, Enum.Material.SmoothPlastic, f, { Name = "OuterRim" })
	disc(0.5, 120, Vector3.new(0, 0.35, 0), C.Plaza, Enum.Material.Marble, f, { Name = "PlazaFloor" })
	disc(0.3, 44, Vector3.new(0, 0.62, 0), C.Stone, Enum.Material.SmoothPlastic, f, { Name = "InnerRim" })
	disc(0.3, 40, Vector3.new(0, 0.7, 0), C.PlazaMid, Enum.Material.Granite, f, { Name = "InnerFloor" })

	-- Fountain
	local fountain = folder("Fountain", f)
	disc(1.6, 18, Vector3.new(0, 1.65, 0), C.White, Enum.Material.Marble, fountain, { Name = "Basin" })
	local water = disc(0.6, 16, Vector3.new(0, 2.2, 0), C.Water, Enum.Material.Glass, fountain, {
		Name = "Water",
		Transparency = 0.4,
		Reflectance = 0.2,
		CanCollide = false,
	})
	local spray = Instance.new("ParticleEmitter")
	spray.Color = ColorSequence.new(Color3.fromRGB(225, 240, 255))
	spray.Rate = 22
	spray.Lifetime = NumberRange.new(1.0, 1.3)
	spray.Speed = NumberRange.new(8, 10)
	spray.SpreadAngle = Vector2.new(10, 10)
	spray.Size = NumberSequence.new(0.3)
	spray.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	spray.Acceleration = Vector3.new(0, -14, 0)
	spray.LightEmission = 0.1
	spray.Parent = water
	cylinder(7, 2.4, Vector3.new(0, 5.9, 0), { Name = "Pillar", Color = C.White, Material = Enum.Material.Marble, Parent = fountain })
	disc(0.8, 8, Vector3.new(0, 6.5, 0), C.White, Enum.Material.Marble, fountain, { Name = "Tier" })
	local orb = ball(
		3,
		Vector3.new(0, 10.4, 0),
		{ Name = "Orb", Color = C.White, Material = Enum.Material.Marble, CanCollide = false, Parent = fountain }
	)
	bob(orb, 0.5, 4)

	-- Spawns
	local spawns = folder("Spawns", root)
	for i = 0, 3 do
		local angle = math.rad(45 + i * 90)
		local pos = Vector3.new(math.cos(angle) * 32, 0, math.sin(angle) * 32)
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn" .. (i + 1)
		spawn.Anchored = true
		spawn.Size = Vector3.new(7, 0.5, 7)
		spawn.Position = pos + Vector3.new(0, 1.1, 0)
		spawn.Color = C.PlazaMid
		spawn.Material = Enum.Material.Granite
		spawn.TopSurface = Enum.SurfaceType.Smooth
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Parent = spawns
		trim(Vector3.new(7.4, 0.2, 7.4), CFrame.new(pos + Vector3.new(0, 0.95, 0)), C.Stone, spawns)
	end

	-- Benches and planters alternate around the plaza.
	for i = 0, 11 do
		local angle = math.rad(i * 30 + 15)
		local pos = Vector3.new(math.cos(angle) * 48, 0, math.sin(angle) * 48)
		local cf = lookAtGround(pos, ORIGIN)
		if i % 2 == 0 then
			part({
				Name = "Bench",
				Size = Vector3.new(6, 0.5, 1.6),
				CFrame = cf * CFrame.new(0, 1.6, 0),
				Color = C.Wood,
				Material = Enum.Material.WoodPlanks,
				Parent = f,
			})
			for _, dx in ipairs({ -2.4, 2.4 }) do
				part({
					Name = "BenchLeg",
					Size = Vector3.new(0.5, 1.4, 1.4),
					CFrame = cf * CFrame.new(dx, 0.7, 0),
					Color = C.Charcoal,
					Material = Enum.Material.Metal,
					Parent = f,
				})
			end
		else
			part({
				Name = "Planter",
				Size = Vector3.new(3.2, 1.6, 3.2),
				CFrame = cf * CFrame.new(0, 1.4, 0),
				Color = C.Charcoal,
				Material = Enum.Material.Concrete,
				Parent = f,
			})
			part({
				Name = "Soil",
				Size = Vector3.new(2.8, 0.3, 2.8),
				CFrame = cf * CFrame.new(0, 2.3, 0),
				Color = C.Grass,
				Material = Enum.Material.Grass,
				CanCollide = false,
				Parent = f,
			})
			cylinder(
				4.5,
				0.7,
				(cf * CFrame.new(0, 4.5, 0)).Position,
				{ Name = "Trunk", Color = C.Wood, Material = Enum.Material.Wood, CanCollide = false, Parent = f }
			)
			ball(
				4.6,
				(cf * CFrame.new(0, 8.2, 0)).Position,
				{ Name = "Canopy", Color = C.Grass, Material = Enum.Material.Grass, CanCollide = false, Parent = f }
			)
		end
	end
end

local function buildPaths(root)
	local f = folder("Paths", root)
	local targets = {
		Vector3.new(0, 0, -74),
		Vector3.new(0, 0, 80),
		Vector3.new(74, 0, 0),
		Vector3.new(-42, 0, 57),
		Vector3.new(42, 0, 57),
		Vector3.new(-52, 0, -54),
	}
	for _, target in ipairs(targets) do
		local dir = (target - ORIGIN).Unit
		local start = dir * 56
		local length = (target - start).Magnitude
		if length > 2 then
			local mid = (start + target) / 2
			local cf = CFrame.lookAt(mid, target)
			part({
				Name = "Path",
				Size = Vector3.new(10, 0.3, length),
				CFrame = cf * CFrame.new(0, 0.15, 0),
				Color = C.Path,
				Material = Enum.Material.Pavement,
				Parent = f,
			})
			trim(Vector3.new(0.4, 0.34, length), cf * CFrame.new(-5.2, 0.17, 0), C.Stone, f)
			trim(Vector3.new(0.4, 0.34, length), cf * CFrame.new(5.2, 0.17, 0), C.Stone, f)
		end
	end
end

local function buildStage(root)
	local f = folder("Stage", root)
	local center = Vector3.new(0, 0, -85)
	part({
		Name = "Platform",
		Size = Vector3.new(48, 3, 20),
		Position = center + Vector3.new(0, 1.5, 0),
		Color = C.Charcoal,
		Material = Enum.Material.Concrete,
		Parent = f,
	})
	part({
		Name = "Step",
		Size = Vector3.new(14, 2, 2),
		Position = Vector3.new(0, 1, -74),
		Color = C.Stone,
		Material = Enum.Material.Concrete,
		Parent = f,
	})
	part({
		Name = "Step",
		Size = Vector3.new(14, 1, 2),
		Position = Vector3.new(0, 0.5, -72),
		Color = C.Stone,
		Material = Enum.Material.Concrete,
		Parent = f,
	})
	-- White edge trim
	trim(Vector3.new(48.4, 0.2, 0.5), CFrame.new(0, 3.1, -75.1), C.White, f)
	trim(Vector3.new(48.4, 0.2, 0.5), CFrame.new(0, 3.1, -94.9), C.White, f)
	trim(Vector3.new(0.5, 0.2, 20), CFrame.new(-24.1, 3.1, -85), C.White, f)
	trim(Vector3.new(0.5, 0.2, 20), CFrame.new(24.1, 3.1, -85), C.White, f)
	-- Two duel spots
	for _, dx in ipairs({ -5, 5 }) do
		disc(
			0.12,
			6.5,
			center + Vector3.new(dx, 3.08, 0),
			C.White,
			Enum.Material.SmoothPlastic,
			f,
			{ Name = "DuelRing", CanCollide = false }
		)
		disc(
			0.14,
			5.5,
			center + Vector3.new(dx, 3.08, 0),
			C.Charcoal,
			Enum.Material.Concrete,
			f,
			{ Name = "DuelRingInner", CanCollide = false }
		)
	end
	disc(0.12, 3, center + Vector3.new(0, 3.08, 0), C.Accent, Enum.Material.SmoothPlastic, f, { Name = "CenterMark", CanCollide = false })

	-- Backdrop: white wall, charcoal title
	local backCF = lookAtGround(Vector3.new(0, 0, -97), ORIGIN)
	part({
		Name = "Backdrop",
		Size = Vector3.new(54, 26, 2),
		CFrame = backCF * CFrame.new(0, 13, 0),
		Color = C.White,
		Material = Enum.Material.Concrete,
		Parent = f,
	})
	board(Vector3.new(40, 9, 0.4), backCF * CFrame.new(0, 17, -1.2), f, "MOG OFF", "the stage settles it", C.Charcoal, C.White, 30)
	trim(Vector3.new(54.4, 0.6, 2.4), CFrame.new(0, 26.2, -97), C.Charcoal, f)
	for _, dx in ipairs({ -27.2, 27.2 }) do
		part({
			Name = "BackdropPillar",
			Size = Vector3.new(1.2, 26, 2.4),
			Position = Vector3.new(dx, 13, -97),
			Color = C.Charcoal,
			Material = Enum.Material.Concrete,
			Parent = f,
		})
	end

	-- Two soft white stage lights
	for _, x in ipairs({ -22, 22 }) do
		part({
			Name = "LightPost",
			Size = Vector3.new(0.7, 14, 0.7),
			Position = Vector3.new(x, 7, -78),
			Color = C.Charcoal,
			Material = Enum.Material.Metal,
			Parent = f,
		})
		local headPos = Vector3.new(x, 14.4, -78)
		local head = part({
			Name = "LightHead",
			Size = Vector3.new(1.6, 1.6, 2.2),
			CFrame = CFrame.lookAt(headPos, center + Vector3.new(0, 4, 0)),
			Color = C.Charcoal,
			Material = Enum.Material.Metal,
			Parent = f,
		})
		local spot = Instance.new("SpotLight")
		spot.Angle = 55
		spot.Brightness = 1.2
		spot.Range = 40
		spot.Color = WARM_LIGHT
		spot.Face = Enum.NormalId.Front
		spot.Shadows = true
		spot.Parent = head
	end
end

local function buildGym(root)
	local f = folder("Gym", root)
	local cx = -80
	part({
		Name = "Mat",
		Size = Vector3.new(44, 0.5, 44),
		Position = Vector3.new(cx, 0.25, 0),
		Color = C.Charcoal,
		Material = Enum.Material.Fabric,
		Parent = f,
	})
	trim(Vector3.new(44.6, 0.2, 44.6), CFrame.new(cx, 0.1, 0), C.Stone, f)
	local wallCF = lookAtGround(Vector3.new(cx, 0, -24), Vector3.new(cx, 0, 0))
	part({
		Name = "GymWall",
		Size = Vector3.new(44, 14, 2),
		CFrame = wallCF * CFrame.new(0, 7, 0),
		Color = C.White,
		Material = Enum.Material.Concrete,
		Parent = f,
	})
	board(Vector3.new(30, 6, 0.4), wallCF * CFrame.new(0, 9, -1.2), f, "THE GYM", "every rep pays  |  press E", C.Charcoal, C.White, 36)
	trim(Vector3.new(44.4, 0.6, 2.4), CFrame.new(cx, 14.2, -24), C.Charcoal, f)

	-- Squat rack + barbell
	local rx, rz = cx - 12, -8
	for _, dx in ipairs({ -3, 3 }) do
		part({
			Name = "RackPost",
			Size = Vector3.new(1, 10, 1),
			Position = Vector3.new(rx + dx, 5, rz),
			Color = C.Charcoal,
			Material = Enum.Material.Metal,
			Parent = f,
		})
	end
	part({
		Name = "RackTop",
		Size = Vector3.new(7, 0.6, 0.6),
		Position = Vector3.new(rx, 10.2, rz),
		Color = C.Charcoal,
		Material = Enum.Material.Metal,
		Parent = f,
	})
	local barbell = part({
		Name = "Barbell",
		Size = Vector3.new(10, 0.35, 0.35),
		Position = Vector3.new(rx, 6, rz),
		Color = C.Steel,
		Material = Enum.Material.Metal,
		Tag = "GymBar",
		Parent = f,
	})
	prompt(barbell, "Do a Rep", "Barbell", 0, 9)
	for _, dx in ipairs({ -4.6, -3.9, 3.9, 4.6 }) do
		part({
			Name = "Plate",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.6, 3.2, 3.2),
			CFrame = CFrame.new(rx + dx, 6, rz),
			Color = C.Charcoal,
			Material = Enum.Material.Metal,
			CanCollide = false,
			Parent = f,
		})
	end

	-- Pull-up bar
	local px, pz = cx + 12, -8
	for _, dx in ipairs({ -3, 3 }) do
		part({
			Name = "PullPost",
			Size = Vector3.new(0.8, 9, 0.8),
			Position = Vector3.new(px + dx, 4.5, pz),
			Color = C.Charcoal,
			Material = Enum.Material.Metal,
			Parent = f,
		})
	end
	local pullBar = part({
		Name = "PullUpBar",
		Size = Vector3.new(7, 0.4, 0.4),
		Position = Vector3.new(px, 9, pz),
		Color = C.Steel,
		Material = Enum.Material.Metal,
		Tag = "GymBar",
		Parent = f,
	})
	prompt(pullBar, "Do a Rep", "Pull-Up Bar", 0, 9)

	-- Bench
	local bx, bz = cx, 8
	local bench = part({
		Name = "Bench",
		Size = Vector3.new(2.2, 0.6, 6),
		Position = Vector3.new(bx, 1.7, bz),
		Color = Color3.fromRGB(70, 70, 80),
		Material = Enum.Material.Fabric,
		Tag = "GymBar",
		Parent = f,
	})
	prompt(bench, "Do a Rep", "Bench Press", 0, 9)
	for _, dz in ipairs({ -2.4, 2.4 }) do
		part({
			Name = "BenchLeg",
			Size = Vector3.new(0.5, 1.4, 0.5),
			Position = Vector3.new(bx, 0.7, bz + dz),
			Color = C.Charcoal,
			Material = Enum.Material.Metal,
			Parent = f,
		})
	end
	for _, dx in ipairs({ -2.6, 2.6 }) do
		part({
			Name = "BenchPost",
			Size = Vector3.new(0.6, 5, 0.6),
			Position = Vector3.new(bx + dx, 2.5, bz - 1.5),
			Color = C.Charcoal,
			Material = Enum.Material.Metal,
			Parent = f,
		})
	end
	part({
		Name = "BenchBar",
		Size = Vector3.new(8, 0.3, 0.3),
		Position = Vector3.new(bx, 5, bz - 1.5),
		Color = C.Steel,
		Material = Enum.Material.Metal,
		CanCollide = false,
		Parent = f,
	})

	-- Dumbbell rack
	local dx0, dz = cx, 18
	part({
		Name = "DumbbellRack",
		Size = Vector3.new(12, 0.6, 2),
		Position = Vector3.new(dx0, 2.5, dz),
		Color = C.Charcoal,
		Material = Enum.Material.Metal,
		Parent = f,
	})
	for _, dx in ipairs({ -5.5, 5.5 }) do
		part({
			Name = "RackLeg",
			Size = Vector3.new(0.6, 2.5, 2),
			Position = Vector3.new(dx0 + dx, 1.25, dz),
			Color = C.Charcoal,
			Material = Enum.Material.Metal,
			Parent = f,
		})
	end
	for i = -2, 2 do
		local x = dx0 + i * 2
		part({
			Name = "DumbbellHandle",
			Size = Vector3.new(1.6, 0.3, 0.3),
			Position = Vector3.new(x, 3.1, dz),
			Color = C.Steel,
			Material = Enum.Material.Metal,
			CanCollide = false,
			Parent = f,
		})
		for _, off in ipairs({ -0.75, 0.75 }) do
			part({
				Name = "DumbbellPlate",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.5, 1.2, 1.2),
				CFrame = CFrame.new(x + off, 3.1, dz),
				Color = C.Charcoal,
				Material = Enum.Material.Metal,
				CanCollide = false,
				Parent = f,
			})
		end
	end
end

local function buildShops(root)
	local f = folder("Shops", root)
	local zs = { -36, -18, 0, 18, 36 }
	for i, statName in ipairs(Constants.STAT_ORDER) do
		local def = Constants.STATS[statName]
		local color = STAT_COLORS[statName] or C.Charcoal
		local cz = zs[i]
		part({
			Name = "StallPad",
			Size = Vector3.new(14, 0.4, 16),
			Position = Vector3.new(82, 0.2, cz),
			Color = C.PlazaMid,
			Material = Enum.Material.Granite,
			Parent = f,
		})
		local wallCF = lookAtGround(Vector3.new(88, 0, cz), Vector3.new(0, 0, cz))
		part({
			Name = "StallWall",
			Size = Vector3.new(1.2, 10, 14),
			CFrame = wallCF * CFrame.new(0, 5, 0),
			Color = C.White,
			Material = Enum.Material.Concrete,
			Parent = f,
		})
		board(
			Vector3.new(10, 3.6, 0.3),
			wallCF * CFrame.new(0, 7, -0.75),
			f,
			def.DisplayName:upper(),
			"upgrade station",
			color,
			C.White,
			40
		)
		local counter = part({
			Name = statName .. "Counter",
			Size = Vector3.new(2.4, 3.2, 10),
			Position = Vector3.new(78, 1.6, cz),
			Color = C.Charcoal,
			Material = Enum.Material.Marble,
			Tag = "ShopStall",
			Attributes = { StatName = statName },
			Parent = f,
		})
		prompt(counter, "Browse Upgrades", def.DisplayName .. " Shop", 0, 11)
		trim(Vector3.new(0.3, 0.3, 10), CFrame.new(76.7, 3.25, cz), color, f)
		part({
			Name = "Canopy",
			Size = Vector3.new(14, 0.5, 16),
			Position = Vector3.new(82, 9.5, cz),
			Color = C.White,
			Material = Enum.Material.SmoothPlastic,
			Parent = f,
		})
		trim(Vector3.new(0.3, 0.5, 16), CFrame.new(75.15, 9.5, cz), color, f)
		for _, dz in ipairs({ -7.5, 7.5 }) do
			part({
				Name = "CanopyPost",
				Size = Vector3.new(0.6, 9.5, 0.6),
				Position = Vector3.new(75.5, 4.75, cz + dz),
				Color = C.Stone,
				Material = Enum.Material.Metal,
				Parent = f,
			})
		end
		local orb = ball(
			1.5,
			Vector3.new(78, 4.3, cz),
			{ Name = "DisplayOrb", Color = color, Material = Enum.Material.SmoothPlastic, CanCollide = false, Parent = f }
		)
		bob(orb, 0.3, 2.6 + i * 0.3)
	end
	part({
		Name = "ShopSignPost",
		Size = Vector3.new(0.8, 16, 0.8),
		Position = Vector3.new(70, 8, -48),
		Color = C.Charcoal,
		Material = Enum.Material.Metal,
		Parent = f,
	})
	board(
		Vector3.new(12, 4, 0.8),
		lookAtGround(Vector3.new(70, 0, -48), ORIGIN) * CFrame.new(0, 15, 0),
		f,
		"UPGRADES",
		nil,
		C.Charcoal,
		C.White,
		40
	)
end

local function buildMirror(root)
	local f = folder("Mirror", root)
	local base = lookAtGround(Vector3.new(-46, 0, 62), ORIGIN)
	part({
		Name = "MirrorBase",
		Size = Vector3.new(12, 1, 4),
		CFrame = base * CFrame.new(0, 0.5, 0),
		Color = C.Stone,
		Material = Enum.Material.Concrete,
		Parent = f,
	})
	local frame = part({
		Name = "MirrorFrame",
		Size = Vector3.new(9, 15, 1.2),
		CFrame = base * CFrame.new(0, 8.5, 0),
		Color = C.Gold,
		Material = Enum.Material.Metal,
		Parent = f,
	})
	local glass = part({
		Name = "MirrorGlass",
		Size = Vector3.new(7.6, 13.4, 0.4),
		CFrame = frame.CFrame * CFrame.new(0, 0, -0.5),
		Color = C.Glass,
		Material = Enum.Material.Glass,
		Reflectance = 1,
		Transparency = 0.05,
		Tag = "RatingMirror",
		Parent = f,
	})
	prompt(glass, "Check Your Mog", "The Mirror", 0.6, 11)
	pointLight(glass, WARM_LIGHT, 18, 0.6)
	board(Vector3.new(11, 2.4, 0.8), base * CFrame.new(0, 17.5, 0), f, "RATE YOURSELF", nil, C.Charcoal, C.White, 40)
end

local function buildKiosk(root)
	local f = folder("CreditCheck", root)
	local base = lookAtGround(Vector3.new(46, 0, 62), ORIGIN)
	local body = part({
		Name = "KioskBody",
		Size = Vector3.new(7, 9, 4),
		CFrame = base * CFrame.new(0, 4.5, 0),
		Color = C.Charcoal,
		Material = Enum.Material.Metal,
		Tag = "CreditCheckKiosk",
		Parent = f,
	})
	prompt(body, "Run Credit Check", "Credit Check", 0.6, 12)
	board(
		Vector3.new(5.2, 3.6, 0.3),
		body.CFrame * CFrame.new(0, 1.5, -2.15),
		f,
		"CREDIT CHECK",
		"verify score  |  get paid",
		C.Green,
		C.Screen,
		48
	)
	part({
		Name = "Keypad",
		Size = Vector3.new(3, 1.6, 0.2),
		CFrame = body.CFrame * CFrame.new(0, -1.2, -2.1),
		Color = C.Stone,
		Material = Enum.Material.SmoothPlastic,
		Parent = f,
	})
	trim(Vector3.new(3.5, 0.3, 0.2), body.CFrame * CFrame.new(0, -2.6, -2.1), C.Accent, f)
	board(Vector3.new(8, 1.8, 4.4), body.CFrame * CFrame.new(0, 5.4, 0), f, "CREDITS", nil, C.Charcoal, C.White, 48)
end

local function buildAltar(root)
	local f = folder("Altar", root)
	local center = Vector3.new(0, 0, 92)
	disc(1, 22, center + Vector3.new(0, 0.5, 0), C.Stone, Enum.Material.Marble, f, { Name = "Tier1" })
	disc(1, 16, center + Vector3.new(0, 1.5, 0), C.PlazaMid, Enum.Material.Marble, f, { Name = "Tier2" })
	disc(1, 10, center + Vector3.new(0, 2.5, 0), C.White, Enum.Material.Marble, f, { Name = "Tier3" })
	disc(0.12, 10.6, center + Vector3.new(0, 3.05, 0), C.Purple, Enum.Material.SmoothPlastic, f, { Name = "AltarRing", CanCollide = false })
	disc(0.14, 9.4, center + Vector3.new(0, 3.05, 0), C.White, Enum.Material.Marble, f, { Name = "AltarRingInner", CanCollide = false })

	for i = 0, 3 do
		local angle = math.rad(45 + i * 90)
		local pos = center + Vector3.new(math.cos(angle) * 13, 0, math.sin(angle) * 13)
		part({
			Name = "AltarPillar",
			Size = Vector3.new(1.6, 14, 1.6),
			Position = pos + Vector3.new(0, 7, 0),
			Color = C.White,
			Material = Enum.Material.Marble,
			Parent = f,
		})
		ball(
			2,
			pos + Vector3.new(0, 15, 0),
			{ Name = "PillarCap", Color = C.White, Material = Enum.Material.Marble, CanCollide = false, Parent = f }
		)
	end

	-- The one glowing object in the world.
	local orb = ball(4.2, center + Vector3.new(0, 9, 0), {
		Name = "RebirthOrb",
		Color = C.Purple,
		Material = Enum.Material.Neon,
		Transparency = 0.15,
		CanCollide = false,
		Tag = "RebirthAltar",
		Parent = f,
	})
	prompt(orb, "Rebirth", "Altar of Rebirth", 1, 14)
	pointLight(orb, C.Purple, 26, 1.0)
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(C.Purple)
	e.Rate = 6
	e.Lifetime = NumberRange.new(1.5, 2.5)
	e.Speed = NumberRange.new(1, 1.6)
	e.SpreadAngle = Vector2.new(30, 30)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	e.LightEmission = 0.5
	e.Acceleration = Vector3.new(0, 1, 0)
	e.Parent = orb
	bob(orb, 1, 3)

	board(
		Vector3.new(16, 3.2, 0.8),
		lookAtGround(center + Vector3.new(0, 0, 12), ORIGIN) * CFrame.new(0, 18, 0),
		f,
		"REBIRTH",
		"reset. come back stronger.",
		C.Purple,
		C.White,
		40
	)
end

local function buildLeaderboard(root)
	local f = folder("Leaderboard", root)
	local base = lookAtGround(Vector3.new(-56, 0, -58), ORIGIN)
	for _, dx in ipairs({ -9, 9 }) do
		part({
			Name = "BoardPost",
			Size = Vector3.new(1.2, 9, 1.2),
			CFrame = base * CFrame.new(dx, 4.5, 0),
			Color = C.Charcoal,
			Material = Enum.Material.Metal,
			Parent = f,
		})
	end
	local screen = part({
		Name = "LeaderboardBoard",
		Size = Vector3.new(24, 15, 1.2),
		CFrame = base * CFrame.new(0, 15.5, 0),
		Color = C.Screen,
		Material = Enum.Material.SmoothPlastic,
		Tag = "LeaderboardBoard",
		Parent = f,
	})
	prompt(screen, "Open Leaderboard", "Top Moggers", 0, 18)
	for _, def in ipairs({
		{ Vector3.new(24.8, 0.4, 1.4), Vector3.new(0, 7.7, 0) },
		{ Vector3.new(24.8, 0.4, 1.4), Vector3.new(0, -7.7, 0) },
		{ Vector3.new(0.4, 15.4, 1.4), Vector3.new(-12.2, 0, 0) },
		{ Vector3.new(0.4, 15.4, 1.4), Vector3.new(12.2, 0, 0) },
	}) do
		trim(def[1], screen.CFrame * CFrame.new(def[2]), C.White, f)
	end

	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Brightness = 1
	gui.Parent = screen

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0.13, 0)
	title.Position = UDim2.new(0, 0, 0.02, 0)
	title.Font = Enum.Font.GothamBlack
	title.Text = "TOP MOGGERS"
	title.TextScaled = true
	title.TextColor3 = C.Gold
	title.Parent = gui

	local entries = Instance.new("Frame")
	entries.Name = "Entries"
	entries.BackgroundTransparency = 1
	entries.Size = UDim2.new(0.92, 0, 0.8, 0)
	entries.Position = UDim2.new(0.04, 0, 0.17, 0)
	entries.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = entries

	for i = 1, 10 do
		local row = Instance.new("Frame")
		row.Name = "Row" .. i
		row.LayoutOrder = i
		row.BackgroundColor3 = (i % 2 == 0) and Color3.fromRGB(26, 28, 34) or Color3.fromRGB(34, 36, 44)
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, 0, 0.09, 0)
		row.Parent = entries
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = row

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "Name"
		nameLabel.BackgroundTransparency = 1
		nameLabel.Size = UDim2.new(0.7, -10, 1, 0)
		nameLabel.Position = UDim2.new(0, 10, 0, 0)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Text = ("%d.  ---"):format(i)
		nameLabel.TextScaled = true
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextColor3 = Color3.fromRGB(120, 120, 140)
		nameLabel.Parent = row

		local scoreLabel = Instance.new("TextLabel")
		scoreLabel.Name = "Score"
		scoreLabel.BackgroundTransparency = 1
		scoreLabel.Size = UDim2.new(0.3, -10, 1, 0)
		scoreLabel.Position = UDim2.new(0.7, 0, 0, 0)
		scoreLabel.Font = Enum.Font.GothamBlack
		scoreLabel.Text = ""
		scoreLabel.TextScaled = true
		scoreLabel.TextXAlignment = Enum.TextXAlignment.Right
		scoreLabel.TextColor3 = C.White
		scoreLabel.Parent = row
	end
end

local function buildLamps(root)
	local f = folder("Lamps", root)
	for i = 0, 9 do
		local angle = math.rad(i * 36)
		local pos = Vector3.new(math.cos(angle) * 62, 0, math.sin(angle) * 62)
		part({
			Name = "LampPost",
			Size = Vector3.new(0.6, 11, 0.6),
			Position = pos + Vector3.new(0, 5.5, 0),
			Color = C.Charcoal,
			Material = Enum.Material.Metal,
			Parent = f,
		})
		local head = ball(
			1.6,
			pos + Vector3.new(0, 11.5, 0),
			{ Name = "LampHead", Color = C.White, Material = Enum.Material.SmoothPlastic, CanCollide = false, Parent = f }
		)
		pointLight(head, WARM_LIGHT, 22, 0.6)
	end
end

local function buildSkyline(root)
	local f = folder("Skyline", root)
	local rng = Random.new(7)
	local shades = {
		Color3.fromRGB(214, 214, 220),
		Color3.fromRGB(228, 228, 232),
		Color3.fromRGB(198, 200, 208),
		Color3.fromRGB(236, 236, 240),
	}
	for i = 1, 40 do
		local angle = (i / 40) * math.pi * 2 + rng:NextNumber(-0.05, 0.05)
		local radius = 175 + rng:NextNumber(0, 55)
		local w = rng:NextNumber(14, 34)
		local d = rng:NextNumber(14, 34)
		local h = rng:NextNumber(35, 130)
		local pos = Vector3.new(math.cos(angle) * radius, h / 2, math.sin(angle) * radius)
		local cf = CFrame.lookAt(pos, Vector3.new(0, h / 2, 0))
		part({
			Name = "Building",
			Size = Vector3.new(w, h, d),
			CFrame = cf,
			Color = shades[rng:NextInteger(1, #shades)],
			Material = Enum.Material.Concrete,
			Parent = f,
		})
		-- Dark glass window bands
		local bands = math.floor(h / 12)
		for b = 1, bands do
			local y = -h / 2 + b * 12 - 4
			part({
				Name = "WindowBand",
				Size = Vector3.new(w * 0.86, 3.2, 0.25),
				CFrame = cf * CFrame.new(0, y, -d / 2 - 0.1),
				Color = Color3.fromRGB(60, 66, 80),
				Material = Enum.Material.Glass,
				Reflectance = 0.15,
				CanCollide = false,
				CastShadow = false,
				Parent = f,
			})
		end
	end
end

-- ---------------------------------------------------------------------------

function MapBuilder.Build()
	if Workspace:FindFirstChild("Hub") then
		return Workspace.Hub
	end
	local root = folder("Hub", Workspace)
	buildGround(root)
	buildPlaza(root)
	buildPaths(root)
	buildStage(root)
	buildGym(root)
	buildShops(root)
	buildMirror(root)
	buildKiosk(root)
	buildAltar(root)
	buildLeaderboard(root)
	buildLamps(root)
	buildSkyline(root)
	return root
end

return MapBuilder
