--!strict
-- Personnalisation des clans : emblèmes, motifs de bannière, palette.
-- Les clans choisissent dans ces listes : rien n'est saisi librement à part
-- le nom et le tag (filtrés par Roblox).

local ClanStyle = {}

ClanStyle.Emblems = {
	{ Id = "Feu", Glyph = "炎", Name = "Flamme" },
	{ Id = "Foudre", Glyph = "雷", Name = "Foudre" },
	{ Id = "Dragon", Glyph = "龍", Name = "Dragon" },
	{ Id = "Oni", Glyph = "鬼", Name = "Oni" },
	{ Id = "Etoile", Glyph = "星", Name = "Étoile" },
	{ Id = "Lame", Glyph = "刃", Name = "Lame" },
	{ Id = "Vent", Glyph = "風", Name = "Vent" },
	{ Id = "Glace", Glyph = "氷", Name = "Glace" },
	{ Id = "Ombre", Glyph = "影", Name = "Ombre" },
	{ Id = "Lumiere", Glyph = "光", Name = "Lumière" },
	{ Id = "Roi", Glyph = "王", Name = "Roi" },
	{ Id = "Tigre", Glyph = "虎", Name = "Tigre" },
}

ClanStyle.Patterns = {
	{ Id = "Uni", Name = "Uni" },
	{ Id = "Bande", Name = "Bande" },
	{ Id = "Diagonale", Name = "Diagonale" },
	{ Id = "Soleil", Name = "Soleil levant" },
	{ Id = "Chevron", Name = "Chevron" },
}

ClanStyle.Palette = {
	Color3.fromRGB(226, 32, 52),
	Color3.fromRGB(255, 120, 30),
	Color3.fromRGB(255, 200, 40),
	Color3.fromRGB(80, 210, 90),
	Color3.fromRGB(30, 180, 170),
	Color3.fromRGB(30, 110, 245),
	Color3.fromRGB(110, 70, 230),
	Color3.fromRGB(230, 60, 170),
	Color3.fromRGB(250, 250, 245),
	Color3.fromRGB(20, 20, 26),
	Color3.fromRGB(150, 100, 60),
	Color3.fromRGB(255, 225, 130),
}

ClanStyle.Roles = { "Chef", "Officier", "Membre" }

function ClanStyle.emblem(id: string): { Id: string, Glyph: string, Name: string }
	for _, emblem in ClanStyle.Emblems do
		if emblem.Id == id then
			return emblem
		end
	end
	return ClanStyle.Emblems[1]
end

function ClanStyle.color(index: number): Color3
	return ClanStyle.Palette[index] or ClanStyle.Palette[1]
end

return ClanStyle
