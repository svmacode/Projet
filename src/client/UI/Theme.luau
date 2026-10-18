--!strict
-- Identité visuelle « manga / bande dessinée » : encre noire, papier crème,
-- aplats de couleurs vives, contours épais, ombres pleines (jamais floues ni
-- transparentes), typographie Bangers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)

local Theme = {}

Theme.Colors = {
	Ink = Color3.fromRGB(16, 16, 22),
	InkSoft = Color3.fromRGB(44, 44, 58),
	Paper = Color3.fromRGB(255, 249, 234),
	PaperDark = Color3.fromRGB(240, 228, 204),
	Red = Color3.fromRGB(226, 32, 58),
	RedDark = Color3.fromRGB(150, 12, 32),
	Yellow = Color3.fromRGB(255, 212, 42),
	YellowDark = Color3.fromRGB(214, 150, 0),
	Blue = Color3.fromRGB(30, 110, 245),
	BlueDark = Color3.fromRGB(12, 50, 150),
	Green = Color3.fromRGB(52, 200, 110),
	Purple = Color3.fromRGB(150, 70, 240),
	Pink = Color3.fromRGB(255, 90, 160),
	White = Color3.fromRGB(255, 255, 255),
	Night = Color3.fromRGB(26, 22, 48),
	Steel = Color3.fromRGB(70, 80, 104),
}

Theme.Team = {
	Rouge = {
		Main = Color3.fromRGB(226, 32, 52),
		Dark = Color3.fromRGB(130, 10, 26),
		Light = Color3.fromRGB(255, 150, 160),
	},
	Bleu = {
		Main = Color3.fromRGB(30, 110, 245),
		Dark = Color3.fromRGB(10, 44, 130),
		Light = Color3.fromRGB(150, 196, 255),
	},
}

Theme.Fonts = {
	Title = Enum.Font.Bangers,
	Body = Enum.Font.GothamBold,
	Heavy = Enum.Font.GothamBlack,
	Fun = Enum.Font.LuckiestGuy,
}

Theme.Stroke = 4
Theme.ShadowOffset = 6

Theme.Tween = {
	Fast = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Pop = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	Slide = TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Slow = TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Bounce = TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
}

function Theme.rarityColor(rarity: string): Color3
	local info = Rarities.get(rarity)
	return if info then info.Color else Theme.Colors.Steel
end

function Theme.rarityDark(rarity: string): Color3
	local info = Rarities.get(rarity)
	return if info then info.ColorDark else Theme.Colors.Ink
end

function Theme.rarityName(rarity: string): string
	local info = Rarities.get(rarity)
	return if info then info.Name else rarity
end

-- Assombrit / éclaircit une couleur (pour les états des boutons).
function Theme.shade(color: Color3, amount: number): Color3
	if amount >= 0 then
		return color:Lerp(Color3.new(1, 1, 1), amount)
	end
	return color:Lerp(Color3.new(0, 0, 0), -amount)
end

-- Images importées sur Roblox (facultatif). Laisser vide = rendu 100 % code.
-- Après import (voir README), coller les identifiants rbxassetid://...
Theme.Images = {
	Logo = "",
	Halftone = "",
	SpeedLines = "",
}

-- Sons (facultatif) : identifiants rbxassetid://... à renseigner.
Theme.Sounds = {
	Click = "",
	Whistle = "",
	Goal = "",
	Shot = "",
	Pass = "",
	PackOpen = "",
	Reveal = "",
	Power = "",
	Ultimate = "",
}

return Theme
