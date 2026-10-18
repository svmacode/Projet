--!strict
-- Composants d'interface. Tout est dessiné pour une résolution de référence
-- de 1600×900 puis mis à l'échelle (téléphone, tablette, PC) par un UIScale.

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Theme = require(script.Parent.Theme)

local C = Theme.Colors
local REFERENCE = Vector2.new(1600, 900)

local Kit = {}

type Props = { [string]: any }

-- Base --------------------------------------------------------------------------------------

function Kit.new(className: string, props: Props?, children: { Instance }?): any
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
	if children then
		for _, child in children do
			child.Parent = instance
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

function Kit.border(parent: Instance, color: Color3?, thickness: number?): UIStroke
	return Kit.new("UIStroke", {
		Color = color or C.Border,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function Kit.padding(parent: Instance, horizontal: number, vertical: number?)
	local v = vertical or horizontal
	Kit.new("UIPadding", {
		PaddingLeft = UDim.new(0, horizontal),
		PaddingRight = UDim.new(0, horizontal),
		PaddingTop = UDim.new(0, v),
		PaddingBottom = UDim.new(0, v),
		Parent = parent,
	})
end

function Kit.list(
	parent: Instance,
	gap: number,
	horizontal: boolean?,
	align: Enum.HorizontalAlignment?,
	valign: Enum.VerticalAlignment?
): UIListLayout
	return Kit.new("UIListLayout", {
		Padding = UDim.new(0, gap),
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		VerticalAlignment = valign or Enum.VerticalAlignment.Top,
		Parent = parent,
	})
end

function Kit.grid(parent: Instance, cell: Vector2, gap: number): UIGridLayout
	return Kit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(cell.X, cell.Y),
		CellPadding = UDim2.fromOffset(gap, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

function Kit.clear(parent: Instance)
	for _, child in parent:GetChildren() do
		if not child:IsA("UIGridStyleLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

-- Écran mis à l'échelle ------------------------------------------------------------------------

function Kit.screen(name: string, displayOrder: number, parent: Instance): (ScreenGui, Frame)
	local gui = Kit.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = displayOrder,
		Parent = parent,
	})
	local root = Kit.new("Frame", {
		Name = "Racine",
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
		local factor = math.clamp(math.min(viewport.X / REFERENCE.X, viewport.Y / REFERENCE.Y), 0.45, 1.5)
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

-- Texte ------------------------------------------------------------------------------------------

function Kit.label(props: Props): TextLabel
	return Kit.new("TextLabel", {
		Name = props.Name or "Texte",
		BackgroundTransparency = 1,
		FontFace = props.Font or Theme.Fonts.Regular,
		Text = props.Text or "",
		TextColor3 = props.Color or C.Text,
		TextSize = props.TextSize or Theme.Text.Body,
		TextWrapped = props.Wrap == true,
		TextTruncate = if props.Wrap then Enum.TextTruncate.None else Enum.TextTruncate.AtEnd,
		TextXAlignment = props.AlignX or Enum.TextXAlignment.Left,
		TextYAlignment = props.AlignY or Enum.TextYAlignment.Center,
		RichText = props.Rich == true,
		Size = props.Size or UDim2.new(1, 0, 0, (props.TextSize or Theme.Text.Body) + 8),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		AutomaticSize = props.AutoSize or Enum.AutomaticSize.None,
		LayoutOrder = props.Order or 0,
		ZIndex = props.ZIndex or 1,
		Visible = props.Visible ~= false,
		Parent = props.Parent,
	})
end

-- Surfaces ------------------------------------------------------------------------------------------

function Kit.surface(props: Props): Frame
	local frame = Kit.new("Frame", {
		Name = props.Name or "Surface",
		BackgroundColor3 = props.Color or C.Surface,
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
	if props.Border ~= false then
		Kit.border(frame, props.BorderColor)
	end
	return frame
end

function Kit.box(props: Props): Frame
	return Kit.new("Frame", {
		Name = props.Name or "Boite",
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

function Kit.divider(parent: Instance, order: number?): Frame
	return Kit.new("Frame", {
		BackgroundColor3 = C.Border,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1),
		LayoutOrder = order or 0,
		Parent = parent,
	})
end

function Kit.scroll(props: Props): ScrollingFrame
	local frame = Kit.new("ScrollingFrame", {
		Name = props.Name or "Defilement",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = if props.Horizontal then Enum.AutomaticSize.X else Enum.AutomaticSize.Y,
		ScrollingDirection = if props.Horizontal then Enum.ScrollingDirection.X else Enum.ScrollingDirection.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.BorderStrong,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	})
	return frame
end

-- Petite pastille (rareté, statut).
function Kit.pill(parent: Instance, text: string, color: Color3, order: number?, textColor: Color3?): Frame
	local pill = Kit.new("Frame", {
		Name = "Pastille",
		BackgroundColor3 = color,
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = order or 0,
		Parent = parent,
	})
	Kit.corner(pill, 11)
	Kit.padding(pill, 10, 0)
	Kit.label({
		Text = text,
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.Tiny,
		Color = textColor or C.Background,
		Size = UDim2.fromOffset(0, 22),
		AutoSize = Enum.AutomaticSize.X,
		Parent = pill,
	})
	return pill
end

-- Boutons ---------------------------------------------------------------------------------------------

export type Variant = "Primary" | "Secondary" | "Ghost" | "Danger" | "Success"

export type Button = {
	Instance: TextButton,
	Label: TextLabel,
	SetText: (string) -> (),
	SetEnabled: (boolean) -> (),
	SetVariant: (Variant) -> (),
	SetSelected: (boolean) -> (),
}

local VARIANTS: { [string]: { Back: Color3, Hover: Color3, Text: Color3, Border: Color3? } } = {
	Primary = { Back = C.Accent, Hover = C.AccentHover, Text = C.TextOnAccent },
	Secondary = { Back = C.Surface3, Hover = Theme.lighten(C.Surface3, 0.08), Text = C.Text, Border = C.BorderStrong },
	Ghost = { Back = C.Surface2, Hover = C.Surface3, Text = C.TextMuted },
	Danger = { Back = Theme.darken(C.Danger, 0.15), Hover = C.Danger, Text = C.White },
	Success = { Back = Theme.darken(C.Success, 0.1), Hover = C.Success, Text = C.TextOnAccent },
}

function Kit.playSound(soundId: string, volume: number?)
	if soundId == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.5
	sound.Parent = SoundService
	SoundService:PlayLocalSound(sound)
	task.delay(4, function()
		sound:Destroy()
	end)
end

function Kit.button(props: Props): Button
	local variant: string = props.Variant or "Secondary"
	local enabled = true
	local selected = false
	local button = Kit.new("TextButton", {
		Name = props.Name or "Bouton",
		AutoButtonColor = false,
		BackgroundColor3 = VARIANTS[variant].Back,
		BorderSizePixel = 0,
		Text = "",
		Size = props.Size or UDim2.fromOffset(180, 44),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		AutomaticSize = props.AutoSize or Enum.AutomaticSize.None,
		LayoutOrder = props.Order or 0,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	})
	Kit.corner(button, props.Radius)
	local stroke = Kit.border(button, VARIANTS[variant].Border or VARIANTS[variant].Back)
	local scale = Kit.new("UIScale", { Parent = button })
	if props.AutoSize then
		Kit.padding(button, 20, 0)
	end
	local label = Kit.label({
		Text = props.Text or "",
		Font = props.Font or Theme.Fonts.Bold,
		TextSize = props.TextSize or Theme.Text.Body,
		Color = VARIANTS[variant].Text,
		AlignX = props.AlignX or Enum.TextXAlignment.Center,
		Size = if props.AutoSize then UDim2.fromScale(0, 1) else UDim2.new(1, -24, 1, 0),
		Position = if props.AutoSize then UDim2.new() else UDim2.fromOffset(12, 0),
		AutoSize = if props.AutoSize then Enum.AutomaticSize.X else nil,
		ZIndex = (props.ZIndex or 1) + 1,
		Parent = button,
	})

	local function paint(hover: boolean)
		local look = VARIANTS[variant]
		if not enabled then
			button.BackgroundColor3 = C.Surface2
			label.TextColor3 = C.TextFaint
			stroke.Color = C.Surface2
			return
		end
		if selected then
			button.BackgroundColor3 = C.Text
			label.TextColor3 = C.Background
			stroke.Color = C.Text
			return
		end
		TweenService:Create(button, Theme.Motion.Fast, { BackgroundColor3 = if hover then look.Hover else look.Back })
			:Play()
		label.TextColor3 = if hover and variant == "Ghost" then C.Text else look.Text
		stroke.Color = look.Border or look.Back
	end

	button.MouseEnter:Connect(function()
		paint(true)
		if enabled then
			Kit.playSound(Theme.Sounds.Hover, 0.15)
		end
	end)
	button.MouseLeave:Connect(function()
		paint(false)
		TweenService:Create(scale, Theme.Motion.Fast, { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		if enabled then
			TweenService:Create(scale, Theme.Motion.Fast, { Scale = 0.97 }):Play()
		end
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, Theme.Motion.Base, { Scale = 1 }):Play()
	end)
	button.Activated:Connect(function()
		if not enabled then
			return
		end
		Kit.playSound(Theme.Sounds.Click, 0.35)
		if props.OnClick then
			task.spawn(props.OnClick)
		end
	end)
	paint(false)

	return {
		Instance = button,
		Label = label,
		SetText = function(text: string)
			label.Text = text
		end,
		SetEnabled = function(value: boolean)
			enabled = value
			button.Active = value
			paint(false)
		end,
		SetVariant = function(value: Variant)
			variant = value
			paint(false)
		end,
		SetSelected = function(value: boolean)
			selected = value
			paint(false)
		end,
	}
end

-- Sélecteur segmenté (ex. 2v2 | 3v3 | 4v4 | 5v5).
export type Segmented = {
	Instance: Frame,
	Select: (string) -> (),
	SetEnabled: (string, boolean) -> (),
	Value: () -> string,
}

function Kit.segmented(props: Props): Segmented
	local options: { { Id: string, Label: string } } = props.Options
	local frame = Kit.surface({
		Name = props.Name or "Selecteur",
		Color = C.Surface2,
		Size = props.Size or UDim2.fromOffset(400, 44),
		Position = props.Position,
		Order = props.Order,
		ZIndex = props.ZIndex,
		Parent = props.Parent,
	})
	Kit.padding(frame, 4)
	local row = Kit.box({ Parent = frame, ZIndex = props.ZIndex })
	Kit.list(row, 4, true)
	local current = props.Value or options[1].Id
	local buttons: { [string]: TextButton } = {}
	local disabled: { [string]: boolean } = {}
	local width = 1 / #options
	local function paint()
		for id, button in buttons do
			local isOn = id == current
			button.BackgroundColor3 = if isOn then C.Text else C.Surface2
			local label = button:FindFirstChild("Texte") :: TextLabel
			label.TextColor3 = if disabled[id] then C.TextFaint elseif isOn then C.Background else C.TextMuted
		end
	end
	for index, option in options do
		local button = Kit.new("TextButton", {
			AutoButtonColor = false,
			BackgroundColor3 = C.Surface2,
			Text = "",
			Size = UDim2.new(width, -4 + 4 / #options, 1, 0),
			LayoutOrder = index,
			ZIndex = (props.ZIndex or 1) + 1,
			Parent = row,
		})
		Kit.corner(button, 6)
		Kit.label({
			Text = option.Label,
			Font = Theme.Fonts.Bold,
			TextSize = props.TextSize or Theme.Text.Body,
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			ZIndex = (props.ZIndex or 1) + 2,
			Parent = button,
		})
		button.Activated:Connect(function()
			if disabled[option.Id] or current == option.Id then
				return
			end
			current = option.Id
			paint()
			Kit.playSound(Theme.Sounds.Click, 0.3)
			if props.OnChange then
				props.OnChange(current)
			end
		end)
		buttons[option.Id] = button
	end
	paint()
	return {
		Instance = frame,
		Select = function(id: string)
			current = id
			paint()
		end,
		SetEnabled = function(id: string, value: boolean)
			disabled[id] = not value
			paint()
		end,
		Value = function()
			return current
		end,
	}
end

-- Barre de progression ; renvoie la fonction de mise à jour.
function Kit.progress(props: Props): (Frame, (number) -> ())
	local back = Kit.new("Frame", {
		Name = props.Name or "Progression",
		BackgroundColor3 = props.Back or C.Surface3,
		BorderSizePixel = 0,
		Size = props.Size or UDim2.fromOffset(200, 6),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		ClipsDescendants = true,
		LayoutOrder = props.Order or 0,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	})
	Kit.corner(back, 3)
	local fill = Kit.new("Frame", {
		BackgroundColor3 = props.Color or C.Accent,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		ZIndex = (props.ZIndex or 1) + 1,
		Parent = back,
	})
	Kit.corner(fill, 3)
	return back,
		function(value: number)
			local clamped = math.clamp(value, 0, 1)
			if props.Animate then
				TweenService:Create(fill, Theme.Motion.Slow, { Size = UDim2.fromScale(clamped, 1) }):Play()
			else
				fill.Size = UDim2.fromScale(clamped, 1)
			end
		end
end

-- Animations ---------------------------------------------------------------------------------------------

function Kit.tween(instance: Instance, info: TweenInfo, goals: { [string]: any }): Tween
	local tween = TweenService:Create(instance, info, goals)
	tween:Play()
	return tween
end

-- Apparition : léger glissement vers le haut + agrandissement.
function Kit.reveal(object: GuiObject, delay: number?, distance: number?)
	local target = object.Position
	object.Position = target + UDim2.fromOffset(0, distance or 16)
	local scale = object:FindFirstChildOfClass("UIScale") or Kit.new("UIScale", { Parent = object })
	scale.Scale = 0.98
	object.Visible = false
	task.delay(delay or 0, function()
		object.Visible = true
		Kit.tween(object, Theme.Motion.Slow, { Position = target })
		Kit.tween(scale, Theme.Motion.Slow, { Scale = 1 })
	end)
end

function Kit.pop(object: GuiObject, from: number?)
	local scale = object:FindFirstChildOfClass("UIScale") or Kit.new("UIScale", { Parent = object })
	scale.Scale = from or 0.9
	Kit.tween(scale, Theme.Motion.Spring, { Scale = 1 })
end

return Kit
