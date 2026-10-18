--!strict
-- Direction artistique de Handball Legends (inspirée de Volleyball Legends /
-- Haikyuu) : claire, ensoleillée, propre.
--
--   • Panneaux blancs légèrement translucides, coins très arrondis, ombre douce.
--   • Texte marine foncé, jamais de noir pur.
--   • Accent orange (Karasuno) en dégradé sur les actions principales,
--     bleu ciel en secondaire, rouge / bleu d'équipe vifs.
--   • Titres en Gotham Black blancs cerclés de marine sur les fonds colorés.
--   • Boutons « bonbon » : face en dégradé posée sur une tranche plus foncée,
--     qui s'enfonce au clic.
-- Tout est dessiné en code : aucune image importée.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)

local Theme = {}

local rgb = Color3.fromRGB

Theme.Colors = {
	-- Voile derrière les fenêtres et fonds sombres.
	Background = rgb(16, 26, 52),
	Overlay = rgb(16, 26, 52),

	-- Panneaux (clairs).
	Surface = rgb(255, 255, 255),
	Surface2 = rgb(243, 246, 251),
	Surface3 = rgb(228, 234, 244),
	Border = rgb(210, 218, 232),
	BorderStrong = rgb(176, 188, 210),

	-- Texte.
	Ink = rgb(20, 32, 66),
	Text = rgb(20, 32, 66),
	TextMuted = rgb(94, 108, 140),
	TextFaint = rgb(148, 160, 184),
	TextOnAccent = rgb(255, 255, 255),

	-- Accent principal : orange Karasuno.
	Accent = rgb(255, 122, 30),
	AccentLight = rgb(255, 176, 64),
	AccentDark = rgb(214, 82, 8),
	AccentHover = rgb(255, 146, 60),
	AccentPressed = rgb(232, 98, 16),

	-- Secondaire : bleu ciel.
	Sky = rgb(46, 155, 255),
	SkyLight = rgb(118, 198, 255),
	SkyDark = rgb(22, 104, 212),

	Gold = rgb(255, 196, 46),
	Success = rgb(40, 196, 104),
	Danger = rgb(238, 62, 76),
	Warning = rgb(255, 170, 30),
	Info = rgb(46, 155, 255),

	White = rgb(255, 255, 255),
	Black = rgb(0, 0, 0),
}

-- Couleurs de section (petits repères, jamais en aplat géant).
Theme.Section = {
	Play = Theme.Colors.Accent,
	Archetypes = Theme.Colors.Accent,
	Locker = Theme.Colors.Sky,
	Shop = Theme.Colors.Accent,
	Clan = rgb(124, 92, 246),
	Party = Theme.Colors.Sky,
	Info = Theme.Colors.Success,
	Tutorial = Theme.Colors.Success,
	Updates = Theme.Colors.Warning,
	Ranked = Theme.Colors.Gold,
	Training = Theme.Colors.Success,
}

Theme.Team = {
	Rouge = { Main = rgb(240, 56, 74), Light = rgb(255, 120, 132), Dark = rgb(170, 22, 44), Name = "ROUGE" },
	Bleu = { Main = rgb(46, 134, 255), Light = rgb(120, 182, 255), Dark = rgb(18, 76, 190), Name = "BLEU" },
}

Theme.Fonts = {
	-- Titres, chiffres, boutons.
	Hero = Font.fromEnum(Enum.Font.GothamBlack),
	Display = Font.fromEnum(Enum.Font.GothamBlack),
	Number = Font.fromEnum(Enum.Font.GothamBlack),
	-- Interface.
	Bold = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
	Semibold = Font.fromEnum(Enum.Font.BuilderSansBold),
	Regular = Font.fromEnum(Enum.Font.BuilderSansMedium),
}

-- Échelle typographique (pixels, résolution de référence 1600×900).
Theme.Text = {
	Hero = 96,
	Display = 56,
	H1 = 34,
	H2 = 26,
	H3 = 20,
	Body = 17,
	Small = 14,
	Tiny = 12,
}

Theme.Radius = 12
Theme.RadiusLarge = 18
Theme.Space = 8

Theme.Motion = {
	Fast = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Base = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Slow = TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Spring = TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	Bounce = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
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

-- Texte lisible posé sur une couleur (marine sur clair, blanc sur foncé).
function Theme.onColor(color: Color3): Color3
	local luminance = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
	return if luminance > 0.72 then Theme.Colors.Ink else Theme.Colors.White
end

-- Sons : identifiants importés par le créateur dans Shared/Assets.luau.
-- Une entrée vide = silence, sans erreur.
local function sound(name: string): string
	return Assets.sound(name) or ""
end

Theme.Sounds = {
	Click = sound("Click"),
	Hover = sound("Hover"),
	Whistle = sound("Whistle"),
	Goal = sound("Goal"),
	Shot = sound("Shot"),
	PerfectShot = sound("PerfectShot"),
	Pass = sound("Pass"),
	Reveal = sound("Reveal"),
	Power = sound("Power"),
	Ultimate = sound("Ultimate"),
}

return Theme
