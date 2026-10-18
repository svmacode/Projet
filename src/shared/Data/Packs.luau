--!strict
-- Packs : les Balles (archétypes) et le Pack Cosmétique.
-- Les taux sont affichés tels quels dans la boutique (transparence obligatoire
-- pour les objets aléatoires payants sur Roblox).

local Rarities = require(script.Parent.Rarities)

export type BallPack = {
	Id: string,
	Name: string,
	Japanese: string,
	Price: number, -- en Hand Coins
	Color: Color3,
	Accent: Color3,
	Odds: { [Rarities.RarityId]: number }, -- en pourcentage
}

export type CosmeticPack = {
	Id: string,
	Name: string,
	Price: number,
	Odds: { [Rarities.RarityId]: number },
}

local Packs = {}

-- Les archétypes Communs sont offerts à tout le monde : les balles commencent
-- donc à la rareté Peu commun.
Packs.Balls = {
	Classique = {
		Id = "Classique",
		Name = "Balle Classique",
		Japanese = "クラシック",
		Price = 450,
		Color = Color3.fromRGB(255, 120, 40),
		Accent = Color3.fromRGB(255, 240, 210),
		Odds = { PeuCommun = 62, Rare = 26, Epique = 9, Legendaire = 2.5, Mythique = 0.5 },
	},
	Doree = {
		Id = "Doree",
		Name = "Balle Dorée",
		Japanese = "ゴールド",
		Price = 1200,
		Color = Color3.fromRGB(255, 196, 30),
		Accent = Color3.fromRGB(255, 250, 200),
		Odds = { PeuCommun = 35, Rare = 38, Epique = 19, Legendaire = 6.5, Mythique = 1.5 },
	},
	Celeste = {
		Id = "Celeste",
		Name = "Balle Céleste",
		Japanese = "セレスト",
		Price = 3000,
		Color = Color3.fromRGB(120, 90, 255),
		Accent = Color3.fromRGB(120, 255, 240),
		Odds = { Rare = 45, Epique = 35, Legendaire = 16, Mythique = 4 },
	},
} :: { [string]: BallPack }

Packs.BallOrder = { "Classique", "Doree", "Celeste" }

-- Garantie : au bout de N balles sans Légendaire ni Mythique, la suivante
-- est au minimum Légendaire.
Packs.PityThreshold = 40

Packs.Cosmetic = {
	Id = "Cosmetique",
	Name = "Pack Cosmétique",
	Price = 800,
	Odds = { Commun = 45, PeuCommun = 28, Rare = 16, Epique = 8, Legendaire = 2.5, Mythique = 0.5 },
} :: CosmeticPack

-- Tire une rareté selon une table de pourcentages. `roll` est dans [0, 1[.
function Packs.rollRarity(odds: { [Rarities.RarityId]: number }, roll: number): Rarities.RarityId
	local weights = (odds :: any) :: { [string]: number }
	local order = Rarities.Order :: { any }
	local total = 0
	for _, rarity in order do
		total += weights[rarity] or 0
	end
	local target = roll * total
	local cumulative = 0
	local last: Rarities.RarityId = "Commun"
	for _, rarity in order do
		local weight = weights[rarity] or 0
		if weight > 0 then
			cumulative += weight
			last = rarity
			if target < cumulative then
				return rarity
			end
		end
	end
	return last
end

function Packs.getBall(id: unknown): BallPack?
	if typeof(id) ~= "string" then
		return nil
	end
	return Packs.Balls[id]
end

return Packs
