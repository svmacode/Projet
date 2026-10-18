--!strict
-- Interface du lobby.
--   Barre du haut : JOUER · CASIER · BOUTIQUE · CLAN, Tutoriel, Nouveautés,
--                   Hand Coins, profil.
--   Accueil (JOUER) : le quartier 3D reste visible ; panneau de lancement en
--                   bas à gauche, groupe en bas à droite.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Court = require(ReplicatedStorage.Shared.Court)
local PatchNotes = require(ReplicatedStorage.Shared.Data.PatchNotes)
local Progression = require(ReplicatedStorage.Shared.Data.Progression)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Kit = require(script.Parent.Parent.UI.Kit)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local ClanScreen = require(script.Parent.Parent.Screens.ClanScreen)
local LockerScreen = require(script.Parent.Parent.Screens.LockerScreen)
local ShopScreen = require(script.Parent.Parent.Screens.ShopScreen)
local TutorialScreen = require(script.Parent.Parent.Screens.TutorialScreen)
local UpdatesScreen = require(script.Parent.Parent.Screens.UpdatesScreen)

local C = Theme.Colors
local LocalPlayer = Players.LocalPlayer

local LobbyMenu = {}

local gui: ScreenGui
local root: Frame
local pages: { [string]: any } = {}
local tabEntries: { [string]: { Label: TextLabel, Line: Frame } } = {}
local currentTab = "JOUER"
local home: Frame
local updatesDot: Frame
local tutorialDot: Frame
local shopDot: Frame

local function selectTab(name: string)
	currentTab = name
	for key, entry in tabEntries do
		local on = key == name
		entry.Label.TextColor3 = if on then C.Text else C.TextMuted
		entry.Line.Visible = on
	end
	for key, page in pages do
		if key == name then
			page.Open()
		elseif key ~= "TUTORIEL" and key ~= "NOUVEAUTÉS" then
			page.Close()
		end
	end
	home.Visible = name == "JOUER"
	State.setScreen(if name == "JOUER" then nil else name)
end

local function openModal(name: string)
	local page = pages[name]
	if page then
		page.Open()
		State.setScreen(name)
	end
end

local function closeModal(name: string)
	local page = pages[name]
	if page then
		page.Close()
	end
	State.setScreen(if currentTab == "JOUER" then nil else currentTab)
end

local function dot(parent: Instance): Frame
	local badge = Kit.new("Frame", {
		BackgroundColor3 = C.Danger,
		Size = UDim2.fromOffset(8, 8),
		Position = UDim2.new(1, -2, 0, 6),
		AnchorPoint = Vector2.new(1, 0),
		Visible = false,
		ZIndex = 25,
		Parent = parent,
	})
	Kit.corner(badge, 4)
	return badge
end

-- Barre du haut ------------------------------------------------------------------------------

