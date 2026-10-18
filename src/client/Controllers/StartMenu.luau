--!strict
-- Écran titre façon générique d'animé : travelling lent sur le quartier au
-- coucher du soleil, plaques de couleur qui claquent, grand lettrage BD,
-- flash blanc, lignes de vitesse, bouton JOUER qui pulse.
-- Uniquement sur les serveurs lobby.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Parent.UI.Kit)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors

local StartMenu = {}

local BAR = 64

-- Boucle infinie aller-retour (pulsation, clignotement).
local function loop(instance: Instance, duration: number, goals: { [string]: any })
	TweenService
		:Create(instance, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), goals)
		:Play()
end

-- Plaque inclinée qui traverse l'écran puis se pose.
local function slidingPlate(root: Frame, color: Color3, y: number, height: number, width: number, delay: number): Frame
	local plate = Kit.new("Frame", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(width, height),
		Position = UDim2.new(0, -width - 200, 0, y),
		Rotation = -7,
		ZIndex = 3,
		Parent = root,
	})
	Kit.border(plate, C.Ink, 4)
	Kit.shade(plate, 0.25)
	task.delay(delay, function()
		Kit.tween(plate, Theme.Motion.Slow, { Position = UDim2.new(0, -60, 0, y) })
	end)
	return plate
end

