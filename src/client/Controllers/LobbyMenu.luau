--!strict
-- Menu principal du lobby (inspiré de Rivals) : boutons à gauche, profil en
-- haut à gauche, Hand Coins en haut à droite, groupe en bas à droite,
-- bannière de recherche en haut au centre.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PatchNotes = require(ReplicatedStorage.Shared.Data.PatchNotes)
local Progression = require(ReplicatedStorage.Shared.Data.Progression)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Kit = require(script.Parent.Parent.UI.Kit)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local ClanScreen = require(script.Parent.Parent.Screens.ClanScreen)
local LockerScreen = require(script.Parent.Parent.Screens.LockerScreen)
local SearchScreen = require(script.Parent.Parent.Screens.SearchScreen)
local ShopScreen = require(script.Parent.Parent.Screens.ShopScreen)
local TrainingScreen = require(script.Parent.Parent.Screens.TrainingScreen)
local TutorialScreen = require(script.Parent.Parent.Screens.TutorialScreen)
local UpdatesScreen = require(script.Parent.Parent.Screens.UpdatesScreen)

local C = Theme.Colors
local LocalPlayer = Players.LocalPlayer

local LobbyMenu = {}

type NavEntry = { Id: string, Label: string, Color: Color3, TextColor: Color3, Big: boolean? }

local NAV: { NavEntry } = {
	{ Id = "Search", Label = "RECHERCHE", Color = C.Yellow, TextColor = C.Ink, Big = true },
	{ Id = "Training", Label = "ENTRAÎNEMENT", Color = C.Blue, TextColor = C.Paper },
	{ Id = "Shop", Label = "BOUTIQUE", Color = C.Red, TextColor = C.Paper },
	{ Id = "Locker", Label = "CASIER", Color = C.Purple, TextColor = C.Paper },
	{ Id = "Clan", Label = "CLAN", Color = C.Green, TextColor = C.Ink },
	{ Id = "Tutorial", Label = "TUTORIEL", Color = C.Paper, TextColor = C.Ink },
	{ Id = "Updates", Label = "MISES À JOUR", Color = C.Paper, TextColor = C.Ink },
}

local gui: ScreenGui
local root: Frame
local screens: { [string]: any } = {}
local badges: { [string]: Frame } = {}

local function openScreen(id: string?)
	for key, screen in screens do
		if key ~= id then
			screen.Close()
		end
	end
	if id and screens[id] then
		screens[id].Open()
	end
	State.setScreen(id)
end

-- Profil (haut gauche) ---------------------------------------------------------------------------