local function buildTopBar()
	local bar = Kit.new("Frame", {
		Name = "Barre",
		BackgroundColor3 = C.Background,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 72),
		ZIndex = 20,
		Parent = root,
	})
	Kit.new("Frame", {
		BackgroundColor3 = C.Border,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, -1),
		ZIndex = 21,
		Parent = bar,
	})
	Kit.label({
		Text = `HANDBALL <font color="#{C.Accent:ToHex()}">LEGENDS</font>`,
		Rich = true,
		Font = Theme.Fonts.DisplayItalic,
		TextSize = 24,
		Size = UDim2.fromOffset(260, 72),
		Position = UDim2.fromOffset(40, 0),
		ZIndex = 21,
		Parent = bar,
	})

	local tabs =
		Kit.box({ Size = UDim2.fromOffset(600, 72), Position = UDim2.fromOffset(330, 0), ZIndex = 21, Parent = bar })
	Kit.list(tabs, 36, true, nil, Enum.VerticalAlignment.Center)
	for index, name in { "JOUER", "CASIER", "BOUTIQUE", "CLAN" } do
		local button = Kit.new("TextButton", {
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Text = "",
			Size = UDim2.fromOffset(0, 72),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = index,
			ZIndex = 21,
			Parent = tabs,
		})
		local label = Kit.label({
			Text = name,
			Font = Theme.Fonts.Bold,
			TextSize = Theme.Text.H3,
			Color = C.TextMuted,
			Size = UDim2.fromOffset(0, 72),
			AutoSize = Enum.AutomaticSize.X,
			ZIndex = 22,
			Parent = button,
		})
		local line = Kit.new("Frame", {
			BackgroundColor3 = C.Accent,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 3),
			Position = UDim2.new(0, 0, 1, -3),
			Visible = false,
			ZIndex = 22,
			Parent = button,
		})
		tabEntries[name] = { Label = label, Line = line }
		if name == "BOUTIQUE" then
			shopDot = dot(button)
		end
		button.MouseEnter:Connect(function()
			if currentTab ~= name then
				label.TextColor3 = C.Text
			end
		end)
		button.MouseLeave:Connect(function()
			if currentTab ~= name then
				label.TextColor3 = C.TextMuted
			end
		end)
		button.Activated:Connect(function()
			selectTab(name)
		end)
	end

	local right = Kit.box({
		Size = UDim2.fromOffset(760, 72),
		Position = UDim2.new(1, -40, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = 21,
		Parent = bar,
	})
	local layout = Kit.list(right, 12, true, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
	local _ = layout
	local tutorial = Kit.button({
		Text = "Tutoriel",
		Variant = "Ghost",
		AutoSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 40),
		Order = 1,
		ZIndex = 22,
		Parent = right,
		OnClick = function()
			openModal("TUTORIEL")
		end,
	})
	tutorialDot = dot(tutorial.Instance)
	local updates = Kit.button({
		Text = "Nouveautés",
		Variant = "Ghost",
		AutoSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 40),
		Order = 2,
		ZIndex = 22,
		Parent = right,
		OnClick = function()
			openModal("NOUVEAUTÉS")
		end,
	})
	updatesDot = dot(updates.Instance)

	-- Hand Coins.
	local coins = Kit.surface({
		Color = C.Surface2,
		Size = UDim2.fromOffset(0, 40),
		AutoSize = Enum.AutomaticSize.X,
		Order = 3,
		ZIndex = 22,
		Parent = right,
	})
	Kit.padding(coins, 14, 0)
	local coinRow =
		Kit.box({ Size = UDim2.fromOffset(0, 40), AutoSize = Enum.AutomaticSize.X, ZIndex = 22, Parent = coins })
	Kit.list(coinRow, 10, true, nil, Enum.VerticalAlignment.Center)
	local coinIcon = Kit.new("Frame", {
		BackgroundColor3 = C.Warning,
		Size = UDim2.fromOffset(16, 16),
		LayoutOrder = 1,
		ZIndex = 23,
		Parent = coinRow,
	})
	Kit.corner(coinIcon, 8)
	local coinText = Kit.label({
		Text = "0",
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.Body,
		Size = UDim2.fromOffset(0, 40),
		AutoSize = Enum.AutomaticSize.X,
		Order = 2,
		ZIndex = 23,
		Parent = coinRow,
	})

	-- Profil.
	local profile = Kit.surface({
		Color = C.Surface2,
		Size = UDim2.fromOffset(0, 40),
		AutoSize = Enum.AutomaticSize.X,
		Order = 4,
		ZIndex = 22,
		Parent = right,
	})
	Kit.padding(profile, 6, 0)
	local profileRow =
		Kit.box({ Size = UDim2.fromOffset(0, 40), AutoSize = Enum.AutomaticSize.X, ZIndex = 22, Parent = profile })
	Kit.list(profileRow, 10, true, nil, Enum.VerticalAlignment.Center)
	local levelBox = Kit.new("Frame", {
		BackgroundColor3 = C.Accent,
		Size = UDim2.fromOffset(30, 30),
		LayoutOrder = 1,
		ZIndex = 23,
		Parent = profileRow,
	})
	Kit.corner(levelBox, 6)
	local levelText = Kit.label({
		Text = "1",
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.Body,
		Color = C.TextOnAccent,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 24,
		Parent = levelBox,
	})
	local nameText = Kit.label({
		Text = LocalPlayer.DisplayName,
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.Body,
		Size = UDim2.fromOffset(0, 40),
		AutoSize = Enum.AutomaticSize.X,
		Order = 2,
		ZIndex = 23,
		Parent = profileRow,
	})
	local _2 = nameText
	Kit.box({ Size = UDim2.fromOffset(4, 40), Order = 3, Parent = profileRow })

	local function refresh(data: any)
		if not data then
			return
		end
		coinText.Text = Format.number(data.Coins)
		levelText.Text = tostring(data.Level)
		local balls = 0
		for _, count in data.Balls do
			balls += count
		end
		shopDot.Visible = balls > 0 or data.CosmeticPacks > 0
		tutorialDot.Visible = not data.TutorialDone
		local latest = PatchNotes[1]
		updatesDot.Visible = latest ~= nil and data.SeenPatch ~= latest.Version
	end
	State.ProfileChanged:Connect(refresh)
	refresh(State.Profile)
