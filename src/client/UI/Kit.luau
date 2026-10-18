--!strict
-- Briques d'interface réutilisables (style manga). Tout est construit en code
-- sur une résolution de référence 1600×900, mise à l'échelle par UIScale
-- selon l'écran (téléphone, tablette, PC).

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Theme = require(script.Parent.Theme)

local Kit = {}

local C = Theme.Colors
local REFERENCE = Vector2.new(1600, 900)

type Props = { [string]: any }

-- Création générique ---------------------------------------------------------------------

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
	return Kit.new("UICorner", { CornerRadius = UDim.new(0, radius or 10), Parent = parent })
end

function Kit.stroke(parent: Instance, thickness: number?, color: Color3?): UIStroke
	return Kit.new("UIStroke", {
		Thickness = thickness or Theme.Stroke,
		Color = color or C.Ink,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Miter,
		Parent = parent,
	})
end

function Kit.textStroke(parent: Instance, thickness: number?, color: Color3?): UIStroke
	return Kit.new("UIStroke", {
		Thickness = thickness or 3,
		Color = color or C.Ink,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = parent,
	})
end

function Kit.padding(parent: Instance, all: number)
	Kit.new("UIPadding", {
		PaddingTop = UDim.new(0, all),
		PaddingBottom = UDim.new(0, all),
		PaddingLeft = UDim.new(0, all),
		PaddingRight = UDim.new(0, all),
		Parent = parent,
	})
end

function Kit.list(
	parent: Instance,
	padding: number,
	horizontal: boolean?,
	align: Enum.HorizontalAlignment?
): UIListLayout
	return Kit.new("UIListLayout", {
		Padding = UDim.new(0, padding),
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		Parent = parent,
	})
end

function Kit.grid(parent: Instance, cellSize: Vector2, padding: number): UIGridLayout
	return Kit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(cellSize.X, cellSize.Y),
		CellPadding = UDim2.fromOffset(padding, padding),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

-- Écran ------------------------------------------------------------------------------------------

function Kit.screen(name: string, displayOrder: number, parent: Instance): ScreenGui
	local gui = Kit.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = displayOrder,
		Parent = parent,
	})
	-- Mise à l'échelle commune : tout est dessiné pour 1600×900.
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
		local factor = math.min(viewport.X / REFERENCE.X, viewport.Y / REFERENCE.Y)
		scale.Scale = math.clamp(factor, 0.4, 1.6)
		-- La zone de référence suit les proportions de l'écran.
		root.Size = UDim2.fromOffset(viewport.X / scale.Scale, viewport.Y / scale.Scale)
	end
	refresh()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
	end
	return gui
end

function Kit.root(gui: ScreenGui): Frame
	return gui:FindFirstChild("Root") :: Frame
end

-- Texte --------------------------------------------------------------------------------------------

function Kit.text(props: Props): TextLabel
	local label = Kit.new("TextLabel", {
		BackgroundTransparency = 1,
		Font = props.Font or Theme.Fonts.Title,
		Text = props.Text or "",
		TextColor3 = props.Color or C.Ink,
		TextScaled = props.Scaled ~= false,
		TextSize = props.TextSize or 24,
		TextWrapped = true,
		TextXAlignment = props.AlignX or Enum.TextXAlignment.Center,
		TextYAlignment = props.AlignY or Enum.TextYAlignment.Center,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Rotation = props.Rotation or 0,
		RichText = props.Rich == true,
		LayoutOrder = props.Order or 0,
		ZIndex = props.ZIndex or 1,
		Name = props.Name or "Texte",
		Parent = props.Parent,
	})
	if props.Stroke then
		Kit.textStroke(label, props.StrokeThickness or 3, props.Stroke)
	end
	if props.MaxSize then
		Kit.new("UITextSizeConstraint", { MaxTextSize = props.MaxSize, Parent = label })
	end
	return label
end

-- Panneaux -----------------------------------------------------------------------------------------

