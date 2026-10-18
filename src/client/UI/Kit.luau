--!strict
-- Composants d'interface « anime sport ». Tout est dessiné pour une
-- résolution de référence de 1600×900 puis mis à l'échelle (téléphone,
-- tablette, PC) par un UIScale. Aucune image : uniquement des Frames,
-- des dégradés, des contours et du texte.

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

-- Contour d'encre (cadre). Par défaut : noir épais.
function Kit.border(parent: Instance, color: Color3?, thickness: number?): UIStroke
	return Kit.new("UIStroke", {
		Color = color or C.Ink,
		Thickness = thickness or Theme.Stroke,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Miter,
		Parent = parent,
	})
end

-- Contour du texte (lettrage).
function Kit.ink(label: TextLabel | TextButton, thickness: number?, color: Color3?): UIStroke
	return Kit.new("UIStroke", {
		Color = color or C.Ink,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = label,
	})
end

function Kit.gradient(parent: Instance, from: Color3, to: Color3, rotation: number?): UIGradient
	return Kit.new("UIGradient", {
		Color = ColorSequence.new(from, to),
		Rotation = rotation or 90,
		Parent = parent,
	})
end

-- Ombrage doux appliqué à une couleur unie (le dégradé multiplie la couleur).
function Kit.shade(parent: Instance, amount: number?): UIGradient
	local dark = 1 - (amount or 0.22)
	return Kit.gradient(parent, Color3.new(1, 1, 1), Color3.new(dark, dark, dark), 90)
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

-- props.Stroke = épaisseur d'un contour d'encre sur le texte (facultatif).
function Kit.label(props: Props): TextLabel
	local label = Kit.new("TextLabel", {
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
		Rotation = props.Rotation or 0,
		LayoutOrder = props.Order or 0,
		ZIndex = props.ZIndex or 1,
		Visible = props.Visible ~= false,
		Parent = props.Parent,
	})
	if props.Stroke then
		Kit.ink(label, props.Stroke, props.StrokeColor)
	end
	return label
end

export type Title = {
	Instance: Frame,
	Label: TextLabel,
	Shadow: TextLabel,
	SetText: (string) -> (),
	SetColors: (Color3, Color3) -> (),
}

-- Grand titre façon générique d'animé : lettrage BD, contour d'encre et
-- doublure de couleur décalée derrière.
function Kit.title(props: Props): Title
	local size: number = props.TextSize or Theme.Text.Display
	local offset: number = props.Offset or math.max(3, math.floor(size / 18))
	local holder = Kit.new("Frame", {
		Name = props.Name or "Titre",
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.new(1, 0, 0, size + 12),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Rotation = props.Rotation or 0,
		LayoutOrder = props.Order or 0,
		ZIndex = props.ZIndex or 1,
		Visible = props.Visible ~= false,
		Parent = props.Parent,
	})
	local common = {
		Text = props.Text or "",
		Font = props.Font or Theme.Fonts.Hero,
		TextSize = size,
		AlignX = props.AlignX or Enum.TextXAlignment.Left,
		Size = UDim2.fromScale(1, 1),
		ZIndex = props.ZIndex or 1,
		Parent = holder,
	}
	local shadowProps = table.clone(common)
	shadowProps.Name = "Doublure"
	shadowProps.Color = props.ShadowColor or C.Pink
	shadowProps.Position = UDim2.fromOffset(offset, offset)
	shadowProps.Stroke = props.Stroke or math.max(2, size / 28)
	local shadow = Kit.label(shadowProps)
	local mainProps = table.clone(common)
	mainProps.Color = props.Color or C.Text
	mainProps.Stroke = props.Stroke or math.max(2, size / 28)
	-- Le texte principal est enfant de la doublure : il est toujours dessiné devant.
	mainProps.Parent = shadow
	mainProps.Position = UDim2.fromOffset(-offset, -offset)
	local main = Kit.label(mainProps)
	return {
		Instance = holder,
		Label = main,
		Shadow = shadow,
		SetText = function(text: string)
			main.Text = text
			shadow.Text = text
		end,
		SetColors = function(color: Color3, shadowColor: Color3)
			main.TextColor3 = color
			shadow.TextColor3 = shadowColor
		end,
	}
end

-- Surfaces ------------------------------------------------------------------------------------------

