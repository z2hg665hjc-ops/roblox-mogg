--[[
	MapBuilder.lua
	Procedurally builds the hub world on server start. Everything lives under
	Workspace.Hub so it's easy to inspect, and the build is idempotent.

	Layout (top-down, +Z is "south"):
	          [MOG STAGE]        [LEADERBOARD]
	  [GYM]     ( plaza + fountain )     [UPGRADE SHOPS x5]
	      [MIRROR]                  [CREDIT CHECK]
	                 [REBIRTH ALTAR]
	Surrounded by a neon night skyline.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local MapBuilder = {}

local C = {
	Ground = Color3.fromRGB(24, 24, 31),
	Plaza = Color3.fromRGB(46, 46, 60),
	PlazaLight = Color3.fromRGB(66, 66, 84),
	Path = Color3.fromRGB(58, 58, 72),
	Metal = Color3.fromRGB(34, 34, 44),
	MetalLight = Color3.fromRGB(120, 124, 140),
	Marble = Color3.fromRGB(205, 200, 222),
	MarbleDark = Color3.fromRGB(70, 64, 92),
	Pink = Color3.fromRGB(255, 70, 190),
	Cyan = Color3.fromRGB(80, 220, 255),
	Purple = Color3.fromRGB(175, 95, 255),
	Gold = Color3.fromRGB(255, 200, 60),
	Green = Color3.fromRGB(90, 255, 150),
	Orange = Color3.fromRGB(255, 120, 90),
	White = Color3.fromRGB(245, 245, 255),
	Black = Color3.fromRGB(10, 10, 14),
}

local STAT_COLORS = {
	Jawline = C.Orange,
	Hair = C.Gold,
	Physique = C.Cyan,
	Aura = C.Purple,
	Fit = C.Pink,
}

local NEON_CYCLE = { C.Pink, C.Cyan, C.Purple, C.Gold }

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

local function ball(diameter, position, props)
	props = props or {}
	props.Shape = Enum.PartType.Ball
	props.Size = Vector3.new(diameter, diameter, diameter)
	props.CFrame = CFrame.new(position)
	return part(props)
end

local function neon(props)
	props.Material = Enum.Material.Neon
	props.CastShadow = false
	return part(props)
end

local function pointLight(parent, color, range, brightness)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range or 20
	light.Brightness = brightness or 1.5
	light.Shadows = false
	light.Parent = parent
	return light
end

local function sparkles(parent, color, rate, speed)
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.Rate = rate or 12
	e.Lifetime = NumberRange.new(1, 1.8)
	e.Speed = NumberRange.new(speed or 2, (speed or 2) + 1.5)
	e.SpreadAngle = Vector2.new(35, 35)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Acceleration = Vector3.new(0, 1.5, 0)
	e.Parent = parent
	return e
end

-- SurfaceGui sign with a title and optional subtitle on a face.
local function sign(target, face, title, color, subtitle, pixelsPerStud)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign"
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud or 40
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.Parent = target

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = subtitle and UDim2.new(0.92, 0, 0.55, 0) or UDim2.new(0.92, 0, 0.8, 0)
	titleLabel.Position = subtitle and UDim2.new(0.04, 0, 0.08, 0) or UDim2.new(0.04, 0, 0.1, 0)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Text = title
	titleLabel.TextScaled = true
	titleLabel.TextColor3 = color
	titleLabel.TextStrokeTransparency = 0.6
	titleLabel.Parent = gui

	if subtitle then
		local subLabel = Instance.new("TextLabel")
		subLabel.Name = "Subtitle"
		subLabel.BackgroundTransparency = 1
		subLabel.Size = UDim2.new(0.9, 0, 0.22, 0)
		subLabel.Position = UDim2.new(0.05, 0, 0.66, 0)
		subLabel.Font = Enum.Font.GothamMedium
		subLabel.Text = subtitle
		subLabel.TextScaled = true
		subLabel.TextColor3 = Color3.fromRGB(215, 215, 230)
		subLabel.TextTransparency = 0.1
		subLabel.Parent = gui
	end
	return gui
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

local function bobAndSpin(inst, height, seconds)
	local up = TweenService:Create(
		inst,
		TweenInfo.new(seconds or 2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = inst.Position + Vector3.new(0, height or 1, 0) }
	)
	up:Play()
	local spin = TweenService:Create(
		inst,
		TweenInfo.new((seconds or 2.5) * 3, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, false),
		{ Orientation = inst.Orientation + Vector3.new(0, 359, 0) }
	)
	spin:Play()
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
		Material = Enum.Material.Slate,
		Parent = g,
	})
	-- Invisible boundary so nobody falls into the void.
	for _, def in ipairs({
		{ Vector3.new(4, 120, 560), Vector3.new(280, 60, 0) },
		{ Vector3.new(4, 120, 560), Vector3.new(-280, 60, 0) },
		{ Vector3.new(560, 120, 4), Vector3.new(0, 60, 280) },
		{ Vector3.new(560, 120, 4), Vector3.new(0, 60, -280) },
	}) do
		part({
			Name = "Barrier",
			Size = def[1],
			Position = def[2],
			Transparency = 1,
			CastShadow = false,
			Parent = g,
		})
	end