end

-- Panneau JOUER -----------------------------------------------------------------------------------

local function buildPlayPanel()
	local card = Kit.surface({
		Name = "Jouer",
		Color = C.Surface,
		Size = UDim2.fromOffset(460, 372),
		Position = UDim2.new(0, 40, 1, -40),
		AnchorPoint = Vector2.new(0, 1),
		Radius = Theme.RadiusLarge,
		ZIndex = 5,
		Parent = home,
	})
	local body =
		Kit.box({ Size = UDim2.new(1, -48, 1, -48), Position = UDim2.fromOffset(24, 24), ZIndex = 6, Parent = card })

	local kind = "Normal"
	local fillBots = true

	Kit.label({
		Text = "TYPE DE PARTIE",
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.Tiny,
		Color = C.TextFaint,
		Size = UDim2.new(1, 0, 0, 16),
		ZIndex = 6,
		Parent = body,
	})
	local kindSelector: Kit.Segmented
	local modeSelector: Kit.Segmented
	local info: TextLabel
	local botsButton: Kit.Button
	local launch: Kit.Button
	local cancel: Kit.Button
	local searchingLabel: TextLabel

	local function refresh()
		local profile = State.Profile
		local level = if profile then profile.Level else 1
		local rankedUnlocked = level >= Config.RankedUnlockLevel
		kindSelector.SetEnabled("Classe", rankedUnlocked)
		local mode = modeSelector.Value()
		local modeInfo = Config.Modes[mode]
		modeSelector.SetEnabled("2v2", kind ~= "Classe")
		if kind == "Classe" and mode == "2v2" then
			modeSelector.Select("3v3")
			mode = "3v3"
			modeInfo = Config.Modes[mode]
		end
		local party = State.Party
		local partySize = if party then #party.Members else 1
		local isLeader = party == nil or party.LeaderId == LocalPlayer.UserId
		local dims = Court.get(mode)
		local lines = {
			`{modeInfo.Label}  ·  2 × {Format.clock(modeInfo.HalfDuration)}  ·  terrain {dims.Length} × {dims.Width}`,
		}
		if kind == "Classe" and profile then
			local rank = Progression.getRank(profile.RP)
			table.insert(lines, `Rang : {rank.Name} {Progression.getDivision(profile.RP)}  ·  {profile.RP} RP`)
		elseif kind == "Entrainement" then
			table.insert(lines, "Partie amicale avec ton groupe, sans récompense.")
		elseif not rankedUnlocked then
			table.insert(lines, `Le classé se débloque au niveau {Config.RankedUnlockLevel}.`)
		end
		if partySize > modeInfo.TeamSize and kind ~= "Entrainement" then
			table.insert(lines, "Ton groupe est trop grand pour ce mode.")
		end
		info.Text = table.concat(lines, "\n")
		botsButton.Instance.Visible = kind == "Entrainement"
		botsButton.SetText(if fillBots then "Bots : activés" else "Bots : désactivés")
		local searching = State.Queue.State ~= "Idle"
		launch.Instance.Visible = not searching
		cancel.Instance.Visible = searching and State.Queue.State == "Searching"
		searchingLabel.Visible = searching
		launch.SetText(
			if not isLeader
				then "LE CHEF LANCE LA PARTIE"
				elseif kind == "Entrainement" then "LANCER L'ENTRAÎNEMENT"
				else "RECHERCHER"
		)
		launch.SetEnabled(isLeader and (kind == "Entrainement" or partySize <= modeInfo.TeamSize))
	end

	kindSelector = Kit.segmented({
		Options = {
			{ Id = "Normal", Label = "Normal" },
			{ Id = "Classe", Label = "Classé" },
			{ Id = "Entrainement", Label = "Entraînement" },
		},
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.fromOffset(0, 22),
		ZIndex = 7,
		Parent = body,
		OnChange = function(value: string)
			kind = value
			refresh()
		end,
	})
	Kit.label({
		Text = "MODE",
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.Tiny,
		Color = C.TextFaint,
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.fromOffset(0, 82),
		ZIndex = 6,
		Parent = body,
	})
	local modeOptions = {}
	for _, mode in Config.ModeOrder do
		table.insert(modeOptions, { Id = mode, Label = mode })
	end
	modeSelector = Kit.segmented({
		Options = modeOptions,
		Value = "3v3",
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.fromOffset(0, 104),
		ZIndex = 7,
		Parent = body,
		OnChange = function()
			refresh()
		end,
	})
	info = Kit.label({
		Text = "",
		TextSize = Theme.Text.Small,
		Color = C.TextMuted,
		Wrap = true,
		AlignY = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 60),
		Position = UDim2.fromOffset(0, 162),
		ZIndex = 6,
		Parent = body,
	})
	botsButton = Kit.button({
		Text = "Bots : activés",
		Variant = "Ghost",
		Size = UDim2.new(1, 0, 0, 32),
		Position = UDim2.fromOffset(0, 214),
		TextSize = Theme.Text.Small,
		ZIndex = 7,
		Parent = body,
		OnClick = function()
			fillBots = not fillBots
			refresh()
		end,
	})
	searchingLabel = Kit.label({
		Text = "",
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.H3,
		Size = UDim2.new(1, -150, 0, 56),
		Position = UDim2.new(0, 0, 1, -56),
		Visible = false,
		ZIndex = 7,
		Parent = body,
	})
	launch = Kit.button({
		Text = "RECHERCHER",
		Variant = "Primary",
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.H3,
		Size = UDim2.new(1, 0, 0, 56),
		Position = UDim2.new(0, 0, 1, -56),
		ZIndex = 7,
		Parent = body,
		OnClick = function()
			local mode = modeSelector.Value()
			if kind == "Entrainement" then
				State.request("QueueAction", "Training", mode, fillBots)
			else
				State.request("QueueAction", "Search", mode, kind == "Classe")
			end
		end,
	})
	cancel = Kit.button({
		Text = "Annuler",
		Variant = "Secondary",
		Size = UDim2.fromOffset(130, 48),
		Position = UDim2.new(1, 0, 1, -52),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = 7,
		Parent = body,
		OnClick = function()
			State.request("QueueAction", "Cancel")
		end,
	})
	cancel.Instance.Visible = false

	-- Chronomètre de recherche.
	task.spawn(function()
		while card.Parent do
			local queue = State.Queue
			if queue.State == "Searching" and queue.Since then
				local mode = Config.Modes[queue.Mode or "3v3"]
				searchingLabel.Text = `Recherche {if mode then mode.Label else ""}{if queue.Ranked
					then " classé"
					else ""}  {Format.clock(math.max(0, os.time() - queue.Since))}`
			elseif queue.State == "Found" then
				searchingLabel.Text = "Partie trouvée !"
			elseif queue.State == "Teleporting" then
				searchingLabel.Text = "Connexion au terrain…"
			end
			task.wait(0.5)
		end
	end)

	State.ProfileChanged:Connect(refresh)
	State.PartyChanged:Connect(refresh)
	State.QueueChanged:Connect(refresh)
	refresh()