local function buildProfile()
	local face, _ = Kit.panel({
		Name = "Profil",
		Size = UDim2.fromOffset(420, 120),
		Position = UDim2.fromOffset(24, 24),
		Color = C.Paper,
		ZIndex = 5,
		Parent = root,
	})
	local avatar = Kit.new("ImageLabel", {
		BackgroundColor3 = C.Yellow,
		Size = UDim2.fromOffset(92, 92),
		Position = UDim2.fromOffset(12, 12),
		Image = "",
		ZIndex = 6,
		Parent = face,
	})
	Kit.stroke(avatar, 3)
	task.spawn(function()
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(
				LocalPlayer.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size150x150
			)
		end)
		if ok then
			avatar.Image = image
		end
	end)
	Kit.text({
		Text = LocalPlayer.DisplayName,
		Size = UDim2.new(1, -220, 0, 40),
		Position = UDim2.fromOffset(116, 10),
		AlignX = Enum.TextXAlignment.Left,
		ZIndex = 6,
		Parent = face,
	})
	local levelBadge = Kit.new("Frame", {
		BackgroundColor3 = C.Red,
		Size = UDim2.fromOffset(80, 80),
		Position = UDim2.new(1, -92, 0, 10),
		Rotation = 8,
		ZIndex = 7,
		Parent = face,
	})
	Kit.stroke(levelBadge, 4)
	Kit.text({ Text = "NIV.", Color = C.Paper, Size = UDim2.new(1, 0, 0.35, 0), ZIndex = 8, Parent = levelBadge })
	local levelText = Kit.text({
		Text = "1",
		Color = C.Paper,
		Stroke = C.Ink,
		StrokeThickness = 3,
		Size = UDim2.new(1, 0, 0.65, 0),
		Position = UDim2.fromScale(0, 0.32),
		ZIndex = 8,
		Parent = levelBadge,
	})
	local _, setXP = Kit.progress(face, {
		Size = UDim2.new(1, -230, 0, 18),
		Position = UDim2.fromOffset(116, 56),
		Color = C.Yellow,
		ZIndex = 6,
		Animate = true,
	})
	local xpText = Kit.text({
		Text = "",
		Font = Theme.Fonts.Heavy,
		Color = C.Steel,
		Size = UDim2.new(1, -230, 0, 18),
		Position = UDim2.fromOffset(116, 80),
		AlignX = Enum.TextXAlignment.Left,
		ZIndex = 6,
		Parent = face,
	})
	local rankText = Kit.text({
		Text = "",
		Size = UDim2.new(1, -230, 0, 20),
		Position = UDim2.fromOffset(116, 98),
		AlignX = Enum.TextXAlignment.Left,
		ZIndex = 6,
		Parent = face,
	})

	-- Hand Coins et balles (haut droite).
	local wallet, _ = Kit.panel({
		Name = "Porte-monnaie",
		Size = UDim2.fromOffset(260, 64),
		Position = UDim2.new(1, -290, 0, 24),
		Color = C.Ink,
		ZIndex = 5,
		Parent = root,
	})
	Kit.coin(wallet, 48, UDim2.fromOffset(8, 8)).ZIndex = 6
	local coinsText = Kit.text({
		Text = "0",
		Color = C.Yellow,
		Size = UDim2.new(1, -76, 1, -14),
		Position = UDim2.fromOffset(66, 7),
		AlignX = Enum.TextXAlignment.Left,
		ZIndex = 6,
		Parent = wallet,
	})
	local ballsFace, ballsContainer = Kit.panel({
		Name = "Balles",
		Size = UDim2.fromOffset(160, 50),
		Position = UDim2.new(1, -190, 0, 102),
		Color = C.Paper,
		ZIndex = 5,
		Parent = root,
	})
	Kit.ball(ballsFace, 36, C.Yellow, C.Red, UDim2.fromOffset(8, 7)).ZIndex = 6
	local ballsText = Kit.text({
		Text = "× 0",
		Size = UDim2.new(1, -60, 1, -10),
		Position = UDim2.fromOffset(52, 5),
		AlignX = Enum.TextXAlignment.Left,
		ZIndex = 6,
		Parent = ballsFace,
	})
	local ballsHit = Kit.new(
		"TextButton",
		{ BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 9, Parent = ballsContainer }
	)
	ballsHit.Activated:Connect(function()
		openScreen("Shop")
	end)

	local function refresh(profile: any)
		if not profile then
			return
		end
		levelText.Text = tostring(profile.Level)
		local needed = Progression.xpForNextLevel(profile.Level)
		setXP(profile.XP / needed)
		xpText.Text = `{Format.number(profile.XP)} / {Format.number(needed)} XP`
		if profile.Level >= Config.RankedUnlockLevel then
			local rank = Progression.getRank(profile.RP)
			rankText.Text = `{string.upper(rank.Name)} {Progression.getDivision(profile.RP)} · {profile.RP} RP`
			rankText.TextColor3 = rank.Color
		else
			rankText.Text = `CLASSÉ AU NIVEAU {Config.RankedUnlockLevel}`
			rankText.TextColor3 = C.Steel
		end
		coinsText.Text = Format.number(profile.Coins)
		local balls = 0
		for _, count in profile.Balls do
			balls += count
		end
		ballsText.Text = `× {balls}`
		badges.Tutorial.Visible = not profile.TutorialDone
		local latest = PatchNotes[1]
		badges.Updates.Visible = latest ~= nil and profile.SeenPatch ~= latest.Version
		badges.Shop.Visible = balls > 0 or profile.CosmeticPacks > 0
	end
	State.ProfileChanged:Connect(refresh)
	refresh(State.Profile)
