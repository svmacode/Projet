--!strict
-- Notifications : autocollants inclinés en haut de l'écran (couleur selon le
-- type), invitations (groupe, clan) qui glissent en bas à droite.

local Players = game:GetService("Players")

local Kit = require(script.Parent.Parent.UI.Kit)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors

local Notifications = {}

local ACCENTS = {
	Info = C.Cyan,
	Danger = C.Danger,
	Gold = C.Accent,
	Level = C.Pink,
	Success = C.Lime,
}

local toastColumn: Frame
local inviteColumn: Frame
local order = 0

-- Plaque inclinée posée sur une ombre dure, à l'intérieur d'un support
-- transparent (le support reste dans le UIListLayout, la plaque peut glisser).
local function stickerFace(parent: Instance, color: Color3, z: number): (Frame, Frame)
	local shadow = Kit.new("Frame", {
		Name = "Ombre",
		BackgroundColor3 = C.Ink,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(5, 5),
		Rotation = -2,
		ZIndex = z,
		Parent = parent,
	})
	local face = Kit.new("Frame", {
		Name = "Face",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Rotation = -2,
		ZIndex = z,
		Parent = parent,
	})
	Kit.border(face, C.Ink, 3)
	Kit.shade(face, 0.22)
	-- Liseré blanc à gauche.
	Kit.new("Frame", {
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 6, 1, 0),
		ZIndex = z,
		Parent = face,
	})
	return face, shadow
end

function Notifications.toast(text: string, style: string?)
	order += 1
	local color = ACCENTS[style or "Info"] or C.Cyan
	local holder = Kit.box({
		Name = "Toast",
		Size = UDim2.fromOffset(0, 52),
		AutoSize = Enum.AutomaticSize.X,
		Order = order,
		ZIndex = 80,
		Parent = toastColumn,
	})
	local inner = Kit.box({
		Size = UDim2.fromOffset(0, 52),
		AutoSize = Enum.AutomaticSize.X,
		Position = UDim2.fromOffset(0, -40),
		ZIndex = 80,
		Parent = holder,
	})
	stickerFace(inner, color, 80)
	local label = Kit.label({
		Text = string.upper(text),
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.H3,
		Color = Theme.onColor(color),
		Size = UDim2.fromOffset(0, 52),
		AutoSize = Enum.AutomaticSize.X,
		Rotation = -2,
		ZIndex = 82,
		Parent = inner,
	})
	if Theme.onColor(color) == C.White then
		Kit.ink(label, 2)
	end
	Kit.padding(label, 26, 0)
	local scale = Kit.new("UIScale", { Scale = 0.6, Parent = holder })
	Kit.tween(inner, Theme.Motion.Slam, { Position = UDim2.new() })
	Kit.tween(scale, Theme.Motion.Slam, { Scale = 1 })
	task.delay(3.4, function()
		if holder.Parent then
			Kit.tween(scale, Theme.Motion.Base, { Scale = 0 })
			task.wait(0.2)
			holder:Destroy()
		end
	end)
	local toasts = {}
	for _, child in toastColumn:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	if #toasts > 4 then
		table.sort(toasts, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		toasts[1]:Destroy()
	end
end

local function invite(title: string, body: string, color: Color3, onAccept: () -> (), onDecline: () -> ())
	local holder = Kit.box({ Size = UDim2.fromOffset(400, 168), ZIndex = 85, Parent = inviteColumn })
	local card = Kit.surface({
		Color = C.Surface,
		Size = UDim2.new(1, -10, 1, -10),
		Position = UDim2.fromOffset(440, 0),
		Radius = Theme.RadiusLarge,
		BorderThickness = 3,
		Shadow = true,
		ShadowColor = color,
		ShadowOffset = 6,
		ZIndex = 85,
		Parent = holder,
	})
	Kit.halftone({
		Parent = card,
		Color = color,
		Columns = 10,
		Rows = 5,
		Spacing = 14,
		Transparency = 0.75,
		Flip = true,
		Position = UDim2.new(1, -4, 0, 4),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = 85,
	})
	local plate = Kit.plate({
		Color = color,
		Size = UDim2.fromOffset(250, 30),
		Position = UDim2.fromOffset(14, -12),
		BorderThickness = 2.5,
		Shadow = false,
		ZIndex = 86,
		Parent = card,
	})
	Kit.label({
		Text = title,
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.Body,
		Color = Theme.onColor(color),
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 87,
		Parent = plate,
	})
	Kit.label({
		Text = body,
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.H3,
		Wrap = true,
		Position = UDim2.fromOffset(20, 32),
		Size = UDim2.new(1, -40, 0, 50),
		AlignY = Enum.TextYAlignment.Top,
		ZIndex = 86,
		Parent = card,
	})
	local done = false
	local function close()
		done = true
		holder:Destroy()
	end
	Kit.button({
		Text = "ACCEPTER",
		Variant = "Success",
		Font = Theme.Fonts.Display,
		Size = UDim2.fromOffset(170, 44),
		Position = UDim2.fromOffset(20, 96),
		ZIndex = 87,
		Parent = card,
		OnClick = function()
			close()
			onAccept()
		end,
	})
	Kit.button({
		Text = "REFUSER",
		Variant = "Ghost",
		Font = Theme.Fonts.Display,
		Size = UDim2.fromOffset(150, 44),
		Position = UDim2.fromOffset(206, 96),
		ZIndex = 87,
		Parent = card,
		OnClick = function()
			close()
			onDecline()
		end,
	})
	Kit.tween(card, Theme.Motion.Slam, { Position = UDim2.new() })
	task.delay(25, function()
		if not done and holder.Parent then
			close()
		end
	end)
end

function Notifications.start()
	local _, root = Kit.screen("Notifications", 90, Players.LocalPlayer:WaitForChild("PlayerGui"))
	toastColumn = Kit.box({
		Size = UDim2.fromOffset(800, 300),
		Position = UDim2.new(0.5, 0, 0, 88),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 80,
		Parent = root,
	})
	Kit.list(toastColumn, 8, false, Enum.HorizontalAlignment.Center)
	inviteColumn = Kit.box({
		Size = UDim2.fromOffset(400, 420),
		Position = UDim2.new(1, -32, 1, -150),
		AnchorPoint = Vector2.new(1, 1),
		ZIndex = 85,
		Parent = root,
	})
	Kit.list(inviteColumn, 12, false, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom)

	State.Notify:Connect(function(text, style)
		Notifications.toast(text, style)
	end)
	State.PartyInvite:Connect(function(_fromUserId, fromName, partyId)
		invite("INVITATION DE GROUPE", `{fromName} t'invite à le rejoindre`, C.Cyan, function()
			State.request("PartyAction", "Accept", partyId)
		end, function()
			State.request("PartyAction", "Decline", partyId)
		end)
	end)
	State.ClanInvite:Connect(function(clanId, clanName, fromName)
		invite("INVITATION DE CLAN", `{fromName} t'invite dans {clanName}`, C.Violet, function()
			State.request("ClanAction", "Accept", clanId)
		end, function()
			State.request("ClanAction", "Decline", clanId)
		end)
	end)
end

return Notifications
