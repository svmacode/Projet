--!strict
-- Tir au timing (façon Volleyball Legends) : tant que le bouton de tir est
-- maintenu, un curseur fait des allers-retours sur une jauge. Relâcher dans
-- la zone parfaite donne un tir parfait (puissance et précision maximales).
--
-- Partagé : le client dessine la jauge, le serveur recalcule la note à partir
-- de SES propres horodatages (début de charge reçu, relâchement reçu,
-- compensation du ping bornée). Le client n'envoie jamais sa note.
--
-- Contrat client :
--   • au début de la charge, MatchInput met l'attribut "ShotChargeStart"
--     (Workspace:GetServerTimeNow()) sur le LocalPlayer, et le retire au
--     relâchement ou à l'annulation ; le HUD lit cet attribut ;
--   • le serveur annonce la note par MatchEvent("ShotGrade", { UserId, Grade, Phase }).

local ShotTiming = {}

export type Grade = "Perfect" | "Good" | "Weak"

ShotTiming.Cycle = 1.1 -- secondes pour un aller-retour complet 0 → 1 → 0
ShotTiming.PerfectMin = 0.84
ShotTiming.PerfectMax = 0.96
ShotTiming.GoodMin = 0.6
ShotTiming.MaxPingCompensation = 0.15 -- secondes

-- Position du curseur (0..1) après `elapsed` secondes de charge.
function ShotTiming.phase(elapsed: number): number
	local t = (math.max(0, elapsed) % ShotTiming.Cycle) / ShotTiming.Cycle
	return if t < 0.5 then t * 2 else (1 - t) * 2
end

function ShotTiming.grade(phase: number): Grade
	if phase >= ShotTiming.PerfectMin and phase <= ShotTiming.PerfectMax then
		return "Perfect"
	elseif phase >= ShotTiming.GoodMin then
		return "Good"
	end
	return "Weak"
end

-- Multiplicateurs appliqués au tir selon la note.
ShotTiming.Effects = {
	Perfect = { Speed = 1.0, Spread = 0 },
	Good = { Speed = 0.82, Spread = 0.04 },
	Weak = { Speed = 0.6, Spread = 0.12 },
} :: { [string]: { Speed: number, Spread: number } }

return ShotTiming
