--!strict
-- Niveaux, tenues débloquées tous les 10 niveaux et rangs du mode classé.

local Progression = {}

Progression.MaxLevel = 100

-- XP nécessaire pour passer du niveau `level` au niveau suivant.
-- Il faut ≈ 2 300 XP pour atteindre le niveau 10, soit une quinzaine de matchs.
function Progression.xpForNextLevel(level: number): number
	return 100 + 40 * (level - 1)
end

-- Applique de l'XP : renvoie le nouveau niveau, l'XP restante et les niveaux gagnés.
function Progression.applyXP(level: number, xp: number, gained: number): (number, number, number)
	local newLevel = level
	local newXP = xp + gained
	local levelsGained = 0
	while newLevel < Progression.MaxLevel do
		local needed = Progression.xpForNextLevel(newLevel)
		if newXP < needed then
			break
		end
		newXP -= needed
		newLevel += 1
		levelsGained += 1
	end
	if newLevel >= Progression.MaxLevel then
		newXP = 0
	end
	return newLevel, newXP, levelsGained
end

-- Tenues -------------------------------------------------------------------------
-- La couleur principale est TOUJOURS celle de l'équipe (rouge ou bleu).
-- Une tenue ne change que le motif et les couleurs d'accent.

export type KitPattern = "Plain" | "Stripes" | "Bolt" | "Scales" | "Armor" | "Stars" | "Aura"

export type Kit = {
	Id: string,
	Name: string,
	Level: number,
	Pattern: KitPattern,
	Accent: Color3,
	Trim: Color3,
	Shorts: "Dark" | "White" | "Team",
}

Progression.Kits = {
	{
		Id = "Lycee",
		Name = "Lycée Seiryō",
		Level = 1,
		Pattern = "Plain",
		Accent = Color3.fromRGB(255, 255, 255),
		Trim = Color3.fromRGB(255, 255, 255),
		Shorts = "Dark",
	},
	{
		Id = "Eclair",
		Name = "Éclair",
		Level = 10,
		Pattern = "Bolt",
		Accent = Color3.fromRGB(255, 220, 40),
		Trim = Color3.fromRGB(20, 20, 24),
		Shorts = "Dark",
	},
	{
		Id = "Dragon",
		Name = "Dragon",
		Level = 20,
		Pattern = "Scales",
		Accent = Color3.fromRGB(255, 196, 40),
		Trim = Color3.fromRGB(20, 20, 24),
		Shorts = "Team",
	},
	{
		Id = "Samourai",
		Name = "Samouraï",
		Level = 30,
		Pattern = "Armor",
		Accent = Color3.fromRGB(30, 24, 30),
		Trim = Color3.fromRGB(255, 200, 40),
		Shorts = "Dark",
	},
	{
		Id = "Celeste",
		Name = "Céleste",
		Level = 40,
		Pattern = "Stars",
		Accent = Color3.fromRGB(255, 255, 255),
		Trim = Color3.fromRGB(120, 255, 240),
		Shorts = "White",
	},
	{
		Id = "Legende",
		Name = "Légende",
		Level = 50,
		Pattern = "Aura",
		Accent = Color3.fromRGB(255, 220, 80),
		Trim = Color3.fromRGB(255, 255, 255),
		Shorts = "Team",
	},
} :: { Kit }

function Progression.getKit(id: unknown): Kit?
	for _, kit in Progression.Kits do
		if kit.Id == id then
			return kit
		end
	end
	return nil
end

function Progression.isKitUnlocked(kitId: string, level: number): boolean
	local kit = Progression.getKit(kitId)
	return kit ~= nil and level >= kit.Level
end

-- Couleurs d'équipe --------------------------------------------------------------

export type TeamId = "Rouge" | "Bleu"

Progression.Teams = {
	Rouge = {
		Id = "Rouge",
		Name = "ROUGE",
		Primary = Color3.fromRGB(226, 32, 52),
		Dark = Color3.fromRGB(120, 10, 24),
		Light = Color3.fromRGB(255, 140, 150),
	},
	Bleu = {
		Id = "Bleu",
		Name = "BLEU",
		Primary = Color3.fromRGB(30, 110, 245),
		Dark = Color3.fromRGB(10, 40, 120),
		Light = Color3.fromRGB(140, 190, 255),
	},
}

-- Rangs classés ----------------------------------------------------------------------

export type Rank = {
	Id: string,
	Name: string,
	MinRP: number,
	Color: Color3,
}

Progression.Ranks = {
	{ Id = "Bronze", Name = "Bronze", MinRP = 0, Color = Color3.fromRGB(205, 127, 50) },
	{ Id = "Argent", Name = "Argent", MinRP = 200, Color = Color3.fromRGB(200, 214, 230) },
	{ Id = "Or", Name = "Or", MinRP = 450, Color = Color3.fromRGB(255, 200, 40) },
	{ Id = "Platine", Name = "Platine", MinRP = 750, Color = Color3.fromRGB(60, 220, 200) },
	{ Id = "Diamant", Name = "Diamant", MinRP = 1100, Color = Color3.fromRGB(80, 160, 255) },
	{ Id = "Maitre", Name = "Maître", MinRP = 1500, Color = Color3.fromRGB(190, 80, 255) },
	{ Id = "Legende", Name = "Légende", MinRP = 2000, Color = Color3.fromRGB(255, 50, 100) },
} :: { Rank }

function Progression.getRank(rp: number): (Rank, number)
	local current = Progression.Ranks[1]
	local index = 1
	for i, rank in Progression.Ranks do
		if rp >= rank.MinRP then
			current = rank
			index = i
		end
	end
	return current, index
end

-- Division I, II ou III à l'intérieur d'un rang (Légende n'en a pas).
function Progression.getDivision(rp: number): string
	local rank, index = Progression.getRank(rp)
	local nextRank = Progression.Ranks[index + 1]
	if not nextRank then
		return ""
	end
	local span = nextRank.MinRP - rank.MinRP
	local progress = (rp - rank.MinRP) / span
	if progress < 1 / 3 then
		return "III"
	elseif progress < 2 / 3 then
		return "II"
	end
	return "I"
end

return Progression