-- Ombre dure qui suit un objet (placée en frère, juste derrière).
-- À n'utiliser que hors UIListLayout / UIGridLayout.
function Kit.dropShadow(object: GuiObject, offset: number?, color: Color3?): Frame
	local distance = offset or Theme.ShadowOffset
	local shadow = Kit.new("Frame", {
		Name = object.Name .. "_Ombre",
		BackgroundColor3 = color or C.Ink,
		BorderSizePixel = 0,
		ZIndex = math.max(0, object.ZIndex - 1),
		Parent = object.Parent,
	})
	local corner = object:FindFirstChildOfClass("UICorner")
	if corner then
		Kit.corner(shadow, corner.CornerRadius.Offset)
	end
	local function sync()
		shadow.Size = object.Size
		shadow.AnchorPoint = object.AnchorPoint
		shadow.Position = object.Position + UDim2.fromOffset(distance, distance)
		shadow.Rotation = object.Rotation
		shadow.Visible = object.Visible
	end
	sync()
	for _, property in { "Size", "Position", "AnchorPoint", "Rotation", "Visible" } do
		object:GetPropertyChangedSignal(property):Connect(sync)
	end
	object.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			shadow:Destroy()
		end
	end)
	return shadow
end

-- props.Shadow = true : ombre dure (hors layouts uniquement).
-- props.Gradient = false : couleur unie, sans ombrage.
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
		Rotation = props.Rotation or 0,
		LayoutOrder = props.Order or 0,
		ZIndex = props.ZIndex or 1,
		Visible = props.Visible ~= false,
		Parent = props.Parent,
	})
	if props.Radius ~= 0 then
		Kit.corner(frame, props.Radius)
	end
	if props.Border ~= false then
		Kit.border(frame, props.BorderColor, props.BorderThickness)
	end
	if props.Gradient ~= false then
		Kit.shade(frame, 0.18)
	end
	if props.Shadow then
		Kit.dropShadow(frame, props.ShadowOffset, props.ShadowColor)
	end
	return frame
end

-- Plaque inclinée aux bords vifs (bandeaux de titres, étiquettes).
function Kit.plate(props: Props): Frame
	local plate = Kit.new("Frame", {
		Name = props.Name or "Plaque",
		BackgroundColor3 = props.Color or C.Accent,
		BorderSizePixel = 0,
		Size = props.Size or UDim2.fromOffset(200, 40),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Rotation = props.Rotation or Theme.Tilt,
		LayoutOrder = props.Order or 0,
		ZIndex = props.ZIndex or 1,
		Visible = props.Visible ~= false,
		Parent = props.Parent,
	})
	if props.Border ~= false then
		Kit.border(plate, props.BorderColor, props.BorderThickness or 3)
	end
	if props.Gradient ~= false then
		Kit.shade(plate, 0.2)
	end
	if props.Shadow ~= false and props.Parent then
		Kit.dropShadow(plate, props.ShadowOffset, props.ShadowColor)
	end
	return plate
end

function Kit.box(props: Props): Frame
	return Kit.new("Frame", {
		Name = props.Name or "Boite",
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		AutomaticSize = props.AutoSize or Enum.AutomaticSize.None,
		Rotation = props.Rotation or 0,
		LayoutOrder = props.Order or 0,
		ZIndex = props.ZIndex or 1,
		Visible = props.Visible ~= false,
		Parent = props.Parent,
	})
end

function Kit.divider(parent: Instance, order: number?): Frame
	return Kit.new("Frame", {
		BackgroundColor3 = C.Surface3,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 2),
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
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.Accent,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	})
	return frame
end

-- Pastille façon autocollant (rareté, statut), légèrement inclinée.
function Kit.pill(parent: Instance, text: string, color: Color3, order: number?, textColor: Color3?): Frame
	local pill = Kit.new("Frame", {
		Name = "Pastille",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		Rotation = -2,
		LayoutOrder = order or 0,
		Parent = parent,
	})
	Kit.corner(pill, 4)
	Kit.border(pill, C.Ink, 2)
	Kit.padding(pill, 9, 0)
	Kit.label({
		Text = string.upper(text),
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.Tiny + 1,
		Color = textColor or Theme.onColor(color),
		Size = UDim2.fromOffset(0, 22),
		AutoSize = Enum.AutomaticSize.X,
		Parent = pill,
	})
	return pill
end

-- Décors -------------------------------------------------------------------------------------------

