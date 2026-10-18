--!strict
-- Menu de départ : page de titre façon couverture de manga (rayons, trame,
-- logo), puis bouton COMMENCER. Uniquement sur les serveurs lobby.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Parent.UI.Kit)
local Logo = require(script.Parent.Parent.UI.Logo)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors

local StartMenu = {}

local function setMenuCamera(active: boolean)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	if active then
		local cframe = Workspace:GetAttribute("MenuCamera")
		camera.CameraType = Enum.CameraType.Scriptable
		if typeof(cframe) == "CFrame" then
			camera.CFrame = cframe
		end
	else
		camera.CameraType = Enum.CameraType.Custom
	end
end

-- Transition « coups de pinceau » : bandes d'encre qui balaient l'écran.
local function wipe(root: Frame, onMiddle: () -> ())
	local strips = {}
	for i = 0, 5 do
		local strip = Kit.new("Frame", {
			BackgroundColor3 = if i % 2 == 0 then C.Ink else C.Red,
			BorderSizePixel = 0,
			Size = UDim2.new(1.6, 0, 0.2, 0),
			Position = UDim2.new(-1.7, 0, i * 0.18 - 0.05, 0),
			Rotation = -8,
			ZIndex = 200,
			Parent = root,
		})
		table.insert(strips, strip)
		task.delay(i * 0.04, function()
			Kit.tween(strip, Theme.Tween.Slide, { Position = UDim2.new(-0.3, 0, i * 0.18 - 0.05, 0) })
		end)
	end
	task.wait(0.55)
	onMiddle()
	for i, strip in strips do
		task.delay(i * 0.04, function()
			Kit.tween(strip, Theme.Tween.Slide, { Position = UDim2.new(1.2, 0, (i - 1) * 0.18 - 0.05, 0) })
		end)
	end
	task.delay(0.8, function()
		for _, strip in strips do
			strip:Destroy()
		end
	end)
end

function StartMenu.start()
	if not State.isLobby() then
		State.Started = true
		State.Began:Fire()
		return
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Kit.screen("MenuDepart", 100, playerGui)
	local root = Kit.root(gui)

	setMenuCamera(true)
	local cameraConnection = RunService.RenderStepped:Connect(function()
		setMenuCamera(true)
	end)

	local cover = Kit.new("Frame", {
		Name = "Couverture",
		BackgroundColor3 = C.Red,
		Size = UDim2.fromScale(1, 1),
		Parent = root,
	})
	Kit.sunburst(cover, C.Red, Theme.shade(C.Red, 0.12), 18, true)
	Kit.halftone(cover, C.RedDark, Vector2.new(0, 0), 9, 22)
	Kit.halftone(cover, C.RedDark, Vector2.new(1, 1), 9, 22)

	-- Cadre de case de manga.
	local frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -40, 1, -40),
		Position = UDim2.fromOffset(20, 20),
		ZIndex = 3,
		Parent = cover,
	})
	Kit.stroke(frame, 8)

	local logo = Logo.build(cover, UDim2.fromOffset(960, 440), UDim2.new(0.5, 0, 0.42, 0))
	logo.ZIndex = 5
	Kit.pop(logo, 0.3)

	local button = Kit.button({
		Text = "COMMENCER",
		Color = C.Yellow,
		Size = UDim2.fromOffset(420, 96),
		Position = UDim2.new(0.5, 0, 0.82, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = -2,
		ShadowOffset = 8,
		StrokeThickness = 5,
		ZIndex = 10,
	})
	button.Container.Parent = cover

	-- Pulsation du bouton.
	task.spawn(function()
		local scale = button.Container:FindFirstChildOfClass("UIScale") :: UIScale
		while button.Container.Parent do
			Kit.tween(scale, TweenInfo.new(0.6, Enum.EasingStyle.Sine), { Scale = 1.06 })
			task.wait(0.6)
			Kit.tween(scale, TweenInfo.new(0.6, Enum.EasingStyle.Sine), { Scale = 1 })
			task.wait(0.6)
		end
	end)

	Kit.text({
		Text = `v{Config.Version}  ·  Lycée Seiryō`,
		Font = Theme.Fonts.Body,
		Color = C.Paper,
		Size = UDim2.fromOffset(400, 26),
		Position = UDim2.new(0, 40, 1, -60),
		AlignX = Enum.TextXAlignment.Left,
		ZIndex = 5,
		Parent = cover,
	})

	local started = false
	local function begin()
		if started then
			return
		end
		started = true
		wipe(root, function()
			cover:Destroy()
			cameraConnection:Disconnect()
			setMenuCamera(false)
			State.Started = true
			State.Began:Fire()
		end)
		task.delay(1.2, function()
			gui:Destroy()
		end)
	end
	button.Face.Activated:Connect(begin)
end

return StartMenu