end

local function buildPlaza(root)
	local f = folder("Plaza", root)
	neon({
		Name = "OuterRim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.5, 124, 124),
		CFrame = CFrame.new(0, 0.25, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = C.Purple,
		Transparency = 0.15,
		Parent = f,
	})
	cylinder(0.5, 120, Vector3.new(0, 0.35, 0), { Name = "PlazaFloor", Color = C.Plaza, Material = Enum.Material.Marble, Parent = f })
	neon({
		Name = "InnerRim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 44, 44),
		CFrame = CFrame.new(0, 0.62, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = C.Cyan,
		Transparency = 0.25,
		Parent = f,
	})
	cylinder(0.3, 40, Vector3.new(0, 0.7, 0), { Name = "InnerFloor", Color = C.PlazaLight, Material = Enum.Material.Marble, Parent = f })

	-- Fountain
	local fountain = folder("Fountain", f)
	cylinder(1.6, 18, Vector3.new(0, 1.65, 0), { Name = "Basin", Color = C.Marble, Material = Enum.Material.Marble, Parent = fountain })
	local water = cylinder(0.6, 16, Vector3.new(0, 2.2, 0), {
		Name = "Water",
		Color = Color3.fromRGB(90, 180, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.35,
		Reflectance = 0.3,
		CanCollide = false,
		Parent = fountain,
	})
	local spray = Instance.new("ParticleEmitter")
	spray.Color = ColorSequence.new(Color3.fromRGB(190, 230, 255))
	spray.Rate = 40
	spray.Lifetime = NumberRange.new(1.0, 1.4)
	spray.Speed = NumberRange.new(9, 12)
	spray.SpreadAngle = Vector2.new(12, 12)
	spray.Size = NumberSequence.new(0.35)
	spray.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	spray.Acceleration = Vector3.new(0, -14, 0)
	spray.LightEmission = 0.4
	spray.Parent = water
	cylinder(7, 2.4, Vector3.new(0, 5.9, 0), { Name = "Pillar", Color = C.Marble, Material = Enum.Material.Marble, Parent = fountain })
	cylinder(0.8, 8, Vector3.new(0, 6.5, 0), { Name = "Tier", Color = C.Marble, Material = Enum.Material.Marble, Parent = fountain })
	local orb = ball(
		3.2,
		Vector3.new(0, 10.5, 0),
		{ Name = "Orb", Color = C.Cyan, Material = Enum.Material.Neon, CanCollide = false, Parent = fountain }
	)
	pointLight(orb, C.Cyan, 44, 2.2)
	sparkles(orb, C.Cyan, 14, 2)
	bobAndSpin(orb, 0.8, 3)

	-- Spawns
	local spawns = folder("Spawns", root)
	for i = 0, 3 do
		local angle = math.rad(45 + i * 90)
		local pos = Vector3.new(math.cos(angle) * 32, 0, math.sin(angle) * 32)
		neon({
			Name = "SpawnGlow",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, 8.5, 8.5),
			CFrame = CFrame.new(pos + Vector3.new(0, 0.95, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = C.Pink,
			Transparency = 0.3,
			CanCollide = false,
			Parent = spawns,
		})
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn" .. (i + 1)
		spawn.Anchored = true
		spawn.Size = Vector3.new(7, 0.6, 7)
		spawn.Position = pos + Vector3.new(0, 1.15, 0)
		spawn.Color = C.PlazaLight
		spawn.Material = Enum.Material.Metal
		spawn.TopSurface = Enum.SurfaceType.Smooth
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Parent = spawns
	end

	-- Benches
	for i = 0, 5 do
		local angle = math.rad(i * 60 + 30)
		local pos = Vector3.new(math.cos(angle) * 48, 0, math.sin(angle) * 48)
		local cf = lookAtGround(pos, ORIGIN)
		part({
			Name = "Bench",
			Size = Vector3.new(6, 0.5, 1.6),
			CFrame = cf * CFrame.new(0, 1.6, 0),
			Color = C.MarbleDark,
			Material = Enum.Material.WoodPlanks,
			Parent = f,
		})
		for _, dx in ipairs({ -2.4, 2.4 }) do
			part({
				Name = "BenchLeg",
				Size = Vector3.new(0.5, 1.4, 1.4),
				CFrame = cf * CFrame.new(dx, 0.7, 0),
				Color = C.Metal,
				Material = Enum.Material.Metal,
				Parent = f,
			})
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
			neon({
				Name = "PathEdge",
				Size = Vector3.new(0.3, 0.2, length),
				CFrame = cf * CFrame.new(-5.1, 0.25, 0),
				Color = C.Pink,
				Transparency = 0.45,
				CanCollide = false,
				Parent = f,
			})
			neon({
				Name = "PathEdge",
				Size = Vector3.new(0.3, 0.2, length),
				CFrame = cf * CFrame.new(5.1, 0.25, 0),
				Color = C.Cyan,
				Transparency = 0.45,
				CanCollide = false,
				Parent = f,
			})
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
		Color = C.Metal,
		Material = Enum.Material.Metal,
		Parent = f,
	})
	-- Steps toward the plaza
	part({
		Name = "Step",
		Size = Vector3.new(14, 2, 2),
		Position = Vector3.new(0, 1, -74),
		Color = C.MetalLight,
		Material = Enum.Material.Metal,
		Parent = f,
	})
	part({
		Name = "Step",
		Size = Vector3.new(14, 1, 2),
		Position = Vector3.new(0, 0.5, -72),
		Color = C.MetalLight,
		Material = Enum.Material.Metal,
		Parent = f,
	})
	-- Edge neon
	for _, def in ipairs({
		{ Vector3.new(48.4, 0.5, 0.6), Vector3.new(0, 3.1, -75.1) },
		{ Vector3.new(48.4, 0.5, 0.6), Vector3.new(0, 3.1, -94.9) },
		{ Vector3.new(0.6, 0.5, 20), Vector3.new(-24.1, 3.1, -85) },
		{ Vector3.new(0.6, 0.5, 20), Vector3.new(24.1, 3.1, -85) },
	}) do
		neon({ Name = "StageEdge", Size = def[1], Position = def[2], Color = C.Pink, CanCollide = false, Parent = f })
	end
	neon({
		Name = "StageCenter",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 9, 9),
		CFrame = CFrame.new(0, 3.1, -85) * CFrame.Angles(0, 0, math.rad(90)),
		Color = C.Pink,
		Transparency = 0.35,
		CanCollide = false,
		Parent = f,
	})

	-- Backdrop + title
	local backdrop = part({
		Name = "Backdrop",
		Size = Vector3.new(54, 26, 2),
		CFrame = lookAtGround(Vector3.new(0, 0, -97), ORIGIN) * CFrame.new(0, 13, 0),
		Color = C.Metal,
		Material = Enum.Material.Metal,
		Parent = f,
	})
	sign(backdrop, Enum.NormalId.Front, "MOG STAGE", C.Pink, "show them what you built", 30)
	for _, dx in ipairs({ -26.6, 26.6 }) do
		neon({
			Name = "BackdropEdge",
			Size = Vector3.new(0.6, 26, 0.8),
			Position = Vector3.new(dx, 13, -96.2),
			Color = C.Cyan,
			CanCollide = false,
			Parent = f,
		})
	end
	neon({
		Name = "BackdropTop",
		Size = Vector3.new(54.6, 0.6, 0.8),
		Position = Vector3.new(0, 26.2, -96.2),
		Color = C.Cyan,
		CanCollide = false,
		Parent = f,
	})

	-- Spotlights
	local i = 0
	for _, x in ipairs({ -28, 28 }) do
		for _, z in ipairs({ -78, -85, -92 }) do
			i += 1
			part({
				Name = "SpotPost",
				Size = Vector3.new(0.8, 14, 0.8),
				Position = Vector3.new(x, 7, z),
				Color = C.Metal,
				Material = Enum.Material.Metal,
				Parent = f,
			})
			local headPos = Vector3.new(x, 14.6, z)
			local head = part({
				Name = "SpotHead",
				Size = Vector3.new(1.8, 1.8, 2.4),
				CFrame = CFrame.lookAt(headPos, center + Vector3.new(0, 3, 0)),
				Color = C.Metal,
				Material = Enum.Material.Metal,
				Parent = f,
			})
			local color = NEON_CYCLE[(i % #NEON_CYCLE) + 1]
			neon({
				Name = "SpotLens",
				Size = Vector3.new(1.4, 1.4, 0.3),
				CFrame = head.CFrame * CFrame.new(0, 0, -1.25),
				Color = color,
				CanCollide = false,
				Parent = f,
			})
			local spot = Instance.new("SpotLight")
			spot.Angle = 42
			spot.Brightness = 5
			spot.Range = 48
			spot.Color = color
			spot.Face = Enum.NormalId.Front
			spot.Shadows = true
			spot.Parent = head
		end
	end
end

local function buildGym(root)
	local f = folder("Gym", root)
	local cx = -80
	part({
		Name = "Mat",
		Size = Vector3.new(44, 0.5, 44),
		Position = Vector3.new(cx, 0.25, 0),
		Color = Color3.fromRGB(38, 38, 46),
		Material = Enum.Material.Fabric,
		Parent = f,
	})
	for _, def in ipairs({
		{ Vector3.new(44.4, 0.3, 0.4), Vector3.new(cx, 0.6, -22.1) },
		{ Vector3.new(44.4, 0.3, 0.4), Vector3.new(cx, 0.6, 22.1) },
		{ Vector3.new(0.4, 0.3, 44), Vector3.new(cx - 22.1, 0.6, 0) },
		{ Vector3.new(0.4, 0.3, 44), Vector3.new(cx + 22.1, 0.6, 0) },
	}) do
		neon({ Name = "MatEdge", Size = def[1], Position = def[2], Color = C.Cyan, Transparency = 0.2, CanCollide = false, Parent = f })
	end
	local wall = part({
		Name = "GymWall",
		Size = Vector3.new(44, 14, 2),
		CFrame = lookAtGround(Vector3.new(cx, 0, -24), Vector3.new(cx, 0, 0)) * CFrame.new(0, 7, 0),
		Color = C.Metal,
		Material = Enum.Material.Metal,
		Parent = f,
	})
	sign(wall, Enum.NormalId.Front, "THE GYM", C.Cyan, "every rep pays. E to lift.", 30)
	neon({
		Name = "GymWallTop",
		Size = Vector3.new(44.4, 0.5, 0.8),
		Position = Vector3.new(cx, 14.2, -23.2),
		Color = C.Cyan,
		CanCollide = false,
		Parent = f,
	})

	-- Squat rack + barbell
	local rx, rz = cx - 12, -8
	for _, dx in ipairs({ -3, 3 }) do
		part({
			Name = "RackPost",
			Size = Vector3.new(1, 10, 1),
			Position = Vector3.new(rx + dx, 5, rz),
			Color = C.Metal,
			Material = Enum.Material.Metal,
			Parent = f,
		})
	end
	part({
		Name = "RackTop",
		Size = Vector3.new(7, 0.6, 0.6),
		Position = Vector3.new(rx, 10.2, rz),
		Color = C.Metal,
		Material = Enum.Material.Metal,
		Parent = f,
	})
	local barbell = part({
		Name = "Barbell",
		Size = Vector3.new(10, 0.35, 0.35),
		Position = Vector3.new(rx, 6, rz),
		Color = C.MetalLight,
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
			Color = C.Black,
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
			Color = C.Metal,
			Material = Enum.Material.Metal,
			Parent = f,
		})
	end
	local pullBar = part({
		Name = "PullUpBar",
		Size = Vector3.new(7, 0.4, 0.4),
		Position = Vector3.new(px, 9, pz),
		Color = C.MetalLight,
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
		Color = Color3.fromRGB(125, 30, 45),
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
			Color = C.Metal,
			Material = Enum.Material.Metal,
			Parent = f,
		})
	end
	for _, dx in ipairs({ -2.6, 2.6 }) do
		part({
			Name = "BenchPost",
			Size = Vector3.new(0.6, 5, 0.6),
			Position = Vector3.new(bx + dx, 2.5, bz - 1.5),
			Color = C.Metal,
			Material = Enum.Material.Metal,
			Parent = f,
		})
	end
	part({
		Name = "BenchBar",
		Size = Vector3.new(8, 0.3, 0.3),
		Position = Vector3.new(bx, 5, bz - 1.5),
		Color = C.MetalLight,
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
		Color = C.Metal,
		Material = Enum.Material.Metal,
		Parent = f,
	})
	for _, dx in ipairs({ -5.5, 5.5 }) do
		part({
			Name = "RackLeg",
			Size = Vector3.new(0.6, 2.5, 2),
			Position = Vector3.new(dx0 + dx, 1.25, dz),
			Color = C.Metal,
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
			Color = C.MetalLight,
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
				Color = C.Black,
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
		local color = STAT_COLORS[statName] or C.White
		local cz = zs[i]
		part({
			Name = "StallPad",
			Size = Vector3.new(14, 0.4, 16),
			Position = Vector3.new(82, 0.2, cz),
			Color = C.PlazaLight,
			Material = Enum.Material.Pavement,
			Parent = f,
		})
		local back = part({
			Name = "StallWall",
			Size = Vector3.new(1.2, 10, 14),
			CFrame = lookAtGround(Vector3.new(88, 0, cz), Vector3.new(0, 0, cz)) * CFrame.new(0, 5, 0),
			Color = C.Metal,
			Material = Enum.Material.Metal,
			Parent = f,
		})
		sign(back, Enum.NormalId.Front, def.DisplayName:upper(), color, "upgrade station", 36)
		local counter = part({
			Name = statName .. "Counter",
			Size = Vector3.new(2.4, 3.2, 10),
			Position = Vector3.new(78, 1.6, cz),
			Color = Color3.fromRGB(52, 52, 66),
			Material = Enum.Material.Marble,
			Tag = "ShopStall",
			Attributes = { StatName = statName },
			Parent = f,
		})
		prompt(counter, "Browse Upgrades", def.DisplayName .. " Shop", 0, 11)
		neon({
			Name = "CounterTrim",
			Size = Vector3.new(0.3, 0.3, 10),
			Position = Vector3.new(76.7, 3.25, cz),
			Color = color,
			CanCollide = false,
			Parent = f,
		})
		part({
			Name = "Canopy",
			Size = Vector3.new(14, 0.5, 16),
			Position = Vector3.new(82, 9.5, cz),
			Color = Color3.fromRGB(30, 30, 40),
			Material = Enum.Material.SmoothPlastic,
			Parent = f,
		})
		neon({
			Name = "CanopyTrim",
			Size = Vector3.new(0.4, 0.4, 16),
			Position = Vector3.new(75.2, 9.3, cz),
			Color = color,
			CanCollide = false,
			Parent = f,
		})
		for _, dz in ipairs({ -7.5, 7.5 }) do
			part({
				Name = "CanopyPost",
				Size = Vector3.new(0.6, 9.5, 0.6),
				Position = Vector3.new(75.5, 4.75, cz + dz),
				Color = C.Metal,
				Material = Enum.Material.Metal,
				Parent = f,
			})
		end
		local orb = ball(
			1.6,
			Vector3.new(78, 4.4, cz),
			{ Name = "DisplayOrb", Color = color, Material = Enum.Material.Neon, CanCollide = false, Parent = f }
		)
		pointLight(orb, color, 18, 1.6)
		bobAndSpin(orb, 0.4, 2 + i * 0.3)
	end
	-- Zone sign
	part({
		Name = "ShopSignPost",
		Size = Vector3.new(1, 16, 1),
		Position = Vector3.new(70, 8, -48),
		Color = C.Metal,
		Material = Enum.Material.Metal,
		Parent = f,
	})
	local board = part({
		Name = "ShopSign",
		Size = Vector3.new(12, 4, 0.8),
		CFrame = lookAtGround(Vector3.new(70, 0, -48), ORIGIN) * CFrame.new(0, 15, 0),
		Color = C.Black,
		Material = Enum.Material.SmoothPlastic,
		Parent = f,
	})
	sign(board, Enum.NormalId.Front, "UPGRADES", C.Gold, nil, 40)
end

local function buildMirror(root)
	local f = folder("Mirror", root)
	local base = lookAtGround(Vector3.new(-46, 0, 62), ORIGIN)
	part({
		Name = "MirrorBase",
		Size = Vector3.new(12, 1, 4),
		CFrame = base * CFrame.new(0, 0.5, 0),
		Color = C.MarbleDark,
		Material = Enum.Material.Marble,
		Parent = f,
	})
	local frame = part({
		Name = "MirrorFrame",
		Size = Vector3.new(9, 15, 1.2),
		CFrame = base * CFrame.new(0, 8.5, 0),
		Color = Color3.fromRGB(205, 172, 92),
		Material = Enum.Material.Metal,
		Parent = f,
	})
	local glass = part({
		Name = "MirrorGlass",
		Size = Vector3.new(7.6, 13.4, 0.4),
		CFrame = frame.CFrame * CFrame.new(0, 0, -0.5),
		Color = Color3.fromRGB(215, 230, 255),
		Material = Enum.Material.Glass,
		Reflectance = 1,
		Transparency = 0.05,
		Tag = "RatingMirror",
		Parent = f,
	})
	prompt(glass, "Check Your Mog", "The Mirror", 0.6, 11)
	pointLight(glass, C.Pink, 22, 1.4)
	neon({
		Name = "MirrorTrim",
		Size = Vector3.new(0.35, 15.2, 0.35),
		CFrame = frame.CFrame * CFrame.new(-4.8, 0, -0.3),
		Color = C.Pink,
		CanCollide = false,
		Parent = f,
	})
	neon({
		Name = "MirrorTrim",
		Size = Vector3.new(0.35, 15.2, 0.35),
		CFrame = frame.CFrame * CFrame.new(4.8, 0, -0.3),
		Color = C.Cyan,
		CanCollide = false,
		Parent = f,
	})
	local header = part({
		Name = "MirrorHeader",
		Size = Vector3.new(11, 2.4, 0.8),
		CFrame = base * CFrame.new(0, 17.5, 0),
		Color = C.Black,
		Material = Enum.Material.SmoothPlastic,
		Parent = f,
	})
	sign(header, Enum.NormalId.Front, "RATE YOURSELF", C.Pink, nil, 40)
end

local function buildKiosk(root)
	local f = folder("CreditCheck", root)
	local base = lookAtGround(Vector3.new(46, 0, 62), ORIGIN)
	local body = part({
		Name = "KioskBody",
		Size = Vector3.new(7, 9, 4),
		CFrame = base * CFrame.new(0, 4.5, 0),
		Color = Color3.fromRGB(28, 28, 38),
		Material = Enum.Material.Metal,
		Tag = "CreditCheckKiosk",
		Parent = f,
	})
	prompt(body, "Run Credit Check", "Credit Check", 0.6, 12)
	local screen = part({
		Name = "KioskScreen",
		Size = Vector3.new(5.2, 3.6, 0.3),
		CFrame = body.CFrame * CFrame.new(0, 1.5, -2.15),
		Color = Color3.fromRGB(10, 16, 13),
		Material = Enum.Material.SmoothPlastic,
		Parent = f,
	})
	sign(screen, Enum.NormalId.Front, "CREDIT CHECK", C.Green, "verify score - get paid", 48)
	part({
		Name = "Keypad",
		Size = Vector3.new(3, 1.6, 0.2),
		CFrame = body.CFrame * CFrame.new(0, -1.2, -2.1),
		Color = Color3.fromRGB(60, 60, 74),
		Material = Enum.Material.SmoothPlastic,
		Parent = f,
	})
	neon({
		Name = "Slot",
		Size = Vector3.new(3.5, 0.3, 0.2),
		CFrame = body.CFrame * CFrame.new(0, -2.6, -2.1),
		Color = C.Green,
		CanCollide = false,
		Parent = f,
	})
	local roof = part({
		Name = "KioskRoof",
		Size = Vector3.new(8, 1.8, 4.4),
		CFrame = body.CFrame * CFrame.new(0, 5.4, 0),
		Color = C.Black,
		Material = Enum.Material.SmoothPlastic,
		Parent = f,
	})
	sign(roof, Enum.NormalId.Front, "$ CREDITS $", C.Green, nil, 48)
	neon({
		Name = "RoofTrim",
		Size = Vector3.new(8.2, 0.4, 4.6),
		CFrame = body.CFrame * CFrame.new(0, 4.4, 0),
		Color = C.Green,
		CanCollide = false,
		Parent = f,
	})
	local lamp = neon({
		Name = "KioskLamp",
		Size = Vector3.new(0.6, 0.6, 0.6),
		CFrame = body.CFrame * CFrame.new(0, 3.8, -2.6),
		Color = C.Green,
		CanCollide = false,
		Parent = f,
	})
	pointLight(lamp, C.Green, 20, 1.8)
end

local function buildAltar(root)
	local f = folder("Altar", root)
	local center = Vector3.new(0, 0, 92)
	cylinder(1, 22, center + Vector3.new(0, 0.5, 0), { Name = "Tier1", Color = C.MarbleDark, Material = Enum.Material.Marble, Parent = f })
	neon({
		Name = "Ring",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 17.5, 17.5),
		CFrame = CFrame.new(center + Vector3.new(0, 1.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = C.Purple,
		Transparency = 0.2,
		CanCollide = false,
		Parent = f,
	})
	cylinder(1, 16, center + Vector3.new(0, 1.5, 0), { Name = "Tier2", Color = C.MarbleDark, Material = Enum.Material.Marble, Parent = f })
	neon({
		Name = "Ring",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 11.5, 11.5),
		CFrame = CFrame.new(center + Vector3.new(0, 2.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = C.Purple,
		Transparency = 0.2,
		CanCollide = false,
		Parent = f,
	})
	cylinder(
		1,
		10,
		center + Vector3.new(0, 2.5, 0),
		{ Name = "Tier3", Color = Color3.fromRGB(58, 48, 86), Material = Enum.Material.Marble, Parent = f }
	)

	for i = 0, 3 do
		local angle = math.rad(45 + i * 90)
		local pos = center + Vector3.new(math.cos(angle) * 13, 0, math.sin(angle) * 13)
		part({
			Name = "AltarPillar",
			Size = Vector3.new(1.6, 14, 1.6),
			Position = pos + Vector3.new(0, 7, 0),
			Color = C.MarbleDark,
			Material = Enum.Material.Marble,
			Parent = f,
		})
		local cap = ball(
			2,
			pos + Vector3.new(0, 15, 0),
			{ Name = "PillarCap", Color = C.Purple, Material = Enum.Material.Neon, CanCollide = false, Parent = f }
		)
		pointLight(cap, C.Purple, 18, 1.2)
	end

	local orb = ball(
		4.5,
		center + Vector3.new(0, 9, 0),
		{ Name = "RebirthOrb", Color = C.Purple, Material = Enum.Material.Neon, CanCollide = false, Tag = "RebirthAltar", Parent = f }
	)
	prompt(orb, "Rebirth", "Altar of Rebirth", 1, 14)
	pointLight(orb, C.Purple, 40, 3)
	sparkles(orb, C.Purple, 22, 3)
	bobAndSpin(orb, 1.2, 2.5)

	local header = part({
		Name = "AltarHeader",
		Size = Vector3.new(16, 3.2, 0.8),
		CFrame = lookAtGround(center + Vector3.new(0, 0, 12), ORIGIN) * CFrame.new(0, 18, 0),
		Color = C.Black,
		Material = Enum.Material.SmoothPlastic,
		Parent = f,
	})
	sign(header, Enum.NormalId.Front, "REBIRTH", C.Purple, "reset. come back stronger.", 40)
end

local function buildLeaderboard(root)
	local f = folder("Leaderboard", root)
	local base = lookAtGround(Vector3.new(-56, 0, -58), ORIGIN)
	for _, dx in ipairs({ -9, 9 }) do
		part({
			Name = "BoardPost",
			Size = Vector3.new(1.2, 9, 1.2),
			CFrame = base * CFrame.new(dx, 4.5, 0),
			Color = C.Metal,
			Material = Enum.Material.Metal,
			Parent = f,
		})
	end
	local screen = part({
		Name = "LeaderboardBoard",
		Size = Vector3.new(24, 15, 1.2),
		CFrame = base * CFrame.new(0, 15.5, 0),
		Color = Color3.fromRGB(12, 12, 18),
		Material = Enum.Material.SmoothPlastic,
		Tag = "LeaderboardBoard",
		Parent = f,
	})
	prompt(screen, "Open Leaderboard", "Top Moggers", 0, 18)
	for _, def in ipairs({
		{ Vector3.new(24.6, 0.5, 1.4), Vector3.new(0, 7.75, 0) },
		{ Vector3.new(24.6, 0.5, 1.4), Vector3.new(0, -7.75, 0) },
		{ Vector3.new(0.5, 15.6, 1.4), Vector3.new(-12.3, 0, 0) },
		{ Vector3.new(0.5, 15.6, 1.4), Vector3.new(12.3, 0, 0) },
	}) do
		neon({
			Name = "BoardTrim",
			Size = def[1],
			CFrame = screen.CFrame * CFrame.new(def[2]),
			Color = C.Gold,
			CanCollide = false,
			Parent = f,
		})
	end

	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Brightness = 1.6
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
		row.BackgroundColor3 = (i % 2 == 0) and Color3.fromRGB(22, 22, 32) or Color3.fromRGB(28, 28, 40)
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
			Size = Vector3.new(0.7, 11, 0.7),
			Position = pos + Vector3.new(0, 5.5, 0),
			Color = C.Metal,
			Material = Enum.Material.Metal,
			Parent = f,
		})
		local color = NEON_CYCLE[(i % #NEON_CYCLE) + 1]
		local head = ball(
			1.8,
			pos + Vector3.new(0, 11.6, 0),
			{ Name = "LampHead", Color = color, Material = Enum.Material.Neon, CanCollide = false, Parent = f }
		)
		pointLight(head, color, 30, 1.6)
	end
end

local function buildSkyline(root)
	local f = folder("Skyline", root)
	local rng = Random.new(7)
	local grays = {
		Color3.fromRGB(30, 30, 40),
		Color3.fromRGB(38, 36, 50),
		Color3.fromRGB(26, 28, 36),
		Color3.fromRGB(44, 42, 58),
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
			Color = grays[rng:NextInteger(1, #grays)],
			Material = Enum.Material.Concrete,
			Parent = f,
		})
		local accent = NEON_CYCLE[rng:NextInteger(1, #NEON_CYCLE)]
		neon({
			Name = "RoofNeon",
			Size = Vector3.new(w + 0.4, 0.5, 0.6),
			CFrame = cf * CFrame.new(0, h / 2 + 0.25, -d / 2),
			Color = accent,
			Transparency = 0.1,
			CanCollide = false,
			Parent = f,
		})
		for _, dx in ipairs({ -w * 0.28, w * 0.28 }) do
			neon({
				Name = "Window",
				Size = Vector3.new(0.5, h * 0.7, 0.3),
				CFrame = cf * CFrame.new(dx, 0, -d / 2 - 0.1),
				Color = accent,
				Transparency = 0.55,
				CanCollide = false,
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