-- Lignes de vitesse animées (traits qui filent à l'horizontale).
function Kit.speedLines(props: Props): Frame
	local container = Kit.new("Frame", {
		Name = "LignesDeVitesse",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	})
	local random = Random.new()
	local count: number = props.Count or 18
	local color: Color3 = props.Color or C.White
	local transparency: number = props.Transparency or 0.75
	local reverse = props.Reverse == true
	for _ = 1, count do
		local length = random:NextNumber(0.08, 0.32)
		local line = Kit.new("Frame", {
			BackgroundColor3 = color,
			BackgroundTransparency = transparency + random:NextNumber(0, 0.2),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(length, 0, 0, random:NextInteger(2, 5)),
			Rotation = props.Angle or 0,
			ZIndex = props.ZIndex or 1,
			Parent = container,
		})
		local y = random:NextNumber(0, 1)
		local fromX = if reverse then 1 + length else -length
		local toX = if reverse then -length else 1 + length
		line.Position = UDim2.fromScale(fromX, y)
		local duration = random:NextNumber(0.5, 1.4) * (props.Speed or 1)
		local info = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1, false, 0)
		task.delay(random:NextNumber(0, 1.5), function()
			if line.Parent then
				TweenService:Create(line, info, { Position = UDim2.fromScale(toX, y) }):Play()
			end
		end)
	end
	return container
end

-- Trame de points façon manga : les points grossissent vers un coin.
function Kit.halftone(props: Props): Frame
	local columns: number = props.Columns or 14
	local rows: number = props.Rows or 8
	local spacing: number = props.Spacing or 16
	local container = Kit.new("Frame", {
		Name = "Trame",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(columns * spacing, rows * spacing),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Rotation = props.Rotation or 0,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	})
	local color: Color3 = props.Color or C.White
	local transparency: number = props.Transparency or 0.82
	local flip = props.Flip == true
	for column = 0, columns - 1 do
		for row = 0, rows - 1 do
			local cx = if flip then columns - 1 - column else column
			local t = 1 - ((cx / columns) * 0.7 + (row / rows) * 0.3)
			local size = math.floor(spacing * 0.8 * t)
			if size >= 2 then
				local dot = Kit.new("Frame", {
					BackgroundColor3 = color,
					BackgroundTransparency = transparency,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Size = UDim2.fromOffset(size, size),
					Position = UDim2.fromOffset(column * spacing + spacing / 2, row * spacing + spacing / 2),
					ZIndex = props.ZIndex or 1,
					Parent = container,
				})
				Kit.corner(dot, size)
			end
		end
	end
	return container
end

-- Fond d'écran animé : dégradé indigo, grandes bandes diagonales de la
-- couleur de section, trame de points et lignes de vitesse.
function Kit.backdrop(parent: Instance, color: Color3?, zIndex: number?): Frame
	local accent = color or C.Accent
	local z = zIndex or 1
	local back = Kit.new("Frame", {
		Name = "Fond",
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z,
		Parent = parent,
	})
	Kit.gradient(back, C.BackgroundTop, C.Background, 120)
	local stripes = {
		{ X = 0.78, Width = 0.22, Transparency = 0.82 },
		{ X = 0.96, Width = 0.06, Transparency = 0.6 },
		{ X = 0.08, Width = 0.03, Transparency = 0.86 },
	}
	for _, stripe in stripes do
		Kit.new("Frame", {
			BackgroundColor3 = accent,
			BackgroundTransparency = stripe.Transparency,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(stripe.X, 0.5),
			Size = UDim2.new(stripe.Width, 0, 2.4, 0),
			Rotation = 18,
			ZIndex = z,
			Parent = back,
		})
	end
	Kit.halftone({
		Parent = back,
		Color = accent,
		Columns = 22,
		Rows = 10,
		Spacing = 18,
		Transparency = 0.8,
		Flip = true,
		Position = UDim2.new(1, 0, 1, 0),
		AnchorPoint = Vector2.new(1, 1),
		ZIndex = z,
	})
	Kit.speedLines({ Parent = back, Color = C.White, Count = 14, Transparency = 0.9, ZIndex = z })
	return back
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
	SetColor: (Color3) -> (),
}

type Look = { Back: Color3, Text: Color3, Shadow: boolean }

local VARIANTS: { [string]: Look } = {
	Primary = { Back = C.Accent, Text = C.TextOnAccent, Shadow = true },
	Secondary = { Back = C.Surface3, Text = C.Text, Shadow = true },
	Ghost = { Back = C.Surface2, Text = C.TextMuted, Shadow = false },
	Danger = { Back = C.Danger, Text = C.White, Shadow = true },
	Success = { Back = C.Success, Text = C.TextOnAccent, Shadow = true },
}

