--!strict
-- TUTORIEL (onglet de la fenêtre Infos) : règles et commandes, étape par étape.
-- Les étapes sont écrites ici pour suivre les règles simplifiées du jeu.

local Kit = require(script.Parent.Parent.UI.Kit)
local State = require(script.Parent.Parent.Controllers.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors

local TutorialScreen = {}

type Step = { Title: string, Body: string, Keys: { { string } } }

local STEPS: { Step } = {
	{
		Title = "Bienvenue au lycée Seiryō",
		Body = "Pour jouer, marche sur un terrain de la cour : 2v2, 3v3, 4v4 ou 5v5. "
			.. "La partie démarre dès que le terrain est complet. Le classé s'ouvre au niveau 10.",
		Keys = {},
	},
	{
		Title = "Se déplacer",
		Body = "Cours, saute et utilise le dash pour prendre de vitesse ton adversaire.",
		Keys = { { "ZQSD / WASD", "Courir" }, { "Espace", "Sauter" }, { "Shift", "Dash" } },
	},
	{
		Title = "Passer",
		Body = "La passe part vers le coéquipier le plus proche de ta visée. Les adversaires peuvent l'intercepter.",
		Keys = { { "E", "Passe" }, { "Souris", "Viser" } },
	},
	{
		Title = "Tirer au bon moment",
		Body = "Maintiens le clic : un curseur fait des allers-retours sur la jauge. "
			.. "Relâche-le dans la zone dorée pour un tir PARFAIT, le plus puissant et le plus précis.",
		Keys = { { "Clic gauche (maintenir)", "Charger le tir" }, { "Relâcher", "Tirer" } },
	},
	{
		Title = "Défendre",
		Body = "Contre les tirs, coupe les passes et va au contact du porteur de face. "
			.. "Un contact par derrière ou sur un joueur sans ballon est une faute : jet franc pour l'adversaire.",
		Keys = { { "F", "Contre / interception" } },
	},
	{
		Title = "Les règles",
		Body = "3 secondes maximum avec le ballon. Seul le gardien peut entrer dans sa zone des 6 mètres. "
			.. "Deux mi-temps de 2 min 30 ; en cas d'égalité, le prochain but l'emporte.",
		Keys = {},
	},
	{
		Title = "Les pouvoirs",
		Body = "Chaque archétype a 3 pouvoirs : le 1 se recharge en 15 s, le 2 se charge en touchant le ballon, "
			.. "le 3 est l'ultime. Obtiens de nouveaux archétypes dans les Balles. 3 balles offertes après ta 1re partie !",
		Keys = { { "1", "Pouvoir 1" }, { "2", "Pouvoir 2" }, { "3", "Ultime" } },
	},
}

-- Construit l'onglet dans `parent`.
function TutorialScreen.build(parent: Instance, z: number)
	local index = 1
	local body = Kit.box({ Size = UDim2.new(1, 0, 1, -72), ZIndex = z, Parent = parent })
	local footer = Kit.box({
		Size = UDim2.new(1, 0, 0, 56),
		Position = UDim2.new(0, 0, 1, -56),
		ZIndex = z,
		Parent = parent,
	})
	local dots = Kit.box({
		Size = UDim2.fromOffset(400, 12),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		ZIndex = z,
		Parent = footer,
	})
	Kit.list(dots, 8, true, nil, Enum.VerticalAlignment.Center)
	local previous: Kit.Button
	local nextButton: Kit.Button

	local function render()
		Kit.clear(body)
		Kit.clear(dots)
		local step = STEPS[index]
		local number = Kit.new("Frame", {
			BackgroundColor3 = C.White,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(64, 64),
			ZIndex = z + 1,
			Parent = body,
		})
		Kit.round(number)
		Kit.gradient(number, Theme.lighten(C.Success, 0.25), C.Success, 90)
		Kit.label({
			Text = tostring(index),
			Font = Theme.Fonts.Number,
			TextSize = 32,
			Color = C.White,
			Stroke = 1.5,
			StrokeColor = Theme.darken(C.Success, 0.3),
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			ZIndex = z + 2,
			Parent = number,
		})
		Kit.pop(number, 0.6)
		Kit.label({
			Text = step.Title,
			Font = Theme.Fonts.Display,
			TextSize = Theme.Text.H1,
			Color = C.Text,
			Size = UDim2.new(1, -90, 0, 44),
			Position = UDim2.fromOffset(84, 10),
			ZIndex = z + 1,
			Parent = body,
		})
		Kit.label({
			Text = step.Body,
			Font = Theme.Fonts.Semibold,
			TextSize = Theme.Text.H3,
			Color = C.TextMuted,
			Wrap = true,
			AlignY = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, 0, 0, 110),
			Position = UDim2.fromOffset(0, 90),
			ZIndex = z + 1,
			Parent = body,
		})
		local keys = Kit.box({
			Size = UDim2.new(1, 0, 0, 200),
			Position = UDim2.fromOffset(0, 210),
			ZIndex = z + 1,
			Parent = body,
		})
		Kit.list(keys, 10)
		for order, key in step.Keys do
			local row = Kit.box({ Size = UDim2.new(1, 0, 0, 44), Order = order, ZIndex = z + 1, Parent = keys })
			local cap = Kit.surface({
				Color = C.White,
				BorderColor = C.BorderStrong,
				BorderThickness = 2,
				Radius = 10,
				Size = UDim2.fromOffset(0, 40),
				AutoSize = Enum.AutomaticSize.X,
				ZIndex = z + 2,
				Parent = row,
			})
			local label = Kit.label({
				Text = key[1],
				Font = Theme.Fonts.Display,
				TextSize = Theme.Text.Small,
				Color = C.Text,
				Size = UDim2.fromOffset(0, 40),
				AutoSize = Enum.AutomaticSize.X,
				ZIndex = z + 3,
				Parent = cap,
			})
			Kit.padding(label, 14, 0)
			Kit.label({
				Text = key[2],
				Font = Theme.Fonts.Bold,
				Color = C.TextMuted,
				Size = UDim2.new(0.5, 0, 1, 0),
				Position = UDim2.fromOffset(260, 0),
				ZIndex = z + 2,
				Parent = row,
			})
		end
		for i = 1, #STEPS do
			local dot = Kit.new("Frame", {
				BackgroundColor3 = if i == index then C.Success elseif i < index then C.SkyLight else C.Surface3,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(if i == index then 32 else 12, 12),
				LayoutOrder = i,
				ZIndex = z + 1,
				Parent = dots,
			})
			Kit.round(dot)
		end
		previous.SetEnabled(index > 1)
		nextButton.SetText(if index == #STEPS then "TERMINER" else "SUIVANT")
	end

	previous = Kit.button({
		Text = "PRÉCÉDENT",
		Variant = "Light",
		Size = UDim2.fromOffset(160, 50),
		Position = UDim2.new(1, -176, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = z + 1,
		Parent = footer,
		OnClick = function()
			index = math.max(1, index - 1)
			render()
		end,
	})
	nextButton = Kit.button({
		Text = "SUIVANT",
		Variant = "Success",
		Size = UDim2.fromOffset(160, 50),
		Position = UDim2.new(1, 0, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = z + 1,
		Parent = footer,
		OnClick = function()
			if index == #STEPS then
				State.request("ProfileAction", "CompleteTutorial")
				State.Notify:Fire("Tutoriel terminé. Bon match !", "Success")
				index = 1
				render()
				return
			end
			index += 1
			render()
		end,
	})
	render()
end

return TutorialScreen