end

-- Groupe ---------------------------------------------------------------------------------------------

local thumbnails: { [number]: string } = {}

local function avatar(userId: number, parent: Instance, size: number, z: number): ImageLabel
	local image = Kit.new("ImageLabel", {
		BackgroundColor3 = C.Surface3,
		Size = UDim2.fromOffset(size, size),
		Image = thumbnails[userId] or "",
		ZIndex = z,
		Parent = parent,
	})
	Kit.corner(image, 8)
	if not thumbnails[userId] then
		task.spawn(function()
			local ok, url = pcall(function()
				return Players:GetUserThumbnailAsync(
					userId,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size150x150
				)
			end)
			if ok then
				thumbnails[userId] = url
				image.Image = url
			end
		end)
	end
	return image
end

local function buildParty()
	local strip = Kit.box({
		Size = UDim2.fromOffset(560, 150),
		Position = UDim2.new(1, -40, 1, -40),
		AnchorPoint = Vector2.new(1, 1),
		ZIndex = 5,
		Parent = home,
	})
	Kit.label({
		Text = "GROUPE",
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.Tiny,
		Color = C.TextFaint,
		AlignX = Enum.TextXAlignment.Right,
		Size = UDim2.new(1, 0, 0, 16),
		ZIndex = 6,
		Parent = strip,
	})
	local slots =
		Kit.box({ Size = UDim2.new(1, 0, 0, 120), Position = UDim2.fromOffset(0, 26), ZIndex = 6, Parent = strip })
	Kit.list(slots, 10, true, Enum.HorizontalAlignment.Right)
	local picker: Frame? = nil

	local function closePicker()
		if picker then
			picker:Destroy()
			picker = nil
		end
	end

	local function openPicker()
		closePicker()
		local panel = Kit.surface({
			Color = C.Surface,
			Size = UDim2.fromOffset(340, 380),
			Position = UDim2.new(1, -40, 1, -210),
			AnchorPoint = Vector2.new(1, 1),
			Radius = Theme.RadiusLarge,
			ZIndex = 40,
			Parent = home,
		})
		picker = panel
		Kit.label({
			Text = "Inviter",
			Font = Theme.Fonts.Bold,
			TextSize = Theme.Text.H3,
			Position = UDim2.fromOffset(20, 16),
			Size = UDim2.new(1, -120, 0, 26),
			ZIndex = 41,
			Parent = panel,
		})
		Kit.button({
			Text = "Fermer",
			Variant = "Ghost",
			Size = UDim2.fromOffset(84, 32),
			Position = UDim2.new(1, -16, 0, 14),
			AnchorPoint = Vector2.new(1, 0),
			TextSize = Theme.Text.Small,
			ZIndex = 42,
			Parent = panel,
			OnClick = closePicker,
		})
		local list = Kit.scroll({
			Size = UDim2.new(1, -24, 1, -72),
			Position = UDim2.fromOffset(12, 60),
			ZIndex = 41,
			Parent = panel,
		})
		Kit.list(list, 6)
		local count = 0
		local party = State.Party
		for _, other in Players:GetPlayers() do
			local inParty = false
			if party then
				for _, member in party.Members do
					if member.UserId == other.UserId then
						inParty = true
					end
				end
			end
			if other ~= LocalPlayer and not inParty then
				count += 1
				local row = Kit.surface({
					Color = C.Surface2,
					Size = UDim2.new(1, -8, 0, 52),
					Order = count,
					ZIndex = 42,
					Parent = list,
				})
				local face = avatar(other.UserId, row, 36, 43)
				face.Position = UDim2.fromOffset(8, 8)
				Kit.label({
					Text = other.DisplayName,
					Font = Theme.Fonts.Semibold,
					Position = UDim2.fromOffset(54, 0),
					Size = UDim2.new(1, -150, 1, 0),
					ZIndex = 43,
					Parent = row,
				})
				Kit.button({
					Text = "Inviter",
					Variant = "Primary",
					TextSize = Theme.Text.Small,
					Size = UDim2.fromOffset(84, 34),
					Position = UDim2.new(1, -9, 0.5, 0),
					AnchorPoint = Vector2.new(1, 0.5),
					ZIndex = 43,
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
				Text = "Aucun autre joueur sur ce serveur.",
				Color = C.TextMuted,
				TextSize = Theme.Text.Small,
				Wrap = true,
				Size = UDim2.new(1, 0, 0, 40),
				ZIndex = 42,
				Parent = list,
			})
		end
		Kit.reveal(panel, 0, 10)
	end

	local function render(party: any)
		Kit.clear(slots)
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
			local slot = Kit.surface({
				Color = C.Surface,
				Size = UDim2.fromOffset(100, 120),
				Order = index,
				ZIndex = 6,
				Parent = slots,
			})
			if member then
				local face = avatar(member.UserId, slot, 64, 7)
				face.Position = UDim2.fromOffset(18, 12)
				Kit.label({
					Text = member.Name,
					Font = Theme.Fonts.Semibold,
					TextSize = Theme.Text.Small,
					AlignX = Enum.TextXAlignment.Center,
					Size = UDim2.new(1, -12, 0, 18),
					Position = UDim2.fromOffset(6, 80),
					ZIndex = 7,
					Parent = slot,
				})
				Kit.label({
					Text = if member.UserId == leaderId then "CHEF" else `NIV. {member.Level}`,
					Font = Theme.Fonts.Bold,
					TextSize = Theme.Text.Tiny,
					Color = if member.UserId == leaderId then C.Accent else C.TextFaint,
					AlignX = Enum.TextXAlignment.Center,
					Size = UDim2.new(1, 0, 0, 14),
					Position = UDim2.fromOffset(0, 98),
					ZIndex = 7,
					Parent = slot,
				})
				if iAmLeader and member.UserId ~= LocalPlayer.UserId then
					local kick = Kit.new("TextButton", {
						AutoButtonColor = false,
						BackgroundTransparency = 1,
						Text = "",
						Size = UDim2.fromScale(1, 1),
						ZIndex = 9,
						Parent = slot,
					})
					kick.Activated:Connect(function()
						State.request("PartyAction", "Kick", member.UserId)
					end)
				end
			elseif iAmLeader then
				local add = Kit.new("TextButton", {
					AutoButtonColor = false,
					BackgroundTransparency = 1,
					Text = "",
					Size = UDim2.fromScale(1, 1),
					ZIndex = 8,
					Parent = slot,
				})
				Kit.label({
					Text = "+",
					Font = Theme.Fonts.Display,
					TextSize = 40,
					Color = C.TextFaint,
					AlignX = Enum.TextXAlignment.Center,
					Size = UDim2.new(1, 0, 0, 70),
					Position = UDim2.fromOffset(0, 12),
					ZIndex = 7,
					Parent = slot,
				})
				Kit.label({
					Text = "Inviter",
					Font = Theme.Fonts.Semibold,
					TextSize = Theme.Text.Small,
					Color = C.TextMuted,
					AlignX = Enum.TextXAlignment.Center,
					Size = UDim2.new(1, 0, 0, 18),
					Position = UDim2.fromOffset(0, 84),
					ZIndex = 7,
					Parent = slot,
				})
				add.MouseEnter:Connect(function()
					slot.BackgroundColor3 = C.Surface2
				end)
				add.MouseLeave:Connect(function()
					slot.BackgroundColor3 = C.Surface
				end)
				add.Activated:Connect(openPicker)
			end
		end
		if party then
			local leave = Kit.button({
				Text = "Quitter",
				Variant = "Ghost",
				TextSize = Theme.Text.Small,
				Size = UDim2.fromOffset(84, 30),
				Position = UDim2.fromOffset(0, -4),
				ZIndex = 7,
				Parent = strip,
				OnClick = function()
					State.request("PartyAction", "Leave")
				end,
			})
			leave.Instance.Name = "Quitter"
		else
			local old = strip:FindFirstChild("Quitter")
			if old then
				old:Destroy()
			end
		end
	end
	State.PartyChanged:Connect(function(party)
		local old = strip:FindFirstChild("Quitter")
		if old then
			old:Destroy()
		end
		render(party)
	end)
	State.ProfileChanged:Connect(function()
		if not State.Party then
			render(nil)
		end
	end)
	render(State.Party)
