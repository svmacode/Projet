--!strict
-- Cosmétiques 100 % esthétiques : Masques, Gants, Chaussures.
-- Chaque objet est construit en pièces 3D (pas d'image à importer) et soudé
-- au personnage. Les mesures sont prévues pour un avatar R6 :
-- tête 2×1×1, bras et jambes 1×2×1. Le visage regarde vers -Z.

local Rarities = require(script.Parent.Rarities)

export type Slot = "Mask" | "Gloves" | "Shoes"

export type PartSpec = {
	Size: Vector3,
	Offset: CFrame,
	Color: Color3,
	Material: Enum.Material?,
	Shape: ("Block" | "Cylinder" | "Ball" | "Wedge")?,
	Light: number?, -- portée d'une PointLight de la couleur de la pièce
}

export type Cosmetic = {
	Id: string,
	Name: string,
	Slot: Slot,
	Rarity: Rarities.RarityId,
	Parts: { PartSpec },
	Sparkles: Color3?, -- particules (raretés hautes)
}

local Cosmetics = {}

Cosmetics.Slots = {
	Mask = { Id = "Mask", Name = "Masques", Single = "Masque" },
	Gloves = { Id = "Gloves", Name = "Gants", Single = "Gants" },
	Shoes = { Id = "Shoes", Name = "Chaussures", Single = "Chaussures" },
}

Cosmetics.SlotOrder = { "Mask", "Gloves", "Shoes" } :: { Slot }

local rgb = Color3.fromRGB
local NEON = Enum.Material.Neon
local METAL = Enum.Material.Metal
local GLASS = Enum.Material.Glass
local WOOD = Enum.Material.Wood
local FABRIC = Enum.Material.Fabric
local HALF_PI = math.pi / 2

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

local function part(size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, shape: string?): PartSpec
	return {
		Size = size,
		Offset = offset,
		Color = color,
		Material = material,
		Shape = shape :: any,
	}
end

local function glow(spec: PartSpec, range: number): PartSpec
	spec.Light = range
	return spec
end

-- Bases communes ----------------------------------------------------------------

local function faceplate(color: Color3, material: Enum.Material?): PartSpec
	return part(Vector3.new(1.32, 0.95, 0.16), at(0, 0, -0.56), color, material)
end

local function glove(color: Color3, material: Enum.Material?): PartSpec
	return part(Vector3.new(1.1, 0.78, 1.1), at(0, -0.64, 0), color, material)
end

local function cuff(color: Color3, material: Enum.Material?): PartSpec
	return part(Vector3.new(1.16, 0.16, 1.16), at(0, -0.27, 0), color, material)
end

local function shoe(color: Color3, material: Enum.Material?, height: number?): PartSpec
	local h = height or 0.46
	return part(Vector3.new(1.1, h, 1.32), at(0, -1 + 0.06 + h / 2, -0.14), color, material)
end

local function sole(color: Color3): PartSpec
	return part(Vector3.new(1.14, 0.14, 1.36), at(0, -0.97, -0.14), color)
end

local LIST: { Cosmetic } = {
	------------------------------------------------------------------ MASQUES
	{
		Id = "Mask_Bandeau",
		Name = "Bandeau Shōnen",
		Slot = "Mask",
		Rarity = "Commun",
		Parts = {
			part(Vector3.new(2.06, 0.26, 1.06), at(0, 0.24, 0), rgb(250, 250, 245), FABRIC),
			part(
				Vector3.new(0.06, 0.2, 0.2),
				at(0, 0.24, -0.54) * CFrame.Angles(0, HALF_PI, 0),
				rgb(220, 30, 50),
				nil,
				"Cylinder"
			),
			part(
				Vector3.new(0.12, 0.16, 0.55),
				at(0.18, 0.12, 0.74) * CFrame.Angles(0.5, 0.25, 0),
				rgb(250, 250, 245),
				FABRIC
			),
			part(
				Vector3.new(0.12, 0.16, 0.5),
				at(-0.12, 0.06, 0.72) * CFrame.Angles(0.7, -0.2, 0),
				rgb(250, 250, 245),
				FABRIC
			),
		},
	},
	{
		Id = "Mask_Visiere",
		Name = "Visière Sport",
		Slot = "Mask",
		Rarity = "Commun",
		Parts = {
			part(Vector3.new(1.6, 0.32, 0.14), at(0, 0.1, -0.55), rgb(20, 40, 90), GLASS),
			part(Vector3.new(2.04, 0.12, 1.04), at(0, 0.1, 0), rgb(20, 20, 24)),
			part(Vector3.new(1.62, 0.05, 0.16), at(0, 0.27, -0.55), rgb(255, 210, 40)),
		},
	},
	{
		Id = "Mask_Kitsune",
		Name = "Masque Kitsune",
		Slot = "Mask",
		Rarity = "PeuCommun",
		Parts = {
			faceplate(rgb(252, 250, 244)),
			part(Vector3.new(0.42, 0.32, 0.32), at(0, -0.16, -0.72), rgb(252, 250, 244)),
			part(Vector3.new(0.14, 0.5, 0.3), at(0.48, 0.62, -0.5), rgb(252, 250, 244), nil, "Wedge"),
			part(Vector3.new(0.14, 0.5, 0.3), at(-0.48, 0.62, -0.5), rgb(252, 250, 244), nil, "Wedge"),
			part(Vector3.new(0.34, 0.06, 0.03), at(0.32, 0.08, -0.645) * CFrame.Angles(0, 0, -0.35), rgb(220, 20, 40)),
			part(Vector3.new(0.34, 0.06, 0.03), at(-0.32, 0.08, -0.645) * CFrame.Angles(0, 0, 0.35), rgb(220, 20, 40)),
			part(Vector3.new(0.1, 0.06, 0.03), at(0, -0.1, -0.89), rgb(20, 20, 24)),
		},
	},
	{
		Id = "Mask_Tengu",
		Name = "Masque Tengu",
		Slot = "Mask",
		Rarity = "PeuCommun",
		Parts = {
			faceplate(rgb(200, 24, 30)),
			part(
				Vector3.new(1.0, 0.22, 0.22),
				at(0, 0.02, -1.08) * CFrame.Angles(0, HALF_PI, 0),
				rgb(200, 24, 30),
				nil,
				"Cylinder"
			),
			part(Vector3.new(0.42, 0.1, 0.04), at(0.3, 0.26, -0.65) * CFrame.Angles(0, 0, 0.3), rgb(20, 20, 24)),
			part(Vector3.new(0.42, 0.1, 0.04), at(-0.3, 0.26, -0.65) * CFrame.Angles(0, 0, -0.3), rgb(20, 20, 24)),
			part(Vector3.new(0.9, 0.08, 0.04), at(0, -0.3, -0.65), rgb(255, 220, 120)),
		},
	},
	{
		Id = "Mask_Oni",
		Name = "Masque Oni",
		Slot = "Mask",
		Rarity = "Rare",
		Parts = {
			faceplate(rgb(180, 20, 34)),
			part(
				Vector3.new(0.7, 0.16, 0.16),
				at(0.5, 0.78, -0.42) * CFrame.Angles(0, 0, HALF_PI - 0.35),
				rgb(255, 220, 90),
				nil,
				"Cylinder"
			),
			part(
				Vector3.new(0.7, 0.16, 0.16),
				at(-0.5, 0.78, -0.42) * CFrame.Angles(0, 0, HALF_PI + 0.35),
				rgb(255, 220, 90),
				nil,
				"Cylinder"
			),
			glow(
				part(
					Vector3.new(0.26, 0.1, 0.04),
					at(0.3, 0.14, -0.65) * CFrame.Angles(0, 0, -0.25),
					rgb(255, 230, 60),
					NEON
				),
				5
			),
			part(
				Vector3.new(0.26, 0.1, 0.04),
				at(-0.3, 0.14, -0.65) * CFrame.Angles(0, 0, 0.25),
				rgb(255, 230, 60),
				NEON
			),
			part(Vector3.new(0.12, 0.2, 0.06), at(0.22, -0.4, -0.64), rgb(255, 255, 250), nil, "Wedge"),
			part(Vector3.new(0.12, 0.2, 0.06), at(-0.22, -0.4, -0.64), rgb(255, 255, 250), nil, "Wedge"),
		},
	},
	{
		Id = "Mask_Hannya",
		Name = "Masque Hannya",
		Slot = "Mask",
		Rarity = "Epique",
		Parts = {
			faceplate(rgb(248, 240, 226)),
			part(
				Vector3.new(1.0, 0.16, 0.16),
				at(0.62, 0.86, -0.3) * CFrame.Angles(0.3, 0, HALF_PI - 0.6),
				rgb(255, 196, 40),
				METAL,
				"Cylinder"
			),
			part(
				Vector3.new(1.0, 0.16, 0.16),
				at(-0.62, 0.86, -0.3) * CFrame.Angles(0.3, 0, HALF_PI + 0.6),
				rgb(255, 196, 40),
				METAL,
				"Cylinder"
			),
			glow(
				part(
					Vector3.new(0.3, 0.12, 0.04),
					at(0.3, 0.12, -0.65) * CFrame.Angles(0, 0, -0.4),
					rgb(255, 30, 60),
					NEON
				),
				7
			),
			part(
				Vector3.new(0.3, 0.12, 0.04),
				at(-0.3, 0.12, -0.65) * CFrame.Angles(0, 0, 0.4),
				rgb(255, 30, 60),
				NEON
			),
			part(Vector3.new(0.9, 0.14, 0.05), at(0, -0.32, -0.65), rgb(170, 10, 30)),
			part(Vector3.new(1.36, 0.08, 0.18), at(0, 0.45, -0.56), rgb(255, 196, 40), METAL),
		},
	},
	{
		Id = "Mask_Dragon",
		Name = "Masque du Dragon",
		Slot = "Mask",
		Rarity = "Legendaire",
		Sparkles = rgb(120, 255, 200),
		Parts = {
			faceplate(rgb(20, 120, 70), METAL),
			part(Vector3.new(1.4, 0.1, 0.2), at(0, 0.48, -0.56), rgb(255, 200, 40), METAL),
			part(Vector3.new(1.4, 0.1, 0.2), at(0, -0.48, -0.56), rgb(255, 200, 40), METAL),
			part(
				Vector3.new(1.1, 0.14, 0.14),
				at(0.7, 0.75, 0.05) * CFrame.Angles(-0.6, 0, HALF_PI - 0.5),
				rgb(255, 220, 120),
				METAL,
				"Cylinder"
			),
			part(
				Vector3.new(1.1, 0.14, 0.14),
				at(-0.7, 0.75, 0.05) * CFrame.Angles(-0.6, 0, HALF_PI + 0.5),
				rgb(255, 220, 120),
				METAL,
				"Cylinder"
			),
			glow(
				part(
					Vector3.new(0.32, 0.12, 0.04),
					at(0.3, 0.1, -0.65) * CFrame.Angles(0, 0, -0.3),
					rgb(80, 255, 230),
					NEON
				),
				8
			),
			part(
				Vector3.new(0.32, 0.12, 0.04),
				at(-0.3, 0.1, -0.65) * CFrame.Angles(0, 0, 0.3),
				rgb(80, 255, 230),
				NEON
			),
		},
	},
	{
		Id = "Mask_Neant",
		Name = "Masque du Néant",
		Slot = "Mask",
		Rarity = "Mythique",
		Sparkles = rgb(255, 60, 220),
		Parts = {
			part(Vector3.new(1.4, 1.0, 0.18), at(0, 0, -0.56), rgb(14, 8, 24), GLASS),
			glow(
				part(
					Vector3.new(0.36, 0.14, 0.04),
					at(0.3, 0.1, -0.665) * CFrame.Angles(0, 0, -0.2),
					rgb(255, 40, 220),
					NEON
				),
				10
			),
			part(
				Vector3.new(0.36, 0.14, 0.04),
				at(-0.3, 0.1, -0.665) * CFrame.Angles(0, 0, 0.2),
				rgb(255, 40, 220),
				NEON
			),
			part(
				Vector3.new(0.08, 1.7, 1.7),
				at(0, 1.05, 0.15) * CFrame.Angles(0, 0, HALF_PI),
				rgb(255, 40, 220),
				NEON,
				"Cylinder"
			),
			part(
				Vector3.new(0.09, 1.4, 1.4),
				at(0, 1.05, 0.15) * CFrame.Angles(0, 0, HALF_PI),
				rgb(14, 8, 24),
				nil,
				"Cylinder"
			),
		},
	},
	------------------------------------------------------------------ GANTS
	{
		Id = "Gloves_Basiques",
		Name = "Gants Basiques",
		Slot = "Gloves",
		Rarity = "Commun",
		Parts = { glove(rgb(250, 250, 245), FABRIC), cuff(rgb(220, 30, 50)) },
	},
	{
		Id = "Gloves_Rayes",
		Name = "Gants Rayés",
		Slot = "Gloves",
		Rarity = "Commun",
		Parts = {
			glove(rgb(24, 24, 30), FABRIC),
			part(Vector3.new(1.13, 0.1, 1.13), at(0, -0.48, 0), rgb(250, 250, 245)),
			part(Vector3.new(1.13, 0.1, 1.13), at(0, -0.72, 0), rgb(250, 250, 245)),
		},
	},
	{
		Id = "Gloves_Flamme",
		Name = "Gants Flamme",
		Slot = "Gloves",
		Rarity = "PeuCommun",
		Parts = {
			glove(rgb(255, 110, 20)),
			cuff(rgb(255, 220, 60)),
			part(
				Vector3.new(0.3, 0.45, 0.5),
				at(0, -0.25, 0.55) * CFrame.Angles(0, math.pi, 0),
				rgb(255, 200, 40),
				NEON,
				"Wedge"
			),
		},
	},
	{
		Id = "Gloves_Tonnerre",
		Name = "Gants Tonnerre",
		Slot = "Gloves",
		Rarity = "PeuCommun",
		Parts = {
			glove(rgb(255, 214, 30)),
			cuff(rgb(30, 30, 60)),
			part(Vector3.new(0.12, 0.5, 0.05), at(0, -0.64, -0.56) * CFrame.Angles(0, 0, 0.5), rgb(40, 40, 120), NEON),
		},
	},
	{
		Id = "Gloves_Givre",
		Name = "Gants Givre",
		Slot = "Gloves",
		Rarity = "Rare",
		Parts = {
			glove(rgb(170, 230, 255), GLASS),
			glow(cuff(rgb(80, 220, 255), NEON), 5),
			part(
				Vector3.new(0.18, 0.4, 0.18),
				at(0.5, -0.4, 0) * CFrame.Angles(0, 0, -0.5),
				rgb(220, 250, 255),
				GLASS,
				"Wedge"
			),
		},
	},
	{
		Id = "Gloves_Dragon",
		Name = "Gants Dragon",
		Slot = "Gloves",
		Rarity = "Epique",
		Parts = {
			glove(rgb(20, 120, 70), METAL),
			cuff(rgb(255, 200, 40), METAL),
			part(Vector3.new(0.1, 0.35, 0.1), at(0.3, -1.05, -0.4), rgb(255, 240, 200), nil, "Wedge"),
			part(Vector3.new(0.1, 0.35, 0.1), at(0, -1.08, -0.4), rgb(255, 240, 200), nil, "Wedge"),
			part(Vector3.new(0.1, 0.35, 0.1), at(-0.3, -1.05, -0.4), rgb(255, 240, 200), nil, "Wedge"),
		},
	},
	{
		Id = "Gloves_Solaires",
		Name = "Gants Solaires",
		Slot = "Gloves",
		Rarity = "Legendaire",
		Sparkles = rgb(255, 220, 80),
		Parts = {
			glove(rgb(255, 196, 40), METAL),
			glow(cuff(rgb(255, 240, 150), NEON), 7),
			part(Vector3.new(1.18, 0.08, 1.18), at(0, -0.9, 0), rgb(255, 240, 150), NEON),
		},
	},
	{
		Id = "Gloves_Vide",
		Name = "Gants du Vide",
		Slot = "Gloves",
		Rarity = "Mythique",
		Sparkles = rgb(255, 40, 220),
		Parts = {
			glove(rgb(14, 8, 24), GLASS),
			glow(cuff(rgb(255, 40, 220), NEON), 9),
			part(Vector3.new(1.18, 0.06, 1.18), at(0, -0.62, 0), rgb(255, 40, 220), NEON),
			part(Vector3.new(1.18, 0.06, 1.18), at(0, -0.92, 0), rgb(120, 255, 240), NEON),
		},
	},
	------------------------------------------------------------------ CHAUSSURES
	{
		Id = "Shoes_Lycee",
		Name = "Baskets Lycée",
		Slot = "Shoes",
		Rarity = "Commun",
		Parts = { shoe(rgb(250, 250, 245)), sole(rgb(220, 30, 50)) },
	},
	{
		Id = "Shoes_Montantes",
		Name = "Montantes Noires",
		Slot = "Shoes",
		Rarity = "Commun",
		Parts = { shoe(rgb(24, 24, 30), nil, 0.75), sole(rgb(250, 250, 245)) },
	},
	{
		Id = "Shoes_Eclair",
		Name = "Chaussures Éclair",
		Slot = "Shoes",
		Rarity = "PeuCommun",
		Parts = {
			shoe(rgb(255, 214, 30)),
			sole(rgb(30, 30, 60)),
			part(
				Vector3.new(0.05, 0.3, 0.6),
				at(0.56, -0.78, -0.14) * CFrame.Angles(0.6, 0, 0),
				rgb(40, 40, 120),
				NEON
			),
		},
	},
	{
		Id = "Shoes_Geta",
		Name = "Geta du Temple",
		Slot = "Shoes",
		Rarity = "PeuCommun",
		Parts = {
			part(Vector3.new(1.1, 0.16, 1.4), at(0, -0.88, -0.14), rgb(150, 96, 50), WOOD),
			part(Vector3.new(1.0, 0.2, 0.2), at(0, -1.04, -0.55), rgb(120, 70, 36), WOOD),
			part(Vector3.new(1.0, 0.2, 0.2), at(0, -1.04, 0.25), rgb(120, 70, 36), WOOD),
			part(Vector3.new(0.12, 0.3, 0.12), at(0, -0.72, -0.4), rgb(200, 20, 40), FABRIC),
		},
	},
	{
		Id = "Shoes_Comete",
		Name = "Chaussures Comète",
		Slot = "Shoes",
		Rarity = "Rare",
		Sparkles = rgb(80, 180, 255),
		Parts = { shoe(rgb(30, 90, 220)), glow(sole(rgb(120, 220, 255)), 5) },
	},
	{
		Id = "Shoes_Samourai",
		Name = "Bottes Samouraï",
		Slot = "Shoes",
		Rarity = "Epique",
		Parts = {
			shoe(rgb(30, 24, 30), nil, 0.9),
			sole(rgb(180, 20, 34)),
			part(Vector3.new(1.16, 0.6, 0.12), at(0, -0.55, -0.66), rgb(180, 20, 34), METAL),
			part(Vector3.new(1.18, 0.08, 0.16), at(0, -0.3, -0.68), rgb(255, 200, 40), METAL),
		},
	},
	{
		Id = "Shoes_Ailees",
		Name = "Chaussures Ailées",
		Slot = "Shoes",
		Rarity = "Legendaire",
		Sparkles = rgb(255, 230, 140),
		Parts = {
			shoe(rgb(252, 250, 244)),
			sole(rgb(255, 196, 40)),
			part(
				Vector3.new(0.08, 0.5, 0.7),
				at(0.6, -0.6, 0.15) * CFrame.Angles(-0.4, 0, 0),
				rgb(255, 230, 140),
				NEON,
				"Wedge"
			),
		},
	},
	{
		Id = "Shoes_Kami",
		Name = "Pas du Kami",
		Slot = "Shoes",
		Rarity = "Mythique",
		Sparkles = rgb(255, 60, 160),
		Parts = {
			shoe(rgb(255, 196, 40), METAL),
			glow(sole(rgb(255, 40, 140)), 9),
			part(Vector3.new(1.16, 0.06, 1.34), at(0, -0.62, -0.14), rgb(255, 40, 140), NEON),
		},
	},
}

local BY_ID: { [string]: Cosmetic } = {}
for _, item in LIST do
	BY_ID[item.Id] = item
end

Cosmetics.List = LIST

function Cosmetics.get(id: unknown): Cosmetic?
	if typeof(id) ~= "string" then
		return nil
	end
	return BY_ID[id]
end

function Cosmetics.byRarity(rarity: string): { Cosmetic }
	local result = {}
	for _, item in LIST do
		if item.Rarity == rarity then
			table.insert(result, item)
		end
	end
	return result
end

function Cosmetics.isSlot(value: unknown): boolean
	return typeof(value) == "string" and (Cosmetics.Slots :: any)[value] ~= nil
end

return Cosmetics
