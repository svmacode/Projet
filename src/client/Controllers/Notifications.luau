--!strict
-- Notifications : messages courts en haut de l'écran, invitations (groupe,
-- clan) en bas à droite.

local Players = game:GetService("Players")

local Kit = require(script.Parent.Parent.UI.Kit)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors

local Notifications = {}

local ACCENTS = {
	Info = C.Info,
	Danger = C.Danger,
	Gold = C.Warning,
	Level = C.Accent,
	Success = C.Success,
}

local toastColumn: Frame
local inviteColumn: Frame
local order = 0

function Notifications.toast(text: string, style: string?)
	order += 1
	local toast = Kit.surface({
		Color = C.Surface,
		Size = UDim2.fromOffset(0, 48),
		AutoSize = Enum.AutomaticSize.X,
		Order = order,
		ZIndex = 80,
		Parent = toastColumn,
	})
	Kit.padding(toast, 18, 0)
	local row =
		Kit.box({ Size = UDim2.fromOffset(0, 48), AutoSize = Enum.AutomaticSize.X, ZIndex = 80, Parent = toast })
	Kit.list(row, 12, true, nil, Enum.VerticalAlignment.Center)
	local dot = Kit.new("Frame", {
		BackgroundColor3 = ACCENTS[style or "Info"] or C.Info,
		Size = UDim2.fromOffset(8, 8),
		LayoutOrder = 1,
		ZIndex = 81,
		Parent = row,
	})
	Kit.corner(dot, 4)
	Kit.label({
		Text = text,
		Font = Theme.Fonts.Semibold,
		TextSize = Theme.Text.Body,
		Size = UDim2.fromOffset(0, 48),
		AutoSize = Enum.AutomaticSize.X,
		Order = 2,
		ZIndex = 81,
		Parent = row,
	})
	Kit.reveal(toast, 0, -10)
	task.delay(3.6, function()
		if toast.Parent then
			toast:Destroy()
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

local function invite(title: string, body: string, onAccept: () -> (), onDecline: () -> ())
	local card = Kit.surface({
		Color = C.Surface,
		Size = UDim2.fromOffset(380, 148),
		Radius = Theme.RadiusLarge,
		ZIndex = 85,
		Parent = inviteColumn,
	})
	Kit.label({
		Text = title,
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.Small,
		Color = C.Accent,
		Position = UDim2.fromOffset(20, 16),
		Size = UDim2.new(1, -40, 0, 18),
		ZIndex = 86,
		Parent = card,
	})
	Kit.label({
		Text = body,
		Font = Theme.Fonts.Semibold,
		TextSize = Theme.Text.H3,
		Wrap = true,
		Position = UDim2.fromOffset(20, 38),
		Size = UDim2.new(1, -40, 0, 48),
		AlignY = Enum.TextYAlignment.Top,
		ZIndex = 86,
		Parent = card,
	})
	local done = false
	local function close()
		done = true
		card:Destroy()
	end
	Kit.button({
		Text = "Accepter",
		Variant = "Primary",
		Size = UDim2.fromOffset(160, 40),
		Position = UDim2.fromOffset(20, 92),
		ZIndex = 87,
		Parent = card,
		OnClick = function()
			close()
			onAccept()
		end,
	})
	Kit.button({
		Text = "Refuser",
		Variant = "Ghost",
		Size = UDim2.fromOffset(160, 40),
		Position = UDim2.fromOffset(196, 92),
		ZIndex = 87,
		Parent = card,
		OnClick = function()
			close()
			onDecline()
		end,
	})
	Kit.reveal(card)
	task.delay(25, function()
		if not done and card.Parent then
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
		Size = UDim2.fromOffset(380, 400),
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
		invite("INVITATION DE GROUPE", `{fromName} t'invite à le rejoindre`, function()
			State.request("PartyAction", "Accept", partyId)
		end, function()
			State.request("PartyAction", "Decline", partyId)
		end)
	end)
	State.ClanInvite:Connect(function(clanId, clanName, fromName)
		invite("INVITATION DE CLAN", `{fromName} t'invite dans {clanName}`, function()
			State.request("ClanAction", "Accept", clanId)
		end, function()
			State.request("ClanAction", "Decline", clanId)
		end)
	end)
end

return Notifications
