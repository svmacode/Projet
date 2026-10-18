--!strict
-- Commandes du match (PC, manette, mobile).
--
--   PC       : Clic gauche maintenu = tir au timing · E = passe · Shift = dash
--              F = interception / contact · 1 2 3 = pouvoirs
--              Ctrl = verrouiller / libérer la caméra
--   Manette  : R2 tir · X passe · B dash · Y contact · croix = pouvoirs
--   Mobile   : boutons à droite de l'écran (créés par MatchHUD)
--
-- Tir au timing (Shared/ShotTiming) : tant que TIR est maintenu, un curseur
-- fait des allers-retours sur la jauge ; on relâche dans la zone parfaite.
-- Le client envoie « ShotCharge » puis « ShotRelease » + direction visée ;
-- c'est le SERVEUR qui note le tir. Pendant la charge, l'attribut
-- « ShotChargeStart » (heure serveur) est posé sur le LocalPlayer pour le HUD.
--
-- Seul le dash est appliqué immédiatement en local pour la réactivité ; le
-- serveur valide son délai et contrôle la vitesse.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local ShotTiming = require(ReplicatedStorage.Shared.ShotTiming)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local State = require(script.Parent.State)

local LocalPlayer = Players.LocalPlayer

local MatchInput = {}

-- Position actuelle du curseur de timing (0..1) pendant une charge, sinon nil.
MatchInput.Charge = nil :: number?
MatchInput.CameraLocked = true
MatchInput.DashReadyAt = 0
MatchInput.ActionFeedback = Signal.new() :: Signal.Signal<string>
-- Note reçue du serveur pour MON dernier tir (« Perfect » | « Good » | « Weak »).
MatchInput.ShotGraded = Signal.new() :: Signal.Signal<string>

local actionRemote: RemoteEvent
local chargeStart: number? = nil -- heure serveur
local bound = false
local aimParams = RaycastParams.new()
aimParams.FilterType = Enum.RaycastFilterType.Exclude

local function myEntry(): any
	local match = State.Match
	if not match then
		return nil
	end
	for _, participant in match.Participants do
		if participant.UserId == LocalPlayer.UserId then
			return participant
		end
	end
	return nil
end

function MatchInput.me(): any
	return myEntry()
end

local function isHolding(): boolean
	local ball = State.Ball
	local mine = myEntry()
	return ball ~= nil and mine ~= nil and ball.State == "Held" and ball.HolderId == mine.Id
end

function MatchInput.isHolding(): boolean
	return isHolding()
end

function MatchInput.isCharging(): boolean
	return chargeStart ~= nil
end

local function character(): (Model?, Humanoid?, BasePart?)
	local char = LocalPlayer.Character
	if not char then
		return nil, nil, nil
	end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	return char, humanoid, if root and root:IsA("BasePart") then root else nil
end

-- Point visé par le centre de l'écran (les personnages et le ballon sont ignorés).
local function aimPoint(): Vector3
	local camera = Workspace.CurrentCamera :: Camera
	local viewport = camera.ViewportSize
	local ray = camera:ViewportPointToRay(viewport.X / 2, viewport.Y / 2)
	local ignore: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	local localBall = Workspace:FindFirstChild("BallonLocal")
	if localBall then
		table.insert(ignore, localBall)
	end
	aimParams.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 400, aimParams)
	return if hit then hit.Position else ray.Origin + ray.Direction * 400
end

local function handPosition(): Vector3?
	local _, _, root = character()
	if not root then
		return nil
	end
	return (root.CFrame * CFrame.new(1.35, 0.35, -0.95)).Position
end

local function aimDirection(): Vector3
	local hand = handPosition()
	local target = aimPoint()
	if hand then
		local direction = target - hand
		if direction.Magnitude > 0.1 then
			return direction.Unit
		end
	end
	return (Workspace.CurrentCamera :: Camera).CFrame.LookVector
end

function MatchInput.aimDirection(): Vector3
	return aimDirection()
