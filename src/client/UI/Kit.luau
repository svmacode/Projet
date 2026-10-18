--!strict
-- Composants d'interface. Tout est dessiné pour une résolution de référence
-- de 1600×900 puis mis à l'échelle (téléphone, tablette, PC) par un UIScale.
-- Aucune image : uniquement des Frames, dégradés, contours et texte.

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

function Kit.round(parent: Instance): UICorner
	return Kit.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = parent })
end

-- Contour de cadre.
function Kit.border(parent: Instance, color: Color3?, thickness: number?, transparency: number?): UIStroke
	return Kit.new("UIStroke", {
		Color = color or C.Border,
		Thickness = thickness or 1.5,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

-- Contour de texte.
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

-- Ombrage doux sur une couleur unie (le dégradé multiplie la couleur).
function Kit.shade(parent: Instance, amount: number?): UIGradient
	local dark = 1 - (amount or 0.12)
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

-- props.Stroke = épaisseur d'un contour sur le texte (facultatif).
function Kit.label(props: Props): TextLabel
	local label = Kit.new("TextLabel", {
		Name = props.Name or "Texte",
		BackgroundTransparency = 1,
		FontFace = props.Font or Theme.Fonts.Regular,
		Text = props.Text or "",
		TextColor3 = props.Color or C.Text,
		TextTransparency = props.Transparency or 0,
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

-- Grand titre : Gotham Black blanc cerclé de marine, avec une ombre portée
-- douce juste en dessous (lisible sur n'importe quel fond coloré).
function Kit.title(props: Props): Title
	local size: number = props.TextSize or Theme.Text.Display
	local strokeColor: Color3 = props.StrokeColor or props.ShadowColor or C.Ink
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
	local offset = math.max(2, math.floor(size / 22))
	local shadow = Kit.label({
		Name = "Ombre",
		Text = props.Text or "",
		Font = props.Font or Theme.Fonts.Hero,
		TextSize = size,
		Color = strokeColor,
		Transparency = 0.55,
		AlignX = props.AlignX or Enum.TextXAlignment.Left,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, offset),
		ZIndex = props.ZIndex or 1,
		Stroke = props.Stroke or math.max(2, size / 16),
		StrokeColor = strokeColor,
		Parent = holder,
	})
	local shadowStroke = shadow:FindFirstChildOfClass("UIStroke")
	if shadowStroke then
		shadowStroke.Transparency = 0.55
	end
	-- Le texte principal est enfant de l'ombre : il est toujours dessiné devant.
	local main = Kit.label({
		Text = props.Text or "",
		Font = props.Font or Theme.Fonts.Hero,
		TextSize = size,
		Color = props.Color or C.White,
		AlignX = props.AlignX or Enum.TextXAlignment.Left,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, -offset),
		ZIndex = props.ZIndex or 1,
		Stroke = props.Stroke or math.max(2, size / 16),
		StrokeColor = strokeColor,
		Parent = shadow,
	})
	return {
		Instance = holder,
		Label = main,
		Shadow = shadow,
		SetText = function(text: string)
			main.Text = text
			shadow.Text = text
		end,
		SetColors = function(color: Color3, outline: Color3)
			main.TextColor3 = color
			shadow.TextColor3 = outline
			for _, label in { main, shadow } do
				local stroke = label:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke.Color = outline
				end
			end
		end,
	}
end

-- Surfaces ------------------------------------------------------------------------------------------

-- Ombre douce qui suit un objet (placée en frère, juste derrière).
-- À n'utiliser que hors UIListLayout / UIGridLayout.
function Kit.dropShadow(object: GuiObject, offset: number?, color: Color3?, transparency: number?): Frame
	local distance = offset or 6
	local shadow = Kit.new("Frame", {
		Name = object.Name .. "_Ombre",
		BackgroundColor3 = color or C.Ink,
		BackgroundTransparency = transparency or 0.85,
		BorderSizePixel = 0,
		ZIndex = math.max(0, object.ZIndex - 1),
		Parent = object.Parent,
	})
	local corner = object:FindFirstChildOfClass("UICorner")
	if corner then
		Kit.new("UICorner", { CornerRadius = corner.CornerRadius, Parent = shadow })
	end
	local function sync()
		shadow.Size = object.Size + UDim2.fromOffset(4, 4)
		shadow.AnchorPoint = object.AnchorPoint
		shadow.Position = object.Position + UDim2.fromOffset(-2, distance - 2)
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

-- Panneau clair arrondi.
-- props.Shadow = true : ombre douce (hors layouts uniquement).
-- props.Transparency : translucidité du fond (0 par défaut).
function Kit.surface(props: Props): Frame
	local frame = Kit.new("Frame", {
		Name = props.Name or "Surface",
		BackgroundColor3 = props.Color or C.Surface,
		BackgroundTransparency = props.Transparency or 0,
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
		Kit.corner(frame, props.Radius or Theme.Radius)
	end
	if props.Border ~= false then
		Kit.border(frame, props.BorderColor, props.BorderThickness)
	end
	if props.Gradient then
		Kit.shade(frame, 0.08)
	end
	if props.Shadow then
		Kit.dropShadow(frame, props.ShadowOffset, props.ShadowColor, props.ShadowTransparency)
	end
	return frame
end

-- Pastille de couleur arrondie (bandeaux, étiquettes). Garde le nom
-- historique « plate » pour les autres modules.
function Kit.plate(props: Props): Frame
	local color: Color3 = props.Color or C.Accent
	local plate = Kit.new("Frame", {
		Name = props.Name or "Plaque",
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		Size = props.Size or UDim2.fromOffset(200, 40),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Rotation = props.Rotation or 0,
		LayoutOrder = props.Order or 0,
		ZIndex = props.ZIndex or 1,
		Visible = props.Visible ~= false,
		Parent = props.Parent,
	})
	Kit.corner(plate, props.Radius or Theme.Radius)
	Kit.gradient(plate, Theme.lighten(color, 0.18), color, 90)
	if props.Border ~= false then
		Kit.border(plate, Theme.darken(color, 0.2), 1.5)
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
		BackgroundColor3 = C.Border,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1),
		LayoutOrder = order or 0,
		Parent = parent,
	})
end

function Kit.scroll(props: Props): ScrollingFrame
	return Kit.new("ScrollingFrame", {
		Name = props.Name or "Defilement",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = if props.Horizontal then Enum.AutomaticSize.X else Enum.AutomaticSize.Y,
		ScrollingDirection = if props.Horizontal then Enum.ScrollingDirection.X else Enum.ScrollingDirection.Y,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = C.BorderStrong,
		ZIndex = props.ZIndex or 1,
		LayoutOrder = props.Order or 0,
		Parent = props.Parent,
	})
end

-- Pastille arrondie (rareté, statut).
function Kit.pill(parent: Instance, text: string, color: Color3, order: number?, textColor: Color3?): Frame
	local pill = Kit.new("Frame", {
		Name = "Pastille",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = order or 0,
		Parent = parent,
	})
	Kit.round(pill)
	Kit.padding(pill, 10, 0)
	Kit.label({
		Text = string.upper(text),
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.Tiny,
		Color = textColor or Theme.onColor(color),
		Size = UDim2.fromOffset(0, 22),
		AutoSize = Enum.AutomaticSize.X,
		Parent = pill,
	})
	return pill
end

-- Fond plein écran ensoleillé : dégradé de la couleur donnée et larges
-- rayons de lumière obliques, très discrets.
function Kit.backdrop(parent: Instance, color: Color3?, zIndex: number?): Frame
	local tint = color or C.Accent
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
	Kit.gradient(back, Theme.lighten(tint, 0.35), Theme.darken(tint, 0.12), 110)
	for index, ray in { { X = 0.22, W = 0.14 }, { X = 0.5, W = 0.06 }, { X = 0.78, W = 0.2 } } do
		local frame = Kit.new("Frame", {
			BackgroundColor3 = C.White,
			BackgroundTransparency = 0.88 + index * 0.02,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(ray.X, 0.5),
			Size = UDim2.new(ray.W, 0, 2.2, 0),
			Rotation = 22,
			ZIndex = z,
			Parent = back,
		})
		Kit.tween(
			frame,
			TweenInfo.new(6 + index * 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Position = UDim2.fromScale(ray.X + 0.06, 0.5) }
		)
	end
	return back
end

-- Icônes dessinées en Frames -------------------------------------------------------------------

-- kind : "Coin" | "Ball" | "Star" | "Users" | "Info" | "Clan" | "Close" | "Lock" | "Cards" | "Plus"
function Kit.icon(kind: string, parent: Instance, size: number, color: Color3?, zIndex: number?): Frame
	local z = zIndex or 1
	local tint = color or C.Ink
	local holder = Kit.new("Frame", {
		Name = "Icone" .. kind,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		ZIndex = z,
		Parent = parent,
	})
	local function disc(scale: number, fill: Color3, x: number?, y: number?): Frame
		local frame = Kit.new("Frame", {
			BackgroundColor3 = fill,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x or 0.5, y or 0.5),
			Size = UDim2.fromScale(scale, scale),
			ZIndex = z,
			Parent = holder,
		})
		Kit.round(frame)
		return frame
	end
	local function glyph(text: string, textColor: Color3, scale: number?, font: Font?)
		Kit.label({
			Text = text,
			Font = font or Theme.Fonts.Hero,
			TextSize = math.floor(size * (scale or 0.6)),
			Color = textColor,
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			ZIndex = z + 1,
			Parent = holder,
		})
	end
	if kind == "Coin" then
		local coin = disc(1, C.Gold)
		Kit.gradient(coin, Color3.fromRGB(255, 226, 120), Color3.fromRGB(240, 160, 20), 90)
		Kit.border(coin, Color3.fromRGB(200, 120, 10), math.max(1, size / 14))
		glyph("H", Color3.fromRGB(150, 84, 0), 0.55)
	elseif kind == "Ball" then
		local ball = disc(1, C.White)
		Kit.border(ball, C.Ink, math.max(1, size / 14))
		for index, rotation in { -35, 35 } do
			local seam = Kit.new("Frame", {
				BackgroundColor3 = if index == 1 then C.Accent else C.Sky,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(0.96, 0, 0, math.max(2, size / 8)),
				Rotation = rotation,
				ZIndex = z,
				Parent = ball,
			})
			Kit.round(seam)
		end
	elseif kind == "Star" then
		glyph("★", tint, 0.95, Theme.Fonts.Bold)
	elseif kind == "Users" then
		disc(0.34, tint, 0.36, 0.3)
		disc(0.28, tint, 0.7, 0.34).BackgroundTransparency = 0.25
		local body = Kit.new("Frame", {
			BackgroundColor3 = tint,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.08, 0.56),
			Size = UDim2.fromScale(0.56, 0.38),
			ZIndex = z,
			Parent = holder,
		})
		Kit.corner(body, math.floor(size * 0.2))
		local body2 = Kit.new("Frame", {
			BackgroundColor3 = tint,
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.52, 0.58),
			Size = UDim2.fromScale(0.44, 0.32),
			ZIndex = z,
			Parent = holder,
		})
		Kit.corner(body2, math.floor(size * 0.16))
	elseif kind == "Info" then
		local circle = disc(1, tint)
		circle.BackgroundTransparency = 0
		glyph("i", Theme.onColor(tint), 0.7)
	elseif kind == "Clan" then
		local shield = Kit.new("Frame", {
			BackgroundColor3 = tint,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.04),
			Size = UDim2.fromScale(0.76, 0.78),
			ZIndex = z,
			Parent = holder,
		})
		Kit.corner(shield, math.floor(size * 0.18))
		local tip = Kit.new("Frame", {
			BackgroundColor3 = tint,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.72),
			Size = UDim2.fromScale(0.5, 0.5),
			Rotation = 45,
			ZIndex = z,
			Parent = holder,
		})
		Kit.corner(tip, math.floor(size * 0.06))
		Kit.label({
			Text = "★",
			Font = Theme.Fonts.Bold,
			TextSize = math.floor(size * 0.46),
			Color = Theme.onColor(tint),
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 0.8),
			ZIndex = z + 1,
			Parent = holder,
		})
	elseif kind == "Close" then
		glyph("×", tint, 1, Theme.Fonts.Bold)
	elseif kind == "Plus" then
		glyph("+", tint, 1, Theme.Fonts.Bold)
	elseif kind == "Lock" then
		local body = Kit.new("Frame", {
			BackgroundColor3 = tint,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.16, 0.44),
			Size = UDim2.fromScale(0.68, 0.5),
			ZIndex = z,
			Parent = holder,
		})
		Kit.corner(body, math.floor(size * 0.1))
		local shackle = Kit.new("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.28, 0.08),
			Size = UDim2.fromScale(0.44, 0.56),
			ZIndex = z,
			Parent = holder,
		})
		Kit.round(shackle)
		Kit.border(shackle, tint, math.max(2, size / 9))
	elseif kind == "Cards" then
		for index = 1, 2 do
			local card = Kit.new("Frame", {
				BackgroundColor3 = if index == 1 then Theme.lighten(tint, 0.35) else tint,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(if index == 1 then 0.4 else 0.58, 0.52),
				Size = UDim2.fromScale(0.5, 0.74),
				Rotation = if index == 1 then -12 else 8,
				ZIndex = z,
				Parent = holder,
			})
			Kit.corner(card, math.floor(size * 0.08))
			Kit.border(card, C.White, math.max(1, size / 20))
		end
	end
	return holder
