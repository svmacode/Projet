--!strict
-- Page plein écran sous la barre de navigation (Casier, Boutique, Clan…)
-- ou fenêtre centrée (Tutoriel, Nouveautés). Chaque page porte la couleur
-- de sa section : bandeau de titre incliné, fond animé, onglets.

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)

local C = Theme.Colors

local Page = {}

export type Page = {
	Container: Frame,
	Content: Frame,
	Open: () -> (),
	Close: () -> (),
	IsOpen: () -> boolean,
}

local TOP_BAR = 72

-- Bandeau incliné qui s'ajuste à la largeur de son titre.
local function titlePlate(parent: Instance, text: string, accent: Color3, height: number, textSize: number, z: number)
	local plate = Kit.plate({
		Color = accent,
		Size = UDim2.fromOffset(240, height),
		ZIndex = z,
		Parent = parent,
	})
	local heading = Kit.title({
		Text = string.upper(text),
		TextSize = textSize,
		Color = Theme.onColor(accent),
		ShadowColor = Theme.darken(accent, 0.45),
		Stroke = if Theme.onColor(accent) == C.White then 2 else 0.01,
		Offset = 3,
		Size = UDim2.new(1, -36, 1, 0),
		Position = UDim2.fromOffset(18, 1),
		ZIndex = z + 1,
		Parent = plate,
	})
	local function fit()
		plate.Size = UDim2.fromOffset(heading.Label.TextBounds.X + 48, height)
	end
	heading.Label:GetPropertyChangedSignal("TextBounds"):Connect(fit)
	fit()
	return plate
end

function Page.full(parent: Instance, title: string, subtitle: string, color: Color3?): Page
	local accent = color or C.Accent
	local container = Kit.new("Frame", {
		Name = title,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -TOP_BAR),
		Position = UDim2.fromOffset(0, TOP_BAR),
		Visible = false,
		ZIndex = 10,
		Parent = parent,
	})
	Kit.backdrop(container, accent, 10)
	local inner = Kit.box({
		Size = UDim2.new(1, -96, 1, -48),
		Position = UDim2.fromOffset(48, 32),
		ZIndex = 10,
		Parent = container,
	})
	local plate = titlePlate(inner, title, accent, 58, Theme.Text.H1 + 8, 11)
	plate.Position = UDim2.fromOffset(-6, 4)
	Kit.label({
		Text = subtitle,
		Font = Theme.Fonts.Semibold,
		TextSize = Theme.Text.Body,
		Color = C.TextMuted,
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(4, 74),
		ZIndex = 11,
		Parent = inner,
	})
	local content = Kit.box({
		Name = "Contenu",
		Size = UDim2.new(1, 0, 1, -112),
		Position = UDim2.fromOffset(0, 112),
		ZIndex = 11,
		Parent = inner,
	})
	local isOpen = false
	return {
		Container = container,
		Content = content,
		Open = function()
			isOpen = true
			container.Visible = true
			inner.Position = UDim2.fromOffset(12, 32)
			Kit.tween(inner, Theme.Motion.Slow, { Position = UDim2.fromOffset(48, 32) })
			Kit.slam(plate, 1.5)
		end,
		Close = function()
			isOpen = false
			container.Visible = false
		end,
		IsOpen = function()
			return isOpen
		end,
	}
end

function Page.modal(parent: Instance, title: string, size: Vector2, onClose: () -> (), color: Color3?): Page
	local accent = color or C.Accent
	local backdrop = Kit.new("TextButton", {
		Name = title,
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 30,
		Parent = parent,
	})
	Kit.speedLines({ Parent = backdrop, Color = accent, Count = 16, Transparency = 0.82, ZIndex = 30 })
	local window = Kit.surface({
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Radius = Theme.RadiusLarge,
		BorderThickness = 3,
		Shadow = true,
		ShadowOffset = 8,
		ShadowColor = accent,
		ZIndex = 31,
		Parent = backdrop,
	})
	-- Bande de couleur en haut de la fenêtre.
	local band = Kit.new("Frame", {
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 6),
		ZIndex = 32,
		Parent = window,
	})
	Kit.corner(band, 3)
	local plate = titlePlate(window, title, accent, 46, Theme.Text.H2 + 6, 33)
	plate.Position = UDim2.fromOffset(24, 22)
	Kit.button({
		Text = "Fermer",
		Variant = "Ghost",
		Size = UDim2.fromOffset(100, 38),
		Position = UDim2.new(1, -24, 0, 24),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = 33,
		Parent = window,
		OnClick = onClose,
	})
	local content = Kit.box({
		Name = "Contenu",
		Size = UDim2.new(1, -64, 1, -116),
		Position = UDim2.fromOffset(32, 100),
		ZIndex = 32,
		Parent = window,
	})
	local isOpen = false
	return {
		Container = backdrop,
		Content = content,
		Open = function()
			isOpen = true
			backdrop.Visible = true
			Kit.pop(window, 0.9)
			Kit.slam(plate, 1.6)
		end,
		Close = function()
			isOpen = false
			backdrop.Visible = false
		end,
		IsOpen = function()
			return isOpen
		end,
	}
end

-- Onglets en plaques inclinées : l'onglet actif est rempli de couleur.
-- Renvoie la fonction de sélection.
function Page.tabs(
	parent: Instance,
	names: { string },
	onSelect: (string) -> (),
	zIndex: number?,
	color: Color3?
): (string) -> ()
	local accent = color or C.Accent
	local z = zIndex or 1
	local bar = Kit.box({ Name = "Onglets", Size = UDim2.new(1, 0, 0, 44), ZIndex = z, Parent = parent })
	Kit.list(bar, 12, true, nil, Enum.VerticalAlignment.Center)
	local entries: { [string]: { Back: Frame, Label: TextLabel, Stroke: UIStroke } } = {}
	local function select(name: string)
		for key, entry in entries do
			local on = key == name
			entry.Back.BackgroundTransparency = if on then 0 else 1
			entry.Stroke.Color = if on then C.Ink else C.Surface3
			entry.Label.TextColor3 = if on then Theme.onColor(accent) else C.TextMuted
			if on then
				Kit.pop(entry.Back, 0.85)
			end
		end
		onSelect(name)
	end
	for index, name in names do
		local button = Kit.new("TextButton", {
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Text = "",
			Size = UDim2.fromOffset(0, 40),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = index,
			ZIndex = z,
			Parent = bar,
		})
		local back = Kit.new("Frame", {
			BackgroundColor3 = accent,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Rotation = Theme.Tilt,
			ZIndex = z,
			Parent = button,
		})
		local stroke = Kit.border(back, C.Surface3, 2.5)
		local label = Kit.label({
			Text = string.upper(name),
			Font = Theme.Fonts.Display,
			TextSize = Theme.Text.H3,
			Color = C.TextMuted,
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.fromOffset(0, 40),
			AutoSize = Enum.AutomaticSize.X,
			ZIndex = z + 1,
			Parent = button,
		})
		Kit.padding(label, 18, 0)
		entries[name] = { Back = back, Label = label, Stroke = stroke }
		button.Activated:Connect(function()
			select(name)
		end)
	end
	return select
end

return Page