end

-- Navigation (gauche) ---------------------------------------------------------------------------------

local function buildNav()
	local column = Kit.new("Frame", {
		Name = "Navigation",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(360, 640),
		Position = UDim2.fromOffset(24, 180),
		ZIndex = 5,
		Parent = root,
	})
	Kit.list(column, 14)
	for index, entry in NAV do
		local button = Kit.button({
			Text = entry.Label,
			Color = entry.Color,
			TextColor = entry.TextColor,
			TextStroke = if entry.TextColor == C.Paper then C.Ink else nil,
			Size = UDim2.fromOffset(if entry.Big then 340 else 300, if entry.Big then 92 else 62),
			Rotation = if index % 2 == 0 then -1.5 else 1,
			Order = index,
			ZIndex = 6,
			ShadowOffset = if entry.Big then 8 else 5,
			Parent = column,
			OnClick = function()
				if State.ActiveScreen == entry.Id then
					openScreen(nil)
				else
					openScreen(entry.Id)
				end
			end,
		})
		local badge = Kit.new("Frame", {
			Name = "Pastille",
			BackgroundColor3 = C.Red,
			Size = UDim2.fromOffset(30, 30),
			Position = UDim2.new(1, -14, 0, -12),
			Visible = false,
			ZIndex = 9,
			Parent = button.Container,
		})
		Kit.corner(badge, 30)
		Kit.stroke(badge, 3)
		Kit.text({ Text = "!", Color = C.Paper, ZIndex = 10, Parent = badge })
		badges[entry.Id] = badge
	end
end

-- Groupe (bas droite) ------------------------------------------------------------------------------------