end

local function send(action: string, a: any?, b: any?)
	actionRemote:FireServer(action, a, b)
end

-- Actions ---------------------------------------------------------------------------------------

local function canPlay(): boolean
	local match = State.Match
	return match ~= nil and (match.Phase == "Live" or match.Phase == "SetPiece") and myEntry() ~= nil
end

local function setCharge(start: number?)
	chargeStart = start
	LocalPlayer:SetAttribute("ShotChargeStart", start)
	if not start then
		MatchInput.Charge = nil
	end
end

local function startCharge()
	if chargeStart or not canPlay() or not isHolding() then
		return
	end
	setCharge(Workspace:GetServerTimeNow())
	send("ShotCharge")
	MatchInput.ActionFeedback:Fire("ShotCharge")
end

local function releaseCharge()
	if not chargeStart then
		return
	end
	setCharge(nil)
	if isHolding() then
		send("ShotRelease", aimDirection())
		MatchInput.ActionFeedback:Fire("Shoot")
	else
		send("ShotRelease", nil)
	end
end

local function pass()
	if not canPlay() or not isHolding() then
		return
	end
	if chargeStart then
		-- Une passe annule la charge de tir.
		setCharge(nil)
		send("ShotRelease", nil)
	end
	-- Coéquipier le plus proche du viseur.
	local camera = Workspace.CurrentCamera :: Camera
	local center = camera.ViewportSize / 2
	local mine = myEntry()
	local best: Model? = nil
	local bestDistance = 340
	if State.Match and mine then
		for _, participant in State.Match.Participants do
			local model = participant.Model
			if participant.Team == mine.Team and participant.Id ~= mine.Id and model and model.Parent then
				local root = model:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					local screen, onScreen = camera:WorldToViewportPoint(root.Position)
					if onScreen then
						local distance = (Vector2.new(screen.X, screen.Y) - center).Magnitude
						if distance < bestDistance then
							best = model
							bestDistance = distance
						end
					end
				end
			end
		end
	end
	send("Pass", aimDirection(), best)
	MatchInput.ActionFeedback:Fire("Pass")
end

local function applyImpulse(velocity: Vector3, duration: number)
	local _, _, root = character()
	if not root then
		return
	end
	if duration <= 0 then
		root.AssemblyLinearVelocity = velocity
		return
	end
	local attachment = root:FindFirstChild("ImpulsionLocale") :: Attachment?
	if not attachment then
		local created = Instance.new("Attachment")
		created.Name = "ImpulsionLocale"
		created.Parent = root
		attachment = created
	end
	local mover = Instance.new("LinearVelocity")
	mover.Attachment0 = attachment
	mover.MaxForce = 1e6
	mover.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	mover.VectorVelocity = velocity
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.Parent = root
	task.delay(duration, function()
		mover:Destroy()
	end)
end

