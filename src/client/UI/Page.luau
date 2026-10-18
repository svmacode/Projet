--!strict
-- Fenêtre centrée (Archétypes, Clan, Groupe, Infos) et barre d'onglets.
-- Une seule fenêtre ouverte à la fois : le monde 3D reste visible derrière.

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)

local C = Theme.Colors

local Page = {}

export type Page = {
	Container: GuiObject,
	Window: Frame,
	Content: Frame,
	Open: () -> (),
	Close: () -> (),
	IsOpen: () -> boolean,
}

-- Fenêtre : bandeau de titre coloré, contenu sur fond blanc, bouton fermer rond.
function Page.modal(parent: Instance, title: string, size: Vector2, onClose: () -> (), color: Color3?): Page
	local accent = color or C.Accent
	local backdrop = Kit.new("TextButton", {
		Name = title,
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = C.Overlay,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 30,
		Parent = parent,
	})
	local window = Kit.surface({
		Name = "Fenetre",
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromScale(0.5, 0.52),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Radius = Theme.RadiusLarge,
		Transparency = 0.02,
		BorderColor = C.White,
		BorderThickness = 3,
		ZIndex = 31,
		Parent = backdrop,
	})
	local scale = Kit.new("UIScale", { Parent = window })
	local header = Kit.new("Frame", {
		Name = "Bandeau",
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 72),
		ZIndex = 32,
		Parent = window,
	})
	Kit.corner(header, Theme.RadiusLarge)
	Kit.gradient(header, Theme.lighten(accent, 0.2), accent, 90)
	-- Le bas du bandeau reste droit.
	local flat = Kit.new("Frame", {
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 1, -20),
		ZIndex = 32,
		Parent = header,
	})
	Kit.gradient(flat, Theme.lighten(accent, 0.05), accent, 90)
	Kit.title({
		Text = string.upper(title),
		TextSize = Theme.Text.H1,
		StrokeColor = Theme.darken(accent, 0.35),
		Size = UDim2.new(1, -120, 1, 0),
		Position = UDim2.fromOffset(28, 0),
		ZIndex = 33,
		Parent = header,
	})
	local close = Kit.closeButton(window, 36, onClose)
	close.AnchorPoint = Vector2.new(0.5, 0.5)
	close.Position = UDim2.new(1, -12, 0, 12)
	local content = Kit.box({
		Name = "Contenu",
		Size = UDim2.new(1, -56, 1, -104),
		Position = UDim2.fromOffset(28, 88),
		ZIndex = 32,
		Parent = window,
	})
	local isOpen = false
	return {
		Container = backdrop,
		Window = window,
		Content = content,
		Open = function()
			isOpen = true
			backdrop.Visible = true
			backdrop.BackgroundTransparency = 1
			Kit.tween(backdrop, Theme.Motion.Base, { BackgroundTransparency = 0.55 })
			scale.Scale = 0.86
			Kit.tween(scale, Theme.Motion.Spring, { Scale = 1 })
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

-- Onglets en pilules : l'onglet actif est rempli de couleur.
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
	local bar = Kit.surface({
		Name = "Onglets",
		Color = C.Surface3,
		Border = false,
		Radius = 22,
		Size = UDim2.fromOffset(0, 44),
		AutoSize = Enum.AutomaticSize.X,
		ZIndex = z,
		Parent = parent,
	})
	Kit.padding(bar, 4)
	Kit.list(bar, 4, true, nil, Enum.VerticalAlignment.Center)
	type Entry = { Button: TextButton, Gradient: UIGradient, Label: TextLabel }
	local entries: { [string]: Entry } = {}
	local function select(name: string)
		for key, entry in entries do
			local on = key == name
			entry.Button.BackgroundTransparency = if on then 0 else 1
			entry.Gradient.Enabled = on
			entry.Label.TextColor3 = if on then C.White else C.TextMuted
			if on then
				Kit.pop(entry.Button, 0.92)
			end
		end
		onSelect(name)
	end
	for index, name in names do
		local button = Kit.new("TextButton", {
			AutoButtonColor = false,
			BackgroundColor3 = C.White,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = "",
			Size = UDim2.fromOffset(0, 36),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = index,
			ZIndex = z + 1,
			Parent = bar,
		})
		Kit.round(button)
		local gradient = Kit.gradient(button, Theme.lighten(accent, 0.2), accent, 90)
		gradient.Enabled = false
		local label = Kit.label({
			Text = string.upper(name),
			Font = Theme.Fonts.Display,
			TextSize = Theme.Text.Small,
			Color = C.TextMuted,
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.fromOffset(0, 36),
			AutoSize = Enum.AutomaticSize.X,
			ZIndex = z + 2,
			Parent = button,
		})
		Kit.padding(label, 20, 0)
		entries[name] = { Button = button, Gradient = gradient, Label = label }
		button.Activated:Connect(function()
			Kit.playSound(Theme.Sounds.Click, 0.3)
			select(name)
		end)
	end
	return select
end

return Page
