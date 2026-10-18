--!strict
-- Système visuel de Handball Legends.
--
-- Principes : surfaces sombres pleines, une seule couleur d'accent, tailles
-- de texte fixes (jamais TextScaled pour le texte courant), coins arrondis
-- identiques partout, grille de 8 px, animations courtes et fluides.
-- Aucune image, aucune transparence d'interface.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)

local Theme = {}

local rgb = Color3.fromRGB

Theme.Colors = {
	Background = rgb(10, 11, 15),
	Surface = rgb(18, 20, 27),
	Surface2 = rgb(26, 29, 38),
	Surface3 = rgb(36, 40, 52),
	Border = rgb(44, 49, 63),
	BorderStrong = rgb(66, 72, 90),

	Text = rgb(242, 243, 246),
	TextMuted = rgb(156, 162, 179),
	TextFaint = rgb(98, 104, 122),
	TextOnAccent = rgb(18, 12, 6),

	Accent = rgb(255, 122, 44),
	AccentHover = rgb(255, 146, 82),
	AccentPressed = rgb(230, 98, 24),

	Success = rgb(62, 214, 140),
	Danger = rgb(255, 77, 87),
	Warning = rgb(255, 196, 64),
	Info = rgb(92, 160, 255),

	White = rgb(255, 255, 255),
	Black = rgb(0, 0, 0),
}

Theme.Team = {
	Rouge = { Main = rgb(232, 58, 68), Dark = rgb(120, 22, 30), Name = "ROUGE" },
	Bleu = { Main = rgb(58, 126, 255), Dark = rgb(20, 46, 112), Name = "BLEU" },
}

-- Builder Sans : la police des interfaces officielles de Roblox.
local function font(enum: Enum.Font, italic: boolean?): Font
	local base = Font.fromEnum(enum)
	if italic then
		return Font.new(base.Family, base.Weight, Enum.FontStyle.Italic)
	end
	return base
end

Theme.Fonts = {
	Display = font(Enum.Font.BuilderSansExtraBold),
	DisplayItalic = font(Enum.Font.BuilderSansExtraBold, true),
	Bold = font(Enum.Font.BuilderSansBold),
	Semibold = font(Enum.Font.BuilderSansBold),
	Regular = font(Enum.Font.BuilderSansMedium),
}

-- Échelle typographique (en pixels, résolution de référence 1600×900).
Theme.Text = {
	Hero = 96,
	Display = 56,
	H1 = 36,
	H2 = 26,
	H3 = 20,
	Body = 17,
	Small = 14,
	Tiny = 12,
}

Theme.Radius = 8
Theme.RadiusLarge = 12
Theme.Space = 8

Theme.Motion = {
	Fast = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Base = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Slow = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Spring = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
}

function Theme.rarityColor(rarity: string): Color3
	local info = Rarities.get(rarity)
	return if info then info.Color else Theme.Colors.TextMuted
end

function Theme.rarityName(rarity: string): string
	local info = Rarities.get(rarity)
	return if info then info.Name else rarity
end

function Theme.lighten(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

function Theme.darken(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

-- Sons (facultatif) : identifiants rbxassetid://… importés par le créateur.
Theme.Sounds = {
	Click = "",
	Hover = "",
	Whistle = "",
	Goal = "",
	Shot = "",
	Pass = "",
	Reveal = "",
	Power = "",
}

return Theme