local function buildParty()
	local face, _ = Kit.panel({
		Name = "Groupe",
		Size = UDim2.fromOffset(380, 300),
		Position = UDim2.new(1, -404, 1, -324),
		Color = C.Paper,
		ZIndex = 5,
		Parent = root,
	})
	Kit.header(face, "GROUPE", C.Blue, "パーティー")
	local slots = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -24, 0, 190),
		Position = UDim2.fromOffset(12, 50),
		ZIndex = 6,
		Parent = face,
	})
	Kit.list(slots, 6)
	local actions = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -24, 0, 46),
		Position = UDim2.new(0, 12, 1, -56),
		ZIndex = 6,
		Parent = face,
	})
	Kit.list(actions, 10, true)
	local picker: Frame? = nil

	local function closePicker()
		if picker then
			picker:Destroy()
			picker = nil
		end
	end

	local function openPicker()
		closePicker()
		local panel, container = Kit.panel({
			Size = UDim2.fromOffset(360, 380),
			Position = UDim2.new(1, -404, 1, -720),
			Color = C.Paper,
			ZIndex = 30,
			Parent = root,
		})
		picker = container
		Kit.header(panel, "INVITER", C.Green)
		local list =
			Kit.scroll(panel, { Size = UDim2.new(1, -24, 1, -110), Position = UDim2.fromOffset(12, 52), ZIndex = 31 })
		Kit.list(list, 6)
		local count = 0
		local party = State.Party
		for _, other in Players:GetPlayers() do
			local alreadyIn = false
			if party then
				for _, member in party.Members do
					if member.UserId == other.UserId then
						alreadyIn = true
					end
				end
			end
			if other ~= LocalPlayer and not alreadyIn then
				count += 1
				Kit.button({
					Text = `{other.DisplayName}  ·  NIV. {other:GetAttribute("Level") or 1}`,
					Color = C.PaperDark,
					Size = UDim2.new(1, -14, 0, 44),
					Order = count,
					ZIndex = 32,
					Parent = list,
					OnClick = function()
						local ok = State.request("PartyAction", "Invite", other.UserId)
						if ok then
							State.Notify:Fire(`Invitation envoyée à {other.DisplayName}`, "Success")
						end
					end,
				})
			end
		end
		if count == 0 then
			Kit.text({
				Text = "Personne d'autre sur ce serveur pour le moment.",
				Font = Theme.Fonts.Body,
				Size = UDim2.new(1, 0, 0, 50),
				ZIndex = 32,
				Parent = list,
			})
		end
		Kit.button({
			Text = "FERMER",
			Color = C.Red,
			TextColor = C.Paper,
			Size = UDim2.new(1, -24, 0, 44),
			Position = UDim2.new(0, 12, 1, -54),
			ZIndex = 32,
			Parent = panel,
			OnClick = closePicker,
		})
		Kit.pop(container, 0.8)
	end

	local function render(party: any)
		Kit.clear(slots)
		Kit.clear(actions)
		local members = if party
			then party.Members
			else {
				{
					UserId = LocalPlayer.UserId,
					Name = LocalPlayer.DisplayName,
					Level = if State.Profile then State.Profile.Level else 1,
				},
			}
		local leaderId = if party then party.LeaderId else LocalPlayer.UserId
		local iAmLeader = leaderId == LocalPlayer.UserId
		for index = 1, Config.MaxPartySize do
			local member = members[index]
			local row = Kit.new("Frame", {
				BackgroundColor3 = if member
					then (if member.UserId == leaderId then C.Yellow else C.PaperDark)
					else C.Paper,
				Size = UDim2.new(1, 0, 0, 32),
				LayoutOrder = index,
				ZIndex = 7,
				Parent = slots,
			})
			Kit.stroke(row, 2)
			if member then
				Kit.text({
					Text = `{if member.UserId == leaderId then "♛ " else ""}{member.Name}`,
					Font = Theme.Fonts.Body,
					Size = UDim2.new(1, -110, 1, -6),
					Position = UDim2.fromOffset(10, 3),
					AlignX = Enum.TextXAlignment.Left,
					ZIndex = 8,
					Parent = row,
				})
				Kit.text({
					Text = `NIV. {member.Level}`,
					Size = UDim2.new(0, 60, 1, -6),
					Position = UDim2.new(1, -100, 0, 3),
					ZIndex = 8,
					Parent = row,
				})
				if iAmLeader and member.UserId ~= LocalPlayer.UserId then
					local kick = Kit.new("TextButton", {
						BackgroundColor3 = C.Red,
						Text = "✕",
						TextColor3 = C.Paper,
						Font = Theme.Fonts.Heavy,
						TextScaled = true,
						Size = UDim2.fromOffset(28, 24),
						Position = UDim2.new(1, -34, 0, 4),
						ZIndex = 9,
						Parent = row,
					})
					Kit.stroke(kick, 2)
					kick.Activated:Connect(function()
						State.request("PartyAction", "Kick", member.UserId)
					end)
				end
			else
				Kit.text({
					Text = "— place libre —",
					Font = Theme.Fonts.Body,
					Color = C.Steel,
					Size = UDim2.new(1, -20, 1, -8),
					Position = UDim2.fromOffset(10, 4),
					ZIndex = 8,
					Parent = row,
				})
			end
		end
		if iAmLeader and #members < Config.MaxPartySize then
			Kit.button({
				Text = "+ INVITER",
				Color = C.Green,
				Size = UDim2.fromOffset(170, 44),
				Order = 1,
				ZIndex = 7,
				Parent = actions,
				OnClick = openPicker,
			})
		end
		if party then
			Kit.button({
				Text = "QUITTER",
				Color = C.Red,
				TextColor = C.Paper,
				Size = UDim2.fromOffset(170, 44),
				Order = 2,
				ZIndex = 7,
				Parent = actions,
				OnClick = function()
					State.request("PartyAction", "Leave")
				end,
			})
		end
	end
	State.PartyChanged:Connect(render)
	State.ProfileChanged:Connect(function()
		render(State.Party)
	end)
	render(State.Party)