end

function LobbyMenu.start()
	if not State.isLobby() then
		return
	end
	gui, root = Kit.screen("Lobby", 10, LocalPlayer:WaitForChild("PlayerGui"))
	gui.Enabled = false
	home = Kit.box({ Name = "Accueil", ZIndex = 5, Parent = root })

	buildTopBar()
	buildPlayPanel()
	buildParty()

	local pageLayer = Kit.box({ Name = "Pages", ZIndex = 10, Parent = root })
	pages["CASIER"] = LockerScreen.create(pageLayer)
	pages["BOUTIQUE"] = ShopScreen.create(pageLayer)
	pages["CLAN"] = ClanScreen.create(pageLayer)
	pages["TUTORIEL"] = TutorialScreen.create(pageLayer, function()
		closeModal("TUTORIEL")
	end)
	pages["NOUVEAUTÉS"] = UpdatesScreen.create(pageLayer, function()
		closeModal("NOUVEAUTÉS")
	end)

	local function updateVisibility()
		gui.Enabled = State.Started and not State.inMatch() and State.Setup == nil
	end
	State.Began:Connect(function()
		updateVisibility()
		selectTab("JOUER")
		local profile = State.Profile
		if profile and not profile.TutorialDone and profile.Stats.Matches == 0 then
			openModal("TUTORIEL")
		end
	end)
	State.MatchChanged:Connect(function()
		if State.inMatch() then
			selectTab("JOUER")
		end
		updateVisibility()
	end)
	State.SetupChanged:Connect(function()
		selectTab("JOUER")
		updateVisibility()
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
