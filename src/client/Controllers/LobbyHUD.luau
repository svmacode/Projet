--!strict
-- HUD du lobby : pas de menu « Jouer » (on marche sur un terrain de la cour).
--   • en haut à droite : Hand Coins, niveau et XP ;
--   • à gauche : ARCHÉTYPES, CLAN, GROUPE, INFOS (gros boutons ronds) ;
--   • en bas : rappel « Marche sur un terrain pour jouer » la première fois.
-- Une seule fenêtre ouverte à la fois. Tout est caché pendant les matchs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Progression = require(ReplicatedStorage.Shared.Data.Progression)
local ArchetypesScreen = require(script.Parent.Parent.Screens.ArchetypesScreen)
local ClanScreen = require(script.Parent.Parent.Screens.ClanScreen)
local Kit = require(script.Parent.Parent.UI.Kit)
local Page = require(script.Parent.Parent.UI.Page)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Parent.UI.Theme)
local TutorialScreen = require(script.Parent.Parent.Screens.TutorialScreen)
local UpdatesScreen = require(script.Parent.Parent.Screens.UpdatesScreen)

local C = Theme.Colors
local LocalPlayer = Players.LocalPlayer

local LobbyHUD = {}

local gui: ScreenGui
local root: Frame
local pages: { [string]: Page.Page } = {}
local current: string? = nil
local infoButton: Kit.RoundButton
local groupButton: Kit.RoundButton

local function closeAll()
	for _, page in pages do
		page.Close()
	end
	current = nil
	State.setScreen(nil)
end

local function openPage(name: string)
	if current == name then
		closeAll()
		return
	end
	for key, page in pages do
		if key ~= name then
			page.Close()
		end
	end
	local page = pages[name]
	if page then
		current = name
		State.setScreen(name)
		page.Open()
	end
end

-- Profil (haut droite) -----------------------------------------------------------------------------

local function buildProfile()
	local card = Kit.surface({
		Transparency = 0.04,
		BorderColor = C.White,
		BorderThickness = 2.5,
		Radius = 20,
		Size = UDim2.fromOffset(340, 76),
		Position = UDim2.new(1, -24, 0, 20),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = 5,
		Parent = root,
	})
	local badge = Kit.new("Frame", {
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(56, 56),
		Position = UDim2.fromOffset(10, 10),
		ZIndex = 6,
		Parent = card,
	})
	Kit.round(badge)
	Kit.gradient(badge, C.AccentLight, C.Accent, 90)
	Kit.border(badge, C.White, 3)
	local level = Kit.label({
		Text = "1",
		Font = Theme.Fonts.Number,
		TextSize = 24,
		Color = C.White,
		Stroke = 1.5,
		StrokeColor = C.AccentDark,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 7,
		Parent = badge,
	})
	Kit.label({
		Text = LocalPlayer.DisplayName,
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.Body,
		Color = C.Text,
		Size = UDim2.new(1, -90, 0, 20),
		Position = UDim2.fromOffset(78, 12),
		ZIndex = 6,
		Parent = card,
	})
	local rank = Kit.label({
		Text = "",
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.Tiny,
		Color = C.TextMuted,
		Size = UDim2.new(1, -90, 0, 16),
		Position = UDim2.fromOffset(78, 32),
		ZIndex = 6,
		Parent = card,
	})
	local _, setXP = Kit.progress({
		Size = UDim2.new(1, -96, 0, 10),
		Position = UDim2.fromOffset(78, 54),
		Animate = true,
		ZIndex = 6,
		Parent = card,
	})

	local wallet = Kit.surface({
		Transparency = 0.04,
		BorderColor = C.White,
		BorderThickness = 2.5,
		Radius = 22,
		Size = UDim2.fromOffset(0, 46),
		AutoSize = Enum.AutomaticSize.X,
		Position = UDim2.new(1, -380, 0, 35),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = 5,
		Parent = root,
	})
	Kit.padding(wallet, 8, 0)
	Kit.list(wallet, 8, true, nil, Enum.VerticalAlignment.Center)
	local coin = Kit.icon("Coin", wallet, 32, nil, 6)
	coin.LayoutOrder = 1
	local coins = Kit.label({
		Text = "0",
		Font = Theme.Fonts.Number,
		TextSize = Theme.Text.H3,
		Color = C.Text,
		Size = UDim2.fromOffset(0, 46),
		AutoSize = Enum.AutomaticSize.X,
		Order = 2,
		ZIndex = 6,
		Parent = wallet,
	})
	Kit.box({ Size = UDim2.fromOffset(4, 4), Order = 3, Parent = wallet })

	local lastCoins: number? = nil
	local function refresh(profile: any)
		if not profile then
			return
		end
		level.Text = tostring(profile.Level)
		setXP(profile.XP / Progression.xpForNextLevel(profile.Level))
		if profile.Level >= Config.RankedUnlockLevel then
			local info = Progression.getRank(profile.RP)
			rank.Text = `{info.Name} {Progression.getDivision(profile.RP)}  ·  {profile.RP} RP`
			rank.TextColor3 = Theme.darken(info.Color, 0.2)
		else
			rank.Text = `Niveau {profile.Level}  ·  classé au niveau {Config.RankedUnlockLevel}`
			rank.TextColor3 = C.TextMuted
		end
		coins.Text = Format.number(profile.Coins)
		if lastCoins and lastCoins ~= profile.Coins then
			Kit.pop(wallet, if profile.Coins > lastCoins then 1.15 else 0.9)
		end
		lastCoins = profile.Coins
	end
	State.ProfileChanged:Connect(refresh)
	refresh(State.Profile)
