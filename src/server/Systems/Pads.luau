--!strict
-- Terrains du lobby (façon Volleyball Legends) : on marche sur une case
-- rouge ou bleue d'un terrain pour le rejoindre. Quand le terrain est plein,
-- un compte à rebours de 5 s part, puis le match est lancé.
--
--   • Rangée Normal : 2v2, 3v3, 4v4, 5v5.
--   • Rangée Classé : 3v3, 4v4, 5v5, dans un enclos dont la porte ne laisse
--     passer que les joueurs niveau 10+ (groupes de collision). Le niveau est
--     de toute façon revérifié côté serveur au moment de rejoindre.
--   • Entraînement : 3v3 contre des bots ; part dès qu'un joueur est dessus.
--
-- Tout est autoritaire côté serveur : la présence sur une case est déduite de
-- la position du personnage lue par le serveur (pas de Touched côté client).
-- Groupes : quand le chef rejoint, ses membres sont placés dans la même équipe.
-- En Studio, un terrain Normal/Classé part aussi avec un seul joueur (bots).

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Matches = require(script.Parent.Matches)
local Matchmaking = require(script.Parent.Matchmaking)
local Party = require(script.Parent.Party)
local PlayerData = require(script.Parent.PlayerData)
local Remote = require(script.Parent.Parent.Lib.Remote)
local ServerRole = require(script.Parent.Parent.Lib.ServerRole)

type Team = string -- "Rouge" | "Bleu"
type Kind = "Normal" | "Ranked" | "Training"

type Slot = {
	Team: Team,
	Index: number,
	Offset: Vector3, -- centre de la case, repère du terrain
	Part: BasePart,
	Light: PointLight,
	Occupant: Player?,
}

type Pad = {
	Id: string,
	Kind: Kind,
	Mode: string,
	TeamSize: number,
	CFrame: CFrame,
	Depth: number,
	Slots: { Slot },
	State: string, -- "Waiting" | "Countdown"
	EndsAt: number?,
	ShownSecond: number?,
	Sign: { Players: TextLabel, Status: TextLabel },
}

type Seat = { Pad: Pad, Slot: Slot, Since: number, OutsideSince: number? }

local Pads = {}

-- Réglages ------------------------------------------------------------------------------

local TICK = 0.15
local COUNTDOWN = 5
local TRAINING_COUNTDOWN = 6
local STUDIO_COUNTDOWN = 6
local SLOT_SIZE = 5
local SLOT_SPACING = 6.5
local HALF_OFFSET = 6.5 -- distance du centre d'une case à la ligne médiane
local JOIN_HALF = 2.5 -- demi-côté de la zone de détection pour rejoindre
local STAY_HALF = 3.6 -- demi-côté toléré avant de considérer qu'on est sorti
local LEAVE_DELAY = 0.35
local PLACEMENT_GRACE = 1.2 -- après une téléportation sur une case
local REFUSE_COOLDOWN = 2.5
local LAUNCH_COOLDOWN = 20

Pads.Layout = {
	NormalRowZ = 0,
	NormalX = { -81, -27, 27, 81 },
	RankedRowZ = -64,
	RankedX = { -46, 0, 46 },
	Training = Vector3.new(-118, 0, 46),
	-- Enclos du classé (min/max en X et Z) et largeur de la porte.
	RankedZone = { MinX = -76, MaxX = 76, MinZ = -96, MaxZ = -38, Gate = 12 },
}

local rgb = Color3.fromRGB
local COLORS = {
	Court = rgb(64, 132, 120),
	CourtRanked = rgb(54, 60, 92),
	Rouge = rgb(232, 64, 70),
	Bleu = rgb(48, 128, 238),
	Line = rgb(250, 250, 246),
	SlotFree = rgb(246, 244, 238),
	Gold = rgb(255, 190, 60),
	Orange = rgb(255, 122, 30),
	Navy = rgb(22, 30, 58),
	Post = rgb(70, 76, 86),
	Fence = rgb(64, 104, 86),
}

local GOTHAM = Font.fromEnum(Enum.Font.GothamBlack)
local GOTHAM_BOLD = Font.fromEnum(Enum.Font.GothamBold)

local GATE_GROUP = "HL_RankedGate"
local LOCKED_GROUP = "HL_Unranked"

