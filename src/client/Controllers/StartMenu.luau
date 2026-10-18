--!strict
-- Écran titre : plan cinématique lent sur le quartier au coucher du soleil,
-- bandes noires, titre, bouton JOUER. Uniquement sur les serveurs lobby.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Parent.UI.Kit)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors

local StartMenu = {}

local BAR = 96

local function shadowedTitle(parent: Instance, text: string, color: Color3, y: number, order: number): Frame
	local holder =
		Kit.box({ Size = UDim2.fromOffset(900, 120), Position = UDim2.fromOffset(96, y), ZIndex = 5, Parent = parent })
	holder.LayoutOrder = order
	Kit.label({
		Text = text,
		Font = Theme.Fonts.DisplayItalic,
		TextSize = 128,
		Color = C.Background,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(6, 6),
		ZIndex = 5,
		Parent = holder,
	})
	Kit.label({
		Text = text,
		Font = Theme.Fonts.DisplayItalic,
		TextSize = 128,
		Color = color,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 6,
		Parent = holder,
	})
	return holder
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

	local top = Kit.new("Frame", {
		BackgroundColor3 = C.Black,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, BAR),
		Position = UDim2.fromOffset(0, -BAR),
		ZIndex = 4,
		Parent = root,
	})
	local bottom = Kit.new("Frame", {
		BackgroundColor3 = C.Black,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, BAR),
		Position = UDim2.fromScale(0, 1),
		ZIndex = 4,
		Parent = root,
	})
	Kit.tween(top, Theme.Motion.Slow, { Position = UDim2.new() })
	Kit.tween(bottom, Theme.Motion.Slow, { Position = UDim2.new(0, 0, 1, -BAR) })

	local first = shadowedTitle(root, "HANDBALL", C.White, 250, 1)
	local second = shadowedTitle(root, "LEGENDS", C.Accent, 360, 2)
	Kit.reveal(first, 0.3, 24)
	Kit.reveal(second, 0.45, 24)

	local subtitle = Kit.label({
		Text = "SAISON 1  ·  LYCÉE SEIRYŌ",
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.H3,
		Color = C.White,
		Position = UDim2.fromOffset(104, 500),
		Size = UDim2.fromOffset(600, 28),
		ZIndex = 6,
		Parent = root,
	})
	Kit.reveal(subtitle, 0.6)

	local play = Kit.button({
		Text = "JOUER",
		Variant = "Primary",
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.H2,
		Size = UDim2.fromOffset(260, 60),
		Position = UDim2.fromOffset(104, 560),
		ZIndex = 6,
		Parent = root,
	})
	Kit.reveal(play.Instance, 0.75)

	Kit.label({
		Text = `v{Config.Version}`,
		Font = Theme.Fonts.Semibold,
		TextSize = Theme.Text.Small,
		Color = C.TextFaint,
		AlignX = Enum.TextXAlignment.Right,
		Size = UDim2.fromOffset(300, BAR),
		Position = UDim2.new(1, -332, 0, 0),
		ZIndex = 5,
		Parent = bottom,
	})
	Kit.label({
		Text = "Appuie sur Entrée ou clique sur JOUER",
		Font = Theme.Fonts.Semibold,
		TextSize = Theme.Text.Small,
		Color = C.TextMuted,
		Size = UDim2.fromOffset(600, BAR),
		Position = UDim2.fromOffset(104, 0),
		ZIndex = 5,
		Parent = bottom,
	})

	local started = false
	local function begin()
		if started then
			return
		end
		started = true
		ContextActionService:UnbindAction("HL_Commencer")
		-- Les bandes se referment puis s'ouvrent sur le lobby.
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