function Kit.playSound(soundId: string, volume: number?)
	if soundId == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.5
	sound.PlaybackSpeed = 0.95 + math.random() * 0.1
	sound.Parent = SoundService
	SoundService:PlayLocalSound(sound)
	task.delay(4, function()
		sound:Destroy()
	end)
end

-- Bouton façon manga : face colorée cerclée d'encre posée sur une ombre dure.
-- Au survol la face se soulève ; au clic elle s'écrase sur son ombre.
-- props.Color remplace la couleur de la variante.
function Kit.button(props: Props): Button
	local variant: string = props.Variant or "Secondary"
	local custom: Color3? = props.Color
	local enabled = true
	local selected = false
	local z = props.ZIndex or 1
	local depth = if VARIANTS[variant].Shadow then 4 else 2
	local button = Kit.new("TextButton", {
		Name = props.Name or "Bouton",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		Size = props.Size or UDim2.fromOffset(180, 44),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		AutomaticSize = props.AutoSize or Enum.AutomaticSize.None,
		Rotation = props.Rotation or 0,
		LayoutOrder = props.Order or 0,
		ZIndex = z,
		Parent = props.Parent,
	})
	-- L'ombre porte la face : la face reste toujours dessinée au-dessus.
	local shadow = Kit.new("Frame", {
		Name = "Ombre",
		BackgroundColor3 = C.Ink,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(depth, depth),
		ZIndex = z,
		Parent = button,
	})
	Kit.corner(shadow, props.Radius)
	local face = Kit.new("Frame", {
		Name = "Face",
		BackgroundColor3 = VARIANTS[variant].Back,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(-depth, -depth),
		ZIndex = z,
		Parent = shadow,
	})
	Kit.corner(face, props.Radius)
	local stroke = Kit.border(face, C.Ink, 2.5)
	Kit.shade(face, 0.22)
	-- Reflet en haut de la face.
	local gloss = Kit.new("Frame", {
		Name = "Reflet",
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -8, 0.32, 0),
		Position = UDim2.fromOffset(4, 3),
		ZIndex = z,
		Parent = face,
	})
	Kit.corner(gloss, 3)
	local label = Kit.label({
		Text = props.Text or "",
		Font = props.Font or Theme.Fonts.Bold,
		TextSize = props.TextSize or Theme.Text.Body,
		Color = VARIANTS[variant].Text,
		AlignX = props.AlignX or Enum.TextXAlignment.Center,
		Size = if props.AutoSize then UDim2.fromScale(0, 1) else UDim2.new(1, -24, 1, 0),
		Position = if props.AutoSize then UDim2.new() else UDim2.fromOffset(12, 0),
		AutoSize = if props.AutoSize then Enum.AutomaticSize.X else nil,
		ZIndex = z + 1,
		Parent = face,
	})
	local labelStroke = Kit.ink(label, 1.5)
	if props.AutoSize then
		-- Le libellé dimensionne le bouton : on le garde dans le flux du bouton.
		label.Parent = button
		label.ZIndex = z + 2
		Kit.padding(label, 22, 0)
	end

	local function look(): Look
		return VARIANTS[variant]
	end

	local function setFace(offset: number)
		face.Position = UDim2.fromOffset(-depth + offset, -depth + offset)
		if props.AutoSize then
			label.Position = UDim2.fromOffset(offset, offset)
		end
	end

	local function paint(hover: boolean)
		local current = look()
		if not enabled then
			face.BackgroundColor3 = C.Surface2
			label.TextColor3 = C.TextFaint
			labelStroke.Enabled = false
			stroke.Color = C.Ink
			gloss.Visible = false
			return
		end
		gloss.Visible = true
		local back = custom or current.Back
		local text = if custom then Theme.onColor(custom) else current.Text
		if selected then
			back = C.Accent
			text = C.TextOnAccent
		end
		-- Contour du libellé seulement quand il est clair sur fond foncé.
		labelStroke.Enabled = text ~= C.TextOnAccent
		TweenService:Create(face, Theme.Motion.Fast, {
			BackgroundColor3 = if hover then Theme.lighten(back, 0.14) else back,
		}):Play()
		label.TextColor3 = if hover and variant == "Ghost" and not selected then C.Text else text
		stroke.Color = C.Ink
	end

	button.MouseEnter:Connect(function()
		paint(true)
		if enabled then
			setFace(-1)
			Kit.playSound(Theme.Sounds.Hover, 0.15)
		end
	end)
	button.MouseLeave:Connect(function()
		paint(false)
		setFace(0)
	end)
	button.MouseButton1Down:Connect(function()
		if enabled then
			setFace(depth)
		end
	end)
	button.MouseButton1Up:Connect(function()
		setFace(0)
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
			setFace(0)
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
		SetColor = function(value: Color3)
			custom = value
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
	local accent: Color3 = props.Color or C.Accent
	local frame = Kit.surface({
		Name = props.Name or "Selecteur",
		Color = C.Background,
		Gradient = false,
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
			button.BackgroundColor3 = if isOn then accent else C.Background
			button.BackgroundTransparency = if isOn then 0 else 1
			local stroke = button:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Enabled = isOn
			end
			local label = button:FindFirstChild("Texte") :: TextLabel
			label.TextColor3 = if disabled[id] then C.TextFaint elseif isOn then Theme.onColor(accent) else C.TextMuted
		end
	end
	for index, option in options do
		local button = Kit.new("TextButton", {
			AutoButtonColor = false,
			BackgroundColor3 = C.Background,
			BorderSizePixel = 0,
			Text = "",
			Size = UDim2.new(width, -4 + 4 / #options, 1, 0),
			LayoutOrder = index,
			ZIndex = (props.ZIndex or 1) + 1,
			Parent = row,
		})
		Kit.corner(button, 4)
		Kit.border(button, C.Ink, 2)
		Kit.label({
			Text = option.Label,
			Font = Theme.Fonts.Display,
			TextSize = props.TextSize or Theme.Text.Body + 1,
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
			Kit.pop(button, 0.88)
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

-- Barre de progression cerclée d'encre ; renvoie la fonction de mise à jour.
function Kit.progress(props: Props): (Frame, (number) -> ())
	local back = Kit.new("Frame", {
		Name = props.Name or "Progression",
		BackgroundColor3 = props.Back or C.Ink,
		BorderSizePixel = 0,
		Size = props.Size or UDim2.fromOffset(200, 8),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		ClipsDescendants = true,
		LayoutOrder = props.Order or 0,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	})
	Kit.corner(back, 3)
	if props.Border ~= false then
		Kit.border(back, C.Ink, 2)
	end
	local color: Color3 = props.Color or C.Accent
	local fill = Kit.new("Frame", {
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		ZIndex = (props.ZIndex or 1) + 1,
		Parent = back,
	})
	Kit.corner(fill, 3)
	Kit.gradient(fill, Theme.lighten(color, 0.25), color, 0)
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

-- Apparition : glissement latéral rapide + léger rebond, façon carton d'animé.
function Kit.reveal(object: GuiObject, delay: number?, distance: number?)
	local target = object.Position
	object.Position = target + UDim2.fromOffset(-(distance or 28), 0)
	local scale = object:FindFirstChildOfClass("UIScale") or Kit.new("UIScale", { Parent = object })
	scale.Scale = 0.96
	object.Visible = false
	task.delay(delay or 0, function()
		object.Visible = true
		Kit.tween(object, Theme.Motion.Slow, { Position = target })
		Kit.tween(scale, Theme.Motion.Spring, { Scale = 1 })
	end)
end

function Kit.pop(object: GuiObject, from: number?)
	local scale = object:FindFirstChildOfClass("UIScale") or Kit.new("UIScale", { Parent = object })
	scale.Scale = from or 0.9
	Kit.tween(scale, Theme.Motion.Spring, { Scale = 1 })
end

-- Arrivée « écrasée » : l'objet tombe de très gros à sa taille.
function Kit.slam(object: GuiObject, from: number?)
	local scale = object:FindFirstChildOfClass("UIScale") or Kit.new("UIScale", { Parent = object })
	scale.Scale = from or 2.4
	Kit.tween(scale, Theme.Motion.Slam, { Scale = 1 })
end

-- Secousse courte (en pixels) : réservée aux grands moments.
function Kit.shake(object: GuiObject, strength: number?, duration: number?)
	local origin = object.Position
	local power = strength or 6
	local finish = os.clock() + (duration or 0.25)
	task.spawn(function()
		while os.clock() < finish and object.Parent do
			object.Position = origin + UDim2.fromOffset(math.random(-power, power), math.random(-power, power))
			task.wait(0.03)
		end
		object.Position = origin
	end)
end

return Kit