local pads: { Pad } = {}
local padsById: { [string]: Pad } = {}
local seats: { [Player]: Seat } = {}
local refusedUntil: { [Player]: number } = {}
local cooldownUntil: { [Player]: number } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- Construction ------------------------------------------------------------------------------

local function part(parent: Instance, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function decor(p: BasePart): BasePart
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function text(parent: Instance, props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.FontFace = props.Font or GOTHAM
	label.TextScaled = true
	label.TextColor3 = props.Color or COLORS.Navy
	label.Text = props.Text or ""
	label.Size = props.Size
	label.Position = props.Position or UDim2.new()
	label.AnchorPoint = props.AnchorPoint or Vector2.zero
	label.TextXAlignment = props.AlignX or Enum.TextXAlignment.Center
	label.Parent = parent
	if props.Stroke then
		local stroke = Instance.new("UIStroke")
		stroke.Color = props.StrokeColor or COLORS.Navy
		stroke.Thickness = props.Stroke
		stroke.Parent = label
	end
	return label
end

local function kindLabel(kind: Kind): (string, Color3)
	if kind == "Ranked" then
		return "CLASSÉ", COLORS.Gold
	elseif kind == "Training" then
		return "ENTRAÎNEMENT", rgb(90, 200, 120)
	end
	return "NORMAL", COLORS.Orange
end

-- Panneau au-dessus du terrain, lisible depuis le sud (côté +Z).
local function buildSign(model: Model, pad: Pad)
	local signCF = pad.CFrame * CFrame.new(0, 0, -pad.Depth / 2 - 1.2)
	for _, x in { -9.5, 9.5 } do
		part(model, Vector3.new(0.7, 13, 0.7), signCF * CFrame.new(x, 6.5, 0), COLORS.Post, Enum.Material.Metal)
	end
	local board =
		part(model, Vector3.new(22, 7.5, 0.5), signCF * CFrame.new(0, 10.2, 0), COLORS.Navy, Enum.Material.Metal)
	decor(board)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Brightness = 1.6
	gui.Parent = board

	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = rgb(255, 255, 255)
	back.BorderSizePixel = 0
	back.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(rgb(255, 255, 255), rgb(226, 236, 248))
	gradient.Rotation = 90
	gradient.Parent = back

	local kindText, kindColor = kindLabel(pad.Kind)
	local band = Instance.new("Frame")
	band.BackgroundColor3 = kindColor
	band.BorderSizePixel = 0
	band.Size = UDim2.new(1, 0, 0, 64)
	band.Parent = back
	text(band, {
		Text = kindText,
		Color = rgb(255, 255, 255),
		Stroke = 3,
		Size = UDim2.new(1, -40, 0, 50),
		Position = UDim2.fromOffset(20, 7),
	})

	local info = Config.Modes[pad.Mode]
	text(back, {
		Text = if info then info.Label else pad.Mode,
		Size = UDim2.new(0.55, 0, 0, 120),
		Position = UDim2.fromOffset(28, 80),
		AlignX = Enum.TextXAlignment.Left,
	})
	local playersLabel = text(back, {
		Text = "0 / 0",
		Font = GOTHAM,
		Color = COLORS.Orange,
		Size = UDim2.new(0.4, 0, 0, 96),
		Position = UDim2.new(1, -28, 0, 92),
		AnchorPoint = Vector2.new(1, 0),
		AlignX = Enum.TextXAlignment.Right,
	})
	local statusLabel = text(back, {
		Text = "",
		Font = GOTHAM_BOLD,
		Color = rgb(90, 100, 130),
		Size = UDim2.new(1, -56, 0, 56),
		Position = UDim2.new(0, 28, 1, -76),
		AlignX = Enum.TextXAlignment.Left,
	})
	pad.Sign = { Players = playersLabel, Status = statusLabel }
end

local function buildPad(parent: Instance, id: string, kind: Kind, mode: string, origin: CFrame): Pad
	local teamSize = if kind == "Training" then 3 else Config.Modes[mode].TeamSize
	local depth = teamSize * SLOT_SPACING + 5
	local model = Instance.new("Model")
	model.Name = id
	model.Parent = parent

	local base = part(
		model,
		Vector3.new(HALF_OFFSET * 4 + 1, 0.6, depth),
		origin * CFrame.new(0, 0.3, 0),
		if kind == "Ranked" then COLORS.CourtRanked else COLORS.Court,
		Enum.Material.SmoothPlastic
	)
	base.Name = "Sol"
	-- Liseré (or pour le classé) et ligne médiane.
	local trim = if kind == "Ranked" then COLORS.Gold else COLORS.Line
	local width = base.Size.X
	for _, z in { -depth / 2 + 0.25, depth / 2 - 0.25 } do
		decor(part(model, Vector3.new(width, 0.05, 0.5), origin * CFrame.new(0, 0.62, z), trim))
	end
	for _, x in { -width / 2 + 0.25, width / 2 - 0.25 } do
		decor(part(model, Vector3.new(0.5, 0.05, depth), origin * CFrame.new(x, 0.62, 0), trim))
	end
	decor(part(model, Vector3.new(0.4, 0.05, depth - 1), origin * CFrame.new(0, 0.62, 0), COLORS.Line))
	-- Bordure surélevée tout autour.
	for _, z in { -depth / 2 - 0.4, depth / 2 + 0.4 } do
		part(
			model,
			Vector3.new(width + 1.6, 0.9, 0.8),
			origin * CFrame.new(0, 0.45, z),
			rgb(232, 228, 220),
			Enum.Material.Concrete
		)
	end
	for _, x in { -width / 2 - 0.4, width / 2 + 0.4 } do
		part(
			model,
			Vector3.new(0.8, 0.9, depth),
			origin * CFrame.new(x, 0.45, 0),
			rgb(232, 228, 220),
			Enum.Material.Concrete
		)
	end

	local pad: Pad = {
		Id = id,
		Kind = kind,
		Mode = mode,
		TeamSize = teamSize,
		CFrame = origin,
		Depth = depth,
		Slots = {},
		State = "Waiting",
		EndsAt = nil,
		ShownSecond = nil,
		Sign = nil :: any,
	}

	for _, team in { "Rouge", "Bleu" } :: { Team } do
		local side = if team == "Rouge" then -1 else 1
		local teamColor = COLORS[team]
		-- Moitié teintée.
		decor(
			part(
				model,
				Vector3.new(HALF_OFFSET * 2 - 1.2, 0.05, depth - 1.6),
				origin * CFrame.new(side * HALF_OFFSET, 0.61, 0),
				teamColor:Lerp(base.Color, 0.55)
			)
		)
		for index = 1, teamSize do
			local z = (index - (teamSize + 1) / 2) * SLOT_SPACING
			local offset = Vector3.new(side * HALF_OFFSET, 0.6, z)
			local slotPart = part(
				model,
				Vector3.new(SLOT_SIZE, 0.16, SLOT_SIZE),
				origin * CFrame.new(offset + Vector3.new(0, 0.08, 0)),
				COLORS.SlotFree
			)
			slotPart.Name = `Case_{team}_{index}`
			decor(slotPart)
			-- Cadre de la couleur de l'équipe.
			for _, edge in
				{
					{ Vector3.new(SLOT_SIZE + 0.6, 0.18, 0.3), Vector3.new(0, 0, SLOT_SIZE / 2 + 0.15) },
					{ Vector3.new(SLOT_SIZE + 0.6, 0.18, 0.3), Vector3.new(0, 0, -SLOT_SIZE / 2 - 0.15) },
					{ Vector3.new(0.3, 0.18, SLOT_SIZE), Vector3.new(SLOT_SIZE / 2 + 0.15, 0, 0) },
					{ Vector3.new(0.3, 0.18, SLOT_SIZE), Vector3.new(-SLOT_SIZE / 2 - 0.15, 0, 0) },
				}
			do
				decor(part(model, edge[1], origin * CFrame.new(offset + edge[2] + Vector3.new(0, 0.09, 0)), teamColor))
			end
			local light = Instance.new("PointLight")
			light.Color = teamColor
			light.Range = 9
			light.Brightness = 1.6
			light.Shadows = false
			light.Enabled = false
			light.Parent = slotPart
			local slot: Slot = {
				Team = team,
				Index = index,
				Offset = offset,
				Part = slotPart,
				Light = light,
				Occupant = nil :: Player?,
			}
			table.insert(pad.Slots, slot)
		end
		-- Nom de l'équipe peint au sol, côté sud.
		local label = decor(
			part(
				model,
				Vector3.new(HALF_OFFSET * 2 - 2, 0.05, 2.2),
				origin * CFrame.new(side * HALF_OFFSET, 0.63, depth / 2 - 1.6),
				teamColor
			)
		)
		label.Transparency = 1
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Top
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.Parent = label
		text(gui, {
			Text = if team == "Rouge" then "ROUGE" else "BLEU",
			Color = teamColor,
			Stroke = 2,
			StrokeColor = rgb(255, 255, 255),
			Size = UDim2.fromScale(1, 1),
		})
	end

	buildSign(model, pad)
	return pad
end

-- Enclos du classé : clôture verte d'école, porte qui ne laisse passer que les
-- joueurs niveau 10+.
local function buildRankedZone(parent: Instance)
	local zone = Pads.Layout.RankedZone
	local model = Instance.new("Model")
	model.Name = "EnclosClasse"
	model.Parent = parent
	local height = 9
	local function fence(from: Vector3, to: Vector3)
		local delta = to - from
		local length = delta.Magnitude
		local cf = CFrame.lookAt((from + to) / 2, to) * CFrame.new(0, height / 2, 0)
		local mesh = part(model, Vector3.new(0.2, height - 1, length), cf, COLORS.Fence, Enum.Material.DiamondPlate)
		mesh.Transparency = 0.45
		for _, y in { -height / 2 + 0.3, height / 2 - 0.2 } do
			decor(
				part(
					model,
					Vector3.new(0.35, 0.35, length),
					cf * CFrame.new(0, y, 0),
					COLORS.Fence,
					Enum.Material.Metal
				)
			)
		end
		local posts = math.max(1, math.floor(length / 8))
		for i = 0, posts do
			local p = from:Lerp(to, i / posts)
			decor(
				part(
					model,
					Vector3.new(0.5, height + 0.6, 0.5),
					CFrame.new(p + Vector3.new(0, (height + 0.6) / 2, 0)),
					COLORS.Fence,
					Enum.Material.Metal
				)
			)
		end
		-- Prolongement invisible : impossible de sauter par-dessus.
		local top = part(model, Vector3.new(0.4, 30, length), cf * CFrame.new(0, height / 2 + 15, 0), COLORS.Fence)
		top.Transparency = 1
		top.CanQuery = false
	end
	local y = 0
	local gateHalf = zone.Gate / 2
	fence(Vector3.new(zone.MinX, y, zone.MinZ), Vector3.new(zone.MaxX, y, zone.MinZ))
	fence(Vector3.new(zone.MinX, y, zone.MinZ), Vector3.new(zone.MinX, y, zone.MaxZ))
	fence(Vector3.new(zone.MaxX, y, zone.MinZ), Vector3.new(zone.MaxX, y, zone.MaxZ))
	fence(Vector3.new(zone.MinX, y, zone.MaxZ), Vector3.new(-gateHalf, y, zone.MaxZ))
	fence(Vector3.new(gateHalf, y, zone.MaxZ), Vector3.new(zone.MaxX, y, zone.MaxZ))

	-- Porte : piliers, arche et barrière lumineuse.
	for _, x in { -gateHalf - 0.6, gateHalf + 0.6 } do
		part(
			model,
			Vector3.new(1.4, 13, 1.4),
			CFrame.new(x, 6.5, zone.MaxZ),
			rgb(236, 232, 224),
			Enum.Material.Concrete
		)
	end
	local arch = part(
		model,
		Vector3.new(zone.Gate + 3, 3, 1.4),
		CFrame.new(0, 14.5, zone.MaxZ),
		COLORS.Navy,
		Enum.Material.Metal
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Brightness = 1.6
	gui.Parent = arch
	text(gui, {
		Text = `CLASSÉ · NIVEAU {Config.RankedUnlockLevel}`,
		Color = COLORS.Gold,
		Size = UDim2.new(1, -30, 1, -24),
		Position = UDim2.fromOffset(15, 12),
	})
	local barrier = part(
		model,
		Vector3.new(zone.Gate, 13, 0.6),
		CFrame.new(0, 6.5, zone.MaxZ),
		COLORS.Gold,
		Enum.Material.ForceField
	)
	barrier.Name = "PorteClasse"
	barrier.Transparency = 0.3
	barrier.CanQuery = false
	barrier.CollisionGroup = GATE_GROUP
end

local function setupCollisionGroups()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(GATE_GROUP)
	end)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(LOCKED_GROUP)
	end)
	PhysicsService:CollisionGroupSetCollidable(GATE_GROUP, "Default", false)
	PhysicsService:CollisionGroupSetCollidable(GATE_GROUP, LOCKED_GROUP, true)
end

local function isRankedUnlocked(player: Player): boolean
	local profile = PlayerData.get(player)
	return profile ~= nil and profile.Level >= Config.RankedUnlockLevel
end

local function applyCollisionGroup(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local group = if isRankedUnlocked(player) then "Default" else LOCKED_GROUP
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = group
		end
	end
end

-- État envoyé aux joueurs -------------------------------------------------------------------

local function counts(pad: Pad): (number, number)
	local rouge, bleu = 0, 0
	for _, slot in pad.Slots do
		if slot.Occupant then
			if slot.Team == "Rouge" then
				rouge += 1
			else
				bleu += 1
			end
		end
	end
	return rouge, bleu
end

local function snapshot(pad: Pad, team: Team): any
	local rouge, bleu = counts(pad)
	local info = Config.Modes[pad.Mode]
	return {
		Id = pad.Id,
		Kind = pad.Kind,
		Mode = pad.Mode,
		Label = if info then info.Label else pad.Mode,
		Team = team,
		TeamSize = pad.TeamSize,
		Rouge = rouge,
		Bleu = bleu,
		Players = rouge + bleu,
		Capacity = pad.TeamSize * 2,
		State = pad.State,
		EndsAt = pad.EndsAt,
	}
end

local function refreshSign(pad: Pad)
	local rouge, bleu = counts(pad)
	pad.Sign.Players.Text = `{rouge + bleu} / {pad.TeamSize * 2}`
	if pad.State == "Countdown" and pad.EndsAt then
		local remaining = math.max(0, math.ceil(pad.EndsAt - now()))
		pad.ShownSecond = remaining
		pad.Sign.Status.Text = `DÉPART DANS {remaining}`
		pad.Sign.Status.TextColor3 = COLORS.Orange
	elseif pad.Kind == "Training" then
		pad.Sign.Status.Text = "Monte sur une case : match contre des bots"
		pad.Sign.Status.TextColor3 = rgb(90, 100, 130)
	elseif pad.Kind == "Ranked" then
		pad.Sign.Status.Text = `Niveau {Config.RankedUnlockLevel} requis · en attente de joueurs`
		pad.Sign.Status.TextColor3 = rgb(90, 100, 130)
	else
		pad.Sign.Status.Text = "En attente de joueurs…"
		pad.Sign.Status.TextColor3 = rgb(90, 100, 130)
	end
end

local function broadcast(pad: Pad)
	refreshSign(pad)
	for _, slot in pad.Slots do
		local occupant = slot.Occupant
		if occupant then
			Remote.fire(occupant, "PadState", snapshot(pad, slot.Team))
		end
	end
end

local function paintSlot(slot: Slot)
	local occupied = slot.Occupant ~= nil
	slot.Part.Color = if occupied then COLORS[slot.Team] else COLORS.SlotFree
	slot.Part.Material = if occupied then Enum.Material.Neon else Enum.Material.SmoothPlastic
	slot.Light.Enabled = occupied
end

-- Places -----------------------------------------------------------------------------------

local function rootOf(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function slotWorld(pad: Pad, slot: Slot): CFrame
	return pad.CFrame * CFrame.new(slot.Offset)
end

-- Repousse un joueur devant le terrain (refus, bouton Quitter).
local function pushOff(player: Player, pad: Pad)
	local character = player.Character
	if character and rootOf(player) then
		local front = pad.CFrame * CFrame.new(0, 3.5, pad.Depth / 2 + 6)
		character:PivotTo(CFrame.lookAt(front.Position, front.Position + pad.CFrame.LookVector))
	end
end

local function vacate(player: Player, notifyClient: boolean)
	local seat = seats[player]
	if not seat then
		return
	end
	seats[player] = nil
	seat.Slot.Occupant = nil
	paintSlot(seat.Slot)
	local pad = seat.Pad
	if pad.State == "Countdown" then
		local rouge, bleu = counts(pad)
		local remainingPlayers = rouge + bleu
		-- Normal/Classé : le compte à rebours exige un terrain plein (sauf Studio).
		local keep = (pad.Kind == "Training" or ServerRole.IsStudio) and remainingPlayers > 0
		if not keep then
			pad.State = "Waiting"
			pad.EndsAt = nil
		end
	end
	if notifyClient then
		Remote.fire(player, "PadState", nil)
	end
	broadcast(pad)
end

local function occupy(player: Player, pad: Pad, slot: Slot, placed: boolean)
	vacate(player, false)
	slot.Occupant = player
	seats[player] = { Pad = pad, Slot = slot, Since = if placed then os.clock() + PLACEMENT_GRACE else os.clock() }
	paintSlot(slot)
	if placed then
		local character = player.Character
		if character then
			local world = slotWorld(pad, slot)
			character:PivotTo(
				CFrame.lookAt(world.Position + Vector3.new(0, 3.2, 0), world.Position + Vector3.new(0, 3.2, 8))
			)
		end
	end
end

local function refuse(player: Player, pad: Pad, message: string)
	refusedUntil[player] = os.clock() + REFUSE_COOLDOWN
	Remote.notify(player, message, "Danger")
	pushOff(player, pad)
end

local function eligible(player: Player, pad: Pad): string?
	if not PlayerData.get(player) then
		return `{player.DisplayName} n'est pas encore prêt.`
	end
	if Matches.isBusy(player) then
		return `{player.DisplayName} est déjà en match.`
	end
	if pad.Kind == "Ranked" and not isRankedUnlocked(player) then
		return `{player.DisplayName} doit être niveau {Config.RankedUnlockLevel} pour le classé.`
	end
	if not rootOf(player) then
		return `{player.DisplayName} n'est pas disponible.`
	end
	return nil
end

-- Le joueur vient de marcher sur une case libre.
local function tryJoin(player: Player, pad: Pad, slot: Slot)
	local problem = eligible(player, pad)
	if problem then
		refuse(player, pad, problem)
		return
	end
	local members = Party.membersOf(player)
	if #members <= 1 then
		occupy(player, pad, slot, false)
		Remote.fire(player, "PadState", snapshot(pad, slot.Team))
		broadcast(pad)
		return
	end
	if not Party.isLeaderOrSolo(player) then
		refuse(player, pad, "Seul le chef du groupe choisit le terrain.")
		return
	end
	if #members > pad.TeamSize and pad.Kind ~= "Training" then
		refuse(player, pad, "Ton groupe est trop grand pour ce terrain.")
		return
	end
	for _, member in members do
		local memberProblem = eligible(member, pad)
		if memberProblem then
			refuse(player, pad, memberProblem)
			return
		end
	end
	-- Places libres (ou déjà tenues par un membre) : d'abord l'équipe choisie,
	-- puis, en entraînement seulement, l'autre équipe.
	local function isFree(candidate: Slot): boolean
		return candidate ~= slot
			and (candidate.Occupant == nil or table.find(members, candidate.Occupant :: Player) ~= nil)
	end
	local free: { Slot } = {}
	for _, candidate in pad.Slots do
		if candidate.Team == slot.Team and isFree(candidate) then
			table.insert(free, candidate)
		end
	end
	if pad.Kind == "Training" then
		for _, candidate in pad.Slots do
			if candidate.Team ~= slot.Team and isFree(candidate) then
				table.insert(free, candidate)
			end
		end
	end
	if #free < #members - 1 then
		refuse(player, pad, "Pas assez de places dans cette équipe pour ton groupe.")
		return
	end
	-- Libère d'abord les places tenues par des membres pour les réattribuer.
	for _, member in members do
		if member ~= player then
			vacate(member, false)
		end
	end
	occupy(player, pad, slot, false)
	local nextFree = 1
	for _, member in members do
		if member ~= player then
			while free[nextFree] and free[nextFree].Occupant ~= nil do
				nextFree += 1
			end
			local target = free[nextFree]
			if target then
				occupy(member, pad, target, true)
				nextFree += 1
			end
		end
	end
	for _, member in members do
		local seat = seats[member]
		if seat then
			Remote.fire(member, "PadState", snapshot(pad, seat.Slot.Team))
		end
	end
	broadcast(pad)
end

-- Lancement -----------------------------------------------------------------------------------

local function partiesOn(players: { Player }): { { number } }
	local seen: { [string]: boolean } = {}
	local groups = {}
	for _, player in players do
		local party = Party.ofPlayer(player)
		if party and not seen[party.Id] then
			seen[party.Id] = true
			local ids = {}
			for _, other in players do
				if table.find(party.Members, other.UserId) then
					table.insert(ids, other.UserId)
				end
			end
			if #ids > 1 then
				table.insert(groups, ids)
			end
		end
	end
	return groups
end

local function launch(pad: Pad)
	local rouge: { Player } = {}
	local bleu: { Player } = {}
	local invalid = false
	for _, slot in pad.Slots do
		local occupant = slot.Occupant
		if occupant then
			if eligible(occupant, pad) then
				invalid = true
				vacate(occupant, true)
			elseif slot.Team == "Rouge" then
				table.insert(rouge, occupant)
			else
				table.insert(bleu, occupant)
			end
		end
	end
	if invalid then
		return -- vacate() a déjà remis le terrain en attente si nécessaire
	end
	local everyone = table.clone(rouge)
	table.move(bleu, 1, #bleu, #everyone + 1, everyone)
	if #everyone == 0 then
		pad.State = "Waiting"
		pad.EndsAt = nil
		broadcast(pad)
		return
	end
	local full = #rouge == pad.TeamSize and #bleu == pad.TeamSize
	local fillBots = pad.Kind == "Training" or not full
	local spec: Matchmaking.LaunchSpec = {
		Mode = pad.Mode,
		Ranked = pad.Kind == "Ranked" and full,
		Training = pad.Kind == "Training",
		FillBots = fillBots,
		Rouge = rouge,
		Bleu = bleu,
		Parties = partiesOn(everyone),
	}
	-- Le terrain se libère tout de suite pour les suivants.
	local launching = snapshot(pad, "Rouge")
	launching.State = "Launching"
	for _, player in everyone do
		local seat = seats[player]
		if seat then
			seats[player] = nil
			seat.Slot.Occupant = nil
			paintSlot(seat.Slot)
			launching.Team = seat.Slot.Team
			Remote.fire(player, "PadState", table.clone(launching))
		end
		cooldownUntil[player] = os.clock() + LAUNCH_COOLDOWN
	end
	pad.State = "Waiting"
	pad.EndsAt = nil
	broadcast(pad)
	task.spawn(function()
		local ok, err = Matchmaking.launch(spec)
		if not ok then
			for _, player in everyone do
				cooldownUntil[player] = nil
				Remote.fire(player, "PadState", nil)
				Remote.notify(player, err or "Le lancement a échoué.", "Danger")
			end
		elseif ServerRole.LocalMatches then
			for _, player in everyone do
				Remote.fire(player, "PadState", nil)
			end
		end
	end)
end

local function updateCountdown(pad: Pad)
	local rouge, bleu = counts(pad)
	local total = rouge + bleu
	if pad.State == "Waiting" then
		local ready
		if pad.Kind == "Training" or ServerRole.IsStudio then
			ready = total > 0
		else
			ready = rouge == pad.TeamSize and bleu == pad.TeamSize
		end
		if ready then
			local duration = if pad.Kind == "Training"
				then TRAINING_COUNTDOWN
				elseif ServerRole.IsStudio and total < pad.TeamSize * 2 then STUDIO_COUNTDOWN
				else COUNTDOWN
			pad.State = "Countdown"
			pad.EndsAt = now() + duration
			broadcast(pad)
		end
		return
	end
	-- En Studio, un terrain qui se remplit raccourcit son compte à rebours.
	if pad.EndsAt and rouge == pad.TeamSize and bleu == pad.TeamSize and pad.EndsAt - now() > COUNTDOWN then
		pad.EndsAt = now() + COUNTDOWN
		broadcast(pad)
	end
	local endsAt = pad.EndsAt or now()
	if now() >= endsAt then
		launch(pad)
		return
	end
	local remaining = math.ceil(endsAt - now())
	if remaining ~= pad.ShownSecond then
		refreshSign(pad)
	end
end

-- Boucle de détection --------------------------------------------------------------------------

local function inside(pad: Pad, slot: Slot, position: Vector3, half: number): boolean
	local rel = pad.CFrame:PointToObjectSpace(position)
	return math.abs(rel.X - slot.Offset.X) <= half
		and math.abs(rel.Z - slot.Offset.Z) <= half
		and rel.Y > -1
		and rel.Y < 9
end

local function step()
	local clock = os.clock()
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		local seat = seats[player]
		local character = player.Character
		local inMatch = Matches.isBusy(player) or (character ~= nil and character:GetAttribute("MatchId") ~= nil)
		if seat then
			if not root or inMatch then
				vacate(player, true)
			elseif clock >= seat.Since and not inside(seat.Pad, seat.Slot, root.Position, STAY_HALF) then
				seat.OutsideSince = seat.OutsideSince or clock
				if clock - (seat.OutsideSince :: number) >= LEAVE_DELAY then
					vacate(player, true)
				end
			else
				seat.OutsideSince = nil
			end
			continue
		end
		if not root or inMatch then
			continue
		end
		if (refusedUntil[player] or 0) > clock or (cooldownUntil[player] or 0) > clock then
			continue
		end
		for _, pad in pads do
			local rel = pad.CFrame:PointToObjectSpace(root.Position)
			if math.abs(rel.Z) > pad.Depth / 2 + 2 or math.abs(rel.X) > HALF_OFFSET * 2 + 3 then
				continue
			end
			for _, slot in pad.Slots do
				if slot.Occupant == nil and inside(pad, slot, root.Position, JOIN_HALF) then
					tryJoin(player, pad, slot)
					break
				end
			end
			break
		end
	end
	for _, pad in pads do
		updateCountdown(pad)
	end
end

-- Cycle de vie ----------------------------------------------------------------------------------

function Pads.init()
	if ServerRole.Role ~= "Lobby" then
		return
	end
	setupCollisionGroups()
	local folder = Instance.new("Folder")
	folder.Name = "Terrains"
	folder.Parent = Workspace

	local layout = Pads.Layout
	local facing = CFrame.Angles(0, 0, 0) -- les terrains regardent vers le sud (+Z) : le panneau est au nord
	for index, mode in Config.ModeOrder do
		local x = layout.NormalX[index]
		if x then
			local id = `Normal_{mode}`
			local pad = buildPad(folder, id, "Normal", mode, CFrame.new(x, 0, layout.NormalRowZ) * facing)
			table.insert(pads, pad)
			padsById[id] = pad
		end
	end
	local rankedIndex = 0
	for _, mode in Config.ModeOrder do
		if Config.Modes[mode].RankedAllowed then
			rankedIndex += 1
			local x = layout.RankedX[rankedIndex]
			if x then
				local id = `Classe_{mode}`
				local pad = buildPad(folder, id, "Ranked", mode, CFrame.new(x, 0, layout.RankedRowZ) * facing)
				table.insert(pads, pad)
				padsById[id] = pad
			end
		end
	end
	local training = buildPad(folder, "Entrainement", "Training", "3v3", CFrame.new(layout.Training) * facing)
	table.insert(pads, training)
	padsById[training.Id] = training
	buildRankedZone(folder)
	for _, pad in pads do
		refreshSign(pad)
	end

	Remote.onInvoke("PadAction", 4, 8, function(player, action)
		if action ~= "Leave" then
			return Remote.fail("Action inconnue.")
		end
		local seat = seats[player]
		if seat then
			local pad = seat.Pad
			vacate(player, true)
			refusedUntil[player] = os.clock() + REFUSE_COOLDOWN
			pushOff(player, pad)
		end
		return Remote.ok()
	end)
end

function Pads.start()
	if ServerRole.Role ~= "Lobby" then
		return
	end
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			vacate(player, true)
			task.defer(applyCollisionGroup, player)
			character.DescendantAdded:Connect(function(descendant)
				if descendant:IsA("BasePart") then
					descendant.CollisionGroup = if isRankedUnlocked(player) then "Default" else LOCKED_GROUP
				end
			end)
		end)
		if player.Character then
			applyCollisionGroup(player)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		vacate(player, false)
		refusedUntil[player] = nil
		cooldownUntil[player] = nil
	end)
	-- Le niveau change (ou le profil arrive) : la porte du classé s'adapte.
	PlayerData.Changed:Connect(function(player)
		applyCollisionGroup(player)
	end)
	task.spawn(function()
		while true do
			task.wait(TICK)
			local result = table.pack(pcall(step))
			if not result[1] then
				warn(`[Pads] {result[2]}`)
			end
		end
	end)
end

return Pads
