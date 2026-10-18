--!strict
-- Cadre commun des écrans du lobby : grande case de manga avec bandeau de
-- titre, bouton de fermeture et zone de contenu.

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)

local C = Theme.Colors

local ScreenFrame = {}

export type Screen = {
	Container: Frame,
	Content: Frame,
	Open: () -> (),
	Close: () -> (),
}

function ScreenFrame.new(parent: Instance, title: string, japanese: string, color: Color3, onClose: () -> ()): Screen
	local face, container = Kit.panel({
		Name = title,
		Size = UDim2.fromOffset(1120, 700),
		Position = UDim2.new(0.5, 150, 0.5, 20),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = C.Paper,
		ShadowOffset = 10,
		StrokeThickness = 5,
		ZIndex = 20,
		Parent = parent,
	})
	container.Visible = false
	Kit.halftone(face, C.PaperDark, Vector2.new(1, 1), 7, 18)
	Kit.header(face, title, color, japanese)

	local close = Kit.button({
		Text = "✕",
		Color = C.Red,
		TextColor = C.Paper,
		Size = UDim2.fromOffset(58, 58),
		Position = UDim2.new(1, -30, 0, -30),
		Font = Theme.Fonts.Heavy,
		ZIndex = 30,
		Parent = face,
		OnClick = onClose,
	})
	local _ = close

	local content = Kit.new("Frame", {
		Name = "Contenu",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -48, 1, -96),
		Position = UDim2.fromOffset(24, 70),
		ZIndex = 21,
		Parent = face,
	})

	local function open()
		container.Visible = true
		container.Position = UDim2.new(0.5, 150, 0.5, 60)
		Kit.tween(container, Theme.Tween.Slide, { Position = UDim2.new(0.5, 150, 0.5, 20) })
		Kit.pop(container, 0.92)
	end
	local function hide()
		container.Visible = false
	end
	return { Container = container, Content = content, Open = open, Close = hide }
end

-- Onglets en haut d'un écran ; renvoie la fonction de sélection.
function ScreenFrame.tabs(parent: Instance, names: { string }, onSelect: (string) -> ()): (string) -> ()
	local bar = Kit.new("Frame", {
		Name = "Onglets",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 52),
		ZIndex = 22,
		Parent = parent,
	})
	Kit.list(bar, 14, true)
	local buttons: { [string]: Kit.Button } = {}
	local function select(name: string)
		for key, button in buttons do
			button.SetColor(if key == name then C.Yellow else C.PaperDark)
		end
		onSelect(name)
	end
	for index, name in names do
		buttons[name] = Kit.button({
			Text = name,
			Color = C.PaperDark,
			Size = UDim2.fromOffset(200, 46),
			Order = index,
			ZIndex = 23,
			Parent = bar,
			OnClick = function()
				select(name)
			end,
		})
	end
	return select
end

return ScreenFrame