-- Panneau papier avec contour encre et ombre pleine décalée.
-- Renvoie (face, conteneur). Les enfants vont dans `face`.
function Kit.panel(props: Props): (Frame, Frame)
	local container = Kit.new("Frame", {
		Name = props.Name or "Panneau",
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.fromOffset(400, 300),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Rotation = props.Rotation or 0,
		LayoutOrder = props.Order or 0,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	})
	local offset = props.ShadowOffset or Theme.ShadowOffset
	if props.Shadow ~= false then
		local shadow = Kit.new("Frame", {
			Name = "Ombre",
			BackgroundColor3 = props.ShadowColor or C.Ink,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromOffset(offset, offset),
			ZIndex = (props.ZIndex or 1),
			Parent = container,
		})
		if props.Corner then
			Kit.corner(shadow, props.Corner)
		end
	end
	local face = Kit.new("Frame", {
		Name = "Face",
		BackgroundColor3 = props.Color or C.Paper,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = (props.ZIndex or 1),
		ClipsDescendants = props.Clip == true,
		Parent = container,
	})
	if props.Corner then
		Kit.corner(face, props.Corner)
	end
	if props.Stroke ~= false then
		Kit.stroke(face, props.StrokeThickness or Theme.Stroke, props.StrokeColor)
	end
	if props.Gradient then
		Kit.new("UIGradient", { Color = props.Gradient, Rotation = props.GradientRotation or 90, Parent = face })
	end
	return face, container
end

-- Bandeau de titre incliné (style case de manga).
function Kit.header(parent: Instance, text: string, color: Color3?, japanese: string?): Frame
	local bar = Kit.new("Frame", {
		Name = "Titre",
		BackgroundColor3 = color or C.Red,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 24, 0, 64),
		Position = UDim2.fromOffset(-12, -22),
		Rotation = -1.5,
		ZIndex = 5,
		Parent = parent,
	})
	Kit.stroke(bar, Theme.Stroke)
	Kit.text({
		Text = text,
		Color = C.Paper,
		Stroke = C.Ink,
		StrokeThickness = 3,
		Size = UDim2.new(1, -40, 1, -10),
		Position = UDim2.fromOffset(20, 5),
		AlignX = Enum.TextXAlignment.Left,
		ZIndex = 6,
		Parent = bar,
	})
	if japanese then
		Kit.text({
			Text = japanese,
			Font = Theme.Fonts.Heavy,
			Color = C.Yellow,
			Size = UDim2.new(0.4, 0, 0.5, 0),
			Position = UDim2.new(0.58, 0, 0.25, 0),
			AlignX = Enum.TextXAlignment.Right,
			ZIndex = 6,
			Parent = bar,
		})
	end
	return bar
end

-- Boutons ---------------------------------------------------------------------------------------------

export type Button = {
	Container: Frame,
	Face: TextButton,
	Label: TextLabel,
	SetEnabled: (boolean) -> (),
	SetText: (string) -> (),
	SetColor: (Color3) -> (),
}

local clickSound: Sound? = nil

function Kit.playSound(soundId: string, volume: number?)
	if soundId == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.6
	sound.Parent = SoundService
	SoundService:PlayLocalSound(sound)
	task.delay(4, function()
		sound:Destroy()
	end)
end

function Kit.button(props: Props): Button
	local baseColor: Color3 = props.Color or C.Yellow
	local textColor: Color3 = props.TextColor or C.Ink
	local container = Kit.new("Frame", {
		Name = props.Name or "Bouton",
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.fromOffset(240, 64),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Rotation = props.Rotation or 0,
		LayoutOrder = props.Order or 0,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	})
	local offset = props.ShadowOffset or 5
	local shadow = Kit.new("Frame", {
		Name = "Ombre",
		BackgroundColor3 = C.Ink,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(offset, offset),
		ZIndex = props.ZIndex or 1,
		Parent = container,
	})
	local face = Kit.new("TextButton", {
		Name = "Face",
		AutoButtonColor = false,
		BackgroundColor3 = baseColor,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		ZIndex = props.ZIndex or 1,
		Parent = container,
	})
	if props.Corner then
		Kit.corner(face, props.Corner)
		Kit.corner(shadow, props.Corner)
	end
	Kit.stroke(face, props.StrokeThickness or 3)
	local label = Kit.text({
		Text = props.Text or "",
		Font = props.Font or Theme.Fonts.Title,
		Color = textColor,
		Stroke = props.TextStroke,
		StrokeThickness = 2,
		Size = UDim2.new(1, -16, 1, -10),
		Position = UDim2.fromOffset(8, 5),
		ZIndex = (props.ZIndex or 1) + 1,
		MaxSize = props.MaxTextSize,
		Parent = face,
	})
	local scale = Kit.new("UIScale", { Parent = container })
	local enabled = true
	local current = baseColor

	face.MouseEnter:Connect(function()
		if enabled then
			TweenService:Create(face, Theme.Tween.Fast, { BackgroundColor3 = Theme.shade(current, 0.18) }):Play()
			TweenService:Create(scale, Theme.Tween.Fast, { Scale = 1.04 }):Play()
		end
	end)
	face.MouseLeave:Connect(function()
		TweenService
			:Create(
				face,
				Theme.Tween.Fast,
				{ BackgroundColor3 = if enabled then current else Theme.shade(current, -0.45) }
			)
			:Play()
		TweenService:Create(scale, Theme.Tween.Fast, { Scale = 1 }):Play()
		face.Position = UDim2.new()
	end)
	face.MouseButton1Down:Connect(function()
		if enabled then
			face.Position = UDim2.fromOffset(offset - 1, offset - 1)
		end
	end)
	face.MouseButton1Up:Connect(function()
		face.Position = UDim2.new()
	end)
	face.Activated:Connect(function()
		face.Position = UDim2.new()
		if not enabled then
			return
		end
		Kit.playSound(Theme.Sounds.Click, 0.4)
		scale.Scale = 0.94
		TweenService:Create(scale, Theme.Tween.Pop, { Scale = 1 }):Play()
		if props.OnClick then
			task.spawn(props.OnClick)
		end
	end)

	local button: Button = {
		Container = container,
		Face = face,
		Label = label,
		SetEnabled = function(value: boolean)
			enabled = value
			face.BackgroundColor3 = if value then current else Theme.shade(current, -0.45)
			label.TextColor3 = if value then textColor else Theme.shade(textColor, -0.3)
		end,
		SetText = function(text: string)
			label.Text = text
		end,
		SetColor = function(color: Color3)
			current = color
			face.BackgroundColor3 = if enabled then color else Theme.shade(color, -0.45)
		end,
	}
	local _ = clickSound
	return button
