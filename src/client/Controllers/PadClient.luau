--!strict
-- Bandeau des terrains du lobby : quand le joueur est sur une case, il voit
-- le terrain (mode, type), son équipe, le nombre de joueurs, le compte à
-- rebours et un bouton QUITTER. Le serveur décide de tout (PadState) ;
-- ce contrôleur ne fait qu'afficher et demander « Leave ».

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)
local Kit = require(script.Parent.Parent.UI.Kit)

local PadClient = {}

local rgb = Color3.fromRGB
local COLORS = {
	White = rgb(255, 255, 255),
	Navy = rgb(22, 30, 58),
	Muted = rgb(104, 114, 140),
	Orange = rgb(255, 122, 30),
	OrangeDark = rgb(222, 92, 10),
	Sky = rgb(64, 170, 255),
	Rouge = rgb(232, 64, 70),
	Bleu = rgb(48, 128, 238),
	Gold = rgb(255, 190, 60),
	Green = rgb(80, 196, 110),
}
local BLACK = Font.fromEnum(Enum.Font.GothamBlack)
local BOLD = Font.fromEnum(Enum.Font.GothamBold)

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number, contextual: boolean?)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = if contextual then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function gradient(parent: Instance, top: Color3, bottom: Color3)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(top, bottom)
	g.Rotation = 90
	g.Parent = parent
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = props.Font or BOLD
	l.TextSize = props.TextSize or 16
	l.TextColor3 = props.Color or COLORS.Navy
	l.Text = props.Text or ""
	l.TextXAlignment = props.AlignX or Enum.TextXAlignment.Left
	l.Size = props.Size
	l.Position = props.Position or UDim2.new()
	l.AnchorPoint = props.AnchorPoint or Vector2.zero
	l.ZIndex = props.ZIndex or 2
	l.Parent = parent
	if props.Stroke then
		stroke(l, props.StrokeColor or COLORS.Navy, props.Stroke, true)
	end
	return l
end

local KIND_TEXT = { Normal = "NORMAL", Ranked = "CLASSÉ", Training = "ENTRAÎNEMENT" } :: { [string]: string }
local KIND_COLOR = { Normal = COLORS.Orange, Ranked = COLORS.Gold, Training = COLORS.Green } :: { [string]: Color3 }

