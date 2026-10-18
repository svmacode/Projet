--!strict
-- Les 6 raretés, communes aux archétypes et aux cosmétiques.

-- "Commun" | "PeuCommun" | "Rare" | "Epique" | "Legendaire" | "Mythique"
export type RarityId = string

export type RarityInfo = {
	Id: RarityId,
	Name: string,
	Rank: number,
	Color: Color3,
	ColorDark: Color3,
	ColorLight: Color3,
	-- Hand Coins rendus quand on obtient un doublon.
	DuplicateRefund: number,
}

local Rarities = {}

Rarities.Order = { "Commun", "PeuCommun", "Rare", "Epique", "Legendaire", "Mythique" } :: { RarityId }

Rarities.Info = {
	Commun = {
		Id = "Commun",
		Name = "Commun",
		Rank = 1,
		Color = Color3.fromRGB(122, 196, 214),
		ColorDark = Color3.fromRGB(36, 92, 112),
		ColorLight = Color3.fromRGB(214, 244, 250),
		DuplicateRefund = 40,
	},
	PeuCommun = {
		Id = "PeuCommun",
		Name = "Peu commun",
		Rank = 2,
		Color = Color3.fromRGB(64, 214, 120),
		ColorDark = Color3.fromRGB(18, 98, 52),
		ColorLight = Color3.fromRGB(200, 255, 214),
		DuplicateRefund = 90,
	},
	Rare = {
		Id = "Rare",
		Name = "Rare",
		Rank = 3,
		Color = Color3.fromRGB(46, 128, 255),
		ColorDark = Color3.fromRGB(14, 46, 130),
		ColorLight = Color3.fromRGB(196, 222, 255),
		DuplicateRefund = 180,
	},
	Epique = {
		Id = "Epique",
		Name = "Épique",
		Rank = 4,
		Color = Color3.fromRGB(170, 76, 255),
		ColorDark = Color3.fromRGB(70, 18, 130),
		ColorLight = Color3.fromRGB(236, 206, 255),
		DuplicateRefund = 380,
	},
	Legendaire = {
		Id = "Legendaire",
		Name = "Légendaire",
		Rank = 5,
		Color = Color3.fromRGB(255, 186, 30),
		ColorDark = Color3.fromRGB(150, 72, 0),
		ColorLight = Color3.fromRGB(255, 240, 180),
		DuplicateRefund = 850,
	},
	Mythique = {
		Id = "Mythique",
		Name = "Mythique",
		Rank = 6,
		Color = Color3.fromRGB(255, 46, 108),
		ColorDark = Color3.fromRGB(120, 0, 52),
		ColorLight = Color3.fromRGB(255, 205, 225),
		DuplicateRefund = 2000,
	},
} :: { [string]: RarityInfo }

function Rarities.get(id: string): RarityInfo?
	return (Rarities.Info :: any)[id]
end

function Rarities.isValid(id: unknown): boolean
	return typeof(id) == "string" and (Rarities.Info :: any)[id] ~= nil
end

return Rarities
