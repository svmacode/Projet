--!strict
-- Écran de chargement court (2 à 3 s) : fond orange → jaune, titre, barre
-- de progression, puis fondu vers le lobby. Pendant ce temps la caméra fait
-- un travelling sur le lycée (attributs MenuCamera / MenuCameraEnd).
-- Sur un serveur de match, on passe directement au jeu.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Parent.UI.Kit)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors
local LocalPlayer = Players.LocalPlayer

local LoadingScreen = {}

local MIN_TIME = 2.2
local MAX_TIME = 4

local function begin()
	State.Started = true
	State.Began:Fire()
end

local function travelling(): (() -> ())?
	local camera = Workspace.CurrentCamera
	local from = Workspace:GetAttribute("MenuCamera")
	local to = Workspace:GetAttribute("MenuCameraEnd")
	if not camera or typeof(from) ~= "CFrame" or typeof(to) ~= "CFrame" then
		return nil
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = from
	local value = Instance.new("CFrameValue")
	value.Value = from
	local connection = value.Changed:Connect(function(cframe)
		camera.CFrame = cframe
	end)
	Kit.tween(value, TweenInfo.new(MAX_TIME + 1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Value = to })
	return function()
		connection:Disconnect()
		value:Destroy()
		camera.CameraType = Enum.CameraType.Custom
		local character = LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end

function LoadingScreen.start()
	if not State.isLobby() then
		begin()
		return
	end
	local gui, root = Kit.screen("Chargement", 100, LocalPlayer:WaitForChild("PlayerGui"))
	local group = Kit.new("CanvasGroup", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 100,
		Parent = root,
	})
	local back = Kit.new("Frame", {
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 100,
		Parent = group,
	})
	Kit.gradient(back, Color3.fromRGB(255, 208, 92), Color3.fromRGB(255, 118, 34), 115)
	-- Grand ballon décoratif en fond, qui tourne lentement.
	local ball = Kit.icon("Ball", back, 760, nil, 100)
	ball.AnchorPoint = Vector2.new(0.5, 0.5)
	ball.Position = UDim2.new(1, -120, 1, 40)
	for _, object in ball:GetDescendants() do
		if object:IsA("Frame") then
			object.BackgroundTransparency = 0.82
		elseif object:IsA("UIStroke") then
			object.Transparency = 0.85
		end
	end
	Kit.tween(ball, TweenInfo.new(18, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), { Rotation = 360 })

	local center = Kit.box({
		Size = UDim2.fromOffset(900, 260),
		Position = UDim2.fromScale(0.5, 0.46),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 101,
		Parent = group,
	})
	local top = Kit.title({
		Text = "HANDBALL",
		TextSize = 104,
		StrokeColor = Color3.fromRGB(150, 56, 0),
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 110),
		ZIndex = 102,
		Parent = center,
	})
	local bottom = Kit.title({
		Text = "LEGENDS",
		TextSize = 72,
		Color = Color3.fromRGB(255, 244, 214),
		StrokeColor = Color3.fromRGB(150, 56, 0),
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 80),
		Position = UDim2.fromOffset(0, 104),
		ZIndex = 102,
		Parent = center,
	})
	Kit.slam(top.Instance, 1.3)
	task.delay(0.12, function()
		Kit.slam(bottom.Instance, 1.3)
	end)

	local bar, setProgress = Kit.progress({
		Size = UDim2.fromOffset(420, 14),
		Position = UDim2.new(0.5, 0, 1, -130),
		AnchorPoint = Vector2.new(0.5, 0),
		Back = Color3.fromRGB(190, 82, 10),
		Color = C.White,
		ZIndex = 102,
		Parent = group,
	})
	Kit.border(bar, C.White, 2)
	local status = Kit.label({
		Text = "Chargement du lycée…",
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.Body,
		Color = C.White,
		Stroke = 1.5,
		StrokeColor = Color3.fromRGB(150, 56, 0),
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(600, 24),
		Position = UDim2.new(0.5, 0, 1, -104),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 102,
		Parent = group,
	})
	Kit.label({
		Text = `v{Config.Version}`,
		Font = Theme.Fonts.Semibold,
		TextSize = Theme.Text.Small,
		Color = C.White,
		Transparency = 0.25,
		AlignX = Enum.TextXAlignment.Right,
		Size = UDim2.fromOffset(200, 20),
		Position = UDim2.new(1, -24, 1, -36),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = 102,
		Parent = group,
	})

	local stopCamera = travelling()
	local started = os.clock()
	local loaded = false
	task.spawn(function()
		if not game:IsLoaded() then
			game.Loaded:Wait()
		end
		pcall(function()
			ContentProvider:PreloadAsync({ root })
		end)
		if not LocalPlayer.Character then
			LocalPlayer.CharacterAdded:Wait()
		end
		loaded = true
	end)
	while true do
		local elapsed = os.clock() - started
		local ratio = math.clamp(elapsed / MIN_TIME, 0, if loaded then 1 else 0.9)
		setProgress(ratio)
		if (loaded and elapsed >= MIN_TIME) or elapsed >= MAX_TIME then
			break
		end
		task.wait()
	end
	setProgress(1)
	status.Text = "C'est parti !"
	task.wait(0.25)
	if stopCamera then
		stopCamera()
	end
	begin()
	Kit.tween(group, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { GroupTransparency = 1 })
	task.delay(0.5, function()
		gui:Destroy()
	end)
end

return LoadingScreen
