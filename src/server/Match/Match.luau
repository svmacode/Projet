--!nonstrict
-- Un match de handball complet.
--
-- Déroulement : choix des postes -> présentation -> engagement -> 1re mi-temps
-- -> mi-temps (changement de côté) -> 2e mi-temps -> but en or si égalité
-- (hors entraînement) -> fin.
--
-- Règles appliquées (inspirées des règles officielles IHF) :
--   * 3 secondes max avec le ballon, 3 pas (distance), reprise de dribble interdite
--   * zone réservée au gardien ; gardien qui sort de sa zone avec le ballon
--   * engagement au centre après chaque but, par l'équipe qui a encaissé
--   * jets francs (repoussés aux 9 m), touches, corners, renvois du gardien
--   * jet de 7 m sur occasion manifeste ou défense dans la zone
--   * contacts : légal de face sur le porteur, faute par derrière ou sans ballon
--   * progression disciplinaire : avertissement, exclusions temporaires, rouge
--   * jeu passif : geste d'avertissement puis perte de balle

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Archetypes = require(ReplicatedStorage.Shared.Data.Archetypes)
local BallMath = require(ReplicatedStorage.Shared.BallMath)
local Config = require(ReplicatedStorage.Shared.Config)
local Court = require(ReplicatedStorage.Shared.Court)
local Net = require(ReplicatedStorage.Shared.Net)
local Abilities = require(script.Parent.Abilities)
local Ball = require(script.Parent.Ball)
local Bots = require(script.Parent.Bots)
local CourtBuilder = require(script.Parent.CourtBuilder)
local MatchTypes = require(script.Parent.MatchTypes)
local Outfit = require(script.Parent.Outfit)

type Participant = MatchTypes.Participant

export type MatchConfig = {
	Id: string,
	Mode: string,
	Ranked: boolean,
	Training: boolean,
	FillBots: boolean,
	Teams: { Rouge: { number }, Bleu: { number } },
}

export type PlayerInfo = {
	KitId: string,
	Equipped: { [string]: string },
	SelectedArchetype: { [string]: string },
	OwnedArchetypes: { [string]: boolean },
	ClanTag: string?,
}

export type SetPiece = {
	Kind: string,
	Team: string,
	Thrower: Participant,
	WhistleAt: number,
}

local Match = {}
Match.__index = Match

local TEAMS = { "Rouge", "Bleu" }
local FIELD_NUMBERS = { 7, 10, 9, 11, 14, 23, 8, 5 }

local SET_PIECE_LABELS = {
	ThrowOff = "ENGAGEMENT",
	FreeThrow = "JET FRANC",
	ThrowIn = "TOUCHE",
	Corner = "CORNER",
	GoalThrow = "RENVOI",
	Penalty = "JET DE 7 MÈTRES",
}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function otherTeam(team: string): string
	return if team == "Rouge" then "Bleu" else "Rouge"
end

-- Construction --------------------------------------------------------------------------

function Match.new(config: MatchConfig, players: { Player }, infos: { [Player]: PlayerInfo }, origin: CFrame, parent: Instance): any
	local self = setmetatable({}, Match) :: any
	self.Config = config
	self.ModeInfo = Config.Modes[config.Mode]
	self.Court = CourtBuilder.build(config.Mode, origin, parent)
	self.Ball = Ball.new(self)
	self.Participants = {} :: { Participant }
	self.ByPlayer = {} :: { [Player]: Participant }
	self.Infos = infos
	self.Players = {} :: { Player }
	self.Score = { Rouge = 0, Bleu = 0 }
	self.AttackSide = { Rouge = 1, Bleu = -1 }
	self.Phase = "Setup"
	self.Half = 1
	self.Clock = self.ModeInfo.HalfDuration
	self.ClockRunning = false
	self.Finished = false
	self.SetPiece = nil :: SetPiece?
	self.PossessionTeam = nil :: string?
	self.PossessionStart = 0
	self.PassiveWarning = false
	self.LastPasser = nil :: Participant?
	self.LastPassTime = 0
	self.Blind = {} :: { [Participant]: number }
	self.Walls = {} :: { BasePart }
	self.Connections = {} :: { RBXScriptConnection }
	self.LastSnapshot = 0
	self.LastScoreboard = 0
	self.SetupDeadline = 0
	self.Message = nil :: string?
	self.BotFolder = Instance.new("Folder")
	self.BotFolder.Name = "Bots"
	self.BotFolder.Parent = self.Court.Model

	local botIndex = 0
	for _, team in TEAMS do
		local userIds: { number } = (config.Teams :: any)[team] or {}
		for _, userId in userIds do
			local player = Players:GetPlayerByUserId(userId)
			if player and table.find(players, player) then
				self:addHuman(player, team)
			end
		end
		if config.FillBots then
			while self:teamCount(team) < self.ModeInfo.TeamSize do
				botIndex += 1
				self:addBot(team, botIndex)
			end
		end
	end
	return self
end

local function newParticipant(id: string, name: string, team: string): Participant
	return {
		Id = id,
		Player = nil,
		IsBot = false,
		Name = name,
		UserId = 0,
		Team = team,
		Poste = nil,
		ArchetypeId = nil,
		Model = nil,
		Humanoid = nil,
		Root = nil,
		Number = 0,
		KitId = "Lycee",
		Equipped = {},
		ClanTag = nil,
		Goals = 0,
		Assists = 0,
		Saves = 0,
		Interceptions = 0,
		Steals = 0,
		ShotsOnTarget = 0,
		Fouls = 0,
		Yellow = false,
		Suspensions = 0,
		SuspendedUntil = 0,
		Red = false,
		Energy = 0,
		Ultimate = 0,
		Power1ReadyAt = 0,
		EnergyGainAt = {},
		NextDashAt = 0,
		NextContactAt = 0,
		NextInterceptAt = 0,
		InterceptUntil = 0,
		RamUntil = 0,
		DiveUntil = 0,
		ZoneTouchUntil = 0,
		Effects = {},
		ShotBuff = nil,
		LastSpeedApplied = -1,
		LastJumpApplied = -1,
		Ready = false,
		Connected = true,
		Bot = nil,
	}
end

function Match:addHuman(player: Player, team: string)
	local participant = newParticipant(`p{player.UserId}`, player.DisplayName, team)
	participant.Player = player
	participant.UserId = player.UserId
	local info: PlayerInfo? = self.Infos[player]
	if info then
		participant.KitId = info.KitId
		participant.Equipped = info.Equipped
		participant.ClanTag = info.ClanTag
	end
	table.insert(self.Participants, participant)
	self.ByPlayer[player] = participant
	table.insert(self.Players, player)
end