function PadClient.start()
	local player = Players.LocalPlayer
	local gui, root = Kit.screen("Terrain", 20, player:WaitForChild("PlayerGui"))
	gui.Enabled = false

	-- Bandeau ------------------------------------------------------------------------------
	local banner = Kit.new("Frame", {
		Name = "Bandeau",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -28),
		Size = UDim2.fromOffset(600, 96),
		BackgroundColor3 = COLORS.White,
		BorderSizePixel = 0,
		Parent = root,
	})
	corner(banner, 18)
	stroke(banner, COLORS.Navy, 3)
	gradient(banner, COLORS.White, rgb(228, 236, 248))
	local scale = Kit.new("UIScale", { Parent = banner })

	local strip = Kit.new("Frame", {
		Size = UDim2.new(0, 14, 1, -16),
		Position = UDim2.fromOffset(10, 8),
		BackgroundColor3 = COLORS.Rouge,
		BorderSizePixel = 0,
		Parent = banner,
	})
	corner(strip, 7)

	local kindPill = Kit.new("Frame", {
		Position = UDim2.fromOffset(38, 14),
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = COLORS.Orange,
		BorderSizePixel = 0,
		Parent = banner,
	})
	corner(kindPill, 12)
	stroke(kindPill, COLORS.Navy, 2)
	local kindPadding = Instance.new("UIPadding")
	kindPadding.PaddingLeft = UDim.new(0, 12)
	kindPadding.PaddingRight = UDim.new(0, 12)
	kindPadding.Parent = kindPill
	local kindLabel = label(kindPill, {
		Text = "NORMAL",
		Font = BLACK,
		TextSize = 13,
		Color = COLORS.White,
		Stroke = 1.5,
		Size = UDim2.fromScale(0, 1),
		AlignX = Enum.TextXAlignment.Center,
	})
	kindLabel.AutomaticSize = Enum.AutomaticSize.X

	local title = label(banner, {
		Text = "3 VS 3",
		Font = BLACK,
		TextSize = 30,
		Size = UDim2.fromOffset(260, 34),
		Position = UDim2.fromOffset(38, 42),
	})
	local detail = label(banner, {
		Text = "",
		TextSize = 15,
		Color = COLORS.Muted,
		Size = UDim2.fromOffset(300, 18),
		Position = UDim2.fromOffset(196, 52),
	})

	local status = label(banner, {
		Text = "",
		Font = BLACK,
		TextSize = 18,
		Color = COLORS.Orange,
		AlignX = Enum.TextXAlignment.Right,
		Size = UDim2.fromOffset(200, 24),
		Position = UDim2.new(1, -180, 0, 16),
		AnchorPoint = Vector2.new(1, 0),
	})

	-- Bouton QUITTER : face orange posée sur une ombre marine.
	local leave = Kit.new("TextButton", {
		Name = "Quitter",
		AutoButtonColor = false,
		Text = "",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -18, 0.5, 0),
		Size = UDim2.fromOffset(140, 52),
		BackgroundColor3 = COLORS.Navy,
		BorderSizePixel = 0,
		Parent = banner,
	})
	corner(leave, 14)
	local leaveFace = Kit.new("Frame", {
		Size = UDim2.new(1, 0, 1, -5),
		BackgroundColor3 = COLORS.Orange,
		BorderSizePixel = 0,
		Parent = leave,
	})
	corner(leaveFace, 14)
	stroke(leaveFace, COLORS.Navy, 2.5)
	gradient(leaveFace, rgb(255, 255, 255), rgb(226, 214, 206))
	label(leaveFace, {
		Text = "QUITTER",
		Font = BLACK,
		TextSize = 20,
		Color = COLORS.White,
		Stroke = 2,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
	})
	leave.MouseEnter:Connect(function()
		leaveFace.BackgroundColor3 = rgb(255, 146, 70)
	end)
	leave.MouseLeave:Connect(function()
		leaveFace.BackgroundColor3 = COLORS.Orange
		leaveFace.Position = UDim2.new()
	end)
	leave.MouseButton1Down:Connect(function()
		leaveFace.Position = UDim2.fromOffset(0, 4)
	end)
	leave.MouseButton1Up:Connect(function()
		leaveFace.Position = UDim2.new()
	end)
	local leaving = false
	leave.Activated:Connect(function()
		if leaving then
			return
		end
		leaving = true
		task.spawn(function()
			pcall(function()
				Net.func("PadAction"):InvokeServer("Leave")
			end)
			leaving = false
		end)
	end)

	-- Grand compte à rebours au centre ------------------------------------------------------
	local countdown = label(root, {
		Text = "",
		Font = BLACK,
		TextSize = 120,
		Color = COLORS.White,
		Stroke = 5,
		AlignX = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -150),
		Size = UDim2.fromOffset(400, 130),
	})
	countdown.Visible = false
	local countdownScale = Kit.new("UIScale", { Parent = countdown })

	-- État ------------------------------------------------------------------------------------
	local state: any = nil
	local shownSecond: number? = nil
	local loop: RBXScriptConnection? = nil

	local function stopLoop()
		if loop then
			loop:Disconnect()
			loop = nil
		end
	end

	local function tickCountdown()
		if not state or state.State ~= "Countdown" or typeof(state.EndsAt) ~= "number" then
			countdown.Visible = false
			shownSecond = nil
			stopLoop()
			return
		end
		local remaining = math.max(0, math.ceil(state.EndsAt - Workspace:GetServerTimeNow()))
		if remaining ~= shownSecond then
			shownSecond = remaining
			countdown.Visible = remaining > 0
			countdown.Text = tostring(remaining)
			countdown.TextColor3 = if remaining <= 2 then COLORS.Orange else COLORS.White
			countdownScale.Scale = 1.6
			TweenService
				:Create(
					countdownScale,
					TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{ Scale = 1 }
				)
				:Play()
			status.Text = `DÉPART DANS {remaining}`
		end
	end

	local function render()
		if not state then
			gui.Enabled = false
			countdown.Visible = false
			stopLoop()
			return
		end
		local wasHidden = not gui.Enabled
		gui.Enabled = true
		local kind = state.Kind or "Normal"
		kindLabel.Text = KIND_TEXT[kind] or "NORMAL"
		kindPill.BackgroundColor3 = KIND_COLOR[kind] or COLORS.Orange
		title.Text = state.Label or ""
		local teamColor = if state.Team == "Bleu" then COLORS.Bleu else COLORS.Rouge
		strip.BackgroundColor3 = teamColor
		local teamName = if state.Team == "Bleu" then "BLEU" else "ROUGE"
		detail.Text = `Équipe {teamName}  ·  {state.Players or 0} / {state.Capacity or 0} joueurs`
		detail.TextColor3 = COLORS.Muted
		leave.Visible = state.State ~= "Launching"
		if state.State == "Launching" then
			status.Text = "TÉLÉPORTATION…"
			status.TextColor3 = COLORS.Sky
			countdown.Visible = false
			stopLoop()
		elseif state.State == "Countdown" then
			status.TextColor3 = COLORS.Orange
			shownSecond = nil
			if not loop then
				loop = RunService.Heartbeat:Connect(tickCountdown)
			end
			tickCountdown()
		else
			status.Text = if kind == "Training" then "PRÊT" else "EN ATTENTE"
			status.TextColor3 = COLORS.Muted
			countdown.Visible = false
			stopLoop()
		end
		if wasHidden then
			scale.Scale = 0.85
			TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
		end
	end

	Net.event("PadState").OnClientEvent:Connect(function(snapshot)
		state = if type(snapshot) == "table" then snapshot else nil
		render()
	end)
end

return PadClient