end

-- Barre latérale ---------------------------------------------------------------------------------------

local function buildSidebar()
	local column = Kit.box({
		Size = UDim2.fromOffset(120, 480),
		Position = UDim2.new(0, 20, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		ZIndex = 5,
		Parent = root,
	})
	Kit.list(column, 6, false, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	Kit.roundButton({
		Text = "ARCHÉTYPES",
		Icon = "Cards",
		Color = C.Accent,
		Order = 1,
		ZIndex = 6,
		Parent = column,
		OnClick = function()
			openPage("Archetypes")
		end,
	})
	Kit.roundButton({
		Text = "CLAN",
		Icon = "Clan",
		Color = Theme.Section.Clan,
		Order = 2,
		ZIndex = 6,
		Parent = column,
		OnClick = function()
			openPage("Clan")
		end,
	})
	groupButton = Kit.roundButton({
		Text = "GROUPE",
		Icon = "Users",
		Color = C.Sky,
		Order = 3,
		ZIndex = 6,
		Parent = column,
		OnClick = function()
			openPage("Groupe")
		end,
	})
	infoButton = Kit.roundButton({
		Text = "INFOS",
		Icon = "Info",
		Color = C.Success,
		Order = 4,
		ZIndex = 6,
		Parent = column,
		OnClick = function()
			openPage("Infos")
		end,
	})
	local function refreshBadges()
		local profile = State.Profile
		infoButton.SetBadge(UpdatesScreen.hasUnread() or (profile ~= nil and profile.TutorialDone ~= true))
		groupButton.SetBadge(false)
	end
	State.ProfileChanged:Connect(refreshBadges)
	refreshBadges()
end

-- Fenêtre Groupe -------------------------------------------------------------------------------------------

local function avatar(parent: Instance, userId: number, size: number, ring: Color3, z: number): Frame
	local holder = Kit.new("Frame", {
		BackgroundColor3 = C.Surface3,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(size, size),
		ZIndex = z,
		Parent = parent,
	})
	Kit.round(holder)
	Kit.border(holder, ring, 3)
	local image = Kit.new("ImageLabel", {
		BackgroundTransparency = 1,
		Image = `rbxthumb://type=AvatarHeadShot&id={userId}&w=150&h=150`,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z + 1,
		Parent = holder,
	})
	Kit.round(image)
	return holder
end

local function buildGroupPage(layer: Instance): Page.Page
	local page = Page.modal(layer, "Groupe", Vector2.new(820, 620), closeAll, C.Sky)
	local content = page.Content
	local Z = 34
	local function render()
		Kit.clear(content)
		local party = State.Party
		local members = if party then party.Members else {}
		local leaderId = if party then party.LeaderId else LocalPlayer.UserId
		local iAmLeader = leaderId == LocalPlayer.UserId
		Kit.label({
			Text = `Ton groupe  ·  {math.max(1, #members)} / {Config.MaxPartySize}`,
			Font = Theme.Fonts.Display,
			TextSize = Theme.Text.H3,
			Color = C.Text,
			Size = UDim2.new(1, -200, 0, 40),
			ZIndex = Z,
			Parent = content,
		})
		Kit.label({
			Text = "Ton groupe entre ensemble sur un terrain et joue dans la même équipe.",
			Font = Theme.Fonts.Semibold,
			TextSize = Theme.Text.Small,
			Color = C.TextMuted,
			Size = UDim2.new(1, 0, 0, 20),
			Position = UDim2.fromOffset(0, 36),
			ZIndex = Z,
			Parent = content,
		})
		if party and #members > 1 then
			Kit.button({
				Text = "QUITTER",
				Variant = "Danger",
				Size = UDim2.fromOffset(150, 42),
				Position = UDim2.new(1, 0, 0, 0),
				AnchorPoint = Vector2.new(1, 0),
				ZIndex = Z,
				Parent = content,
				OnClick = function()
					State.request("PartyAction", "Leave")
				end,
			})
		end
		local slots = Kit.box({
			Size = UDim2.new(1, 0, 0, 150),
			Position = UDim2.fromOffset(0, 70),
			ZIndex = Z,
			Parent = content,
		})
		Kit.list(slots, 12, true)
		local list = if #members > 0
			then members
			else { { UserId = LocalPlayer.UserId, Name = LocalPlayer.DisplayName, Level = 1 } }
		for index = 1, Config.MaxPartySize do
			local member = list[index]
			local slot = Kit.surface({
				Color = if member then C.White else C.Surface2,
				BorderColor = if member and member.UserId == leaderId then C.Gold else C.Border,
				BorderThickness = 2,
				Radius = 16,
				Size = UDim2.fromOffset(140, 150),
				Order = index,
				ZIndex = Z,
				Parent = slots,
			})
			if member then
				local isLeader = member.UserId == leaderId
				local face = avatar(slot, member.UserId, 64, if isLeader then C.Gold else C.Sky, Z + 1)
				face.AnchorPoint = Vector2.new(0.5, 0)
				face.Position = UDim2.new(0.5, 0, 0, 14)
				Kit.label({
					Text = member.Name,
					Font = Theme.Fonts.Bold,
					TextSize = Theme.Text.Small,
					Color = C.Text,
					AlignX = Enum.TextXAlignment.Center,
					Size = UDim2.new(1, -12, 0, 18),
					Position = UDim2.fromOffset(6, 84),
					ZIndex = Z + 1,
					Parent = slot,
				})
				Kit.label({
					Text = if isLeader then "Chef" else `Niveau {member.Level}`,
					Font = Theme.Fonts.Semibold,
					TextSize = Theme.Text.Tiny,
					Color = if isLeader then Theme.darken(C.Gold, 0.25) else C.TextMuted,
					AlignX = Enum.TextXAlignment.Center,
					Size = UDim2.new(1, -12, 0, 16),
					Position = UDim2.fromOffset(6, 102),
					ZIndex = Z + 1,
					Parent = slot,
				})
				if iAmLeader and member.UserId ~= LocalPlayer.UserId then
					local kick = Kit.new("TextButton", {
						AutoButtonColor = false,
						BackgroundTransparency = 1,
						Text = "Exclure",
						FontFace = Theme.Fonts.Bold,
						TextSize = Theme.Text.Tiny,
						TextColor3 = C.Danger,
						Size = UDim2.new(1, 0, 0, 20),
						Position = UDim2.new(0, 0, 1, -24),
						ZIndex = Z + 1,
						Parent = slot,
					})
					kick.Activated:Connect(function()
						State.request("PartyAction", "Kick", member.UserId)
					end)
				end
			else
				local plus = Kit.icon("Plus", slot, 44, C.TextFaint, Z + 1)
				plus.AnchorPoint = Vector2.new(0.5, 0.5)
				plus.Position = UDim2.fromScale(0.5, 0.45)
				Kit.label({
					Text = "Libre",
					Font = Theme.Fonts.Semibold,
					TextSize = Theme.Text.Tiny,
					Color = C.TextFaint,
					AlignX = Enum.TextXAlignment.Center,
					Size = UDim2.new(1, 0, 0, 16),
					Position = UDim2.new(0, 0, 1, -30),
					ZIndex = Z + 1,
					Parent = slot,
				})
			end
		end

		Kit.label({
			Text = "INVITER DES JOUEURS DU SERVEUR",
			Font = Theme.Fonts.Display,
			TextSize = Theme.Text.Small,
			Color = C.TextMuted,
			Size = UDim2.new(1, 0, 0, 20),
			Position = UDim2.fromOffset(0, 240),
			ZIndex = Z,
			Parent = content,
		})
		local others = Kit.scroll({
			Size = UDim2.new(1, 0, 1, -270),
			Position = UDim2.fromOffset(0, 270),
			ZIndex = Z,
			Parent = content,
		})
		Kit.list(others, 8)
		local inParty: { [number]: boolean } = {}
		for _, member in members do
			inParty[member.UserId] = true
		end
		local count = 0
		for _, other in Players:GetPlayers() do
			if other ~= LocalPlayer and not inParty[other.UserId] then
				count += 1
				local row = Kit.surface({
					Color = C.Surface2,
					Border = false,
					Radius = 14,
					Size = UDim2.new(1, -10, 0, 56),
					Order = count,
					ZIndex = Z + 1,
					Parent = others,
				})
				local face = avatar(row, other.UserId, 40, C.White, Z + 2)
				face.Position = UDim2.fromOffset(10, 8)
				Kit.label({
					Text = other.DisplayName,
					Font = Theme.Fonts.Bold,
					Color = C.Text,
					Size = UDim2.new(1, -220, 1, 0),
					Position = UDim2.fromOffset(62, 0),
					ZIndex = Z + 2,
					Parent = row,
				})
				Kit.button({
					Text = "INVITER",
					Variant = "Secondary",
					TextSize = Theme.Text.Small,
					Size = UDim2.fromOffset(120, 40),
					Position = UDim2.new(1, -10, 0.5, 0),
					AnchorPoint = Vector2.new(1, 0.5),
					ZIndex = Z + 2,
					Parent = row,
					OnClick = function()
						if State.request("PartyAction", "Invite", other.UserId) then
							State.Notify:Fire(`Invitation envoyée à {other.DisplayName}`, "Success")
						end
					end,
				})
			end
		end
		if count == 0 then
			Kit.label({
				Text = "Personne d'autre sur ce serveur pour l'instant.",
				Font = Theme.Fonts.Semibold,
				Color = C.TextMuted,
				Size = UDim2.new(1, 0, 0, 40),
				ZIndex = Z + 1,
				Parent = others,
			})
		end
	end
	State.PartyChanged:Connect(function()
		if page.IsOpen() then
			render()
		end
	end)
	Players.PlayerAdded:Connect(function()
		if page.IsOpen() then
			render()
		end
	end)
	Players.PlayerRemoving:Connect(function()
		if page.IsOpen() then
			task.defer(render)
		end
	end)
	local baseOpen = page.Open
	page.Open = function()
		render()
		baseOpen()
	end
	return page
end

-- Fenêtre Infos (Tutoriel / Nouveautés) ---------------------------------------------------------------------

local function buildInfoPage(layer: Instance): Page.Page
	local page = Page.modal(layer, "Infos", Vector2.new(940, 660), closeAll, C.Success)
	local content = page.Content
	local Z = 34
	local tabs: { [string]: Frame } = {}
	for _, name in { "Tutoriel", "Nouveautés" } do
		tabs[name] = Kit.box({
			Size = UDim2.new(1, 0, 1, -60),
			Position = UDim2.fromOffset(0, 60),
			Visible = false,
			ZIndex = Z,
			Parent = content,
		})
	end
	TutorialScreen.build(tabs["Tutoriel"], Z)
	UpdatesScreen.build(tabs["Nouveautés"], Z)
	local select = Page.tabs(content, { "Tutoriel", "Nouveautés" }, function(name)
		for key, frame in tabs do
			frame.Visible = key == name
		end
		if name == "Nouveautés" then
			UpdatesScreen.markRead()
		end
	end, Z, C.Success)
	local baseOpen = page.Open
	page.Open = function()
		select(if UpdatesScreen.hasUnread() then "Nouveautés" else "Tutoriel")
		baseOpen()
	end
	return page
end

-- Rappel « Marche sur un terrain » --------------------------------------------------------------------------

local function buildHint()
	local hint = Kit.surface({
		Transparency = 0.04,
		BorderColor = C.White,
		BorderThickness = 2.5,
		Radius = 26,
		Size = UDim2.fromOffset(0, 52),
		AutoSize = Enum.AutomaticSize.X,
		Position = UDim2.new(0.5, 0, 1, -40),
		AnchorPoint = Vector2.new(0.5, 1),
		Visible = false,
		ZIndex = 5,
		Parent = root,
	})
	Kit.padding(hint, 20, 0)
	Kit.list(hint, 12, true, nil, Enum.VerticalAlignment.Center)
	local ball = Kit.icon("Ball", hint, 30, nil, 6)
	ball.LayoutOrder = 1
	Kit.tween(ball, TweenInfo.new(2.4, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), { Rotation = 360 })
	Kit.label({
		Text = "Marche sur un terrain de la cour pour lancer une partie",
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.H3,
		Color = C.Text,
		Size = UDim2.fromOffset(0, 52),
		AutoSize = Enum.AutomaticSize.X,
		Order = 2,
		ZIndex = 6,
		Parent = hint,
	})
	local dismissed = false
	local function dismiss()
		if dismissed then
			return
		end
		dismissed = true
		hint.Visible = false
	end
	State.PadChanged:Connect(function(pad)
		if pad ~= nil then
			dismiss()
		end
	end)
	local function maybeShow()
		local profile = State.Profile
		if dismissed or not State.Started or not profile then
			return
		end
		if profile.Stats and profile.Stats.Matches > 0 then
			dismiss()
			return
		end
		hint.Visible = true
		Kit.pop(hint, 0.7)
		task.delay(20, dismiss)
	end
	State.Began:Connect(maybeShow)
	State.ProfileChanged:Connect(function()
		if not hint.Visible then
			maybeShow()
		end
	end)
end

-- Démarrage ------------------------------------------------------------------------------------------------

function LobbyHUD.start()
	if not State.isLobby() then
		return
	end
	gui, root = Kit.screen("Lobby", 10, LocalPlayer:WaitForChild("PlayerGui"))
	gui.Enabled = false
	buildProfile()
	buildSidebar()
	buildHint()
	local layer = Kit.box({ Name = "Fenetres", ZIndex = 30, Parent = root })
	pages.Archetypes = ArchetypesScreen.create(layer, closeAll)
	pages.Clan = ClanScreen.create(layer, closeAll)
	pages.Groupe = buildGroupPage(layer)
	pages.Infos = buildInfoPage(layer)

	local function refreshVisibility()
		local visible = State.Started and not State.inMatch() and State.Setup == nil
		gui.Enabled = visible
		if not visible then
			closeAll()
		end
	end
	State.Began:Connect(refreshVisibility)
	State.MatchChanged:Connect(refreshVisibility)
	State.SetupChanged:Connect(refreshVisibility)
	State.MatchEvent:Connect(function(kind)
		if kind == "Leave" then
			refreshVisibility()
		end
	end)
	refreshVisibility()

	-- Échap ferme la fenêtre ouverte.
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			if current then
				closeAll()
			end
		end
	end)
end

return LobbyHUD