function Match:addBot(team: string, index: number)
	local name = Bots.Names[(index - 1) % #Bots.Names + 1]
	local participant = newParticipant(`bot{index}`, `{name} (bot)`, team)
	participant.IsBot = true
	participant.UserId = -index
	participant.Bot = Bots.newState(index)
	participant.KitId = "Lycee"
	participant.Ready = true
	table.insert(self.Participants, participant)
end

function Match:teamCount(team: string): number
	local count = 0
	for _, participant in self.Participants do
		if participant.Team == team then
			count += 1
		end
	end
	return count
end

-- Réseau ------------------------------------------------------------------------------------

function Match:fireAll(name: string, ...: any)
	local remote = Net.event(name)
	for _, player in self.Players do
		if player.Parent == Players then
			remote:FireClient(player, ...)
		end
	end
end

function Match:fireTo(player: Player, name: string, ...: any)
	if player.Parent == Players then
		Net.event(name):FireClient(player, ...)
	end
end

function Match:event(kind: string, data: any)
	self:fireAll("MatchEvent", kind, data)
end

function Match:notify(participant: Participant, text: string, style: string?)
	if participant.Player then
		self:fireTo(participant.Player, "Notify", text, style or "Info")
	end
end

-- Interrogations ------------------------------------------------------------------------------

function Match:attackSideOf(team: string): number
	return self.AttackSide[team]
end

function Match:defendSideOf(team: string): number
	return -self.AttackSide[team]
end

function Match:isActive(participant: Participant): boolean
	return participant.Connected
		and participant.Root ~= nil
		and participant.Root.Parent ~= nil
		and participant.SuspendedUntil <= now()
end

function Match:isStunned(participant: Participant): boolean
	for _, effect in participant.Effects do
		if effect.Kind == "Stun" and effect.ExpiresAt > now() then
			return true
		end
	end
	return false
end

function Match:canAct(participant: Participant): boolean
	return self:isActive(participant) and not self:isStunned(participant)
end

function Match:canTouchBall(participant: Participant): boolean
	return self:canAct(participant)
end

function Match:activeParticipants(): { Participant }
	local list = {}
	for _, participant in self.Participants do
		if self:isActive(participant) then
			table.insert(list, participant)
		end
	end
	return list
end

function Match:opponentsOf(participant: Participant): { Participant }
	local list = {}
	for _, other in self.Participants do
		if other.Team ~= participant.Team and self:isActive(other) then
			table.insert(list, other)
		end
	end
	return list
end

function Match:teammatesOf(participant: Participant, includeSelf: boolean): { Participant }
	local list = {}
	for _, other in self.Participants do
		if other.Team == participant.Team and (includeSelf or other ~= participant) and self:isActive(other) then
			table.insert(list, other)
		end
	end
	return list
end

function Match:localOf(participant: Participant): Vector3?
	local root = participant.Root
	if not root then
		return nil
	end
	return self.Court.CFrame:PointToObjectSpace(root.Position)
end

function Match:isGrounded(participant: Participant): boolean
	local humanoid = participant.Humanoid
	return humanoid ~= nil and humanoid.FloorMaterial ~= Enum.Material.Air
end

function Match:effectValue(participant: Participant, kind: string, default: number): number
	local value = default
	local t = now()
	for _, effect in participant.Effects do
		if effect.Kind == kind and effect.ExpiresAt > t then
			value *= effect.Value
		end
	end
	return value
end

function Match:hasEffect(participant: Participant, kind: string): boolean
	local t = now()
	for _, effect in participant.Effects do
		if effect.Kind == kind and effect.ExpiresAt > t then
			return true
		end
	end
	return false
end

function Match:isBlind(participant: Participant): boolean
	return (self.Blind[participant] or 0) > now()
end

-- Effets ------------------------------------------------------------------------------------------

function Match:addEffect(participant: Participant, kind: string, value: number, duration: number)
	table.insert(participant.Effects, { Kind = kind, Value = value, ExpiresAt = now() + duration })
	if participant.Model then
		self:event("Status", { Model = participant.Model, Kind = kind, Duration = duration })
	end
end

function Match:stun(participant: Participant, duration: number, label: string?)
	self:addEffect(participant, "Stun", 1, duration)
	if self.Ball.Holder == participant and self.Phase == "Live" then
		self.Ball:drop()
	end
	if label and participant.Model then
		self:event("Popup", { Model = participant.Model, Text = label, Style = "Danger" })
	end
end

function Match:blind(participant: Participant, duration: number)
	self.Blind[participant] = now() + duration
	if participant.Player then
		self:fireTo(participant.Player, "MatchEvent", "Blind", { Duration = duration })
	end
	if participant.Model then
		self:event("Status", { Model = participant.Model, Kind = "Blind", Duration = duration })
	end
end

function Match:gainEnergy(participant: Participant, reason: string)
	local amount = Config.Powers.EnergyGains[reason]
	if not amount then
		return
	end
	local t = now()
	if (participant.EnergyGainAt[reason] or 0) > t then
		return
	end
	participant.EnergyGainAt[reason] = t + Config.Powers.EnergyGainCooldown
	participant.Energy = math.min(Config.Powers.EnergyMax, participant.Energy + amount)
end

function Match:gainUltimate(participant: Participant, reason: string)
	local amount = Config.Powers.UltimateGains[reason]
	if amount and not participant.Red then
		participant.Ultimate = math.min(Config.Powers.UltimateMax, participant.Ultimate + amount)
	end
end

function Match:createGoalWall(team: string, duration: number, coverage: number, style: string)
	local dims: Court.Dimensions = self.Court.Dims
	local side = self:defendSideOf(team)
	local width = dims.GoalWidth * math.clamp(coverage, 0.2, 1) + (if coverage >= 1 then 1 else 0)
	local height = dims.GoalHeight * (if coverage >= 1 then 1.05 else 0.85)
	local x = side * (dims.Length / 2 - 0.9)
	local wall = Instance.new("Part")
	wall.Name = "MurDePouvoir"
	wall.Anchored = true
	wall.CanCollide = false
	wall.CanTouch = false
	wall.CanQuery = true
	wall.Size = Vector3.new(0.8, height, width)
	wall.CFrame = self.Court.CFrame * CFrame.new(x, height / 2, 0)
	local styles: { [string]: { Color3 | Enum.Material | number } } = {
		Ice = { Color3.fromRGB(150, 230, 255), Enum.Material.Ice, 0.15 },
		Wood = { Color3.fromRGB(150, 96, 50), Enum.Material.WoodPlanks, 0 },
		Net = { Color3.fromRGB(40, 190, 170), Enum.Material.Fabric, 0.2 },
		Light = { Color3.fromRGB(255, 245, 190), Enum.Material.Neon, 0.1 },
		Holy = { Color3.fromRGB(255, 225, 130), Enum.Material.Neon, 0.05 },
	}
	local look = styles[style] or styles.Ice
	wall.Color = look[1] :: Color3
	wall.Material = look[2] :: Enum.Material
	wall.Transparency = look[3] :: number
	wall.Parent = self.Court.Collidables
	table.insert(self.Walls, wall)
	self:event("GoalWall", { Part = wall, Style = style, Duration = duration, Team = team })
	task.delay(duration, function()
		local index = table.find(self.Walls, wall)
		if index then
			table.remove(self.Walls, index)
		end
		wall:Destroy()
	end)
end

-- Placement des personnages ------------------------------------------------------------------

function Match:placeAt(participant: Participant, localPosition: Vector3, lookAtLocal: Vector3?)
	local model = participant.Model
	local root = participant.Root
	if not model or not root then
		return
	end
	local world = self.Court.CFrame:PointToWorldSpace(localPosition + Vector3.new(0, 3, 0))
	local target = self.Court.CFrame:PointToWorldSpace((lookAtLocal or Vector3.zero) + Vector3.new(0, 3, 0))
	if (target - world).Magnitude < 0.1 then
		target = world + self.Court.CFrame.LookVector
	end
	model:PivotTo(CFrame.lookAt(world, Vector3.new(target.X, world.Y, target.Z)))
	root.AssemblyLinearVelocity = Vector3.zero
end

function Match:bindCharacter(participant: Participant, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
	if not humanoid or not root or not humanoid:IsA("Humanoid") or not root:IsA("BasePart") then
		return
	end
	participant.Model = character
	participant.Humanoid = humanoid
	participant.Root = root
	participant.LastSpeedApplied = -1
	participant.LastJumpApplied = -1
	humanoid.UseJumpPower = true
	character:SetAttribute("Team", participant.Team)
	character:SetAttribute("ParticipantId", participant.Id)
	character:SetAttribute("MatchId", self.Config.Id)
	Outfit.apply(character, {
		Team = participant.Team,
		KitId = participant.KitId,
		Number = participant.Number,
		Equipped = participant.Equipped,
		ClanTag = participant.ClanTag,
	})
end

function Match:spawnBot(participant: Participant)
	local model, humanoid, root = Bots.buildRig(participant.Name)
	model.Parent = self.BotFolder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	Bots.animate(humanoid)
	participant.Model = model
	participant.Humanoid = humanoid
	participant.Root = root
	model:SetAttribute("Team", participant.Team)
	model:SetAttribute("ParticipantId", participant.Id)
	model:SetAttribute("MatchId", self.Config.Id)
	Outfit.apply(model, {
		Team = participant.Team,
		KitId = participant.KitId,
		Number = participant.Number,
		Equipped = participant.Equipped,
	})
end

-- Place chaque équipe dans sa moitié (engagement) ou en position de jeu.
function Match:formation(kickoff: boolean)
	local dims: Court.Dimensions = self.Court.Dims
	for _, team in TEAMS do
		local side = self:defendSideOf(team)
		local keeper: Participant? = nil
		local field: { Participant } = {}
		for _, participant in self.Participants do
			if participant.Team == team and self:isActive(participant) then
				if participant.Poste == "Gardien" and not keeper then
					keeper = participant
				else
					table.insert(field, participant)
				end
			end
		end
		local spots = Court.formation(dims, #field, side, kickoff)
		if keeper then
			self:placeAt(keeper, spots[1], Vector3.zero)
		end
		for index, participant in field do
			self:placeAt(participant, spots[index + 1], Vector3.new(-side * dims.Length, 0, 0))
		end
	end
end

-- Choix des postes ---------------------------------------------------------------------------------

function Match:setupSnapshot(): any
	local entries = {}
	for _, participant in self.Participants do
		table.insert(entries, {
			Id = participant.Id,
			Name = participant.Name,
			UserId = participant.UserId,
			IsBot = participant.IsBot,
			Team = participant.Team,
			Poste = participant.Poste,
			Archetype = participant.ArchetypeId,
			Ready = participant.Ready,
		})
	end
	return {
		MatchId = self.Config.Id,
		Mode = self.Config.Mode,
		Ranked = self.Config.Ranked,
		Training = self.Config.Training,
		Deadline = self.SetupDeadline,
		Participants = entries,
		Closed = self.Phase ~= "Setup",
	}
end

function Match:broadcastSetup()
	self:fireAll("MatchSetup", self:setupSnapshot())
end

function Match:keeperOf(team: string): Participant?
	for _, participant in self.Participants do
		if participant.Team == team and participant.Poste == "Gardien" then
			return participant
		end
	end
	return nil
end

local function defaultArchetype(info: PlayerInfo?, poste: string): string
	if info then
		local selected = info.SelectedArchetype[poste]
		if selected and info.OwnedArchetypes[selected] then
			local archetype = Archetypes.get(selected)
			if archetype and archetype.Poste == poste then
				return selected
			end
		end
	end
	for _, id in Archetypes.Starters do
		local archetype = Archetypes.get(id)
		if archetype and archetype.Poste == poste then
			return id
		end
	end
	return Archetypes.Starters[1]
end

function Match:handleSetup(player: Player, action: string, arg: any): (boolean, string?)
	local participant = self.ByPlayer[player]
	if not participant or self.Phase ~= "Setup" then
		return false, "Choix fermé."
	end
	local info: PlayerInfo? = self.Infos[player]
	if action == "Poste" then
		if not Archetypes.isPoste(arg) then
			return false, "Poste invalide."
		end
		if arg == "Gardien" then
			local keeper = self:keeperOf(participant.Team)
			if keeper and keeper ~= participant then
				return false, "Ton équipe a déjà un gardien."
			end
		end
		participant.Poste = arg
		participant.ArchetypeId = defaultArchetype(info, arg)
		participant.Ready = false
	elseif action == "Archetype" then
		local archetype = Archetypes.get(arg)
		if not archetype or not participant.Poste or archetype.Poste ~= participant.Poste then
			return false, "Archétype invalide pour ce poste."
		end
		if not info or not info.OwnedArchetypes[archetype.Id] then
			return false, "Archétype non débloqué."
		end
		participant.ArchetypeId = archetype.Id
	elseif action == "Ready" then
		if not participant.Poste or not participant.ArchetypeId then
			return false, "Choisis d'abord ton poste."
		end
		participant.Ready = true
	else
		return false, "Action inconnue."
	end
	self:broadcastSetup()
	return true, nil
end

function Match:autoAssign()
	local rng = Random.new()
	for _, team in TEAMS do
		local members = {}
		for _, participant in self.Participants do
			if participant.Team == team then
				table.insert(members, participant)
			end
		end
		if not self:keeperOf(team) then
			-- Priorité : humain sans poste, puis bot, puis n'importe qui.
			local pick: Participant? = nil
			for _, participant in members do
				if not participant.IsBot and not participant.Poste then
					pick = participant
					break
				end
			end
			if not pick then
				for _, participant in members do
					if participant.IsBot then
						pick = participant
						break
					end
				end
			end
			pick = pick or members[1]
			if pick then
				pick.Poste = "Gardien"
				pick.ArchetypeId = nil
			end
		end
		local toggle = 0
		for _, participant in members do
			if not participant.Poste then
				toggle += 1
				participant.Poste = if toggle % 2 == 1 then "Attaquant" else "Defenseur"
				participant.ArchetypeId = nil
			end
			if not participant.ArchetypeId then
				if participant.IsBot then
					local pool = {}
					for _, archetype in Archetypes.byPoste(participant.Poste :: string) do
						if archetype.Rarity == "Commun" or archetype.Rarity == "PeuCommun" then
							table.insert(pool, archetype.Id)
						end
					end
					participant.ArchetypeId = pool[rng:NextInteger(1, #pool)]
				else
					local player = participant.Player
					participant.ArchetypeId = defaultArchetype(if player then self.Infos[player] else nil, participant.Poste :: string)
				end
			end
			participant.Ready = true
		end
		-- Numéros de maillot.
		local fieldIndex = 0
		for _, participant in members do
			if participant.Poste == "Gardien" then
				participant.Number = 1
			else
				fieldIndex += 1
				participant.Number = FIELD_NUMBERS[(fieldIndex - 1) % #FIELD_NUMBERS + 1]
			end
		end
	end
end

function Match:setupPhase()
	self.Phase = "Setup"
	self.SetupDeadline = now() + Config.Match.PositionSelectTime
	self:broadcastSetup()
	while now() < self.SetupDeadline and not self.Finished do
		local allReady = true
		for _, participant in self.Participants do
			if not participant.IsBot and participant.Connected and not participant.Ready then
				allReady = false
			end
		end
		if allReady then
			break
		end
		task.wait(0.25)
	end
	self:autoAssign()
	self.Phase = "Intro"
	self:broadcastSetup()
end

-- Vitesse et contraintes de déplacement ---------------------------------------------------------

function Match:isFrozen(participant: Participant): boolean
	if self.Phase == "ThrowOff" or self.Phase == "Intro" then
		return true
	end
	local setPiece: SetPiece? = self.SetPiece
	if setPiece and setPiece.Thrower == participant and self.Ball.Holder == participant and setPiece.Kind ~= "GoalThrow" then
		return true
	end
	return false
end

function Match:applyMovement(participant: Participant)
	local humanoid = participant.Humanoid
	if not humanoid then
		return
	end
	local speed: number
	local jump = Config.Movement.JumpPower
	if not self:isActive(participant) or self:isStunned(participant) or self:isFrozen(participant) then
		speed = 0
		jump = 0
	else
		speed = if participant.Poste == "Gardien" then Config.Movement.KeeperWalkSpeed else Config.Movement.WalkSpeed
		speed *= self:effectValue(participant, "Haste", 1) * self:effectValue(participant, "Slow", 1)
		if self.Ball.Holder == participant and self.Ball.Dribbling then
			speed *= Config.Rules.DribbleSpeedMultiplier
		end
	end
	speed = math.floor(speed * 10 + 0.5) / 10
	if speed ~= participant.LastSpeedApplied then
		participant.LastSpeedApplied = speed
		humanoid.WalkSpeed = speed
	end
	if jump ~= participant.LastJumpApplied then
		participant.LastJumpApplied = jump
		humanoid.JumpPower = jump
	end
end

-- Coups de sifflet --------------------------------------------------------------------------------

function Match:chooseThrower(team: string, localSpot: Vector3, preferKeeper: boolean): Participant?
	if preferKeeper then
		local keeper = self:keeperOf(team)
		if keeper and self:isActive(keeper) then
			return keeper
		end
	end
	local best: Participant? = nil
	local bestScore = math.huge
	for _, participant in self.Participants do
		if participant.Team == team and self:isActive(participant) then
			local localPos = self:localOf(participant)
			if localPos then
				local score = (Vector3.new(localPos.X, 0, localPos.Z) - localSpot).Magnitude
				if participant.Poste == "Gardien" then
					score += 200
				end
				if score < bestScore then
					best = participant
					bestScore = score
				end
			end
		end
	end
	return best
end

-- Accorde une phase arrêtée à `team`.
function Match:awardSetPiece(kind: string, team: string, localSpot: Vector3, reason: string?)
	if self.Finished then
		return
	end
	local dims: Court.Dimensions = self.Court.Dims
	local attackSide = self:attackSideOf(team)
	local spot = Vector3.new(localSpot.X, 0, localSpot.Z)
	if kind == "FreeThrow" then
		spot = Court.pushOutside(dims, spot, attackSide, dims.FreeThrowRadius)
		spot = Court.pushOutside(dims, spot, -attackSide, dims.GoalAreaRadius + 1)
	elseif kind == "ThrowIn" then
		spot = Vector3.new(math.clamp(spot.X, -dims.Length / 2 + 2, dims.Length / 2 - 2), 0, math.sign(spot.Z) * (dims.Width / 2 - 0.5))
		spot = Court.pushOutside(dims, spot, attackSide, dims.GoalAreaRadius + 1)
		spot = Court.pushOutside(dims, spot, -attackSide, dims.GoalAreaRadius + 1)
	elseif kind == "Corner" then
		local zSign = if spot.Z >= 0 then 1 else -1
		spot = Vector3.new(attackSide * (dims.Length / 2 - 0.8), 0, zSign * (dims.Width / 2 - 0.8))
	elseif kind == "GoalThrow" then
		spot = Court.keeperSpot(dims, -attackSide)
	elseif kind == "Penalty" then
		spot = Court.penaltySpot(dims, attackSide)
	end

	local thrower = self:chooseThrower(team, spot, kind == "GoalThrow")
	if not thrower then
		return
	end
	local goalLocal = Vector3.new(attackSide * dims.Length / 2, 0, 0)
	self:placeAt(thrower, spot, goalLocal)

	-- Écarter les adversaires du lanceur (3 m en vrai).
	local minDistance = Config.Rules.SetPieceDefenderDistance
	for _, participant in self.Participants do
		if participant ~= thrower and self:isActive(participant) then
			local localPos = self:localOf(participant)
			if localPos then
				local flat = Vector3.new(localPos.X, 0, localPos.Z)
				if kind == "Penalty" then
					if participant.Poste == "Gardien" and participant.Team ~= team then
						self:placeAt(participant, Court.keeperSpot(dims, attackSide) + Vector3.new(attackSide * 1.5, 0, 0), spot)
					else
						local pushed = Court.pushOutside(dims, flat, attackSide, dims.FreeThrowRadius + 1)
						if (pushed - flat).Magnitude > 0.1 then
							self:placeAt(participant, pushed, spot)
						end
					end
				elseif participant.Team ~= team and (flat - spot).Magnitude < minDistance then
					local away = (flat - spot)
					local direction = if away.Magnitude > 0.1 then away.Unit else Vector3.new(-attackSide, 0, 0)
					local target = spot + direction * (minDistance + 0.5)
					target = Vector3.new(
						math.clamp(target.X, -dims.Length / 2 + 1, dims.Length / 2 - 1),
						0,
						math.clamp(target.Z, -dims.Width / 2 + 1, dims.Width / 2 - 1)
					)
					self:placeAt(participant, target, spot)
				end
			end
		end
	end

	local setupTime = if kind == "GoalThrow" then 0.6 else Config.Match.SetPieceSetupTime
	self.SetPiece = { Kind = kind, Team = team, Thrower = thrower, WhistleAt = now() + setupTime }
	self.Phase = "SetPiece"
	self.Ball:give(thrower, true)
	self:setPossession(team)
	self:event("SetPiece", {
		Kind = kind,
		Label = SET_PIECE_LABELS[kind] or kind,
		Team = team,
		Reason = reason,
		Thrower = thrower.Model,
	})
end

function Match:whistle()
	local setPiece: SetPiece? = self.SetPiece
	self.Phase = "Live"
	if setPiece then
		self.Ball.Locked = false
		self.Ball.HoldStart = now()
		self.Ball.CarryDistance = 0
		if setPiece.Kind == "GoalThrow" then
			self.SetPiece = nil
		end
	end
	self.ClockRunning = true
	self:event("Whistle", {})
	self.Ball:broadcast()
end

function Match:setPossession(team: string)
	if self.PossessionTeam ~= team then
		self.PossessionTeam = team
		self.PossessionStart = now()
		self.PassiveWarning = false
		self.LastPasser = nil
	end
end

function Match:startThrowOff(team: string)
	self.Phase = "ThrowOff"
	self.ClockRunning = false
	self.SetPiece = nil
	for _, wall in self.Walls do
		wall:Destroy()
	end
	table.clear(self.Walls)
	self:formation(true)
	local thrower = self:chooseThrower(team, Vector3.zero, false)
	if thrower then
		self:placeAt(thrower, Vector3.new(self:defendSideOf(team) * 1.5, 0, 0), Vector3.new(self:attackSideOf(team) * 10, 0, 0))
		self.Ball:give(thrower, true)
		self.SetPiece = { Kind = "ThrowOff", Team = team, Thrower = thrower, WhistleAt = now() + Config.Match.ThrowOffCountdown }
	end
	self:setPossession(team)
	self:event("ThrowOff", { Team = team, Countdown = Config.Match.ThrowOffCountdown })
	local myEpoch = self.Half
	task.delay(Config.Match.ThrowOffCountdown, function()
		if self.Finished or self.Half ~= myEpoch or self.Phase ~= "ThrowOff" then
			return
		end
		self.Phase = "SetPiece"
		self:whistle()
	end)
end

-- Fautes et violations ------------------------------------------------------------------------------

function Match:violation(offender: Participant, label: string, kind: string?, spotOverride: Vector3?)
	if self.Phase ~= "Live" then
		return
	end
	local spot = spotOverride or self:localOf(offender) or Vector3.zero
	self:event("Violation", { Label = label, Model = offender.Model, Team = offender.Team })
	self:awardSetPiece(kind or "FreeThrow", otherTeam(offender.Team), spot, label)
end

function Match:suspend(participant: Participant)
	participant.Suspensions += 1
	local red = participant.Suspensions >= Config.Rules.SuspensionsBeforeRed
	participant.Red = participant.Red or red
	if participant.Red then
		participant.Ultimate = 0
	end
	participant.SuspendedUntil = now() + (if red then Config.Rules.RedCardTime else Config.Rules.SuspensionTime)
	if self.Ball.Holder == participant then
		self.Ball:drop()
	end
	local bench = self.Court.BenchSpots[participant.Team]
	if bench then
		self:placeAt(participant, bench + Vector3.new(0, 0, 3), Vector3.zero)
	end
	self:event(if red then "RedCard" else "Suspension", {
		Model = participant.Model,
		Name = participant.Name,
		Team = participant.Team,
		Duration = participant.SuspendedUntil - now(),
	})
end

function Match:discipline(offender: Participant)
	offender.Fouls += 1
	local rules = Config.Rules
	if not offender.Yellow and offender.Fouls >= rules.FoulsBeforeYellow then
		offender.Yellow = true
		self:event("YellowCard", { Model = offender.Model, Name = offender.Name, Team = offender.Team })
	elseif offender.Yellow and offender.Fouls >= rules.FoulsBeforeSuspension + offender.Suspensions * 2 then
		self:suspend(offender)
	end
end

function Match:isClearChance(victim: Participant): boolean
	if self.Ball.Holder ~= victim then
		return false
	end
	local localPos = self:localOf(victim)
	if not localPos then
		return false
	end
	local dims: Court.Dimensions = self.Court.Dims
	local side = self:attackSideOf(victim.Team)
	return Court.distanceToGoal(dims, localPos, side) < dims.FreeThrowRadius + 3
end

function Match:commitFoul(offender: Participant, victim: Participant, label: string)
	local clearChance = self:isClearChance(victim)
	local spot = self:localOf(victim) or Vector3.zero
	self:discipline(offender)
	self:event("Foul", { Label = label, Offender = offender.Model, Victim = victim.Model, Team = offender.Team })
	if self.Phase ~= "Live" and self.Phase ~= "SetPiece" then
		return
	end
	self.Phase = "Live"
	self:awardSetPiece(if clearChance then "Penalty" else "FreeThrow", victim.Team, spot, label)
end

-- Événements du ballon ------------------------------------------------------------------------------

function Match:inOwnZone(participant: Participant): boolean
	if participant.Poste == "Gardien" or not self:isGrounded(participant) then
		return false
	end
	local localPos = self:localOf(participant)
	return localPos ~= nil and Court.inGoalArea(self.Court.Dims, localPos, self:defendSideOf(participant.Team))
end

function Match:onCaught(participant: Participant, kind: string, from: Participant?, distance: number?)
	if self.SetPiece and self.SetPiece.Thrower ~= participant then
		self.SetPiece = nil
	end
	-- Défendre en posant le pied dans sa zone : jet de 7 mètres.
	if
		kind ~= "Catch"
		and from
		and from.Team ~= participant.Team
		and (self:inOwnZone(participant) or participant.ZoneTouchUntil > now())
	then
		self:event("Violation", { Label = "DÉFENSE DANS LA ZONE", Model = participant.Model, Team = participant.Team })
		self:awardSetPiece("Penalty", from.Team, Vector3.zero, "Défense dans la zone")
		return
	end
	if kind == "Catch" and from and from.Team == participant.Team then
		if (distance or 0) >= Config.Powers.MinPassDistanceForEnergy then
			self:gainEnergy(participant, "Catch")
			self:gainEnergy(from, "PassCompleted")
		end
		self.LastPasser = from
		self.LastPassTime = now()
	elseif kind == "Interception" then
		participant.Interceptions += 1
		self:gainEnergy(participant, "Interception")
		self:gainUltimate(participant, "Interception")
		self:event("Interception", { Model = participant.Model, Team = participant.Team })
	elseif kind == "Steal" then
		self:gainEnergy(participant, "Steal")
		self:event("Steal", { Model = participant.Model, Team = participant.Team })
	end
	local previousTeam = self.PossessionTeam
	self:setPossession(participant.Team)
	if previousTeam ~= participant.Team then
		self.LastPasser = nil
	end
end

function Match:onSave(keeper: Participant, shooter: Participant?, parried: boolean)
	keeper.Saves += 1
	self:gainEnergy(keeper, "Save")
	self:gainUltimate(keeper, "Save")
	if shooter then
		shooter.ShotsOnTarget += 1
		self:gainEnergy(shooter, "ShotOnTarget")
	end
	self:event("Save", { Model = keeper.Model, Team = keeper.Team, Parried = parried })
end

function Match:onBlock(blocker: Participant, shooter: Participant?)
	if shooter and shooter.Team ~= blocker.Team and self:inOwnZone(blocker) then
		self:event("Violation", { Label = "DÉFENSE DANS LA ZONE", Model = blocker.Model, Team = blocker.Team })
		self:awardSetPiece("Penalty", shooter.Team, Vector3.zero, "Défense dans la zone")
		return
	end
	self:gainEnergy(blocker, "Block")
	self:event("Block", { Model = blocker.Model, Team = blocker.Team })
end

function Match:onWallBlock(_wall: BasePart, ballObject: any)
	local thrower: Participant? = ballObject.Thrower
	self:event("WallBlock", { Position = ballObject.Position, Team = if thrower then otherTeam(thrower.Team) else nil })
end

function Match:onGoal(side: number, ballObject: any)
	if self.Phase ~= "Live" and self.Phase ~= "SetPiece" then
		return
	end
	local scoringTeam = if self.AttackSide.Rouge == side then "Rouge" else "Bleu"
	local thrower: Participant? = ballObject.Thrower
	local scorer = if thrower and thrower.Team == scoringTeam then thrower else nil
	local assist: Participant? = nil
	if scorer then
		scorer.Goals += 1
		scorer.ShotsOnTarget += 1
		self:gainEnergy(scorer, "Goal")
		self:gainUltimate(scorer, "Goal")
		local passer: Participant? = self.LastPasser
		if passer and passer ~= scorer and passer.Team == scoringTeam and now() - self.LastPassTime < 8 then
			passer.Assists += 1
			self:gainUltimate(passer, "Assist")
			assist = passer
		end
	end
	self.Score[scoringTeam] += 1
	self.Phase = "Goal"
	self.ClockRunning = false
	self.SetPiece = nil
	self.Ball:place(ballObject.Position)
	self:event("Goal", {
		Team = scoringTeam,
		Scorer = if scorer then scorer.Name else nil,
		ScorerModel = if scorer then scorer.Model else nil,
		Assist = if assist then assist.Name else nil,
		OwnGoal = scorer == nil,
		Score = table.clone(self.Score),
		Fire = ballObject.Mods ~= nil and ballObject.Mods.Fire,
	})
	self:broadcastState()
	local half = self.Half
	task.delay(Config.Match.GoalCelebrationTime, function()
		if self.Finished or self.Half ~= half or (self.Phase :: string) ~= "Goal" then
			return
		end
		if self.Half == 3 then
			self.Clock = 0 -- but en or : fin du match
			return
		end
		if self.Clock > 0 then
			self:startThrowOff(otherTeam(scoringTeam))
		end
	end)
end

function Match:onOut(kind: string, side: number, localPos: Vector3, ballObject: any)
	if self.Phase ~= "Live" and self.Phase ~= "SetPiece" then
		return
	end
	self.Phase = "Live"
	local last: Participant? = ballObject.LastTouch
	local lastTeam = if last then last.Team else (if math.random() < 0.5 then "Rouge" else "Bleu")
	if kind == "Sideline" then
		self:awardSetPiece("ThrowIn", otherTeam(lastTeam), localPos, "Sortie en touche")
		return
	end
	-- Ligne de but : qui défend ce but ?
	local defendingTeam = if self:defendSideOf("Rouge") == side then "Rouge" else "Bleu"
	if last and last.Team == defendingTeam and last.Poste ~= "Gardien" then
		self:awardSetPiece("Corner", otherTeam(defendingTeam), localPos, "Dévié par la défense")
	else
		self:awardSetPiece("GoalThrow", defendingTeam, localPos, "Sortie en but")
	end
end

-- Actions des joueurs ------------------------------------------------------------------------------

local function horizontal(vector: Vector3): Vector3
	local flat = Vector3.new(vector.X, 0, vector.Z)
	return if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
end

function Match:canThrow(participant: Participant): boolean
	local ball = self.Ball
	if ball.Holder ~= participant or ball.Locked then
		return false
	end
	if self.Phase ~= "Live" and self.Phase ~= "SetPiece" then
		return false
	end
	return self:canAct(participant)
end

function Match:afterRelease(participant: Participant)
	local setPiece: SetPiece? = self.SetPiece
	if setPiece and setPiece.Thrower == participant then
		self.SetPiece = nil
	end
	self.Phase = "Live"
end

function Match:pickPassTarget(participant: Participant, direction: Vector3): Participant?
	local root = participant.Root
	if not root then
		return nil
	end
	local flatDirection = horizontal(direction)
	local best: Participant? = nil
	local bestScore = math.huge
	for _, mate in self:teammatesOf(participant, false) do
		local mateRoot = mate.Root
		if mateRoot then
			local offset = mateRoot.Position - root.Position
			local distance = offset.Magnitude
			if distance > 2 and distance < 90 then
				local angle = math.deg(math.acos(math.clamp(horizontal(offset):Dot(flatDirection), -1, 1)))
				if angle < 70 then
					local score = angle + distance * 0.15
					if score < bestScore then
						best = mate
						bestScore = score
					end
				end
			end
		end
	end
	return best
end

function Match:actionPass(participant: Participant, direction: Vector3, hint: Participant?)
	if not self:canThrow(participant) then
		return
	end
	local origin = Ball.handPosition(participant)
	if not origin then
		return
	end
	local target = if hint and hint.Team == participant.Team and hint ~= participant and self:isActive(hint)
		then hint
		else self:pickPassTarget(participant, direction)
	local velocity: Vector3
	if target and target.Root then
		local targetRoot = target.Root
		local distance = (targetRoot.Position - origin).Magnitude
		local travel = math.clamp(distance / Config.Ball.PassSpeed, 0.22, 1.1)
		local lead = Vector3.new(targetRoot.AssemblyLinearVelocity.X, 0, targetRoot.AssemblyLinearVelocity.Z) * travel * 0.85
		local aim = targetRoot.Position + lead + Vector3.new(0, 1.2, 0)
		velocity = BallMath.solveLob(origin, aim, travel)
	else
		velocity = horizontal(direction) * Config.Ball.PassSpeed * 0.8 + Vector3.new(0, 10, 0)
	end
	self.Ball:release(origin, velocity, "Pass", nil, target)
	self:afterRelease(participant)
	self:event("Pass", { Model = participant.Model, Target = if target then target.Model else nil })
end

function Match:actionShoot(participant: Participant, direction: Vector3, charge: number)
	if not self:canThrow(participant) then
		return
	end
	local origin = Ball.handPosition(participant)
	if not origin then
		return
	end
	local mods = participant.ShotBuff
	if mods and mods.ExpiresAt < now() then
		mods = nil
	end
	participant.ShotBuff = nil
	local power = math.clamp(charge, 0, 1)
	local speed = Config.Ball.ShotMinSpeed + (Config.Ball.ShotMaxSpeed - Config.Ball.ShotMinSpeed) * power
	speed *= if mods then mods.SpeedMult else 1
	-- Léger relevé pour compenser la gravité « animé ».
	local aim = (direction + Vector3.new(0, 0.04, 0)).Unit
	local velocity = aim * speed
	self.Ball:release(origin, velocity, "Shot", mods, nil)

	local dims: Court.Dimensions = self.Court.Dims
	local side = self:attackSideOf(participant.Team)
	if mods and mods.Curve > 0 then
		local right = aim:Cross(Vector3.yAxis)
		if right.Magnitude > 0.01 then
			right = right.Unit
			local goalCenter = self.Court.CFrame:PointToWorldSpace(Vector3.new(side * dims.Length / 2, dims.GoalHeight / 2, 0))
			local sign = if right:Dot(goalCenter - origin) >= 0 then 1 else -1
			self.Ball.Accel = right * sign * 70 * mods.Curve
		end
	end
	if mods and mods.Homing then
		local keeper = self:keeperOf(otherTeam(participant.Team))
		local keeperZ = 0
		if keeper then
			local keeperLocal = self:localOf(keeper)
			keeperZ = if keeperLocal then keeperLocal.Z else 0
		end
		local cornerZ = (if keeperZ > 0 then -1 else 1) * (dims.GoalWidth / 2 - 1)
		self.Ball.HomingTarget = self.Court.CFrame:PointToWorldSpace(Vector3.new(side * (dims.Length / 2 + 1), dims.GoalHeight * 0.7, cornerZ))
	end
	self.Ball:broadcast()
	self:afterRelease(participant)
	self:event("Shot", {
		Model = participant.Model,
		Charge = power,
		Fire = mods ~= nil and mods.Fire,
		Powered = mods ~= nil,
		Team = participant.Team,
	})
end

function Match:actionDribble(participant: Participant)
	local ball = self.Ball
	if ball.Holder ~= participant or ball.Locked or self.Phase ~= "Live" or not self:canAct(participant) then
		return
	end
	if ball.Dribbling then
		ball.Dribbling = false
		ball.DribbleUsed = true
		ball.HoldStart = now()
		ball.CarryDistance = 0
		ball:broadcast()
		return
	end
	if ball.DribbleUsed then
		self:notify(participant, "Reprise de dribble interdite : passe ou tire !", "Danger")
		return
	end
	ball.Dribbling = true
	ball:broadcast()
end

function Match:actionJump(participant: Participant)
	local humanoid = participant.Humanoid
	if humanoid and self:canAct(participant) then
		humanoid.Jump = true
	end
end

function Match:actionDash(participant: Participant, direction: Vector3)
	if not self:canAct(participant) or now() < participant.NextDashAt then
		return
	end
	if self.Phase ~= "Live" and self.Phase ~= "SetPiece" then
		return
	end
	if self:isFrozen(participant) then
		return
	end
	participant.NextDashAt = now() + Config.Movement.DashCooldown - 0.15
	if participant.IsBot then
		Abilities.impulse(self, participant, horizontal(direction) * Config.Movement.DashSpeed, Config.Movement.DashDuration)
	end
	self:event("Dash", { Model = participant.Model })
end

function Match:actionContact(participant: Participant)
	if not self:canAct(participant) or self.Phase ~= "Live" then
		return
	end
	local t = now()
	local ball = self.Ball
	-- Ballon en l'air : posture d'interception.
	if ball.State == "Flight" then
		if t < participant.NextInterceptAt then
			return
		end
		participant.InterceptUntil = t + Config.Intercept.Duration
		participant.NextInterceptAt = t + Config.Intercept.Cooldown
		self:event("InterceptStance", { Model = participant.Model, Duration = Config.Intercept.Duration })
		return
	end
	if t < participant.NextContactAt then
		return
	end
	participant.NextContactAt = t + Config.Contact.Cooldown
	local root = participant.Root
	if not root then
		return
	end
	local facing = horizontal(root.CFrame.LookVector)
	local victim: Participant? = nil
	local bestDistance = Config.Contact.Range
	for _, opponent in self:opponentsOf(participant) do
		local opponentRoot = opponent.Root
		if opponentRoot then
			local offset = opponentRoot.Position - root.Position
			local distance = offset.Magnitude
			if distance <= bestDistance and horizontal(offset):Dot(facing) > 0.25 then
				victim = opponent
				bestDistance = distance
			end
		end
	end
	if not victim or not victim.Root then
		self:event("Whiff", { Model = participant.Model })
		return
	end
	local target = victim :: Participant
	local victimRoot = target.Root :: BasePart
	self:event("Contact", { From = participant.Model, To = target.Model })
	if self:hasEffect(target, "Unstoppable") then
		self:event("Popup", { Model = target.Model, Text = "INÉBRANLABLE !", Style = "Gold" })
		self:stun(participant, Config.Contact.SelfRecovery, nil)
		return
	end
	local toAttacker = horizontal(root.Position - victimRoot.Position)
	local victimFacing = horizontal(victimRoot.CFrame.LookVector)
	local fromBehind = victimFacing:Dot(toAttacker) < math.cos(math.rad(180 - Config.Contact.BehindAngle))
	local isCarrier = ball.Holder == target
	if not isCarrier or fromBehind then
		self:stun(target, Config.Contact.StunTime * 0.6, nil)
		self:commitFoul(participant, target, if fromBehind then "CHARGE DANS LE DOS" else "OBSTRUCTION")
		return
	end
	-- Contact réglementaire de face sur le porteur.
	local chance = if ball.Dribbling then Config.Contact.DribbleStealChance else Config.Contact.StealChance
	self:addEffect(target, "Stun", 1, Config.Contact.StunTime)
	if math.random() < chance then
		participant.Steals += 1
		ball:give(participant)
		self:onCaught(participant, "Steal", target)
		self:event("Popup", { Model = participant.Model, Text = "BALLON VOLÉ !", Style = "Gold" })
	else
		self:event("Popup", { Model = target.Model, Text = "TIENT BON !", Style = "Info" })
	end
	self:stun(participant, Config.Contact.SelfRecovery, nil)
end

function Match:actionPower(participant: Participant, slot: number)
	if not self:canAct(participant) or self.Phase ~= "Live" then
		return
	end
	local archetype = Archetypes.get(participant.ArchetypeId)
	local power = archetype and archetype.Powers[slot]
	if not archetype or not power then
		return
	end
	local t = now()
	if slot == 1 and t < participant.Power1ReadyAt then
		return
	elseif slot == 2 and participant.Energy < Config.Powers.EnergyMax then
		return
	elseif slot == 3 and (participant.Ultimate < Config.Powers.UltimateMax or participant.Red) then
		return
	end
	local ok, reason = Abilities.canExecute(self, participant, power)
	if not ok then
		self:notify(participant, reason or "Impossible maintenant.", "Danger")
		return
	end
	if slot == 1 then
		participant.Power1ReadyAt = t + Config.Powers.Power1Cooldown
	elseif slot == 2 then
		participant.Energy = 0
		self:gainUltimate(participant, "Power2Used")
	else
		participant.Ultimate = 0
	end
	self:event("Power", {
		Model = participant.Model,
		PowerId = power.Id,
		ArchetypeId = archetype.Id,
		Slot = slot,
		Team = participant.Team,
		Name = participant.Name,
	})
	Abilities.execute(self, participant, power)
	self:broadcastState()
end

-- Entrée réseau (déjà limitée en débit par le système Matches).
function Match:handleAction(player: Player, action: string, a: any, b: any)
	local participant = self.ByPlayer[player]
	if not participant then
		return
	end
	if action == "Pass" then
		if typeof(a) ~= "Vector3" then
			return
		end
		local hint: Participant? = nil
		if typeof(b) == "Instance" then
			for _, other in self.Participants do
				if other.Model == b then
					hint = other
				end
			end
		end
		self:actionPass(participant, a, hint)
	elseif action == "Shoot" then
		if typeof(a) ~= "Vector3" or typeof(b) ~= "number" then
			return
		end
		self:actionShoot(participant, a, b)
	elseif action == "Dribble" then
		self:actionDribble(participant)
	elseif action == "Contact" then
		self:actionContact(participant)
	elseif action == "Dash" then
		if typeof(a) ~= "Vector3" then
			return
		end
		self:actionDash(participant, a)
	elseif action == "Power" then
		if a == 1 or a == 2 or a == 3 then
			self:actionPower(participant, a)
		end
	end
end

-- Boucle principale -------------------------------------------------------------------------------------

function Match:checkHolderRules()
	local ball = self.Ball
	local holder: Participant? = ball.Holder
	if not holder or ball.Locked or self.Phase ~= "Live" then
		return
	end
	local t = now()
	local dims: Court.Dimensions = self.Court.Dims
	local localPos = self:localOf(holder)
	if not localPos then
		return
	end
	local grounded = self:isGrounded(holder)

	if not ball.Dribbling then
		if t - ball.HoldStart > Config.Rules.MaxHoldTime + 0.15 then
			self:violation(holder, "3 SECONDES")
			return
		end
		local root = holder.Root :: BasePart
		local last = ball.LastCarryPosition
		if grounded and last then
			local delta = Vector3.new(root.Position.X - last.X, 0, root.Position.Z - last.Z).Magnitude
			if delta < 10 then -- ignore les téléportations
				ball.CarryDistance += delta
			end
		end
		ball.LastCarryPosition = root.Position
		local setPiece: SetPiece? = self.SetPiece
		local isThrower = setPiece ~= nil and setPiece.Thrower == holder
		if ball.CarryDistance > Config.Rules.MaxCarryDistance and not isThrower then
			self:violation(holder, "MARCHER")
			return
		end
	else
		ball.LastCarryPosition = if holder.Root then holder.Root.Position else nil
	end

	if grounded then
		if holder.Poste == "Gardien" then
			local ownSide = self:defendSideOf(holder.Team)
			if not Court.inGoalArea(dims, localPos, ownSide) and Court.distanceToGoal(dims, localPos, ownSide) > dims.GoalAreaRadius + 1.5 then
				self:violation(holder, "GARDIEN HORS ZONE")
				return
			end
		else
			local attackSide = self:attackSideOf(holder.Team)
			if Court.inGoalArea(dims, localPos, attackSide) then
				self:event("Violation", { Label = "ZONE !", Model = holder.Model, Team = holder.Team })
				self:awardSetPiece("GoalThrow", otherTeam(holder.Team), localPos, "Pied dans la zone")
				return
			end
			if Court.inGoalArea(dims, localPos, -attackSide) then
				self:violation(holder, "RETOUR EN ZONE")
				return
			end
		end
	end

	-- Jeu passif.
	local possessionTime = t - self.PossessionStart
	if possessionTime > Config.Rules.PassivePlayWarning and not self.PassiveWarning then
		self.PassiveWarning = true
		self:event("PassiveWarning", { Team = holder.Team })
	elseif self.PassiveWarning and possessionTime > Config.Rules.PassivePlayWarning + Config.Rules.PassivePlayGrace then
		self:violation(holder, "JEU PASSIF")
	end
end

-- Les joueurs de champ ne peuvent pas stationner dans les zones.
function Match:enforceZones()
	local dims: Court.Dimensions = self.Court.Dims
	for _, participant in self.Participants do
		if participant.Poste ~= "Gardien" and self:isActive(participant) and self.Ball.Holder ~= participant then
			if self:isGrounded(participant) then
				local localPos = self:localOf(participant)
				if localPos then
					for _, side in { -1, 1 } do
						if Court.distanceToGoal(dims, localPos, side) < dims.GoalAreaRadius - 1 and math.abs(localPos.X) <= dims.Length / 2 then
							if side == self:defendSideOf(participant.Team) then
								participant.ZoneTouchUntil = now() + 0.5
							end
							local pushed = Court.pushOutside(dims, Vector3.new(localPos.X, 0, localPos.Z), side, dims.GoalAreaRadius + 0.6)
							local root = participant.Root :: BasePart
							local look = root.CFrame.LookVector
							local world = self.Court.CFrame:PointToWorldSpace(pushed + Vector3.new(0, localPos.Y, 0))
							;(participant.Model :: Model):PivotTo(CFrame.lookAt(world, world + Vector3.new(look.X, 0, look.Z)))
						end
					end
				end
			end
		end
	end
end

function Match:updateParticipants(dt: number)
	local t = now()
	for _, participant in self.Participants do
		-- Nettoyage des effets expirés.
		for i = #participant.Effects, 1, -1 do
			if participant.Effects[i].ExpiresAt <= t then
				table.remove(participant.Effects, i)
			end
		end
		-- Retour d'exclusion.
		if participant.SuspendedUntil > 0 and participant.SuspendedUntil <= t then
			participant.SuspendedUntil = 0
			local bench = self.Court.BenchSpots[participant.Team]
			if bench then
				self:placeAt(participant, Vector3.new(bench.X, 0, self.Court.Dims.Width / 2 - 2), Vector3.zero)
			end
			self:event("Return", { Model = participant.Model, Name = participant.Name })
		end
		-- Charge (pouvoir) : renverse les adversaires touchés.
		if participant.RamUntil > t and participant.Root then
			for _, opponent in self:opponentsOf(participant) do
				local opponentRoot = opponent.Root
				if opponentRoot and (opponentRoot.Position - participant.Root.Position).Magnitude < 4.5 and not self:isStunned(opponent) then
					if not self:hasEffect(opponent, "Unstoppable") then
						self:stun(opponent, 0.9, "PERCUTÉ !")
					end
				end
			end
		end
		if self.Phase == "Live" and self:isActive(participant) then
			participant.Ultimate = math.min(Config.Powers.UltimateMax, participant.Ultimate + Config.Powers.UltimatePassivePerSecond * dt)
		end
		self:applyMovement(participant)
		if participant.IsBot then
			Bots.think(self, participant)
		end
	end
end

function Match:update(dt: number)
	if self.Finished then
		return
	end
	local t = now()
	if self.ClockRunning and (self.Phase == "Live" or self.Phase == "SetPiece") then
		self.Clock = math.max(0, self.Clock - dt)
	end
	local setPiece: SetPiece? = self.SetPiece
	if self.Phase == "SetPiece" and setPiece and setPiece.Kind ~= "ThrowOff" and t >= setPiece.WhistleAt and self.Ball.Locked then
		self:whistle()
	end
	self:updateParticipants(dt)
	if self.Phase == "Live" or self.Phase == "SetPiece" then
		self.Ball:update(dt)
		self:checkHolderRules()
		self:enforceZones()
	end
	if os.clock() - self.LastSnapshot > 0.25 then
		self:broadcastState()
	end
	if os.clock() - self.LastScoreboard > 0.5 then
		self.LastScoreboard = os.clock()
		local board = self.Court.Scoreboard
		board.Home.Text = tostring(self.Score.Rouge)
		board.Away.Text = tostring(self.Score.Bleu)
		local seconds = math.ceil(self.Clock)
		board.Clock.Text = string.format("%d:%02d", seconds // 60, seconds % 60)
		board.Period.Text = if self.Half == 3 then "BUT EN OR" elseif self.Half == 2 then "2e MT" else "1re MT"
	end
end

function Match:snapshot(): any
	local participants = {}
	for _, p in self.Participants do
		table.insert(participants, {
			Id = p.Id,
			Name = p.Name,
			UserId = p.UserId,
			IsBot = p.IsBot,
			Team = p.Team,
			Poste = p.Poste,
			Archetype = p.ArchetypeId,
			Model = p.Model,
			Number = p.Number,
			Goals = p.Goals,
			Assists = p.Assists,
			Saves = p.Saves,
			YellowCard = p.Yellow,
			SuspendedUntil = p.SuspendedUntil,
			RedCard = p.Red,
			Energy = p.Energy,
			Ultimate = p.Ultimate,
			Power1ReadyAt = p.Power1ReadyAt,
			NextDashAt = p.NextDashAt,
			NextContactAt = p.NextContactAt,
			ShotBuff = p.ShotBuff ~= nil and p.ShotBuff.ExpiresAt > now(),
			Ready = p.Ready,
		})
	end
	return {
		Id = self.Config.Id,
		Mode = self.Config.Mode,
		Ranked = self.Config.Ranked,
		Training = self.Config.Training,
		Phase = self.Phase,
		Half = self.Half,
		Clock = self.Clock,
		ClockRunning = self.ClockRunning,
		ServerTime = now(),
		Score = table.clone(self.Score),
		AttackSide = table.clone(self.AttackSide),
		Possession = self.PossessionTeam,
		PassiveWarning = self.PassiveWarning,
		CourtCFrame = self.Court.CFrame,
		CourtMode = self.Config.Mode,
		Participants = participants,
		SetPiece = if self.SetPiece then self.SetPiece.Kind else nil,
		Message = self.Message,
	}
end

function Match:broadcastState()
	self.LastSnapshot = os.clock()
	self:fireAll("MatchState", self:snapshot())
end

-- Gestion des personnages des joueurs ----------------------------------------------------------

function Match:connectPlayer(participant: Participant)
	local player = participant.Player :: Player
	local character = player.Character
	if not character then
		player:LoadCharacterAsync()
		character = player.Character or player.CharacterAdded:Wait()
	end
	self:bindCharacter(participant, character :: Model)
	table.insert(
		self.Connections,
		player.CharacterAdded:Connect(function(newCharacter)
			if self.Finished then
				return
			end
			task.wait(0.2)
			self:bindCharacter(participant, newCharacter)
			local side = self:defendSideOf(participant.Team)
			local spot = if participant.Poste == "Gardien"
				then Court.keeperSpot(self.Court.Dims, side)
				else Vector3.new(side * self.Court.Dims.Length * 0.3, 0, 0)
			self:placeAt(participant, spot, Vector3.zero)
		end)
	)
end

function Match:onPlayerRemoving(player: Player)
	local participant = self.ByPlayer[player]
	if not participant then
		return
	end
	participant.Connected = false
	if self.Ball.Holder == participant then
		self.Ball:drop()
	end
	local index = table.find(self.Players, player)
	if index then
		table.remove(self.Players, index)
	end
	self:event("Left", { Name = participant.Name, Team = participant.Team })
	-- Plus aucun humain : le match s'arrête.
	if #self.Players == 0 then
		self.Finished = true
	end
end

function Match:humansIn(team: string): number
	local count = 0
	for _, participant in self.Participants do
		if participant.Team == team and not participant.IsBot and participant.Connected then
			count += 1
		end
	end
	return count
end

function Match:forfeitCheck(): string?
	if self.Config.Training then
		return nil
	end
	local rouge, bleu = self:humansIn("Rouge"), self:humansIn("Bleu")
	if rouge == 0 and bleu > 0 and #self.Config.Teams.Rouge > 0 then
		return "Bleu"
	elseif bleu == 0 and rouge > 0 and #self.Config.Teams.Bleu > 0 then
		return "Rouge"
	end
	return nil
end

-- Déroulement ------------------------------------------------------------------------------------------

function Match:waitPeriod(): boolean
	while not self.Finished do
		if self.Clock <= 0 and self.Phase ~= "Goal" then
			return true
		end
		local forfeit = self:forfeitCheck()
		if forfeit then
			self.ForfeitWinner = forfeit
			return false
		end
		if self.Half == 3 and self.Score.Rouge ~= self.Score.Bleu and self.Phase ~= "Goal" then
			return true
		end
		task.wait(0.1)
	end
	return false
end

function Match:run(): any
	self:setupPhase()
	if self.Finished then
		return self:results(nil)
	end

	for _, participant in self.Participants do
		if participant.IsBot then
			self:spawnBot(participant)
		elseif participant.Player and participant.Player.Parent == Players then
			self:connectPlayer(participant)
		else
			participant.Connected = false
		end
	end
	table.insert(
		self.Connections,
		RunService.Heartbeat:Connect(function(dt)
			local ok, err = pcall(self.update, self, dt)
			if not ok then
				warn(`[Match] {err}`)
			end
		end)
	)
	table.insert(
		self.Connections,
		Players.PlayerRemoving:Connect(function(player)
			self:onPlayerRemoving(player)
		end)
	)

	-- Présentation des équipes.
	self.Phase = "Intro"
	self:formation(true)
	self:broadcastState()
	self:event("Intro", { Mode = self.Config.Mode, Ranked = self.Config.Ranked, Training = self.Config.Training })
	task.wait(4)

	local firstTeam = if math.random() < 0.5 then "Rouge" else "Bleu"
	for half = 1, 2 do
		if self.Finished then
			break
		end
		self.Half = half
		self.Clock = self.ModeInfo.HalfDuration
		self:startThrowOff(if half == 1 then firstTeam else otherTeam(firstTeam))
		local completed = self:waitPeriod()
		if not completed then
			break
		end
		self.ClockRunning = false
		if half == 1 then
			self.Phase = "Halftime"
			self.Ball:hide()
			self:event("Halftime", { Score = table.clone(self.Score), Duration = Config.Match.HalftimeDuration })
			self:broadcastState()
			task.wait(Config.Match.HalftimeDuration)
			-- Changement de côté.
			self.AttackSide = { Rouge = -self.AttackSide.Rouge, Bleu = -self.AttackSide.Bleu }
			for _, participant in self.Participants do
				participant.Energy = math.min(participant.Energy, Config.Powers.EnergyMax)
			end
		end
	end

	if not self.Finished and not self.ForfeitWinner and not self.Config.Training and self.Score.Rouge == self.Score.Bleu then
		self.Half = 3
		self.Clock = Config.Match.GoldenGoalDuration
		self:event("GoldenGoal", { Duration = Config.Match.GoldenGoalDuration })
		self:startThrowOff(if math.random() < 0.5 then "Rouge" else "Bleu")
		self:waitPeriod()
	end

	local winner: string? = self.ForfeitWinner
	if not winner then
		if self.Score.Rouge > self.Score.Bleu then
			winner = "Rouge"
		elseif self.Score.Bleu > self.Score.Rouge then
			winner = "Bleu"
		end
	end
	return self:results(winner)
end

function Match:results(winner: string?): any
	self.Phase = "Ended"
	self.ClockRunning = false
	self.Ball:hide()
	-- Homme du match : buts, passes décisives, arrêts, interceptions.
	local mvp: Participant? = nil
	local bestScore = -1
	for _, p in self.Participants do
		local score = p.Goals * 3 + p.Assists * 2 + p.Saves * 2 + p.Interceptions + p.Steals
		if winner and p.Team == winner then
			score += 1
		end
		if score > bestScore then
			mvp = p
			bestScore = score
		end
	end
	local perPlayer: { [Player]: any } = {}
	local table_ = {}
	for _, p in self.Participants do
		table.insert(table_, {
			Name = p.Name,
			Team = p.Team,
			Poste = p.Poste,
			Archetype = p.ArchetypeId,
			Goals = p.Goals,
			Assists = p.Assists,
			Saves = p.Saves,
			Interceptions = p.Interceptions,
			MVP = p == mvp,
			IsBot = p.IsBot,
			UserId = p.UserId,
		})
		local player = p.Player
		if player and p.Connected then
			perPlayer[player] = {
				Outcome = if winner == nil then "Draw" elseif winner == p.Team then "Win" else "Loss",
				Goals = p.Goals,
				Assists = p.Assists,
				Saves = p.Saves,
				Interceptions = p.Interceptions + p.Steals,
				MVP = p == mvp,
				Ranked = self.Config.Ranked,
				Training = self.Config.Training,
			}
		end
	end
	self:broadcastState()
	return {
		Winner = winner,
		Score = table.clone(self.Score),
		MVP = if mvp then mvp.Name else nil,
		Table = table_,
		PerPlayer = perPlayer,
		Forfeit = self.ForfeitWinner ~= nil,
	}
end

function Match:destroy()
	self.Finished = true
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	table.clear(self.Connections)
	for _, participant in self.Participants do
		local model = participant.Model
		if model then
			model:SetAttribute("MatchId", nil)
			model:SetAttribute("Team", nil)
			model:SetAttribute("ParticipantId", nil)
		end
	end
	self.Court.Model:Destroy()
end

return Match
