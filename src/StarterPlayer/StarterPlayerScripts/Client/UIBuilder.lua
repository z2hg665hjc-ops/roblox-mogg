--[[
	UIBuilder.lua
	Tiny declarative helpers so every controller builds UI the same way:
	rounded panels, glowing strokes, animated buttons, progress bars, and
	open/close animations for panels.
]]

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent:WaitForChild("Theme"))

local UI = {}

local clickSound = nil

local function getClickSound()
	if clickSound then
		return clickSound
	end
	clickSound = Instance.new("Sound")
	clickSound.Name = "UIClick"
	clickSound.SoundId = Theme.Sounds.Click
	clickSound.Volume = 0.35
	clickSound.Parent = SoundService
	return clickSound
end

function UI.Click()
	local s = getClickSound()
	if s then
		s:Play()
	end
end

function UI.Create(className, props, children)
	local inst = Instance.new(className)
	local parent = nil
	for key, value in pairs(props or {}) do
		if key == "Parent" then
			parent = value
		else
			inst[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function UI.Corner(parent, radius)
	return UI.Create("UICorner", { CornerRadius = UDim.new(0, radius or Theme.Corner), Parent = parent })
end

function UI.Stroke(parent, color, thickness, transparency)
	return UI.Create("UIStroke", {
		Color = color or Theme.Colors.Stroke,
		Thickness = thickness or 1.5,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function UI.Gradient(parent, c1, c2, rotation)
	return UI.Create("UIGradient", {
		Color = ColorSequence.new(c1, c2),
		Rotation = rotation or 90,
		Parent = parent,
	})
end

function UI.Padding(parent, px, py)
	py = py or px
	return UI.Create("UIPadding", {
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		PaddingTop = UDim.new(0, py),
		PaddingBottom = UDim.new(0, py),
		Parent = parent,
	})
end

function UI.List(parent, padding, direction, hAlign, vAlign)
	return UI.Create("UIListLayout", {
		Padding = UDim.new(0, padding or 8),
		FillDirection = direction or Enum.FillDirection.Vertical,
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left,
		VerticalAlignment = vAlign or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

function UI.Text(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = Theme.Font,
		TextColor3 = Theme.Colors.Text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		RichText = true,
		Text = "",
	}
	for k, v in pairs(props or {}) do
		defaults[k] = v
	end
	return UI.Create("TextLabel", defaults)
end

-- Frame with rounded corners, stroke and background.
function UI.Box(props)
	local defaults = {
		BackgroundColor3 = Theme.Colors.Panel,
		BorderSizePixel = 0,
	}
	for k, v in pairs(props or {}) do
		if k ~= "Corner" and k ~= "StrokeColor" and k ~= "NoStroke" then
			defaults[k] = v
		end
	end
	local frame = UI.Create("Frame", defaults)
	UI.Corner(frame, props and props.Corner or Theme.Corner)
	if not (props and props.NoStroke) then
		UI.Stroke(frame, props and props.StrokeColor or Theme.Colors.Stroke, 1.5, 0.2)
	end
	return frame
end

-- Animated button. props.OnClick(button) fires on activation.
function UI.Button(props)
	local color = props.Color or Theme.Colors.Accent
	local button = UI.Create("TextButton", {
		Name = props.Name or "Button",
		Size = props.Size or UDim2.fromOffset(140, 44),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = props.Font or Theme.FontBlack,
		Text = props.Text or "",
		TextColor3 = props.TextColor or Theme.Colors.Text,
		TextSize = props.TextSize or 18,
		TextScaled = props.TextScaled or false,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	})
	UI.Corner(button, props.Corner or Theme.Corner)
	local stroke = UI.Stroke(button, Color3.new(1, 1, 1), 1.2, 0.85)
	UI.Gradient(button, Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 205), 90)

	local baseSize = button.Size
	local enabled = true

	local function hover(isIn)
		if not enabled then
			return
		end
		TweenService:Create(button, Theme.Tween.Fast, {
			Size = isIn and (baseSize + UDim2.fromOffset(4, 2)) or baseSize,
		}):Play()
		TweenService:Create(stroke, Theme.Tween.Fast, { Transparency = isIn and 0.45 or 0.85 }):Play()
	end

	button.MouseEnter:Connect(function()
		hover(true)
	end)
	button.MouseLeave:Connect(function()
		hover(false)
	end)
	button.MouseButton1Down:Connect(function()
		if enabled then
			TweenService:Create(button, Theme.Tween.Fast, { Size = baseSize - UDim2.fromOffset(4, 2) }):Play()
		end
	end)
	button.MouseButton1Up:Connect(function()
		hover(true)
	end)
	button.Activated:Connect(function()
		if not enabled then
			return
		end
		UI.Click()
		if props.OnClick then
			props.OnClick(button)
		end
	end)

	local api = {
		Instance = button,
	}
	function api.SetEnabled(isEnabled)
		enabled = isEnabled
		TweenService:Create(button, Theme.Tween.Fast, {
			BackgroundColor3 = isEnabled and color or Theme.Colors.Disabled,
			TextColor3 = isEnabled and (props.TextColor or Theme.Colors.Text) or Theme.Colors.TextDim,
		}):Play()
	end
	function api.SetText(text)
		button.Text = text
	end
	function api.SetColor(newColor)
		color = newColor
		if enabled then
			TweenService:Create(button, Theme.Tween.Fast, { BackgroundColor3 = newColor }):Play()
		end
	end
	function api.SetSize(size)
		baseSize = size
		button.Size = size
	end
	return api
end

-- Horizontal progress bar. Returns api with Set(alpha, labelText).
function UI.ProgressBar(props)
	local frame = UI.Create("Frame", {
		Name = props.Name or "Progress",
		Size = props.Size or UDim2.new(1, 0, 0, 18),
		Position = props.Position,
		BackgroundColor3 = Theme.Colors.Background,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	})
	UI.Corner(frame, 9)
	UI.Stroke(frame, Theme.Colors.Stroke, 1, 0.4)
	local fill = UI.Create("Frame", {
		Name = "Fill",
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = props.Color or Theme.Colors.Accent,
		BorderSizePixel = 0,
		Parent = frame,
	})
	UI.Corner(fill, 9)
	UI.Gradient(fill, Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 190), 0)
	local label = UI.Text({
		Name = "Label",
		Size = UDim2.new(1, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Font,
		TextSize = 12,
		TextStrokeTransparency = 0.5,
		Parent = frame,
	})
	local api = { Instance = frame }
	function api.Set(alpha, text)
		alpha = math.clamp(alpha or 0, 0, 1)
		TweenService:Create(fill, Theme.Tween.Normal, { Size = UDim2.new(alpha, 0, 1, 0) }):Play()
		if text then
			label.Text = text
		end
	end
	function api.SetColor(color)
		fill.BackgroundColor3 = color
	end
	return api
end

-- Centered modal panel with title + close button. Hidden by default.
-- Returns api: Frame, Content, Open(), Close(), Toggle(), IsOpen()
function UI.Panel(props)
	local width = props.Width or 520
	local height = props.Height or 420

	local dim = UI.Create("TextButton", {
		Name = (props.Name or "Panel") .. "Dim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
		ZIndex = 10,
		Parent = props.Parent,
	})

	local frame = UI.Box({
		Name = props.Name or "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = Theme.Colors.Panel,
		StrokeColor = props.Accent or Theme.Colors.Accent,
		ZIndex = 11,
		Parent = dim,
	})
	local scale = UI.Create("UIScale", { Scale = 0.85, Parent = frame })

	-- Header
	local header = UI.Create("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = Theme.Colors.PanelLight,
		BorderSizePixel = 0,
		ZIndex = 12,
		Parent = frame,
	})
	UI.Corner(header, Theme.Corner)
	-- Square off the bottom corners of the header.
	UI.Create("Frame", {
		Size = UDim2.new(1, 0, 0, Theme.Corner),
		Position = UDim2.new(0, 0, 1, -Theme.Corner),
		BackgroundColor3 = Theme.Colors.PanelLight,
		BorderSizePixel = 0,
		ZIndex = 12,
		Parent = header,
	})
	UI.Create("Frame", {
		Name = "AccentBar",
		Size = UDim2.new(1, 0, 0, 3),
		Position = UDim2.new(0, 0, 1, -3),
		BackgroundColor3 = props.Accent or Theme.Colors.Accent,
		BorderSizePixel = 0,
		ZIndex = 13,
		Parent = header,
	})
	UI.Text({
		Name = "Title",
		Size = UDim2.new(1, -120, 1, 0),
		Position = UDim2.fromOffset(20, 0),
		Font = Theme.FontBlack,
		TextSize = 24,
		Text = props.Title or "",
		TextColor3 = props.Accent or Theme.Colors.Accent,
		ZIndex = 13,
		Parent = header,
	})
	if props.Subtitle then
		UI.Text({
			Name = "Subtitle",
			Size = UDim2.new(1, -120, 0, 16),
			Position = UDim2.new(0, 20, 1, -20),
			Font = Theme.FontMedium,
			TextSize = 12,
			Text = props.Subtitle,
			TextColor3 = Theme.Colors.TextDim,
			ZIndex = 13,
			Parent = header,
		})
	end

	local content = UI.Create("Frame", {
		Name = "Content",
		Size = UDim2.new(1, -32, 1, -58 - 32),
		Position = UDim2.fromOffset(16, 58 + 16),
		BackgroundTransparency = 1,
		ZIndex = 12,
		Parent = frame,
	})

	local api = {
		Frame = frame,
		Content = content,
		Dim = dim,
	}
	local isOpen = false

	function api.IsOpen()
		return isOpen
	end

	function api.Open()
		if isOpen then
			return
		end
		isOpen = true
		dim.Visible = true
		dim.BackgroundTransparency = 1
		scale.Scale = 0.85
		TweenService:Create(dim, Theme.Tween.Normal, { BackgroundTransparency = 0.45 }):Play()
		TweenService:Create(scale, Theme.Tween.Pop, { Scale = 1 }):Play()
		if props.OnOpen then
			props.OnOpen()
		end
	end

	function api.Close()
		if not isOpen then
			return
		end
		isOpen = false
		TweenService:Create(dim, Theme.Tween.Fast, { BackgroundTransparency = 1 }):Play()
		local t = TweenService:Create(scale, Theme.Tween.Fast, { Scale = 0.9 })
		t:Play()
		t.Completed:Connect(function()
			if not isOpen then
				dim.Visible = false
			end
		end)
		if props.OnClose then
			props.OnClose()
		end
	end

	function api.Toggle()
		if isOpen then
			api.Close()
		else
			api.Open()
		end
	end

	UI.Button({
		Name = "Close",
		Text = "X",
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.new(1, -50, 0, 9),
		Color = Theme.Colors.Red,
		TextSize = 18,
		Corner = 10,
		Parent = header,
		OnClick = api.Close,
	}).Instance.ZIndex =
		14

	dim.Activated:Connect(function()
		api.Close()
	end)
	-- Clicks inside the panel shouldn't close it.
	frame.Active = true

	return api
end

return UI