end

-- Décors ----------------------------------------------------------------------------------------------

-- Rayons de soleil (fond typique des cases d'action en manga).
function Kit.sunburst(parent: Instance, colorA: Color3, colorB: Color3, rays: number, spin: boolean?): Frame
	local holder = Kit.new("Frame", {
		Name = "Rayons",
		BackgroundColor3 = colorA,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true,
		ZIndex = 0,
		Parent = parent,
	})
	local center = Kit.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(10, 10),
		Parent = holder,
	})
	for i = 0, rays - 1 do
		Kit.new("Frame", {
			BackgroundColor3 = colorB,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(3200, 3200 * math.tan(math.pi / rays / 2) * 2 * 0.5),
			Rotation = i * 360 / rays,
			ZIndex = 0,
			Parent = center,
		})
	end
	if spin then
		task.spawn(function()
			while holder.Parent do
				center.Rotation = (center.Rotation + 0.08) % 360
				task.wait(1 / 30)
			end
		end)
	end
	return holder
end

-- Trame de points (halftone) dans un coin.
function Kit.halftone(parent: Instance, color: Color3, corner: Vector2, count: number, spacing: number)
	for row = 0, count - 1 do
		for column = 0, count - 1 - row do
			local size = math.max(2, (count - row - column) * 1.6)
			local dot = Kit.new("Frame", {
				BackgroundColor3 = color,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(size, size),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(
					corner.X,
					(1 - 2 * corner.X) * (column * spacing + spacing / 2),
					corner.Y,
					(1 - 2 * corner.Y) * (row * spacing + spacing / 2)
				),
				ZIndex = 0,
				Parent = parent,
			})
			Kit.corner(dot, 100)
		end
	end
end

-- Pièce « Hand Coin ».
function Kit.coin(parent: Instance, size: number, position: UDim2?, anchor: Vector2?): Frame
	local coin = Kit.new("Frame", {
		Name = "HandCoin",
		BackgroundColor3 = C.Yellow,
		Size = UDim2.fromOffset(size, size),
		Position = position or UDim2.new(),
		AnchorPoint = anchor or Vector2.zero,
		ZIndex = 3,
		Parent = parent,
	})
	Kit.corner(coin, size)
	Kit.stroke(coin, math.max(2, size / 12))
	local inner = Kit.new("Frame", {
		BackgroundColor3 = C.YellowDark,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.7, 0.7),
		ZIndex = 3,
		Parent = coin,
	})
	Kit.corner(inner, size)
	Kit.text({ Text = "H", Color = C.Paper, Stroke = C.Ink, StrokeThickness = 2, ZIndex = 4, Parent = inner })
	return coin
end

