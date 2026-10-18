--!strict
-- Messages courts (en haut au centre) et invitations (en bas à droite).

local Players = game:GetService("Players")

local Kit = require(script.Parent.Parent.UI.Kit)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors

local Notifications = {}

local STYLES: { [string]: Color3 } = {
	Info = C.Sky,
	Success = C.Success,
	Danger = C.Danger,
	Warning = C.Warning,
	Gold = C.Gold,
	Level = C.Accent,
}

local toastColumn: Frame
local inviteColumn: Frame
local order = 0
local MAX_TOASTS = 4

function Notifications.toast(text: string, style: string?)
	if not toastColumn then
		return
	end
	local color = STYLES[style or "Info"] or C.Sky
	order += 1
	local toasts = {}
	for _, child in toastColumn:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	if #toasts >= MAX_TOASTS then
		table.sort(toasts, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		toasts[1]:Destroy()
	end
	local holder = Kit.box({
		Size = UDim2.fromOffset(0, 50),
		AutoSize = Enum.AutomaticSize.X,
		Order = order,
		ZIndex = 80,
		Parent = toastColumn,
	})
	local toast = Kit.surface({
		Transparency = 0.02,
		BorderColor = C.White,
		BorderThickness = 2,
		Radius = 25,
		Size = UDim2.fromOffset(0, 46),
		AutoSize = Enum.AutomaticSize.X,
		ZIndex = 80,
		Parent = holder,
	})
	Kit.padding(toast, 18, 0)
	Kit.list(toast, 10, true, nil, Enum.VerticalAlignment.Center)
	local dot = Kit.new("Frame", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(12, 12),
		LayoutOrder = 1,
		ZIndex = 81,
		Parent = toast,
	})
	Kit.round(dot)
	Kit.label({
		Text = text,
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.Body,
		Color = C.Text,
		Size = UDim2.fromOffset(0, 46),
		AutoSize = Enum.AutomaticSize.X,
		Order = 2,
		ZIndex = 81,
		Parent = toast,
	})
	Kit.pop(holder, 0.6)
	task.delay(3.6, function()
		if holder.Parent then
			Kit.tween(
				holder:FindFirstChildOfClass("UIScale") :: UIScale,
				TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Scale = 0 }
			)
			task.wait(0.2)
			holder:Destroy()
		end
	end)
end

local function invite(title: string, body: string, color: Color3, onAccept: () -> (), onDecline: () -> ())
	order += 1
	local holder = Kit.box({
		Size = UDim2.fromOffset(380, 150),
		Order = -order,
		ZIndex = 85,
		Parent = inviteColumn,
	})
	local card = Kit.surface({
		Transparency = 0.02,
		BorderColor = C.White,
		BorderThickness = 3,
		Radius = Theme.RadiusLarge,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(420, 0),
		ZIndex = 85,
		Parent = holder,
	})
	local band = Kit.new("Frame", {
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 8, 1, -24),
		Position = UDim2.fromOffset(12, 12),
		ZIndex = 86,
		Parent = card,
	})
	Kit.round(band)
	Kit.gradient(band, Theme.lighten(color, 0.2), color, 90)
	Kit.label({
		Text = title,
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.Small,
		Color = color,
		Size = UDim2.new(1, -56, 0, 18),
		Position = UDim2.fromOffset(34, 16),
		ZIndex = 86,
		Parent = card,
	})
	Kit.label({
		Text = body,
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.Body,
		Color = C.Text,
		Wrap = true,
		AlignY = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, -56, 0, 44),
		Position = UDim2.fromOffset(34, 38),
		ZIndex = 86,
		Parent = card,
	})
	local done = false
	local function close()
		if done then
			return
		end
		done = true
		Kit.tween(card, Theme.Motion.Base, { Position = UDim2.fromOffset(420, 0) })
		task.delay(0.25, function()
			holder:Destroy()
		end)
	end
	Kit.button({
		Text = "Accepter",
		Variant = "Success",
		Size = UDim2.new(0.5, -28, 0, 42),
		Position = UDim2.new(0, 34, 1, -56),
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
		Size = UDim2.new(0.5, -28, 0, 42),
		Position = UDim2.new(0.5, 6, 1, -56),
		ZIndex = 87,
		Parent = card,
		OnClick = function()
			close()
			onDecline()
		end,
	})
	Kit.tween(card, Theme.Motion.Spring, { Position = UDim2.new() })
	task.delay(25, function()
		if holder.Parent then
			close()
		end
	end)
end

function Notifications.start()
	local _, root = Kit.screen("Notifications", 90, Players.LocalPlayer:WaitForChild("PlayerGui"))
	toastColumn = Kit.box({
		Size = UDim2.fromOffset(900, 260),
		Position = UDim2.new(0.5, 0, 0, 24),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 80,
		Parent = root,
	})
	Kit.list(toastColumn, 8, false, Enum.HorizontalAlignment.Center)
	inviteColumn = Kit.box({
		Size = UDim2.fromOffset(380, 420),
		Position = UDim2.new(1, -28, 1, -40),
		AnchorPoint = Vector2.new(1, 1),
		ZIndex = 85,
		Parent = root,
	})
	Kit.list(inviteColumn, 12, false, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom)

	State.Notify:Connect(function(text, style)
		Notifications.toast(text, style)
	end)
	State.PartyInvite:Connect(function(_fromUserId, fromName, partyId)
		invite("INVITATION DE GROUPE", `{fromName} t'invite dans son groupe`, C.Sky, function()
			State.request("PartyAction", "Accept", partyId)
		end, function()
			State.request("PartyAction", "Decline", partyId)
		end)
	end)
	State.ClanInvite:Connect(function(clanId, clanName, fromName)
		invite("INVITATION DE CLAN", `{fromName} t'invite dans le clan {clanName}`, Theme.Section.Clan, function()
			State.request("ClanAction", "Accept", clanId)
		end, function()
			State.request("ClanAction", "Decline", clanId)
		end)
	end)
end

return Notifications
