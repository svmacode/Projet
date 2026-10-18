--!strict
-- Messages à l'écran : bulles façon manga (info, alerte, récompense),
-- invitations de groupe et de clan.

local Players = game:GetService("Players")

local Kit = require(script.Parent.Parent.UI.Kit)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors

local Notifications = {}

local STYLES = {
	Info = { Back = C.Paper, Text = C.Ink, Tag = "!" },
	Danger = { Back = C.Red, Text = C.Paper, Tag = "✖" },
	Gold = { Back = C.Yellow, Text = C.Ink, Tag = "★" },
	Level = { Back = C.Purple, Text = C.Paper, Tag = "▲" },
	Success = { Back = C.Green, Text = C.Ink, Tag = "✔" },
}

local toastList: Frame
local inviteList: Frame

function Notifications.toast(text: string, style: string?)
	local look = STYLES[style or "Info"] or STYLES.Info
	local face, container = Kit.panel({
		Size = UDim2.fromOffset(440, 64),
		Color = look.Back,
		Rotation = math.random(-15, 15) / 10,
		Parent = toastList,
		ZIndex = 50,
	})
	container.LayoutOrder = -math.floor(os.clock() * 100)
	local tag = Kit.new("Frame", {
		BackgroundColor3 = C.Ink,
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.fromOffset(10, 10),
		ZIndex = 51,
		Parent = face,
	})
	Kit.corner(tag, 44)
	Kit.text({ Text = look.Tag, Color = look.Back, Font = Theme.Fonts.Heavy, ZIndex = 52, Parent = tag })
	Kit.text({
		Text = text,
		Font = Theme.Fonts.Body,
		Color = look.Text,
		Size = UDim2.new(1, -74, 1, -12),
		Position = UDim2.fromOffset(64, 6),
		AlignX = Enum.TextXAlignment.Left,
		MaxSize = 22,
		ZIndex = 51,
		Parent = face,
	})
	Kit.pop(container, 0.5)
	task.delay(4.2, function()
		if container.Parent then
			Kit.tween(container, Theme.Tween.Slide, { Position = UDim2.fromOffset(500, 0) })
			task.wait(0.3)
			container:Destroy()
		end
	end)
	-- Pas plus de 5 bulles à la fois.
	local children = {}
	for _, child in toastList:GetChildren() do
		if child:IsA("Frame") then
			table.insert(children, child)
		end
	end
	if #children > 5 then
		table.sort(children, function(a, b)
			return a.LayoutOrder > b.LayoutOrder
		end)
		children[1]:Destroy()
	end
end

local function invite(title: string, body: string, onAccept: () -> (), onDecline: () -> ())
	local face, container = Kit.panel({
		Size = UDim2.fromOffset(420, 150),
		Color = C.Paper,
		Parent = inviteList,
		ZIndex = 60,
	})
	Kit.header(face, title, C.Blue)
	Kit.text({
		Text = body,
		Font = Theme.Fonts.Body,
		Size = UDim2.new(1, -30, 0, 40),
		Position = UDim2.fromOffset(15, 46),
		MaxSize = 22,
		ZIndex = 61,
		Parent = face,
	})
	local done = false
	local function close()
		done = true
		container:Destroy()
	end
	Kit.button({
		Text = "ACCEPTER",
		Color = C.Green,
		Size = UDim2.fromOffset(180, 44),
		Position = UDim2.fromOffset(16, 94),
		ZIndex = 62,
		Parent = face,
		OnClick = function()
			close()
			onAccept()
		end,
	})
	Kit.button({
		Text = "REFUSER",
		Color = C.Red,
		TextColor = C.Paper,
		Size = UDim2.fromOffset(180, 44),
		Position = UDim2.fromOffset(220, 94),
		ZIndex = 62,
		Parent = face,
		OnClick = function()
			close()
			onDecline()
		end,
	})
	Kit.pop(container, 0.4)
	task.delay(25, function()
		if not done and container.Parent then
			close()
		end
	end)
end

function Notifications.start()
	local gui = Kit.screen("Notifications", 90, Players.LocalPlayer:WaitForChild("PlayerGui"))
	local root = Kit.root(gui)
	toastList = Kit.new("Frame", {
		Name = "Bulles",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 110),
		Size = UDim2.fromOffset(460, 500),
		Parent = root,
	})
	Kit.list(toastList, 12, false, Enum.HorizontalAlignment.Right)
	inviteList = Kit.new("Frame", {
		Name = "Invitations",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 120),
		Size = UDim2.fromOffset(440, 400),
		Parent = root,
	})
	Kit.list(inviteList, 16, false, Enum.HorizontalAlignment.Center)

	State.Notify:Connect(function(text, style)
		Notifications.toast(text, style)
	end)
	State.PartyInvite:Connect(function(_fromUserId, fromName, partyId)
		invite("INVITATION", `{fromName} t'invite dans son groupe !`, function()
			State.request("PartyAction", "Accept", partyId)
		end, function()
			State.request("PartyAction", "Decline", partyId)
		end)
	end)
	State.ClanInvite:Connect(function(clanId, clanName, fromName)
		invite("CLAN", `{fromName} t'invite à rejoindre {clanName}`, function()
			State.request("ClanAction", "Accept", clanId)
		end, function()
			State.request("ClanAction", "Decline", clanId)
		end)
	end)
end

return Notifications