-- Balle de handball dessinée (icône des packs).
function Kit.ball(
	parent: Instance,
	size: number,
	color: Color3,
	accent: Color3,
	position: UDim2?,
	anchor: Vector2?
): Frame
	local ball = Kit.new("Frame", {
		Name = "Balle",
		BackgroundColor3 = color,
		Size = UDim2.fromOffset(size, size),
		Position = position or UDim2.new(),
		AnchorPoint = anchor or Vector2.zero,
		ClipsDescendants = false,
		ZIndex = 3,
		Parent = parent,
	})
	Kit.corner(ball, size)
	Kit.stroke(ball, math.max(3, size / 22))
	-- Coutures.
	for _, rotation in { 35, -35 } do
		local seam = Kit.new("Frame", {
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0.95, 0, 0, math.max(4, size / 14)),
			Rotation = rotation,
			ZIndex = 4,
			Parent = ball,
		})
		Kit.stroke(seam, 2)
	end
	local shine = Kit.new("Frame", {
		BackgroundColor3 = C.White,
		Size = UDim2.fromScale(0.22, 0.14),
		Position = UDim2.fromScale(0.2, 0.16),
		Rotation = -30,
		ZIndex = 5,
		Parent = ball,
	})
	Kit.corner(shine, size)
	return ball
end

-- Barre de progression ; renvoie la fonction de mise à jour.
function Kit.progress(parent: Instance, props: Props): (Frame, (number) -> ())
	local back = Kit.new("Frame", {
		Name = props.Name or "Barre",
		BackgroundColor3 = props.Back or C.InkSoft,
		BorderSizePixel = 0,
		Size = props.Size or UDim2.fromOffset(200, 16),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		ClipsDescendants = true,
		LayoutOrder = props.Order or 0,
		ZIndex = props.ZIndex or 2,
		Parent = parent,
	})
	Kit.stroke(back, props.StrokeThickness or 3)
	local fill = Kit.new("Frame", {
		Name = "Remplissage",
		BackgroundColor3 = props.Color or C.Yellow,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		ZIndex = (props.ZIndex or 2) + 1,
		Parent = back,
	})
	local function set(value: number)
		local clamped = math.clamp(value, 0, 1)
		if props.Animate then
			TweenService:Create(fill, Theme.Tween.Fast, { Size = UDim2.fromScale(clamped, 1) }):Play()
		else
			fill.Size = UDim2.fromScale(clamped, 1)
		end
	end
	return back, set
end

function Kit.rarityChip(parent: Instance, rarity: string, props: Props?): Frame
	local p: Props = props or {}
	local chip = Kit.new("Frame", {
		Name = "Rarete",
		BackgroundColor3 = Theme.rarityColor(rarity),
		Size = p.Size or UDim2.fromOffset(130, 30),
		Position = p.Position or UDim2.new(),
		AnchorPoint = p.AnchorPoint or Vector2.zero,
		Rotation = p.Rotation or -2,
		ZIndex = p.ZIndex or 4,
		Parent = parent,
	})
	Kit.stroke(chip, 3)
	Kit.text({
		Text = string.upper(Theme.rarityName(rarity)),
		Color = C.Paper,
		Stroke = C.Ink,
		StrokeThickness = 2,
		Size = UDim2.new(1, -8, 1, -4),
		Position = UDim2.fromOffset(4, 2),
		ZIndex = (p.ZIndex or 4) + 1,
		Parent = chip,
	})
	return chip
end

-- Animations --------------------------------------------------------------------------------------------

function Kit.tween(instance: Instance, info: TweenInfo, goals: { [string]: any }): Tween
	local tween = TweenService:Create(instance, info, goals)
	tween:Play()
	return tween
end

function Kit.pop(guiObject: GuiObject, from: number?)
	local scale = guiObject:FindFirstChildOfClass("UIScale") or Kit.new("UIScale", { Parent = guiObject })
	scale.Scale = from or 0.6
	Kit.tween(scale, Theme.Tween.Pop, { Scale = 1 })
end

function Kit.shake(guiObject: GuiObject, strength: number, duration: number)
	local origin = guiObject.Position
	task.spawn(function()
		local stop = os.clock() + duration
		while os.clock() < stop and guiObject.Parent do
			local s = strength * (stop - os.clock()) / duration
			guiObject.Position = origin + UDim2.fromOffset(math.random(-s, s), math.random(-s, s))
			task.wait(1 / 60)
		end
		guiObject.Position = origin
	end)
end

function Kit.clear(parent: Instance)
	for _, child in parent:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIGridLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

-- Liste défilante (sans fond gris : papier + barre de défilement encre).
function Kit.scroll(parent: Instance, props: Props): ScrollingFrame
	return Kit.new("ScrollingFrame", {
		Name = props.Name or "Liste",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = props.Horizontal and Enum.AutomaticSize.X or Enum.AutomaticSize.Y,
		ScrollingDirection = props.Horizontal and Enum.ScrollingDirection.X or Enum.ScrollingDirection.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = C.Ink,
		ZIndex = props.ZIndex or 2,
		Parent = parent,
	})
end

return Kit