end

-- Boutons ---------------------------------------------------------------------------------------------

export type Variant = "Primary" | "Secondary" | "Light" | "Ghost" | "Danger" | "Success" | "Gold"

export type Button = {
	Instance: TextButton,
	Label: TextLabel,
	SetText: (string) -> (),
	SetEnabled: (boolean) -> (),
	SetVariant: (Variant) -> (),
	SetSelected: (boolean) -> (),
	SetColor: (Color3) -> (),
}

type Look = { Base: Color3, Text: Color3?, Flat: boolean? }

local VARIANTS: { [string]: Look } = {
	Primary = { Base = C.Accent },
	Secondary = { Base = C.Sky },
	Light = { Base = C.White, Text = C.Ink },
	Ghost = { Base = C.Surface3, Text = C.TextMuted, Flat = true },
	Danger = { Base = C.Danger },
	Success = { Base = C.Success },
	Gold = { Base = C.Gold },
}

function Kit.playSound(soundId: string, volume: number?)
	if soundId == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.5
	sound.PlaybackSpeed = 0.96 + math.random() * 0.08
	sound.Parent = SoundService
	SoundService:PlayLocalSound(sound)
	task.delay(4, function()
		sound:Destroy()
	end)
end

-- Bouton « bonbon » : face en dégradé posée sur une tranche plus foncée.
-- Au survol il grossit légèrement, au clic la face s'enfonce.
-- props.Color remplace la couleur de la variante ; props.Radius = rayon.
function Kit.button(props: Props): Button
	local variant: string = props.Variant or "Secondary"
	local custom: Color3? = props.Color
	local enabled = true
	local selected = false
	local hovering = false
	local z = props.ZIndex or 1
	local radius: number = props.Radius or Theme.Radius
	local function look(): Look
		return VARIANTS[variant] or VARIANTS.Secondary
	end
	local depth = if look().Flat then 0 else (props.Depth or 4)

	local button = Kit.new("TextButton", {
		Name = props.Name or "Bouton",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		Size = props.Size or UDim2.fromOffset(180, 46),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		AutomaticSize = props.AutoSize or Enum.AutomaticSize.None,
		LayoutOrder = props.Order or 0,
		ZIndex = z,
		Parent = props.Parent,
	})
	local scale = Kit.new("UIScale", { Parent = button })
	-- Tranche (le bas épais du bouton) : porte la face.
	local edge = Kit.new("Frame", {
		Name = "Tranche",
		BackgroundColor3 = C.AccentDark,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -depth),
		Position = UDim2.fromOffset(0, depth),
		ZIndex = z,
		Parent = button,
	})
	Kit.corner(edge, radius)
	local face = Kit.new("Frame", {
		Name = "Face",
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, -depth),
		ZIndex = z,
		Parent = edge,
	})
	Kit.corner(face, radius)
	local faceGradient = Kit.gradient(face, C.AccentLight, C.Accent, 90)
	local stroke = Kit.border(face, C.AccentDark, 1.5)
	local gloss = Kit.new("Frame", {
		Name = "Reflet",
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.78,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -10, 0.42, -2),
		Position = UDim2.fromOffset(5, 3),
		ZIndex = z,
		Parent = face,
	})
	Kit.corner(gloss, math.max(4, radius - 4))
	Kit.new("UIGradient", {
		Transparency = NumberSequence.new(0.1, 1),
		Rotation = 90,
		Parent = gloss,
	})
	local label = Kit.label({
		Text = props.Text or "",
		Font = props.Font or Theme.Fonts.Display,
		TextSize = props.TextSize or Theme.Text.Body,
		Color = C.White,
		AlignX = props.AlignX or Enum.TextXAlignment.Center,
		Size = if props.AutoSize then UDim2.fromScale(0, 1) else UDim2.new(1, -20, 1, 0),
		Position = if props.AutoSize then UDim2.new() else UDim2.fromOffset(10, 0),
		AutoSize = if props.AutoSize then Enum.AutomaticSize.X else nil,
		ZIndex = z + 1,
		Parent = face,
	})
	local labelStroke = Kit.ink(label, 1.5, C.AccentDark)
	if props.AutoSize then
		-- Le libellé dimensionne le bouton : il reste dans le flux du bouton.
		label.Parent = button
		label.Size = UDim2.new(0, 0, 1, -depth)
		label.ZIndex = z + 2
		Kit.padding(label, 22, 0)
	end

	local function setPressed(pressed: boolean)
		local offset = if pressed then depth - 1 else 0
		face.Position = UDim2.fromOffset(0, -depth + offset)
		if props.AutoSize then
			label.Position = UDim2.fromOffset(0, offset)
		end
	end

	local function paint()
		local current = look()
		local base = custom or current.Base
		if selected then
			base = C.Accent
		end
		local textColor = if custom then Theme.onColor(base) elseif selected then C.White else current.Text or C.White
		local dark = Theme.darken(base, 0.24)
		if not enabled then
			base = C.Surface3
			dark = C.BorderStrong
			textColor = C.TextFaint
		end
		edge.BackgroundColor3 = if current.Flat and not selected then base else dark
		faceGradient.Color = if current.Flat and not selected
			then ColorSequence.new(base, base)
			else ColorSequence.new(Theme.lighten(base, if hovering and enabled then 0.32 else 0.22), base)
		stroke.Color = if base == C.White then C.Border else dark
		stroke.Transparency = if current.Flat and not selected then 1 else 0
		gloss.Visible = enabled and not (current.Flat and not selected)
		label.TextColor3 = if hovering and current.Flat and enabled and not selected then C.Text else textColor
		labelStroke.Enabled = enabled and textColor == C.White and not (current.Flat and not selected)
		labelStroke.Color = dark
	end

	button.MouseEnter:Connect(function()
		hovering = true
		paint()
		if enabled then
			Kit.tween(scale, Theme.Motion.Fast, { Scale = 1.04 })
			Kit.playSound(Theme.Sounds.Hover, 0.15)
		end
	end)
	button.MouseLeave:Connect(function()
		hovering = false
		paint()
		setPressed(false)
		Kit.tween(scale, Theme.Motion.Base, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		if enabled then
			setPressed(true)
		end
	end)
	button.MouseButton1Up:Connect(function()
		setPressed(false)
	end)
	button.Activated:Connect(function()
		if not enabled then
			return
		end
		setPressed(false)
		Kit.playSound(Theme.Sounds.Click, 0.35)
		if props.OnClick then
			task.spawn(props.OnClick)
		end
	end)
	paint()

	return {
		Instance = button,
		Label = label,
		SetText = function(text: string)
			label.Text = text
		end,
		SetEnabled = function(value: boolean)
			enabled = value
			button.Active = value
			setPressed(false)
			paint()
		end,
		SetVariant = function(value: Variant)
			variant = value
			paint()
		end,
		SetSelected = function(value: boolean)
			selected = value
			paint()
		end,
		SetColor = function(value: Color3)
			custom = value
			paint()
		end,
	}
end

-- Bouton rond avec icône et libellé dessous (barre latérale du lobby).
export type RoundButton = {
	Instance: TextButton,
	Badge: Frame,
	SetBadge: (boolean) -> (),
}

function Kit.roundButton(props: Props): RoundButton
	local size: number = props.Size or 76
	local color: Color3 = props.Color or C.Accent
	local z = props.ZIndex or 1
	local holder = Kit.new("TextButton", {
		Name = props.Name or "BoutonRond",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.fromOffset(size + 24, size + 30),
		Position = props.Position or UDim2.new(),
		LayoutOrder = props.Order or 0,
		ZIndex = z,
		Parent = props.Parent,
	})
	local scale = Kit.new("UIScale", { Parent = holder })
	local edge = Kit.new("Frame", {
		BackgroundColor3 = Theme.darken(color, 0.25),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 5),
		Size = UDim2.fromOffset(size, size),
		ZIndex = z,
		Parent = holder,
	})
	Kit.round(edge)
	local face = Kit.new("Frame", {
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, -5),
		Size = UDim2.fromScale(1, 1),
		ZIndex = z,
		Parent = edge,
	})
	Kit.round(face)
	Kit.gradient(face, Theme.lighten(color, 0.28), color, 90)
	Kit.border(face, C.White, 3)
	local icon = Kit.icon(props.Icon or "Info", face, math.floor(size * 0.5), C.White, z + 1)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	local caption = Kit.label({
		Text = props.Text or "",
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.Small,
		Color = C.White,
		Stroke = 2,
		StrokeColor = C.Ink,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 0, size + 4),
		ZIndex = z + 2,
		Parent = holder,
	})
	caption.TextTruncate = Enum.TextTruncate.None
	local badge = Kit.new("Frame", {
		Name = "Pastille",
		BackgroundColor3 = C.Danger,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(18, 18),
		Position = UDim2.new(0.5, size / 2 - 14, 0, 0),
		Visible = false,
		ZIndex = z + 3,
		Parent = holder,
	})
	Kit.round(badge)
	Kit.border(badge, C.White, 2.5)
	holder.MouseEnter:Connect(function()
		Kit.tween(scale, Theme.Motion.Spring, { Scale = 1.08 })
		Kit.playSound(Theme.Sounds.Hover, 0.15)
	end)
	holder.MouseLeave:Connect(function()
		Kit.tween(scale, Theme.Motion.Base, { Scale = 1 })
		face.Position = UDim2.fromOffset(0, -5)
	end)
	holder.MouseButton1Down:Connect(function()
		face.Position = UDim2.fromOffset(0, -1)
	end)
	holder.MouseButton1Up:Connect(function()
		face.Position = UDim2.fromOffset(0, -5)
	end)
	holder.Activated:Connect(function()
		face.Position = UDim2.fromOffset(0, -5)
		Kit.playSound(Theme.Sounds.Click, 0.35)
		if props.OnClick then
			task.spawn(props.OnClick)
		end
	end)
	return {
		Instance = holder,
		Badge = badge,
		SetBadge = function(value: boolean)
			badge.Visible = value
		end,
	}
