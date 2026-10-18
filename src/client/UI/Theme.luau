--!strict
-- Direction artistique de Handball Legends : « anime sport ».
--
-- Inspirations : génériques d'animés de sport et menus de jeux de combat.
--   • Fond indigo profond en dégradé, jamais de noir plat.
--   • Couleurs saturées : jaune électrique (action principale), rose, cyan,
--     violet, vert acide. Chaque section du jeu a SA couleur.
--   • Encre : contours noirs épais, ombres dures décalées (pas de flou),
--     comme une case de manga.
--   • Plaques inclinées, lignes de vitesse, trames de points.
--   • Titres en Bangers (lettrage BD), chiffres et intertitres en Oswald,
--     texte courant en Builder Sans.
-- Tout est dessiné en code : aucune image importée.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)

local Theme = {}

local rgb = Color3.fromRGB

Theme.Colors = {
	-- Fonds (indigo → violet).
	Background = rgb(20, 12, 48),
	BackgroundTop = rgb(44, 18, 96),
	Surface = rgb(34, 22, 78),
	Surface2 = rgb(48, 32, 104),
	Surface3 = rgb(66, 46, 136),
	Border = rgb(10, 6, 26),
	BorderStrong = rgb(118, 92, 210),

	-- Encre : contours et ombres dures.
	Ink = rgb(10, 6, 26),

	Text = rgb(255, 255, 255),
	TextMuted = rgb(200, 190, 244),
	TextFaint = rgb(132, 118, 196),
	TextOnAccent = rgb(20, 10, 40),

	-- Accent principal : jaune électrique.
	Accent = rgb(255, 214, 10),
	AccentHover = rgb(255, 232, 92),
	AccentPressed = rgb(240, 180, 0),

	-- Palette secondaire.
	Pink = rgb(255, 46, 126),
	Cyan = rgb(32, 214, 255),
	Violet = rgb(150, 96, 255),
	Lime = rgb(170, 255, 60),
	Orange = rgb(255, 126, 36),

	Success = rgb(64, 232, 128),
	Danger = rgb(255, 54, 96),
	Warning = rgb(255, 160, 30),
	Info = rgb(32, 214, 255),

	White = rgb(255, 255, 255),
	Black = rgb(0, 0, 0),
}

-- Couleur signature de chaque section.
Theme.Section = {
	Play = Theme.Colors.Accent,
	Locker = Theme.Colors.Cyan,
	Shop = Theme.Colors.Pink,
	Clan = Theme.Colors.Violet,
	Tutorial = Theme.Colors.Lime,
	Updates = Theme.Colors.Orange,
	Ranked = rgb(255, 196, 0),
	Training = Theme.Colors.Lime,
}

Theme.Team = {
	Rouge = { Main = rgb(255, 52, 76), Dark = rgb(130, 14, 40), Name = "ROUGE" },
	Bleu = { Main = rgb(40, 140, 255), Dark = rgb(16, 40, 130), Name = "BLEU" },
}

local function font(enum: Enum.Font, weight: Enum.FontWeight?, italic: boolean?): Font
	local base = Font.fromEnum(enum)
	return Font.new(base.Family, weight or base.Weight, if italic then Enum.FontStyle.Italic else Enum.FontStyle.Normal)
end

Theme.Fonts = {
	-- Lettrage BD pour les grands moments (titres, GOAL, raretés).
	Hero = font(Enum.Font.Bangers),
	-- Condensé sportif pour les intertitres, chiffres, scores.
	Display = font(Enum.Font.Oswald, Enum.FontWeight.Bold),
	DisplayItalic = font(Enum.Font.Oswald, Enum.FontWeight.Bold),
	Number = font(Enum.Font.Oswald, Enum.FontWeight.Bold),
	-- Interface.
	Bold = font(Enum.Font.BuilderSansExtraBold),
	Semibold = font(Enum.Font.BuilderSansBold),
	Regular = font(Enum.Font.BuilderSansMedium),
}

-- Échelle typographique (pixels, résolution de référence 1600×900).
Theme.Text = {
	Hero = 120,
	Display = 64,
	H1 = 40,
	H2 = 28,
	H3 = 20,
	Body = 17,
	Small = 14,
	Tiny = 12,
}

Theme.Radius = 6
Theme.RadiusLarge = 10
Theme.Space = 8
Theme.Stroke = 2.5 -- épaisseur de l'encre
Theme.ShadowOffset = 5 -- ombre dure (px)
Theme.Tilt = -3 -- inclinaison des plaques (degrés)

Theme.Motion = {
	Fast = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Base = TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Slow = TweenInfo.new(0.42, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Spring = TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	Slam = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
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

-- Texte lisible posé sur une couleur donnée (encre sur clair, blanc sur foncé).
function Theme.onColor(color: Color3): Color3
	local luminance = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
	return if luminance > 0.6 then Theme.Colors.TextOnAccent else Theme.Colors.White
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