local function dash()
	if not canPlay() then
		return
	end
	local _, humanoid, root = character()
	if not humanoid or not root or humanoid.WalkSpeed <= 0 then
		return
	end
	if os.clock() < MatchInput.DashReadyAt then
		return
	end
	MatchInput.DashReadyAt = os.clock() + Config.Movement.DashCooldown
	local direction = humanoid.MoveDirection
	if direction.Magnitude < 0.1 then
		local look = root.CFrame.LookVector
		direction = Vector3.new(look.X, 0, look.Z)
	end
	direction = Vector3.new(direction.X, 0, direction.Z).Unit
	-- Dash horizontal net : on conserve la vitesse verticale (dash en l'air possible).
	applyImpulse(
		direction * Config.Movement.DashSpeed + Vector3.new(0, math.max(0, root.AssemblyLinearVelocity.Y * 0.3), 0),
		Config.Movement.DashDuration
	)
	send("Dash", direction)
	MatchInput.ActionFeedback:Fire("Dash")
end

function MatchInput.perform(action: string)
	if action == "Shoot" then
		if chargeStart then
			releaseCharge()
		else
			startCharge()
		end
	elseif action == "ShootBegin" then
		startCharge()
	elseif action == "ShootEnd" then
		releaseCharge()
	elseif action == "Pass" then
		pass()
	elseif action == "Dash" then
		dash()
	elseif action == "Contact" then
		if canPlay() then
			send("Contact")
			MatchInput.ActionFeedback:Fire("Contact")
		end
	elseif action == "Power1" or action == "Power2" or action == "Power3" then
		if canPlay() then
			send("Power", tonumber(string.sub(action, 6)))
		end
	end
end

-- Liaisons clavier / manette ----------------------------------------------------------------------

local BINDINGS: { { Name: string, Inputs: { Enum.KeyCode | Enum.UserInputType } } } = {
	{ Name = "Pass", Inputs = { Enum.KeyCode.E, Enum.KeyCode.ButtonX } },
	{ Name = "Dash", Inputs = { Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonB } },
	{ Name = "Contact", Inputs = { Enum.KeyCode.F, Enum.KeyCode.ButtonY } },
	{ Name = "Power1", Inputs = { Enum.KeyCode.One, Enum.KeyCode.DPadLeft } },
	{ Name = "Power2", Inputs = { Enum.KeyCode.Two, Enum.KeyCode.DPadUp } },
	{ Name = "Power3", Inputs = { Enum.KeyCode.Three, Enum.KeyCode.DPadRight } },
}

local function bind()
	if bound then
		return
	end
	bound = true
	for _, binding in BINDINGS do
		ContextActionService:BindAction(`HL_{binding.Name}`, function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				MatchInput.perform(binding.Name)
			end
			return Enum.ContextActionResult.Sink
		end, false, table.unpack(binding.Inputs))
	end
	ContextActionService:BindAction("HL_Shoot", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			startCharge()
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			releaseCharge()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	ContextActionService:BindAction("HL_CameraLock", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			MatchInput.CameraLocked = not MatchInput.CameraLocked
			State.request("ProfileAction", "SetSetting", "CameraLock", MatchInput.CameraLocked)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl)
end

local function unbind()
	if not bound then
		return
	end
	bound = false
	for _, binding in BINDINGS do
		ContextActionService:UnbindAction(`HL_{binding.Name}`)
	end
	ContextActionService:UnbindAction("HL_Shoot")
	ContextActionService:UnbindAction("HL_CameraLock")
	setCharge(nil)
end

function MatchInput.start()
	actionRemote = Net.event("MatchAction")

	Net.event("MatchEvent").OnClientEvent:Connect(function(kind, data)
		if kind == "Impulse" and typeof(data) == "table" and typeof(data.Velocity) == "Vector3" then
			applyImpulse(data.Velocity, tonumber(data.Duration) or 0)
		elseif kind == "ShotGrade" and typeof(data) == "table" and data.UserId == LocalPlayer.UserId then
			if typeof(data.Grade) == "string" then
				MatchInput.ShotGraded:Fire(data.Grade)
			end
		end
	end)

	State.ProfileChanged:Connect(function(profile)
		if profile and profile.Settings and profile.Settings.CameraLock ~= nil then
			MatchInput.CameraLocked = profile.Settings.CameraLock
		end
	end)

	State.MatchChanged:Connect(function()
		if State.inMatch() and myEntry() then
			bind()
			pcall(function()
				StarterGui:SetCore("ResetButtonCallback", false)
			end)
		else
			unbind()
			pcall(function()
				StarterGui:SetCore("ResetButtonCallback", true)
			end)
		end
	end)

	-- Curseur de timing (lu par le HUD et les animations).
	RunService.RenderStepped:Connect(function()
		local start = chargeStart
		if not start then
			return
		end
		if not isHolding() then
			setCharge(nil)
			return
		end
		MatchInput.Charge = ShotTiming.phase(Workspace:GetServerTimeNow() - start)
	end)
end

return MatchInput