end

-- Bannière de recherche (haut centre) ----------------------------------------------------------------

local function buildQueueBanner()
	local face, container = Kit.panel({
		Name = "Recherche",
		Size = UDim2.fromOffset(520, 76),
		Position = UDim2.new(0.5, 0, 0, 24),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = C.Yellow,
		Rotation = -1,
		ZIndex = 8,
		Parent = root,
	})
	container.Visible = false
	local label = Kit.text({
		Text = "",
		Size = UDim2.new(1, -190, 1, -14),
		Position = UDim2.fromOffset(16, 7),
		AlignX = Enum.TextXAlignment.Left,
		ZIndex = 9,
		Parent = face,
	})
	Kit.button({
		Text = "ANNULER",
		Color = C.Red,
		TextColor = C.Paper,
		Size = UDim2.fromOffset(150, 52),
		Position = UDim2.new(1, -164, 0, 12),
		ZIndex = 10,
		Parent = face,
		OnClick = function()
			State.request("QueueAction", "Cancel")
		end,
	})
	local dots = 0
	task.spawn(function()
		while true do
			task.wait(0.5)
			local queue = State.Queue
			if queue.State == "Searching" and queue.Since then
				dots = (dots + 1) % 4
				local mode = Config.Modes[queue.Mode or "3v3"]
				local elapsed = math.max(0, os.time() - queue.Since)
				label.Text =
					`RECHERCHE {if mode then mode.Label else ""}{if queue.Ranked then " CLASSÉ" else ""}{string.rep(
						".",
						dots
					)}  {Format.clock(elapsed)}`
			end
		end
	end)
	State.QueueChanged:Connect(function(queue)
		local visible = queue.State == "Searching"
		if visible and not container.Visible then
			Kit.pop(container, 0.6)
		end
		container.Visible = visible
	end)
end

function LobbyMenu.start()
	if not State.isLobby() then
		return
	end
	gui = Kit.screen("Lobby", 10, LocalPlayer:WaitForChild("PlayerGui"))
	gui.Enabled = false
	root = Kit.root(gui)

	local screenLayer = Kit.new(
		"Frame",
		{ Name = "Ecrans", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = root }
	)
	local function closeAll()
		openScreen(nil)
	end
	screens.Search = SearchScreen.create(screenLayer, closeAll)
	screens.Training = TrainingScreen.create(screenLayer, closeAll)
	screens.Shop = ShopScreen.create(screenLayer, closeAll)
	screens.Locker = LockerScreen.create(screenLayer, closeAll)
	screens.Clan = ClanScreen.create(screenLayer, closeAll)
	screens.Tutorial = TutorialScreen.create(screenLayer, closeAll)
	screens.Updates = UpdatesScreen.create(screenLayer, closeAll)

	buildNav()
	buildProfile()
	buildParty()
	buildQueueBanner()

	local function updateVisibility()
		gui.Enabled = State.Started and not State.inMatch() and State.Setup == nil
	end
	State.Began:Connect(function()
		updateVisibility()
		-- Premier lancement : proposer le tutoriel.
		local profile = State.Profile
		if profile and not profile.TutorialDone and profile.Stats.Matches == 0 then
			openScreen("Tutorial")
		end
	end)
	State.MatchChanged:Connect(function()
		if State.inMatch() then
			openScreen(nil)
		end
		updateVisibility()
	end)
	State.SetupChanged:Connect(function()
		openScreen(nil)
		updateVisibility()
	end)
	State.QueueChanged:Connect(function(queue)
		if queue.State == "Found" or queue.State == "Teleporting" then
			openScreen(nil)
		end
	end)
	State.MatchEvent:Connect(function(kind)
		if kind == "Leave" then
			State.Setup = nil
			updateVisibility()
		end
	end)
	updateVisibility()
end

return LobbyMenu
