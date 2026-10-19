--!strict
-- Reusable UI building blocks. Everything is laid out at a 1600×900 reference
-- resolution and scaled by a UIScale, so the same layout works on phones,
-- tablets, PC and consoles. No imported images.

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Theme = require(script.Parent.Theme)

local C = Theme.Colors
local REFERENCE = Vector2.new(1600, 900)

local Kit = {}

export type Props = { [string]: any }

function Kit.new(className: string, props: Props?): any
	local instance = Instance.new(className)
	local parent: Instance? = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Kit.corner(parent: Instance, radius: number?): UICorner
	return Kit.new("UICorner", { CornerRadius = UDim.new(0, radius or Theme.Radius), Parent = parent })
end

function Kit.stroke(parent: Instance, color: Color3, thickness: number?, textMode: boolean?): UIStroke
	return Kit.new("UIStroke", {
		Color = color,
		Thickness = thickness or 1.5,
		ApplyStrokeMode = if textMode then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function Kit.padding(parent: Instance, x: number, y: number?)
	Kit.new("UIPadding", {
		PaddingLeft = UDim.new(0, x),
		PaddingRight = UDim.new(0, x),
		PaddingTop = UDim.new(0, y or x),
		PaddingBottom = UDim.new(0, y or x),
		Parent = parent,
	})
end

function Kit.list(parent: Instance, gap: number, horizontal: boolean?, align: Enum.HorizontalAlignment?): UIListLayout
	return Kit.new("UIListLayout", {
		Padding = UDim.new(0, gap),
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

function Kit.clear(parent: Instance)
	for _, child in parent:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") and not child:IsA("UIGridLayout") then
			child:Destroy()
		end
	end
end

-- ScreenGui with a scaled reference-size root frame.
function Kit.screen(name: string, order: number, parent: Instance): (ScreenGui, Frame)
	local gui = Kit.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = order,
		Parent = parent,
	})
	local root = Kit.new("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(REFERENCE.X, REFERENCE.Y),
		Parent = gui,
	})
	local scale = Kit.new("UIScale", { Parent = root })
	local function refresh()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local viewport = camera.ViewportSize
		local factor = math.clamp(math.min(viewport.X / REFERENCE.X, viewport.Y / REFERENCE.Y), 0.5, 1.6)
		scale.Scale = factor
		root.Size = UDim2.fromOffset(viewport.X / factor, viewport.Y / factor)
	end
	refresh()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
	end
	return gui, root
end

function Kit.label(props: Props): TextLabel
	local label = Kit.new("TextLabel", {
		Name = props.Name or "Label",
		BackgroundTransparency = 1,
		FontFace = props.Font or Theme.Fonts.Body,
		Text = props.Text or "",
		TextColor3 = props.Color or C.Text,
		TextSize = props.TextSize or Theme.Text.Body,
		TextXAlignment = props.AlignX or Enum.TextXAlignment.Left,
		TextYAlignment = props.AlignY or Enum.TextYAlignment.Center,
		TextWrapped = props.Wrap == true,
		RichText = props.Rich == true,
		Size = props.Size or UDim2.new(1, 0, 0, (props.TextSize or Theme.Text.Body) + 6),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		AutomaticSize = props.AutoSize or Enum.AutomaticSize.None,
		Rotation = props.Rotation or 0,
		LayoutOrder = props.Order or 0,
		ZIndex = props.ZIndex or 1,
		Visible = props.Visible ~= false,
		Parent = props.Parent,
	})
	if props.Outline then
		Kit.stroke(label, props.OutlineColor or C.Ink, props.Outline, true)
	end
	return label
end

-- Solid surface. Panels are opaque: legibility first.
function Kit.panel(props: Props): Frame
	local frame = Kit.new("Frame", {
		Name = props.Name or "Panel",
		BackgroundColor3 = props.Color or C.Surface,
		BackgroundTransparency = props.Transparency or 0,
		BorderSizePixel = 0,
		Size = props.Size or UDim2.fromOffset(200, 100),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		AutomaticSize = props.AutoSize or Enum.AutomaticSize.None,
		ClipsDescendants = props.Clip == true,
		LayoutOrder = props.Order or 0,
		ZIndex = props.ZIndex or 1,
		Visible = props.Visible ~= false,
		Parent = props.Parent,
	})
	if props.Radius ~= 0 then
		Kit.corner(frame, props.Radius)
	end
	return frame
end

function Kit.box(props: Props): Frame
	return Kit.new("Frame", {
		Name = props.Name or "Box",
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		AutomaticSize = props.AutoSize or Enum.AutomaticSize.None,
		LayoutOrder = props.Order or 0,
		ZIndex = props.ZIndex or 1,
		Visible = props.Visible ~= false,
		Parent = props.Parent,
	})
end

-- Short slanted accent bar (the "broadcast slash" used to anchor titles).
function Kit.slash(parent: Instance, color: Color3, size: UDim2, position: UDim2, zIndex: number?): Frame
	return Kit.new("Frame", {
		Name = "Slash",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = size,
		Position = position,
		Rotation = 14,
		ZIndex = zIndex or 1,
		Parent = parent,
	})
end

function Kit.tween(instance: Instance, info: TweenInfo, goals: { [string]: any }): Tween
	local tween = TweenService:Create(instance, info, goals)
	tween:Play()
	return tween
end

function Kit.scale(object: GuiObject): UIScale
	local existing = object:FindFirstChildOfClass("UIScale")
	if existing then
		return existing
	end
	return Kit.new("UIScale", { Parent = object })
end

function Kit.pop(object: GuiObject, from: number?)
	local scale = Kit.scale(object)
	scale.Scale = from or 1.25
	Kit.tween(scale, Theme.Motion.Snap, { Scale = 1 })
end

function Kit.playSound(id: string?, volume: number?)
	if not id or id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.5
	sound.Parent = SoundService
	SoundService:PlayLocalSound(sound)
	task.delay(5, function()
		sound:Destroy()
	end)
end

-- Buttons ----------------------------------------------------------------------------------------------

export type Variant = "Primary" | "Secondary" | "Ghost" | "Danger"

export type Button = {
	Instance: TextButton,
	SetText: (string) -> (),
	SetEnabled: (boolean) -> (),
	SetSelected: (boolean) -> (),
}

local VARIANTS: { [string]: { Back: Color3, Hover: Color3, Text: Color3 } } = {
	Primary = { Back = C.Accent, Hover = C.AccentHot, Text = C.TextOnAccent },
	Secondary = { Back = C.Raised, Hover = C.Line, Text = C.Text },
	Ghost = { Back = C.Surface, Hover = C.Raised, Text = C.TextDim },
	Danger = { Back = C.Danger, Hover = Color3.fromRGB(255, 110, 120), Text = C.White },
}

-- Button with hover, press, keyboard/gamepad focus (SelectionGained) and disabled states.
function Kit.button(props: Props): Button
	local variant: string = props.Variant or "Secondary"
	local look = VARIANTS[variant]
	local enabled = true
	local selected = false
	local hovered = false
	local button = Kit.new("TextButton", {
		Name = props.Name or "Button",
		AutoButtonColor = false,
		BackgroundColor3 = look.Back,
		BorderSizePixel = 0,
		Text = props.Text or "",
		FontFace = props.Font or Theme.Fonts.Heavy,
		TextSize = props.TextSize or Theme.Text.Large,
		TextColor3 = look.Text,
		Size = props.Size or UDim2.fromOffset(200, 48),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.Order or 0,
		ZIndex = props.ZIndex or 1,
		Selectable = true,
		Parent = props.Parent,
	})
	Kit.corner(button, props.Radius)
	local focus = Kit.stroke(button, C.White, 2.5)
	focus.Enabled = false
	local scale = Kit.scale(button)

	local function paint()
		if not enabled then
			button.BackgroundColor3 = C.Raised
			button.TextColor3 = C.TextFaint
			return
		end
		if selected then
			button.BackgroundColor3 = C.Accent
			button.TextColor3 = C.TextOnAccent
			return
		end
		button.BackgroundColor3 = if hovered then look.Hover else look.Back
		button.TextColor3 = look.Text
	end

	button.MouseEnter:Connect(function()
		hovered = true
		paint()
	end)
	button.MouseLeave:Connect(function()
		hovered = false
		paint()
		Kit.tween(scale, Theme.Motion.Fast, { Scale = 1 })
	end)
	button.SelectionGained:Connect(function()
		focus.Enabled = true
	end)
	button.SelectionLost:Connect(function()
		focus.Enabled = false
	end)
	button.MouseButton1Down:Connect(function()
		if enabled then
			Kit.tween(scale, Theme.Motion.Fast, { Scale = 0.95 })
		end
	end)
	button.MouseButton1Up:Connect(function()
		Kit.tween(scale, Theme.Motion.Base, { Scale = 1 })
	end)
	button.Activated:Connect(function()
		if not enabled then
			return
		end
		if props.OnClick then
			task.spawn(props.OnClick)
		end
	end)
	paint()

	return {
		Instance = button,
		SetText = function(text: string)
			button.Text = text
		end,
		SetEnabled = function(value: boolean)
			enabled = value
			button.Active = value
			paint()
		end,
		SetSelected = function(value: boolean)
			selected = value
			paint()
		end,
	}
end

-- Progress bar; returns the frame and an update function (0..1).
function Kit.bar(props: Props): (Frame, (number, Color3?) -> ())
	local back = Kit.panel({
		Name = props.Name or "Bar",
		Color = props.Back or C.Ink,
		Size = props.Size or UDim2.fromOffset(200, 8),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Radius = props.Radius or 3,
		Clip = true,
		ZIndex = props.ZIndex,
		Parent = props.Parent,
	})
	local fill = Kit.panel({
		Color = props.Color or C.Accent,
		Size = UDim2.fromScale(0, 1),
		Radius = props.Radius or 3,
		ZIndex = (props.ZIndex or 1) + 1,
		Parent = back,
	})
	return back,
		function(value: number, color: Color3?)
			fill.Size = UDim2.fromScale(math.clamp(value, 0, 1), 1)
			if color then
				fill.BackgroundColor3 = color
			end
		end
end

return Kit
