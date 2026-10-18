--!strict
-- Page plein écran sous la barre de navigation (Casier, Boutique, Clan…)
-- ou fenêtre centrée (Tutoriel, Nouveautés).

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

function Page.full(parent: Instance, title: string, subtitle: string): Page
	local container = Kit.new("Frame", {
		Name = title,
		BackgroundColor3 = C.Background,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -TOP_BAR),
		Position = UDim2.fromOffset(0, TOP_BAR),
		Visible = false,
		ZIndex = 10,
		Parent = parent,
	})
	local inner = Kit.box({
		Size = UDim2.new(1, -96, 1, -48),
		Position = UDim2.fromOffset(48, 32),
		ZIndex = 10,
		Parent = container,
	})
	Kit.label({
		Text = title,
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.H1,
		Size = UDim2.new(1, 0, 0, 44),
		ZIndex = 11,
		Parent = inner,
	})
	Kit.label({
		Text = subtitle,
		TextSize = Theme.Text.Body,
		Color = C.TextMuted,
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 44),
		ZIndex = 11,
		Parent = inner,
	})
	local content = Kit.box({
		Name = "Contenu",
		Size = UDim2.new(1, 0, 1, -88),
		Position = UDim2.fromOffset(0, 88),
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
			inner.Position = UDim2.fromOffset(48, 48)
			Kit.tween(inner, Theme.Motion.Slow, { Position = UDim2.fromOffset(48, 32) })
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

function Page.modal(parent: Instance, title: string, size: Vector2, onClose: () -> ()): Page
	local backdrop = Kit.new("TextButton", {
		Name = title,
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = C.Background,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 30,
		Parent = parent,
	})
	local window = Kit.surface({
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Radius = Theme.RadiusLarge,
		ZIndex = 31,
		Parent = backdrop,
	})
	Kit.label({
		Text = title,
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.H2,
		Size = UDim2.new(1, -120, 0, 32),
		Position = UDim2.fromOffset(32, 26),
		ZIndex = 32,
		Parent = window,
	})
	Kit.button({
		Text = "Fermer",
		Variant = "Ghost",
		Size = UDim2.fromOffset(96, 36),
		Position = UDim2.new(1, -24, 0, 24),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = 33,
		Parent = window,
		OnClick = onClose,
	})
	Kit.new("Frame", {
		BackgroundColor3 = C.Border,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.fromOffset(0, 80),
		ZIndex = 32,
		Parent = window,
	})
	local content = Kit.box({
		Name = "Contenu",
		Size = UDim2.new(1, -64, 1, -112),
		Position = UDim2.fromOffset(32, 104),
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
			Kit.pop(window, 0.96)
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

-- Barre d'onglets horizontale (texte souligné). Renvoie la fonction de sélection.
function Page.tabs(parent: Instance, names: { string }, onSelect: (string) -> (), zIndex: number?): (string) -> ()
	local bar = Kit.box({ Name = "Onglets", Size = UDim2.new(1, 0, 0, 40), ZIndex = zIndex, Parent = parent })
	Kit.list(bar, 28, true)
	local entries: { [string]: { Label: TextLabel, Line: Frame } } = {}
	local function select(name: string)
		for key, entry in entries do
			local on = key == name
			entry.Label.TextColor3 = if on then C.Text else C.TextMuted
			entry.Line.Visible = on
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
			ZIndex = zIndex,
			Parent = bar,
		})
		local label = Kit.label({
			Text = name,
			Font = Theme.Fonts.Bold,
			TextSize = Theme.Text.H3,
			Color = C.TextMuted,
			Size = UDim2.fromOffset(0, 32),
			AutoSize = Enum.AutomaticSize.X,
			ZIndex = zIndex,
			Parent = button,
		})
		local line = Kit.new("Frame", {
			BackgroundColor3 = C.Accent,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 3),
			Position = UDim2.new(0, 0, 1, -3),
			Visible = false,
			ZIndex = zIndex,
			Parent = button,
		})
		entries[name] = { Label = label, Line = line }
		button.Activated:Connect(function()
			select(name)
		end)
	end
	Kit.new("Frame", {
		BackgroundColor3 = C.Border,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		ZIndex = zIndex,
		Parent = parent,
	}).Position =
		UDim2.fromOffset(0, 40)
	return select
end

return Page