function StartMenu.start()
	if not State.isLobby() then
		State.Started = true
		State.Began:Fire()
		return
	end
	local gui, root = Kit.screen("EcranTitre", 100, Players.LocalPlayer:WaitForChild("PlayerGui"))

	-- Plan de caméra : travelling lent entre deux points fournis par le serveur.
	local camera = Workspace.CurrentCamera :: Camera
	local startTime = os.clock()
	local cameraConnection = RunService.RenderStepped:Connect(function()
		local from = Workspace:GetAttribute("MenuCamera")
		local to = Workspace:GetAttribute("MenuCameraEnd")
		if typeof(from) ~= "CFrame" then
			return
		end
		camera.CameraType = Enum.CameraType.Scriptable
		local alpha = (math.sin((os.clock() - startTime) * 0.06 - math.pi / 2) + 1) / 2
		camera.CFrame = if typeof(to) == "CFrame" then from:Lerp(to, alpha) else from
		camera.FieldOfView = 55
	end)

	-- Voile indigo à gauche : le titre reste lisible sur la 3D.
	local wash = Kit.new("Frame", {
		BackgroundColor3 = C.Background,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0.75, 1),
		ZIndex = 1,
		Parent = root,
	})
	Kit.new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(0.55, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = wash,
	})
	Kit.speedLines({ Parent = root, Color = C.White, Count = 26, Transparency = 0.82, ZIndex = 2 })
	Kit.halftone({
		Parent = root,
		Color = C.Pink,
		Columns = 26,
		Rows = 12,
		Spacing = 18,
		Transparency = 0.7,
		Position = UDim2.new(0, 0, 1, -BAR),
		AnchorPoint = Vector2.new(0, 1),
		ZIndex = 2,
	})
	Kit.halftone({
		Parent = root,
		Color = C.Cyan,
		Columns = 18,
		Rows = 9,
		Spacing = 18,
		Transparency = 0.72,
		Flip = true,
		Position = UDim2.new(1, 0, 0, BAR),
		ZIndex = 2,
		AnchorPoint = Vector2.new(1, 0),
	})

	-- Plaques de couleur derrière le titre.
	slidingPlate(root, C.Pink, 300, 150, 1080, 0.15)
	slidingPlate(root, C.Cyan, 430, 120, 960, 0.25)
	slidingPlate(root, C.Violet, 545, 40, 760, 0.35)

	-- Bandes cinéma, liserés de couleur.
	local top = Kit.new("Frame", {
		BackgroundColor3 = C.Ink,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, BAR),
		Position = UDim2.fromOffset(0, -BAR),
		ZIndex = 8,
		Parent = root,
	})
	Kit.new("Frame", {
		BackgroundColor3 = C.Accent,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 4),
		Position = UDim2.new(0, 0, 1, 0),
		ZIndex = 8,
		Parent = top,
	})
	local bottom = Kit.new("Frame", {
		BackgroundColor3 = C.Ink,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, BAR),
		Position = UDim2.fromScale(0, 1),
		ZIndex = 8,
		Parent = root,
	})
	Kit.new("Frame", {
		BackgroundColor3 = C.Pink,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 4),
		Position = UDim2.fromOffset(0, -4),
		ZIndex = 8,
		Parent = bottom,
	})
	Kit.tween(top, Theme.Motion.Slow, { Position = UDim2.new() })
	Kit.tween(bottom, Theme.Motion.Slow, { Position = UDim2.new(0, 0, 1, -BAR) })

	-- Titre.
	local titleBox = Kit.box({
		Size = UDim2.fromOffset(1000, 330),
		Position = UDim2.fromOffset(90, 215),
		Rotation = -6,
		ZIndex = 5,
		Parent = root,
	})
	local first = Kit.title({
		Text = "HANDBALL",
		TextSize = 150,
		Color = C.White,
		ShadowColor = C.Ink,
		Offset = 8,
		Stroke = 5,
		Size = UDim2.fromOffset(1000, 160),
		ZIndex = 5,
		Parent = titleBox,
	})
	local second = Kit.title({
		Text = "LEGENDS",
		TextSize = 176,
		Color = C.Accent,
		ShadowColor = C.Pink,
		Offset = 9,
		Stroke = 6,
		Size = UDim2.fromOffset(1000, 180),
		Position = UDim2.fromOffset(60, 130),
		ZIndex = 6,
		Parent = titleBox,
	})
	first.Instance.Visible = false
	second.Instance.Visible = false

	-- Étiquette de saison.
	local season = Kit.plate({
		Color = C.Ink,
		Size = UDim2.fromOffset(420, 40),
		Position = UDim2.fromOffset(150, 560),
		BorderColor = C.Accent,
		ShadowColor = C.Pink,
		ShadowOffset = 4,
		Visible = false,
		ZIndex = 6,
		Parent = root,
	})
	Kit.label({
		Text = "SAISON 1  ·  LYCÉE SEIRYŌ",
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.H3 + 2,
		Color = C.Accent,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 7,
		Parent = season,
	})

	-- Bouton JOUER.
	local play = Kit.button({
		Text = "JOUER",
		Variant = "Primary",
		Font = Theme.Fonts.Hero,
		TextSize = 60,
		Size = UDim2.fromOffset(340, 88),
		Position = UDim2.fromOffset(150, 640),
		Rotation = -3,
		ZIndex = 7,
		Parent = root,
	})
	local playScale = Kit.new("UIScale", { Parent = play.Instance })
	play.Instance.Visible = false

	local hint = Kit.label({
		Text = "APPUIE SUR ENTRÉE",
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.H3,
		Color = C.White,
		Stroke = 2,
		Size = UDim2.fromOffset(400, BAR),
		Position = UDim2.fromOffset(96, 0),
		ZIndex = 9,
		Parent = bottom,
	})
	loop(hint, 0.6, { TextTransparency = 0.75 })

	local version = Kit.new("Frame", {
		BackgroundColor3 = C.Cyan,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(84, 26),
		Position = UDim2.new(1, -40, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Rotation = -3,
		ZIndex = 9,
		Parent = bottom,
	})
	Kit.corner(version, 4)
	Kit.border(version, C.White, 2)
	Kit.label({
		Text = `v{Config.Version}`,
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.Small,
		Color = C.TextOnAccent,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 10,
		Parent = version,
	})

	-- Flash blanc au moment où le titre claque.
	local flash = Kit.new("Frame", {
		BackgroundColor3 = C.White,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
		Parent = root,
	})

	task.delay(0.45, function()
		first.Instance.Visible = true
		Kit.slam(first.Instance, 2.6)
		task.wait(0.14)
		second.Instance.Visible = true
		Kit.slam(second.Instance, 3)
		task.wait(0.12)
		flash.BackgroundTransparency = 0.15
		Kit.tween(flash, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
		Kit.shake(titleBox, 10, 0.3)
		task.wait(0.2)
		season.Visible = true
		Kit.reveal(season, 0, 60)
		task.wait(0.15)
		play.Instance.Visible = true
		Kit.slam(play.Instance, 1.6)
		task.wait(0.4)
		if play.Instance.Parent then
			playScale.Scale = 1
			loop(playScale, 0.55, { Scale = 1.06 })
		end
	end)

	-- Le mot LEGENDS respire doucement.
	task.delay(1.6, function()
		if second.Instance.Parent then
			loop(second.Instance, 1.4, { Rotation = 1.5 })
		end
	end)

	local started = false
	local function begin()
		if started then
			return
		end
		started = true
		ContextActionService:UnbindAction("HL_Commencer")
		-- Flash, puis les bandes se referment et s'ouvrent sur le lobby.
		flash.BackgroundTransparency = 0.3
		Kit.tween(flash, Theme.Motion.Base, { BackgroundTransparency = 1 })
		Kit.tween(top, Theme.Motion.Base, { Size = UDim2.new(1, 0, 0.5, 0) })
		Kit.tween(bottom, Theme.Motion.Base, { Size = UDim2.new(1, 0, 0.5, 0), Position = UDim2.fromScale(0, 0.5) })
		task.wait(0.25)
		for _, child in root:GetChildren() do
			if child ~= top and child ~= bottom then
				child:Destroy()
			end
		end
		cameraConnection:Disconnect()
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
		State.Started = true
		State.Began:Fire()
		task.wait(0.1)
		Kit.tween(top, Theme.Motion.Slow, { Size = UDim2.new(1, 0, 0, 0) })
		Kit.tween(bottom, Theme.Motion.Slow, { Size = UDim2.new(1, 0, 0, 0), Position = UDim2.fromScale(0, 1) })
		task.wait(0.5)
		gui:Destroy()
	end
	play.Instance.Activated:Connect(function()
		task.spawn(begin)
	end)
	ContextActionService:BindAction("HL_Commencer", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			task.spawn(begin)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Return, Enum.KeyCode.ButtonA)
end

return StartMenu