end

-- Bouton de fermeture rond (coin des fenêtres).
function Kit.closeButton(parent: Instance, zIndex: number, onClick: () -> ()): TextButton
	local button = Kit.new("TextButton", {
		Name = "Fermer",
		AutoButtonColor = false,
		BackgroundColor3 = C.Danger,
		BorderSizePixel = 0,
		Text = "",
		Size = UDim2.fromOffset(44, 44),
		ZIndex = zIndex,
		Parent = parent,
	})
	Kit.round(button)
	Kit.gradient(button, Theme.lighten(C.Danger, 0.25), C.Danger, 90)
	Kit.border(button, C.White, 3)
	local icon = Kit.icon("Close", button, 34, C.White, zIndex + 1)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.new(0.5, 0, 0.5, -2)
	local scale = Kit.new("UIScale", { Parent = button })
	button.MouseEnter:Connect(function()
		Kit.tween(scale, Theme.Motion.Spring, { Scale = 1.1 })
	end)
	button.MouseLeave:Connect(function()
		Kit.tween(scale, Theme.Motion.Base, { Scale = 1 })
	end)
	button.Activated:Connect(function()
		Kit.playSound(Theme.Sounds.Click, 0.35)
		onClick()
	end)
	return button
end

-- Sélecteur segmenté (ex. Gardien | Défenseur | Attaquant).
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
		Color = C.Surface3,
		Border = false,
		Radius = props.Radius or Theme.Radius,
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
			button.BackgroundTransparency = if isOn then 0 else 1
			local gradient = button:FindFirstChildOfClass("UIGradient")
			if gradient then
				gradient.Enabled = isOn
			end
			local label = button:FindFirstChild("Texte") :: TextLabel
			label.TextColor3 = if disabled[id] then C.TextFaint elseif isOn then Theme.onColor(accent) else C.TextMuted
		end
	end
	for index, option in options do
		local button = Kit.new("TextButton", {
			AutoButtonColor = false,
			BackgroundColor3 = C.White,
			BorderSizePixel = 0,
			Text = "",
			Size = UDim2.new(width, -4 + 4 / #options, 1, 0),
			LayoutOrder = index,
			ZIndex = (props.ZIndex or 1) + 1,
			Parent = row,
		})
		Kit.corner(button, math.max(4, (props.Radius or Theme.Radius) - 3))
		Kit.gradient(button, Theme.lighten(accent, 0.2), accent, 90)
		Kit.label({
			Text = option.Label,
			Font = Theme.Fonts.Display,
			TextSize = props.TextSize or Theme.Text.Small,
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
			Kit.pop(button, 0.9)
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

-- Barre de progression arrondie ; renvoie la fonction de mise à jour.
function Kit.progress(props: Props): (Frame, (number) -> ())
	local back = Kit.new("Frame", {
		Name = props.Name or "Progression",
		BackgroundColor3 = props.Back or C.Surface3,
		BorderSizePixel = 0,
		Size = props.Size or UDim2.fromOffset(200, 8),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		ClipsDescendants = true,
		LayoutOrder = props.Order or 0,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	})
	Kit.round(back)
	local color: Color3 = props.Color or C.Accent
	local fill = Kit.new("Frame", {
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		ZIndex = (props.ZIndex or 1) + 1,
		Parent = back,
	})
	Kit.round(fill)
	Kit.gradient(fill, Theme.lighten(color, 0.3), color, 90)
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

-- Apparition : petit glissement vers le haut avec un léger rebond.
function Kit.reveal(object: GuiObject, delay: number?, distance: number?)
	local target = object.Position
	object.Position = target + UDim2.fromOffset(0, distance or 18)
	local scale = object:FindFirstChildOfClass("UIScale") or Kit.new("UIScale", { Parent = object })
	scale.Scale = 0.94
	object.Visible = false
	task.delay(delay or 0, function()
		if not object.Parent then
			return
		end
		object.Visible = true
		Kit.tween(object, Theme.Motion.Slow, { Position = target })
		Kit.tween(scale, Theme.Motion.Spring, { Scale = 1 })
	end)
end

function Kit.pop(object: GuiObject, from: number?)
	local scale = object:FindFirstChildOfClass("UIScale") or Kit.new("UIScale", { Parent = object })
	scale.Scale = from or 0.85
	Kit.tween(scale, Theme.Motion.Spring, { Scale = 1 })
end

-- Arrivée percutante : l'objet arrive plus grand et se pose avec un rebond.
function Kit.slam(object: GuiObject, from: number?)
	local scale = object:FindFirstChildOfClass("UIScale") or Kit.new("UIScale", { Parent = object })
	scale.Scale = from or 1.8
	Kit.tween(scale, Theme.Motion.Bounce, { Scale = 1 })
end

-- Secousse courte (en pixels) : réservée aux grands moments.
function Kit.shake(object: GuiObject, strength: number?, duration: number?)
	local origin = object.Position
	local power = strength or 5
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
